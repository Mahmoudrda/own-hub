"""Refunds and service disputes (spec 4.8, 4.9, 4.12)."""

from __future__ import annotations

import datetime as dt
import re

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
    common.require_active_coach(db, uid, coach_v, allow_hold=True)  # protects her clients, so it works on hold
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


_REFUND_TXN = re.compile(r"\d{10,20}")


def _paid_at(value, earliest: dt.datetime, now: dt.datetime) -> dt.datetime:
    """The time the coach says she sent the money back: ISO text, between the
    moment the refund became due and now (a few minutes of slack for phone clocks)."""
    try:
        moment = dt.datetime.fromisoformat(value.replace("Z", "+00:00")) if isinstance(value, str) else None
    except ValueError:
        moment = None
    slack = dt.timedelta(minutes=LIMITS["refundPaidSlackMinutes"])
    moment = common.as_utc(moment)
    if moment is None or not (earliest - slack <= moment <= now + slack):
        raise common.refuse(errors.INVALID, errors.REFUND_PAID_AT_INVALID)
    return moment


def record(db, uid: str, data: dict, *, coach_v, now: dt.datetime, notify) -> dict:
    """The coach sent money back by InstaPay and writes it down: the bank's
    transaction number (digits, never used before), the amount and the time. Own
    Hub moves nothing and cannot see it, so the record is her word: the client
    can answer it with open_service_dispute (staff decide), and a refund that
    staff ordered must be at least the amount they named."""
    common.require_active_coach(db, uid, coach_v, allow_hold=True)  # protects her clients, so it works on hold
    payment_id = common.text(data.get("paymentId"), max_len=128)
    txn = common.text(data.get("txnNumber"), max_len=40)
    key = proof.txn_key(txn)
    if not _REFUND_TXN.fullmatch(key) or not (LIMITS["refundTxnMinDigits"] <= len(key) <= LIMITS["refundTxnMaxDigits"]):
        raise common.refuse(errors.INVALID, errors.REFUND_TXN_INVALID)
    amount = common.whole(data.get("amountPiasters"), low=1, high=10_000_000)
    kind = common.one_of(data.get("kind"), ("refund", "overpayment"))
    cfg = model.config(db)
    held = {}

    def body(transaction):
        ref, cur = engine.load_for_party(transaction, db, payment_id, uid, states.COACH)
        if (cur.get("refund") or {}).get("recordedAt") and kind == "refund" and cur["status"] == "refunded":
            return {"status": cur["status"]}  # already recorded
        reg_ref = db.collection("paymentTxnNumbers").document(key)
        reg = reg_ref.get(transaction=transaction)
        used_before = reg.exists and (reg.to_dict() or {}).get("paymentId") != payment_id
        if used_before or key == (cur.get("proof") or {}).get("txnKey") or key == (cur.get("refund") or {}).get("txnKey"):
            raise common.refuse(errors.PRECONDITION, errors.TXN_REUSED)
        if kind == "overpayment":
            if cur["status"] not in PAID or amount > cur.get("overpaidPiasters", 0):
                raise common.bad()
            paid_at = _paid_at(data.get("paidAt"), common.as_utc(cur.get("createdAt")) or now, now)
            transaction.set(reg_ref, {"paymentId": payment_id, "kind": "overpayment", "createdAt": now})
            transaction.update(ref, {"refund.overpayment": {"txnNumber": txn, "amountPiasters": amount, "paidAt": paid_at, "recordedAt": now}})
            return {"status": cur["status"]}
        if amount > cur["amountPiasters"]:
            raise common.bad()
        dispute = cur.get("dispute") or {}
        if cur["status"] == "in_review":
            if dispute.get("staffDecision") != "refund_owed":
                raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
            if amount < dispute.get("refundOwedPiasters", 0):
                raise common.bad()
        seen = activation.read_for_end(transaction, db, cur["subId"])
        due_from = (common.as_utc(dispute.get("decidedAt")) if cur["status"] == "in_review"
                    else common.as_utc((cur.get("refund") or {}).get("requestedAt"))) or common.as_utc(cur.get("statusAt")) or now
        paid_at = _paid_at(data.get("paidAt"), due_from, now)
        rel_source = None
        got = (cur.get("coachDecision") or {}).get("receivedPiasters", cur["amountPiasters"])
        held["payment"], held["from"] = cur, cur["status"]
        changes = {"refund": {**(cur.get("refund") or {}), "txnNumber": txn, "txnKey": key, "amountPiasters": amount,
                              "paidAt": paid_at, "recordedAt": now, "partial": amount < got},
                   "access": {"state": "none", "until": None}, **fees.recompute(cur, max(0, got - amount), cfg, rel_source)}
        transaction.set(reg_ref, {"paymentId": payment_id, "kind": "refund", "createdAt": now})
        engine.move(transaction, db, ref, cur, "refunded", states.COACH, uid, now, changes=changes, code="refund_recorded")
        activation.end(transaction, db, cur["subId"], seen, "refund", now)  # a package ends when a refund is recorded
        return {"status": "refunded"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], [(held["from"], "refunded")])
        fees.refresh(db, payment_id, now, notify=notify)  # a refund lowers or closes the bill
    return out


