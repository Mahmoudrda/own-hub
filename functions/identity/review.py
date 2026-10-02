"""The human review loop, as plain functions over an injected store.

What review IS here, since no image is ever stored: a live encounter with a
woman reviewer. The queue holds reason codes, two scores and a scheduling
handle. It never holds a photograph, a frame, a phone number or an ID number.

Every function in this module takes a `ReviewStore`. The Cloud Functions in
main.py call them with the Firestore implementation (store.FirestoreReviewStore),
so there is one code path for the access log, the state writes and the checks.
The reviewer command line tool (tools/review_queue.py) calls those Cloud
Functions over HTTPS with the reviewer's own ID token and holds no admin
credentials. Tests call these functions with an in-memory fake.

Errors are `ReviewError(kind, reason)`. `reason` is always a reason code from
reasons.py, never a sentence and never anything she or the reviewer typed.
main.py maps `kind` onto an HttpsError code.
"""

from __future__ import annotations

import datetime as dt
import time
from dataclasses import dataclass
from typing import Any, Optional, Protocol

from . import config, decisions, dedupe, nid, reasons

# The four states of users/{uid}.verification.state. Server-written only; the
# rules' verificationUntouched() keeps the client out. No reason codes and no
# flag id ever go into this map: it is hers to read.
STATE_APPROVED = "approved"
STATE_PENDING = "pending"
STATE_REJECTED = "rejected"
STATE_RETRY = "retry"
VERIFICATION_STATES = frozenset({STATE_APPROVED, STATE_PENDING, STATE_REJECTED, STATE_RETRY})

PATH_CODES = {
    "niqab": reasons.NIQAB_PATH_REQUESTED,
    "declined": reasons.CAMERA_DECLINED,
    "error": reasons.REVIEW_REQUESTED_AFTER_ERROR,
}

# ReviewError kinds, mapped to HttpsError codes by main.py.
INVALID = "invalid-argument"
PRECONDITION = "failed-precondition"
EXHAUSTED = "resource-exhausted"
NOT_FOUND = "not-found"


_sleep = time.sleep


def _now() -> dt.datetime:
    return dt.datetime.now(dt.timezone.utc)


class ReviewError(Exception):
    def __init__(self, kind: str, reason: str):
        super().__init__(reason)
        self.kind = kind
        self.reason = reason


# What a flag document may hold. Asserted by tests against every flag written,
# so a phone, an image or a raw number cannot quietly join it.
FLAG_FIELDS = frozenset(
    {
        "uid",
        "jobId",
        "state",
        "flags",
        "reasons",
        "id_hmac",
        "liveness_confidence",
        "match_similarity",
        "scoreScales",
        "route",
        "scheduledFor",
        "createdAt",
        "slaExpiresAt",
        "requestedWomanReviewer",
    }
)


