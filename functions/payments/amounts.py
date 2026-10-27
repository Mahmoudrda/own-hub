"""A different amount (spec 4.3)."""

from __future__ import annotations

import datetime as dt

from coaching import common

from . import activation, coach, engine, errors, fees, model, profile, states


def mark(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    """The coach received less than the amount. She may accept it in writing
    (acceptLower); the package never starts on a partial payment otherwise."""
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    received = common.whole(data.get("receivedPiasters"), low=1, high=10_000_000)
    accept = data.get("acceptLower")
    if not isinstance(accept, bool):
        raise common.bad()
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] == "different_amount":
            return {"status": "different_amount"}
        if received >= cur["amountPiasters"]:
            raise common.bad()  # more or equal: she just confirms (with receivedPiasters)
        held["payment"] = cur
        engine.move(transaction, db, ref, cur, "different_amount", states.COACH, uid, now, code="different_amount",
                    changes={"coachDecision": {"differentAmountPiasters": received, "acceptLower": accept, "decidedAt": now}})
        return {"status": "different_amount"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [("proof_submitted", "different_amount")])
    return out


def respond(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    decision = common.one_of(data.get("decision"), ("agree", "dispute"))
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        lower = cur.get("coachDecision") or {}
        if cur["status"] == "confirmed" and decision == "agree":
            return {"status": "confirmed"}
        held["payment"] = cur
        if decision == "dispute":
            engine.move(transaction, db, ref, cur, "in_review", states.CLIENT, uid, now, code="client_disputes_amount",
                        changes={"dispute": {"kind": "different_amount", "openedBy": "client", "openedAt": now}})
            held["to"] = "in_review"
            return {"status": "in_review"}
        if lower.get("acceptLower") is not True:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        seen = activation.read_for_start(transaction, db, cur["subId"])
        prof_ref = profile.profile_ref(db, cur["coachUid"])
        prof = common.read(prof_ref, transaction) or {}
        rel_source = (seen["rel"].to_dict() or {}).get("source") if seen["rel"].exists else None
        out = coach.apply_confirmation(transaction, db, ref, cur, seen, prof_ref, prof, cfg, now, states.CLIENT, uid,
                                       lower["differentAmountPiasters"])
        transaction.update(ref, fees.recompute(out, lower["differentAmountPiasters"], cfg, rel_source))
        held["to"] = "confirmed"
        return {"status": "confirmed"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [("different_amount", held["to"])])
    return out