def open_service_dispute(db, uid: str, data: dict, *, now: dt.datetime, notify) -> dict:
    """The client raises a problem with a paid package ('service'), a refused
    refund ('refund') or a refund she never received ('refund_not_received').
    Each kind once per payment, inside its window, and at most 3 a month in all.
    Her free-text note goes to staff only (payments/{id}/staff/dispute): the
    coach can read the payment but not that."""
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
        if cur["status"] not in PAID + ("refund_denied", "refunded"):
            raise common.refuse(errors.PRECONDITION, errors.ILLEGAL_TRANSITION)
        kind = {"refund_denied": "refund", "refunded": "refund_not_received"}.get(cur["status"], "service")
        if kind in (cur.get("disputeKinds") or []):
            raise common.refuse(errors.PRECONDITION, errors.DISPUTE_ALREADY_USED)
        sub = common.read(db.collection("subscriptions").document(cur["subId"]), transaction) or {}
        grace = model.days(LIMITS["serviceDisputeGraceDays"])
        if kind == "service":
            length = model.days(int((sub.get("package") or {}).get("durationDays") or 0))
            if now > started_at(cur) + length + grace:
                raise common.refuse(errors.PRECONDITION, errors.DISPUTE_WINDOW_CLOSED)
        elif kind == "refund_not_received":
            recorded = common.as_utc((cur.get("refund") or {}).get("recordedAt")) or started_at(cur)
            if now > recorded + grace:
                raise common.refuse(errors.PRECONDITION, errors.DISPUTE_WINDOW_CLOSED)
        if standing.get(month, 0) >= LIMITS["disputesPerMonth"]:
            raise common.refuse(errors.EXHAUSTED, errors.DISPUTE_LIMIT)
        facts = {"sessionsUsed": sub.get("sessionsUsed", 0), "sessionsIncluded": sub.get("sessionsIncluded", 0)}
        held["payment"], held["from"] = cur, cur["status"]
        pay = cur
        if kind == "service":
            pay = engine.move(transaction, db, ref, cur, "service_dispute", states.CLIENT, uid, now, code="service_dispute")
        by_client = kind != "service"
        engine.move(transaction, db, ref, pay, "in_review", states.CLIENT if by_client else states.SYSTEM, uid if by_client else None, now,
                    code="dispute_in_review",
                    changes={"dispute": {"kind": kind, "openedBy": "client", "openedAt": now, "serviceFacts": facts},
                             "disputeKinds": [*(cur.get("disputeKinds") or []), kind]})
        transaction.set(ref.collection("staff").document("dispute"), {"clientNote": note, "kind": kind, "openedAt": now}, merge=True)
        transaction.set(standing_ref, {month: firestore.Increment(1)}, merge=True)
        held["moves"] = ([(cur["status"], "service_dispute"), ("service_dispute", "in_review")] if kind == "service"
                         else [(cur["status"], "in_review")])
        return {"status": "in_review"}

    out = common.run(db, body)
    if held:
        engine.notify_moves(notify, held["payment"], held["moves"])
    return out