class ReviewStore(Protocol):
    def verification_state(self, uid: str) -> Optional[str]: ...

    def set_verification_state(
        self,
        uid: str,
        state: str,
        *,
        route: Optional[str] = None,
        scheduled_for: Optional[dt.datetime] = None,
        decided: bool = False,
        reset_booking: bool = False,
    ) -> None: ...

    def uid_daily_count_and_increment(self, uid: str, field: str) -> int: ...

    def write_review_consent(self, uid: str, path: str) -> None: ...

    def review_consent_given(self, uids: list) -> set:
        """The subset of `uids` with users/{uid}/consents/review-v{N}."""
        ...

    def open_flag_id(self, uid: str) -> Optional[str]: ...

    def ocr_submissions(self, uid: str) -> int: ...

    def open_flag(
        self,
        uid: str,
        job_payload: Optional[dict],
        flag_payload: dict,
        *,
        job_id: Optional[str] = None,
        mark_duplicate: bool = False,
    ) -> tuple[str, bool]: ...

    def get_flag(self, flag_id: str) -> Optional[dict]: ...

    def list_open(self, limit: int) -> list[tuple[str, dict]]: ...

    def mark_scheduled(
        self,
        flag_id: str,
        route: str,
        when: dt.datetime,
        reviewer_uid: str,
        sla_expires_at: dt.datetime,
    ) -> None: ...

    def close_flag(
        self,
        flag_id: str,
        *,
        uid: str,
        state: str,
        reviewer_uid: str,
        reviewer_reason: str,
        id_hmac: Optional[str] = None,
    ) -> Optional[str]:
        """One transaction: re-read the flag, refuse unless PENDING_REVIEW
        (REVIEW_NOT_PENDING); with id_hmac, claim the registry for uid or
        refuse with the dedupe reason; then close the flag and its job and
        clear her openFlagId. Returns None on commit, else the reason code,
        having written nothing."""
        ...

    def stale_flags(self, now: dt.datetime, limit: int) -> list[tuple[str, dict]]: ...

    def expire_flag(self, flag_id: str, uid: str, now: dt.datetime) -> bool:
        """One transaction: expire only if still PENDING_REVIEW and still past
        its slaExpiresAt at `now`. True when it expired the flag."""
        ...

    def grant_bonus(self, uid: str, flag_id: str) -> bool: ...

    def mark_mint_pending(self, flag_id: str) -> None: ...

    def clear_mint_pending(self, flag_id: str) -> None: ...

    def mint_pending_flags(self, limit: int) -> list[tuple[str, str]]:
        """(flag_id, uid) for APPROVED flags whose mint has not landed."""
        ...

    def claim(self, id_hmac: str, uid: str) -> dedupe.DedupeVerdict: ...

    def mint_verified(self, uid: str) -> None: ...

    def phone_for(self, uid: str) -> Optional[str]: ...

    def log_access(self, reviewer_uid: str, flag_id: str, action: str) -> None: ...

    def pepper(self) -> bytes: ...

    def notify(self, flag_id: str, codes) -> None: ...

    def new_job_payload(self, uid: str, decision: decisions.Decision, attempt: int) -> dict: ...


def sla_deadline(now: Optional[dt.datetime] = None) -> dt.datetime:
    now = now or dt.datetime.now(dt.timezone.utc)
    return now + dt.timedelta(hours=config.REVIEW_SLA_HOURS)


def flag_payload(
    uid: str,
    job_id: Optional[str],
    decision: decisions.Decision,
    *,
    id_hmac: Optional[str] = None,
    liveness_confidence: Optional[float] = None,
    match_similarity: Optional[float] = None,
    now: Optional[dt.datetime] = None,
    created_at: Any = None,
) -> dict:
    """The flag document. Codes, scores and a scheduling handle; nothing else.

    `jobId` is filled in by the store when the job id is minted inside the
    transaction (the flag and the job share one id).
    """
    payload = {
        "uid": uid,
        "jobId": job_id,
        "state": decisions.PENDING_REVIEW,
        "flags": list(decision.flags),
        "reasons": list(decision.reasons),
        "id_hmac": id_hmac,
        # Scores, not images. A reviewer about to spend fifteen minutes on a
        # video call should see whether the case is borderline or nowhere near.
        "liveness_confidence": liveness_confidence,
        "match_similarity": match_similarity,
        "scoreScales": {
            "liveness": config.ACTIVE_THRESHOLDS.liveness_scale,
            "match": config.ACTIVE_THRESHOLDS.match_scale,
        },
        "route": None,
        "scheduledFor": None,
        "createdAt": created_at,
        "slaExpiresAt": sla_deadline(now),
        # She asked for the woman-reviewer route herself. Surfaced so the queue
        # can route it to a woman reviewer without asking her again.
        "requestedWomanReviewer": reasons.NIQAB_PATH_REQUESTED in decision.flags,
    }
    assert set(payload) <= FLAG_FIELDS
    return payload


# ------------------------------------------------------------- request


@dataclass(frozen=True)
class RequestResult:
    state: str
    flag_id: Optional[str] = None
    created: bool = False
    code: Optional[str] = None


