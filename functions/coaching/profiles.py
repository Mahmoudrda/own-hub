"""A coach's public profile and her payout account.

The profile fields she may change herself are few and bounded. Her payout
account lives under `coachPrivate/{uid}`: a change is only a request until
finance confirms it, and it is never paid to before that.
"""

from __future__ import annotations

import datetime as dt
from typing import Optional

from google.cloud import firestore

from . import applications, chat, common, errors


def _coach_ref(db, uid: str):
    return db.collection("coaches").document(uid)


def _private_ref(db, uid: str):
    return db.collection("coachPrivate").document(uid)


def update(
    db,
    uid: str,
    data: dict,
    *,
    live: bool,
    coach_v: Optional[str],
    blobs,
    reencode,
    now: dt.datetime,
) -> dict:
    common.require_portfolio_live(live)
    common.require_active_coach(db, uid, coach_v)
    limits = common.LIMITS

    changes: dict = {}
    chat.refuse_contact(data.get("headline"), data.get("approachText"))
    if data.get("headline") is not None:
        changes["headline"] = common.text(data["headline"], min_len=10, max_len=limits["headlineMax"])
    if data.get("approachText") is not None:
        changes["approach.text"] = common.text(
            data["approachText"], min_len=limits["approachTextMin"], max_len=limits["approachTextMax"]
        )
    for key in ("acceptingClients", "autoAccept"):
        if data.get(key) is not None:
            if not isinstance(data[key], bool):
                raise common.bad()
            changes[key] = data[key]
    if data.get("maxActiveClients") is not None:
        changes["maxActiveClients"] = common.whole(
            data["maxActiveClients"], low=limits["maxActiveClientsMin"], high=limits["maxActiveClientsMax"]
        )
    photo_path = data.get("photoPath")
    if photo_path is not None:
        photo_path = common.text(photo_path, max_len=300)
        if not applications.under_prefix(photo_path, applications.photo_prefix(uid)) or not blobs.exists(
            photo_path
        ):
            raise common.refuse(errors.INVALID, errors.FILE_NOT_UPLOADED)
    if not changes and photo_path is None:
        raise common.bad()

    ref = _coach_ref(db, uid)
    if not ref.get().exists:
        raise common.refuse(errors.PERMISSION, errors.NOT_A_COACH)

    if photo_path is not None:
        applications.write_public_photos(blobs, reencode, uid, blobs.read(photo_path))
    changes["updatedAt"] = now
    ref.update(changes)
    return {"ok": True}


def _payout(data: dict) -> dict:
    rail, account = data.get("rail"), data.get("account")
    if not common.account_ok(rail, account):
        raise common.bad()
    return {
        "rail": rail,
        "account": account,
        "holderName": common.text(data.get("holderName"), min_len=3, max_len=common.LIMITS["fullNameMax"]),
    }


def request_payout_change(
    db, uid: str, data: dict, *, live: bool, coach_v: Optional[str], now: dt.datetime
) -> dict:
    """Her new account waits as `pendingPayout`; the confirmed one keeps being
    used until finance confirms the new one."""
    common.require_payments_live(live)
    common.require_active_coach(db, uid, coach_v)  # her private row exists
    pending = {**_payout(data), "requestedAt": now}
    _private_ref(db, uid).update({"pendingPayout": pending, "updatedAt": now})
    return {"state": "pending"}


def _same_name(a, b) -> bool:
    def fold(value) -> str:
        return " ".join(str(value or "").casefold().split())

    return bool(fold(a)) and fold(a) == fold(b)


def confirm_payout(db, actor_uid: str, data: dict, *, now: dt.datetime) -> dict:
    """Finance confirms or rejects the account waiting for her: a requested
    change, or the first account while the state is still `pending`."""
    uid = common.text(data.get("uid"), max_len=128)
    common.refuse_if_subject(actor_uid, uid)
    decision = common.one_of(data.get("decision"), ("confirm", "reject"))

    ref = _private_ref(db, uid)
    if not ref.get().exists:
        raise common.refuse(errors.NOT_FOUND, errors.NOT_A_COACH)

    def body(transaction):
        stored = ref.get(transaction=transaction).to_dict() or {}
        pending = stored.get("pendingPayout")
        state = stored.get("payoutState")
        waiting = pending if isinstance(pending, dict) else (
            stored.get("payout") if state == "pending" and isinstance(stored.get("payout"), dict) else None
        )
        if waiting is None:
            raise common.refuse(errors.PRECONDITION, errors.WRONG_STATUS)
        changes: dict = {"updatedAt": now}
        if decision == "confirm":
            changes["payout"] = {
                "rail": waiting.get("rail"),
                "account": waiting.get("account"),
                "holderName": waiting.get("holderName"),
            }
            changes["payoutState"] = "confirmed"
            changes["payoutNameMatches"] = _same_name(waiting.get("holderName"), stored.get("fullName"))
            new_state = "confirmed"
        else:
            new_state = state if state in ("confirmed", "none") else "rejected"
            changes["payoutState"] = new_state
        if isinstance(pending, dict):
            changes["pendingPayout"] = firestore.DELETE_FIELD
        transaction.update(ref, changes)
        return new_state

    new_state = common.run(db, body)
    common.log_access(db, actor_uid, f"payout_{decision}", uid, now)
    return {"state": new_state}
