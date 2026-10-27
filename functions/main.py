"""Own Hub identity verification — Cloud Functions entry points.

===============================================================================
IMAGES ARE NEVER WRITTEN ANYWHERE.
===============================================================================

The ID card images and the selfie frames arrive in the request body, exist as
Python bytes for the length of one function invocation, and are gone when it
returns. They are not written to Cloud Storage. They are not written to
Firestore. They are not written to a temporary file, a cache, a log line, a
crash report or an analytics event. There is no cleanup job for them because
there is nothing to clean up, and there is no bucket to misconfigure because
there is no bucket.

This is the single most important property of the design, and it is deliberate.
In July 2025 the Tea app leaked roughly 72,000 images — including about 13,000
selfies and photo IDs submitted for exactly this kind of verification — from a
Firebase Storage bucket that was left publicly readable. The images were the
whole breach. Every control that failed there (bucket ACLs, a deletion job that
was supposed to run, a retention policy) is a control this design does not need,
because the data those controls were protecting never comes to rest.

THERE IS NO EXCEPTION.
Spec §4's allowlist permits an evidence bundle for flagged cases. The owner has
decided against it: no image is stored, in any bucket, for any duration, for any
case. The bundle write path, the dedicated bucket, the lifecycle rule and the
hourly purge job were built and then DELETED rather than left behind a disabled
flag — a dormant code path that writes ID images to a bucket is exactly the
thing that gets switched on by accident a year later. AUDIT.md records this as a
conscious deviation from §4 rather than a gap.

Three consequences worth stating, because they constrain what can be built on
top of this and someone will eventually want to:

  * **A human reviewer cannot see her face — so review is a live encounter.**
    By the time a flagged case reaches the queue, the images no longer exist.
    Review is therefore a video call with a woman reviewer, or a ladies-only gym
    visit; the queue schedules and records those, it does not display evidence.
    The reviewer sees reason codes, scores and a scheduling handle. This is what
    review IS here, not a degraded version of looking at a photograph.
  * **There is no re-scoring.** If a threshold is retuned, past decisions cannot
    be replayed against the new numbers, because the inputs are gone. Spec §10's
    pilot is where calibration data comes from, collected with consent.
  * **A support escalation cannot "look at what she sent".** There is nothing to
    look at. This is the point.

===============================================================================

Callables, in the order a woman meets them:

    record_legal_acceptance   free    Terms and Privacy accepted at C06
    record_consent            free    spec §2 step 1, before any camera
    start_verification        free    mints the single-use liveness session
    verify_identity           paid    the whole pipeline, one round trip
    list_verification_flags   admin   the review queue: codes, scores, handle
    schedule_verification_review    woman reviewer books a call or a gym visit
    decide_verification_flag        records the outcome of that live review
    expire_stale_reviews      hourly  72-hour SLA -> RETRY_REQUIRED
    admin_dashboard           admin   counts only, for the owner's console
    admin_logs                admin   codes and times, a page at a time
    record_meal_photo_consent free    E12, before her first meal photo
    analyze_meal_photo        paid    E12/E13, one photo to foods, grams, macros
    register_for_event        free    reserves her seat on a published event
    cancel_event_registration free    gives that seat back
    list_events_admin         admin   events with their seats, for the dashboard
    save_event                admin   creates or edits an event
    submit_community_food     free    offers a confirmed meal to every woman
    list_community_foods      admin   candidates and the published foods
    review_community_food     admin   approves or rejects one candidate

Wire contract, agreed with the Flutter worker:
    `verify_identity` takes {front, back, frames, liveness:{sessionId}} and
    returns {outcome, reasons}. `liveness.outcome`, if a client sends one, is
    IGNORED — see the note on `verify_identity`. `reasons` carries only the
    coarse user-safe hints from reasons.to_user_safe, never internal codes.

Every callable checks, in this order and before doing any work: App Check,
authentication, consent where required, attempt limits, the cost ledger. Spec §5.
"""

from __future__ import annotations

import base64
import hashlib
import os
import time
import uuid
from typing import Any, Optional

import firebase_admin
from firebase_functions import firestore_fn, https_fn, options, scheduler_fn

from identity import (
    approvals,
    config,
    decisions,
    imagesize,
    pipeline,
    providers,
    logs,
    reasons,
    review,
    scheduling,
    store,
    webhook,
)

firebase_admin.initialize_app()

# 512 MiB for every function: they read and write Firestore and Auth, and the
# waitlist already runs at 256. verify_identity alone asks for 1 GiB below,
# for the face model. Memory is billed per second, so this halves the cost of
# every other call.
options.set_global_options(
    region=config.REGION,
    memory=options.MemoryOption.MB_512,
    timeout_sec=config.TIMEOUT_SEC,
    max_instances=config.MAX_INSTANCES,
)

# App Check is enforced in `_require_auth`, NOT through `enforce_app_check=` on
# the decorators (R3). With the decorator flag on, firebase-functions 0.6.0
# answers a missing or invalid token with UNAUTHENTICATED "Unauthenticated"
# before this code runs, so a phone that fails Play Integrity could never be
# told the real cause. With it off the framework still VERIFIES any token sent
# (firebase_functions/private/util.py `_on_call_check_app_token` calls
# app_check.verify_token) and sets `request.app` only for a token that passed;
# missing and invalid both leave it None. config.ENFORCE_APP_CHECK stays True
# and the check stays fail-closed: no work and no billing without a valid token.


# ----------------------------------------------------------------- helpers


# N1: sign-in providers each kind of caller may use. Email/password, Google and
# Apple are enabled in the console, so the women-facing callables check the
# provider themselves. Staff (reviewers, admins) may also use a password.
USER_PROVIDERS = ("phone",)
STAFF_PROVIDERS = ("phone", "password")


def _sign_in_provider(request: https_fn.CallableRequest) -> Optional[str]:
    token = request.auth.token or {}
    firebase = token.get("firebase") if isinstance(token, dict) else None
    if not isinstance(firebase, dict):
        return None
    return firebase.get("sign_in_provider")


def _local_emulator() -> bool:
    """True only inside the Firebase emulator suite on a developer machine.
    The Python SDK cannot verify an App Check token there, so the gate below
    steps aside. It needs the emulator flag and BOTH emulator hosts on this
    machine's loopback: a deployed service pointed at a loopback database
    could not work at all, so no production setting can satisfy it."""
    env = os.environ

    def loopback(name: str) -> bool:
        host = env.get(name, "").rsplit(":", 1)[0].strip("[]")
        return host in ("127.0.0.1", "localhost", "::1")

    return (
        env.get("FUNCTIONS_EMULATOR") == "true"
        and loopback("FIRESTORE_EMULATOR_HOST")
        and loopback("FIREBASE_AUTH_EMULATOR_HOST")
    )


def _require_auth(
    request: https_fn.CallableRequest,
    providers: Optional[tuple] = USER_PROVIDERS,
) -> str:
    """App Check, then authentication, then the sign-in provider (N1).

    This is THE App Check gate (R3). Every callable calls this (directly or
    through the reviewer and admin guards) before any other work.
    `request.app` is None for a missing or an invalid token, so both get
    FAILED_PRECONDITION app_check_missing, which the app can show her as the
    real cause.

    `providers` defaults to phone only. None skips the provider check, which
    only delete_account uses: anyone with an account may erase it.
    """
    if config.ENFORCE_APP_CHECK and request.app is None and not _local_emulator():
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.APP_CHECK_MISSING
        )
    if request.auth is None or not request.auth.uid:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED, reasons.UNAUTHENTICATED
        )
    if providers is not None and _sign_in_provider(request) not in providers:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.PHONE_SIGN_IN_REQUIRED
        )
    return request.auth.uid


def _is_store_reviewer(request: https_fn.CallableRequest, uid: str) -> bool:
    """M13: a store review account, by uid or by the phone number in her
    verified ID token. The number matters because a reviewer who deletes her
    account and signs in again with the same test number gets a new uid. Both
    lists live in Secret Manager and are empty (nobody) on any failure."""
    if uid in store.store_reviewer_uids():
        return True
    token = request.auth.token if request.auth is not None else None
    phone = token.get("phone_number") if isinstance(token, dict) else None
    if not isinstance(phone, str) or not phone:
        return False
    return phone in store.store_reviewer_phones()


def _decode_image(value: Any, budget_left: dict) -> bytes:
    """One base64 image, size-checked BEFORE it is decoded.

    The order matters. Checking the length of the base64 string first means a
    decompression bomb is refused without ever materialising in memory;
    decoding first and checking after would already have allocated it.
    """
    if not isinstance(value, str) or not value:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_UNDECODABLE
        )
    # 4 base64 characters carry 3 bytes.
    approximate = (len(value) * 3) // 4
    if approximate > config.MAX_IMAGE_BYTES:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_TOO_LARGE
        )
    budget_left["total"] = budget_left.get("total", 0) + approximate
    if budget_left["total"] > config.MAX_TOTAL_BYTES:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_TOO_LARGE
        )
    try:
        raw = base64.b64decode(value, validate=True)
    except Exception:
        # Bare, and nothing from the exception propagates: a base64 error
        # message can quote the offending input, which here is image data.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_UNDECODABLE
        )
    # T24: a header declaring more pixels than the ceiling is a decompression
    # bomb. Refused here, before any paid call and before any pixel decode.
    # Only the too-large case is refused at the door; bytes with no readable
    # header are refused by faces.decode, which never decodes them either.
    if imagesize.refusal(raw) == reasons.IMAGE_TOO_LARGE:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_TOO_LARGE
        )
    return raw


def _install_hash(raw: Optional[str]) -> Optional[str]:
    """Hash the client's install id before it is ever stored.

    Spec §3 wants "the same app install has attempted more than 2 different
    id_hmac values" as a flag signal, which needs a stable per-install key. It
    does NOT need that key to be readable. Hashing it means the collection that
    implements the signal is not a device-tracking database even for someone who
    obtains it.

    Honest about the limit: the install id comes from the client and is
    therefore forgeable. This raises the cost for an unsophisticated attacker
    and bounds the damage of an accident. App Check is the control that actually
    resists automation, which is why config.ENFORCE_APP_CHECK is True.
    """
    if not raw or not isinstance(raw, str):
        # Not a string means a client sending a number, an object or a list in
        # this field. There is nothing to hash and nothing worth failing the
        # request over: the install id is a FLAG signal, not a control, so the
        # honest answer is the same as sending nothing at all.
        return None
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


def _operation_id(raw: Any) -> str:
    """The client's idempotency key, bounded and typed.

    It is used as a Firestore field value and stored in a list of the last 50 on
    the ledger document, which is capped at 1 MiB. An unbounded string from the
    request body is therefore a way to make that document large enough to start
    failing writes for the account it belongs to — which would jam the very
    counter that limits her spend.

    128 characters is well beyond any real idempotency key (a UUID is 36) and
    far short of anything that matters to a 1 MiB budget. Anything longer, or
    anything that is not a string, is treated as absent and a server-generated
    id is used — refusing the request outright would fail a verification over a
    field the client can regenerate.
    """
    if isinstance(raw, str) and 0 < len(raw) <= 128:
        return raw
    return str(uuid.uuid4())


def _ms(started: float) -> int:
    return int((time.monotonic() - started) * 1000)


def _response(decision: decisions.Decision) -> dict:
    """The agreed wire envelope: `{outcome, reasons}`.

    Spec §3 forbids telling her which check failed, because a precise error
    message teaches bypass. The Flutter worker's contract asks for a `reasons`
    array, so the key stays and its CONTENTS change: `reasons.to_user_safe`
    collapses 28 internal codes onto 5 actionable hints, many-to-few, so the
    mapping cannot be inverted. A man rejected by the sex gate gets an empty
    `reasons` array, because there is no honest hint to give him and inventing
    one would be the leak this exists to prevent.

    `refreshToken` is not decoration. Custom claims only reach the client's ID
    token on refresh, so without the app calling `getIdToken(true)` it would
    show an unverified state to a woman who was just verified, until the token
    happened to roll over an hour later.
    """
    return {
        "outcome": decision.outcome,
        "reasons": reasons.to_user_safe(decision.reasons),
        "refreshToken": decision.outcome == decisions.APPROVED,
    }


