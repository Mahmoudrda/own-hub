# WO-10c: Scheduled functions: expiry and reminders, the 48 and 72 hour escalations, bounded access, fee statements on the 1st, fee paid and overdue
Depends on: WO-10b4, WO-10n, WO-10o, WO-10d-server
Size: L
Reads first: `docs/plan/INSTAPAY-PAYMENTS-SPEC.md` 4.1, 4.5, 4.7, 4.8, 4.13, 13.1, 13.4, 13.9; `functions/main.py` lines 2445-2470 (`coaching_sweeper`: how a scheduled job reads `store.db()` and the clock) and line 91 (`scheduler_fn` import); `functions/coaching/subscriptions.py` lines 668-700 (`_expire` pattern); `functions/payments/activation.py`, `coach.py` (`can_grant`), `fees.py`, `profile.py`; `functions/tests/test_coaching_sweeper.py` lines 1-40 (how a sweep test calls the module with a fixed clock)

## Why
Silence must never block anyone. A request not paid in 24 hours expires (a late proof within 7 days is still accepted); a coach who does not answer a proof gets a reminder at 48 hours and at 72 hours the payment goes to staff; a client whose coach is silent keeps bounded access; an amber proof nobody objects to in 24 hours gives access; a refund request unanswered for 3 days goes to staff; a coach's report the client never answers goes to staff after 72 hours. Access that was only provisional ends when its time runs out, unless the payment is paid or under review because of silence. On the 1st of each month every coach gets a fee statement for last month, she records that she paid Own Hub by InstaPay, the owner confirms, and 30 days late means no new clients (existing clients are never cut off).

## Final result
Three scheduled functions registered in `main.py`: `expire_payments` (every 1 hours), `escalate_silent_payments` (every 30 minutes), `generate_fee_statements` (`0 6 1 * *`, Cairo time). Three callables: `record_fee_payment` (coach), `confirm_fee_payment` and `list_fee_statements` (finance or admin). All run with the kill switch off too (open payments must still resolve). Every pass re-checks each payment inside its own transaction, so overlapping runs and a client's action at the same moment are safe, and every change writes an event and the notifications of `states.notices_for`.

## Files to edit or create
| path | create or edit | what changes |
|---|---|---|
| `functions/payments/sweep.py` | create | `expire_pass` (expire, 12 hour reminder, pending addresses, overdue) |
| `functions/payments/escalate.py` | create | `escalate_pass` (48 and 72 hours, amber, refund, report, access end) |
| `functions/payments/fees.py` | edit | statements, `record_payment`, `confirm_payment` |
| `functions/main.py` | edit | three scheduled functions, two callables |
| `functions/tests/test_entrypoints.py` | edit | two names |
| `functions/tests/test_payments_scheduled.py` | create | sweep and escalation tests with a fake clock |
| `functions/tests/test_payments_fees.py` | create | statement tests |

