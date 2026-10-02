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

    record_consent            free    spec §2 step 1, before any camera
    start_verification        free    mints the single-use liveness session
    verify_identity           paid    the whole pipeline, one round trip
    list_verification_flags   admin   the review queue: codes, scores, handle
    schedule_verification_review    woman reviewer books a call or a gym visit
    decide_verification_flag        records the outcome of that live review
    expire_stale_reviews      hourly  72-hour SLA -> RETRY_REQUIRED

Wire contract, agreed with the Flutter worker:
    `verify_identity` takes {front, back, frames, liveness:{sessionId}} and
    returns {outcome, reasons}. `liveness.outcome`, if a client sends one, is
    IGNORED — see the note on `verify_identity`. `reasons` carries only the
    coarse user-safe hints from reasons.to_user_safe, never internal codes.

Every callable checks, in this order and before doing any work: authentication,
App Check, consent where required, attempt limits, the cost ledger. Spec §5.
"""

from __future__ import annotations

import base64
import hashlib
import time
import uuid
from typing import Any, Optional

import firebase_admin
from firebase_functions import https_fn, options, scheduler_fn

from identity import (
    config,
    decisions,
    pipeline,
    providers,
    logs,
    providers_selfhosted,
    reasons,
    review,
    store,
    webhook,
)

firebase_admin.initialize_app()

options.set_global_options(
    region=config.REGION,
    memory=options.MemoryOption.GB_1,
    timeout_sec=config.TIMEOUT_SEC,
    max_instances=config.MAX_INSTANCES,
)

# App Check is applied through `enforce_app_check=` on each decorator below.
# firebase-functions 0.6.0 exposes it as a plain bool there and has no
# AppCheckPolicy enum, so there is nothing to translate — but `_require_auth`
# re-checks `request.app` anyway, because whether the decorator actually
# enforced depends on a deploy-time option and a silently unenforced deploy
# would not show up in any test.


# ----------------------------------------------------------------- helpers


def _require_auth(request: https_fn.CallableRequest) -> str:
    """Authentication, then App Check. Never assume the decorator did it.

    `enforce_app_check` on the decorator is the real gate, but this is checked
    again here because the decorator's behaviour depends on a deploy-time option
    and a silently unenforced deploy is exactly the configuration mistake that
    would not show up in any test.
    """
    if request.auth is None or not request.auth.uid:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAUTHENTICATED, reasons.UNAUTHENTICATED
        )
    if config.ENFORCE_APP_CHECK and request.app is None:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.APP_CHECK_MISSING
        )
    return request.auth.uid


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
        return base64.b64decode(value, validate=True)
    except Exception:
        # Bare, and nothing from the exception propagates: a base64 error
        # message can quote the offending input, which here is image data.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.IMAGE_UNDECODABLE
        )


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


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def record_consent(request: https_fn.CallableRequest) -> dict:
    """Spec §2 step 1: persisted before any camera access.

    Three fields, per spec §4 row 3: uid, consent version, timestamp. Not the
    text, not her IP, not her device. The version is the only thing tying the
    record to what she was actually shown, which is why config.CONSENT_VERSION
    must be bumped whenever that text changes.
    """
    uid = _require_auth(request)
    version = (request.data or {}).get("consentVersion")
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
        store.write_consent(uid)
    return {"ok": True, "consentVersion": config.CONSENT_VERSION}


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
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
    data = request.data or {}
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


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
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


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
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
    data = request.data or {}
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
        store.set_verification_state(uid, review.STATE_REJECTED, decided=True)
    if failed_check and outcome.id_hmac:
        # Spec §3's cross-account signal: count failures against the CARD, not
        # the account, so a series of fresh sign-ups on one stolen card is
        # visible.
        store.FirestoreBehaviour().record_failure(outcome.id_hmac)

    # The images go out of scope here and are collected. Nothing above wrote
    # them anywhere; this is belt and braces on an already-empty promise.
    del card_front, card_back, frames, inputs, outcome
    logs.decision(
        "verify_identity",
        outcome=decision.outcome,
        reasons=list(decision.reasons),
        latencyMs=_ms(started),
        jobId=job_id,
    )
    return _response(decision)


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
        store.set_verification_state(uid, review.STATE_PENDING, reset_booking=True)
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


def _require_admin(request: https_fn.CallableRequest) -> str:
    """The `admin` claim, server-minted exactly like `verified`.

    `firebase/firestore.rules` already defines `isAdmin()` as
    `request.auth.token.admin == true`, so this matches what the rules enforce.
    A client cannot grant itself admin any more than it can grant itself a
    verified badge.
    """
    uid = _require_auth(request)
    if not (request.auth.token or {}).get("admin"):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.UNAUTHENTICATED
        )
    return uid


def _require_woman_reviewer(request: https_fn.CallableRequest) -> str:
    """The claim that may decide a live review.

    A SEPARATE claim from `admin`, and the separation is the point. An admin
    administers a system. A woman reviewer meets a woman — on a video call or at
    a ladies-only gym — and is herself a woman, which is the entire reason the
    route exists and is the one property no amount of administrative privilege
    substitutes for.

    Minted out of band by staff. There is no self-service path, exactly like
    `admin`.
    """
    uid = _require_auth(request)
    if not (request.auth.token or {}).get("womanReviewer"):
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


def _body(request: https_fn.CallableRequest) -> dict:
    data = request.data or {}
    if not isinstance(data, dict):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    return data


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def request_review(request: https_fn.CallableRequest) -> dict:
    """She asks for a woman reviewer: {path: "niqab" | "declined" | "error"}.

    S3. Takes no images, no frames and no phone number. N7: first records
    users/{uid}/consents/review-v1 = {version, at, path}; asking for the call
    is the consent to be looked up and called (the app shows the wording
    before calling; wording PENDING COUNSEL). Then writes a flag with the
    path's reason code, at most one open flag per account, and sets her
    verification state to `pending`. Returns {state: "pending"}, or
    {state: "approved"} if she is already verified.
    """
    started = time.monotonic()
    uid = _require_auth(request)
    data = _body(request)
    result = _review_call(review.request, store.FirestoreReviewStore(), uid, data.get("path"))
    logs.decision(
        "request_review",
        outcome=decisions.PENDING_REVIEW if result.state == review.STATE_PENDING else result.state,
        state=result.state,
        reasons=[result.code] if result.code else [],
        latencyMs=_ms(started),
        flagId=result.flag_id,
    )
    return {"state": result.state}


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def list_verification_flags(request: https_fn.CallableRequest) -> dict:
    """The review queue, oldest first: reason codes, scores, and a handle.

    Never an image, because none exists, and never a phone number.

    N8: a woman reviewer may read it (she works the queue with her own
    account through tools/review_queue.py, which holds no admin credentials);
    an admin still may. Every read is written to the access log.
    """
    reviewer_uid = _require_auth(request)
    token = request.auth.token or {}
    if not (token.get("womanReviewer") or token.get("admin")):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.PERMISSION_DENIED, reasons.UNAUTHENTICATED
        )
    rows = review.list_open(store.FirestoreReviewStore(), reviewer_uid)
    return {"flags": rows}


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def get_review_contact(request: https_fn.CallableRequest) -> dict:
    """Her phone number, for the woman reviewer about to call her.

    Looked up from Firebase Auth at the moment of calling, never copied onto
    the flag, never logged. Each lookup is written to the review access log.
    Refused unless the flag is PENDING_REVIEW and the reviewer is not her.
    """
    reviewer_uid = _require_woman_reviewer(request)
    data = _body(request)
    return _review_call(
        review.contact, store.FirestoreReviewStore(), reviewer_uid, data.get("flagId")
    )


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
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


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
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


@scheduler_fn.on_schedule(schedule="every 1 hours", region=config.REGION)
def expire_stale_reviews(event: scheduler_fn.ScheduledEvent) -> None:
    """A flagged case undecided past the SLA becomes RETRY_REQUIRED.

    Our failure to review within 72 hours, not hers: her state becomes `retry`,
    and she earns one more OCR submission if it still fits under the cost cap.
    Nothing is ever reset. See review.expire.
    """
    import datetime as dt

    count = review.expire(store.FirestoreReviewStore(), dt.datetime.now(dt.timezone.utc))
    logs.decision("expire_stale_reviews", outcome=decisions.RETRY_REQUIRED, count=count)


# ------------------------------------------------------------- deletion


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
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
    uid = _require_auth(request)
    from account import deletion

    started = time.monotonic()
    try:
        result = deletion.run(uid, deletion.FirebaseBackend())
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
    finished = failed = 0
    for uid in deletion.unfinished(store.db(), cutoff):
        try:
            deletion.run(uid, deletion.FirebaseBackend())
            finished += 1
        except Exception:
            failed += 1
    # N9: the one late sweep of users/{uid} and plans/{uid}, 65 minutes after
    # done, for writes a still-valid token or a queued client made meanwhile.
    for uid in deletion.due_resweeps(store.db(), dt.datetime.now(dt.timezone.utc)):
        try:
            deletion.resweep(uid, deletion.FirebaseBackend())
        except Exception:
            failed += 1
    logs.decision("resume_account_deletions", state="done", count=finished)
    if failed:
        logs.error("account_deletion_failed", state=deletion.FAILED_RETRYABLE, count=failed)