def _deps() -> pipeline.Deps:
    """The live wiring. Self-hosted providers; the AWS slot is unfilled."""
    # Imported here, not at the top: it loads OpenCV and numpy, which only the
    # two verification calls use. Every other function starts without them.
    from identity import providers_selfhosted

    # One FirestoreChallengeStore, not two. They are stateless and two instances
    # behave identically, but binding `put` and `take` off separate objects
    # reads as though the mint and the consume might touch different state,
    # which is the one thing about a single-use session that must be obviously
    # untrue.
    challenges = store.FirestoreChallengeStore()
    liveness = providers_selfhosted.SelfHostedLiveness(
        store=providers_selfhosted.ChallengeStore(
            put=challenges.put,
            take=challenges.take,
        )
    )
    return pipeline.Deps(
        ocr=providers_selfhosted.VisionOcr(),
        liveness=liveness,
        face_match=providers_selfhosted.SelfHostedFaceMatch(),
        ledger_store=store.FirestoreLedger(),
        registry=store.FirestoreRegistry(),
        pepper=store.pepper(),
        behaviour=store.FirestoreBehaviour(),
        thresholds=config.ACTIVE_THRESHOLDS,
    )


# -------------------------------------------------------------- the flow


@https_fn.on_call()
def record_consent(request: https_fn.CallableRequest) -> dict:
    """Spec §2 step 1: persisted before any camera access.

    The consent version and a timestamp, plus (version 2) the language the
    wording was shown in and the app version, when the client sends them in
    an allowed shape. Not the text, not her IP, not her device. The version
    is what ties the record to what she was actually shown, which is why
    config.CONSENT_VERSION must be bumped whenever that text changes.
    """
    uid = _require_auth(request)
    payload = _payload(request)
    data = payload if isinstance(payload, dict) else {}
    version = data.get("consentVersion")
    if version != config.CONSENT_VERSION:
        # A client agreeing to a version we do not recognise has been shown
        # something we cannot account for. Refusing is the honest answer.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )
    # S21: agreeing twice is a no-op. The first record already proves what she
    # was shown and when; a second write would only move the timestamp and
    # let a tight loop turn this callable into a free Firestore write pump.
    if not store.has_consent(uid):
        store.write_consent(uid, data.get("locale"), data.get("appVersion"))
    return {"ok": True, "consentVersion": config.CONSENT_VERSION}


@https_fn.on_call()
def record_pledge(request: https_fn.CallableRequest) -> dict:
    """C16: she agreed to the community's three rules.

    Request {version, locale, appVersion}. The version must be the server's
    current one (config.PLEDGE_VERSION); any other is agreement to rules we
    cannot account for and is refused with consent_missing. Recorded once at
    users/{uid}/consents/pledge-v{N}; agreeing again changes nothing. A locale
    or app version of the wrong shape is left out rather than stored.
    """
    uid = _require_auth(request)
    data = _body(request)
    version = data.get("version")
    if isinstance(version, bool) or version != config.PLEDGE_VERSION:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )
    store.write_pledge(uid, data.get("locale"), data.get("appVersion"))
    return {"ok": True, "version": config.PLEDGE_VERSION}


@https_fn.on_call()
def record_legal_acceptance(request: https_fn.CallableRequest) -> dict:
    """M1: she accepted the Terms of Use and the Privacy Policy at C06.

    Request {termsVersion, privacyVersion, locale, appVersion, platform,
    acceptedAtMs}. The versions must be the server's current ones; anything
    else is acceptance of words we cannot account for and is refused with
    consent_missing, which tells the app to show the update sheet. Recorded
    once at users/{uid}/consents/legal-t{T}-p{P}: accepting the same versions
    again changes nothing. Not gated on verification, because she accepts
    before the check.
    """
    uid = _require_auth(request)
    data = _payload(request)
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    if (
        data.get("termsVersion") != config.TERMS_VERSION
        or data.get("privacyVersion") != config.PRIVACY_VERSION
    ):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )
    locale = data.get("locale")
    app_version = data.get("appVersion")
    platform = data.get("platform")
    accepted_at = data.get("acceptedAtMs")
    if (
        not store.valid_locale(locale)
        or not store.valid_app_version(app_version)
        or platform not in config.LEGAL_PLATFORMS
        or isinstance(accepted_at, bool)
        or not isinstance(accepted_at, int)
        or accepted_at <= 0
    ):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    if not store.has_legal_acceptance(uid):
        store.write_legal_acceptance(uid, locale, app_version, platform, accepted_at)
    return {
        "ok": True,
        "termsVersion": config.TERMS_VERSION,
        "privacyVersion": config.PRIVACY_VERSION,
    }


@https_fn.on_call()
def record_health_consent(request: https_fn.CallableRequest) -> dict:
    """S17: her separate consent to back up health data to the cloud.

    Request {consentVersion: 1, granted: bool}. Granting records
    users/{uid}/consents/health-v1 with state "granted"; the rules refuse
    cycle, period, check-in, measurement, life-stage and allergy writes until
    it exists. Withdrawing records "withdrawn" and deletes the cloud copy of
    those collections and profile keys. Not gated on verification: it is a
    privacy control (Protected List 6).
    """
    uid = _require_auth(request)
    data = _payload(request) or {}
    if not isinstance(data, dict) or not isinstance(data.get("granted"), bool):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    if data.get("consentVersion") != config.HEALTH_CONSENT_VERSION:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )
    granted = data["granted"]
    store.write_health_consent(uid, granted)
    if not granted:
        store.purge_health_data(uid)
    state = "granted" if granted else "withdrawn"
    logs.decision("record_health_consent", state=state)
    return {"ok": True, "state": state}


@https_fn.on_call()
def start_verification(request: https_fn.CallableRequest) -> dict:
    """Mint a single-use, uid-bound liveness session.

    The challenge sequence is chosen HERE, by the server, with `secrets`. A
    client-chosen challenge is no challenge at all: an attacker who picks the
    sequence can pre-record it.
    """
    uid = _require_auth(request)

    if not store.has_consent(uid):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )

    gate = store.verification_gate(uid)
    if gate.state == review.STATE_REJECTED:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.VERIFICATION_CLOSED
        )
    if gate.open_flag_id:
        # A review is already waiting for her. The client routes this to C14.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.REVIEW_ALREADY_OPEN
        )

    # M13: a store review account still gets a real session, so the app's
    # camera screens run as they do for everyone, but it is not counted
    # against the daily limits or the cost ledger. verify_identity approves
    # it without reading a frame.
    if not _is_store_reviewer(request, uid):
        # S6: her own daily allowance first, so one account can never run the
        # global counter up for everyone else.
        if (
            store.uid_daily_count_and_increment(uid, "starts")
            > config.PER_UID_DAILY_START_LIMIT
        ):
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, reasons.PER_UID_DAILY_LIMIT
            )

        # Spec §6's global kill switch, checked before anything is minted.
        if store.daily_count_and_increment() > config.DAILY_VERIFICATION_LIMIT:
            logs.warn("daily_limit_reached", field="sessions")
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, reasons.DAILY_LIMIT_REACHED
            )

        budget = store.FirestoreLedger().read(uid)
        if budget.remaining <= 0:
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, reasons.COST_CAP_REACHED
            )

    deps = _deps()
    session_id = deps.liveness.create_session(uid)
    snapshot = store.db().collection(config.COL_SESSIONS).document(session_id).get()
    steps = (snapshot.to_dict() or {}).get("steps", [])

    return {
        "sessionId": session_id,
        "steps": steps,
        "expiresInSec": config.CHALLENGE_TTL_SEC,
    }


@https_fn.on_call(
    memory=options.MemoryOption.GB_1,
    max_instances=config.VERIFY_MAX_INSTANCES,
)
def verify_identity(request: https_fn.CallableRequest) -> dict:
    """The whole of spec §2 steps 3 to 8, in one round trip.

    Request, as agreed with the Flutter worker:
        front       str        base64 JPEG, card front
        back        str        base64 JPEG, card back — carries النوع
        frames      [str]      3-8 base64 selfie frames, one per challenge step
        liveness    {sessionId: str}
        niqabPath   bool       she asked for a woman reviewer
        installId   str        hashed before it is stored
        operationId str        idempotency key for a double tap

    **`liveness.outcome` is ignored if present, deliberately and completely.**
    The Flutter worker's first draft of this contract had the client sending a
    liveness outcome. A client that reports its own verification result is the
    cheapest possible attack on this system: a patched APK sends
    `{"outcome": "pass"}` and walks in. Rule of engagement 3 forbids making the
    client the source of truth for any verification outcome, so the field is not
    read, not logged, and not stored. The outcome is computed here, from the
    frames, by the server.

    Response: `{outcome, reasons, refreshToken}`. See `_response`.
    """
    started = time.monotonic()
    uid = _require_auth(request)
    data = _payload(request) or {}
    if not isinstance(data, dict):
        # A callable body is whatever the client put in `data`. A list or a
        # string reaches here just as easily as an object and would turn every
        # `.get` below into an AttributeError, which the functions framework
        # renders as INTERNAL — a 500 for what is plainly a bad request, and a
        # stack trace in the logs for something that deserves one line.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )

    if not store.has_consent(uid):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )

    # M13: a store review account on the owner's allow-list (Secret Manager,
    # empty by default) is approved without the pipeline. No image is read,
    # nothing is billed, and every use is logged and recorded. Nobody else
    # can reach this branch: the lists are server-side and fail closed.
    if _is_store_reviewer(request, uid):
        store.mint_claims(uid, True)
        store.write_user_verification(uid)
        store.FirestoreReviewStore().log_access(uid, "store-review", "reviewerBypass")
        logs.warn("reviewer_bypass")
        return {"outcome": decisions.APPROVED, "reasons": [], "refreshToken": True}

    # Closed or already waiting, decided before any counter moves or any byte
    # is decoded. S7: one open flag per uid, and a rejected account is final.
    gate = store.verification_gate(uid)
    if gate.state == review.STATE_REJECTED:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.VERIFICATION_CLOSED
        )
    if gate.open_flag_id:
        logs.decision(
            "verify_identity",
            outcome=decisions.PENDING_REVIEW,
            reasons=[reasons.REVIEW_ALREADY_OPEN],
            latencyMs=_ms(started),
        )
        return {
            "outcome": decisions.PENDING_REVIEW,
            "reasons": [],
            "refreshToken": False,
        }

    # S6: her own daily allowance before the global counter. Order:
    # auth, body, consent, closed/open review, per-uid cap, global, decode.
    if (
        store.uid_daily_count_and_increment(uid, "verifies")
        > config.PER_UID_DAILY_VERIFY_LIMIT
    ):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, reasons.PER_UID_DAILY_LIMIT
        )

    # Spec §6's global kill switch, on the door that actually costs money.
    #
    # start_verification also checks it, but start_verification is free: it
    # mints a challenge and writes one Firestore document. THIS is the callable
    # that calls Cloud Vision, and nothing in the pipeline requires a session to
    # have been minted first — OCR is step 3 and the liveness session is not
    # consulted until step 6 — so a caller that never touches
    # start_verification reached both paid Vision calls with the global limit
    # never once consulted.
    #
    # Checked here, before the base64 is decoded, so a refused request costs one
    # Firestore transaction rather than 24 MB of decoding as well.
    if (
        store.daily_count_and_increment(store.DAILY_VERIFY_FIELD)
        > config.DAILY_VERIFICATION_LIMIT
    ):
        # The alert policy in firebase/ops/kill-switch-alert-policy.json
        # matches this event.
        logs.warn("daily_limit_reached", field=store.DAILY_VERIFY_FIELD)
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, reasons.DAILY_LIMIT_REACHED
        )

    # THE FRAME COUNT IS CHECKED BEFORE ANYTHING IS DECODED.
    #
    # The count used to be validated after the whole list had been decoded, and
    # only on the non-niqab path — so `{"niqabPath": true, "frames": [...1000
    # frames...]}` was decoded in full and never counted at all. The per-image
    # and total-bytes ceilings bounded the memory, but nothing bounded the
    # number of base64 decodes, and the work was done before the request could
    # be refused. Refusing on a list length is free.
    raw_frames = data.get("frames") or []
    if not isinstance(raw_frames, list):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_UNDECODABLE
        )
    if len(raw_frames) > config.MAX_SELFIE_FRAMES:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_TOO_LARGE
        )

    sizes: dict = {}
    card_front = _decode_image(data.get("front"), sizes)
    card_back = _decode_image(data.get("back"), sizes)
    frames = [_decode_image(frame, sizes) for frame in raw_frames]

    # Only the session id is taken from the client's `liveness` object. Anything
    # else it contains — notably an `outcome` — is discarded here and never
    # reaches the pipeline. The isinstance guard is because `liveness` is
    # attacker-controlled like everything else in the body: a string here would
    # otherwise raise AttributeError and surface as a 500.
    liveness_block = data.get("liveness")
    session_id = (
        liveness_block.get("sessionId") if isinstance(liveness_block, dict) else None
    )
    if session_id is not None and not isinstance(session_id, str):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.SESSION_MISSING
        )

    niqab = bool(data.get("niqabPath"))
    # The upper bound was enforced above, before decoding. This is the floor,
    # and it applies only off the niqab path: a woman who asked for a woman
    # reviewer sends no frames at all and the pipeline returns before liveness.
    if not niqab and len(frames) < config.MIN_SELFIE_FRAMES:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.LIVENESS_FAILED
        )

    inputs = pipeline.Inputs(
        uid=uid,
        card_front=card_front,
        card_back=card_back,
        liveness_session_id=session_id,
        selfie_frames=frames,
        niqab_path_requested=niqab,
        install_id_hash=_install_hash(data.get("installId")),
        operation_id=_operation_id(data.get("operationId")),
    )

    # While this call runs, request_review refuses (VERIFICATION_IN_PROGRESS):
    # the automatic check decides first, so a reviewer request cannot open a
    # flag beside an approval that lands a moment later.
    _mark_verifying(uid)
    try:
        decision, job_id = _decide_and_commit(uid, inputs, gate)
    finally:
        _clear_verifying(uid)

    # The images go out of scope here and are collected. Nothing above wrote
    # them anywhere; this is belt and braces on an already-empty promise.
    del card_front, card_back, frames, inputs
    logs.decision(
        "verify_identity",
        outcome=decision.outcome,
        reasons=list(decision.reasons),
        latencyMs=_ms(started),
        jobId=job_id,
    )
    return _response(decision)


