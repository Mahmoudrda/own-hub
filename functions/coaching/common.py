"""Helpers every private-coaching module shares: the contract's limits, the
live switch, field checks, the staff access log, and the small adapters for
files, claims and pushes that main.py fills in and the tests fake.

Every module function takes `now` (an aware UTC datetime) and stores times from
it, so a test can run the whole journey on a fixed clock.
"""

from __future__ import annotations

import datetime as dt
import hashlib
import json
import logging
import os
import re
import secrets
from typing import Any, Callable, Iterable, Optional, Protocol
from zoneinfo import ZoneInfo

from google.cloud import firestore

from . import errors

_HERE = os.path.dirname(os.path.abspath(__file__))
_CONTRACT_PATHS = (
    os.path.join(_HERE, "coaching_contract.json"),
    os.path.join(os.path.dirname(os.path.dirname(_HERE)), "contracts", "coaching_contract.json"),
)


def _load_contract() -> dict:
    for path in _CONTRACT_PATHS:
        if os.path.exists(path):
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
    raise FileNotFoundError("coaching_contract.json")


CONTRACT = _load_contract()
"""contracts/coaching_contract.json, read from the copy beside this file,
because only functions/ is deployed. A test keeps the two identical."""

def sha(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


LIMITS: dict = CONTRACT["limits"]
ENUMS: dict = CONTRACT["enums"]
RAILS: dict = CONTRACT["rails"]


class Blobs(Protocol):
    """The personal bucket, as the modules see it."""

    def exists(self, path: str) -> bool: ...

    def read(self, path: str) -> bytes: ...

    def write(self, path: str, data: bytes, content_type: str) -> None: ...

    def delete(self, path: str) -> None: ...

    def lock(self, path: str) -> None: ...


Notify = Callable[[str, str], None]
"""`notify(uid, kind)`: one push of a kind in ENUMS['pushKinds']. Never raises."""

CAIRO = ZoneInfo("Africa/Cairo")


def run(db, body: Callable):
    """Runs `body(transaction)` in a Firestore transaction. The body may run
    more than once, so it reads, decides and writes, and nothing else. Looks
    `firestore.transactional` up on each call, so a test can swap it."""
    return firestore.transactional(body)(db.transaction())


def read(reference, transaction) -> Optional[dict]:
    """The document's fields, or None when it does not exist. (A real snapshot
    raises on a missing field, so callers read a dict.)"""
    snapshot = reference.get(transaction=transaction)
    return (snapshot.to_dict() or {}) if snapshot.exists else None


MIN_APP_BUILD = 433440
"""The lowest app build (minutes since 1 Jan 2026 UTC, as tool/build_ios.sh and
tool/build_release.sh number it) that has the payment screens: release 1.1.0,
first built on 29 Oct 2026. Version 1.0.0 (builds up to 424738) sends no
appBuild at all. Raise it only when a later build is required to pay."""


def app_can_pay(build: Any) -> bool:
    """True for a whole appBuild at or above MIN_APP_BUILD. A bool is not a build."""
    return isinstance(build, int) and not isinstance(build, bool) and build >= MIN_APP_BUILD


def _require_switch(live: bool) -> None:
    if not live:
        raise errors.CoachingError(errors.PRECONDITION, errors.COACH_APP_CLOSED)


def require_portfolio_live(live: bool) -> None:
    """Applications, profiles, packages, claims."""
    _require_switch(live)


def require_clients_live(live: bool) -> None:
    """Requests, accepting, chat, plans, sessions, invites."""
    _require_switch(live)


def require_payments_live(live: bool) -> None:
    """Proofs, refunds, payouts."""
    _require_switch(live)


def require_verified(verified: bool) -> None:
    if not verified:
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_VERIFIED)


def require_coach(coach_v: Any) -> None:
    if coach_v == "suspended":
        raise errors.CoachingError(errors.PERMISSION, errors.COACH_SUSPENDED)
    if coach_v != "active":
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_A_COACH)


def require_active_coach(db, uid: str, coach_v: Any, *, allow_hold: bool = False) -> dict:
    """The claim AND the server's own record. A token stays valid for up to an
    hour after a suspension, so the claim alone is not enough: coachPrivate
    says whether she is suspended now. Returns her coachPrivate row."""
    require_coach(coach_v)
    snap = db.collection("coachPrivate").document(uid).get()
    if not snap.exists:
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_A_COACH)
    row = snap.to_dict() or {}
    if row.get("suspended"):
        raise errors.CoachingError(errors.PERMISSION, errors.COACH_SUSPENDED)
    if not allow_hold and row.get("hold"):
        raise errors.CoachingError(errors.PERMISSION, errors.COACH_ON_HOLD)  # fee recording uses require_coach, not this
    return row


