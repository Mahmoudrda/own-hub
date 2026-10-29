"""The coach's InstaPay address (spec 4.4, 13.12 item 7)."""

from __future__ import annotations

import datetime as dt
import re

from coaching import common

from . import errors, model, profile

DEFAULT_SUFFIXES = ("instapay",)  # UNVERIFIED: other bank suffixes. Ask the owner for three real addresses, then set coachingConfig/instapay.addressSuffixes.
_PHONE = re.compile(r"^\+?[0-9][0-9 \-]{6,}$")
_HANDLE_LOCAL = re.compile(r"^[a-z0-9._-]{3,40}$")
MIN_GAP_MINUTES = 10

DEFAULTS = {"paymentsCreated": 0, "paymentsConfirmed": 0, "cleanConfirmed": 0, "disputesLost": 0,
            "autoConfirmGreen": False, "allowLongFirst": False, "status": "ok"}


def suffixes(db) -> tuple:
    row = db.collection("coachingConfig").document("instapay").get()
    listed = (row.to_dict() or {}).get("addressSuffixes") if row.exists else None
    if isinstance(listed, list) and listed and all(isinstance(s, str) and re.fullmatch(r"[a-z]{3,20}", s) for s in listed):
        return tuple(listed)
    return DEFAULT_SUFFIXES


def check_address(raw, allowed: tuple) -> str:
    """The address as it will be stored (trimmed, lower case), or a refusal.
    A phone number is refused with its own code so the app can explain why."""
    if not isinstance(raw, str):
        raise common.bad()
    text = raw.strip().lower()
    if _PHONE.match(text):
        raise common.refuse(errors.INVALID, errors.ADDRESS_NOT_HANDLE)
    local, at, suffix = text.partition("@")
    if not at or suffix not in allowed or not _HANDLE_LOCAL.match(local):
        raise common.refuse(errors.INVALID, errors.ADDRESS_FORMAT)
    if sum(ch.isdigit() for ch in local) >= 9:  # a phone number written as a handle
        raise common.refuse(errors.INVALID, errors.ADDRESS_NOT_HANDLE)
    return text


def set_address(db, uid: str, data: dict, *, coach_v, recent_sign_in: bool, now: dt.datetime, notify) -> dict:
    common.require_active_coach(db, uid, coach_v)
    if recent_sign_in is not True:
        raise common.refuse(errors.PERMISSION, errors.RECENT_SIGN_IN_REQUIRED)
    address = check_address(data.get("address"), suffixes(db))
    name = common.text(data.get("accountName"), min_len=2, max_len=80)
    prof_ref = profile.profile_ref(db, uid)
    coach_ref = db.collection("coaches").document(uid)
    alert_ref = db.collection("paymentAlerts").document()
    held = {}

    def body(transaction):
        prof = common.read(prof_ref, transaction)
        coach = common.read(coach_ref, transaction)
        standing = common.read(profile.standing_ref(db, uid), transaction)
        last = common.as_utc((prof or {}).get("changedAt"))
        if last is not None and now < last + dt.timedelta(minutes=MIN_GAP_MINUTES):
            raise common.refuse(errors.EXHAUSTED, errors.TOO_MANY_REQUESTS)
        current = profile.effective(prof, now)
        suspended = profile.coach_suspended(standing)
        if current is None:  # the first address: active at once
            transaction.set(prof_ref, {**DEFAULTS, **(prof or {}), "address": address, "accountName": name,
                                       "verifiedAt": now, "changedAt": now, "pending": None})
            status, effective = "active", now
        else:
            if current == (address, name):
                return {"status": "active", "effectiveAt": common.plain(now)}  # nothing changes
            effective = now + model.hours(model.LIMITS["addressDelayHours"])
            # A pending change that has already come due is settled before a new one is stored.
            base = {"address": current[0], "accountName": current[1]}
            transaction.set(prof_ref, {**DEFAULTS, **(prof or {}), **base, "changedAt": now,
                                       "pending": {"address": address, "accountName": name, "requestedAt": now, "effectiveAt": effective}})
            status = "pending"
        if coach is not None:
            transaction.update(coach_ref, {"instapayReady": not suspended})
        transaction.set(alert_ref, {"type": "addressChange", "coachRef": common.staff_ref(uid), "firstTime": current is None,
                                    "at": now, "effectiveAt": effective})
        held["changed"] = current is not None
        return {"status": status, "effectiveAt": common.plain(effective)}

    result = common.run(db, body)
    if held.get("changed"):
        try:
            notify(uid, "instapayAddressChangedCoach")  # she is told of her own change, so a taken-over account cannot redirect payments unseen (S3)
        except Exception:  # noqa: BLE001
            pass
        for snap in db.collection("payments").where("coachUid", "==", uid).stream():
            row = snap.to_dict() or {}
            late = common.as_utc(row.get("lateUntil"))
            if row.get("status") in ("awaiting_payment", "expired") and late is not None and now <= late:
                try:
                    notify(row["clientUid"], "instapayAddressChanged", snap.id)
                except Exception:  # noqa: BLE001
                    pass
    return result


def set_options(db, uid: str, data: dict, *, coach_v, now: dt.datetime) -> dict:
    common.require_active_coach(db, uid, coach_v)
    allow = data.get("allowLongFirst")
    if not isinstance(allow, bool):
        raise common.bad()
    ref = profile.profile_ref(db, uid)

    def body(transaction):
        if common.read(ref, transaction) is None:
            raise common.refuse(errors.PRECONDITION, errors.COACH_NOT_READY)
        transaction.update(ref, {"allowLongFirst": allow})
        return {"allowLongFirst": allow}

    return common.run(db, body)
