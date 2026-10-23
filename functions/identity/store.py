"""The Firestore side: transactions, TTLs, and the secret.

Every interface the pure modules declared gets its real implementation here, and
every one of them is transactional where a race would break a promise:

  * `FirestoreLedger.spend` — check-and-debit in one transaction, idempotent on
    `operation_id`, because spec §5 requires a double tap not to double-charge.
  * `FirestoreRegistry.claim` — read-and-write in one transaction, because two
    accounts submitting the same card at the same moment would otherwise both
    see "no entry" and both register.
  * `FirestoreChallengeStore.take` — read-and-consume in one transaction,
    because spec §5 requires a sessionId to be single-use and a read followed by
    a separate write is an exploitable race.

None of these write an image, a name, a birth date or a raw ID number. Spec §4's
allowlist is the contract, and `_allowlisted` below enforces it at the boundary
rather than trusting every call site to remember.
"""

from __future__ import annotations

import datetime as dt
import random
import re
import threading
from dataclasses import dataclass
from typing import Optional

from google.cloud import firestore

from . import config, dedupe, decisions, ledger, reasons

_db = None
_db_lock = threading.Lock()


def db() -> firestore.Client:
    """One client per process. Creating one per call leaks connections."""
    global _db
    if _db is None:
        with _db_lock:
            if _db is None:
                _db = firestore.Client(project="own-hub")
    return _db


# ----------------------------------------------------------------- secrets

_pepper_cache: Optional[bytes] = None
_pepper_lock = threading.Lock()


def pepper() -> bytes:
    """Read ID_PEPPER from Secret Manager, once per process.

    Read at runtime over the API rather than through a `secrets=[...]` binding
    on the callable, for one concrete reason: the secret resource that actually
    exists in this project is named `nid-hash-pepper`, with dashes. Firebase's
    secret binding maps a secret's name onto an environment variable of the same
    name, and dashes are not valid in an environment variable name on every
    platform in that path. Reading it directly avoids renaming a secret that
    already exists, and avoids the class of bug where it appears to work in the
    emulator and fails on deploy.

    Cached for the life of the instance. Secret Manager charges per access
    operation, and an uncached read would add one billed call to every
    verification for a value that never changes within a deploy.

    NEVER logged, never returned to a caller, never written to Firestore.
    """
    global _pepper_cache
    if _pepper_cache is None:
        with _pepper_lock:
            if _pepper_cache is None:
                from google.cloud import secretmanager

                client = secretmanager.SecretManagerServiceClient()
                name = (
                    f"projects/own-hub/secrets/{config.SECRET_PEPPER}"
                    f"/versions/latest"
                )
                response = client.access_secret_version(request={"name": name})
                _pepper_cache = response.payload.data
    return _pepper_cache


_reviewer_cache: Optional[tuple[float, frozenset]] = None
_reviewer_phone_cache: Optional[tuple[float, frozenset]] = None


def parse_reviewer_uids(raw: str) -> frozenset:
    """Uids from the secret's text: comma or newline separated, blanks and
    anything that is not a plausible Firebase uid dropped."""
    out = set()
    for part in re.split(r"[,\s]+", raw or ""):
        part = part.strip()
        if re.fullmatch(r"[A-Za-z0-9_-]{6,128}", part):
            out.add(part)
    return frozenset(out)


def parse_reviewer_phones(raw: str) -> frozenset:
    """E.164 numbers from the secret's text, one per line or comma separated.

    Spaces and dashes inside a number are ignored, so "+20 100 000 0000" and
    "+201000000000" are the same entry. Anything that is not a full
    international number starting with "+" is dropped: a bare local number
    could match the wrong person's token."""
    out = set()
    for line in re.split(r"[,\n;]+", raw or ""):
        number = re.sub(r"[\s\-()]", "", line)
        if re.fullmatch(r"\+[1-9][0-9]{7,14}", number):
            out.add(number)
    return frozenset(out)


def _read_reviewer_secret(secret_id: str, parse, cache_name: str) -> frozenset:
    """One cached, fail-closed read of a reviewer allow-list secret."""
    import time as _time

    cached = globals()[cache_name]
    now = _time.monotonic()
    if cached is not None and now - cached[0] < config.REVIEWER_UIDS_CACHE_SEC:
        return cached[1]
    values: frozenset = frozenset()
    try:
        from google.cloud import secretmanager

        client = secretmanager.SecretManagerServiceClient()
        name = f"projects/own-hub/secrets/{secret_id}/versions/latest"
        response = client.access_secret_version(request={"name": name})
        values = parse(response.payload.data.decode("utf-8"))
    except Exception:  # noqa: BLE001 - fail closed: nobody is a reviewer
        values = frozenset()
    globals()[cache_name] = (now, values)
    return values


def store_reviewer_uids() -> frozenset:
    """M13: the store review accounts, from Secret Manager. Empty on any
    failure, so an unreadable secret lets nobody through."""
    return _read_reviewer_secret(
        config.SECRET_REVIEWER_UIDS, parse_reviewer_uids, "_reviewer_cache"
    )


def store_reviewer_phones() -> frozenset:
    """M13: the store review phone numbers, from Secret Manager. A reviewer who
    deletes her account and signs in again with the same test number gets a
    new uid; the number is what stays the same. Empty on any failure."""
    return _read_reviewer_secret(
        config.SECRET_REVIEWER_PHONES, parse_reviewer_phones, "_reviewer_phone_cache"
    )


_real_store_reviewer_uids = store_reviewer_uids
_real_store_reviewer_phones = store_reviewer_phones
"""The unstubbed readers, for the fail-closed tests (conftest replaces
`store_reviewer_uids` and `store_reviewer_phones` in every test)."""


# ------------------------------------------------------------------ ledger


