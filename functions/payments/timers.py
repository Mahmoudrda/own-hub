"""The clock side of the state machine (spec 4.1, 4.5, 4.7, 4.8).

A party who stays silent must not leave a payment stuck. `engine.move` stamps
`escalateAt` when a payment enters a waiting state; everything here reads it.
The scheduled functions are separate work: they call `sweep` (or the pieces)
and are the only callers that need a clock. Staff reach the same move through
`staff.resolve`, so a queued payment can be decided before the schedule runs.
"""

from __future__ import annotations

import datetime as dt
from typing import Optional

from coaching import common

from . import activation, coach, engine, fees, model, states

TERMINAL_FOR_TIMERS = ("confirmed", "resolved_paid", "resolved_unpaid", "cancelled", "refunded", "refund_denied")


def due(db, now: dt.datetime) -> list[str]:
    """Ids of payments whose silent party has run out of time (escalateAt passed)."""
    return [s.id for s in db.collection("payments").where("escalateAt", "<=", now).stream()]


def overdue(payment: dict, now: dt.datetime) -> bool:
    when = common.as_utc(payment.get("escalateAt"))
    return when is not None and when <= now and payment.get("status") not in TERMINAL_FOR_TIMERS + ("in_review",)


def escalate_move(transaction, db, ref, payment: dict, now: dt.datetime) -> dict:
    """The system sends an overdue payment to staff (inside the caller's
    transaction, reads already done). Returns the payment as it now stands."""
    return engine.move(
        transaction, db, ref, payment, "in_review", states.SYSTEM, None, now,
        changes={"dispute": {**(payment.get("dispute") or {}), "kind": f"silent_{payment['status']}", "openedBy": "system", "openedAt": now}},
        code="escalated_silent",
    )


def escalate(db, payment_id: str, now: dt.datetime, notify) -> bool:
    """One overdue payment to staff; False when it is not overdue (any more)."""
    held = {}

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        if not overdue(cur, now):
            return False
        held["from"] = cur["status"]
        held["payment"] = cur
        escalate_move(transaction, db, ref, cur, now)
        return True

    moved = common.run(db, body)
    if moved:
        engine.notify_moves(notify, held["payment"], [(held["from"], "in_review")])
    return moved


def expire(db, payment_id: str, now: dt.datetime) -> Optional[str]:
    """awaiting_payment past its day -> expired; expired past the late-proof
    window -> cancelled (the exit that frees the request). Returns the new
    status, or None when nothing was due."""

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        if cur["status"] == "awaiting_payment" and (common.as_utc(cur.get("expiresAt")) or now) <= now:
            # a coach's "a client paid me" report keeps its clock through the expiry
            engine.move(transaction, db, ref, cur, "expired", states.SYSTEM, None, now, code="expired",
                        changes={"escalateAt": cur.get("escalateAt")})
            return "expired"
        if cur["status"] == "expired" and (common.as_utc(cur.get("lateUntil")) or now) < now:
            engine.move(transaction, db, ref, cur, "cancelled", states.SYSTEM, None, now, code="expired_closed")
            return "cancelled"
        return None

    return common.run(db, body)


def sweep(db, now: dt.datetime, notify) -> dict:
    """One pass: escalate what is overdue, expire what ran out of time."""
    counts = {"escalated": 0, "expired": 0, "cancelled": 0}
    for payment_id in due(db, now):
        counts["escalated"] += bool(escalate(db, payment_id, now, notify))
    waiting = [s.id for s in db.collection("payments").where("status", "==", "awaiting_payment").where("expiresAt", "<=", now).stream()]
    waiting += [s.id for s in db.collection("payments").where("status", "==", "expired").stream()]
    for payment_id in waiting:
        moved = expire(db, payment_id, now)
        if moved:
            counts[moved] += 1
    return counts


# ------------------------------------------------------------------ the rest of the clock
#
# Each rule below re-reads the payment inside its own transaction, so a pass
# that overlaps a party's action does the right thing. Pushes go out after the
# commit. None of these reads the kill switch: open payments must keep moving
# with the switch off.


def _stream(db, field: str, value):
    return [s.id for s in db.collection("payments").where(field, "==", value).stream()]


def remind_client(db, payment_id: str, now: dt.datetime) -> Optional[dict]:
    """Once, 12 hours into the 24 hour request: 'your request is still open'."""

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        expires = common.as_utc(cur.get("expiresAt"))
        if cur["status"] != "awaiting_payment" or cur.get("reminded12h") or expires is None or expires <= now \
                or expires > now + model.hours(model.LIMITS["expiryHours"] - 12):
            return None
        transaction.update(ref, {"reminded12h": True})
        return cur

    return common.run(db, body)


