"""The complete vocabulary of things that can be said about a verification.

A closed list, and the only thing a reviewer, a support agent or a log line ever
sees about a woman's attempt.

The rule the whole design hangs on: a reason code is a fact about the CHECK, not
a description of HER. "the sex field could not be read" is a fact about an OCR
pass. "photo looks like a man" is a description of a woman, and there is no code
for it because there must be no way to write one. Free text would let a reviewer
type it anyway, which is why `verification_flags` has no notes field and why
this module exists instead of a `notes` string. Spec §4: no PII in flags.

Codes are stable wire values. Renaming one orphans every job document already
written, so add rather than rename.

Spec §3 also forbids showing any of this to the woman herself: user-facing
copy is coarse and neutral ("Verified", "Under review", "Verification
unsuccessful", "Please retake the photo"), because a message that says which
check failed teaches bypass. `to_user_safe` at the bottom of this file is the
ONLY way a code is allowed to reach a client, and it is many-to-few so the
mapping cannot be inverted.
"""

from __future__ import annotations

from . import nid as _nid

# ------------------------------------------- the number (mirrors nid.py)
# nid.py is dependency-free by spec §8, so it declares its own literals. These
# aliases are the single source of truth for everyone else, and
# tests/test_reasons_sync.py asserts the two cannot drift apart.

NID_UNREADABLE = _nid.UNREADABLE
NID_BAD_LENGTH = _nid.BAD_LENGTH
NID_BAD_CENTURY = _nid.BAD_CENTURY
NID_BAD_DATE = _nid.BAD_DATE
NID_FUTURE_DATE = _nid.FUTURE_DATE

NID_SIDES_DISAGREE = "nid_sides_disagree"
"""The number read off the front and the number read off the back are not the
same. Spec §2 step 3: if the number appears on both sides, both reads must
agree. A disagreement is an OCR failure, so it is RETRY_CAPTURE."""

NID_GOVERNORATE_UNKNOWN = "nid_governorate_unknown"
"""RECORDED, never a flag and never a rejection.

Spec §3 listed this as a FLAG signal and gave its own reason for doubting it in
the same sentence: the published list may be incomplete. That makes an unknown
code evidence about nid.GOVERNORATES, not about the woman holding the card, and
a woman reviewer on a video call has nothing to examine — the card photograph is
gone by the time the call happens. It is also not rare: only 28 of the 100
two-digit codes were ever issued, so most single-digit OCR misreads in that
position land on one we do not have.

So it stays on the job document, main.py counts the code itself into an
aggregate with no uid attached, and it opens no review. See
decisions._score_stage for the full argument and what an attacker gains."""

UNDERAGE = "underage"
AGE_IMPLAUSIBLE = "age_implausible"
BIRTH_DATE_MISMATCH = "birth_date_mismatch"
"""The date printed on the card disagrees with the date encoded in the number.

A BAD READ first, a flag only once the OCR retries are exhausted. Nothing hangs
on the printed date — age comes from digits 2-7, which have already been parsed
as a real calendar date and checked against MIN_AGE — so a disagreement is one
error-prone OCR pass over small print on a laminate, compared against a half
that was validated structurally. A disagreement that survives four separate
photographs has stopped being a slip, and that is the one a human should see.
See decisions._early."""

# ------------------------------------------------------------- the sex gate

SEX_DIGIT_MALE = "sex_digit_male"
"""Digit 13 is odd. Spec §2 step 4: reject immediately, make no further paid
calls. This is the gate that keeps a male applicant's cost at about $0.003."""

SEX_WORD_UNREADABLE = "sex_word_unreadable"
"""The printed النوع word could not be read. A FLAG per spec §3, not a
rejection — but only AFTER the OCR retries are gone, and now whichever way
digit 13 reads.

Glare on the laminate, a shadow, a scratch across a field set in small Arabic
type. A retake is free and a woman reviewer is not, and the male-digit branch
gains the most: a retake that reads ذكر turns a review into a clean rejection,
and one that reads أنثى raises SEX_CONFLICT, which is a real flag. See
decisions._early."""

