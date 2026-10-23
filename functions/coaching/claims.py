"""The coach claim: the real adapter main.py hands to the other modules, and
the admin's suspension.

`coachV` is the only thing the rules and the callables trust for coach rights,
and only the server writes it.
"""

from __future__ import annotations

import datetime as dt
import logging

from . import common, errors


def merge_claims(auth, uid: str, changes: dict) -> None:
    """Read her custom claims, merge `changes` in, write them back.

    `set_custom_user_claims` replaces the whole map, so writing only `coachV`
    would strip `verified` (see identity/store.py mint_claims)."""
    user = auth.get_user(uid)
    claims = dict(user.custom_claims or {})
    claims.update(changes)
    auth.set_custom_user_claims(uid, claims)


def suspend(db, actor_uid: str, data: dict, *, merge_claims, now: dt.datetime) -> dict:
    """Takes her coach rights away and hides her page. Subscriptions are not
    ended here: staff decide what happens to her clients."""
    uid = common.text(data.get("uid"), max_len=128)
    reason = common.text(data.get("reason"), max_len=200, min_len=2)
    common.refuse_if_subject(actor_uid, uid)

    ref = db.collection("coaches").document(uid)
    if not ref.get().exists:
        raise common.refuse(errors.NOT_FOUND, errors.NOT_A_COACH)

    common.log_access(db, actor_uid, "coach_suspend", uid, now)
    ref.update({"published": False, "acceptingClients": False, "updatedAt": now})
    db.collection("coachPrivate").document(uid).set(
        {"suspended": True, "suspendReason": reason, "suspendedAt": now, "updatedAt": now}, merge=True
    )
    merge_claims(uid, {"coachV": "suspended"})
    return {"coachV": "suspended"}


def on_verification_revoked(db, uid: str, now: dt.datetime) -> None:
    """Her women-only check was taken back: a coach's page comes down and the
    server record says suspended, so a token that is still valid cannot act.
    Does nothing for a woman who is not a coach. Never raises."""
    try:
        ref = db.collection("coaches").document(uid)
        if not ref.get().exists:
            return
        ref.update({"published": False, "acceptingClients": False, "updatedAt": now})
        db.collection("coachPrivate").document(uid).set(
            {
                "suspended": True,
                "suspendReason": "verification_revoked",
                "suspendedAt": now,
                "updatedAt": now,
            },
            merge=True,
        )
    except Exception:  # noqa: BLE001 - the revoke itself must go through
        logging.getLogger(__name__).error("coach_unpublish_after_revoke_failed")
