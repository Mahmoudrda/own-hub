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
                {"hmacs": seen[-10:], "updatedAt": firestore.SERVER_TIMESTAMP},
            )

        txn(db().transaction())

    def record_failure(self, id_hmac: str) -> None:
        db().collection("verificationBehaviour").document(id_hmac).set(
            {"failures": firestore.Increment(1), "updatedAt": firestore.SERVER_TIMESTAMP},
            merge=True,
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
) -> None:
    """S8: the one server-written place she can read where her check stands.

    A merge of `verification.*` keys only. No reason codes and no flag id: the
    map is hers to read (rules: isSelf) and must not teach anyone which check
    failed. The client can never write it (rules: verificationUntouched)."""
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
    db().collection(config.COL_USERS).document(uid).set(
        {"verification": fields}, merge=True
    )


def verification_state(uid: str) -> Optional[str]:
    snapshot = db().collection(config.COL_USERS).document(uid).get()
    if not snapshot.exists:
        return None
    verification = (snapshot.to_dict() or {}).get("verification") or {}
    state = verification.get("state") if isinstance(verification, dict) else None
    return state if state in VERIFICATION_STATES else None


def write_consent(uid: str) -> None:
    """Spec §2 step 1 / §4 row 3: uid, consent version, timestamp. Nothing else.

    Not the text she agreed to, not her IP, not her device. The version is the
    only thing tying the record to what she was shown, which is why
    config.CONSENT_VERSION must be bumped whenever that text changes.
    """
    db().collection(config.COL_USERS).document(uid).collection(
        config.COL_CONSENTS
    ).document(f"verification-v{config.CONSENT_VERSION}").set(
        {
            "version": config.CONSENT_VERSION,
            "at": firestore.SERVER_TIMESTAMP,
        }
    )


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
    """Spec §6's global kill switch counter.

    One document per UTC day. A distributed counter would be the textbook answer
    at high write rates, and at 278 verifications a day it would be premature:
    Firestore's per-document write limit is around one per second sustained, and
    278/day is 0.003/second.

    TWO FIELDS ON THE SAME DOCUMENT, and the second one is the one that matters.

    `sessions` counts start_verification, which mints a challenge and costs
    nothing. `verifications` counts verify_identity, which is the only callable
    in this system that spends money — two Cloud Vision units per submission.

    Counting only `sessions` put the kill switch on the free door. Nothing in
    verify_identity's path requires a session to have been minted: OCR is step 3
    and the liveness session is not consulted until step 6, so a caller who
    never touches start_verification reaches both paid Vision calls with the
    global limit never once consulted. Per-uid caps still bound one account, but
    the blast-radius limit spec §6 asks for is a GLOBAL one, and a global limit
    that only counts the free call cannot bound a bill.
    """
    today = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
    reference = db().collection(config.COL_STATS).document(today)

    @firestore.transactional
    def txn(transaction):
        snapshot = reference.get(transaction=transaction)
        count = int((snapshot.to_dict() or {}).get(field, 0)) if snapshot.exists else 0
        transaction.set(reference, {field: count + 1}, merge=True)
        return count + 1

    return txn(db().transaction())


DAILY_VERIFY_FIELD = "verifications"
"""The counter verify_identity increments. See daily_count_and_increment."""


# ------------------------------------------------------------ review loop


def _today() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")


def uid_daily_count_and_increment(uid: str, field: str) -> int:
    """One account's count of `field` today, after adding this call.

    On verificationLedger/{uid}.daily = {day, starts, verifies, reviews}, reset
    when the UTC day changes. Transactional and merge-only, so nothing else on
    the ledger document is touched."""
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
        transaction.set(reference, {"daily": daily}, merge=True)
        return count

    return txn(db().transaction())


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


def _clear_open_flag(uid: str, flag_id: str) -> None:
    reference = db().collection(config.COL_LEDGER).document(uid)

    @firestore.transactional
    def txn(transaction):
        snapshot = reference.get(transaction=transaction)
        if snapshot.exists and (snapshot.to_dict() or {}).get("openFlagId") == flag_id:
            transaction.set(reference, {"openFlagId": None}, merge=True)

    txn(db().transaction())


class FirestoreReviewStore:
    """review.ReviewStore over Firestore and Firebase Auth."""

    def verification_state(self, uid):
        return verification_state(uid)

    def set_verification_state(self, uid, state, **kwargs):
        set_verification_state(uid, state, **kwargs)

    def uid_daily_count_and_increment(self, uid, field):
        return uid_daily_count_and_increment(uid, field)

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

    def mark_scheduled(self, flag_id, route, when, reviewer_uid):
        db().collection(config.COL_FLAGS).document(flag_id).update(
            {
                "route": route,
                "scheduledFor": when,
                "reviewerUid": reviewer_uid,
                "scheduledAt": firestore.SERVER_TIMESTAMP,
                "reasons": firestore.ArrayUnion([reasons.REVIEW_SCHEDULED]),
            }
        )

    def close_flag(self, flag_id, *, uid, state, reviewer_uid, reviewer_reason):
        db().collection(config.COL_FLAGS).document(flag_id).update(
            {
                "state": state,
                "decidedBy": reviewer_uid,
                "decidedAt": firestore.SERVER_TIMESTAMP,
                "reviewerReason": reviewer_reason,
                "expireAt": decided_expiry(),
            }
        )
        job = db().collection(config.COL_VERIFICATION_JOBS).document(flag_id)
        if job.get().exists:
            job.update(
                {"state": state, "decidedBy": "reviewer", "expireAt": decided_expiry()}
            )
        _clear_open_flag(uid, flag_id)

    def stale_flags(self, now, limit):
        query = (
            db()
            .collection(config.COL_FLAGS)
            .where("state", "==", decisions.PENDING_REVIEW)
            .where("slaExpiresAt", "<", now)
            .limit(limit)
        )
        return [(s.id, s.to_dict() or {}) for s in query.stream()]

    def expire_flag(self, flag_id, uid):
        db().collection(config.COL_FLAGS).document(flag_id).update(
            {
                "state": decisions.RETRY_REQUIRED,
                "reasons": firestore.ArrayUnion([reasons.REVIEW_SLA_EXPIRED]),
                "expiredAt": firestore.SERVER_TIMESTAMP,
                "expireAt": decided_expiry(),
            }
        )
        job = db().collection(config.COL_VERIFICATION_JOBS).document(flag_id)
        if job.get().exists:
            job.update({"state": decisions.RETRY_REQUIRED, "expireAt": decided_expiry()})
        if uid:
            _clear_open_flag(uid, flag_id)

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
            }
        )

    def pepper(self):
        return pepper()

    def notify(self, flag_id, codes):
        from . import webhook

        webhook.post_flag(flag_id, codes)
