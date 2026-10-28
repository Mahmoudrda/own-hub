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
    full); {} when the fee was already set. 8 percent for a client the coach
    brought with her invite code (relationship source 'invite'), 15 percent
    otherwise; both come from coachingConfig/instapay (model.config)."""
    if payment.get("feeOwedAt"):
        return {}
    bps = cfg["feeBpsInvite"] if rel_source == "invite" else cfg["feeBpsMarketplace"]
    return {"feePiasters": fee_piasters(payment.get("feeBasePiasters", payment["baseAmountPiasters"]), bps), "feeBps": bps,
            "feeState": "owed", "feeOwedAt": now}


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
    """One statement per coach with fees owed last month (Cairo calendar).
    Safe to run twice: an existing statement is never rewritten."""
    year, month = previous_month(now)
    start, end = month_bounds(year, month)
    accounts = db.collection("coachingConfig").document("receivingAccounts").get()
    pay_to = ((accounts.to_dict() or {}).get("instapay") or {}) if accounts.exists else {}
    by_coach: dict = {}
    for snap in db.collection("payments").where("feeOwedAt", ">=", start).where("feeOwedAt", "<", end).stream():
        row = snap.to_dict() or {}
        by_coach.setdefault(row.get("coachUid"), []).append((snap.id, row))
    made = 0
    for coach_uid, rows in by_coach.items():
        if not coach_uid:
            continue
        ref = db.collection("feeStatements").document(statement_id(coach_uid, year, month))

        def body(transaction, ref=ref, coach_uid=coach_uid, rows=rows):
            if ref.get(transaction=transaction).exists:
                return False
            transaction.set(ref, {"coachUid": coach_uid, "year": year, "month": month, **build_lines(rows),
                                  "status": "open", "generatedAt": now, "dueAt": now + model.days(model.LIMITS["feeOverdueDays"]),
                                  "payTo": {"address": pay_to.get("address"), "holderName": pay_to.get("holderName")},
                                  "overdueNotified": False})
            return True

        if common.run(db, body):
            made += 1
            try:
                notify(coach_uid, "instapayStatementReady", f"{year}-{month:02d}")
            except Exception:  # noqa: BLE001
                pass
    return made


def mark_overdue(db, *, now: dt.datetime, notify) -> int:
    """A statement still unpaid 30 days after it was made: the coach takes no
    NEW clients (`coaches.acceptingClients` false; her own choice is kept in
    `acceptingBeforeOverdue`). Existing clients are never touched (4.13)."""
    flagged = 0
    for snap in list(db.collection("feeStatements").where("status", "in", list(OPEN_STATEMENT)).stream()):
        row = snap.to_dict() or {}
        due = common.as_utc(row.get("dueAt"))
        if due is None or due > now or row.get("overdueNotified"):
            continue
        coach_ref = db.collection("coaches").document(row["coachUid"])

        def body(transaction, snap=snap, row=row, coach_ref=coach_ref):
            fresh = common.read(snap.reference, transaction)
            coach = common.read(coach_ref, transaction)
            if not fresh or fresh.get("overdueNotified") or fresh.get("status") not in OPEN_STATEMENT:
                return False
            transaction.update(snap.reference, {"overdueNotified": True})
            transaction.set(profile.standing_ref(db, row["coachUid"]), {"feeOverdue": True}, merge=True)
            if coach is not None:
                changes = {"acceptingClients": False}
                if coach.get("acceptingBeforeOverdue") is None:  # a second late statement keeps what she chose first
                    changes["acceptingBeforeOverdue"] = coach.get("acceptingClients") is not False
                transaction.update(coach_ref, changes)
            return True

        if common.run(db, body):
            flagged += 1
            try:
                notify(row["coachUid"], "instapayFeeOverdue", f"{row['year']}-{int(row['month']):02d}")
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
        status = common.one_of(status, ("open", "paid_claimed", "paid"))
    after = data.get("after")
    if after is not None:
        after = common.text(after, max_len=160)
    common.log_access(db, actor, "fees.list", "statements", now)
    rows = [(s.id, s.to_dict() or {}) for s in db.collection("feeStatements").stream()]
    rows = [r for r in rows if status is None or r[1].get("status") == status]
    rows.sort(key=lambda r: (str(common.as_utc(r[1].get("generatedAt"))), r[0]), reverse=True)
    if after:
        ids = [r[0] for r in rows]
        rows = rows[ids.index(after) + 1:] if after in ids else []
    more = len(rows) > 25
    rows = rows[:25]
    keep = ("coachUid", "year", "month", "status", "totalDuePiasters", "disputedPiasters", "settledPiasters", "waivedPiasters",
            "generatedAt", "dueAt", "claimedAt", "claimedTxn", "paidAt")
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


def confirm_payment(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    """The owner (finance or admin) confirms the coach's fee payment: the owed
    lines become 'settled', and a coach who was overdue takes new clients again
    once no statement of hers is late."""
    from . import errors

    statement = common.text(data.get("statementId"), max_len=160)
    common.log_access(db, actor, "fees.confirm", statement, now)
    ref = db.collection("feeStatements").document(statement)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        if row["status"] == "paid":
            return {"status": "paid"}
        if row["status"] not in OPEN_STATEMENT:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        coach_uid = row["coachUid"]
        coach_ref = db.collection("coaches").document(coach_uid)
        pay_refs = [db.collection("payments").document(line["paymentId"]) for line in row.get("lines") or []]
        pays = [common.read(r, transaction) for r in pay_refs]
        coach = common.read(coach_ref, transaction)
        others = [s for s in db.collection("feeStatements").where("coachUid", "==", coach_uid)
                  .where("status", "in", list(OPEN_STATEMENT)).stream(transaction=transaction) if s.id != ref.id]
        late = any((common.as_utc((s.to_dict() or {}).get("dueAt")) or now) <= now for s in others)

        transaction.update(ref, {"status": "paid", "paidAt": now, "confirmedBy": common.staff_ref(actor)})
        for pay_ref, pay in zip(pay_refs, pays):
            if pay is not None and pay.get("feeState") == "owed":
                transaction.update(pay_ref, {"feeState": "settled"})
        if not late:
            transaction.set(profile.standing_ref(db, coach_uid), {"feeOverdue": False}, merge=True)
            if coach is not None and "acceptingBeforeOverdue" in coach:
                transaction.update(coach_ref, {"acceptingClients": coach["acceptingBeforeOverdue"] is not False,
                                               "acceptingBeforeOverdue": None})
        return {"status": "paid"}

    return common.run(db, body)
