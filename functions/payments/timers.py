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

from . import engine, model, states

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
