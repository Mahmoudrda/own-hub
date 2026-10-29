"""Own Hub's fee (D63, spec 4.13, 13.1): owed from the moment access starts."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import model, profile


def fee_piasters(base_piasters: int, bps: int) -> int:
    """On the package price only: the 1 to 99 extra piasters that make the amount
    unique belong to the coach. Integer arithmetic, rounded down."""
    return base_piasters * bps // 10000


def at_activation(payment: dict, cfg: dict, rel_source, now: dt.datetime) -> dict:
    """The payment fields to write when access first starts (provisional or
    full); {} when the fee was already set. 7.5 percent for a client the coach
    brought with her invite code (relationship source 'invite'), 15 percent
    otherwise; both come from coachingConfig/instapay (model.config)."""
    if payment.get("feeOwedAt"):
        return {}
    bps = cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"]
    return {"feePiasters": fee_piasters(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), bps), "feeBps": bps,
            "feeState": "owed", "feeOwedAt": now}


def source_of(seen: dict):
    """The pair's source: the relationship's, else the subscription's (the
    relationship gets it only when the first coaching begins, after the fee)."""
    rel = seen["rel"].to_dict() if seen["rel"].exists else {}
    return (rel or {}).get("source") or (seen.get("sub") or {}).get("source")


def pay_to(db) -> dict:
    accounts = db.collection("coachingConfig").document("receivingAccounts").get()
    row = ((accounts.to_dict() or {}).get("instapay") or {}) if accounts.exists else {}
    return {"address": row.get("address"), "holderName": row.get("holderName")}


def due_of(row: dict):
    """When the bill puts her account on hold; a statement made before the
    3 and 7 day rule has only its 30 day dueAt."""
    return common.as_utc(row.get("holdAt") or row.get("dueAt"))


def on_hold_bill(row: dict) -> bool:
    """Her account is held for this bill: the server put it on hold and it still owes something."""
    return bool(row.get("overdueNotified")) and row.get("status") != "paid" and row.get("totalDuePiasters", 1) > 0


def start(transaction, db, ref, payment: dict, cfg: dict, rel_source, now: dt.datetime) -> dict:
    """`at_activation` plus the bill for this one payment: due 3 days after the
    fee became owed, on hold at 7. Returns the payment fields to write (with
    `feeStatementId`); {} when the fee was already set. Call before the
    caller's own writes to `ref`."""
    fee = at_activation(payment, cfg, rel_source, now)
    if not fee or fee["feePiasters"] <= 0:
        return fee
    bill = f"{payment['coachUid']}__{ref.id}"
    local = common.cairo_day(now)
    transaction.set(db.collection("feeStatements").document(bill), {
        "coachUid": payment["coachUid"], "year": local.year, "month": local.month, "paymentId": ref.id,
        **build_lines([(ref.id, {**payment, **fee})]), "status": "open", "generatedAt": now,
        "dueAt": now + model.days(model.LIMITS["feeDueDays"]), "holdAt": now + model.days(model.LIMITS["feeHoldDays"]),
        "payTo": pay_to(db), "overdueNotified": False, "readyNotified": False, "dueSoonSent": False, "dueTodaySent": False})
    return {**fee, "feeStatementId": bill}


def recompute(payment: dict, paid_piasters: int, cfg: dict, rel_source) -> dict:
    """The fee when the coach accepts less in writing: on the package price or
    what she actually received, whichever is lower."""
    bps = payment.get("feeBps") or (cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"])
    base = min(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), paid_piasters)
    return {"feePiasters": fee_piasters(base, bps), "feeBps": bps}


# ----------------------------------------------------------- the monthly statement (spec 4.13)

OPEN_STATEMENT = ("open", "paid_claimed")


def statement_id(coach_uid: str, year: int, month: int) -> str:
    return f"{coach_uid}__{year}-{month:02d}"


def previous_month(now: dt.datetime) -> tuple:
    """(year, month) of the month before `now` in Cairo time."""
    local = common.cairo_day(now)
    return (local.year - 1, 12) if local.month == 1 else (local.year, local.month - 1)


