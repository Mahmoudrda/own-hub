"""Readers for a woman's payment profile and standing (written by WO-10d and WO-10o)."""

from __future__ import annotations

import datetime as dt
from typing import Optional

from coaching import common


def profile_ref(db, uid: str):
    return db.collection("coachPaymentProfiles").document(uid)


def standing_ref(db, uid: str):
    return db.collection("paymentStanding").document(uid)


def effective(profile: Optional[dict], now: dt.datetime) -> Optional[tuple]:
    """(address, accountName) the coach is paid at right now, or None when she
    has none. A pending change counts only after its 24 hour delay (4.4)."""
    if not profile:
        return None
    pending = profile.get("pending") or {}
    when = common.as_utc(pending.get("effectiveAt"))
    if pending.get("address") and when is not None and when <= now:
        return pending["address"], pending["accountName"]
    if profile.get("address"):
        return profile["address"], profile["accountName"]
    return None


def coach_suspended(standing: Optional[dict]) -> bool:
    return bool((standing or {}).get("coachSuspended"))


def client_suspended(standing: Optional[dict]) -> bool:
    return bool((standing or {}).get("clientSuspended"))