def require_not_on_hold(db, uid: str, transaction=None) -> None:
    """For the coach actions that carry no coach claim (leaving a coaching,
    marking a session done, making an invite code): refused while on hold."""
    if (db.collection("coachPrivate").document(uid).get(transaction=transaction).to_dict() or {}).get("hold"):
        raise errors.CoachingError(errors.PERMISSION, errors.COACH_ON_HOLD)


def coaches_on_hold(db) -> set:
    """Uids of coaches whose account is on hold for an unpaid Own Hub fee
    (`coachPrivate.hold`, server-only)."""
    return {s.id for s in db.collection("coachPrivate").where("hold.reason", "==", "fee").stream()}


def refuse_if_subject(actor_uid: str, *subjects: Any) -> None:
    """Staff never decide a case about themselves."""
    if actor_uid in {s for s in subjects if isinstance(s, str) and s}:
        raise errors.CoachingError(errors.PERMISSION, errors.STAFF_IS_SUBJECT)


def refuse(code: str, reason: str) -> errors.CoachingError:
    """The refusal to raise: `raise common.refuse(errors.NOT_FOUND, ...)`."""
    return errors.CoachingError(code, reason)


def bad(reason: str = errors.BAD_REQUEST) -> errors.CoachingError:
    return refuse(errors.INVALID, reason)


def text(value: Any, *, max_len: int, min_len: int = 1, reason: str = errors.BAD_REQUEST) -> str:
    """A trimmed string of min_len..max_len characters, else a refusal."""
    if not isinstance(value, str):
        raise bad(reason)
    value = value.strip()
    if not (min_len <= len(value) <= max_len):
        raise bad(reason)
    return value


def optional_text(value: Any, *, max_len: int) -> str:
    if value is None:
        return ""
    return text(value, max_len=max_len, min_len=0)


def whole(value: Any, *, low: int, high: int, reason: str = errors.BAD_REQUEST) -> int:
    """A whole number in low..high. Bools are refused; iOS Int64 wrappers are
    unwrapped by main._payload before a module sees them."""
    if isinstance(value, bool) or not isinstance(value, int):
        raise bad(reason)
    if not (low <= value <= high):
        raise bad(reason)
    return value


def whole_of(value: Any, allowed: Iterable, reason: str = errors.BAD_REQUEST) -> int:
    """A whole number that is one of `allowed` (a bool or a float is not)."""
    if isinstance(value, bool) or not isinstance(value, int) or value not in list(allowed):
        raise bad(reason)
    return value


def one_of(value: Any, allowed: Iterable, reason: str = errors.BAD_REQUEST):
    if value not in list(allowed):
        raise bad(reason)
    return value


def subset(values: Any, allowed: Iterable, *, low: int, high: int, reason: str = errors.BAD_REQUEST) -> list:
    """A list of distinct allowed values, low..high long, in the given order."""
    allowed = list(allowed)
    if not isinstance(values, list) or not (low <= len(values) <= high):
        raise bad(reason)
    if len(set(map(str, values))) != len(values) or any(v not in allowed for v in values):
        raise bad(reason)
    return list(values)


def account_ok(rail: Any, account: Any) -> bool:
    spec = RAILS.get(rail) if isinstance(rail, str) else None
    return bool(spec) and isinstance(account, str) and re.fullmatch(spec["accountPattern"], account) is not None


def reference_ok(rail: Any, reference: Any) -> bool:
    spec = RAILS.get(rail) if isinstance(rail, str) else None
    return bool(spec) and isinstance(reference, str) and re.fullmatch(spec["referencePattern"], reference) is not None


def normalise_reference(reference: str) -> str:
    """The form a reference is kept unique in: no spaces or dashes, upper case."""
    return re.sub(r"[\s-]", "", reference).upper()


def final_price(coach_price: int) -> int:
    """The client's price. Integer arithmetic on purpose: Python's round() is
    banker's rounding and 1.15 is not exact in binary."""
    return (coach_price * (100 + LIMITS["marginPercent"]) + 50) // 100