class FirestoreLedger:
    """Spec §6's per-uid cost ledger."""

    def read(self, uid: str) -> ledger.Budget:
        snapshot = db().collection(config.COL_LEDGER).document(uid).get()
        if not snapshot.exists:
            return ledger.Budget()
        data = snapshot.to_dict() or {}
        return ledger.Budget(
            spent_micro_usd=int(data.get("spent_micro_usd", 0)),
            ocr_submissions=int(data.get("ocr_submissions", 0)),
            liveness_attempts=int(data.get("liveness_attempts", 0)),
            # Carried so the pipeline can refuse a replayed operation id BEFORE
            # it calls Vision. See Budget.operations for why checking it inside
            # `spend` is too late to stop the bill.
            operations=tuple(data.get("operations", []) or ()),
            bonus_ocr_submissions=int(data.get("bonusOcrSubmissions", 0)),
        )

    def spend(
        self, uid: str, kind: str, cost: int, operation_id: str
    ) -> tuple[bool, ledger.Budget, Optional[str]]:
        reference = db().collection(config.COL_LEDGER).document(uid)

        @firestore.transactional
        def txn(transaction):
            snapshot = reference.get(transaction=transaction)
            data = snapshot.to_dict() if snapshot.exists else {}
            applied = list(data.get("operations", []))

            budget = ledger.Budget(
                spent_micro_usd=int(data.get("spent_micro_usd", 0)),
                ocr_submissions=int(data.get("ocr_submissions", 0)),
                liveness_attempts=int(data.get("liveness_attempts", 0)),
                operations=tuple(applied),
                bonus_ocr_submissions=int(data.get("bonusOcrSubmissions", 0)),
            )

            # Idempotency. A retried tap carries the same operation_id and must
            # return the first call's answer rather than charging again.
            #
            # This is the LAST line of defence, not the first one. By the time
            # execution reaches here the provider has already been called and
            # billed, so skipping the debit here without also refusing the
            # request earlier turns a replayed operation id into free provider
            # calls. pipeline._run checks Budget.already_applied before it
            # contacts Vision, and that is the check that protects the money.
            if operation_id in applied:
                return False, budget, None

            refusal = ledger.check(budget, kind, cost)
            if refusal is not None:
                return False, budget, refusal.code

            updated = ledger.apply(budget, kind, cost)
            updated = ledger.Budget(
                spent_micro_usd=updated.spent_micro_usd,
                ocr_submissions=updated.ocr_submissions,
                liveness_attempts=updated.liveness_attempts,
                operations=tuple((applied + [operation_id])[-50:]),
                bonus_ocr_submissions=budget.bonus_ocr_submissions,
            )
            # Bounded: keeping every operation id forever would grow this
            # document without limit, and a Firestore document is capped at 1 MiB.
            # The last 50 covers any plausible retry window.
            transaction.set(
                reference,
                {
                    "spent_micro_usd": updated.spent_micro_usd,
                    "ocr_submissions": updated.ocr_submissions,
                    "liveness_attempts": updated.liveness_attempts,
                    "operations": (applied + [operation_id])[-50:],
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                },
                # MERGE. The ledger document also carries openFlagId,
                # duplicateFlagRaised, bonusOcrSubmissions and the per-uid
                # daily counters; a full overwrite here would erase them.
                merge=True,
            )
            return True, updated, None

        return txn(db().transaction())


# ---------------------------------------------------------------- registry


class FirestoreRegistry:
    """One national ID, one account. Spec §2 step 5."""

    def read(self, id_hmac: str) -> Optional[dedupe.RegistryEntry]:
        snapshot = db().collection(config.COL_NID_REGISTRY).document(id_hmac).get()
        if not snapshot.exists:
            return None
        data = snapshot.to_dict() or {}
        return dedupe.RegistryEntry(
            uid=data.get("uid"),
            state=data.get("state", dedupe.STATE_ACTIVE),
            pepper_version=int(data.get("pepper_version", 0)),
        )

    def claim(self, id_hmac: str, uid: str) -> dedupe.DedupeVerdict:
        reference = db().collection(config.COL_NID_REGISTRY).document(id_hmac)

        @firestore.transactional
        def txn(transaction):
            snapshot = reference.get(transaction=transaction)
            existing = None
            if snapshot.exists:
                data = snapshot.to_dict() or {}
                existing = dedupe.RegistryEntry(
                    uid=data.get("uid"),
                    state=data.get("state", dedupe.STATE_ACTIVE),
                    pepper_version=int(data.get("pepper_version", 0)),
                )
            verdict = dedupe.judge(existing, uid)
            if verdict.ok and not verdict.is_reverification:
                payload = dedupe.registry_document(uid)
                payload["createdAt"] = firestore.SERVER_TIMESTAMP
                transaction.set(reference, payload)
            return verdict

        return txn(db().transaction())


# --------------------------------------------------------------- challenges


class FirestoreChallengeStore:
    """Ephemeral session state. Spec §4: maximum one hour, no images, no raw ID.

    `expiresAt` is written so a Firestore TTL policy can sweep these. The TTL
    policy itself is a project-level configuration this code cannot create; it
    is listed in DECISIONS_NEEDED.md as a deploy step, because a TTL field with
    no TTL policy behind it is a document that lives forever while looking like
    it does not.
    """

    def put(self, session_id: str, record: dict) -> None:
        payload = dict(record)
        payload["createdAt"] = firestore.SERVER_TIMESTAMP
        payload["expiresAt"] = dt.datetime.now(dt.timezone.utc) + dt.timedelta(
            seconds=config.CHALLENGE_TTL_SEC
        )
        db().collection(config.COL_SESSIONS).document(session_id).set(payload)

    def take(self, session_id: str) -> Optional[dict]:
        reference = db().collection(config.COL_SESSIONS).document(session_id)

        @firestore.transactional
        def txn(transaction):
            snapshot = reference.get(transaction=transaction)
            if not snapshot.exists:
                return None
            data = snapshot.to_dict() or {}
            if data.get("consumed"):
                return {**data, "consumed": True}
            expires = data.get("expiresAt")
            if expires is not None and expires < dt.datetime.now(dt.timezone.utc):
                return {**data, "expired": True}
            # Consume inside the same transaction that read it. Two concurrent
            # requests cannot both see "unused".
            transaction.update(reference, {"consumed": True})
            return data

        return txn(db().transaction())


# --------------------------------------------------------------- behaviour


class FirestoreBehaviour:
    """Spec §3's two cross-account FLAG signals.

    Both counters are keyed on a hash, never on a device identifier or an ID
    number, so this collection is not a tracking database even for someone who
    obtains it.
    """

    def failures_for_hmac(self, id_hmac: str) -> int:
        snapshot = db().collection("verificationBehaviour").document(id_hmac).get()
        return int((snapshot.to_dict() or {}).get("failures", 0)) if snapshot.exists else 0

    def distinct_hmacs_for_install(self, install_id_hash: str) -> int:
        snapshot = (
            db().collection("verificationInstalls").document(install_id_hash).get()
        )
        if not snapshot.exists:
            return 0
        return len((snapshot.to_dict() or {}).get("hmacs", []))

    def record_attempt(self, id_hmac: str, install_id_hash: Optional[str]) -> None:
        """M9: every write moves `expireAt` on by config.SIGNAL_RETENTION_DAYS,
        so an installation that stops trying is swept by the TTL policy."""
        if not install_id_hash:
            return
        reference = db().collection("verificationInstalls").document(install_id_hash)

        @firestore.transactional
        def txn(transaction):
            snapshot = reference.get(transaction=transaction)
            seen = list((snapshot.to_dict() or {}).get("hmacs", [])) if snapshot.exists else []
            if id_hmac not in seen:
                seen.append(id_hmac)
            transaction.set(
                reference,
                {
                    "hmacs": seen[-10:],
                    "updatedAt": firestore.SERVER_TIMESTAMP,
                    "expireAt": signal_expiry(),
                },
            )

        txn(db().transaction())

    def record_failure(self, id_hmac: str) -> None:
        """M9: the count lives config.SIGNAL_RETENTION_DAYS past its last
        failure, then the TTL policy on `expireAt` deletes it."""
        db().collection("verificationBehaviour").document(id_hmac).set(
            {
                "failures": firestore.Increment(1),
                "updatedAt": firestore.SERVER_TIMESTAMP,
                "expireAt": signal_expiry(),
            },
            merge=True,
        )


