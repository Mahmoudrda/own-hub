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
    """Every read `grant` needs. Call before any write. A subscription the
    sweeper ended at its provisional limit is only restarted when the coaching
    could be opened today (`restartable`): the coach has a place free, nobody
    blocked anybody, and no other subscription of the pair is open."""
    sub_ref = db.collection("subscriptions").document(sub_id)
    sub = common.read(sub_ref, transaction) or {}
    coach_ref = db.collection("coaches").document(sub.get("coachUid", "none"))
    rel_ref = db.collection("relationships").document(sub.get("relId", "none"))
    seen = {"subRef": sub_ref, "sub": sub, "coachRef": coach_ref, "coach": coach_ref.get(transaction=transaction),
            "rel": rel_ref.get(transaction=transaction)}
    seen["held"] = bool((common.read(db.collection("coachPrivate").document(sub.get("coachUid", "none")), transaction) or {}).get("hold"))
    if lapsed(sub):
        seen["restartable"] = _restartable(transaction, db, sub_id, sub, seen)
    return seen


def _restartable(transaction, db, sub_id: str, sub: dict, seen: dict) -> bool:
    coach = seen["coach"].to_dict() if seen["coach"].exists else None
    if coach is None or coach.get("activeClients", 0) >= coach.get("maxActiveClients", common.LIMITS["maxActiveClientsDefault"]):
        return False
    if subscriptions.blocked_either(transaction, db, sub["coachUid"], sub["clientUid"]):
        return False
    rel = seen["rel"].to_dict() if seen["rel"].exists else {}
    if rel.get("status") == "active" and rel.get("activeSubId") not in (None, sub_id):
        return False
    pair = (db.collection("subscriptions").where("clientUid", "==", sub["clientUid"]).where("coachUid", "==", sub["coachUid"])
            .where("status", "in", list(subscriptions.OPEN)))
    return not any(snap.id != sub_id for snap in pair.stream(transaction=transaction))


def lapsed(sub: dict) -> bool:
    """A subscription the sweeper ended when its provisional access ran out
    with the payment still unconfirmed. `provisionalUntil` stays set on it."""
    return sub.get("status") == "ended" and sub.get("provisionalUntil") is not None


def grantable(seen: dict) -> bool:
    """Whether a confirmation can still start (or restart) the coaching. `seen`
    is what `read_for_start` returned."""
    sub = seen.get("sub") or {}
    return sub.get("status") in ("awaiting_payment", "active") or (lapsed(sub) and seen.get("restartable") is True)


def grant(transaction, db, seen: dict, now: dt.datetime, *, provisional_until: Optional[dt.datetime] = None) -> str:
    """Makes the subscription `active`. With `provisional_until` the access is
    short: `endsAt` is that moment (so every check of the coaching's end, the
    hourly sweeper first, enforces it) and `provisionalUntil` says why. Without
    it the access is the whole package. A later full grant on a running
    provisional subscription extends it to the package length; on one the
    sweeper ended at the provisional limit it starts the coaching again.
    Returns 'started', 'upgraded' or 'unchanged'."""
    sub, sub_ref = seen["sub"], seen["subRef"]
    payment = dict(sub.get("payment") or {})
    package = sub.get("package") or {}
    if sub.get("status") == "active":
        if provisional_until is None and sub.get("provisionalUntil"):
            began = common.as_utc(sub.get("startsAt")) or now
            credit = dt.timedelta(seconds=int(sub.get("holdCreditSeconds") or 0))  # days given back after a fee hold
            transaction.update(sub_ref, {"provisionalUntil": None, "endsAt": began + common.days(package["durationDays"]) + credit,
                                         "payment": {**payment, "state": "approved"}})
            return "upgraded"
        return "unchanged"
    if sub.get("status") != "awaiting_payment" and not grantable(seen):
        raise common.refuse(coaching_errors.PRECONDITION, coaching_errors.WRONG_STATUS)
    full_end = now + common.days(package["durationDays"])
    ends = min(provisional_until, full_end) if provisional_until else full_end
    transaction.update(
        sub_ref,
        {
            "status": "active",
            "startsAt": now,
            "endsAt": ends,
            "provisionalUntil": ends if provisional_until else None,
            "payment": {**payment, "state": "review" if provisional_until else "approved"},
            "statusAt": now,
        },
    )
    subscriptions.begin(
        transaction, db, sub_id=sub_ref.id, coach_uid=sub["coachUid"], client_uid=sub["clientUid"],
        rel_id=sub["relId"], rel=seen["rel"], coach_ref=seen["coachRef"], coach=seen["coach"], now=now, source=sub.get("source"), held=seen.get("held", False),
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