SEX_CONFLICT = "sex_conflict"
"""Digit 13 and the printed word disagree. A FLAG per spec §3. Never
auto-decided in either direction: a single mis-OCR'd Arabic-Indic glyph flips
digit 13, and a woman turned away by one glyph is the worst outcome this system
can produce."""

# ---------------------------------------------------------------- liveness

LIVENESS_PASS = "liveness_pass"
LIVENESS_FLAG_BAND = "liveness_flag_band"
LIVENESS_FAILED = "liveness_failed"
LIVENESS_PROVIDER_ERROR = "liveness_provider_error"
"""The provider did not return a usable answer: a timeout, a 5xx, a session in a
status other than SUCCEEDED. Spec §9.4 requires that this gives the user a retry
and records NO charge, because charging a woman's budget for our vendor's outage
would eventually lock her out of the product through no fault of her own."""

SESSION_MISSING = "session_missing"
SESSION_EXPIRED = "session_expired"
SESSION_ALREADY_USED = "session_already_used"
SESSION_WRONG_ACCOUNT = "session_wrong_account"
"""Spec §5: a liveness sessionId is single-use and uid-bound. Replaying a
successful session from another uid must fail."""

# ------------------------------------------------------------- face match

MATCH_PASS = "match_pass"
MATCH_FLAG_BAND = "match_flag_band"
MATCH_FAILED = "match_failed"
FACE_NOT_FOUND_ON_CARD = "face_not_found_on_card"
"""Spec §2 step 7: if no face is detected on the card, RETRY_CAPTURE. Glare, a
thumb over the portrait, the back of the card photographed twice. A bad scan is
not a bad person."""

FACE_TOO_SMALL_ON_CARD = "face_too_small_on_card"
FACE_NOT_FOUND_IN_REFERENCE = "face_not_found_in_reference"
FACE_FRAMES_DISAGREE = "face_frames_disagree"
"""Not all selfie frames are the same person. The classic swap: the card's
printed photo for frame one, a real face for the rest."""

MATCH_PROVIDER_ERROR = "match_provider_error"

# --------------------------------------------------------------- behaviour
# Spec §3's two cross-account FLAG signals.

HMAC_MANY_FAILURES = "hmac_many_failures"
"""The same id_hmac has failed liveness or match more than twice, across ANY
accounts. Across accounts is the operative part: this is what catches someone
working through one stolen card on a series of fresh sign-ups."""

INSTALL_MANY_IDS = "install_many_ids"
"""The same app install has attempted more than two different id_hmac values.
One household phone verifying a mother and two daughters is a real Egyptian
scenario and stays under the limit; a card-testing rig does not."""

# ------------------------------------------------------------ the gates

DUPLICATE_ID = "duplicate_id"
REGISTRATION_CLOSED = "registration_closed"
"""The registry entry is tombstoned because the account holding it was deleted.
The app's own deletion manifest closes these rather than removing them
(`state:'closed'`, `uid:null`) so a removed woman cannot re-register while no
personal data stays linked."""

COST_CAP_REACHED = "cost_cap_reached"
ATTEMPT_LIMIT_OCR = "attempt_limit_ocr"
ATTEMPT_LIMIT_LIVENESS = "attempt_limit_liveness"
DAILY_LIMIT_REACHED = "daily_limit_reached"
DUPLICATE_SUBMISSION = "duplicate_submission"
"""This operationId has already been submitted and charged for.

Refused before the OCR provider is contacted, which is the point of it. The
ledger's own idempotency check lives inside `spend`, which runs after the paid
call, so it stops the second debit and not the second bill — and `operationId`
comes from the request body, so repeating one was an attacker-controlled way to
get unlimited billed Vision calls against a ledger that never moved. See
ledger.Budget.already_applied and pipeline._run."""
CONSENT_MISSING = "consent_missing"
APP_CHECK_MISSING = "app_check_missing"
UNAUTHENTICATED = "unauthenticated"
PHONE_SIGN_IN_REQUIRED = "phone_sign_in_required"
"""N1: the caller is signed in, but not with a phone number (email/password,
Google, Apple, anonymous). The women-facing callables take a phone sign-in
only, so an account with no SMS step cannot multiply the per-uid caps or
reach the review queue. Reviewers and admins may also use "password".
delete_account takes any provider (Protected List 6)."""
IMAGE_TOO_LARGE = "image_too_large"
IMAGE_UNDECODABLE = "image_undecodable"