def request(store: ReviewStore, uid: str, path: Any) -> RequestResult:
    """She asks for a woman reviewer: niqab, declined camera, or after an error.

    Records users/{uid}/consents/review-v1 = {version, at, path} first (N7):
    the request is the consent to be looked up and called. Wording PENDING
    COUNSEL.

    Takes no images and no frames, so there is nothing here to store or leak.
    At most one open flag per account: a second request returns the open one.
    """
    if not isinstance(path, str) or path not in config.REVIEW_REQUEST_PATHS:
        raise ReviewError(INVALID, reasons.INTERNAL_ERROR)

    state = store.verification_state(uid)
    if state == STATE_APPROVED:
        return RequestResult(STATE_APPROVED)
    if state == STATE_REJECTED:
        raise ReviewError(PRECONDITION, reasons.VERIFICATION_CLOSED)

    if store.uid_daily_count_and_increment(uid, "reviews") > config.PER_UID_DAILY_REVIEW_LIMIT:
        raise ReviewError(EXHAUSTED, reasons.PER_UID_DAILY_LIMIT)

    # N7: asking for the call is her consent to it. Recorded server-side
    # before any flag exists, so a woman who declined the camera at C09b is
    # never phoned without a record that she asked to be. Wording PENDING
    # COUNSEL (config.REVIEW_CONSENT_VERSION).
    store.write_review_consent(uid, path)

    code = PATH_CODES[path]
    decision = decisions.Decision(decisions.PENDING_REVIEW, (code,), (code,))
    job = store.new_job_payload(uid, decision, store.ocr_submissions(uid))
    flag_id, created = store.open_flag(uid, job, flag_payload(uid, None, decision))
    if created:
        store.set_verification_state(uid, STATE_PENDING, reset_booking=True)
        store.notify(flag_id, decision.flags)
    return RequestResult(STATE_PENDING, flag_id, created, code)


# ------------------------------------------------------------- reviewer


def _pending_flag_for(store: ReviewStore, reviewer_uid: str, flag_id: Any) -> dict:
    if not isinstance(flag_id, str) or not flag_id:
        raise ReviewError(INVALID, reasons.INTERNAL_ERROR)
    record = store.get_flag(flag_id)
    if record is None:
        raise ReviewError(NOT_FOUND, reasons.INTERNAL_ERROR)
    if record.get("state") != decisions.PENDING_REVIEW:
        raise ReviewError(PRECONDITION, reasons.REVIEW_NOT_PENDING)
    if record.get("uid") == reviewer_uid:
        raise ReviewError(PRECONDITION, reasons.REVIEWER_IS_SUBJECT)
    return record


def contact(store: ReviewStore, reviewer_uid: str, flag_id: Any) -> dict:
    """Her phone number, looked up from Firebase Auth at the moment of calling.

    Never copied onto the flag, never logged, never stored. Every lookup is
    written to the review access log, so a curious reviewer leaves a trace.

    R4: refused with review_consent_missing until she has asked for the call
    (request_review records users/{uid}/consents/review-v{N}). A flag the
    pipeline raised on its own carries no consent until she taps "Ask for the
    call" in the app.
    """
    record = _pending_flag_for(store, reviewer_uid, flag_id)
    if record["uid"] not in store.review_consent_given([record["uid"]]):
        raise ReviewError(PRECONDITION, reasons.REVIEW_CONSENT_MISSING)
    store.log_access(reviewer_uid, flag_id, "contact")
    phone = store.phone_for(record["uid"])
    if not phone:
        raise ReviewError(NOT_FOUND, reasons.INTERNAL_ERROR)
    return {"phone": phone}


def parse_when(value: Any) -> dt.datetime:
    """ISO-8601 with an explicit offset. A time with no zone is ambiguous."""
    if not isinstance(value, str) or not value:
        raise ReviewError(INVALID, reasons.INTERNAL_ERROR)
    try:
        when = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        raise ReviewError(INVALID, reasons.INTERNAL_ERROR)
    if when.tzinfo is None:
        raise ReviewError(INVALID, reasons.INTERNAL_ERROR)
    return when.astimezone(dt.timezone.utc)


def _as_utc(value: Any) -> Optional[dt.datetime]:
    if isinstance(value, dt.datetime):
        return value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)
    return None


