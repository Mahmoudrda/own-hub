"""K07: a coach invites a woman she already coaches.

She shares a short code (by WhatsApp, from the app). The woman she sends it to
types it on C01, keeps it on her phone through sign-up, and redeems it once she
has passed the women-only check. Redeeming only tells the app which coach the
code is for; the app then opens that coach's page and she asks to join there,
through the same sheet as anyone else (health questions, doctor tick, consent).
Nothing is written, so an invite skips nothing but the search, and no row
exists that a coach's desk could mistake for a request.

`coachInvites/{code}` is server-only (firestore.rules) and holds the coach's uid
and two dates, nothing about the woman invited. Deletion row 49 removes a
coach's codes with her account.

No attempt counter: a code is eight characters from a 31-letter alphabet
(about 8.5 x 10^11 codes), and only a verified account may redeem, which costs
an identity check per account. Guessing one is not a practical attack.
"""

from __future__ import annotations

import datetime as dt
import secrets
from typing import Callable, Optional

from . import errors

COLLECTION = "coachInvites"

ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
"""No 0/O, 1/I/L: a code read aloud or copied by hand stays one code."""

CODE_LENGTH = 8

VALID_DAYS = 30

FIELDS = ("coachUid", "createdAt", "expiresAt")

_ARABIC_DIGITS = str.maketrans("٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")


def normalise(raw) -> Optional[str]:
    """The code as stored, or None. Spaces, dashes, case and Eastern Arabic
    digits are forgiven, because people copy codes out of chat bubbles."""
    if not isinstance(raw, str) or len(raw) > 40:
        return None
    code = raw.translate(_ARABIC_DIGITS).upper()
    code = "".join(ch for ch in code if ch not in " -_ ")
    if len(code) != CODE_LENGTH or any(ch not in ALPHABET for ch in code):
        return None
    return code


def new_code(choice: Callable[[str], str] = secrets.choice) -> str:
    return "".join(choice(ALPHABET) for _ in range(CODE_LENGTH))


def _aware(value) -> Optional[dt.datetime]:
    if isinstance(value, dt.datetime):
        return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)
    return None


def create(
    db,
    uid: str,
    *,
    is_coach: bool,
    verified: bool,
    live: bool,
    now: dt.datetime,
    make_code: Callable[[], str] = new_code,
) -> dict:
    """Her current code, or a new one. One live code per coach: asking again
    returns the same code until it lapses."""
    if not live:
        raise errors.CoachingError(errors.PRECONDITION, errors.COACH_APP_CLOSED)
    if not verified:
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_VERIFIED)
    if not is_coach:
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_A_COACH)

    invites = db.collection(COLLECTION)
    for snapshot in invites.where("coachUid", "==", uid).stream():
        expires = _aware(snapshot.get("expiresAt"))
        if expires is not None and expires > now:
            return {"ok": True, "code": snapshot.id, "expiresAtMs": _ms(expires)}

    expires = now + dt.timedelta(days=VALID_DAYS)
    for _ in range(5):
        code = make_code()
        ref = invites.document(code)
        if ref.get().exists:
            continue
        record = {"coachUid": uid, "createdAt": now, "expiresAt": expires}
        assert set(record) <= set(FIELDS)
        ref.set(record)
        return {"ok": True, "code": code, "expiresAtMs": _ms(expires)}
    raise errors.CoachingError(errors.EXHAUSTED, errors.INVITE_INVALID)


def accept(
    db,
    uid: str,
    data: dict,
    *,
    verified: bool,
    live: bool,
    now: dt.datetime,
    timestamp,
) -> dict:
    """The coach a code is for: `{ok, relId, coachUid}`. Writes nothing
    (`timestamp` stays in the signature for the callable and is not used)."""
    if not live:
        raise errors.CoachingError(errors.PRECONDITION, errors.COACH_APP_CLOSED)
    if not verified:
        raise errors.CoachingError(errors.PERMISSION, errors.NOT_VERIFIED)
    code = normalise(data.get("code"))
    if code is None:
        raise errors.CoachingError(errors.INVALID, errors.INVITE_INVALID)

    invite = db.collection(COLLECTION).document(code).get()
    if not invite.exists:
        raise errors.CoachingError(errors.NOT_FOUND, errors.INVITE_INVALID)
    coach_uid = invite.get("coachUid")
    expires = _aware(invite.get("expiresAt"))
    if not isinstance(coach_uid, str) or not coach_uid:
        raise errors.CoachingError(errors.NOT_FOUND, errors.INVITE_INVALID)
    if expires is None or expires <= now:
        raise errors.CoachingError(errors.PRECONDITION, errors.INVITE_EXPIRED)
    if coach_uid == uid:
        raise errors.CoachingError(errors.PRECONDITION, errors.INVITE_OWN)

    users = db.collection("users")
    # A coach page that no longer exists, or a block in either direction, is
    # answered exactly like a code that never existed.
    if not db.collection("coaches").document(coach_uid).get().exists:
        raise errors.CoachingError(errors.NOT_FOUND, errors.INVITE_INVALID)
    if (
        users.document(coach_uid).collection("blocks").document(uid).get().exists
        or users.document(uid).collection("blocks").document(coach_uid).get().exists
    ):
        raise errors.CoachingError(errors.NOT_FOUND, errors.INVITE_INVALID)

    return {"ok": True, "relId": f"{coach_uid}__{uid}", "coachUid": coach_uid}


def _ms(value: dt.datetime) -> int:
    return int(value.timestamp() * 1000)
