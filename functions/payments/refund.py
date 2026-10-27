"""Refunds and service disputes (spec 4.8, 4.9, 4.12)."""

from __future__ import annotations

import datetime as dt

from google.cloud import firestore

from coaching import common

from . import activation, engine, errors, fees, model, profile, proof, states

LIMITS = model.LIMITS
PAID = model.PAID_STATUSES


def started_at(row: dict) -> dt.datetime:
    """When access began: the coach's confirmation, or the staff decision, or the last change."""
    return (common.as_utc((row.get("coachDecision") or {}).get("confirmedAt"))
            or common.as_utc((row.get("dispute") or {}).get("decidedAt"))
            or common.as_utc(row.get("statusAt")))


def request(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if (cur.get("refund") or {}).get("requestedAt"):
            if cur["status"] == "refund_requested":
                return {"status": "refund_requested"}  # a second tap
            raise common.refuse(errors.PRECONDITION, errors.REFUND_ALREADY_REQUESTED)
        if cur["status"] not in PAID:
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        if now > started_at(cur) + model.days(LIMITS["refundWindowDays"]):
            raise common.refuse(errors.PRECONDITION, errors.REFUND_WINDOW_CLOSED)
        held["payment"], held["from"] = cur, cur["status"]
        engine.move(transaction, db, ref, cur, "refund_requested", states.CLIENT, uid, now, code="refund_requested",
                    changes={"refund": {"requestedAt": now, "coachDueAt": now + model.days(LIMITS["refundCoachDays"])}})
        return {"status": "refund_requested"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "refund_requested")])
    return out


def deny(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    reason = common.one_of(data.get("reasonCode"), ("sessions_delivered", "outside_terms", "other"))
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if cur["status"] == "refund_denied":
            return {"status": "refund_denied"}
        held["payment"] = cur
        engine.move(transaction, db, ref, cur, "refund_denied", states.COACH, uid, now, code=f"refund_denied_{reason}",
                    changes={"refund.deniedAt": now, "refund.deniedReason": reason})
        return {"status": "refund_denied"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [("refund_requested", "refund_denied")])
    return out


def record(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    """The coach sent money back by InstaPay and writes it down. Own Hub moves nothing."""
    common.require_active_coach(db, uid, coach_v)
    payment_id = common.text(data.get("paymentId"), max_len=128)
    txn = common.text(data.get("txnNumber"), max_len=40)
    if len(proof.txn_key(txn)) < 6:
        raise common.bad()
    amount = common.whole(data.get("amountPiasters"), low=1, high=10_000_000)
    kind = common.one_of(data.get("kind"), ("refund", "overpayment"))
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if (cur.get("refund") or {}).get("recordedAt") and kind == "refund":
            return {"status": cur["status"]}  # already recorded
        if kind == "overpayment":
            if cur["status"] not in PAID or amount > cur.get("overpaidPiasters", 0):
                raise common.bad()
            transaction.update(ref, {"refund.overpayment": {"txnNumber": txn, "amountPiasters": amount, "recordedAt": now}})
            return {"status": cur["status"]}
        if amount > cur["amountPiasters"]:
            raise common.bad()
        if cur["status"] == "in_review" and (cur.get("dispute") or {}).get("staffDecision") != "refund_owed":
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        seen = activation.read_for_end(transaction, db, cur["subId"])
        rel_source = None
        got = (cur.get("coachDecision") or {}).get("receivedPiasters", cur["amountPiasters"])
        held["payment"], held["from"] = cur, cur["status"]
        changes = {"refund": {**(cur.get("refund") or {}), "txnNumber": txn, "amountPiasters": amount, "recordedAt": now,
                              "partial": amount < got},
                   "access": {"state": "none", "until": None}, **fees.recompute(cur, max(0, got - amount), cfg, rel_source)}
        engine.move(transaction, db, ref, cur, "refunded", states.COACH, uid, now, changes=changes, code="refund_recorded")
        activation.end(transaction, db, cur["subId"], seen, "refund", now)  # a package ends when a refund is recorded
        return {"status": "refunded"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "refunded")])
    return out


def open_service_dispute(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    payment_id = common.text(data.get("paymentId"), max_len=128)
    note = common.optional_text(data.get("note"), max_len=model.LIMITS.get("noteMax", 500))
    month = f"disputes_{now:%Y%m}"
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.CLIENT)
        if cur["status"] == "in_review" and (cur.get("dispute") or {}).get("openedBy") == "client":
            return {"status": "in_review"}  # a second tap
        standing_ref = profile.standing_ref(db, uid)
        standing = common.read(standing_ref, transaction) or {}
        if cur["status"] not in PAID + ("refund_denied",):
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        if standing.get(month, 0) >= LIMITS["disputesPerMonth"]:
            raise common.refuse(errors.EXHAUSTED, errors.DISPUTE_LIMIT)
        sub = common.read(db.collection("subscriptions").document(cur["subId"]), transaction) or {}
        kind = "refund" if cur["status"] == "refund_denied" else "service"
        facts = {"sessionsUsed": sub.get("sessionsUsed", 0), "sessionsIncluded": sub.get("sessionsIncluded", 0)}
        held["payment"], held["from"] = cur, cur["status"]
        pay = cur
        if kind == "service":
            pay = engine.move(transaction, db, ref, cur, "service_dispute", states.CLIENT, uid, now, code="service_dispute")
        engine.move(transaction, db, ref, pay, "in_review", states.CLIENT if kind == "refund" else states.SYSTEM, uid if kind == "refund" else None, now,
                    code="dispute_in_review",
                    changes={"dispute": {"kind": kind, "openedBy": "client", "openedAt": now, "serviceFacts": facts, "clientNote": note}})
        transaction.set(standing_ref, {month: firestore.Increment(1)}, merge=True)
        held["moves"] = [(cur["status"], "service_dispute"), ("service_dispute", "in_review")] if kind == "service" else [("refund_denied", "in_review")]
        return {"status": "in_review"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], held["moves"])
    return out
