"""Spec §3's decision matrix, as one pure function.

`decide()` takes a bag of already-gathered signals and returns an outcome. It
makes no network calls, reads no clock, touches no Firestore. That is what lets
tests/test_decisions.py walk every row of the matrix and every FLAG signal,
including values sitting exactly on each threshold — which is spec §9.2's
requirement and is impossible to do honestly against a function that also does
I/O.

The ordering inside `decide` is not the same thing as the ordering of the
PIPELINE. Spec §2 fixes the pipeline order so that cheap checks run before paid
ones and a male applicant costs about $0.003; that ordering lives in
pipeline.py, and it is why most fields on `Signals` are Optional — by the time a
male applicant is rejected, liveness has never run and there is no confidence to
report. `decide` handles the partial bag correctly rather than assuming a full
one.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

from . import config, reasons

# ------------------------------------------------------------------ outcomes

APPROVED = "APPROVED"
PENDING_REVIEW = "PENDING_REVIEW"
REJECTED_NOT_ELIGIBLE = "REJECTED_NOT_ELIGIBLE"
REJECTED_FAILED = "REJECTED_FAILED"
REJECTED_DUPLICATE = "REJECTED_DUPLICATE"
RETRY_CAPTURE = "RETRY_CAPTURE"
RETRY_REQUIRED = "RETRY_REQUIRED"
"""Spec §5's 72-hour expiry state. Not produced by `decide`; set by the purge
job. Listed here so the state machine is readable in one place."""

OUTCOMES = frozenset(
    {
        APPROVED,
        PENDING_REVIEW,
        REJECTED_NOT_ELIGIBLE,
        REJECTED_FAILED,
        REJECTED_DUPLICATE,
        RETRY_CAPTURE,
        RETRY_REQUIRED,
    }
)

TERMINAL_REJECTIONS = frozenset({REJECTED_NOT_ELIGIBLE, REJECTED_DUPLICATE})
"""Outcomes a retry cannot change. A man's card will still be a man's card on
the fourth attempt, and spending more of the budget on it helps nobody."""


# ------------------------------------------------------------------ signals


@dataclass(frozen=True)
class Signals:
    """Everything known about one attempt, at the moment of decision.

    Optional means "this stage never ran", not "this stage returned nothing".
    The distinction matters: a `None` liveness confidence on a male applicant is
    correct and expected, while a `None` on a female applicant who reached step
    6 is a bug, and `decide` treats the second as RETRY_CAPTURE rather than
    silently approving on the strength of the checks that did run.
    """

    # Step 3, parsing
    nid_parse_failure: Optional[str] = None
    sides_disagree: bool = False
    governorate_unknown: bool = False
    underage: bool = False
    age_implausible: bool = False
    printed_birth_date_disagrees: bool = False

    # Step 4, the sex gate
    sex_from_digit: Optional[str] = None  # "female" | "male"
    sex_from_word: Optional[str] = None  # "female" | "male" | None = unreadable
    sex_word_retries_exhausted: bool = False
    """Spec §3 flags an unreadable word only "after retries". Before the retries
    are used up the right answer is RETRY_CAPTURE — ask her to photograph the
    back again — because a human reviewer is expensive and a second photograph
    is free."""

    # Step 5, dedupe
    duplicate_of_other_account: bool = False
    registration_closed: bool = False

    # Step 6, liveness
    liveness_ran: bool = False
    liveness_confidence: Optional[float] = None
    liveness_provider_error: bool = False

    # Step 7, match
    match_ran: bool = False
    match_similarity: Optional[float] = None
    match_provider_error: bool = False
    face_not_found_on_card: bool = False

    # Cross-account behaviour, spec §3's last two FLAG signals
    hmac_failure_count: int = 0
    install_distinct_hmacs: int = 0

    # Attempt state
    attempts_exhausted: bool = False
    """True when the woman has used her OCR or liveness allowance. Spec §3 makes
    REJECTED_FAILED conditional on this: a low score on attempt one is
    RETRY_CAPTURE, and only a low score with nothing left becomes a rejection."""

    niqab_path_requested: bool = False

    # Provider identity, checked against the threshold set's scales.
    # None means that stage did not run and has nothing to check.
    liveness_scale: Optional[str] = None
    match_scale: Optional[str] = None


@dataclass(frozen=True)
class Decision:
    outcome: str
    reasons: tuple[str, ...] = ()
    flags: tuple[str, ...] = ()
    """The subset of `reasons` that are spec §3 FLAG signals. Carried
    separately so `verification_flags` can record exactly why a human is being
    asked, without a reviewer having to re-derive it."""

    def __post_init__(self) -> None:
        if self.outcome not in OUTCOMES:
            raise ValueError(f"unknown outcome {self.outcome!r}")
        unknown = set(self.reasons) - reasons.ALL
        if unknown:
            # The guard that stops a free-text sentence about a woman reaching a
            # document support staff can read.
            raise ValueError(f"reason codes not in reasons.py: {sorted(unknown)}")


def decide_before_scores(signals: Signals) -> Optional[Decision]:
    """Everything spec §3 can conclude WITHOUT liveness or match scores.

    Returns a terminal Decision, or None meaning "keep going, this attempt has
    earned its paid calls".

    This exists because spec §2's ordering is a requirement: a male applicant
    must be rejected before liveness is paid for. The pipeline calls this at
    step 4 and step 5, and only proceeds to the paid providers when it returns
    None. Running the full matrix there instead would report RETRY_CAPTURE for
    every applicant, because the scores legitimately do not exist yet.

    Flags are deliberately NOT terminal here. A flagged case still needs its
    scores gathered so the reviewer has something to look at, unless it is
    flagged for a reason that makes the scores meaningless (the niqab path,
    which the pipeline handles separately).
    """
    found: list[str] = []
    flags: list[str] = []
    terminal = _early(signals, found, flags)
    return terminal


def decide(
    signals: Signals, thresholds: Optional[config.ThresholdSet] = None
) -> Decision:
    """Spec §3, top to bottom.

    Order within the matrix is deliberate and is NOT the pipeline order:

      1. Things that make the attempt unreadable (RETRY_CAPTURE) come first,
         because a card we could not read tells us nothing about who she is and
         must never fall through into a rejection.
      2. Then the eligibility rejections, which no retry can change.
      3. Then the duplicate gate.
      4. Then flags.
      5. Then the score rejections, which require attempts to be exhausted.
      6. Approval only when nothing above fired.

    Putting flags AFTER the hard rejections is the one ordering choice worth
    arguing about. It means a man whose card also has an unknown governorate is
    rejected rather than queued for a human — correct, because a human would
    reject him too and the flag queue is a scarce resource that exists for
    ambiguous women, not for unambiguous men.
    """
    thresholds = thresholds or config.ACTIVE_THRESHOLDS
    # Raises ThresholdScaleMismatch rather than judging a cosine-derived score
    # against Rekognition confidence thresholds. See config.py.
    thresholds = thresholds.for_providers(signals.liveness_scale, signals.match_scale)

    found: list[str] = []
    flags: list[str] = []

    def flag(code: str) -> None:
        found.append(code)
        flags.append(code)

    terminal = _early(signals, found, flags)
    if terminal is not None:
        return terminal

    return _score_stage(signals, thresholds, found, flags, flag)


def _early(
    signals: Signals, found: list[str], flags: list[str]
) -> Optional[Decision]:
    """Sections 1-3 of the matrix, plus the flags they raise.

    Mutates `found` and `flags` so the caller keeps any flag raised on the way
    through — a male digit contradicted by a female printed word raises
    SEX_CONFLICT here and must still be in the final decision's flag list.
    """

    def flag(code: str) -> None:
        found.append(code)
        flags.append(code)

    # ---------------------------------------------------- 1. unreadable input

    if signals.nid_parse_failure:
        return Decision(RETRY_CAPTURE, (signals.nid_parse_failure,))
    if signals.sides_disagree:
        return Decision(RETRY_CAPTURE, (reasons.NID_SIDES_DISAGREE,))
    if signals.age_implausible:
        # A 130-year-old is a misread date, not a supercentenarian, and telling
        # her to retake the photograph is the truthful response.
        return Decision(RETRY_CAPTURE, (reasons.AGE_IMPLAUSIBLE,))
    if signals.face_not_found_on_card:
        return Decision(RETRY_CAPTURE, (reasons.FACE_NOT_FOUND_ON_CARD,))
    if signals.liveness_provider_error:
        # Spec §9.4: the user gets a retry and no charge is recorded. The "no
        # charge" half is enforced in ledger.py, which only debits on a
        # successful provider call.
        return Decision(RETRY_CAPTURE, (reasons.LIVENESS_PROVIDER_ERROR,))
    if signals.match_provider_error:
        return Decision(RETRY_CAPTURE, (reasons.MATCH_PROVIDER_ERROR,))
    if (
        signals.sex_from_word is None
        and not signals.sex_word_retries_exhausted
        and signals.sex_from_digit == "female"
    ):
        # Ask for a better photograph of the back before spending a reviewer on
        # her. Only applies while the digit says female: if the digit says male
        # we have a rejection to make and no reason to keep asking.
        return Decision(RETRY_CAPTURE, (reasons.SEX_WORD_UNREADABLE,))

    # -------------------------------------------- 2. eligibility rejections

    if signals.sex_from_digit == "male":
        # Spec §2 step 4. Note what does NOT happen here: nothing looks at her
        # face to reach this. Gender comes only from the card (rule of
        # engagement 4), and the two sources are digit 13 and the printed word.
        if signals.sex_from_word == "female":
            # The sources disagree. Spec §3 makes that a FLAG, and a flag beats
            # a rejection: a woman whose 13th digit was misread by one position
            # is exactly the person this branch exists for.
            flag(reasons.SEX_CONFLICT)
        elif signals.sex_from_word is None:
            flag(reasons.SEX_WORD_UNREADABLE)
        else:
            return Decision(REJECTED_NOT_ELIGIBLE, (reasons.SEX_DIGIT_MALE,))

    if signals.underage:
        return Decision(REJECTED_NOT_ELIGIBLE, (reasons.UNDERAGE,))

    # ------------------------------------------------------- 3. the duplicate

    if signals.registration_closed:
        return Decision(REJECTED_DUPLICATE, (reasons.REGISTRATION_CLOSED,))
    if signals.duplicate_of_other_account:
        return Decision(REJECTED_DUPLICATE, (reasons.DUPLICATE_ID,))

    return None


def _score_stage(
    signals: Signals,
    thresholds: config.ThresholdSet,
    found: list[str],
    flags: list[str],
    flag,
) -> Decision:
    """Sections 4-6: the flags that need no score, then the scores themselves."""

    # ------------------------------------------------------------- 4. flags

    if signals.niqab_path_requested:
        flag(reasons.NIQAB_PATH_REQUESTED)
    if signals.governorate_unknown:
        flag(reasons.NID_GOVERNORATE_UNKNOWN)
    if signals.printed_birth_date_disagrees:
        flag(reasons.BIRTH_DATE_MISMATCH)
    if (
        signals.sex_from_digit == "female"
        and signals.sex_from_word == "male"
    ):
        flag(reasons.SEX_CONFLICT)
    if (
        signals.sex_from_word is None
        and signals.sex_word_retries_exhausted
        and reasons.SEX_WORD_UNREADABLE not in found
    ):
        flag(reasons.SEX_WORD_UNREADABLE)
    if signals.hmac_failure_count > 2:
        flag(reasons.HMAC_MANY_FAILURES)
    if signals.install_distinct_hmacs > 2:
        flag(reasons.INSTALL_MANY_IDS)

    # ----------------------------------------- 5. the scores, and their bands
    #
    # The niqab path deliberately never reaches these. A woman who asked for a
    # woman reviewer is not made to fail a face match she cannot pass; her flag
    # is already raised and the scores are not part of her decision.

    if not signals.niqab_path_requested:
        liveness_verdict = _band(
            signals.liveness_confidence,
            ran=signals.liveness_ran,
            flag_at=thresholds.liveness_flag,
            pass_at=thresholds.liveness_pass,
        )
        match_verdict = _band(
            signals.match_similarity,
            ran=signals.match_ran,
            flag_at=thresholds.match_flag,
            pass_at=thresholds.match_pass,
        )

        if liveness_verdict == _MISSING or match_verdict == _MISSING:
            # A stage that should have run did not. Never approve on the
            # strength of the checks that happened to complete.
            return Decision(RETRY_CAPTURE, (reasons.INTERNAL_ERROR,))

        if liveness_verdict == _BELOW or match_verdict == _BELOW:
            failed = []
            if liveness_verdict == _BELOW:
                failed.append(reasons.LIVENESS_FAILED)
            if match_verdict == _BELOW:
                failed.append(reasons.MATCH_FAILED)
            if signals.attempts_exhausted:
                return Decision(REJECTED_FAILED, tuple(failed))
            # Spec §3 makes REJECTED_FAILED conditional on "after the allowed
            # attempts are used". Before that, she gets another go, which is the
            # difference between a system that rejects a badly-lit first attempt
            # and one that helps her take a better photograph.
            return Decision(RETRY_CAPTURE, tuple(failed))

        if liveness_verdict == _BAND:
            flag(reasons.LIVENESS_FLAG_BAND)
        if match_verdict == _BAND:
            flag(reasons.MATCH_FLAG_BAND)

    # ------------------------------------------------------ 6. the outcome

    if flags:
        return Decision(PENDING_REVIEW, tuple(found), tuple(flags))

    passed = [reasons.LIVENESS_PASS, reasons.MATCH_PASS] if not signals.niqab_path_requested else []
    return Decision(APPROVED, tuple(found + passed))


_MISSING = "missing"
_BELOW = "below"
_BAND = "band"
_ABOVE = "above"


def _band(
    score: Optional[float], *, ran: bool, flag_at: float, pass_at: float
) -> str:
    """Place one score in spec §3's three bands.

    Boundaries are inclusive at the top of each band, matching spec §3's
    wording: APPROVED needs `>= PASS`, REJECTED_FAILED needs `< FLAG`. So a
    score sitting exactly on FLAG is in the flag band, and a score sitting
    exactly on PASS passes. Spec §9.2 requires tests at exactly each threshold,
    and those tests are the reason this is a named function rather than two
    comparisons inlined twice.
    """
    if not ran or score is None:
        return _MISSING
    if score < flag_at:
        return _BELOW
    if score < pass_at:
        return _BAND
    return _ABOVE