def rel_id(coach_uid: str, client_uid: str) -> str:
    return f"{coach_uid}__{client_uid}"


_CODE_ALPHABET = CONTRACT["ids"]["paymentCodeAlphabet"]


def payment_code(choice: Callable[[str], str] = secrets.choice) -> str:
    return "OH" + "".join(choice(_CODE_ALPHABET) for _ in range(6))


def hours(n: int) -> dt.timedelta:
    return dt.timedelta(hours=n)


def days(n: int) -> dt.timedelta:
    return dt.timedelta(days=n)


def as_utc(value: Any) -> Optional[dt.datetime]:
    """A stored time as an aware UTC datetime, or None."""
    if isinstance(value, dt.datetime):
        return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)
    return None


def log_access(db, actor_uid: str, action: str, target: str, now: dt.datetime) -> None:
    """Every staff read or decision leaves a line in adminAccessLog, the same
    collection and shape as the console (console/access.py): a short reference
    for the staff member and for the target, never a uid, an amount, a
    reference or an account number, and a one-year expiry."""
    from console import access

    db.collection(access.COLLECTION).add(
        {
            "admin": access.short_ref(actor_uid),
            "action": f"coaching.{action}",
            "target": access.short_ref(target),
            "at": now,
            "expireAt": now + dt.timedelta(days=access.RETENTION_DAYS),
        }
    )


def sessions_included(live_sessions_per_month: int, duration_days: int) -> int:
    return live_sessions_per_month * duration_days // 28


def refund_amount(price_final: int, used: int, included: int) -> int:
    """What she gets back when she cancels inside the window: the price less
    the share of live sessions already held. Counsel confirms the formula."""
    if included <= 0:
        return 0
    used = max(0, min(used, included))
    return price_final - (price_final * used) // included


def coach_share_after_refund(coach_price: int, used: int, included: int) -> int:
    """Her share when the client cancels: her price for the sessions held."""
    if included <= 0:
        return 0
    used = max(0, min(used, included))
    return (coach_price * used) // included


def coach_share_of_kept(coach_price: int, price_final: int, refund: int) -> int:
    """Her share when staff refund part of the price: her price in the same
    proportion as the part of the price Own Hub keeps."""
    return coach_price * (price_final - refund) // price_final


def monthly_equivalent(price_final: int, duration_days: int) -> int:
    return price_final * 28 // duration_days


_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def parse_day(value: Any) -> dt.date:
    """A `YYYY-MM-DD` string as a date, else a refusal."""
    if not isinstance(value, str) or not _DATE.match(value):
        raise bad()
    try:
        return dt.date.fromisoformat(value)
    except ValueError:
        raise bad() from None


def cairo_day(moment: dt.datetime) -> dt.date:
    """The calendar day in Cairo, where her transfer is dated."""
    return moment.astimezone(CAIRO).date()


def consent_ref(db, uid: str, name: str):
    return db.collection("users").document(uid).collection("consents").document(name)


def record_consent(transaction, ref, seen, locale: str, now: dt.datetime) -> None:
    """Writes the consent at `ref` unless `seen` (its snapshot, read earlier)
    says it is there already."""
    if not seen.exists:
        transaction.set(ref, {"version": 1, "at": now, "locale": locale})


def staff_ref(actor_uid: str) -> str:
    """How a record names the staff member: a short reference, never her uid."""
    from console import access

    return access.short_ref(actor_uid)


def decided_stamp(actor_uid: str, now: dt.datetime) -> dict:
    """Who decided and when, as every decision record keeps it."""
    return {"decidedBy": staff_ref(actor_uid), "decidedAt": now}


def drop_proof_image(proof_ref, path: Optional[str], blobs) -> bool:
    """Deletes a decided screenshot, then clears the pointer and the flag.
    When the delete fails the flag stays, the hourly pass tries again, and this
    returns False."""
    try:
        if path:
            blobs.delete(path)
        proof_ref.update({"imagePath": None, "imageDeletePending": False})
    except Exception:  # noqa: BLE001
        logging.getLogger(__name__).error("coaching_proof_image_delete_failed")
        return False
    return True


def plain(value: Any):
    """A stored value as something a callable can return: times as ISO text."""
    if isinstance(value, dt.datetime):
        return value.isoformat()
    if isinstance(value, dict):
        return {key: plain(item) for key, item in value.items()}
    if isinstance(value, list):
        return [plain(item) for item in value]
    return value