def _mark_verifying(uid: str) -> None:
    """Best effort: a marker that cannot be written must not stop her check."""
    try:
        store.mark_verify_in_flight(uid)
    except Exception:
        logs.warn("verify_marker_failed", step="mark")


def _clear_verifying(uid: str) -> None:
    """Best effort: the marker expires by itself (config.VERIFY_IN_FLIGHT_SEC)."""
    try:
        store.clear_verify_in_flight(uid)
    except Exception:
        logs.warn("verify_marker_failed", step="clear")


def _decide_and_commit(uid: str, inputs, gate):
    """The pipeline, the registry claim, and every write of its outcome.

    No write here may turn an `approved` state back: the review flag's
    `pending` and a final `rejected` are both written with keep_approved.
    """
    deps = _deps()
    outcome = pipeline.run(inputs, deps)
    decision = outcome.decision

    # Step 5's registry claim happens only on approval. A card that failed a
    # face match must not burn its own registry slot — she will be back with a
    # better photograph, and finding her own card already taken would be the
    # most infuriating possible bug.
    if decision.outcome == decisions.APPROVED and outcome.id_hmac:
        verdict = deps.registry.claim(outcome.id_hmac, uid)
        if not verdict.ok:
            # Lost a race with another account between the read and the claim.
            decision = decisions.Decision(
                decisions.REJECTED_DUPLICATE, (verdict.reason or reasons.DUPLICATE_ID,)
            )

    # S7: the first duplicate gets exactly one human review, because a woman
    # whose card was registered by someone else needs a human path. A second
    # duplicate is final. REGISTRATION_CLOSED is not reviewable at all.
    duplicate_review = (
        decision.outcome == decisions.REJECTED_DUPLICATE
        and reasons.DUPLICATE_ID in decision.reasons
        and not gate.duplicate_flag_raised
    )
    if duplicate_review:
        decision = decisions.Decision(
            decisions.PENDING_REVIEW, (reasons.DUPLICATE_ID,), (reasons.DUPLICATE_ID,)
        )

    # N3: a failed liveness or face match with no attempts left is the machine
    # being unable to tell, not a finding that she is not who she says. The
    # brief promises a human review call when the automatic check is unsure, so
    # it opens one review flag (one open flag per uid, state pending) instead of
    # closing the account. `rejected` is kept for NOT_ELIGIBLE (digit 13 and the
    # printed sex word agree, or underage), the second duplicate, and an
    # explicit reviewer reject.
    failed_check = decision.outcome == decisions.REJECTED_FAILED
    if failed_check:
        decision = decisions.Decision(
            decisions.PENDING_REVIEW, decision.reasons, decision.reasons
        )

    attempt = deps.ledger_store.read(uid).ocr_submissions
    if decision.outcome == decisions.PENDING_REVIEW:
        job_id = _raise_flag(
            uid, decision, outcome, attempt, mark_duplicate=duplicate_review
        )
    else:
        job_id = store.write_job(uid, decision, outcome, attempt)

    if outcome.unknown_governorate_code:
        # She is not flagged for this and never should be: an unknown code is a
        # gap in nid.GOVERNORATES or a misread of digits 8-9, not a fact about
        # her. But the gap has to become visible to somebody, and the job
        # document deliberately records only the reason code, never the digits.
        # This counter is the one place the digits survive, with no uid attached
        # and no way back to a person. See store.UNKNOWN_GOVERNORATE_DOC.
        store.record_unknown_governorate(outcome.unknown_governorate_code)

    if decision.outcome == decisions.APPROVED:
        store.mint_claims(uid, True)
        store.write_user_verification(uid)
    elif decision.outcome in (
        decisions.REJECTED_NOT_ELIGIBLE,
        decisions.REJECTED_DUPLICATE,
    ):
        # S8: final, and she is told so. No reason code reaches this map.
        # REJECTED_FAILED never reaches here: it became a review above (N3).
        # keep_approved: an approval that landed while this call ran stands.
        store.set_verification_state(
            uid, review.STATE_REJECTED, decided=True, keep_approved=True
        )
    if failed_check and outcome.id_hmac:
        # Spec §3's cross-account signal: count failures against the CARD, not
        # the account, so a series of fresh sign-ups on one stolen card is
        # visible.
        store.FirestoreBehaviour().record_failure(outcome.id_hmac)
    return decision, job_id


def _raise_flag(uid: str, decision, outcome, attempt: int, *, mark_duplicate=False):
    """Spec §5's admin review flow: a flag record with reason codes and no PII.

    The job and the flag are written in one transaction with her ledger, so
    there is at most one open flag per uid (S7). If one is already open (a race
    with another request), nothing new is written and the open one stands.

    The webhook carries only the flag id and the reason codes. It goes to a
    third-party chat service, so anything richer would be identity data sitting
    in someone else's message history.
    """
    job = store.job_payload(
        uid, decision, attempt, outcome.spent_micro_usd, outcome.provider_ids
    )
    flag = review.flag_payload(
        uid,
        None,
        decision,
        id_hmac=outcome.id_hmac,
        liveness_confidence=outcome.liveness_confidence,
        match_similarity=outcome.match_similarity,
    )
    flag_id, created = store.open_flag(uid, job, flag, mark_duplicate=mark_duplicate)
    if created:
        store.set_verification_state(
            uid, review.STATE_PENDING, reset_booking=True, keep_approved=True
        )
        _post_flag_webhook(flag_id, decision.flags)
    return flag_id


def _post_flag_webhook(flag_id: str, flags) -> None:
    """Spec §5: the flag id and reason codes only. See identity/webhook.py."""
    webhook.post_flag(flag_id, flags)


# ---------------------------------------------------------------- the review
#
# What human review IS here, since no image is ever stored.
#
# A reviewer cannot look at a photograph, because by the time a case reaches
# this queue the photographs do not exist anywhere. So review is a LIVE
# encounter with a woman reviewer: a video call, or a visit to a ladies-only
# gym. Those are the app's own two `ReviewerPath` values (`video` | `gym`) and
# the screen for them (C15) already exists.
#
# The queue therefore schedules and records live reviews. It does not display
# evidence, and there is no callable that returns an image or a signed URL —
# that endpoint was built for spec §5 and then deleted along with the bundle.
#
# The access log survives the deletion. Spec §5 required one for opening
# evidence; there is no evidence, and a queue that shows reason codes and
# biometric scores against a named woman is still a capability that needs a
# record of every use. A curious employee with the reviewer claim should leave a
# trace.
#
# CAPACITY, because this is now an operational number and not a technical one:
# at 50,000 sign-ups, EVERY PERCENTAGE POINT OF FLAG RATE IS 500 VIDEO CALLS.
# Spec §10 targets a flag rate under 10%, which is up to 5,000 calls. At fifteen
# minutes each that is roughly 1,250 reviewer-hours. See RESIDUAL_RISKS.md.


def _require_admin(
    request: https_fn.CallableRequest, providers: tuple = STAFF_PROVIDERS
) -> str:
    """The `admin` claim, server-minted exactly like `verified`.

    `firebase/firestore.rules` already defines `isAdmin()` as
    `request.auth.token.admin == true`, so this matches what the rules enforce.
    A client cannot grant itself admin any more than it can grant itself a
    verified badge. The claim is set out of band by tools/grant_admin.py.

    The console callables pass USER_PROVIDERS: the console runs inside the
    app, which signs in by phone only, so a password session holding the
    claim has no business reading it.
    """
    uid = _require_auth(request, providers)
    if not (request.auth.token or {}).get("admin"):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.UNAUTHENTICATED
        )
    return uid


def _require_woman_reviewer(
    request: https_fn.CallableRequest, allow_admin: bool = False
) -> str:
    """The claim that may decide a live review.

    A SEPARATE claim from `admin`, and the separation is the point. An admin
    administers a system. A woman reviewer meets a woman — on a video call or at
    a ladies-only gym — and is herself a woman, which is the entire reason the
    route exists and is the one property no amount of administrative privilege
    substitutes for.

    Minted out of band by staff. There is no self-service path, exactly like
    `admin`. `allow_admin` is for the dashboard's approve and queue callables,
    which an admin may also use.
    """
    return _require_staff_claim(
        request, ("womanReviewer", "admin") if allow_admin else ("womanReviewer",)
    )


def _require_finance(request: https_fn.CallableRequest) -> str:
    """Staff who check payments and pay coaches: the `finance` claim, or an
    admin. Minted out of band by tools/grant_finance.py, like `admin`."""
    return _require_staff_claim(request, ("finance", "admin"))


def _require_staff_claim(request: https_fn.CallableRequest, claims: tuple) -> str:
    """A staff sign-in (a phone or a staff provider) holding any one of
    `claims`; the caller's uid."""
    uid = _require_auth(request, STAFF_PROVIDERS)
    token = request.auth.token or {}
    if not any(token.get(claim) for claim in claims):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.UNAUTHENTICATED
        )
    return uid


def _log_review_access(reviewer_uid: str, flag_id: str, action: str) -> None:
    """Every use of the queue leaves a trace. See store.FirestoreReviewStore."""
    store.FirestoreReviewStore().log_access(reviewer_uid, flag_id, action)


_REVIEW_ERROR_CODES = {
    review.INVALID: https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    review.PRECONDITION: https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    review.EXHAUSTED: https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
    review.NOT_FOUND: https_fn.FunctionsErrorCode.NOT_FOUND,
}


def _review_call(fn, *args, **kwargs):
    """Run a review.* function and turn a ReviewError into an HttpsError.

    The message is always the reason code and nothing else: never a phone, an
    NID or anything a reviewer typed."""
    try:
        return fn(*args, **kwargs)
    except review.ReviewError as error:
        raise https_fn.HttpsError(_REVIEW_ERROR_CODES[error.kind], error.reason)