def month_bounds(year: int, month: int) -> tuple:
    """[start, end) of a Cairo calendar month as UTC datetimes (Egypt changes
    its clock; zoneinfo does the arithmetic)."""
    start = dt.datetime(year, month, 1, tzinfo=common.CAIRO)
    end = dt.datetime(year + (month == 12), 1 if month == 12 else month + 1, 1, tzinfo=common.CAIRO)
    return start.astimezone(dt.timezone.utc), end.astimezone(dt.timezone.utc)


def build_lines(rows: list) -> dict:
    """Pure. rows = [(paymentId, payment dict)]. One line per payment and the
    totals. 'owed' counts toward the total due; 'disputed' is listed as pending
    (13.5); 'settled' and 'waived' are shown and not counted."""
    lines, totals = [], {"owed": 0, "disputed": 0, "settled": 0, "waived": 0}
    for pid, row in sorted(rows, key=lambda r: (str(common.as_utc(r[1].get("feeOwedAt"))), r[0])):
        state = row.get("feeState") or "owed"
        lines.append({"paymentId": pid, "reference": row.get("reference"), "basePiasters": row.get("baseAmountPiasters"),
                      "feePiasters": row.get("feePiasters", 0), "feeState": state, "owedAt": row.get("feeOwedAt")})
        totals[state] = totals.get(state, 0) + row.get("feePiasters", 0)
    return {"lines": lines, "totalDuePiasters": totals["owed"], "disputedPiasters": totals["disputed"],
            "settledPiasters": totals["settled"], "waivedPiasters": totals["waived"]}


def generate(db, *, now: dt.datetime, notify) -> int:
    """The safety net: one statement per coach for last month's owed lines that
    have no bill yet (`feeStatementId`), due 3 days and on hold at 7 days from
    now. Safe to run twice: a billed line, or an existing statement, is never
    billed again."""
    year, month = previous_month(now)
    start, end = month_bounds(year, month)
    pay_to_ = pay_to(db)
    by_coach: dict = {}
    for snap in db.collection("payments").where("feeOwedAt", ">=", start).where("feeOwedAt", "<", end).stream():
        row = snap.to_dict() or {}
        if not row.get("feeStatementId"):
            by_coach.setdefault(row.get("coachUid"), []).append((snap.id, row))
    made = 0
    for coach_uid, rows in by_coach.items():
        if not coach_uid:
            continue
        ref = db.collection("feeStatements").document(statement_id(coach_uid, year, month))

        def body(transaction, ref=ref, coach_uid=coach_uid, rows=rows):
            if ref.get(transaction=transaction).exists:
                return False
            pay_refs = [db.collection("payments").document(pid) for pid, _ in rows]
            fresh = [(r.id, common.read(r, transaction)) for r in pay_refs]
            fresh = [(pid, row) for pid, row in fresh if row is not None and not row.get("feeStatementId")]
            if not fresh or build_lines(fresh)["totalDuePiasters"] == 0:
                return False  # nothing owed: no statement, no push
            transaction.set(ref, {"coachUid": coach_uid, "year": year, "month": month, **build_lines(fresh),
                                  "status": "open", "generatedAt": now, "dueAt": now + model.days(model.LIMITS["feeDueDays"]),
                                  "holdAt": now + model.days(model.LIMITS["feeHoldDays"]), "payTo": pay_to_,
                                  "overdueNotified": False, "readyNotified": True, "dueSoonSent": False, "dueTodaySent": False})
            for pid, _ in fresh:
                transaction.update(db.collection("payments").document(pid), {"feeStatementId": ref.id})
            return True

        if common.run(db, body):
            made += 1
            try:
                notify(coach_uid, "instapayStatementReady", f"{year}-{month:02d}")
            except Exception:  # noqa: BLE001
                pass
    return made


_LINE_KEYS = ("lines", "totalDuePiasters", "disputedPiasters", "settledPiasters", "waivedPiasters")