def schedule(
    store: ReviewStore,
    reviewer_uid: str,
    flag_id: Any,
    route: Any,
    scheduled_for: Any,
    *,
    now: Optional[dt.datetime] = None,
) -> dict:
    """Book the live review. A booking may not be in the past (more than
    REVIEW_BOOKING_PAST_TOLERANCE_MINUTES ago). N6: a booking may be at most
    REVIEW_BOOKING_MAX_DAYS ahead, and it moves the flag's slaExpiresAt to the
    booked time plus REVIEW_BOOKING_GRACE_HOURS (never earlier than it was), so
    the expiry sweep cannot expire a booked review before the call."""
    if route not in config.REVIEW_ROUTES:
        raise ReviewError(INVALID, reasons.INTERNAL_ERROR)
    when = parse_when(scheduled_for)
    now = now or _now()
    if when < now - dt.timedelta(minutes=config.REVIEW_BOOKING_PAST_TOLERANCE_MINUTES):
        raise ReviewError(INVALID, reasons.REVIEW_TIME_OUT_OF_RANGE)
    if when > now + dt.timedelta(days=config.REVIEW_BOOKING_MAX_DAYS):
        raise ReviewError(INVALID, reasons.REVIEW_TIME_OUT_OF_RANGE)
    record = _pending_flag_for(store, reviewer_uid, flag_id)
    sla = when + dt.timedelta(hours=config.REVIEW_BOOKING_GRACE_HOURS)
    current = _as_utc(record.get("slaExpiresAt"))
    if current is not None and current > sla:
        sla = current
    store.mark_scheduled(flag_id, route, when, reviewer_uid, sla)
    store.set_verification_state(
        record["uid"], STATE_PENDING, route=route, scheduled_for=when
    )
    store.log_access(reviewer_uid, flag_id, f"schedule:{route}")
    return {"ok": True, "route": route}


def _hmac_from_typed_digits(store: ReviewStore, digits: Any, today: dt.date) -> str:
    """The NID the reviewer read on the live call, turned into the registry key.

    The digits exist only in this frame. They are never stored, logged or
    echoed; every refusal is a reason code.
    """
    if not isinstance(digits, str) or not digits.strip():
        raise ReviewError(PRECONDITION, reasons.NID_UNREADABLE)
    parsed, failure = nid.first_valid(digits, today=today)
    if parsed is None:
        raise ReviewError(PRECONDITION, failure or reasons.NID_UNREADABLE)
    try:
        if parsed.sex_from_digit != "female":
            raise ReviewError(PRECONDITION, reasons.SEX_DIGIT_MALE)
        age = parsed.age_on(today)
        if age < config.MIN_AGE:
            raise ReviewError(PRECONDITION, reasons.UNDERAGE)
        if age > config.MAX_AGE_PLAUSIBLE:
            raise ReviewError(PRECONDITION, reasons.AGE_IMPLAUSIBLE)
        return dedupe.hash_and_forget(parsed.number, store.pepper())
    finally:
        del parsed


@dataclass(frozen=True)
class DecideResult:
    outcome: str
    uid: str
    reasons: tuple


def decide(
    store: ReviewStore,
    reviewer_uid: str,
    flag_id: Any,
    approve: bool,
    nid_digits: Any = None,
    *,
    today: Optional[dt.date] = None,
) -> DecideResult:
    """Record the outcome of a live review. S19.

    Refuses unless the flag is still PENDING_REVIEW, the reviewer is not the
    woman being reviewed, and a live review was booked. Approval claims the
    registry in the same transaction that closes the flag: if the claim fails
    (the card belongs to another account, or the registration is closed) or
    the flag is no longer pending, nothing is written, nothing is minted and
    the flag stays as it was.
    """
    record = _pending_flag_for(store, reviewer_uid, flag_id)
    uid = record["uid"]
    if record.get("route") not in config.REVIEW_ROUTES:
        # A decision with no booked review behind it is a desk decision on a
        # case there is no evidence for, which this design removes.
        raise ReviewError(PRECONDITION, reasons.INTERNAL_ERROR)

    # N10: the flag is re-read and closed in ONE transaction keyed on
    # state == PENDING_REVIEW (with the registry claim, on approval), so two
    # reviewers, or a reviewer and the expiry sweep, cannot both decide it.
    # Nothing is minted and her state is not written unless it commits.
    if approve:
        id_hmac = record.get("id_hmac")
        if not id_hmac:
            id_hmac = _hmac_from_typed_digits(
                store, nid_digits, today or dt.date.today()
            )
        nid_digits = None
        refusal = store.close_flag(
            flag_id,
            uid=uid,
            state=decisions.APPROVED,
            reviewer_uid=reviewer_uid,
            reviewer_reason=reasons.REVIEWER_APPROVED,
            id_hmac=id_hmac,
        )
        if refusal:
            raise ReviewError(PRECONDITION, refusal)
        # The approval is committed. A failed mint must not lose it: retry a
        # few times here, then leave mintPending on the flag for the hourly
        # job (retry_pending_mints).
        if not _mint_and_approve(store, uid):
            store.mark_mint_pending(flag_id)
        outcome = decisions.APPROVED
        codes = (reasons.REVIEWER_APPROVED,)
    else:
        refusal = store.close_flag(
            flag_id,
            uid=uid,
            state=decisions.REJECTED_FAILED,
            reviewer_uid=reviewer_uid,
            reviewer_reason=reasons.REVIEWER_REJECTED,
        )
        if refusal:
            raise ReviewError(PRECONDITION, refusal)
        store.set_verification_state(uid, STATE_REJECTED, decided=True)
        outcome = "rejected"
        codes = (reasons.REVIEWER_REJECTED,)
    store.log_access(reviewer_uid, flag_id, "decide")
    return DecideResult(outcome, uid, codes)