def signal_expiry() -> dt.datetime:
    """When a fraud signal may be swept. PENDING COUNSEL, see config."""
    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(
        days=config.SIGNAL_RETENTION_DAYS
    )


def access_log_expiry() -> dt.datetime:
    """When a reviewer access log entry may be swept. PENDING COUNSEL."""
    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(
        days=config.ACCESS_LOG_RETENTION_DAYS
    )


# ------------------------------------------------------- the allowlist guard

_ALLOWED_JOB_FIELDS = frozenset(
    {
        "uid",
        "state",
        "reasons",
        "flags",
        "attempt",
        "spent_micro_usd",
        "provider_ids",
        "liveness_band",
        "match_band",
        "createdAt",
        "decidedAt",
        "imagesDeletedAt",
        "decidedBy",
        "pepper_version",
        "schemaV",
        "expireAt",
    }
)
"""Spec §4's row 2, enumerated.

Note what is absent and why each absence is deliberate:
  * no raw scores — a reviewer sees a BAND ("uncertain"), not a number. Spec §3
    forbids exposing scores to the user and there is no reason a reviewer needs
    one either: a cosine they cannot interpret invites them to second-guess it,
    and a raw biometric score tied to a uid is a small real leak about her face.
  * no free text of any kind. There is no `notes` field, so there is nowhere for
    a description of a woman to be written.
  * no name, address, birth date, governorate, or ID number.
"""


def _allowlisted(payload: dict) -> dict:
    """Refuse to write a field spec §4 does not permit.

    Raises rather than silently dropping. A dropped field is a bug that looks
    like it worked; a raised error is a bug that gets fixed. This is the last
    line of defence before Firestore, and it is the one that would catch a
    future change that started persisting something it should not.
    """
    extra = set(payload) - _ALLOWED_JOB_FIELDS
    if extra:
        raise ValueError(
            f"spec §4 does not permit persisting {sorted(extra)}. Add a row to "
            f"the allowlist table and to _ALLOWED_JOB_FIELDS, or do not write it."
        )
    return payload


def write_job(uid: str, decision, outcome, attempt: int) -> str:
    """Record the outcome. Spec §4 row 2.

    `imagesDeletedAt` is set to the decision time, and that claim is literally
    true rather than aspirational: the images were never written anywhere, so
    by the moment this document exists they are gone from the only place they
    ever were, which is this process's memory. The app's A03 privacy screen
    reads this field to decide whether it may say "your ID and selfie were
    deleted after the check", and it now may.
    """
    payload = job_payload(
        uid, decision, attempt, outcome.spent_micro_usd, outcome.provider_ids
    )
    _, reference = db().collection(config.COL_VERIFICATION_JOBS).add(payload)
    return reference.id


def job_payload(
    uid: str, decision, attempt: int, spent_micro_usd: int = 0, provider_ids=None
) -> dict:
    """The allowlisted job document, without writing it.

    Split out of write_job so a PENDING_REVIEW job can be written inside the
    same transaction as its flag (one open flag per uid).

    S16: a decided job carries `expireAt` for the Firestore TTL policy. A job
    waiting on review does not; it gets one when its flag is decided or
    expires."""
    payload = {
            "uid": uid,
            "state": decision.outcome,
            "reasons": list(decision.reasons),
            "flags": list(decision.flags),
            "attempt": attempt,
            "spent_micro_usd": spent_micro_usd,
            "provider_ids": dict(provider_ids or {}),
            "liveness_band": _band_name(decision, "liveness"),
            "match_band": _band_name(decision, "match"),
            "pepper_version": config.PEPPER_VERSION,
            "schemaV": 1,
            "createdAt": firestore.SERVER_TIMESTAMP,
            "decidedAt": firestore.SERVER_TIMESTAMP,
            "imagesDeletedAt": firestore.SERVER_TIMESTAMP,
            "decidedBy": "system",
        }
    if decision.outcome != decisions.PENDING_REVIEW:
        payload["expireAt"] = decided_expiry()
    return _allowlisted(payload)


def decided_expiry() -> dt.datetime:
    """When a decided job or flag may be swept. PENDING COUNSEL, see config."""
    return dt.datetime.now(dt.timezone.utc) + dt.timedelta(
        days=config.DECIDED_RECORD_RETENTION_DAYS
    )


def _band_name(decision, which: str) -> str:
    """A coarse word, never a number."""
    flag_code = reasons.LIVENESS_FLAG_BAND if which == "liveness" else reasons.MATCH_FLAG_BAND
    fail_code = reasons.LIVENESS_FAILED if which == "liveness" else reasons.MATCH_FAILED
    pass_code = reasons.LIVENESS_PASS if which == "liveness" else reasons.MATCH_PASS
    if fail_code in decision.reasons:
        return "below"
    if flag_code in decision.reasons:
        return "uncertain"
    if pass_code in decision.reasons:
        return "pass"
    return "not_run"


def mint_claims(uid: str, verified: bool) -> None:
    """Set the `verified` custom claim WITHOUT destroying the others.

    `set_custom_user_claims` REPLACES the entire claims map. Writing
    `{"verified": True}` on a coach would silently strip her `coachV: "active"`
    claim and lock her out of every coach document she owns — a bug that would
    only appear for the small group of users who are both, and would look like a
    Firestore rules problem rather than a claims problem.

    So: read, merge, write.

    On the claim name — spec §5 says "for example `vf: true`, `vstatus`", which
    is illustrative. The repository's `firebase/firestore.rules` already reads
    `request.auth.token.verified == true` and `request.auth.token.coachV ==
    'active'` in 864 lines of rules that were written against those names.
    Matching the existing file beats matching an example, so `verified` it is.
    Recorded in VERIFICATION_SPEC_DELTA.md.
    """
    from firebase_admin import auth

    user = auth.get_user(uid)
    claims = dict(user.custom_claims or {})
    claims["verified"] = bool(verified)
    if not verified and claims.get("coachV") == "active":
        claims["coachV"] = "suspended"
    auth.set_custom_user_claims(uid, claims)