def _sync(db, bill_ref, now: dt.datetime) -> bool:
    """Brings a bill's lines and totals in line with its payments (a lower
    accepted amount, a refund, a staff decision, a dispute). A bill with nothing
    owed and nothing in dispute is closed as waived. True when it was closed."""
    def body(transaction):
        row = common.read(bill_ref, transaction)
        if row is None or row.get("status") not in OPEN_STATEMENT:
            return False
        ids = [line["paymentId"] for line in row.get("lines") or [] if line.get("paymentId")]
        rows = [(i, common.read(db.collection("payments").document(i), transaction)) for i in ids]
        rows = [(i, r) for i, r in rows if r is not None]
        if not rows:
            return False
        built = build_lines(rows)
        changes = {k: built[k] for k in _LINE_KEYS}
        closed = built["totalDuePiasters"] == 0 and built["disputedPiasters"] == 0
        if closed:
            changes.update(status="paid", waived=True, paidAt=now)
        was = {line.get("paymentId"): line.get("feeState") for line in row.get("lines") or []}
        back = any(was.get(line["paymentId"]) == "disputed" and line["feeState"] == "owed" for line in built["lines"])
        still_owed = any(was.get(line["paymentId"]) == "owed" and line["feeState"] == "owed" for line in built["lines"])
        if back and not closed and not still_owed:
            # a fee that leaves a dispute as owed starts its 3 and 7 days from now, not from the old dates;
            # but never when another owed line is already on the bill: its dates (the earliest) stand
            changes.update(dueAt=now + model.days(model.LIMITS["feeDueDays"]), holdAt=now + model.days(model.LIMITS["feeHoldDays"]),
                           overdueNotified=False, dueSoonSent=False, dueTodaySent=False)
        if any(row.get(k) != v for k, v in changes.items()):
            transaction.update(bill_ref, changes)
        return closed

    return common.run(db, body)


def _owed_row(db, snap, now: dt.datetime):
    """The bill as it stands after `_sync`, or None when nothing is owed on it
    now (closed, or only in dispute: no reminder, no hold)."""
    if _sync(db, snap.reference, now):
        return None
    row = snap.reference.get().to_dict() or {}
    return row if row.get("status") in OPEN_STATEMENT and row.get("totalDuePiasters", 1) > 0 else None


def refresh(db, payment_id: str, now: dt.datetime, *, notify=None, notify_client=None) -> None:
    """After a payment's fee changed (lower amount accepted, refund, staff
    decision): its bill follows, and if that closed it the hold check runs."""
    bill = (db.collection("payments").document(payment_id).get().to_dict() or {}).get("feeStatementId")
    if not bill:
        return
    ref = db.collection("feeStatements").document(bill)
    coach_uid = (ref.get().to_dict() or {}).get("coachUid")
    if coach_uid and _sync(db, ref, now):
        release(db, coach_uid, now, notify=notify, notify_client=notify_client)


