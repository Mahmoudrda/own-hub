"""Starting and ending the coaching that a payment pays for. Reuses the routine
free coaching and the old proof flow already use (`subscriptions.begin`,
`subscriptions.write_ending`), so the relationship, the coach's place counter
and the chat line behave the same."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from coaching import common, subscriptions
from coaching import errors as coaching_errors


def read_for_start(transaction, db, sub_id: str) -> dict:
    """Every read `grant` needs. Call before any write."""
    sub_ref = db.collection("subscriptions").document(sub_id)
    sub = common.read(sub_ref, transaction) or {}
    coach_ref = db.collection("coaches").document(sub.get("coachUid", "none"))
    rel_ref = db.collection("relationships").document(sub.get("relId", "none"))
    return {"subRef": sub_ref, "sub": sub, "coachRef": coach_ref, "coach": coach_ref.get(transaction=transaction),
            "rel": rel_ref.get(transaction=transaction)}


def grant(transaction, db, seen: dict, now: dt.datetime, *, provisional_until: Optional[dt.datetime] = None) -> str:
    """Makes the subscription `active`. With `provisional_until` the access is
    short and says so on the subscription (`provisionalUntil`); without it the
    access is full. Calling it again on a running subscription only upgrades a
    provisional one to full. Returns 'started', 'upgraded' or 'unchanged'."""
    sub, sub_ref = seen["sub"], seen["subRef"]
    payment = dict(sub.get("payment") or {})
    if sub.get("status") == "active":
        if provisional_until is None and sub.get("provisionalUntil"):
            transaction.update(sub_ref, {"provisionalUntil": None, "payment": {**payment, "state": "approved"}})
            return "upgraded"
        return "unchanged"
    if sub.get("status") != "awaiting_payment":
        raise common.refuse(coaching_errors.PRECONDITION, coaching_errors.WRONG_STATUS)
    package = sub.get("package") or {}
    transaction.update(
        sub_ref,
        {
            "status": "active",
            "startsAt": now,
            "endsAt": now + common.days(package["durationDays"]),
            "provisionalUntil": provisional_until,
            "payment": {**payment, "state": "review" if provisional_until else "approved"},
            "statusAt": now,
        },
    )
    subscriptions.begin(
        transaction, db, sub_id=sub_ref.id, coach_uid=sub["coachUid"], client_uid=sub["clientUid"],
        rel_id=sub["relId"], rel=seen["rel"], coach_ref=seen["coachRef"], coach=seen["coach"], now=now,
    )
    return "started"


def read_for_end(transaction, db, sub_id: str) -> dict:
    sub = common.read(db.collection("subscriptions").document(sub_id), transaction) or {}
    return {"sub": sub, "seen": subscriptions.read_ending(transaction, db, sub_id, sub, money=False) if sub else None}


def end(transaction, db, sub_id: str, read: dict, reason: str, now: dt.datetime) -> bool:
    """Ends a running subscription (`ended_early`, `reason` from the contract's
    endReasons: 'refund' or 'dispute'). Does nothing when it is not running."""
    sub = read["sub"]
    if sub.get("status") != "active":
        return False
    subscriptions.write_ending(
        transaction, db, sub_id, sub, read["seen"],
        changes={"status": "ended_early", "endReason": reason, "provisionalUntil": None, "statusAt": now}, now=now,
    )
    return True
