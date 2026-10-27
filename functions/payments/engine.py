"""One way to change a payment's status, and one way to make a repeat harmless."""

from __future__ import annotations

import datetime as dt
import re
from typing import Optional

from coaching import common

from . import errors, model, states

_KEY = re.compile(r"^[A-Za-z0-9_-]{8,64}$")


def idem_key(value) -> str:
    """The client's idempotency key: 8 to 64 characters of letters, digits, _ and -."""
    if not isinstance(value, str) or not _KEY.match(value):
        raise common.bad()
    return value


def payment_ref(db, payment_id: str):
    return db.collection("payments").document(payment_id)


class Payment(dict):
    """A payment row that knows whether the amount lock it names is still its
    own. `move` only touches a lock that is: a lapsed lock may have been taken
    by another payment of the same coach and amount (WO-10m)."""

    lock_owned = False


def read_payment(transaction, db, ref) -> Optional[Payment]:
    """The payment as `Payment`, or None. Reads the row and its lock, both
    before any write of the caller's transaction."""
    row = common.read(ref, transaction)
    if row is None:
        return None
    pay = Payment(row)
    if row.get("lockId"):
        lock = db.collection("paymentAmountLocks").document(row["lockId"]).get(transaction=transaction)
        pay.lock_owned = lock.exists and (lock.to_dict() or {}).get("paymentId") == ref.id
    return pay


def load(transaction, db, payment_id: str) -> tuple:
    """(ref, payment) or the one 'not found' refusal."""
    ref = payment_ref(db, payment_id)
    row = read_payment(transaction, db, ref)
    if row is None:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    return ref, row


def load_for_party(transaction, db, payment_id: str, uid: str, role: str) -> tuple:
    """Like `load`, and the caller must be the client (role 'client') or the
    coach (role 'coach') named on it. A stranger gets the same 'not found'."""
    ref, row = load(transaction, db, payment_id)
    field = "clientUid" if role == states.CLIENT else "coachUid"
    if row.get(field) != uid:
        raise common.refuse(errors.NOT_FOUND, errors.PAYMENT_NOT_FOUND)
    return ref, row


def actor_label(role: str, uid: str) -> str:
    return common.staff_ref(uid) if role == states.STAFF else role


def move(transaction, db, ref, payment: dict, to: str, role: str, actor_uid: Optional[str],
         now: dt.datetime, *, changes: Optional[dict] = None, code: Optional[str] = None) -> dict:
    """Checks the move against the table, writes the new status and ONE event
    document, and returns the payment as it now stands (so a caller can chain a
    second move in the same transaction). The event holds a role and a short
    code, never a name, an amount or a uid: both parties read the timeline."""
    states.check(payment["status"], to, role)
    update = {"status": to, "statusAt": now, "escalateAt": model.escalate_at(to, now), **(changes or {})}
    if to == "in_review" and payment.get("feeState") == "owed" and "feeState" not in update:
        update["feeState"] = "disputed"  # the statement lists it as disputed, pending (13.5)
    transaction.update(ref, update)
    lock = payment.get("lockId")
    if lock and getattr(payment, "lock_owned", False) and (to in model.LONG_HOLD or to not in model.HOLDS_AMOUNT):
        held = now + model.days(30) if to in model.LONG_HOLD else now
        transaction.update(db.collection("paymentAmountLocks").document(lock), {"heldUntil": held})
    transaction.set(
        ref.collection("events").document(),
        {
            "at": now,
            "from": payment["status"],
            "to": to,
            "role": role,
            "actor": actor_label(role, actor_uid or ""),
            "code": code,
        },
    )
    out = Payment({**payment, **update})
    out.lock_owned = getattr(payment, "lock_owned", False)
    return out


def replay(transaction, db, uid: str, scope: str, key: str) -> Optional[dict]:
    """The answer already given for this (woman, call, key), or None."""
    snap = db.collection("paymentIdempotency").document(f"{uid}__{scope}__{key}").get(transaction=transaction)
    return (snap.to_dict() or {}).get("result") if snap.exists else None


def remember(transaction, db, uid: str, scope: str, key: str, result: dict, now: dt.datetime) -> None:
    transaction.set(
        db.collection("paymentIdempotency").document(f"{uid}__{scope}__{key}"),
        {"uid": uid, "result": common.plain(result), "at": now, "expireAt": now + model.days(model.LIMITS["idempotencyDays"])},
    )


def notify_moves(notify, payment: dict, moves: list) -> None:
    """Pushes for each (from, to) a call made (states.notices_for). `payment`
    names the two parties. Never raises into the caller's answer."""
    for frm, to in moves:
        for who, kind in states.notices_for(frm, to):
            uid = payment["clientUid"] if who == states.CLIENT else payment["coachUid"]
            try:
                notify(uid, kind)
            except Exception:  # noqa: BLE001
                pass