def _mint_and_approve(store: ReviewStore, uid: str, attempts: Optional[int] = None) -> bool:
    """Mint the verified claim (merge, never replace: store.mint_claims) and
    write her state approved. True once both landed."""
    attempts = attempts or config.MINT_ATTEMPTS
    for attempt in range(attempts):
        try:
            store.mint_verified(uid)
            store.set_verification_state(uid, STATE_APPROVED, decided=True)
            return True
        except Exception:
            if attempt + 1 < attempts:
                backoff = config.MINT_RETRY_BACKOFF_SEC
                _sleep(backoff[min(attempt, len(backoff) - 1)])
    return False


def retry_pending_mints(store: ReviewStore, limit: int = 100) -> int:
    """The hourly job's half of the mint retry: finish every APPROVED flag
    still marked mintPending, then clear the mark. Returns how many landed."""
    done = 0
    for flag_id, uid in store.mint_pending_flags(limit):
        if uid and _mint_and_approve(store, uid, attempts=1):
            store.clear_mint_pending(flag_id)
            done += 1
    return done


def list_open(store: ReviewStore, reviewer_uid: str, limit: int = 50) -> list[dict]:
    """The queue: codes, scores and a handle. Never an image, never a phone."""
    rows = []
    open_flags = store.list_open(limit)
    consented = store.review_consent_given(
        sorted({data.get("uid") for _, data in open_flags if data.get("uid")})
    )
    for flag_id, data in open_flags:
        rows.append(
            {
                "flagId": flag_id,
                "flags": data.get("flags", []),
                "reasons": data.get("reasons", []),
                "livenessConfidence": data.get("liveness_confidence"),
                "matchSimilarity": data.get("match_similarity"),
                "scoreScales": data.get("scoreScales"),
                "route": data.get("route"),
                "scheduledFor": str(data.get("scheduledFor") or ""),
                "createdAt": str(data.get("createdAt")),
                "slaExpiresAt": str(data.get("slaExpiresAt") or ""),
                "requestedWomanReviewer": reasons.NIQAB_PATH_REQUESTED
                in data.get("flags", []),
                # Whether approving needs the NID read on the live call. The
                # hash itself never leaves the server.
                "needsNidOnCall": not data.get("id_hmac"),
                # R4: whether she asked for the call. A boolean only; the
                # reviewer may not fetch her phone until it is true.
                "consentGiven": data.get("uid") in consented,
            }
        )
    store.log_access(reviewer_uid, "*", "list")
    return rows


# ------------------------------------------------------------- expiry


def expire(store: ReviewStore, now: dt.datetime, limit: int = 200) -> int:
    """Past the SLA a flag becomes RETRY_REQUIRED: our failure, not hers.

    S7: she earns exactly one more OCR submission per expired flag, and only
    while a whole submission still fits under COST_CAP_MICRO_USD. Nothing is
    ever reset.
    """
    count = 0
    for flag_id, data in store.stale_flags(now, limit):
        uid = data.get("uid")
        # N10: re-checked inside the transaction. A flag booked (SLA moved)
        # or decided since the query is left alone.
        if not store.expire_flag(flag_id, uid, now):
            continue
        if uid:
            # N6: the booking expired with the flag; C14 must not keep
            # showing a call time that is no longer going to happen.
            store.set_verification_state(uid, STATE_RETRY, reset_booking=True)
            store.grant_bonus(uid, flag_id)
        count += 1
    return count