def release(db, coach_uid: str, now: dt.datetime, *, notify=None, notify_client=None) -> bool:
    """THE way a hold or a fee block ends, whichever way a bill closed
    (confirmed by staff, waived by a refund, waived by staff). Nothing happens
    while another bill of hers with something owed is past its hold time.
    Then: she takes new clients again as before, the hold ends, each coaching
    that was running when it began moves later by the hold length, her clients'
    `coachAway` goes, she and they are told. True when it released."""
    for snap in list(db.collection("feeStatements").where("coachUid", "==", coach_uid).where("status", "in", list(OPEN_STATEMENT)).stream()):
        _sync(db, snap.reference, now)  # a stale total must not keep her held
    coach_ref = db.collection("coaches").document(coach_uid)
    priv_ref = db.collection("coachPrivate").document(coach_uid)
    told: dict = {}

    def body(transaction):
        told.clear()
        priv = common.read(priv_ref, transaction) or {}
        coach = common.read(coach_ref, transaction)
        bills = [b.to_dict() or {} for b in db.collection("feeStatements").where("coachUid", "==", coach_uid)
                 .where("status", "in", list(OPEN_STATEMENT)).stream(transaction=transaction)]
        late = any(b.get("totalDuePiasters", 1) > 0 and (due_of(b) or now) <= now for b in bills)
        held = bool(priv.get("hold"))
        restore = priv.get("acceptingBeforeOverdue") is not None   # None once restored: never flips her own choice again
        if late or (not held and not restore):
            return False
        rels, subs = [], []
        if held:
            rels = [r.reference for r in db.collection("relationships").where("coachUid", "==", coach_uid)
                    .stream(transaction=transaction) if (r.to_dict() or {}).get("coachAway")]
            subs = [(r.reference, r.to_dict() or {}) for r in db.collection("subscriptions").where("coachUid", "==", coach_uid)
                    .where("status", "==", "active").stream(transaction=transaction)]

        transaction.set(profile.standing_ref(db, coach_uid), {"feeOverdue": False}, merge=True)
        if restore:
            if coach is not None:
                transaction.update(coach_ref, {"acceptingClients": priv["acceptingBeforeOverdue"] is not False})
            transaction.update(priv_ref, {"acceptingBeforeOverdue": None})
        if held:
            since = common.as_utc(priv["hold"].get("since")) or now
            gap = max(now - since, dt.timedelta(0))
            transaction.update(priv_ref, {"hold": None})
            for rel in rels:
                transaction.update(rel, {"coachAway": False})
            moved_clients = []
            for sub_ref, sub in subs:
                if not sub.get("endsAt"):
                    continue
                began = common.as_utc(sub.get("startsAt"))
                lost = gap if began is None or began <= since else max(now - began, dt.timedelta(0))  # one that began in the hold lost only its part
                end = common.as_utc(sub["endsAt"]) + lost
                transaction.update(sub_ref, {"endsAt": end, "holdCreditSeconds": int(sub.get("holdCreditSeconds") or 0) + int(lost.total_seconds()),
                                             **({"provisionalUntil": end} if sub.get("provisionalUntil") else {})})
                moved_clients.append(sub.get("clientUid"))
            told.update(coach=coach_uid, clients=sorted({c for c in moved_clients if c}))
        return True

    out = common.run(db, body)
    for who, fn, kind in ([(told["coach"], notify, "instapayAccountActive")] + [(c, notify_client or notify, "coachBack") for c in told["clients"]]) if told else []:
        try:
            if fn is not None:
                fn(who, kind)
        except Exception:  # noqa: BLE001
            pass
    return out


def _ref(row: dict) -> str:
    """What a push about this bill carries: the payment it was made for, else its month."""
    return row.get("paymentId") or f"{row['year']}-{int(row['month']):02d}"


def remind(db, *, now: dt.datetime, notify) -> dict:
    """Once each, from the hourly pass: the new bill, 24 hours before it is
    due, and when it falls due. Neutral pushes, no amounts."""
    sent = {"ready": 0, "dueSoon": 0, "dueToday": 0}
    for snap in list(db.collection("feeStatements").where("status", "==", "open").stream()):
        row = _owed_row(db, snap, now)
        due = common.as_utc((row or {}).get("dueAt"))
        if row is None or due is None:
            continue
        month = _ref(row)
        steps = []
        if row.get("readyNotified") is False:
            steps.append(("readyNotified", "instapayStatementReady", "ready"))
        if due <= now and row.get("dueTodaySent") is False:
            steps.append(("dueTodaySent", "instapayFeeDueToday", "dueToday"))
            if row.get("dueSoonSent") is False:
                snap.reference.update({"dueSoonSent": True})
        elif due - model.hours(24) <= now < due and row.get("dueSoonSent") is False:
            steps.append(("dueSoonSent", "instapayFeeDueSoon", "dueSoon"))
        for flag, kind, key in steps:
            snap.reference.update({flag: True})
            sent[key] += 1
            try:
                notify(row["coachUid"], kind, month)
            except Exception:  # noqa: BLE001
                pass
    return sent