# iOS sends every Dart int as {"@type": "...Int64Value", "value": "3"}, because a
# long long may not fit a JavaScript number; Android and the web send a plain 3.
# Callables read their request only through _payload, so every version, count
# and timestamp reaches the same checks from both platforms.
_WRAPPED_INT_TYPES = (
    "type.googleapis.com/google.protobuf.Int64Value",
    "type.googleapis.com/google.protobuf.UInt64Value",
)


def _unwrap(value):
    if isinstance(value, dict):
        if (
            set(value) == {"@type", "value"}
            and value["@type"] in _WRAPPED_INT_TYPES
            and isinstance(value["value"], str)
        ):
            try:
                return int(value["value"])
            except ValueError:
                return value
        return {k: _unwrap(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_unwrap(v) for v in value]
    return value


def _payload(request: https_fn.CallableRequest):
    return _unwrap(request.data)


def _body(request: https_fn.CallableRequest) -> dict:
    data = _payload(request) or {}
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    return data


@https_fn.on_call()
def request_review(request: https_fn.CallableRequest) -> dict:
    """She asks for a woman reviewer: {path: "niqab" | "declined" | "error"}.

    S3. Takes no images, no frames and no phone number. Writes a flag with
    the path's reason code, at most one open flag per account, and sets her
    verification state to `pending`. N7: then records
    users/{uid}/consents/review-v2 = {version, at, path, flagId}; asking for
    the call is the consent to be looked up and called (the app shows the
    wording before calling; wording PENDING COUNSEL). N3: the consent names
    that flag and covers it only. Returns {state: "pending"}, or
    {state: "approved"} if she is already verified. A `knownReviewerId` only
    marks the queue row with the reviewer she named; it never approves her.
    """
    started = time.monotonic()
    uid = _require_auth(request)
    data = _body(request)
    # M13: a store review account on the owner's allow-list is approved here
    # too, exactly as verify_identity approves it, so choosing the woman
    # reviewer instead of the camera can never leave it waiting on a person.
    if _is_store_reviewer(request, uid) and not approvals.revoked_since_approval(uid):
        store.mint_claims(uid, True)
        store.write_user_verification(uid)
        store.FirestoreReviewStore().log_access(uid, "store-review", "reviewerBypass")
        logs.warn("reviewer_bypass")
        return {"state": review.STATE_APPROVED}
    known = data.get("knownReviewerId")
    result = _review_call(review.request, store.FirestoreReviewStore(), uid, data.get("path"))
    if known and result.state == review.STATE_PENDING:
        approvals.note_known_reviewer(uid, known)
    logs.decision(
        "request_review",
        outcome=decisions.PENDING_REVIEW if result.state == review.STATE_PENDING else result.state,
        state=result.state,
        reasons=[result.code] if result.code else [],
        latencyMs=_ms(started),
        flagId=result.flag_id,
    )
    return {"state": result.state}


@https_fn.on_call()
def list_verification_flags(request: https_fn.CallableRequest) -> dict:
    """The review queue, oldest first: reason codes, scores, and a handle.

    Never an image, because none exists, and never a phone number.

    N8: a woman reviewer may read it (she works the queue with her own
    account through tools/review_queue.py, which holds no admin credentials);
    an admin still may. Every read is written to the access log.
    """
    reviewer_uid = _require_auth(request, STAFF_PROVIDERS)
    token = request.auth.token or {}
    if not (token.get("womanReviewer") or token.get("admin")):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.UNAUTHENTICATED
        )
    rows = review.list_open(store.FirestoreReviewStore(), reviewer_uid)
    return {"flags": rows}


@https_fn.on_call()
def get_review_contact(request: https_fn.CallableRequest) -> dict:
    """Her phone number, for the woman reviewer about to call her.

    Looked up from Firebase Auth at the moment of calling, never copied onto
    the flag, never logged. Each lookup is written to the review access log.
    Refused unless the flag is PENDING_REVIEW, the reviewer is not her, and
    she asked for the call (R4: review_consent_missing otherwise).
    """
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    return _review_call(
        review.contact, store.FirestoreReviewStore(), reviewer_uid, data.get("flagId")
    )


@https_fn.on_call()
def schedule_verification_review(request: https_fn.CallableRequest) -> dict:
    """Book the live review: {flagId, route: "video"|"gym", scheduledFor}.

    `scheduledFor` is ISO-8601 with an explicit offset. Only a woman reviewer
    may book; the flag must be PENDING_REVIEW and must not be her own. Her
    verification map gains reviewRoute and reviewScheduledFor so C14 can show
    the booked time.
    """
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    return _review_call(
        review.schedule,
        store.FirestoreReviewStore(),
        reviewer_uid,
        data.get("flagId"),
        data.get("route"),
        data.get("scheduledFor"),
    )


@https_fn.on_call()
def decide_verification_flag(request: https_fn.CallableRequest) -> dict:
    """Record the outcome of a live review: {flagId, approve, nid?}.

    S19. Requires the `womanReviewer` claim, a PENDING_REVIEW flag, a reviewer
    who is not the subject, and a booked route. Approval claims the registry
    first and mints nothing if the claim fails. A flag with no id_hmac (the
    niqab, declined and error paths) needs `nid`: the 14 digits the reviewer
    read on the live call. They are hashed and dropped, never stored or logged.
    """
    started = time.monotonic()
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    approve = data.get("approve")
    if not isinstance(approve, bool):
        # N11: bool("false") is True. Only a real JSON boolean decides.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    result = _review_call(
        review.decide,
        store.FirestoreReviewStore(),
        reviewer_uid,
        data.get("flagId"),
        approve,
        data.get("nid"),
    )
    logs.decision(
        "decide_verification_flag",
        outcome=result.outcome,
        reasons=list(result.reasons),
        latencyMs=_ms(started),
        flagId=data.get("flagId") if isinstance(data.get("flagId"), str) else None,
    )
    return {"ok": True, "outcome": result.outcome}


# ------------------------------------- reviewer dashboard: one-click approval


@https_fn.on_call()
def approve_user(request: https_fn.CallableRequest) -> dict:
    """{uid, reason?: "approve" | "knownPerson", adultSeen: true} -> {state: "approved"}.

    One click, with her confirmation that she saw proof the woman is 18 or
    older (recorded in the ledger). No ID number, no call, no note: the claim is
    minted, her state set, any open flag closed, and the ledger records who and
    how. A reviewer cannot approve herself.
    """
    started = time.monotonic()
    reviewer_uid = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    reason = data.get("reason", "approve")
    if reason not in approvals.APPROVE_REASONS:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    state = _review_call(
        approvals.approve, reviewer_uid, data.get("uid"), reason, data.get("adultSeen") is True
    )
    logs.decision("approve_user", outcome=state, state=state, latencyMs=_ms(started))
    return {"state": state}


@https_fn.on_call()
def approve_users(request: https_fn.CallableRequest) -> dict:
    """{uids: [...], adultSeen: true} -> {approved: [...], failed: [...]}; one bad row never
    stops the rest."""
    reviewer_uid = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    result = _review_call(
        approvals.approve_many, reviewer_uid, data.get("uids"), data.get("adultSeen") is True
    )
    logs.decision("approve_users", outcome="approved", count=len(result["approved"]))
    return result


@https_fn.on_call()
def revoke_user(request: https_fn.CallableRequest) -> dict:
    """{uid} -> {state: "pending"}: the undo. Takes the verified claim back
    (other claims kept) and reopens her case."""
    reviewer_uid = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    state = _review_call(approvals.revoke, reviewer_uid, data.get("uid"))
    logs.decision("revoke_user", outcome=state, state=state)
    return {"state": state}


@https_fn.on_call()
def decline_user(request: https_fn.CallableRequest) -> dict:
    """{uid, reason?: "notClear" | "notMatching" | "other"} -> {state: "rejected"}.

    The decline half of the reviewer's decision, with the same guard and the
    same audit trail as an approve: her open flag is closed as rejected, the
    ledger records who, when and why, and the access log gets a line."""
    reviewer_uid = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    state = _review_call(
        approvals.decline, reviewer_uid, data.get("uid"), data.get("reason", "other")
    )
    logs.decision("decline_user", outcome=state, state=state)
    return {"state": state}


@https_fn.on_call()
def list_review_queue(request: https_fn.CallableRequest) -> list:
    """{status?: pending | scheduled | approved, query?} -> a list of rows. A phone
    number appears only where she asked for the call, and each is logged."""
    reviewer_uid = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    return _review_call(
        approvals.list_queue, reviewer_uid, data.get("status"), data.get("query")
    )


@https_fn.on_call()
def set_preapproved_phones(request: https_fn.CallableRequest) -> dict:
    """{add?: "comma list", remove?: [...], restore?: [removed numbers, within 5 minutes], adultSeen: true when adding} -> {phones: [...]}, E.164."""
    reviewer_uid = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    phones = _review_call(
        approvals.set_preapproved,
        reviewer_uid,
        data.get("add"),
        data.get("remove"),
        data.get("adultSeen") is True,
        data.get("restore"),
    )
    return {"phones": phones, "needsAgeTick": approvals.needing_age_tick()}


@https_fn.on_call()
def list_preapproved_phones(request: https_fn.CallableRequest) -> dict:
    """{} -> {phones: [...]}."""
    _require_woman_reviewer(request, allow_admin=True)
    return {"phones": approvals.list_preapproved(), "needsAgeTick": approvals.needing_age_tick()}


@https_fn.on_call()
def claim_fast_verification(request: https_fn.CallableRequest) -> dict:
    """{} -> {state: "approved" | "none", via?}.

    Right after a phone sign-in. Approves her when the phone in her verified
    ID token is pre-approved, is in TEST_BYPASS_PHONES (environment, empty
    means nobody) or is a store review account. The request body is never
    read: only the token decides.
    """
    uid = _require_auth(request)
    token = request.auth.token or {}
    result = _review_call(
        approvals.claim_fast,
        uid,
        token.get("phone_number"),
        _is_store_reviewer(request, uid),
    )
    logs.decision(
        "claim_fast_verification",
        outcome=f"fast_{result['via']}" if "via" in result else "none",
        state=result["state"],
    )
    return result


@https_fn.on_call()
def get_reviewer_settings(request: https_fn.CallableRequest) -> dict:
    reviewer_uid = _require_woman_reviewer(request)
    return scheduling.get_settings(reviewer_uid)


@https_fn.on_call()
def set_reviewer_settings(request: https_fn.CallableRequest) -> dict:
    """{firstName, listed, availability: [{weekday 1-7, start
    "HH:MM", end "HH:MM"}], slotMinutes} in Cairo time; weekday 1 = Monday."""
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    return _review_call(scheduling.set_settings, reviewer_uid, data)


@https_fn.on_call()
def list_reviewers(request: https_fn.CallableRequest) -> list:
    """{} -> [{reviewerId, firstName}]: only reviewers who listed themselves."""
    _require_auth(request)
    return scheduling.list_reviewers()


@https_fn.on_call()
def list_review_slots(request: https_fn.CallableRequest) -> list:
    """{days: 7} -> [{reviewerId, start}]: free slots, start in UTC."""
    _require_auth(request)
    data = _body(request)
    return scheduling.list_slots(data.get("days"))


@https_fn.on_call()
def book_review_slot(request: https_fn.CallableRequest) -> dict:
    """{reviewerId, start} -> {scheduledFor}. Needs her open review (so after
    request_review); a second booking replaces the first."""
    uid = _require_auth(request)
    data = _body(request)
    return _review_call(scheduling.book, uid, data.get("reviewerId"), data.get("start"))


@https_fn.on_call()
def list_schedule(request: https_fn.CallableRequest) -> list:
    """{from, to} -> [{uid, start, displayName?, phone?}]: the
    caller's own bookings. A phone only where she asked for the call."""
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    return _review_call(
        scheduling.list_schedule, reviewer_uid, data.get("from"), data.get("to")
    )


@https_fn.on_call()
def reschedule_review(request: https_fn.CallableRequest) -> dict:
    """{uid, start} -> {scheduledFor}: move a woman to a time the reviewer
    picks, whether or not it is in her availability."""
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    return _review_call(scheduling.reschedule, reviewer_uid, data.get("uid"), data.get("start"))


