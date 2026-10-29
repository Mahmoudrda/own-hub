"""The coach's confirmation, shared with the automatic confirmation of a GREEN proof."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from google.cloud import firestore

from coaching import common

from . import activation, engine, errors, fees, model, profile, states


def can_grant(seen: dict) -> bool:
    return activation.grantable(seen)


def grant_provisional(transaction, db, ref, pay: dict, seen: dict, cfg: dict, now: dt.datetime) -> dict:
    """Bounded access (13.1): at most `provisionalMaxDays` or the package, the
    fee owed from this moment (13.1), the coaching started or extended by
    `activation.grant`. Used by a GREEN proof and by an AMBER nobody objected
    to. Returns the payment as it now stands. All reads done by the caller."""
    days = min(model.LIMITS["provisionalMaxDays"], (seen["sub"].get("package") or {}).get("durationDays", 7))
    until = now + model.days(days)
    rel_source = fees.source_of(seen)
    changes = {"access": {"state": "provisional", "until": until}, **fees.start(transaction, db, ref, pay, cfg, rel_source, now)}
    transaction.update(ref, changes)
    if can_grant(seen):
        activation.grant(transaction, db, seen, now, provisional_until=until)
    return {**pay, **changes}


def apply_confirmation(transaction, db, ref, cur: dict, seen: dict, prof_ref, prof: dict, cfg: dict,
                       now: dt.datetime, role: str, actor_uid: Optional[str], received: Optional[int]) -> dict:
    """proof_submitted -> confirmed, full access, fee owed (if not already),
    the coach's counters. All reads were done by the caller. Returns the payment."""
    rel_source = fees.source_of(seen)
    got = received if received is not None else cur["amountPiasters"]
    starts = can_grant(seen)  # false when the acceptance is gone: the money is confirmed, the coaching is for staff to restore
    changes = {
        "coachDecision": {**(cur.get("coachDecision") or {}), "confirmedAt": now, "receivedPiasters": got, "autoConfirmed": role == states.SYSTEM},
        "overpaidPiasters": max(0, got - cur["amountPiasters"]),
        "access": {"state": "full" if starts else "none", "until": None},
        **fees.start(transaction, db, ref, cur, cfg, rel_source, now),
    }
    out = engine.move(transaction, db, ref, cur, "confirmed", role, actor_uid, now, changes=changes,
                      code="auto_confirmed" if role == states.SYSTEM else "coach_confirmed")
    if starts:
        activation.grant(transaction, db, seen, now)
    clean = 1 if (cur.get("outcome") == "green" and not cur.get("dispute")) else 0
    transaction.update(prof_ref, {"paymentsConfirmed": firestore.Increment(1), "cleanConfirmed": firestore.Increment(clean)})
    return out


def confirm(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v, allow_hold=True)  # protects her clients, so it works on hold
    payment_id = common.text(data.get("paymentId"), max_len=128)
    received = data.get("receivedPiasters")
    if received is not None:
        received = common.whole(received, low=1, high=10_000_000)
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] == "confirmed":
            return {"status": "confirmed"}  # a second tap changes nothing
        if received is not None and received < cur["amountPiasters"]:
            raise common.bad()  # a lower amount goes through coach_mark_different_amount
        seen = activation.read_for_start(transaction, db, cur["subId"])
        prof_ref = profile.profile_ref(db, uid)
        prof = common.read(prof_ref, transaction) or {}
        held["payment"], held["from"] = cur, cur["status"]
        apply_confirmation(transaction, db, ref, cur, seen, prof_ref, prof, cfg, now, states.COACH, uid, received)
        return {"status": "confirmed"}

    result = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "confirmed")])
    return result


def set_auto_confirm(db, uid: str, data: dict, *, coach_v, now: dt.datetime) -> dict:
    """The coach turns confirming green payments by themselves on or off. On needs
    the owner's switch (model.config autoConfirmAllowed, off by default) and 3
    clean payments (13.4). Off is always allowed."""
    common.require_active_coach(db, uid, coach_v)
    enabled = data.get("enabled")
    if not isinstance(enabled, bool):
        raise common.bad()
    if enabled and not model.config(db)["autoConfirmAllowed"]:
        raise common.refuse(errors.PRECONDITION, errors.AUTO_CONFIRM_OFF)  # the owner has not turned it on (coachingConfig/instapay)
    ref = profile.profile_ref(db, uid)

    def body(transaction):
        row = common.read(ref, transaction)
        if row is None:
            raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
        if enabled and row.get("cleanConfirmed", 0) < model.LIMITS["cleanPaymentsForAutoConfirm"]:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        transaction.update(ref, {"autoConfirmGreen": enabled})
        return {"autoConfirmGreen": enabled}

    return common.run(db, body)