def mark_overdue(db, *, now: dt.datetime, notify) -> int:
    """A bill not confirmed by staff at its hold time (7 days after the fee became
    owed; her own "I paid" does not count): her account goes ON HOLD. `coaches.hold = {reason, since}`, no new clients
    (`acceptingClients` false; her own choice is kept in `acceptingBeforeOverdue`),
    and each active client's relationship says `coachAway`. Nothing is deleted;
    existing clients keep their plans and the chat stays readable. Staff
    confirming the fee ends it (`confirm_payment`)."""
    flagged = 0
    for snap in list(db.collection("feeStatements").where("status", "in", list(OPEN_STATEMENT)).stream()):
        row = snap.to_dict() or {}
        due = due_of(row)
        if due is None or due > now or row.get("overdueNotified"):
            continue
        row = _owed_row(db, snap, now)
        if row is None:
            continue
        coach_ref = db.collection("coaches").document(row["coachUid"])
        priv_ref = db.collection("coachPrivate").document(row["coachUid"])
        rels = db.collection("relationships").where("coachUid", "==", row["coachUid"])

        def body(transaction, snap=snap, row=row, coach_ref=coach_ref, priv_ref=priv_ref, rels=rels):
            fresh = common.read(snap.reference, transaction)
            coach = common.read(coach_ref, transaction)
            priv = common.read(priv_ref, transaction) or {}
            active = [r.reference for r in rels.stream(transaction=transaction) if (r.to_dict() or {}).get("status") == "active"]
            if not fresh or fresh.get("overdueNotified") or fresh.get("status") not in OPEN_STATEMENT:
                return False
            transaction.update(snap.reference, {"overdueNotified": True})
            transaction.set(profile.standing_ref(db, row["coachUid"]), {"feeOverdue": True}, merge=True)
            if coach is not None:
                transaction.update(coach_ref, {"acceptingClients": False})
                private = {}
                if not priv.get("hold"):
                    private["hold"] = {"reason": "fee", "since": now}
                if priv.get("acceptingBeforeOverdue") is None:  # a second late bill keeps what she chose first
                    private["acceptingBeforeOverdue"] = coach.get("acceptingClients") is not False
                transaction.set(priv_ref, private, merge=True)
                for rel in active:
                    transaction.update(rel, {"coachAway": True})
            return True

        if common.run(db, body):
            flagged += 1
            try:
                notify(row["coachUid"], "instapayFeeOverdue", _ref(row))
            except Exception:  # noqa: BLE001
                pass
    return flagged