@scheduler_fn.on_schedule(schedule="every 1 hours", region=config.REGION)
def expire_stale_reviews(event: scheduler_fn.ScheduledEvent) -> None:
    """A flagged case undecided past the SLA becomes RETRY_REQUIRED.

    Our failure to review within 72 hours, not hers: her state becomes `retry`,
    and she earns one more OCR submission if it still fits under the cost cap.
    Nothing is ever reset. See review.expire.

    Also finishes any approval whose verified claim failed to mint at decide
    time (flag mintPending), then clears the mark. See review.retry_pending_mints.
    """
    import datetime as dt

    review_store = store.FirestoreReviewStore()
    count = review.expire(review_store, dt.datetime.now(dt.timezone.utc))
    logs.decision("expire_stale_reviews", outcome=decisions.RETRY_REQUIRED, count=count)
    # An approval whose verified claim could not be minted at decide time.
    minted = review.retry_pending_mints(
        review_store, skip=approvals.revoked_since_approval
    )
    if minted:
        logs.decision("expire_stale_reviews", outcome=decisions.APPROVED, count=minted)
    # Removed pre-approved numbers past their undo window (a list read does it too).
    approvals._live_preapproved()


# ------------------------------------------------------------- the console
#
# The owner's dashboard and logs, read from the app's admin build. Admin claim
# and a phone sign-in, App Check first like every other callable. Each read is
# written to adminAccessLog BEFORE anything is returned: a read that cannot be
# recorded does not happen. Nothing in either answer names a person; see
# console/dashboard.py and console/oplog.py.


def _record_console_read(uid: str, action: str) -> None:
    from console import access

    try:
        access.record(store.db(), uid, action)
    except Exception:
        logs.error("console_access_unrecorded")
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAVAILABLE, reasons.INTERNAL_ERROR
        )


@https_fn.on_call()
def admin_dashboard(request: https_fn.CallableRequest) -> dict:
    """Counts for the owner: `{refresh?: bool}` in, the dashboard out.

    Aggregations only, cached in the instance for five minutes unless
    `refresh` is true. See console/dashboard.py for every field."""
    uid = _require_admin(request, USER_PROVIDERS)
    data = _body(request)
    import datetime as dt

    from console import dashboard

    _record_console_read(uid, "dashboard")
    return dashboard.cached(
        store.db(),
        dt.datetime.now(dt.timezone.utc),
        refresh=data.get("refresh") is True,
    )


@https_fn.on_call()
def list_exercises(request: https_fn.CallableRequest) -> dict:
    """The member exercise library and the contract's vocabularies, for the
    reviewer dashboard's Exercises tab. Admin only."""
    _require_admin(request)
    from console import exercise_editor

    return exercise_editor.list_library(store.db())


@https_fn.on_call()
def save_exercise(request: https_fn.CallableRequest) -> dict:
    """Adds or edits one exercise whose clips and poster the dashboard already
    uploaded. `{ok, version}` or `{ok: false, problems}`. Admin only."""
    _require_admin(request)
    from console import exercise_editor
    from firebase_admin import storage

    return exercise_editor.save(
        store.db(), storage.bucket(exercise_editor.CONTENT_BUCKET), _body(request)
    )


@https_fn.on_call()
def list_events_admin(request: https_fn.CallableRequest) -> dict:
    """Every event with its seats, soonest first, for the dashboard's Events
    tab. Admin only."""
    _require_admin(request)
    from events import admin as events_admin

    return events_admin.list_all(store.db())


@https_fn.on_call()
def save_event(request: https_fn.CallableRequest) -> dict:
    """Creates or edits one event whose pictures and clips the dashboard
    already uploaded. `{ok, eventId}` or `{ok: false, problems}`. Never changes
    the seats taken. Admin only."""
    _require_admin(request)
    from events import admin as events_admin

    return events_admin.save(store.db(), _body(request))


@https_fn.on_call()
def list_community_foods(request: https_fn.CallableRequest) -> dict:
    """Pending community foods by how many women confirmed them, the published
    list and the category and allergen vocabularies, for the dashboard's Foods
    tab. Admin only."""
    _require_admin(request)
    from nutrition import community_foods

    return community_foods.list_all(store.db())


@https_fn.on_call()
def review_community_food(request: https_fn.CallableRequest) -> dict:
    """Approves one candidate into meta/communityFoods or rejects it. Request
    {key, action: "approve" | "reject"} and, to approve, {nameEn, nameAr,
    category, allergens, allergensNone}. `{ok, version?}` or `{ok: false,
    problems}`. Admin only."""
    _require_admin(request)
    from nutrition import community_foods

    return community_foods.review(store.db(), _body(request))


_SEAT_ERROR_CODES = {
    "not_found": https_fn.FunctionsErrorCode.NOT_FOUND,
    "closed": https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    "full": https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
}


def _seat_call(request: https_fn.CallableRequest, uid: str, action: str) -> dict:
    if _claim(request, "verified") is not True:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.NOT_VERIFIED
        )
    event_id = _body(request).get("eventId")
    from events import seats

    if not isinstance(event_id, str) or not seats.ID.match(event_id):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    try:
        return getattr(seats, action)(store.db(), uid, event_id)
    except seats.SeatError as error:
        raise https_fn.HttpsError(_SEAT_ERROR_CODES[error.kind], error.reason)


@https_fn.on_call()
def register_for_event(request: https_fn.CallableRequest) -> dict:
    """Reserves her seat: `{eventId}` -> `{registered: true, seatsTaken, capacity}`.

    Verified members only. A second call changes nothing. Refusals, each the
    whole message:
      event_not_found   NOT_FOUND
      event_closed      FAILED_PRECONDITION (not published, over, or no seats set)
      event_full        FAILED_PRECONDITION
    """
    uid = _require_auth(request)
    return _seat_call(request, uid, "register")


@https_fn.on_call()
def cancel_event_registration(request: https_fn.CallableRequest) -> dict:
    """Gives her seat back: `{eventId}` -> `{registered: false, seatsTaken,
    capacity}`. Verified members only; a repeat changes nothing."""
    uid = _require_auth(request)
    return _seat_call(request, uid, "cancel")


@https_fn.on_call()
def admin_logs(request: https_fn.CallableRequest) -> dict:
    """One page of one operational log: `{kind, before?, limit?, outcome?}`.

    `kind` is decisions, reviews, deletions, waitlist, errors or access.
    Codes, times and short case references only. See console/oplog.py."""
    uid = _require_admin(request, USER_PROVIDERS)
    data = _body(request)
    import datetime as dt

    from console import oplog

    kind = data.get("kind")
    if kind not in oplog.KINDS:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    _record_console_read(uid, f"logs.{kind}")
    try:
        return oplog.page(store.db(), data, dt.datetime.now(dt.timezone.utc))
    except oplog.LogRequestError:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )


# ------------------------------------------------------------- deletion


@https_fn.on_call()
def delete_account(request: https_fn.CallableRequest) -> dict:
    """S4: delete her account and everything the manifest names. `{}` in.

    Signed in is enough; NOT gated on `verified`. A woman who never finished
    verification, or was rejected, has the same right to erasure (Protected
    List 6). Returns {state: "done", journal: [...]} with the eight states of
    contracts/identity_contract.json deletionJournal. On a failure the record
    is left at `failedRetryable` and resume_account_deletions finishes it,
    which matters because her Auth user is disabled at step two and she
    cannot retry herself.
    """
    # N1: any sign-in provider. Erasure is open to every account that exists
    # (Protected List 6); App Check and auth still apply.
    uid = _require_auth(request, providers=None)
    from account import deletion

    started = time.monotonic()
    try:
        # B3: a deletion with a very large community footprint stops its scan
        # before the client's 60-second timeout and the sweeper finishes it.
        result = deletion.run(
            uid,
            deletion.FirebaseBackend(),
            deadline=deletion.deadline_after(config.DELETION_CALL_BUDGET_SEC),
        )
    except Exception:
        logs.error("account_deletion_failed", state=deletion.FAILED_RETRYABLE)
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INTERNAL, reasons.INTERNAL_ERROR
        )
    logs.decision("delete_account", state=result["state"], latencyMs=_ms(started))
    return result


@scheduler_fn.on_schedule(schedule="every 15 minutes", region=config.REGION)
def resume_account_deletions(event: scheduler_fn.ScheduledEvent) -> None:
    """Finish any deletion that stopped part way and has been idle 10 minutes,
    and run each finished deletion's one late sweep once it is due (N9)."""
    import datetime as dt

    from account import deletion

    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(minutes=10)
    # B3: one budget for the whole run, under TIMEOUT_SEC. A deletion that is
    # not reached, or whose scan runs out of time, keeps its state and cursor
    # and is picked up by the next run.
    deadline = deletion.deadline_after(config.DELETION_SWEEP_BUDGET_SEC)
    finished = failed = 0
    for uid in deletion.unfinished(store.db(), cutoff):
        if deletion.expired(deadline):
            break
        try:
            deletion.run(uid, deletion.FirebaseBackend(), deadline=deadline)
            finished += 1
        except Exception:
            failed += 1
    # N9: the one late sweep of users/{uid}, plans/{uid}, her Storage and her
    # community data, 65 minutes after done, for writes a still-valid token or
    # a queued client made meanwhile.
    for uid in deletion.due_resweeps(store.db(), dt.datetime.now(dt.timezone.utc)):
        if deletion.expired(deadline):
            break
        try:
            deletion.resweep(uid, deletion.FirebaseBackend(), deadline=deadline)
        except Exception:
            failed += 1
    logs.decision("resume_account_deletions", state="done", count=finished)
    if failed:
        logs.error("account_deletion_failed", state=deletion.FAILED_RETRYABLE, count=failed)


# ------------------------------------------------------------- post counters


def _count_change(event) -> None:
    from community import counts

    change = event.data
    before = change.before.to_dict() if change.before is not None and change.before.exists else None
    after = change.after.to_dict() if change.after is not None and change.after.exists else None
    counts.on_change(store.db(), event.id, event.document, before, after)


@firestore_fn.on_document_written(
    document="posts/{postId}/likes/{likeId}", region=config.REGION
)
def post_like_counter(event) -> None:
    """C1: posts/{postId}.counts.likes, the only writer of it. Idempotent per
    event id; never below 0. See community/counts.py."""
    _count_change(event)


@firestore_fn.on_document_written(
    document="posts/{postId}/comments/{commentId}", region=config.REGION
)
def post_comment_counter(event) -> None:
    """C1: posts/{postId}.counts.comments, live comments only (a tombstone is
    not one). Idempotent per event id; never below 0."""
    _count_change(event)


# ------------------------------------------------------------- waitlist


def _waitlist_store():
    from waitlist import join

    return join.FirestoreWaitlist(store.db())


@https_fn.on_request(
    region=config.REGION,
    memory=options.MemoryOption.MB_256,
    # One instance: an honest day is at most 5,000 joins (well under one a
    # second), and a public endpoint's instance count is its flood ceiling.
    max_instances=1,
)
def join_waitlist(request: https_fn.Request) -> https_fn.Response:
    """W1: the public site's waitlist form. No App Check, because it is the
    web: strict validation, a honeypot and a per-IP cap instead. All of it is
    in waitlist/join.py; this only adapts Flask to it."""
    import datetime as dt

    from waitlist import join

    result = join.handle(
        join.from_flask(request),
        _waitlist_store(),
        join.ip_key,
        dt.datetime.now(dt.timezone.utc),
    )
    return https_fn.Response(result.body, status=result.status, headers=result.headers)


# ------------------------------------------------------------- coaching
#
# Three switches: coaching.COACH_PORTFOLIO_LIVE (applications, profiles,
# packages, certificates), coaching.COACH_CLIENTS_LIVE (requests, chat, plans,
# sessions) and coaching.COACH_PAYMENTS_LIVE (everything about money). They move with coachPortfolioLive() and
# coachPaymentsLive() in both rules files. Each refusal is a code from
# coaching/errors.py and nothing else.

_COACHING_ERROR_CODES = {
    "failed_precondition": https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
    "permission_denied": https_fn.FunctionsErrorCode.PERMISSION_DENIED,
    "invalid_argument": https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
    "not_found": https_fn.FunctionsErrorCode.NOT_FOUND,
    "resource_exhausted": https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
}