def remind_coach(db, payment_id: str, now: dt.datetime) -> Optional[dict]:
    """Once, 48 hours after a proof she has not answered (4.1)."""

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        sent = common.as_utc(cur.get("proofSubmittedAt"))
        if cur["status"] != "proof_submitted" or cur.get("reminded48h") or sent is None \
                or now < sent + model.hours(model.LIMITS["coachRemindHours"]):
            return None
        transaction.update(ref, {"reminded48h": True})
        return cur

    return common.run(db, body)


def grant_amber(db, payment_id: str, now: dt.datetime, cfg: dict) -> bool:
    """An AMBER proof nobody objected to for 24 hours gives bounded access (13.4)."""

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        until = common.as_utc(cur.get("amberUntil"))
        if cur["status"] != "proof_submitted" or cur.get("outcome") != "amber" or until is None or until > now \
                or (cur.get("access") or {}).get("state") != "none":
            return False
        seen = activation.read_for_start(transaction, db, cur["subId"])
        coach.grant_provisional(transaction, db, ref, cur, seen, cfg, now)
        return True

    return common.run(db, body)


def warn_access(db, payment_id: str, now: dt.datetime) -> Optional[dict]:
    """Once, in the last day of bounded access that is not yet a paid one."""

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        access = cur.get("access") or {}
        until = common.as_utc(access.get("until"))
        if access.get("state") != "provisional" or cur["status"] in model.PAID_STATUSES or cur.get("warned") \
                or until is None or not (now < until <= now + model.days(1)):
            return None
        transaction.update(ref, {"warned": True})
        return cur

    return common.run(db, body)


def lapse_access(db, payment_id: str, now: dt.datetime) -> bool:
    """Bounded access that ran out: the payment stops saying 'provisional'. Only
    the payment field changes. The hourly sweeper ends the subscription at its
    own `endsAt` and keeps `provisionalUntil`, which is what lets a later paid
    decision restart the coaching (`activation.lapsed`)."""

    def body(transaction):
        ref, cur = engine.load(transaction, db, payment_id)
        access = cur.get("access") or {}
        until = common.as_utc(access.get("until"))
        if access.get("state") != "provisional" or until is None or until > now or cur["status"] in model.PAID_STATUSES:
            return False
        transaction.update(ref, {"access": {"state": "none", "until": None}})
        return True

    return common.run(db, body)


def promote_addresses(db, now: dt.datetime) -> int:
    """A coach's new address, after its 24 hour delay, becomes her address
    (`profile.effective` already honours it from that moment; this makes the
    stored profile say so)."""
    done = 0
    for snap in list(db.collection("coachPaymentProfiles").where("pending.effectiveAt", "<=", now).stream()):
        def body(transaction, ref=snap.reference):
            row = common.read(ref, transaction) or {}
            pending = row.get("pending") or {}
            when = common.as_utc(pending.get("effectiveAt"))
            if not pending.get("address") or when is None or when > now:
                return False
            transaction.update(ref, {"address": pending["address"], "accountName": pending["accountName"], "pending": None})
            return True

        done += bool(common.run(db, body))
    return done


def _notify(notify, uid: str, kind: str, ref: Optional[str] = None) -> None:
    try:
        notify(uid, kind, ref)
    except Exception:  # noqa: BLE001
        pass


def half_hourly(db, now: dt.datetime, notify) -> dict:
    """The 30 minute pass: silence first, then the coach reminder and AMBER access."""
    counts = {**sweep(db, now, notify), "coachReminded": 0, "amberGranted": 0}
    cfg = model.config(db)
    for payment_id in _stream(db, "status", "proof_submitted"):
        row = remind_coach(db, payment_id, now)
        if row:
            _notify(notify, row["coachUid"], "instapayCoachReminder", payment_id)
            counts["coachReminded"] += 1
        counts["amberGranted"] += bool(grant_amber(db, payment_id, now, cfg))
    return counts


def hourly(db, now: dt.datetime, notify) -> dict:
    """The hourly pass: expiry and silence, the client reminder, bounded access
    running out, a coach's address coming due, late fee statements."""
    counts = {**sweep(db, now, notify), "clientReminded": 0, "accessWarned": 0, "accessLapsed": 0}
    soon = db.collection("payments").where("status", "==", "awaiting_payment").where("expiresAt", "<=", now + model.hours(12))
    for snap in list(soon.stream()):
        row = remind_client(db, snap.id, now)
        if row:
            _notify(notify, row["clientUid"], "instapayReminder", snap.id)
            counts["clientReminded"] += 1
    for payment_id in [s.id for s in db.collection("payments").where("access.state", "==", "provisional").stream()]:
        if lapse_access(db, payment_id, now):
            counts["accessLapsed"] += 1
            continue
        row = warn_access(db, payment_id, now)
        if row:
            _notify(notify, row["clientUid"], "instapayAccessEndsSoon", payment_id)
            counts["accessWarned"] += 1
    counts["addresses"] = promote_addresses(db, now)
    counts["feesOverdue"] = fees.mark_overdue(db, now=now, notify=notify)
    return counts