def write_user_verification(uid: str) -> None:
    """The two fields the Flutter app's `VerificationRecord` actually reads.

    `app/lib/features/account/domain/verification_claim.dart` models exactly
    `decidedAt` and `imagesDeletedAt` and nothing else. Writing more would put
    fields on the user document that no client reads and that spec §4 does not
    allow.
    """
    set_verification_state(uid, "approved", decided=True)


VERIFICATION_STATES = frozenset({"approved", "pending", "rejected", "retry"})
"""users/{uid}.verification.state (S8). Mirrors review.VERIFICATION_STATES and
contracts/identity_contract.json documents.verificationState.states."""


def set_verification_state(
    uid: str,
    state: str,
    *,
    route=None,
    scheduled_for=None,
    decided: bool = False,
    reset_booking: bool = False,
    keep_approved: bool = False,
) -> bool:
    """S8: the one server-written place she can read where her check stands.

    A merge of `verification.*` keys only. No reason codes and no flag id: the
    map is hers to read (rules: isSelf) and must not teach anyone which check
    failed. The client can never write it (rules: verificationUntouched).

    With `keep_approved`, the write is a transaction that leaves an `approved`
    state alone: verify_identity's own outcome may never turn an approval that
    landed while it ran back into `pending` or `rejected`. Returns False when
    it left the state as it was."""
    ref = db().collection(config.COL_USERS).document(uid)
    update = _verification_update(
        state,
        route=route,
        scheduled_for=scheduled_for,
        decided=decided,
        reset_booking=reset_booking,
    )
    if not keep_approved or state == "approved":
        ref.set(update, merge=True)
        return True

    @firestore.transactional
    def txn(transaction):
        snapshot = ref.get(transaction=transaction)
        data = (snapshot.to_dict() or {}) if snapshot.exists else {}
        current = data.get("verification") or {}
        if isinstance(current, dict) and current.get("state") == "approved":
            return False
        transaction.set(ref, update, merge=True)
        return True

    return txn(db().transaction())


def _verification_update(
    state: str,
    *,
    route=None,
    scheduled_for=None,
    decided: bool = False,
    reset_booking: bool = False,
) -> dict:
    """The merge payload for users/{uid}.verification, for a plain write or a
    transaction (R5: booking, rejection and expiry write it inside theirs)."""
    if state not in VERIFICATION_STATES:
        raise ValueError(f"unknown verification state {state!r}")
    fields: dict = {"state": state, "updatedAt": firestore.SERVER_TIMESTAMP}
    if reset_booking:
        fields["reviewRoute"] = None
        fields["reviewScheduledFor"] = None
    if route is not None:
        fields["reviewRoute"] = route
    if scheduled_for is not None:
        fields["reviewScheduledFor"] = scheduled_for
    if decided:
        fields["decidedAt"] = firestore.SERVER_TIMESTAMP
        if state == "approved":
            fields["imagesDeletedAt"] = firestore.SERVER_TIMESTAMP
    return {"verification": fields}


def verification_state(uid: str) -> Optional[str]:
    snapshot = db().collection(config.COL_USERS).document(uid).get()
    if not snapshot.exists:
        return None
    verification = (snapshot.to_dict() or {}).get("verification") or {}
    state = verification.get("state") if isinstance(verification, dict) else None
    return state if state in VERIFICATION_STATES else None


VERIFY_IN_FLIGHT_FIELD = "verifyInFlightUntil"
"""On verificationLedger/{uid}: until when a verify_identity call for her may
still be running. Server-only, like the rest of the ledger."""


def _ledger_ref(uid: str):
    return db().collection(config.COL_LEDGER).document(uid)


def mark_verify_in_flight(uid: str, now: Optional[dt.datetime] = None) -> None:
    """verify_identity has started for her. request_review refuses until
    clear_verify_in_flight, or until config.VERIFY_IN_FLIGHT_SEC have passed."""
    now = now or dt.datetime.now(dt.timezone.utc)
    until = now + dt.timedelta(seconds=config.VERIFY_IN_FLIGHT_SEC)
    _ledger_ref(uid).set({VERIFY_IN_FLIGHT_FIELD: until}, merge=True)


def clear_verify_in_flight(uid: str) -> None:
    _ledger_ref(uid).set({VERIFY_IN_FLIGHT_FIELD: None}, merge=True)


def verify_in_flight(uid: str, now: Optional[dt.datetime] = None) -> bool:
    snapshot = _ledger_ref(uid).get()
    if not snapshot.exists:
        return False
    until = (snapshot.to_dict() or {}).get(VERIFY_IN_FLIGHT_FIELD)
    if not isinstance(until, dt.datetime):
        return False
    if until.tzinfo is None:
        until = until.replace(tzinfo=dt.timezone.utc)
    return until > (now or dt.datetime.now(dt.timezone.utc))


def write_consent(
    uid: str, locale: Optional[str] = None, app_version: Optional[str] = None
) -> None:
    """Spec §2 step 1 / §4 row 3: the consent version and a timestamp, plus
    (version 2) the language the wording was shown in and the app version
    that showed it. Five fields at most, counting the uid in the path.

    Not the text she agreed to, not her IP, not her device. The version is
    what ties the record to what she was shown, which is why
    config.CONSENT_VERSION must be bumped whenever that text changes. A
    locale or app version that does not pass `consent_extras` is left out
    rather than stored.
    """
    payload = {
        "version": config.CONSENT_VERSION,
        "at": firestore.SERVER_TIMESTAMP,
    }
    payload.update(consent_extras(locale, app_version))
    db().collection(config.COL_USERS).document(uid).collection(
        config.COL_CONSENTS
    ).document(f"verification-v{config.CONSENT_VERSION}").set(payload)


def valid_locale(value) -> bool:
    return isinstance(value, str) and value in config.CONSENT_LOCALES


def valid_app_version(value) -> bool:
    return isinstance(value, str) and re.match(config.APP_VERSION_PATTERN, value) is not None


def consent_extras(locale, app_version) -> dict:
    """The optional `locale` and `appVersion` of a consent record, each only
    if it is one of the allowed shapes."""
    extras = {}
    if valid_locale(locale):
        extras["locale"] = locale
    if valid_app_version(app_version):
        extras["appVersion"] = app_version
    return extras


LEGAL_ACCEPTANCE_FIELDS = (
    "termsVersion",
    "privacyVersion",
    "locale",
    "appVersion",
    "platform",
    "clientAcceptedAt",
    "at",
)
"""Every field a legal acceptance record may hold, and nothing else."""