def _coaching_call(fn, *args, **kwargs):
    from coaching import errors as coaching_errors

    try:
        return _json_safe(fn(*args, **kwargs))
    except coaching_errors.CoachingError as error:
        raise https_fn.HttpsError(_COACHING_ERROR_CODES[error.code], error.reason)


def _json_safe(value):
    """Stored times leave as ISO-8601 strings; a callable answer must be JSON."""
    import datetime as dt

    if isinstance(value, dt.datetime):
        aware = value if value.tzinfo else value.replace(tzinfo=dt.timezone.utc)
        return aware.isoformat()
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(v) for v in value]
    return value


def _claim(request: https_fn.CallableRequest, name: str):
    token = request.auth.token if request.auth is not None else None
    return (token or {}).get(name) if isinstance(token, dict) else None


def _coach_object_exists(media_ref: str) -> bool:
    """Whether her certificate photo is in the personal bucket."""
    try:
        return _PersonalBlobs().exists(media_ref)
    except Exception:
        return False


@https_fn.on_call()
def record_signup_role(request: https_fn.CallableRequest) -> dict:
    """C08: `{role: trainee|coach|both}` to users/{uid}.roles (D11).

    Server-written because the rules keep `roles` out of the client's
    whitelist. Not gated on verification: she chooses before the check. A
    coach role is refused while the coach app is closed.
    """
    uid = _require_auth(request)
    data = _body(request)
    from google.cloud import firestore

    import coaching
    from coaching import roles

    return _coaching_call(
        roles.record,
        store.db(),
        uid,
        data,
        live=coaching.COACH_PORTFOLIO_LIVE,
        timestamp=firestore.SERVER_TIMESTAMP,
        coach_v=_claim(request, "coachV"),
    )


@https_fn.on_call()
def submit_coach_certificate(request: https_fn.CallableRequest) -> dict:
    """K02: `{credentialId, mediaRef}` once the photo is in the bucket.

    Records coaches/{uid}/certificates/{id} as `uploaded` for a woman
    reviewer. Verified women only, and only while the coach app is live.
    """
    uid = _require_auth(request)
    data = _body(request)
    from google.cloud import firestore

    import coaching
    from coaching import certificates

    return _coaching_call(
        certificates.submit,
        store.db(),
        uid,
        data,
        verified=_claim(request, "verified") is True,
        live=coaching.COACH_PORTFOLIO_LIVE,
        object_exists=_coach_object_exists,
        timestamp=firestore.SERVER_TIMESTAMP,
    )


@https_fn.on_call()
def create_coach_invite(request: https_fn.CallableRequest) -> dict:
    """K07: her invite code for a woman she already coaches. `{}` in,
    `{code, expiresAtMs}` out. Needs the coach claim."""
    uid = _require_auth(request)
    _body(request)
    import datetime as dt

    import coaching
    from coaching import invites

    return _coaching_call(
        invites.create,
        store.db(),
        uid,
        is_coach=_claim(request, "coachV") == "active",
        verified=_claim(request, "verified") is True,
        live=coaching.COACH_CLIENTS_LIVE,
        now=dt.datetime.now(dt.timezone.utc),
    )


@https_fn.on_call()
def accept_coach_invite(request: https_fn.CallableRequest) -> dict:
    """After her check: `{code}` opens an enquiry with the coach who sent it.
    `{relId, coachUid}` out."""
    uid = _require_auth(request)
    data = _body(request)
    import datetime as dt

    from google.cloud import firestore

    import coaching
    from coaching import invites

    return _coaching_call(
        invites.accept,
        store.db(),
        uid,
        data,
        verified=_claim(request, "verified") is True,
        live=coaching.COACH_CLIENTS_LIVE,
        now=dt.datetime.now(dt.timezone.utc),
        timestamp=firestore.SERVER_TIMESTAMP,
    )


@https_fn.on_call()
def review_client_health(request: https_fn.CallableRequest) -> dict:
    """C9: the coach has read this client's health answers. `{subId}`."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    import datetime as dt

    import coaching
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.review_health,
        store.db(),
        uid,
        data,
        live=coaching.COACH_CLIENTS_LIVE,
        coach_v=_claim(request, "coachV"),
        now=dt.datetime.now(dt.timezone.utc),
    )


@https_fn.on_call()
def submit_check_in(request: https_fn.CallableRequest) -> dict:
    """C3: the client answers her weekly check-in. `{relId, weekKey, answers}`."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    import datetime as dt

    import coaching
    from coaching import checkins

    return _coaching_call(
        checkins.submit,
        store.db(),
        uid,
        data,
        live=coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE,
        now=dt.datetime.now(dt.timezone.utc),
    )


@https_fn.on_call()
def coach_needs_attention(request: https_fn.CallableRequest) -> dict:
    """C3: the coach's clients that need a look. `{}` in, `{clients}` out."""
    uid = _require_auth(request)
    _require_verified(request)
    _body(request)
    import datetime as dt

    import coaching
    from coaching import checkins

    return _coaching_call(
        checkins.needs_attention,
        store.db(),
        uid,
        live=coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE,
        coach_v=_claim(request, "coachV"),
        now=dt.datetime.now(dt.timezone.utc),
    )


@scheduler_fn.on_schedule(schedule="0 9 * * 5", timezone="Africa/Cairo", region=config.REGION)
def send_weekly_check_ins(event: scheduler_fn.ScheduledEvent) -> None:
    """Friday 09:00 Cairo: the weekly check-in card and push. Safe to run twice."""
    import datetime as dt

    import coaching
    from coaching import checkins

    if not (coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE):
        return
    count = checkins.send_cards(store.db(), dt.datetime.now(dt.timezone.utc), _coaching_notify)
    logs.decision("send_weekly_check_ins", outcome="sent", count=count)


@scheduler_fn.on_schedule(schedule="0 9 * * 1", timezone="Africa/Cairo", region=config.REGION)
def check_in_follow_up(event: scheduler_fn.ScheduledEvent) -> None:
    """Monday 09:00 Cairo: one kind follow-up for last week's open card."""
    import datetime as dt

    import coaching
    from coaching import checkins

    if not (coaching.COACH_CLIENTS_LIVE and coaching.CHECK_INS_LIVE):
        return
    count = checkins.follow_up(store.db(), dt.datetime.now(dt.timezone.utc), _coaching_notify)
    logs.decision("check_in_follow_up", outcome="sent", count=count)



# ------------------------------------------------------- private coaching
#
# DECISIONS D61. The logic lives in pure modules under coaching/; these wrappers
# run the guards, then hand each module the clock and the adapters it needs
# (the personal bucket, claims, pushes). Member and coach calls refuse while
# their group's switch is False. Staff calls are not gated, so receiving
# accounts and seller details can be set before payments are turned on.


def _PersonalBlobs():
    from coaching import blobs

    return blobs.PersonalBlobs()


def _coaching_now():
    import datetime as dt

    return dt.datetime.now(dt.timezone.utc)


def _coaching_notify(uid: str, kind: str) -> None:
    """One push; a failed push never fails the call that caused it."""
    try:
        from firebase_admin import messaging

        from coaching import push

        push.send_kind(uid, kind, db=store.db(), messaging=messaging)
    except Exception:
        logs.error("coaching_push_failed")


def _payments_notify(uid: str, kind: str) -> None:
    """Push for payments using the payments notice texts."""
    try:
        from firebase_admin import messaging

        from payments import notices

        notices.send_kind(uid, kind, db=store.db(), messaging=messaging)
    except Exception:
        logs.error("payments_push_failed")


def _recent_sign_in(request: https_fn.CallableRequest, max_age_seconds: int = 300) -> bool:
    """True when this ID token comes from a phone sign-in made in the last five
    minutes. The app gets there by re-authenticating with a fresh SMS code,
    which is the 'one-time code to her phone' of spec 4.4."""
    token = request.auth.token if request.auth is not None else None
    auth_time = token.get("auth_time") if isinstance(token, dict) else None
    if isinstance(auth_time, bool) or not isinstance(auth_time, (int, float)):
        return False
    return _sign_in_provider(request) == "phone" and 0 <= time.time() - auth_time <= max_age_seconds


def _coaching_merge_claims(uid: str, changes: dict) -> None:
    from firebase_admin import auth

    from coaching import claims

    claims.merge_claims(auth, uid, changes)


def _reencode(raw: bytes, **kwargs) -> bytes:
    from nutrition import photo

    return photo.reencode(raw, **kwargs)


def _verified(request: https_fn.CallableRequest) -> bool:
    return _claim(request, "verified") is True


def _require_verified(request: https_fn.CallableRequest) -> None:
    from coaching import common

    _coaching_call(common.require_verified, _verified(request))


def _portfolio_live() -> bool:
    import coaching

    return coaching.COACH_PORTFOLIO_LIVE


def _clients_live() -> bool:
    import coaching

    return coaching.COACH_CLIENTS_LIVE


def _payments_live() -> bool:
    import coaching

    return coaching.COACH_PAYMENTS_LIVE


def _instapay_on() -> bool:
    """The InstaPay kill switch (config/payments.enabled). Off when missing."""
    from payments import model as payments_model

    return payments_model.enabled(store.db())


def common_limits() -> dict:
    from coaching import common

    return common.LIMITS


@https_fn.on_call()
def submit_coach_application(request: https_fn.CallableRequest) -> dict:
    """K01 to K13: every section of a coach application, files already in the
    bucket under her own prefix. Verified women only."""
    uid = _require_auth(request)
    data = _body(request)
    from coaching import applications

    return _coaching_call(
        applications.submit, store.db(), uid, data,
        live=_portfolio_live(), verified=_verified(request), coach_v=_claim(request, "coachV"),
        blobs=_PersonalBlobs(), now=_coaching_now(), payments_live=_payments_live(),
    )


