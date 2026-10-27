"""The unique amount and the reference code (spec 13.2, 13.9)."""

from __future__ import annotations

import datetime as dt
import random

from coaching import common

from . import errors, model

REF_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"   # no 0 O 1 I L
MAX_TRIES = 99   # every candidate; a nearly full coach costs up to 99 small reads


def lock_id(coach_uid: str, amount: int) -> str:
    return f"{coach_uid}__{amount}"


def allocate(transaction, db, coach_uid: str, base_piasters: int, payment_id: str,
             now: dt.datetime, *, rng: random.Random | None = None) -> tuple[int, str]:
    """Reads, then (after the caller's other reads) the caller writes with
    `claim`. Returns (amount, lockId) of a free amount between base+1 and
    base+99 piasters. A lock is free when it does not exist or its heldUntil
    has passed. Two payments of one coach never share an amount while either
    is open; refuses amount_unavailable when none of the 99 is free."""
    rng = rng or random.Random()
    extras = list(range(1, 100))
    rng.shuffle(extras)
    locks = db.collection("paymentAmountLocks")
    for extra in extras[:MAX_TRIES]:
        amount = base_piasters + extra
        snap = locks.document(lock_id(coach_uid, amount)).get(transaction=transaction)
        held = common.as_utc((snap.to_dict() or {}).get("heldUntil")) if snap.exists else None
        if held is None or held <= now:
            return amount, lock_id(coach_uid, amount)
    raise common.refuse(errors.EXHAUSTED, errors.AMOUNT_UNAVAILABLE)


def claim(transaction, db, lock: str, coach_uid: str, amount: int, payment_id: str, now: dt.datetime) -> None:
    """Writes the lock. Held for the late-proof window (7 days); `engine.move`
    extends it while the payment is open and frees it when it ends."""
    transaction.set(
        db.collection("paymentAmountLocks").document(lock),
        {"coachUid": coach_uid, "amountPiasters": amount, "paymentId": payment_id,
         "heldUntil": now + model.days(model.LIMITS["lateProofDays"])},
    )


def new_reference(transaction, db, *, rng: random.Random | None = None) -> str:
    """OH-XXXXXX, not used by any payment (five tries)."""
    rng = rng or random.SystemRandom()
    for _ in range(5):
        candidate = "OH-" + "".join(rng.choice(REF_ALPHABET) for _ in range(6))
        taken = db.collection("payments").where("reference", "==", candidate).limit(1)
        if not any(True for _ in taken.stream(transaction=transaction)):
            return candidate
    raise common.refuse(errors.EXHAUSTED, errors.AMOUNT_UNAVAILABLE)