def legal_acceptance_doc_id(
    terms_version: Optional[int] = None, privacy_version: Optional[int] = None
) -> str:
    terms = config.TERMS_VERSION if terms_version is None else terms_version
    privacy = config.PRIVACY_VERSION if privacy_version is None else privacy_version
    return f"legal-t{terms}-p{privacy}"


def _legal_ref(uid: str):
    return (
        db()
        .collection(config.COL_USERS)
        .document(uid)
        .collection(config.COL_CONSENTS)
        .document(legal_acceptance_doc_id())
    )


PLEDGE_FIELDS = ("version", "at", "locale", "appVersion")
"""Every field a pledge record may hold, and nothing else."""


def pledge_doc_id(version: Optional[int] = None) -> str:
    return f"pledge-v{config.PLEDGE_VERSION if version is None else version}"


def write_pledge(
    uid: str, locale: Optional[str] = None, app_version: Optional[str] = None
) -> bool:
    """C16: she agreed to the community's rules. Written once per version; an
    agreement already on file is left as it was. Returns True when written."""
    ref = (
        db()
        .collection(config.COL_USERS)
        .document(uid)
        .collection(config.COL_CONSENTS)
        .document(pledge_doc_id())
    )
    if ref.get().exists:
        return False
    payload = {"version": config.PLEDGE_VERSION, "at": firestore.SERVER_TIMESTAMP}
    payload.update(consent_extras(locale, app_version))
    assert set(payload) <= set(PLEDGE_FIELDS)
    ref.set(payload)
    return True


def has_legal_acceptance(uid: str) -> bool:
    """Whether she has accepted the current Terms and Privacy Policy."""
    return _legal_ref(uid).get().exists


def legal_acceptance_payload(
    locale: str, app_version: str, platform: str, client_accepted_at
) -> dict:
    """M1: users/{uid}/consents/legal-t{T}-p{P}. Allow-listed fields only.

    `clientAcceptedAt` is when her phone says she tapped (milliseconds since
    the epoch, possibly some time before the code arrived); `at` is when the
    server recorded it. Both are kept because they answer different
    questions."""
    payload = {
        "termsVersion": config.TERMS_VERSION,
        "privacyVersion": config.PRIVACY_VERSION,
        "locale": locale,
        "appVersion": app_version,
        "platform": platform,
        "clientAcceptedAt": client_accepted_at,
        "at": firestore.SERVER_TIMESTAMP,
    }
    extra = set(payload) - set(LEGAL_ACCEPTANCE_FIELDS)
    if extra:
        raise ValueError(f"not permitted in a legal acceptance: {sorted(extra)}")
    return payload


def write_legal_acceptance(
    uid: str, locale: str, app_version: str, platform: str, client_accepted_at
) -> None:
    """Server-only, like every consent record. Lives under users/{uid}, so
    account deletion's recursive delete removes it (manifest row 10)."""
    _legal_ref(uid).set(
        legal_acceptance_payload(locale, app_version, platform, client_accepted_at)
    )


def _review_consent_ref(uid: str):
    return (
        db()
        .collection(config.COL_USERS)
        .document(uid)
        .collection(config.COL_CONSENTS)
        .document(f"review-v{config.REVIEW_CONSENT_VERSION}")
    )


def write_review_consent(uid: str, path: str, flag_id: str) -> None:
    """N7: users/{uid}/consents/review-v2 = {version, at, path, flagId}.
    Server-only.

    Recorded by request_review against the open flag, or the one it just
    opened: asking for the call is the consent to be phoned and reviewed live
    by a woman reviewer. The wording the app shows before calling is PENDING
    COUNSEL. N3: `flagId` binds it to that flag only, and close_flag and
    expire_flag delete it, so it never carries over to a later automatic
    flag. A full set, so a later request records the path she chose last.
    Lives under users/{uid}, so account deletion's recursive delete removes it
    (manifest row 10)."""
    _review_consent_ref(uid).set(
        {
            "version": config.REVIEW_CONSENT_VERSION,
            "at": firestore.SERVER_TIMESTAMP,
            "path": path,
            "flagId": flag_id,
        }
    )


def review_consented_flags(pairs) -> set:
    """R4 and N3: of the (uid, flag_id) pairs, the flag ids whose subject's
    users/{uid}/consents/review-v{N} names that flag. One batched read;
    get_all does not promise to answer in request order, so results are
    matched back by path."""
    wanted: dict = {}
    refs = {}
    for uid, flag_id in pairs:
        if uid and flag_id:
            ref = _review_consent_ref(uid)
            refs[ref.path] = ref
            wanted.setdefault(ref.path, set()).add(flag_id)
    if not refs:
        return set()
    out = set()
    for snap in db().get_all(list(refs.values())):
        if not snap.exists or snap.reference.path not in wanted:
            continue
        flag_id = (snap.to_dict() or {}).get("flagId")
        if flag_id in wanted[snap.reference.path]:
            out.add(flag_id)
    return out


HEALTH_COLLECTIONS = ("checkins", "measurements", "cycle", "periods")
HEALTH_PROFILE_KEYS = ("lifeStage", "allergies")