# ---------------------------------------------------------------- reviewer

NIQAB_PATH_REQUESTED = "niqab_path_requested"
"""She asked for the woman-reviewer route herself. Not a failure and not a
downgrade: the bar goes UP, because a video call with a woman reviewer is
stronger evidence than any similarity score."""

REVIEWER_APPROVED = "reviewer_approved"
REVIEWER_REJECTED = "reviewer_rejected"
REVIEW_SLA_EXPIRED = "review_sla_expired"
"""A flagged case not decided within REVIEW_SLA_HOURS. She is moved to
RETRY_REQUIRED — one fresh attempt, still inside the cost cap — because an
undecided flag is our failure to review in time, not hers."""

REVIEW_SCHEDULED = "review_scheduled"
"""A live review has been booked: a video call with a woman reviewer, or a
ladies-only gym visit. Since no image is ever stored, this is what review IS."""

INTERNAL_ERROR = "internal_error"

# ------------------------------------------- review loop and abuse limits
# Stable wire values (contracts/identity_contract.json). Add, never rename.

CAMERA_DECLINED = "camera_declined"
"""She declined the camera at C09b and asked for a woman reviewer instead."""
REVIEW_REQUESTED_AFTER_ERROR = "review_requested_after_error"
"""The automatic check could not run for her (a network or server error) and
she asked for a woman reviewer rather than trying again."""
PER_UID_DAILY_LIMIT = "per_uid_daily_limit"
"""One account's daily allowance of a verification callable is used up. Checked
BEFORE the global kill switch so one account cannot exhaust it for everyone."""
VERIFICATION_CLOSED = "verification_closed"
"""Her verification has been rejected for good; no further attempt is taken."""
REVIEW_ALREADY_OPEN = "review_already_open"
"""She already has a review waiting. One open review per account."""
REVIEWER_IS_SUBJECT = "reviewer_is_subject"
"""A reviewer may never review her own case."""
REVIEW_NOT_PENDING = "review_not_pending"
"""The flag has already been decided or has expired."""
REVIEW_TIME_OUT_OF_RANGE = "review_time_out_of_range"
"""A reviewer tried to book a live review further ahead than
config.REVIEW_BOOKING_MAX_DAYS. Reviewer-facing only."""
REVIEW_CONSENT_MISSING = "review_consent_missing"
"""R4: a reviewer asked for her phone number before she asked for the call
(users/{uid}/consents/review-v{REVIEW_CONSENT_VERSION} does not exist). A
machine-raised flag has no consent until she taps "Ask for the call".
Reviewer-facing only."""


# ------------------------------------------------- what crosses the wire
#
# Spec §3: "Never expose scores, reason codes, or which check failed, because
# that teaches bypass."
#
# The Flutter worker's contract returns `{outcome, reasons}`. The key names are
# kept so the client parsing does not change; `reasons` is populated from THIS
# vocabulary and never from the internal codes above. An attacker who can read
# the response learns "retake the back of your card", not "your 13th digit said
# male and the printed word said female", which would tell them precisely which
# control to work on next.

RETAKE_FRONT = "retake_front"
RETAKE_BACK = "retake_back"
RETAKE_SELFIE = "retake_selfie"
TRY_AGAIN_LATER = "try_again_later"
CONTACT_SUPPORT = "contact_support"

