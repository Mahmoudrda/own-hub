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
import uuid
from typing import Any, Optional

import firebase_admin
from firebase_functions import https_fn, options, scheduler_fn

from identity import (
    config,
    decisions,
    pipeline,
    providers,
    providers_selfhosted,
    reasons,
    store,
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
    if not raw:
        return None
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


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
    liveness = providers_selfhosted.SelfHostedLiveness(
        store=providers_selfhosted.ChallengeStore(
            put=store.FirestoreChallengeStore().put,
            take=store.FirestoreChallengeStore().take,
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
    store.write_consent(uid)
    return {"ok": True, "consentVersion": config.CONSENT_VERSION}


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

    # Spec §6's global kill switch, checked before anything is minted.
    if store.daily_count_and_increment() > config.DAILY_VERIFICATION_LIMIT:
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
    record = store.FirestoreChallengeStore()
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
    uid = _require_auth(request)
    data = request.data or {}

    if not store.has_consent(uid):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.CONSENT_MISSING
        )

    sizes: dict = {}
    card_front = _decode_image(data.get("front"), sizes)
    card_back = _decode_image(data.get("back"), sizes)
    frames = [_decode_image(frame, sizes) for frame in (data.get("frames") or [])]

    # Only the session id is taken from the client's `liveness` object. Anything
    # else it contains — notably an `outcome` — is discarded here and never
    # reaches the pipeline.
    session_id = (data.get("liveness") or {}).get("sessionId")

    niqab = bool(data.get("niqabPath"))
    if not niqab and not (
        config.MIN_SELFIE_FRAMES <= len(frames) <= config.MAX_SELFIE_FRAMES
    ):
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
        operation_id=str(data.get("operationId") or uuid.uuid4()),
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

    attempt = deps.ledger_store.read(uid).ocr_submissions
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
    elif decision.outcome == decisions.PENDING_REVIEW:
        _raise_flag(uid, job_id, decision, outcome)
    elif decision.outcome in (decisions.REJECTED_FAILED,) and outcome.id_hmac:
        # Spec §3's cross-account signal: count failures against the CARD, not
        # the account, so a series of fresh sign-ups on one stolen card is
        # visible.
        store.FirestoreBehaviour().record_failure(outcome.id_hmac)

    # The images go out of scope here and are collected. Nothing above wrote
    # them anywhere; this is belt and braces on an already-empty promise.
    del card_front, card_back, frames, inputs, outcome
    return _response(decision)


def _raise_flag(uid: str, job_id: str, decision, outcome) -> None:
    """Spec §5's admin review flow: a flag record with reason codes and no PII.

    The webhook carries only the flag id and the reason codes. It goes to a
    third-party chat service, so anything richer would be identity data sitting
    in someone else's message history.
    """
    from google.cloud import firestore

    payload = {
        "uid": uid,
        "jobId": job_id,
        "state": decisions.PENDING_REVIEW,
        "flags": list(decision.flags),
        "reasons": list(decision.reasons),
        "id_hmac": outcome.id_hmac,
        # Scores, not images. Spec §4 row 2 allowlists scores, and a reviewer
        # about to spend fifteen minutes on a video call should be able to see
        # whether the case is borderline-at-79 or nowhere-near-at-40. There is
        # nothing else for her to look at: no photograph exists.
        "liveness_confidence": outcome.liveness_confidence,
        "match_similarity": outcome.match_similarity,
        "scoreScales": {
            "liveness": config.ACTIVE_THRESHOLDS.liveness_scale,
            "match": config.ACTIVE_THRESHOLDS.match_scale,
        },
        "route": None,
        "scheduledFor": None,
        "createdAt": firestore.SERVER_TIMESTAMP,
        "slaExpiresAt": _sla_deadline(),
    }

    store.db().collection(config.COL_FLAGS).document(job_id).set(payload)
    _post_flag_webhook(job_id, decision.flags)


def _post_flag_webhook(flag_id: str, flags) -> None:
    """Spec §5: the flag id and reason codes only.

    Best effort. A chat webhook being down must never fail a verification that
    has already been decided, so every failure here is swallowed — the flag
    document is the durable record and the webhook is only a notification.
    """
    import os
    import json
    import urllib.request

    url = os.environ.get("FLAG_WEBHOOK_URL")
    if not url:
        return
    try:
        body = json.dumps({"flagId": flag_id, "reasons": list(flags)}).encode()
        req = urllib.request.Request(
            url, data=body, headers={"Content-Type": "application/json"}
        )
        urllib.request.urlopen(req, timeout=5).close()
    except Exception:
        pass


def _sla_deadline():
    import datetime as dt

    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(
        hours=config.REVIEW_SLA_HOURS
    )


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
    from google.cloud import firestore

    store.db().collection(config.COL_REVIEW_ACCESS).add(
        {
            "flagId": flag_id,
            "reviewerUid": reviewer_uid,
            "action": action,
            "at": firestore.SERVER_TIMESTAMP,
        }
    )


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def list_verification_flags(request: https_fn.CallableRequest) -> dict:
    """The review queue: reason codes, scores, and a scheduling handle.

    Never an image, because none exists. `scoreScales` travels with the scores
    so a reviewer reading "79" knows which scale it is on — the same unit
    confusion that `config.ThresholdSet` guards against in code would otherwise
    reappear in a human's head.
    """
    reviewer_uid = _require_admin(request)
    query = (
        store.db()
        .collection(config.COL_FLAGS)
        .where("state", "==", decisions.PENDING_REVIEW)
        .limit(50)
    )
    rows = []
    for snapshot in query.stream():
        data = snapshot.to_dict() or {}
        rows.append(
            {
                "flagId": snapshot.id,
                "flags": data.get("flags", []),
                "reasons": data.get("reasons", []),
                "livenessConfidence": data.get("liveness_confidence"),
                "matchSimilarity": data.get("match_similarity"),
                "scoreScales": data.get("scoreScales"),
                "route": data.get("route"),
                "scheduledFor": str(data.get("scheduledFor") or ""),
                "createdAt": str(data.get("createdAt")),
                "slaExpiresAt": str(data.get("slaExpiresAt") or ""),
                # She asked for the woman-reviewer route herself. Surfaced so the
                # queue can route it to a woman reviewer without her having to be
                # asked again, and without an admin opening it first.
                "requestedWomanReviewer": reasons.NIQAB_PATH_REQUESTED
                in data.get("flags", []),
            }
        )
    _log_review_access(reviewer_uid, "*", "list")
    return {"flags": rows}


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def schedule_verification_review(request: https_fn.CallableRequest) -> dict:
    """Book the live review. Spec §5's queue, rebuilt around an encounter.

    Request: {flagId, route: "video"|"gym", scheduledFor: ISO-8601}

    Only a woman reviewer may book, for both routes. A gym visit is still a
    woman meeting a woman in a women-only space; the route changes the venue,
    not who is qualified to do it.

    `scheduledFor` is stored as a handle, not as a calendar integration. What
    the product needs from the server is a durable record that a review was
    booked and when — the booking itself lives wherever the reviewers already
    keep their diary, and building a scheduler here would be inventing a
    calendar nobody asked for.
    """
    reviewer_uid = _require_woman_reviewer(request)
    data = request.data or {}
    flag_id = data.get("flagId")
    route = data.get("route")
    if route not in config.REVIEW_ROUTES:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )
    if not flag_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, reasons.INTERNAL_ERROR
        )

    from google.cloud import firestore

    reference = store.db().collection(config.COL_FLAGS).document(flag_id)
    if not reference.get().exists:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.NOT_FOUND, reasons.INTERNAL_ERROR
        )
    reference.update(
        {
            "route": route,
            "scheduledFor": data.get("scheduledFor"),
            "reviewerUid": reviewer_uid,
            "scheduledAt": firestore.SERVER_TIMESTAMP,
            "reasons": firestore.ArrayUnion([reasons.REVIEW_SCHEDULED]),
        }
    )
    _log_review_access(reviewer_uid, flag_id, f"schedule:{route}")
    return {"ok": True, "route": route}


