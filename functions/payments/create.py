"""create_payment: one request for one package, with a unique amount (spec 4.6, 4.7, 4.11, 4.12, 13.1, 13.2)."""

from __future__ import annotations

import datetime as dt
import random
from typing import Optional

from google.cloud import firestore

from coaching import common

from . import allocation, engine, errors, model, profile, states

LIMITS = model.LIMITS


def create(db, uid: str, data: dict, *, now: dt.datetime, on: bool, rng: Optional[random.Random] = None) -> dict:
    if not on:
        raise common.refuse(errors.PRECONDITION, errors.PAYMENTS_OFF)
    sub_id = common.text(data.get("subId"), max_len=128)
    key = engine.idem_key(data.get("idempotencyKey"))
    cfg = model.config(db)
    sub_ref = db.collection("subscriptions").document(sub_id)

    def body(transaction):
        again = engine.replay(transaction, db, uid, "create", key)
        if again is not None:
            return again
        sub = common.read(sub_ref, transaction)
        if sub is None or sub.get("clientUid") != uid:
            raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
        if sub.get("status") != "awaiting_payment":
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        coach_uid = sub["coachUid"]
        prof_ref = profile.profile_ref(db, coach_uid)
        prof = common.read(prof_ref, transaction)
        coach_private = common.read(db.collection("coachPrivate").document(coach_uid), transaction) or {}
        coach_standing = common.read(profile.standing_ref(db, coach_uid), transaction)
        client_standing = common.read(profile.standing_ref(db, uid), transaction)
        packages = list(db.collection("coaches").document(coach_uid).collection("packages").stream(transaction=transaction))
        mine = list(db.collection("payments").where("clientUid", "==", uid).stream(transaction=transaction))

        where = profile.effective(prof, now)
        if where is None:
            raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
        if coach_private.get("suspended") or profile.coach_suspended(coach_standing):
            raise common.refuse(errors.PRECONDITION, errors.COACH_PAYMENTS_SUSPENDED)
        if profile.client_suspended(client_standing):
            raise common.refuse(errors.PRECONDITION, errors.CLIENT_PAYMENTS_SUSPENDED)

        top, top_ref = None, None
        if data.get("topUpOf") is not None:
            top_id = common.text(data.get("topUpOf"), max_len=128)
            top_ref = engine.payment_ref(db, top_id)
            top = common.read(top_ref, transaction)
            lower = (top or {}).get("coachDecision") or {}
            if (top is None or top.get("clientUid") != uid or top.get("subId") != sub_id
                    or top.get("status") != "different_amount" or lower.get("acceptLower") is True):
                raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
            base = top["amountPiasters"] - lower["differentAmountPiasters"]
        else:
            base = int(sub["priceFinalEgp"]) * 100
        if base > cfg["maxAmountEgp"] * 100:
            raise common.refuse(errors.PRECONDITION, errors.AMOUNT_OVER_LIMIT)

        rows = [(s.id, s.to_dict() or {}) for s in mine]
        if any(r.get("subId") == sub_id and r.get("status") in model.HOLDS_AMOUNT and not (top is not None and pid == top_ref.id) for pid, r in rows):
            raise common.refuse(errors.PRECONDITION, errors.OPEN_PAYMENT_EXISTS)
        since = now - model.hours(24)
        recent = [r for _, r in rows if (common.as_utc(r.get("createdAt")) or since) > since and not r.get("topUpOf")]
        if len(recent) >= LIMITS["requestsPerDay"]:
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_REQUESTS)
        has_paid = any(r.get("status") in model.PAID_STATUSES for _, r in rows)
        if not has_paid and top is None and not (prof or {}).get("allowLongFirst"):
            lengths = [p.to_dict().get("durationDays") for p in packages if (p.to_dict() or {}).get("active") is True]
            if lengths and (sub.get("package") or {}).get("durationDays", 0) > min(lengths):
                raise common.refuse(errors.PRECONDITION, errors.FIRST_PAYMENT_SHORTEST_ONLY)

        pay_ref = db.collection("payments").document()
        amount, lock = allocation.allocate(transaction, db, coach_uid, base, pay_ref.id, now, rng=rng)
        reference = allocation.new_reference(transaction, db)
        seen_count = int((prof or {}).get("paymentsCreated", 0))

        allocation.claim(transaction, db, lock, coach_uid, amount, pay_ref.id, now)
        transaction.set(
            pay_ref,
            {
                "clientUid": uid, "coachUid": coach_uid, "subId": sub_id, "packageId": sub.get("packageId"),
                "baseAmountPiasters": base, "amountPiasters": amount, "lockId": lock, "reference": reference,
                "addressSnapshot": {"address": where[0], "accountName": where[1]},
                "status": "awaiting_payment", "statusAt": now, "createdAt": now,
                "expiresAt": now + model.hours(LIMITS["expiryHours"]),
                "lateUntil": now + model.days(LIMITS["lateProofDays"]),
                "proof": {"screenshotCount": 0, "amberAttempts": 0, "screenshotPaths": [], "imageFlags": []},
                "outcome": None, "access": {"state": "none", "until": None},
                "coachDecision": None, "coachReport": None, "dispute": None, "refund": None,
                "feePiasters": 0, "feeState": None, "feeOwedAt": None, "idempotencyKey": key,
                "staffVisible": seen_count < LIMITS["firstPaymentsStaffVisible"],
                "relSource": None, "reminded12h": False, "reminded48h": False,
                "topUpOf": top_ref.id if top_ref is not None else None,
                "feeBasePiasters": top["baseAmountPiasters"] if top is not None else base,
            },
        )
        transaction.set(
            pay_ref.collection("events").document(),
            {"at": now, "from": None, "to": "awaiting_payment", "role": states.CLIENT, "actor": states.CLIENT, "code": "created"},
        )
        if top is not None:
            engine.move(transaction, db, top_ref, top, "cancelled", states.CLIENT, uid, now, code="topped_up")
        transaction.update(prof_ref, {"paymentsCreated": firestore.Increment(1)})
        transaction.update(sub_ref, {"payment.paymentId": pay_ref.id})
        result = {
            "paymentId": pay_ref.id, "amountPiasters": amount, "reference": reference,
            "address": where[0], "accountName": where[1], "expiresAt": now + model.hours(LIMITS["expiryHours"]),
            "status": "awaiting_payment",
        }
        engine.remember(transaction, db, uid, "create", key, result, now)
        return result

    return common.run(db, body)