@https_fn.on_call()
def list_coach_applications(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    from coaching import applications

    return _coaching_call(
        applications.list_for_review, store.db(), actor, data, now=_coaching_now()
    )


@https_fn.on_call()
def decide_coach_application(request: https_fn.CallableRequest) -> dict:
    """Approve (mints coachV), ask for changes, or reject."""
    actor = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    from coaching import applications

    return _coaching_call(
        applications.decide, store.db(), actor, data,
        merge_claims=_coaching_merge_claims, blobs=_PersonalBlobs(),
        notify=_coaching_notify, reencode=_reencode, now=_coaching_now(),
    )


@https_fn.on_call()
def add_portfolio_media(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import media

    return _coaching_call(
        media.add, store.db(), uid, data,
        live=_portfolio_live(), coach_v=_claim(request, "coachV"),
        blobs=_PersonalBlobs(), reencode=_reencode, now=_coaching_now(),
    )


@https_fn.on_call()
def remove_portfolio_media(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import media

    return _coaching_call(
        media.remove, store.db(), uid, data,
        live=_portfolio_live(), coach_v=_claim(request, "coachV"),
        blobs=_PersonalBlobs(), now=_coaching_now(),
    )


@https_fn.on_call()
def confirm_portfolio_consent(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import media

    return _coaching_call(
        media.confirm_consent, store.db(), uid, data,
        live=_portfolio_live(), coach_v=_claim(request, "coachV"), blobs=_PersonalBlobs(), now=_coaching_now(),
    )


@https_fn.on_call()
def list_portfolio_media(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)  # no admin: admins never see these photos
    data = _body(request)
    from coaching import media

    return _coaching_call(media.list_for_review, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def decide_portfolio_media(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)  # reviewer only
    data = _body(request)
    from coaching import media

    return _coaching_call(
        media.decide, store.db(), actor, data,
        blobs=_PersonalBlobs(), reencode=_reencode,
        notify=_coaching_notify, now=_coaching_now(),
    )


@https_fn.on_call()
def suspend_coach(request: https_fn.CallableRequest) -> dict:
    actor = _require_admin(request)
    data = _body(request)
    from coaching import claims

    return _coaching_call(
        claims.suspend, store.db(), actor, data,
        merge_claims=_coaching_merge_claims, now=_coaching_now(),
    )


@https_fn.on_call()
def update_coach_profile(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import profiles

    return _coaching_call(
        profiles.update, store.db(), uid, data,
        live=_portfolio_live(), coach_v=_claim(request, "coachV"),
        blobs=_PersonalBlobs(), reencode=_reencode, now=_coaching_now(),
    )


@https_fn.on_call()
def request_payout_account_change(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import profiles

    return _coaching_call(
        profiles.request_payout_change, store.db(), uid, data,
        live=_payments_live(), coach_v=_claim(request, "coachV"), now=_coaching_now(),
    )


@https_fn.on_call()
def confirm_payout_account(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import common as coaching_common
    from coaching import profiles

    _coaching_call(coaching_common.require_payments_live, _payments_live())
    return _coaching_call(
        profiles.confirm_payout, store.db(), actor, data, now=_coaching_now()
    )


@https_fn.on_call()
def save_coach_package(request: https_fn.CallableRequest) -> dict:
    """K04: a package she designs. Her price in, the client's final price and
    what she receives out."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import packages

    return _coaching_call(
        packages.save, store.db(), uid, data,
        live=_portfolio_live(), coach_v=_claim(request, "coachV"), now=_coaching_now(),
    )


@https_fn.on_call()
def request_coaching(request: https_fn.CallableRequest) -> dict:
    """H03: she asks a coach for a package. No price travels in the request."""
    uid = _require_auth(request)
    data = _body(request)
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.request, store.db(), uid, data,
        live=_clients_live(), payments_live=_payments_live(), instapay=_instapay_on(), verified=_verified(request),
        now=_coaching_now(), notify=_coaching_notify,
    )


@https_fn.on_call()
def respond_coaching_request(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.respond, store.db(), uid, data,
        live=_clients_live(), payments_live=_payments_live(), instapay=_instapay_on(), coach_v=_claim(request, "coachV"),
        now=_coaching_now(), notify=_coaching_notify,
    )


@https_fn.on_call()
def create_payment(request: https_fn.CallableRequest) -> dict:
    """PAY1: a client starts a payment for her accepted package. {subId, idempotencyKey}."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import create

    return _coaching_call(create.create, store.db(), uid, data, now=_coaching_now(), on=_instapay_on())


@https_fn.on_call()
def cancel_payment(request: https_fn.CallableRequest) -> dict:
    """PAY3: the client withdraws an unpaid request. {paymentId}. Works with the switch off."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import cancel

    return _coaching_call(cancel.cancel, store.db(), uid, data, now=_coaching_now())


@https_fn.on_call()
def set_coach_instapay_address(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import address

    return _coaching_call(
        address.set_address, store.db(), uid, data, coach_v=_claim(request, "coachV"),
        recent_sign_in=_recent_sign_in(request), now=_coaching_now(), notify=_payments_notify,
    )


@https_fn.on_call()
def set_coach_payment_options(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import address

    return _coaching_call(address.set_options, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now())


@https_fn.on_call()
def submit_instapay_proof(request: https_fn.CallableRequest) -> dict:
    """PAY2: screenshots and the transaction number. Works with the kill switch off."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import ocr, proof

    budget: dict = {}
    raw = data.get("images")
    if not isinstance(raw, list):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR)
    images = [_decode_image(item, budget) for item in raw[: proof.MAX_IMAGES_PER_CALL + 1]]
    return _coaching_call(
        proof.submit, store.db(), uid, data, images,
        now=_coaching_now(), blobs=_PersonalBlobs(), reencode=_reencode, reader=ocr.TextReader(), notify=_payments_notify,
    )


@https_fn.on_call()
def coach_confirm_payment(request: https_fn.CallableRequest) -> dict:
    """PAY4: 'I received it'. Works with the kill switch off."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import coach

    return _coaching_call(
        coach.confirm, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now(), notify=_payments_notify,
    )


@https_fn.on_call()
def coach_mark_different_amount(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import amounts

    return _coaching_call(amounts.mark, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def client_respond_different_amount(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import amounts

    return _coaching_call(amounts.respond, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def coach_report_payment(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import report

    return _coaching_call(report.coach_report, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def client_confirm_coach_report(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import report

    return _coaching_call(report.client_answer, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def set_auto_confirm_green(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import coach

    return _coaching_call(coach.set_auto_confirm, store.db(), uid, data, coach_v=_claim(request, "coachV"), now=_coaching_now())


@https_fn.on_call()
def request_refund(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.request, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def deny_refund(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.deny, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def record_instapay_refund(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.record, store.db(), uid, data, coach_v=_claim(request, "coachV"),
                          now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def open_service_dispute(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import refund

    return _coaching_call(refund.open_service_dispute, store.db(), uid, data, now=_coaching_now(), notify=_payments_notify)


@https_fn.on_call()
def get_payment_image(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.party_image, store.db(), uid, data, blobs=_PersonalBlobs())


@https_fn.on_call()
def staff_list_payment_queue(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)  # no admin: a woman's private payment data
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.queue, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def staff_get_payment_evidence(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.get_evidence, store.db(), actor, data, now=_coaching_now(), blobs=_PersonalBlobs())


@https_fn.on_call()
def staff_resolve_payment(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request)
    data = _body(request)
    from payments import staff

    return _coaching_call(staff.resolve, store.db(), actor, data, now=_coaching_now(), notify=_payments_notify)




@https_fn.on_call()
def end_my_coaching(request: https_fn.CallableRequest) -> dict:
    """Either the client or the coach leaves a coaching."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.end_mine, store.db(), uid, data,
        live=_clients_live(), now=_coaching_now(), notify=_coaching_notify,
    )


@https_fn.on_call()
def cancel_coaching_request(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.cancel_request, store.db(), uid, data,
        live=_clients_live(), now=_coaching_now(),
    )


@https_fn.on_call()
def submit_payment_proof(request: https_fn.CallableRequest) -> dict:
    """H04: the transfer details and a screenshot, for a person to check.
    The screenshot is re-encoded without metadata and deleted at the decision."""
    uid = _require_auth(request)
    _require_verified(request)
    from coaching import common as coaching_common

    _coaching_call(coaching_common.require_payments_live, _payments_live())
    data = _body(request)
    image = _decode_image(data.get("imageJpeg"), {})
    from coaching import proofs

    fields = {k: v for k, v in data.items() if k != "imageJpeg"}
    return _coaching_call(
        proofs.submit, store.db(), uid, fields, image,
        live=_payments_live(), now=_coaching_now(), blobs=_PersonalBlobs(), reencode=_reencode,
    )


@https_fn.on_call()
def list_payment_proofs(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import proofs

    return _coaching_call(proofs.list_for_staff, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def decide_payment_proof(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import proofs

    return _coaching_call(
        proofs.decide, store.db(), actor, data,
        now=_coaching_now(), blobs=_PersonalBlobs(), notify=_coaching_notify,
    )


@https_fn.on_call()
def request_cancellation(request: https_fn.CallableRequest) -> dict:
    """H05: cancel within the 14-day window; staff send the refund."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import refunds

    return _coaching_call(
        refunds.request, store.db(), uid, data, live=_payments_live(), now=_coaching_now()
    )


@https_fn.on_call()
def list_refund_requests(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import refunds

    return _coaching_call(refunds.list_for_staff, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def record_refund(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import refunds

    return _coaching_call(
        refunds.record, store.db(), actor, data, now=_coaching_now(), notify=_coaching_notify
    )


@https_fn.on_call()
def end_coaching(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import subscriptions

    return _coaching_call(
        subscriptions.end_early, store.db(), actor, data,
        now=_coaching_now(), notify=_coaching_notify,
    )


@https_fn.on_call()
def list_payouts_owed(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import payouts

    return _coaching_call(payouts.owed, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def record_coach_payout(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import payouts

    return _coaching_call(
        payouts.record, store.db(), actor, data, now=_coaching_now(), notify=_coaching_notify
    )


@https_fn.on_call()
def get_receiving_accounts(request: https_fn.CallableRequest) -> dict:
    actor = _require_finance(request)
    data = _body(request)
    from coaching import receiving

    return _coaching_call(receiving.get, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def set_receiving_accounts(request: https_fn.CallableRequest) -> dict:
    actor = _require_admin(request)
    data = _body(request)
    from coaching import receiving

    return _coaching_call(receiving.set_accounts, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def set_seller_details(request: https_fn.CallableRequest) -> dict:
    actor = _require_admin(request)
    data = _body(request)
    from coaching import receiving

    return _coaching_call(receiving.set_seller, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def publish_coach_plan(request: https_fn.CallableRequest) -> dict:
    """W08: a workout or meal plan she built, shared with an active client."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import plans

    return _coaching_call(
        plans.publish, store.db(), uid, data,
        live=_clients_live(), coach_v=_claim(request, "coachV"), now=_coaching_now(),
        notify=_coaching_notify,
    )


@https_fn.on_call()
def schedule_live_session(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import sessions

    return _coaching_call(
        sessions.schedule, store.db(), uid, data,
        live=_clients_live(), coach_v=_claim(request, "coachV"),
        now=_coaching_now(), notify=_coaching_notify,
    )


@https_fn.on_call()
def respond_live_session(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import sessions

    return _coaching_call(
        sessions.respond, store.db(), uid, data, live=_clients_live(), now=_coaching_now()
    )


@https_fn.on_call()
def mark_session_done(request: https_fn.CallableRequest) -> dict:
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import sessions

    return _coaching_call(
        sessions.mark_done, store.db(), uid, data, live=_clients_live(), now=_coaching_now()
    )


@https_fn.on_call()
def list_coaching_reports(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    from coaching import moderation

    return _coaching_call(moderation.list_for_staff, store.db(), actor, data, now=_coaching_now())


@https_fn.on_call()
def decide_coaching_report(request: https_fn.CallableRequest) -> dict:
    actor = _require_woman_reviewer(request, allow_admin=True)
    data = _body(request)
    from coaching import claims, moderation, subscriptions

    db = store.db()
    now = _coaching_now()

    def suspend(coach_uid: str) -> None:
        claims.suspend(
            db, actor, {"uid": coach_uid, "reason": "report"},
            merge_claims=_coaching_merge_claims, now=now,
        )

    def end_early(sub_id: str) -> None:
        subscriptions.end_early(
            db, actor, {"subId": sub_id, "reason": "safety"},
            now=now, notify=_coaching_notify,
        )

    return _coaching_call(
        moderation.decide, db, actor, data, now=now, suspend=suspend, end_early=end_early
    )


@https_fn.on_call()
def mark_thread_read(request: https_fn.CallableRequest) -> dict:
    """She opened a thread: her unread count goes to zero and `reads/{uid}`
    gets the time, in one write."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import chat

    return _coaching_call(
        chat.mark_read, store.db(), uid, data, live=_clients_live(), now=_coaching_now()
    )


@https_fn.on_call()
def accept_chat_rules(request: https_fn.CallableRequest) -> dict:
    """She ticked the chat and conduct rules before her first coaching message;
    the version, a hash of the words and the time are kept."""
    uid = _require_auth(request)
    _require_verified(request)
    data = _body(request)
    from coaching import chat

    return _coaching_call(
        chat.accept_rules, store.db(), uid, data, live=_clients_live(), now=_coaching_now()
    )


@firestore_fn.on_document_created(
    document="relationships/{relId}/messages/{messageId}", region=config.REGION
)
def on_coaching_message(event) -> None:
    """Screens a new chat message, hides it when the screen fails, keeps the
    thread's last activity and pushes the other party (throttled)."""
    if not _clients_live() or event.data is None:
        return
    from coaching import chat

    try:
        chat.on_message(
            store.db(), event.params["relId"], event.params["messageId"],
            event.data.to_dict() or {}, now=_coaching_now(), notify=_coaching_notify,
            blobs=_PersonalBlobs(), reencode=_reencode,
        )
    except Exception:
        logs.error("coaching_message_trigger_failed")
        raise


@firestore_fn.on_document_created(document="reports/{reportId}", region=config.REGION)
def on_coaching_report(event) -> None:
    """Keeps a copy of the reported coaching content, for staff only."""
    if event.data is None:
        return
    from coaching import moderation

    try:
        from datetime import timedelta

        db = store.db()
        data = event.data.to_dict() or {}
        since = _coaching_now() - timedelta(hours=24)
        mine = db.collection("reports").where("reporterUid", "==", data.get("reporterUid")).where("createdAt", ">=", since)
        if sum(1 for _ in mine.stream()) > common_limits()["reportsPerDay"]:
            db.collection("reports").document(event.params["reportId"]).update({"throttled": True})
            return
        moderation.capture_evidence(
            db, event.params["reportId"], data, now=_coaching_now()
        )
    except Exception:
        logs.error("coaching_report_trigger_failed")
        raise


@firestore_fn.on_document_created(document="users/{uid}/blocks/{otherUid}", region=config.REGION)
def on_coaching_block(event) -> None:
    """A block between a client and a coach ends any open coaching between them."""
    if not _clients_live():
        return
    from coaching import subscriptions

    try:
        subscriptions.end_for_block(
            store.db(), event.params["uid"], event.params["otherUid"], now=_coaching_now()
        )
    except Exception:
        logs.error("coaching_block_trigger_failed")
        raise


@scheduler_fn.on_schedule(schedule="every 1 hours", region=config.REGION)
def coaching_sweeper(event: scheduler_fn.ScheduledEvent) -> None:
    """Expiries, finished programmes, the ends-soon push, payouts becoming due,
    and an alert when a payment screenshot outlives its decision window. The
    retry of a missed coach claim runs always; the client parts need the
    clients switch, the ledger and proof parts the payments switch."""
    from coaching import applications, subscriptions

    db, now = store.db(), _coaching_now()
    try:
        applications.retry_claims(db, merge_claims=_coaching_merge_claims)
    except Exception:
        logs.error("coaching_claim_retry_failed")
    clients, payments = _clients_live(), _payments_live() or _instapay_on()
    if not (clients or payments):
        return
    counts = subscriptions.sweep(
        db, now=now, notify=_coaching_notify, blobs=_PersonalBlobs(), clients=clients, payments=payments
    )
    stale = counts["staleProofImages"]
    if stale:
        logs.error("coaching_stale_proof_images", count=stale)


# ------------------------------------------------------------- meal photos
#
# E12 and E13: she photographs a meal, the model names the foods and estimates
# their grams, and every energy and macro number comes from nutrition/ (the
# Egyptian dish table, then USDA FoodData Central). The photo is checked,
# re-encoded without its metadata, sent once to Vertex AI in Frankfurt, and
# never stored or logged, under the same rule as the ID photos at the top of
# this file.


@https_fn.on_call()
def record_meal_photo_consent(request: https_fn.CallableRequest) -> dict:
    """E12: her consent to send a meal photo to Google Vertex AI for an estimate.

    Request {consentVersion, locale?, appVersion?}. The version must be
    config.MEAL_PHOTO_CONSENT_VERSION; any other is agreement to words we
    cannot account for and is refused with consent_missing. Recorded once at
    users/{uid}/consents/meal-photo-v1; agreeing again changes nothing. A
    locale or app version of the wrong shape is left out rather than stored.
    """
    uid = _require_auth(request)
    data = _body(request)
    version = data.get("consentVersion")
    if isinstance(version, bool) or version != config.MEAL_PHOTO_CONSENT_VERSION:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )
    store.write_meal_photo_consent(uid, data.get("locale"), data.get("appVersion"))
    return {"ok": True, "consentVersion": config.MEAL_PHOTO_CONSENT_VERSION}


@https_fn.on_call()
def withdraw_meal_photo_consent(request: https_fn.CallableRequest) -> dict:
    """She takes back her consent to send meal photos to Google Vertex AI. The
    record stays with the time she withdrew; analyze_meal_photo refuses until
    she consents again."""
    uid = _require_auth(request)
    _body(request)
    store.withdraw_meal_photo_consent(uid)
    return {"ok": True}


@https_fn.on_call()
def record_consent_choice(request: https_fn.CallableRequest) -> dict:
    """Her optional choice to share usage statistics or crash reports, or to
    stop. Request {purpose: "analytics" | "crash", granted: bool,
    consentVersion, locale?, appVersion?}. The version must be the current one
    for the purpose (config.CHOICE_CONSENT_VERSIONS). Every change is kept
    with its time; the choice itself is applied on her phone."""
    uid = _require_auth(request)
    data = _body(request)
    purpose, granted = data.get("purpose"), data.get("granted")
    version = data.get("consentVersion")
    if purpose not in config.CHOICE_CONSENT_VERSIONS or not isinstance(granted, bool):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    if isinstance(version, bool) or version != config.CHOICE_CONSENT_VERSIONS[purpose]:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )
    store.write_choice_consent(uid, purpose, granted, data.get("locale"), data.get("appVersion"))
    return {"ok": True}


@https_fn.on_call()
def analyze_meal_photo(request: https_fn.CallableRequest) -> dict:
    """One meal photo to the foods on it, with grams and macros she can edit.

    Request {imageJpeg: base64, locale: "en" | "ar"}. Order: App Check, auth,
    body, consent (meal-photo-v1), the image's size and header, the image
    decoded and re-encoded, then scanCache by the SHA-256 of the re-encoded
    bytes: a hit is answered with cached: true, no model call and no count. On
    a miss: her daily scans, the app's daily scans, then the model is called
    exactly once and its items are cached for 30 days. A photo that cannot be
    re-encoded is refused before either count moves, so it never costs her a
    scan.

    Response {items, totals, estimate: true, cached}; nutrition/meal.py
    documents each item. Refusals, each the whole message:
      consent_missing            FAILED_PRECONDITION
      image_undecodable,
      image_too_large            INVALID_ARGUMENT
      meal_scan_daily_limit,
      meal_scans_paused          RESOURCE_EXHAUSTED
      no_food_seen               NOT_FOUND
      meal_unclear               FAILED_PRECONDITION
      meal_service_unavailable   UNAVAILABLE (her scan is given back)
    """
    started = time.monotonic()
    uid = _require_auth(request)
    # Meal logging is for verified members only (the meal rules say the same),
    # and a scan costs money, so nobody else reaches the model.
    if _claim(request, "verified") is not True:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.NOT_VERIFIED
        )
    data = _body(request)
    locale = data.get("locale")
    if locale is not None and not store.valid_locale(locale):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    if not store.has_meal_photo_consent(uid):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )

    # Free checks first: the base64 length, the decode, and a JPEG, PNG or WebP
    # header declaring a sane size. A request that is not a photo does not
    # spend one of her scans.
    raw = _decode_image(data.get("imageJpeg"), {})
    refused = imagesize.refusal(raw)
    if refused is not None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, refused)

    from nutrition import cache as scan_cache
    from nutrition import config as meal_config
    from nutrition import meal, model, photo

    # Re-encoded before anything is counted: a header can look like a photo
    # and the body not be one, and that must not spend a scan, hers or the
    # app's. The size checks above bound what this decode can cost.
    try:
        jpeg = photo.reencode(raw)
    except photo.PhotoRejected as rejected:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, rejected.code
        )
    finally:
        del raw

    # The same photo again is answered from scanCache: no model call, and
    # neither her allowance nor the app's moves.
    cache_key = scan_cache.key(jpeg)
    cached = _scan_cache_get(cache_key)
    if cached is not None:
        del jpeg
        answer = meal.resolve(cached)
        answer["cached"] = True
        _log_meal("cached", None, started, count=len(answer["items"]))
        return answer

    try:
        if (
            store.uid_daily_count_and_increment(uid, meal_config.UID_COUNTER_FIELD)
            > meal_config.MEAL_SCANS_PER_UID_PER_DAY
        ):
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                reasons.MEAL_SCAN_DAILY_LIMIT,
            )
        if (
            store.daily_count_and_increment(meal_config.GLOBAL_COUNTER_FIELD)
            > meal_config.MEAL_SCANS_GLOBAL_PER_DAY
        ):
            logs.warn("meal_scans_paused", field=meal_config.GLOBAL_COUNTER_FIELD)
            _refund_meal_scan(uid, meal_config.UID_COUNTER_FIELD)
            raise https_fn.HttpsError(
                https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED,
                reasons.MEAL_SCANS_PAUSED,
            )
    except BaseException:
        del jpeg
        raise

    try:
        result = model.analyse(jpeg)
    except model.ServiceUnavailable as down:
        _refund_meal_scan(uid, meal_config.UID_COUNTER_FIELD)
        _log_meal(
            "unavailable", reasons.MEAL_SERVICE_UNAVAILABLE, started, model_error=down.label
        )
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAVAILABLE, reasons.MEAL_SERVICE_UNAVAILABLE
        )
    except model.Unclear as unclear:
        _log_meal(
            "unclear",
            reasons.MEAL_UNCLEAR,
            started,
            prompt_tokens=unclear.prompt_tokens,
            output_tokens=unclear.output_tokens,
        )
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.MEAL_UNCLEAR
        )
    finally:
        del jpeg

    if not result.items:
        _log_meal(
            "no_food",
            reasons.NO_FOOD_SEEN,
            started,
            prompt_tokens=result.prompt_tokens,
            output_tokens=result.output_tokens,
        )
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.NOT_FOUND, reasons.NO_FOOD_SEEN
        )

    _scan_cache_put(cache_key, result.items)
    answer = meal.resolve(result.items)
    answer["cached"] = False
    _log_meal(
        "estimated",
        None,
        started,
        count=len(answer["items"]),
        prompt_tokens=result.prompt_tokens,
        output_tokens=result.output_tokens,
    )
    return answer


def _scan_cache_get(cache_key: str) -> Optional[list]:
    """The cached items for this photo, or None. A cache that cannot be read is
    a miss, never a failed scan."""
    import datetime as dt

    from nutrition import cache

    try:
        return cache.get(store.db(), cache_key, dt.datetime.now(dt.timezone.utc))
    except Exception:
        logs.warn("scan_cache_unavailable")
        return None


def _scan_cache_put(cache_key: str, items: list) -> None:
    import datetime as dt

    from nutrition import cache

    try:
        cache.put(store.db(), cache_key, items, dt.datetime.now(dt.timezone.utc))
    except Exception:
        logs.warn("scan_cache_unavailable")


def _refund_meal_scan(uid: str, field: str) -> None:
    """Best effort: our outage must not cost her a scan, and a failed refund
    must not turn the honest answer into a different error."""
    try:
        store.uid_daily_refund(uid, field)
    except Exception:
        logs.warn("meal_scan_refund_failed")


def _log_meal(
    outcome: str,
    reason: Optional[str],
    started: float,
    *,
    count: Optional[int] = None,
    prompt_tokens: Optional[int] = None,
    output_tokens: Optional[int] = None,
    model_error: Optional[str] = None,
) -> None:
    """One decision line per model call: outcome, item count, latency and the
    token usage Vertex AI reported, or the model's error code when it failed.
    Never the photo, never a food name, never an error message."""
    fields: dict = {"outcome": outcome, "latencyMs": _ms(started)}
    if reason:
        fields["reasons"] = [reason]
    if count is not None:
        fields["count"] = count
    if prompt_tokens is not None:
        fields["promptTokens"] = prompt_tokens
    if output_tokens is not None:
        fields["outputTokens"] = output_tokens
    if model_error:
        fields["modelError"] = model_error
    logs.decision("analyze_meal_photo", **fields)


@https_fn.on_call()
def submit_community_food(request: https_fn.CallableRequest) -> dict:
    """E13: a meal she confirmed, offered to every woman after the owner checks
    it. Request {nameEn?, nameAr?, items: [{name, grams}], kcal, proteinG,
    carbsG, fatG}. Verified members only. Stored as a candidate with no uid and
    no photo; one confirmation per woman (a hashed marker). `{ok: true}`, also
    for a repeat. Refusals: community_food_invalid INVALID_ARGUMENT,
    community_food_daily_limit RESOURCE_EXHAUSTED."""
    uid = _require_auth(request)
    if _claim(request, "verified") is not True:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.NOT_VERIFIED
        )
    from nutrition import community_foods, config as meal_config

    row, _ = community_foods.validate_submission(_body(request))
    if row is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.COMMUNITY_FOOD_INVALID
        )
    if (
        store.uid_daily_count_and_increment(uid, meal_config.COMMUNITY_COUNTER_FIELD)
        > meal_config.COMMUNITY_FOODS_PER_UID_PER_DAY
    ):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.RESOURCE_EXHAUSTED, reasons.COMMUNITY_FOOD_DAILY_LIMIT
        )
    community_foods.submit(store.db(), community_foods.marker_id(uid, store.pepper()), row)
    return {"ok": True}