@https_fn.on_call(enforce_app_check=config.ENFORCE_APP_CHECK)
def decide_verification_flag(request: https_fn.CallableRequest) -> dict:
    """Record the outcome of a live review.

    Request: {flagId, approve: bool}

    Requires the `womanReviewer` claim, not `admin`. The decision follows an
    encounter with a woman; the person who had the encounter is the person who
    records it, and there is no desk-based path because there is nothing on a
    desk to look at.
    """
    reviewer_uid = _require_woman_reviewer(request)
    data = request.data or {}
    flag_id = data.get("flagId")
    approve = bool(data.get("approve"))

    reference = store.db().collection(config.COL_FLAGS).document(flag_id)
    snapshot = reference.get()
    if not snapshot.exists:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.NOT_FOUND, reasons.INTERNAL_ERROR
        )
    record = snapshot.to_dict() or {}
    uid = record.get("uid")

    if record.get("route") not in config.REVIEW_ROUTES:
        # A decision with no booked review behind it is a desk decision on a
        # case there is no evidence for, which is exactly what this design
        # removes. Refusing keeps the audit trail honest.
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.FAILED_PRECONDITION, reasons.INTERNAL_ERROR
        )

    if approve:
        if record.get("id_hmac"):
            store.FirestoreRegistry().claim(record["id_hmac"], uid)
        store.mint_claims(uid, True)
        store.write_user_verification(uid)

    from google.cloud import firestore

    reference.update(
        {
            "state": decisions.APPROVED if approve else decisions.REJECTED_FAILED,
            "decidedBy": reviewer_uid,
            "decidedAt": firestore.SERVER_TIMESTAMP,
            "reviewerReason": reasons.REVIEWER_APPROVED
            if approve
            else reasons.REVIEWER_REJECTED,
        }
    )
    _log_review_access(reviewer_uid, flag_id, "decide")
    return {"ok": True, "outcome": decisions.APPROVED if approve else "rejected"}


@scheduler_fn.on_schedule(schedule="every 1 hours", region=config.REGION)
def expire_stale_reviews(event: scheduler_fn.ScheduledEvent) -> None:
    """A flagged case undecided past the SLA becomes RETRY_REQUIRED.

    RETRY_REQUIRED, not a rejection, and the reasoning is the whole of it: an
    undecided flag is OUR failure to review within 72 hours, not hers. Turning
    our own backlog into her rejection would be the wrong way round, and she
    gets one fresh attempt, still inside the cost cap.

    There is nothing to purge. The spec §5 version of this job deleted evidence
    on the same schedule; the evidence never exists now, so all that remains is
    the state transition.
    """
    import datetime as dt

    from google.cloud import firestore

    now = dt.datetime.now(dt.timezone.utc)
    query = (
        store.db()
        .collection(config.COL_FLAGS)
        .where("state", "==", decisions.PENDING_REVIEW)
        .where("slaExpiresAt", "<", now)
        .limit(200)
    )
    for snapshot in query.stream():
        snapshot.reference.update(
            {
                "state": decisions.RETRY_REQUIRED,
                "reasons": firestore.ArrayUnion([reasons.REVIEW_SLA_EXPIRED]),
                "expiredAt": firestore.SERVER_TIMESTAMP,
            }
        )