## Steps
1. File `functions/payments/sweep.py`, create:
```python
"""The hourly pass: expiry, the 12 hour reminder, pending addresses coming due, overdue fees."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import engine, model, profile, states


def _expire_one(db, payment_id: str, now: dt.datetime):
    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        expires = common.as_utc(cur.get("expiresAt"))
        if cur["status"] != "awaiting_payment" or expires is None or expires > now:
            return None
        engine.move(transaction, db, ref, cur, "expired", states.SYSTEM, None, now, code="expired")
        return cur

    return common.run(db, body)


def _remind_one(db, payment_id: str, now: dt.datetime):
    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        if cur["status"] != "awaiting_payment" or cur.get("reminded12h"):
            return None
        transaction.update(ref, {"reminded12h": True})
        return cur

    return common.run(db, body)


def expire_pass(db, *, now: dt.datetime, notify) -> dict:
    counts = {"expired": 0, "reminded": 0, "addresses": 0, "overdue": 0}
    for snap in list(db.collection("payments").where("status", "==", "awaiting_payment").stream()):
        row = snap.to_dict() or {}
        expires, created = common.as_utc(row.get("expiresAt")), common.as_utc(row.get("createdAt"))
        if expires is not None and expires <= now:
            if _expire_one(db, snap.id, now):
                counts["expired"] += 1
        elif created is not None and created <= now - model.hours(12) and not row.get("reminded12h"):
            cur = _remind_one(db, snap.id, now)
            if cur:
                notify(cur["clientUid"], "instapayReminder")
                counts["reminded"] += 1
    for snap in list(db.collection("coachPaymentProfiles").stream()):
        pending = (snap.to_dict() or {}).get("pending") or {}
        when = common.as_utc(pending.get("effectiveAt"))
        if pending.get("address") and when is not None and when <= now:
            snap.reference.update({"address": pending["address"], "accountName": pending["accountName"], "pending": None})
            counts["addresses"] += 1
    counts["overdue"] = _overdue(db, now, notify)
    return counts


def _overdue(db, now: dt.datetime, notify) -> int:
    """A statement unpaid 30 days after it was made: the coach takes no NEW
    clients (`coaches.acceptingClients` false, her own choice kept in
    `acceptingBeforeOverdue`). Existing clients are never touched (4.13)."""
    flagged = 0
    for snap in list(db.collection("feeStatements").where("status", "in", ["open", "paid_claimed"]).stream()):
        row = snap.to_dict() or {}
        due = common.as_utc(row.get("dueAt"))
        if due is None or due > now or row.get("overdueNotified"):
            continue
        coach_ref = db.collection("coaches").document(row["coachUid"])

        def body(transaction, snap=snap, row=row, coach_ref=coach_ref):
            fresh = common.read(snap.reference, transaction)
            coach = common.read(coach_ref, transaction)
            if not fresh or fresh.get("overdueNotified") or fresh.get("status") not in ("open", "paid_claimed"):
                return False
            transaction.update(snap.reference, {"overdueNotified": True})
            transaction.set(profile.standing_ref(db, row["coachUid"]), {"instapayFeeOverdue": True}, merge=True)
            if coach is not None:
                prior = coach.get("acceptingClients")
                transaction.update(coach_ref, {"acceptingClients": False, "acceptingBeforeOverdue": prior is not False})
            return True

        if common.run(db, body):
            notify(row["coachUid"], "instapayFeeOverdue")
            flagged += 1
    return flagged
```
2. File `functions/payments/escalate.py`, create (full file). A rule returns `None` (nothing to do) or `(moves, notices)`: `moves` is a list of real `(from, to)` transitions whose pushes come from `states.notices_for`, `notices` is a list of `(party, kind)` extra pushes.
```python
"""The 48 and 72 hour rules and the other silences (spec 4.1, 4.5, 4.8, 13.4)."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import activation, coach, engine, fees, model, states

L = model.LIMITS


def _grant_provisional(transaction, db, ref, cur, seen, cfg, now, until) -> dict:
    rel_source = (seen["rel"].to_dict() or {}).get("source") if seen["rel"].exists else None
    changes = {"access": {"state": "provisional", "until": until}, **fees.at_activation(cur, cfg, rel_source, now)}
    transaction.update(ref, changes)
    if coach.can_grant(seen):
        activation.grant(transaction, db, seen, now, provisional_until=until)
    return {**cur, **changes}


def _access_until(now, seen):
    return now + model.days(min(L["provisionalMaxDays"], (seen["sub"].get("package") or {}).get("durationDays", 7)))


def _run(db, payment_id: str, now: dt.datetime, notify, rule) -> bool:
    """Re-reads the payment inside a transaction and applies `rule`. Pushes go
    out after the commit. True when the rule did something."""
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        seen = activation.read_for_start(transaction, db, cur["subId"])
        end_read = activation.read_for_end(transaction, db, cur["subId"])
        out = rule(db, transaction, ref, cur, seen, end_read, cfg, now)
        if out is not None:
            held["payment"], held["out"] = cur, out
        return out is not None

    done = common.run(db, body)
    if done:
        moves, notices = held["out"]
        engine.notify_moves(notify, held["payment"], moves)
        for party, kind in notices:
            notify(held["payment"]["clientUid" if party == states.CLIENT else "coachUid"], kind)
    return done


def rule_proof(db, t, ref, cur, seen, end_read, cfg, now):
    """proof_submitted: 72 hours -> review (the client kept safe); 48 hours ->
    the coach is reminded and bounded access starts; an amber nobody objected
    to for 24 hours -> bounded access."""
    if cur["status"] != "proof_submitted":
        return None
    sent = common.as_utc(cur.get("proofSubmittedAt"))
    if sent is None:
        return None
    age, access = now - sent, (cur.get("access") or {}).get("state")
    if age >= model.hours(L["escalateHours"]):
        pay = cur if access == "provisional" else _grant_provisional(t, db, ref, cur, seen, cfg, now, None)
        engine.move(t, db, ref, pay, "in_review", states.SYSTEM, None, now, code="coach_silent_72h",
                    changes={"dispute": {"kind": "coach_silent", "openedBy": "system", "openedAt": now},
                             "access": {"state": "provisional", "until": None}})
        return [("proof_submitted", "in_review")], []
    if age >= model.hours(L["coachRemindHours"]) and not cur.get("reminded48h"):
        t.update(ref, {"reminded48h": True})
        if access != "provisional":
            _grant_provisional(t, db, ref, cur, seen, cfg, now, _access_until(now, seen))
        return [], [(states.COACH, "instapayCoachReminder")]
    amber_until = common.as_utc(cur.get("amberUntil"))
    if cur.get("outcome") == "amber" and amber_until and amber_until <= now and access == "none":
        _grant_provisional(t, db, ref, cur, seen, cfg, now, _access_until(now, seen))
        return [], []
    return None


def rule_report(db, t, ref, cur, seen, end_read, cfg, now):
    """A coach's 'a client paid me' the client did not confirm in 72 hours (or answered no)."""
    report = cur.get("coachReport") or {}
    when = common.as_utc(report.get("reportedAt"))
    if cur["status"] not in ("awaiting_payment", "expired") or when is None or now < when + model.hours(L["escalateHours"]):
        return None
    engine.move(t, db, ref, cur, "in_review", states.SYSTEM, None, now, code="report_unanswered_72h",
                changes={"dispute": {"kind": "coach_report", "openedBy": "system", "openedAt": now,
                                     "clientAnswer": report.get("clientAnswer")}})
    return [(cur["status"], "in_review")], []


def rule_amount(db, t, ref, cur, seen, end_read, cfg, now):
    """A different amount the client did not answer in 72 hours."""
    if cur["status"] != "different_amount" or now < common.as_utc(cur["statusAt"]) + model.hours(L["escalateHours"]):
        return None
    engine.move(t, db, ref, cur, "in_review", states.SYSTEM, None, now, code="amount_unanswered_72h",
                changes={"dispute": {"kind": "different_amount", "openedBy": "system", "openedAt": now}})
    return [("different_amount", "in_review")], []


def rule_refund(db, t, ref, cur, seen, end_read, cfg, now):
    """A refund request the coach left unanswered for 3 days goes to staff."""
    due = common.as_utc((cur.get("refund") or {}).get("coachDueAt"))
    if cur["status"] != "refund_requested" or due is None or now < due:
        return None
    engine.move(t, db, ref, cur, "in_review", states.SYSTEM, None, now, code="refund_unanswered_3d",
                changes={"dispute": {"kind": "refund", "openedBy": "system", "openedAt": now}})
    return [("refund_requested", "in_review")], []


def rule_access_end(db, t, ref, cur, seen, end_read, cfg, now):
    """Bounded access that ran out while the payment is still not paid. Access
    held open by a silence review has `until` None and is not touched."""
    access = cur.get("access") or {}
    until = common.as_utc(access.get("until"))
    if access.get("state") != "provisional" or until is None or until > now or cur["status"] in model.PAID_STATUSES:
        return None
    t.update(ref, {"access": {"state": "none", "until": None}})
    activation.end(t, db, cur["subId"], end_read, "dispute", now)
    return [], []


def rule_access_warn(db, t, ref, cur, seen, end_read, cfg, now):
    """One day before bounded access ends, once."""
    access = cur.get("access") or {}
    until = common.as_utc(access.get("until"))
    if access.get("state") != "provisional" or until is None or cur.get("warned") or not (now < until <= now + model.days(1)):
        return None
    t.update(ref, {"warned": True})
    return [], [(states.CLIENT, "instapayAccessEndsSoon")]


STATUS_RULES = (
    ("proof_submitted", rule_proof, "proof"),
    ("awaiting_payment", rule_report, "report"),
    ("expired", rule_report, "report"),
    ("different_amount", rule_amount, "amount"),
    ("refund_requested", rule_refund, "refund"),
)


def escalate_pass(db, *, now: dt.datetime, notify) -> dict:
    counts = {"proof": 0, "report": 0, "amount": 0, "refund": 0, "accessEnded": 0, "accessWarned": 0}
    for status, rule, name in STATUS_RULES:
        for snap in list(db.collection("payments").where("status", "==", status).stream()):
            counts[name] += _run(db, snap.id, now, notify, rule)
    for snap in list(db.collection("payments").where("access.state", "==", "provisional").stream()):
        if _run(db, snap.id, now, notify, rule_access_end):
            counts["accessEnded"] += 1
        else:
            counts["accessWarned"] += _run(db, snap.id, now, notify, rule_access_warn)
    return counts
```
3. File `functions/payments/fees.py` (WO-10b2). Append the statement code:
```python
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
    for pid, row in sorted(rows, key=lambda r: str(common.as_utc(r[1].get("feeOwedAt")))):
        state = row.get("feeState") or "owed"
        lines.append({"paymentId": pid, "reference": row.get("reference"), "basePiasters": row.get("baseAmountPiasters"),
                      "feePiasters": row.get("feePiasters", 0), "feeState": state, "owedAt": row.get("feeOwedAt")})
        totals[state] = totals.get(state, 0) + row.get("feePiasters", 0)
    return {"lines": lines, "totalDuePiasters": totals["owed"], "disputedPiasters": totals["disputed"],
            "settledPiasters": totals["settled"], "waivedPiasters": totals["waived"]}


def generate(db, *, now: dt.datetime, notify) -> int:
    """One statement per coach with fees owed last month. Safe to run twice."""
    year, month = previous_month(now)
    start, end = month_bounds(year, month)
    accounts = db.collection("coachingConfig").document("receivingAccounts").get()
    pay_to = ((accounts.to_dict() or {}).get("instapay") or {}) if accounts.exists else {}
    made = 0
    for prof in list(db.collection("coachPaymentProfiles").stream()):
        coach_uid = prof.id
        rows = [(s.id, s.to_dict() or {}) for s in db.collection("payments").where("coachUid", "==", coach_uid)
                .where("feeOwedAt", ">=", start).where("feeOwedAt", "<", end).stream()]
        if not rows:
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
            notify(coach_uid, "instapayStatementReady")
    return made


def list_statements(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    """The owner's overview (finance or admin): statements newest first, 25 a page,
    optionally one status. Totals only; no payment lines (those stay with the coach)."""
    status = data.get("status")
    if status is not None:
        status = common.one_of(status, ("open", "paid_claimed", "paid"))
    after = data.get("after")
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
    statement_id_ = common.text(data.get("statementId"), max_len=160)
    txn = common.text(data.get("txnNumber"), max_len=40)
    key = proof.txn_key(txn)
    if len(key) < 6:
        raise common.bad()
    ref = db.collection("feeStatements").document(statement_id_)
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
        transaction.set(reg_ref, {"statementId": statement_id_, "createdAt": now})
        transaction.update(ref, {"status": "paid_claimed", "claimedAt": now, "claimedTxn": txn})
        return {"status": "paid_claimed"}

    return common.run(db, body)


def confirm_payment(db, actor: str, data: dict, *, now: dt.datetime) -> dict:
    """The owner (finance or admin) confirms the coach's fee payment: the owed
    lines become 'settled', and a coach who was overdue takes new clients again."""
    from . import errors, profile

    statement_id_ = common.text(data.get("statementId"), max_len=160)
    common.log_access(db, actor, "fees.confirm", statement_id_, now)
    ref = db.collection("feeStatements").document(statement_id_)
    snap = ref.get()
    row = snap.to_dict() if snap.exists else None
    if row is None:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    if row["status"] == "paid":
        return {"status": "paid"}
    if row["status"] not in ("open", "paid_claimed"):
        raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
    coach_uid = row["coachUid"]
    ref.update({"status": "paid", "paidAt": now, "confirmedBy": common.staff_ref(actor)})
    for line in row.get("lines") or []:
        pay_ref = db.collection("payments").document(line["paymentId"])
        pay = pay_ref.get()
        if pay.exists and (pay.to_dict() or {}).get("feeState") == "owed":
            pay_ref.update({"feeState": "settled"})
    still = [s for s in db.collection("feeStatements").where("coachUid", "==", coach_uid).where("status", "in", ["open", "paid_claimed"]).stream()
             if common.as_utc((s.to_dict() or {}).get("dueAt")) and common.as_utc(s.to_dict()["dueAt"]) <= now]
    if not still:
        profile.standing_ref(db, coach_uid).set({"instapayFeeOverdue": False}, merge=True)
        coach_ref = db.collection("coaches").document(coach_uid)
        coach = coach_ref.get()
        if coach.exists and "acceptingBeforeOverdue" in (coach.to_dict() or {}):
            coach_ref.update({"acceptingClients": coach.to_dict()["acceptingBeforeOverdue"], "acceptingBeforeOverdue": None})
    return {"status": "paid"}
```
(At the top of `fees.py`, which so far imports only `datetime`, add `from coaching import common` and `from . import model`. `datetime as dt` is already there from WO-10b2.)
4. File `functions/main.py`. After `coaching_sweeper` (and after `payments_retention` if WO-10a3 is done) add:
```python
@scheduler_fn.on_schedule(schedule="every 1 hours", region=config.REGION)
def expire_payments(event: scheduler_fn.ScheduledEvent) -> None:
    """Hourly: unpaid requests expire (24 hours), the 12 hour reminder, a coach's
    address change coming due, fee statements 30 days late. Runs with the kill switch off."""
    from payments import sweep

    try:
        sweep.expire_pass(store.db(), now=_coaching_now(), notify=_payments_notify)
    except Exception:
        logs.error("payments_expire_failed")


@scheduler_fn.on_schedule(schedule="every 30 minutes", region=config.REGION)
def escalate_silent_payments(event: scheduler_fn.ScheduledEvent) -> None:
    """The 48 and 72 hour rules, amber access, refund and report silences, bounded access ending."""
    from payments import escalate

    try:
        escalate.escalate_pass(store.db(), now=_coaching_now(), notify=_payments_notify)
    except Exception:
        logs.error("payments_escalate_failed")


@scheduler_fn.on_schedule(schedule="0 6 1 * *", timezone=scheduler_fn.Timezone("Africa/Cairo"), region=config.REGION)
def generate_fee_statements(event: scheduler_fn.ScheduledEvent) -> None:
    """The 1st of each month, 06:00 Cairo: last month's fee statement for each coach."""
    from payments import fees

    try:
        fees.generate(store.db(), now=_coaching_now(), notify=_payments_notify)
    except Exception:
        logs.error("payments_statements_failed")


@https_fn.on_call()
def record_fee_payment(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import fees

    return _coaching_call(fees.record_payment, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now())


@https_fn.on_call()
def list_fee_statements(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from payments import fees

    return _coaching_call(fees.list_statements, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def confirm_fee_payment(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from payments import fees

    return _coaching_call(fees.confirm_payment, store.db(), actor, data, now=_coaching_now())
```
5. File `functions/tests/test_entrypoints.py`: add `"record_fee_payment", "confirm_fee_payment", "list_fee_statements",` to `CALLABLES`; the parametrized unauthenticated and App Check tests run on them.
6. File `functions/tests/test_payments_scheduled.py`, create (fixed clock; `seed_world(db)`; payments via `make_payment`; `notes = Notes()`; the pass is called with `now=...`):
| test | arrange, act, assert |
|---|---|
| `test_unpaid_requests_expire_after_24_hours_and_keep_the_late_window` | payment `awaiting_payment`, `expiresAt NOW+24h`; `expire_pass(now=NOW+25h)` -> `expired`, event `awaiting_payment->expired (system)`, no push, lock untouched; then a proof within 7 days is still accepted (call `proof.submit` at NOW+3 days: not refused) |
| `test_a_request_not_yet_due_is_left_alone` | now `NOW+23h` -> still `awaiting_payment` |
| `test_the_12_hour_reminder_is_sent_once` | `NOW+13h`: push `instapayReminder`, `reminded12h True`; a second pass sends nothing |
| `test_a_pending_address_comes_due_exactly_once` | profile pending effective at `NOW+1h`; pass at `NOW+2h` -> `address` replaced, `pending None`; before that nothing |
| `test_at_48_hours_the_coach_is_reminded_and_a_silent_amber_gets_bounded_access` | `proof_submitted`, `proofSubmittedAt NOW`, outcome amber, no access; `escalate_pass(now=NOW+49h)` -> push `instapayCoachReminder` to the coach, `reminded48h True`, subscription `active` with `provisionalUntil == NOW+49h+7d`, fee owed; second pass nothing |
| `test_at_72_hours_it_goes_to_review_and_the_client_stays_protected` | `NOW+73h` -> `in_review`, `dispute.kind == "coach_silent"`, access `provisional` with `until None`, subscription active; pushes `instapayReviewStarted` to the client and `instapayDisputeOpened` to the coach |
| `test_a_green_payment_keeps_its_access_through_the_escalation` | green with provisional access: at 73h `in_review`, `access.until None`, no second grant (coach `activeClients` still 1) |
| `test_amber_with_no_objection_for_24_hours_gives_access` | `amberUntil NOW+24h`, pass at `NOW+25h` -> access provisional; an amber the coach already marked `coach_not_received` is not touched (status differs) |
| `test_nothing_happens_before_48_hours` | pass at `NOW+47h` -> unchanged |
| `test_a_coach_report_unanswered_for_72_hours_goes_to_review` | `awaiting_payment` with `coachReport.reportedAt NOW`; pass at `NOW+73h` -> `in_review`, `dispute.kind == "coach_report"`, `clientAnswer` carried; at 71h nothing; also from `expired` |
| `test_a_different_amount_unanswered_for_72_hours_goes_to_review` | `different_amount` with `statusAt NOW` -> `in_review` at 73h |
| `test_a_refund_request_unanswered_for_3_days_goes_to_review` | `refund_requested`, `refund.coachDueAt NOW+3d`; at `NOW+3d+1h` -> `in_review`, `dispute.kind "refund"`, pushes to both; at 2 days nothing |
| `test_bounded_access_ends_when_its_time_runs_out_unless_paid_or_held_by_silence` | `access {provisional, until NOW+7d}` and subscription active: at `NOW+8d` -> access `none`, subscription `ended_early` (`endReason dispute`), place freed; the same payment with status `confirmed` is untouched; with `until None` untouched |
| `test_one_day_before_the_end_the_client_is_warned_once` | at `NOW+6.5d` -> push `instapayAccessEndsSoon`, `warned True`; again nothing |
| `test_the_pass_is_safe_when_a_client_acts_at_the_same_moment` | set the payment `confirmed`, then call `escalate._run(db, PAY, NOW + 73h, notes, escalate.rule_proof)` directly (as if the query had found it earlier); it returns `False` and changes nothing |
| `test_every_move_writes_an_event_with_the_system_role` | events of the 72 hour test end with `("proof_submitted","in_review","system")` |
| `test_scheduled_jobs_run_with_the_kill_switch_off` | no `config/payments` document: all passes still work |
7. File `functions/tests/test_payments_fees.py`, create:
| test | arrange, act, assert |
|---|---|
| `test_build_lines_counts_owed_lists_disputed_and_ignores_waived` | pure: rows with fee states owed (7500), disputed (3000), settled (1000), waived (500) -> `totalDuePiasters 7500`, `disputedPiasters 3000`, `settledPiasters 1000`, `waivedPiasters 500`, four lines in order of `feeOwedAt` |
| `test_month_bounds_follow_cairo_time` | `month_bounds(2026, 10)` -> start is `2026-09-30T21:00Z`, end `2026-10-31T22:00Z`? Compute with zoneinfo and assert the start equals `dt.datetime(2026,10,1,tzinfo=CAIRO).astimezone(utc)`, end likewise for Nov 1; a payment at `2026-10-31T22:30Z` falls in November; December rolls to January of the next year; `previous_month` of `2026-11-01T05:00Z` is `(2026, 10)` and of `2027-01-01T05:00Z` is `(2026, 12)` |
| `test_the_first_of_the_month_makes_one_statement_per_coach_with_fees` | three payments of COACH with `feeOwedAt` in October and one in September, one other coach with none; `fees.generate(now=2026-11-01 06:00 Cairo)` -> one statement id `coach-uid-1__2026-10`, totals right, `status open`, `dueAt == generatedAt + 30 days`, `payTo` copied from `coachingConfig/receivingAccounts.instapay`, push `instapayStatementReady`; a second run makes none |
| `test_a_disputed_fee_is_listed_pending_and_not_counted` | one payment `feeState disputed` -> in `disputedPiasters`, not in `totalDuePiasters` |
| `test_the_coach_marks_the_fee_paid_once_and_the_number_is_unique` | `record_payment(... txnNumber="FEE1234567890")` -> `paid_claimed`; repeat same -> same answer; another statement with the same number -> `TXN_REUSED`; another coach's statement -> `PAYMENT_NOT_FOUND`; short number -> `bad_request`; a non-coach -> `not_a_coach` |
| `test_the_overview_lists_statements_newest_first_with_a_status_filter_and_no_lines` | three statements; `list_statements` -> three items newest first; `status="paid"` -> one; no `lines` key; page of 25 with `next`; a bad status -> `bad_request`; the read is logged |
| `test_the_owner_confirms_and_the_lines_settle` | `confirm_payment` -> `paid`, `feeState` of owed lines `settled`, disputed lines unchanged, access log line written; repeat -> `paid`; unknown id -> `PAYMENT_NOT_FOUND` |
| `test_30_days_late_means_no_new_clients_but_existing_ones_stay` | statement open with `dueAt NOW-1d`; `sweep.expire_pass` -> `paymentStanding.feeOverdue True`, `coaches.acceptingClients False`, `acceptingBeforeOverdue True`, push `instapayFeeOverdue` once; an active subscription of hers is untouched; `subscriptions.request` for a new client is refused `coach_unavailable` |
| `test_paying_restores_acceptance_to_what_it_was` | continue: `confirm_payment` -> `instapayFeeOverdue False`, `acceptingClients True`; a coach who had set `acceptingClients False` herself stays False (`acceptingBeforeOverdue False`) |
Command: `cd functions && venv/bin/python -m pytest tests/test_payments_scheduled.py tests/test_payments_fees.py tests/test_entrypoints.py tests/test_payments_proof.py -q`

## Strings to add
None. Push kinds used (WO-10a2): `instapayReminder, instapayCoachReminder, instapayReviewStarted, instapayDisputeOpened, instapayAccessEndsSoon, instapayStatementReady, instapayFeeOverdue`. Open owner decision: when exactly a fee is "30 days late" (this order: 30 days after the statement is made, `LIMITS["feeOverdueDays"]`).

## Tests to add or change
As above.

## Verify
The command ends with `N passed`, no `failed`. After deploy (owner): `gcloud scheduler jobs list --project=own-hub --location=europe-west3 | grep -E "expire_payments|escalate_silent_payments|generate_fee_statements"` shows three jobs (UNVERIFIED job names; the deploy creates them from the function names).

## Do not
- Do not make any pass depend on the kill switch.
- Do not cut off a running coaching because a fee is late.
- Do not debit anyone: the fee is paid by the coach by InstaPay and confirmed by the owner.
- Do not start a pass by reading the payment outside the transaction and acting on it: each rule re-reads.

## Done checklist
- [ ] sweep.py, escalate.py created; fees.py extended
- [ ] three scheduled functions and two callables registered
- [ ] all tests pass

## If stuck
Anchor missing or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to the next work order that does not depend on this one.