def write_health_consent(uid: str, granted: bool) -> None:
    """S17: users/{uid}/consents/health-v1. Server-written only.

    Granted is a full set (a fresh grant after a withdrawal starts clean).
    Withdrawn is a merge that keeps when it was first given."""
    reference = (
        db()
        .collection(config.COL_USERS)
        .document(uid)
        .collection(config.COL_CONSENTS)
        .document(f"health-v{config.HEALTH_CONSENT_VERSION}")
    )
    if granted:
        reference.set(
            {
                "version": config.HEALTH_CONSENT_VERSION,
                "state": "granted",
                "at": firestore.SERVER_TIMESTAMP,
                "withdrawnAt": None,
            }
        )
    else:
        reference.set(
            {
                "version": config.HEALTH_CONSENT_VERSION,
                "state": "withdrawn",
                "withdrawnAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )


def purge_health_data(uid: str) -> None:
    """She withdrew: delete the cloud copy of her health data. The copy on her
    phone stays, because it is the source of truth (Protected List 11)."""
    user = db().collection(config.COL_USERS).document(uid)
    for name in HEALTH_COLLECTIONS:
        db().recursive_delete(user.collection(name))
    user.set(
        {"profile": {key: firestore.DELETE_FIELD for key in HEALTH_PROFILE_KEYS}},
        merge=True,
    )


MEAL_PHOTO_CONSENT_FIELDS = ("version", "at", "locale", "appVersion")
"""Every field a meal-photo consent record may hold, and nothing else."""


def _meal_photo_consent_ref(uid: str):
    return (
        db()
        .collection(config.COL_USERS)
        .document(uid)
        .collection(config.COL_CONSENTS)
        .document(f"meal-photo-v{config.MEAL_PHOTO_CONSENT_VERSION}")
    )


def has_meal_photo_consent(uid: str) -> bool:
    return _meal_photo_consent_ref(uid).get().exists


def write_meal_photo_consent(
    uid: str, locale: Optional[str] = None, app_version: Optional[str] = None
) -> bool:
    """E12: users/{uid}/consents/meal-photo-v1 = {version, at, locale?,
    appVersion?}. Server-written only, once per version; a record already on
    file is left as it was. Returns True when written. Lives under users/{uid},
    so account deletion's recursive delete removes it."""
    ref = _meal_photo_consent_ref(uid)
    if ref.get().exists:
        return False
    payload = {
        "version": config.MEAL_PHOTO_CONSENT_VERSION,
        "at": firestore.SERVER_TIMESTAMP,
    }
    payload.update(consent_extras(locale, app_version))
    assert set(payload) <= set(MEAL_PHOTO_CONSENT_FIELDS)
    ref.set(payload)
    return True


def has_consent(uid: str) -> bool:
    snapshot = (
        db()
        .collection(config.COL_USERS)
        .document(uid)
        .collection(config.COL_CONSENTS)
        .document(f"verification-v{config.CONSENT_VERSION}")
        .get()
    )
    return snapshot.exists


UNKNOWN_GOVERNORATE_DOC = "governorate-unknown"
"""One document, one counter per unseen code, no uid anywhere in it.

An unknown governorate code stopped being a FLAG (decisions._score_stage), on
the grounds that it is evidence about nid.GOVERNORATES rather than about the
woman holding the card. That argument only holds if somebody can actually fix
the table, and nothing else in the system remembers WHICH code was unknown: the
job document records the reason code, never the two digits, because a
governorate is her place of birth and spec §4 does not allow it beside her uid.

So the code is counted here and nowhere else. The document looks like
`{"45": 41, "37": 2}`. That is enough to say "go and check code 45" and is not
enough to say anything at all about any of those 41 women — there is no uid, no
timestamp per event, and no way back from a count to a person."""


def record_unknown_governorate(code: str) -> None:
    """Add one to the counter for a governorate code we do not have.

    Best effort, and silent on failure by design: this is an observation for us,
    and a Firestore hiccup here must never turn a woman's completed
    verification into an error she sees. The decision has already been made and
    returned by the time this is called.
    """
    if not code:
        return
    try:
        db().collection(config.COL_STATS).document(UNKNOWN_GOVERNORATE_DOC).set(
            {code: firestore.Increment(1)}, merge=True
        )
    except Exception:
        pass


def daily_count_and_increment(field: str = "sessions") -> int:
    """Spec §6's global kill switch counter, sharded (S6).

    TWO FIELDS, and the second one is the one that matters. `sessions` counts
    start_verification, which is free. `verifications` counts verify_identity,
    the only callable that spends money; a caller who never starts a session
    still reaches Cloud Vision, so the kill switch must count that door.

    One document per UTC day used to hold both counters in a read-modify-write
    transaction. Every verification in the country contended on it. Now each
    call adds one to a random shard, verificationStats/{day}_s{0..N-1}, with a
    server-side Increment (no transaction, no contention), then reads all the
    shards and returns the sum including this call. Per-uid caps are checked
    before this, so one account cannot run it up.
    """
    from google.cloud import firestore as _fs

    today = _today()
    stats = db().collection(config.COL_STATS)
    shard = random.randrange(config.DAILY_COUNTER_SHARDS)
    stats.document(f"{today}_s{shard}").set({field: _fs.Increment(1)}, merge=True)
    refs = [
        stats.document(f"{today}_s{i}") for i in range(config.DAILY_COUNTER_SHARDS)
    ]
    total = 0
    for snapshot in db().get_all(refs):
        if snapshot.exists:
            total += int((snapshot.to_dict() or {}).get(field, 0))
    return total


DAILY_VERIFY_FIELD = "verifications"
"""The counter verify_identity increments. See daily_count_and_increment."""


# ------------------------------------------------------------ review loop


def _today() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")


def uid_daily_count_and_increment(uid: str, field: str) -> int:
    """One account's count of `field` today, after adding this call.

    On verificationLedger/{uid}.daily = {day, starts, verifies, reviews,
    mealScans}, reset when the UTC day changes. Transactional, and nothing else
    on the ledger document is touched.

    merge=["daily"], NOT merge=True. Firestore's merge=True on a nested map is
    a leaf merge (update mask daily.day, daily.starts), so yesterday's
    daily.verifies and daily.reviews would survive the day change and the
    per-uid daily cap would become a lifetime cap. Naming the field replaces
    the whole map. tests/test_store_merge_semantics.py pins this."""
    reference = db().collection(config.COL_LEDGER).document(uid)
    today = _today()

    @firestore.transactional
    def txn(transaction):
        snapshot = reference.get(transaction=transaction)
        data = snapshot.to_dict() if snapshot.exists else {}
        daily = dict((data or {}).get("daily") or {})
        if daily.get("day") != today:
            daily = {"day": today}
        count = int(daily.get(field, 0)) + 1
        daily[field] = count
        transaction.set(reference, {"daily": daily}, merge=["daily"])
        return count

    return txn(db().transaction())


def uid_daily_refund(uid: str, field: str) -> None:
    """Give back one count of `field` today, after a call our side failed.

    The pair of uid_daily_count_and_increment, for a provider outage that must
    not cost her an attempt (the rule LIVENESS_PROVIDER_ERROR states). Only
    today's count moves, never below zero; a day that has already rolled over
    is left alone. Same merge=["daily"] as the increment."""
    reference = db().collection(config.COL_LEDGER).document(uid)
    today = _today()

    @firestore.transactional
    def txn(transaction):
        snapshot = reference.get(transaction=transaction)
        data = snapshot.to_dict() if snapshot.exists else {}
        daily = dict((data or {}).get("daily") or {})
        if daily.get("day") != today or int(daily.get(field, 0)) <= 0:
            return
        daily[field] = int(daily[field]) - 1
        transaction.set(reference, {"daily": daily}, merge=["daily"])

    txn(db().transaction())


@dataclass(frozen=True)
class Gate:
    """What verify_identity and start_verification must know before any work."""

    state: Optional[str] = None
    open_flag_id: Optional[str] = None
    duplicate_flag_raised: bool = False


def _pending_flag(flag_id: Optional[str], transaction=None) -> bool:
    if not flag_id:
        return False
    snapshot = (
        db().collection(config.COL_FLAGS).document(flag_id).get(transaction=transaction)
    )
    return bool(
        snapshot.exists
        and (snapshot.to_dict() or {}).get("state") == decisions.PENDING_REVIEW
    )


def verification_gate(uid: str) -> Gate:
    ledger_snapshot = db().collection(config.COL_LEDGER).document(uid).get()
    data = (ledger_snapshot.to_dict() or {}) if ledger_snapshot.exists else {}
    open_id = data.get("openFlagId")
    return Gate(
        state=verification_state(uid),
        open_flag_id=open_id if _pending_flag(open_id) else None,
        duplicate_flag_raised=bool(data.get("duplicateFlagRaised")),
    )


def open_flag(
    uid: str,
    job: Optional[dict],
    flag: dict,
    *,
    job_id: Optional[str] = None,
    mark_duplicate: bool = False,
) -> tuple[str, bool]:
    """One open flag per uid (S7), in one transaction on the ledger document.

    If `openFlagId` already points at a PENDING_REVIEW flag, returns it and
    writes nothing. Otherwise writes the job (when given) and the flag under one
    id, and records it as her open flag."""
    ledger_ref = db().collection(config.COL_LEDGER).document(uid)
    jobs = db().collection(config.COL_VERIFICATION_JOBS)
    job_ref = jobs.document(job_id) if job_id else jobs.document()
    flag_ref = db().collection(config.COL_FLAGS).document(job_ref.id)

    @firestore.transactional
    def txn(transaction):
        snapshot = ledger_ref.get(transaction=transaction)
        data = (snapshot.to_dict() or {}) if snapshot.exists else {}
        current = data.get("openFlagId")
        if current and _pending_flag(current, transaction):
            return current, False
        if job is not None:
            transaction.set(job_ref, job)
        payload = dict(flag)
        payload["jobId"] = job_ref.id
        payload["createdAt"] = firestore.SERVER_TIMESTAMP
        transaction.set(flag_ref, payload)
        update = {"openFlagId": job_ref.id, "updatedAt": firestore.SERVER_TIMESTAMP}
        if mark_duplicate:
            update["duplicateFlagRaised"] = True
        transaction.set(ledger_ref, update, merge=True)
        return job_ref.id, True

    return txn(db().transaction())


class FirestoreReviewStore:
    """review.ReviewStore over Firestore and Firebase Auth."""

    def verification_state(self, uid):
        return verification_state(uid)

    def set_verification_state(self, uid, state, **kwargs):
        set_verification_state(uid, state, **kwargs)

    def verify_in_flight(self, uid):
        return verify_in_flight(uid)

    def uid_daily_count_and_increment(self, uid, field):
        return uid_daily_count_and_increment(uid, field)

    def write_review_consent(self, uid, path, flag_id):
        write_review_consent(uid, path, flag_id)

    def review_consented_flags(self, pairs):
        return review_consented_flags(pairs)

    def open_flag_id(self, uid):
        return verification_gate(uid).open_flag_id

    def ocr_submissions(self, uid):
        return FirestoreLedger().read(uid).ocr_submissions

    def new_job_payload(self, uid, decision, attempt):
        return job_payload(uid, decision, attempt)

    def open_flag(self, uid, job_payload, flag_payload, **kwargs):
        return open_flag(uid, job_payload, flag_payload, **kwargs)

    def get_flag(self, flag_id):
        snapshot = db().collection(config.COL_FLAGS).document(flag_id).get()
        return (snapshot.to_dict() or {}) if snapshot.exists else None

    def list_open(self, limit):
        query = (
            db()
            .collection(config.COL_FLAGS)
            .where("state", "==", decisions.PENDING_REVIEW)
            .order_by("createdAt")
            .limit(limit)
        )
        return [(s.id, s.to_dict() or {}) for s in query.stream()]

    def mark_scheduled(self, flag_id, route, when, reviewer_uid, sla_expires_at):
        """R5: re-read the flag, refuse unless PENDING_REVIEW, then book it and
        write her state `pending` with the booking, in ONE transaction. A
        reject or expiry that committed first is never overwritten. Returns
        None on commit, else REVIEW_NOT_PENDING with nothing written."""
        flag_ref = db().collection(config.COL_FLAGS).document(flag_id)

        @firestore.transactional
        def txn(transaction):
            flag = flag_ref.get(transaction=transaction)
            data = (flag.to_dict() or {}) if flag.exists else {}
            if data.get("state") != decisions.PENDING_REVIEW or not data.get("uid"):
                return reasons.REVIEW_NOT_PENDING
            transaction.update(
                flag_ref,
                {
                    "route": route,
                    "scheduledFor": when,
                    "slaExpiresAt": sla_expires_at,
                    "reviewerUid": reviewer_uid,
                    "scheduledAt": firestore.SERVER_TIMESTAMP,
                    "reasons": firestore.ArrayUnion([reasons.REVIEW_SCHEDULED]),
                },
            )
            transaction.set(
                db().collection(config.COL_USERS).document(data["uid"]),
                _verification_update("pending", route=route, scheduled_for=when),
                merge=True,
            )
            return None

        return txn(db().transaction())

    def close_flag(
        self,
        flag_id,
        *,
        uid,
        state,
        reviewer_uid,
        reviewer_reason,
        id_hmac=None,
        user_state=None,
    ):
        """N10: re-read, check PENDING_REVIEW, claim the registry (approval)
        and close flag, job and openFlagId in ONE transaction. R5: with
        `user_state` (a rejection) her verification state is written in the
        same transaction, so a rejection is always enforced. Returns None on
        commit, or the refusal reason code with nothing written."""
        flag_ref = db().collection(config.COL_FLAGS).document(flag_id)
        job_ref = db().collection(config.COL_VERIFICATION_JOBS).document(flag_id)
        ledger_ref = db().collection(config.COL_LEDGER).document(uid)
        registry_ref = (
            db().collection(config.COL_NID_REGISTRY).document(id_hmac) if id_hmac else None
        )

        @firestore.transactional
        def txn(transaction):
            flag = flag_ref.get(transaction=transaction)
            if not flag.exists or (flag.to_dict() or {}).get("state") != decisions.PENDING_REVIEW:
                return reasons.REVIEW_NOT_PENDING
            job = job_ref.get(transaction=transaction)
            ledger_snapshot = ledger_ref.get(transaction=transaction)
            claim_payload = None
            if registry_ref is not None:
                entry_snapshot = registry_ref.get(transaction=transaction)
                existing = None
                if entry_snapshot.exists:
                    data = entry_snapshot.to_dict() or {}
                    existing = dedupe.RegistryEntry(
                        uid=data.get("uid"),
                        state=data.get("state", dedupe.STATE_ACTIVE),
                        pepper_version=int(data.get("pepper_version", 0)),
                    )
                verdict = dedupe.judge(existing, uid)
                if not verdict.ok:
                    return verdict.reason or reasons.DUPLICATE_ID
                if not verdict.is_reverification:
                    claim_payload = dedupe.registry_document(uid)
                    claim_payload["createdAt"] = firestore.SERVER_TIMESTAMP
            # Writes only after every read.
            if claim_payload is not None:
                transaction.set(registry_ref, claim_payload)
            transaction.update(
                flag_ref,
                {
                    "state": state,
                    "decidedBy": reviewer_uid,
                    "decidedAt": firestore.SERVER_TIMESTAMP,
                    "reviewerReason": reviewer_reason,
                    "expireAt": decided_expiry(),
                },
            )
            if job.exists:
                transaction.update(
                    job_ref,
                    {"state": state, "decidedBy": "reviewer", "expireAt": decided_expiry()},
                )
            if (
                ledger_snapshot.exists
                and (ledger_snapshot.to_dict() or {}).get("openFlagId") == flag_id
            ):
                transaction.set(ledger_ref, {"openFlagId": None}, merge=True)
            # N3: her consent covered this flag only.
            transaction.delete(_review_consent_ref(uid))
            if user_state is not None:
                transaction.set(
                    db().collection(config.COL_USERS).document(uid),
                    _verification_update(user_state, decided=True),
                    merge=True,
                )
            return None

        return txn(db().transaction())

    def stale_flags(self, now, limit):
        query = (
            db()
            .collection(config.COL_FLAGS)
            .where("state", "==", decisions.PENDING_REVIEW)
            .where("slaExpiresAt", "<", now)
            .limit(limit)
        )
        return [(s.id, s.to_dict() or {}) for s in query.stream()]

    def expire_flag(self, flag_id, uid, now):
        """N10: expire only if still PENDING_REVIEW and still past its SLA at
        `now`, re-checked inside one transaction with the job, openFlagId and
        (R5) her `retry` state writes. A booking moves slaExpiresAt (N6), so a flag booked after the
        sweep's query is left alone."""
        flag_ref = db().collection(config.COL_FLAGS).document(flag_id)
        job_ref = db().collection(config.COL_VERIFICATION_JOBS).document(flag_id)
        ledger_ref = db().collection(config.COL_LEDGER).document(uid) if uid else None

        @firestore.transactional
        def txn(transaction):
            flag = flag_ref.get(transaction=transaction)
            data = (flag.to_dict() or {}) if flag.exists else {}
            sla = data.get("slaExpiresAt")
            if data.get("state") != decisions.PENDING_REVIEW or sla is None or not sla < now:
                return False
            job = job_ref.get(transaction=transaction)
            ledger_snapshot = (
                ledger_ref.get(transaction=transaction) if ledger_ref is not None else None
            )
            transaction.update(
                flag_ref,
                {
                    "state": decisions.RETRY_REQUIRED,
                    "reasons": firestore.ArrayUnion([reasons.REVIEW_SLA_EXPIRED]),
                    "expiredAt": firestore.SERVER_TIMESTAMP,
                    "expireAt": decided_expiry(),
                },
            )
            if job.exists:
                transaction.update(
                    job_ref, {"state": decisions.RETRY_REQUIRED, "expireAt": decided_expiry()}
                )
            if (
                ledger_snapshot is not None
                and ledger_snapshot.exists
                and (ledger_snapshot.to_dict() or {}).get("openFlagId") == flag_id
            ):
                transaction.set(ledger_ref, {"openFlagId": None}, merge=True)
            if uid:
                # N3: her consent covered this flag only.
                transaction.delete(_review_consent_ref(uid))
                # R5: her state moves to retry with the flag, booking cleared
                # (N6), in the same transaction.
                transaction.set(
                    db().collection(config.COL_USERS).document(uid),
                    _verification_update("retry", reset_booking=True),
                    merge=True,
                )
            return True

        return txn(db().transaction())

    def grant_bonus(self, uid, flag_id):
        reference = db().collection(config.COL_LEDGER).document(uid)

        @firestore.transactional
        def txn(transaction):
            snapshot = reference.get(transaction=transaction)
            data = (snapshot.to_dict() or {}) if snapshot.exists else {}
            budget = ledger.Budget(
                spent_micro_usd=int(data.get("spent_micro_usd", 0)),
                bonus_ocr_submissions=int(data.get("bonusOcrSubmissions", 0)),
            )
            granted = tuple(data.get("bonusGrantedFor", []) or ())
            if not ledger.may_grant_bonus(budget, flag_id, granted):
                return False
            transaction.set(
                reference,
                {
                    "bonusOcrSubmissions": budget.bonus_ocr_submissions + 1,
                    "bonusGrantedFor": list(granted + (flag_id,))[-20:],
                },
                merge=True,
            )
            return True

        return txn(db().transaction())

    def mark_mint_pending(self, flag_id):
        db().collection(config.COL_FLAGS).document(flag_id).update({"mintPending": True})

    def clear_mint_pending(self, flag_id):
        db().collection(config.COL_FLAGS).document(flag_id).update(
            {"mintPending": firestore.DELETE_FIELD}
        )

    def clear_mint_pending_for(self, uid):
        query = (
            db().collection(config.COL_FLAGS)
            .where("uid", "==", uid)
            .where("mintPending", "==", True)
        )
        for snapshot in query.stream():
            snapshot.reference.update({"mintPending": firestore.DELETE_FIELD})

    def mint_pending_flags(self, limit):
        """Single-field equality on mintPending (auto-indexed). APPROVED is
        checked here so a stray mark on any other flag mints nothing."""
        query = (
            db().collection(config.COL_FLAGS).where("mintPending", "==", True).limit(limit)
        )
        out = []
        for snapshot in query.stream():
            data = snapshot.to_dict() or {}
            if data.get("state") == decisions.APPROVED:
                out.append((snapshot.id, data.get("uid")))
        return out

    def claim(self, id_hmac, uid):
        return FirestoreRegistry().claim(id_hmac, uid)

    def mint_verified(self, uid):
        mint_claims(uid, True)

    def phone_for(self, uid):
        from firebase_admin import auth

        return auth.get_user(uid).phone_number

    def log_access(self, reviewer_uid, flag_id, action):
        db().collection(config.COL_REVIEW_ACCESS).add(
            {
                "flagId": flag_id,
                "reviewerUid": reviewer_uid,
                "action": action,
                "at": firestore.SERVER_TIMESTAMP,
                "expireAt": access_log_expiry(),
            }
        )

    def pepper(self):
        return pepper()

    def notify(self, flag_id, codes):
        from . import webhook

        webhook.post_flag(flag_id, codes)

    def notify_approved(self, uid):
        from firebase_admin import messaging

        from . import push

        push.send_approved(uid, db(), messaging)