def list_statements(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    """The owner's overview (finance or admin): statements newest first, 25 a
    page, optionally one status. Totals only; the payment lines stay with the
    coach. shortcut: reads every statement, fine while coaches number in the
    hundreds; page by a stored cursor beyond that."""
    status = data.get("status")
    if status is not None:
        status = common.one_of(status, ("open", "paid_claimed", "paid", "attention"))
    after = data.get("after")
    if after is not None:
        after = common.text(after, max_len=160)
    common.log_access(db, actor, "fees.list", "statements", now)
    rows = [(s.id, s.to_dict() or {}) for s in db.collection("feeStatements").stream()]
    if status == "attention":  # what needs staff: claims to check and accounts on hold
        rows = [r for r in rows if r[1].get("status") == "paid_claimed" or on_hold_bill(r[1])]
    else:
        rows = [r for r in rows if status is None or r[1].get("status") == status]
    rows.sort(key=lambda r: (str(common.as_utc(r[1].get("generatedAt"))), r[0]), reverse=True)
    rows.sort(key=lambda r: not on_hold_bill(r[1]))  # coaches on hold first, stable
    if after:
        ids = [r[0] for r in rows]
        rows = rows[ids.index(after) + 1:] if after in ids else []
    more = len(rows) > 25
    rows = rows[:25]
    keep = ("coachUid", "year", "month", "status", "totalDuePiasters", "disputedPiasters", "settledPiasters", "waivedPiasters",
            "generatedAt", "dueAt", "holdAt", "overdueNotified", "claimedAt", "claimedTxn", "paidAt")
    items = [{"statementId": sid, **{k: common.plain(row.get(k)) for k in keep}} for sid, row in rows]
    return {"items": items, "next": rows[-1][0] if more and rows else None}


def record_payment(db, uid: str, data: dict, *, coach_v, now: dt.datetime) -> dict:
    """PAY9 'Mark fee as paid': the coach says she paid Own Hub by InstaPay.
    The owner confirms in the dashboard; nothing is debited automatically."""
    from . import errors, proof

    common.require_coach(coach_v)
    statement = common.text(data.get("statementId"), max_len=160)
    txn = common.text(data.get("txnNumber"), max_len=40)
    key = proof.txn_key(txn)
    if len(key) < 6:
        raise common.bad()
    ref = db.collection("feeStatements").document(statement)
    reg_ref = db.collection("paymentTxnNumbers").document(f"FEE{key}")

    def body(transaction):
        row = common.read(ref, transaction)
        reg = reg_ref.get(transaction=transaction)
        if row is None or row.get("coachUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        if row["status"] == "paid_claimed":
            return {"status": "paid_claimed"}
        if row["status"] != "open":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        if reg.exists:
            raise common.refuse(errors.PRECONDITION, errors.TXN_REUSED)
        transaction.set(reg_ref, {"statementId": statement, "createdAt": now})
        transaction.update(ref, {"status": "paid_claimed", "claimedAt": now, "claimedTxn": txn})
        return {"status": "paid_claimed"}

    return common.run(db, body)


def reject_claim(db, actor: str, data: dict, *, now: dt.datetime, notify=None) -> dict:
    """Staff (finance or admin) say the coach's "I paid" did not check out: the
    bill goes back to `open`, with the reason, and she is asked to check it. The
    transfer number stays used. Time already run keeps running."""
    from . import errors

    statement = common.text(data.get("statementId"), max_len=160)
    reason = common.text(data.get("reason"), min_len=10, max_len=500, reason=errors.REASON_REQUIRED)
    common.log_access(db, actor, "fees.reject", statement, now)
    ref = db.collection("feeStatements").document(statement)
    held: dict = {}

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        if row["status"] != "paid_claimed":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        held["coach"], held["month"] = row["coachUid"], _ref(row)
        transaction.update(ref, {"status": "open", "claimedTxn": None, "claimedAt": None,
                                 "claimRejected": {"at": now, "by": common.staff_ref(actor), "reason": reason}})
        return {"status": "open"}

    out = common.run(db, body)
    try:
        if notify is not None:
            notify(held["coach"], "instapayFeeClaimRejected", held["month"])
    except Exception:  # noqa: BLE001
        pass
    return out


def confirm_payment(db, actor: str, data: dict, *, now: dt.datetime, notify=None, notify_client=None) -> dict:
    """The owner (finance or admin) confirms the coach's fee payment: the owed
    lines become 'settled', then the shared `release` check runs (a hold ends
    only when no other bill of hers with something owed is past its hold time)."""
    from . import errors

    statement = common.text(data.get("statementId"), max_len=160)
    common.log_access(db, actor, "fees.confirm", statement, now)
    ref = db.collection("feeStatements").document(statement)
    held: dict = {}

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        if row["status"] == "paid":
            return {"status": "paid"}
        if row["status"] not in OPEN_STATEMENT:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        held["coach"] = row["coachUid"]
        pay_refs = [db.collection("payments").document(line["paymentId"]) for line in row.get("lines") or []]
        pays = [common.read(r, transaction) for r in pay_refs]
        disputed = [(r, p) for r, p in zip(pay_refs, pays) if p is not None and p.get("feeState") == "disputed"]
        if disputed and not any(p is not None and p.get("feeState") == "owed" for p in pays):
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)  # only a fee in dispute: decide that first
        transaction.update(ref, {"status": "paid", "paidAt": now, "confirmedBy": common.staff_ref(actor)})
        for pay_ref, pay in zip(pay_refs, pays):
            if pay is not None and pay.get("feeState") == "owed":
                transaction.update(pay_ref, {"feeState": "settled"})
        for pay_ref, pay in disputed:  # a fee still in dispute gets its own open bill, so a later "owed" is not lost
            own = f"{row['coachUid']}__{pay_ref.id}"
            transaction.set(db.collection("feeStatements").document(own), {
                **{k: row.get(k) for k in ("coachUid", "year", "month", "payTo", "dueAt", "holdAt")}, "paymentId": pay_ref.id,
                **build_lines([(pay_ref.id, pay)]), "status": "open", "generatedAt": now, "overdueNotified": False,
                "readyNotified": True, "dueSoonSent": False, "dueTodaySent": False})
            transaction.update(pay_ref, {"feeStatementId": own})
        return {"status": "paid"}

    out = common.run(db, body)
    if held:
        release(db, held["coach"], now, notify=notify, notify_client=notify_client)
    return out