USER_SAFE = frozenset(
    {RETAKE_FRONT, RETAKE_BACK, RETAKE_SELFIE, TRY_AGAIN_LATER, CONTACT_SUPPORT}
)

_TO_USER_SAFE = {
    NID_UNREADABLE: RETAKE_FRONT,
    NID_BAD_LENGTH: RETAKE_FRONT,
    NID_BAD_CENTURY: RETAKE_FRONT,
    NID_BAD_DATE: RETAKE_FRONT,
    NID_FUTURE_DATE: RETAKE_FRONT,
    AGE_IMPLAUSIBLE: RETAKE_FRONT,
    FACE_NOT_FOUND_ON_CARD: RETAKE_FRONT,
    FACE_TOO_SMALL_ON_CARD: RETAKE_FRONT,
    NID_SIDES_DISAGREE: RETAKE_BACK,
    SEX_WORD_UNREADABLE: RETAKE_BACK,
    LIVENESS_FAILED: RETAKE_SELFIE,
    FACE_NOT_FOUND_IN_REFERENCE: RETAKE_SELFIE,
    FACE_FRAMES_DISAGREE: RETAKE_SELFIE,
    MATCH_FAILED: RETAKE_SELFIE,
    SESSION_MISSING: RETAKE_SELFIE,
    SESSION_EXPIRED: RETAKE_SELFIE,
    SESSION_ALREADY_USED: RETAKE_SELFIE,
    IMAGE_TOO_LARGE: RETAKE_FRONT,
    IMAGE_UNDECODABLE: RETAKE_FRONT,
    COST_CAP_REACHED: CONTACT_SUPPORT,
    ATTEMPT_LIMIT_OCR: CONTACT_SUPPORT,
    ATTEMPT_LIMIT_LIVENESS: CONTACT_SUPPORT,
    DUPLICATE_ID: CONTACT_SUPPORT,
    REGISTRATION_CLOSED: CONTACT_SUPPORT,
    DAILY_LIMIT_REACHED: TRY_AGAIN_LATER,
    PER_UID_DAILY_LIMIT: TRY_AGAIN_LATER,
    DUPLICATE_SUBMISSION: TRY_AGAIN_LATER,
    LIVENESS_PROVIDER_ERROR: TRY_AGAIN_LATER,
    MATCH_PROVIDER_ERROR: TRY_AGAIN_LATER,
    INTERNAL_ERROR: TRY_AGAIN_LATER,
}
"""Deliberately MANY-TO-FEW. Twenty-eight internal codes collapse onto five
hints, so the mapping is not invertible and the response cannot be used to
recover which check failed.

Codes with no entry here map to nothing at all — notably SEX_DIGIT_MALE,
SEX_CONFLICT, UNDERAGE, NID_GOVERNORATE_UNKNOWN and every FLAG signal. There is
no actionable hint for those, and inventing one would be the leak this table
exists to prevent."""


def to_user_safe(codes) -> list[str]:
    """Collapse internal codes onto the hints the client may see.

    Order-preserving and de-duplicated, so a woman with two problems on the same
    photograph is told once.
    """
    out: list[str] = []
    for code in codes:
        hint = _TO_USER_SAFE.get(code)
        if hint and hint not in out:
            out.append(hint)
    return out


ALL: frozenset[str] = frozenset(
    value
    for name, value in list(globals().items())
    if name.isupper()
    and name not in {"ALL", "USER_SAFE"}
    and not name.startswith("RETAKE_")
    and name not in {"TRY_AGAIN_LATER", "CONTACT_SUPPORT"}
    and isinstance(value, str)
)
"""Used by the job writer to refuse to persist a code that is not in this file.

Belt and braces against exactly one thing: somebody, one day, under deadline,
passing an f-string into a reasons list and putting a sentence about a woman
into a document support staff can read.
"""
