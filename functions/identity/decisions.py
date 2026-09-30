"""Spec §3's decision matrix, as one pure function.

WHAT BELONGS IN HUMAN REVIEW, AND WHAT DOES NOT
-----------------------------------------------
The test every FLAG signal in here has to pass, and the reason several of spec
§3's no longer do:

    **A case belongs in human review only if a human would learn something a
    retake would not.**

That is sharper here than it sounds, because of what review IS in this product.
No image is ever stored (DECISIONS_NEEDED.md D3), so a reviewer cannot look at
her card or her selfie. She dials into a video call with a woman reviewer, who
sees reason codes, two scores and a face on a live camera. A reviewer therefore
learns a great deal about "is this a woman, and is she the person on the card"
and nothing whatsoever about "did the OCR read the small Arabic type on the
back correctly" — because by the time the call happens the photograph of that
type no longer exists anywhere.

So the signals split cleanly in two:

  SUSPICIOUS — the card contradicts itself, or behaviour across accounts and
    devices looks like someone working through cards. A retake cannot change
    any of it, and a live encounter settles it. These flag:
      SEX_CONFLICT, HMAC_MANY_FAILURES, INSTALL_MANY_IDS,
      LIVENESS_FLAG_BAND and MATCH_FLAG_BAND once the attempts are used,
      SEX_WORD_UNREADABLE once the attempts are used,
      BIRTH_DATE_MISMATCH once the attempts are used,
      NIQAB_PATH_REQUESTED, which she asked for herself.

  THE CAMERA FAILED — a statement about how the card photographed, not about
    the woman holding it. The remedy is another photograph, which costs
    $0.003 against fifteen minutes of a woman reviewer's day. These retake:
      SEX_WORD_UNREADABLE and BIRTH_DATE_MISMATCH while OCR retries remain,
      LIVENESS_FLAG_BAND and MATCH_FLAG_BAND while attempts remain.

  NEITHER — evidence about our own data, not about her:
      NID_GOVERNORATE_UNKNOWN, which is recorded and counted and does not
      open a review at all.

Every one of those downgrades is argued at the line that implements it,
including what an attacker gains from it. None of them lets anything through
that used to be stopped: a band score still never approves, an unreadable word
still flags once the retries are gone, and the two cross-account signals are
untouched. The arithmetic for what this does to the queue is in
VERIFICATION_REPORT.md; the short version is that at 50,000 sign-ups every
percentage point of flag rate is 500 video calls.

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
    """RECORDED, NOT FLAGGED. See `_score_stage`, which explains why a code we
    have not heard of is a gap in our table rather than a fact about her."""
    underage: bool = False
    age_implausible: bool = False
    printed_birth_date_disagrees: bool = False
    """A BAD READ FIRST, a flag only if it survives the retries. See `_early`.

    Not produced by the pipeline yet: spec §2 step 3 asks for the cross-check
    "if the printed birth date is readable", and nothing reads it today. The
    classification is set here anyway so that whoever wires it up inherits the
    right behaviour instead of inventing one under deadline."""

    # Step 4, the sex gate
    sex_from_digit: Optional[str] = None  # "female" | "male"
    sex_from_word: Optional[str] = None  # "female" | "male" | None = unreadable
    ocr_retries_exhausted: bool = False
    """True once she has used her MAX_OCR_SUBMISSIONS photographs of the card.

    Spec §3 flags an unreadable النوع word only "after retries". Before the
    retries are used up the right answer is RETRY_CAPTURE — ask her to
    photograph the back again — because a human reviewer is expensive and a
    second photograph is free.

    Named for the OCR budget rather than for the النوع word, because it now
    gates two different bad-read signals: the unreadable sex word and a printed
    birth date that disagrees with the encoded one. Both are statements about
    how the card photographed, not about the woman holding it, and both deserve
    the same free remedy before a human is spent."""

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


def decide_budget_refusal(code: str) -> Decision:
    """What to answer when the ledger refuses a call: she has used everything
    we gave her.

    THIS IS NOT RETRY_CAPTURE, AND IT USED TO BE.

    `ledger.check` refuses three ways: the OCR submissions are gone
    (MAX_OCR_SUBMISSIONS = 4), the liveness attempts are gone
    (MAX_LIVENESS_ATTEMPTS = 2), or the per-uid cost cap is reached. All three
    returned RETRY_CAPTURE, which the client maps to the camera screen. The
    budget document is keyed by uid, has no TTL, no expiry and nothing anywhere
    in `functions/` resets it, so the fifth unreadable photograph of a card sent
    her back to the camera to take a sixth, and a sixth to take a seventh, for
    the life of the account. She was told nothing, because the user-safe hint
    never reached her screen either.

    A refusal here is a statement about OUR limit, never about her photograph,
    so "take it again" is the one answer that cannot be true. PENDING_REVIEW is:
    it is already what an exhausted OCR allowance means everywhere else in this
    module (SEX_WORD_UNREADABLE and BIRTH_DATE_MISMATCH both flag once
    `ocr_retries_exhausted`), and review in this product is a video call with a
    woman reviewer, who can settle in three minutes what four photographs of a
    laminated card could not.

    The abuse case does not argue the other way. An attacker who burns the
    liveness allowance against one card buys a live encounter with a human,
    which is a higher bar than the score they were trying to game, not a lower
    one. The same reasoning is written out for NIQAB_PATH_REQUESTED.

    A reviewer-callable reset of the budget is the obvious companion to this and
    is deliberately NOT here: it is a product decision about who may hand a
    woman four more attempts, and it belongs to the owner.
    """
    return Decision(PENDING_REVIEW, (code,))


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
         must never fall through into a rejection. This section grew: an
         unreadable النوع word whichever way digit 13 reads, and a printed
         birth date disagreeing with the encoded one, are now bad reads first
         and flags only once the OCR retries are gone.
      2. Then the eligibility rejections, which no retry can change.
      3. Then the duplicate gate.
      4. Then flags.
      5. Then the score rejections, which require attempts to be exhausted.
      6. Approval only when nothing above fired.

    Putting flags AFTER the hard rejections is the one ordering choice worth
    arguing about. It means a man whose card also carries some other oddity is
    rejected rather than queued for a human — correct, because a human would
    reject him too and the flag queue is a scarce resource that exists for
    ambiguous women, not for unambiguous men.

    Step 5 has one more ordering rule inside it, for the same reason: an
    uncertain SCORE sends her to a human only once a retake can no longer help
    and nothing else about her attempt already needs one. See `_score_stage`.
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
        and not signals.ocr_retries_exhausted
        and signals.sex_from_digit is not None
    ):
        # THE OCR FAILED. THAT IS NOT A SUSPICION.
        #
        # An unreadable النوع word says the back of the card photographed badly:
        # glare on the laminate, a shadow, a scratch across a field printed in
        # small Arabic type. A human reviewer on a video call learns nothing
        # from it that a second photograph would not, and the second photograph
        # costs $0.003 while the video call costs fifteen minutes of a woman
        # reviewer's day. Spec §3 agrees — it flags an unreadable word only
        # "after retries" — and `ocr_retries_exhausted` is where that ends.
        #
        # This used to apply only while digit 13 said female. It now applies
        # whichever way the digit reads, and the male-digit case is the one that
        # gained the most:
        #
        #   * if the retake reads ذكر, he is a clean REJECTED_NOT_ELIGIBLE and
        #     never reaches a human at all;
        #   * if the retake reads أنثى, the digit and the word genuinely
        #     disagree and SEX_CONFLICT fires below, which is a real flag;
        #   * if it still will not read after four photographs, it flags exactly
        #     as it did before.
        #
        # So the change converts reviews into retakes and loses no case. What an
        # attacker gains: a man who deliberately obscures the النوع field can
        # make us pay for four OCR submissions (12,000 µUSD, inside the 50,000
        # cap) before he reaches the same human review he used to reach
        # immediately. He arrives at a video call with a woman reviewer either
        # way, which is where he is caught.
        return Decision(RETRY_CAPTURE, (reasons.SEX_WORD_UNREADABLE,))

    if (
        signals.printed_birth_date_disagrees
        and not signals.ocr_retries_exhausted
        and signals.sex_from_digit != "male"
    ):
        # The `!= "male"` guard keeps spec §2 step 4's "reject immediately, make
        # no further paid calls". By the time execution reaches here with a male
        # digit the printed word HAS been read — an unreadable one returned
        # above — so it either agrees (he is rejected two blocks down, and four
        # more photographs of his birth date would change nothing) or it
        # disagrees (SEX_CONFLICT, a real flag a retake cannot clear). Unlike
        # the النوع word, a clearer photograph of a printed date tells us
        # nothing at all about digit 13.
        #
        # Same reasoning as above otherwise, and the evidence points the same
        # way.
        #
        # Nothing hangs on the PRINTED date: age comes from digits 2-7 of the
        # number, which has already been parsed as a real calendar date and
        # checked against MIN_AGE. So a disagreement is not a fact about her
        # eligibility, it is a fact about one OCR pass over small print on a
        # laminated card — the error-prone half of a comparison whose other half
        # was validated structurally.
        #
        # A forger controls both fields and would make them agree, so this
        # catches only careless forgeries, and it catches them just as well on
        # the fourth photograph as on the first. Asking for a better photograph
        # first therefore removes the OCR noise without removing the signal: a
        # disagreement that survives four independent reads is no longer
        # plausibly a slip, and THAT is the thing worth a human.
        #
        # What an attacker gains: a careless forgery gets up to three further
        # attempts to have its printed date read as something consistent. Since
        # the date is read by the same OCR each time and the forgery does not
        # change between photographs, that is close to no gain at all.
        return Decision(RETRY_CAPTURE, (reasons.BIRTH_DATE_MISMATCH,))

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
        # RECORDED, NOT FLAGGED. `found.append` rather than `flag`, and the one
        # word difference is the whole decision.
        #
        # Spec §2 step 3 calls an unknown governorate code a FLAG signal and
        # says why in the same breath: "because the list may be incomplete". So
        # the spec already tells us what an unknown code evidences — a gap in
        # OUR table — and nid.GOVERNORATES says the same thing at more length.
        # It is not evidence about the woman. A human on a video call cannot
        # look at a two-digit code and learn anything from her face, and the
        # card image she was asked for no longer exists by the time the call
        # happens, so there is literally nothing for a reviewer to examine.
        #
        # It is also not rare enough to treat as an oddity. The code is digits
        # 8-9 of a number read by OCR from Arabic-Indic glyphs on a laminated
        # card. Only 28 of the 100 two-digit codes are real, so roughly seven in
        # ten single-digit misreads in that position land on a code we have
        # never heard of. This signal is therefore mostly an OCR-error detector
        # wearing a fraud detector's coat, and at 50,000 sign-ups each percent
        # of it is 500 video calls.
        #
        # What an attacker gains: a forged card carrying a governorate code that
        # was never issued now passes this particular check silently. That is
        # worth close to nothing to him. He had to forge a card to get here, and
        # RESIDUAL_RISKS.md #1 already states plainly that nothing in this system
        # detects a forged card — no hologram, no microprint, no government
        # lookup. A forger clever enough to print a card is clever enough to
        # copy a real governorate code off any other card, so the only forgeries
        # this ever caught were the ones that would fail on sight anyway.
        #
        # It is still RECORDED on the job document, and main.py counts the code
        # itself into an aggregate with no uid attached, so the table in nid.py
        # can be corrected the first time the state issues a code we do not have.
        found.append(reasons.NID_GOVERNORATE_UNKNOWN)

    if signals.printed_birth_date_disagrees:
        # Reached only when `_early` let it through, which means the retries are
        # exhausted: four separate photographs of the card all read a printed
        # date that disagrees with the encoded one. At that point it has stopped
        # looking like an OCR slip and started looking like a property of the
        # card, which is a human's question. See the long note in `_early`.
        flag(reasons.BIRTH_DATE_MISMATCH)

    if (
        signals.sex_from_digit == "female"
        and signals.sex_from_word == "male"
    ):
        flag(reasons.SEX_CONFLICT)
    if (
        signals.sex_from_word is None
        and signals.ocr_retries_exhausted
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

        # ------------------------------------------ the uncertain band
        #
        # A score between FLAG and PASS is the one case this whole review queue
        # exists for, and it is also the single largest source of its volume. So
        # the ordering below matters: a band score sends her to a human only
        # when a retake can no longer help and nothing else about her attempt is
        # already suspicious.
        #
        # Why a retake helps here, concretely. The band is our matcher being
        # unsure, and the things that make it unsure are the things a second
        # capture changes: a three-quarter selfie against a passport-style card
        # portrait, a shadow across half her face, a card held at an angle so
        # the printed photograph is keystoned, a small turn that barely cleared
        # YAW_SPREAD_MIN. A woman reviewer on a video call cannot see any of
        # that — by the time she dials in, no image exists anywhere — so she
        # learns strictly less from a band score than a second photograph does.
        # That is the owner's test for what belongs in review, applied to the
        # biggest queue driver in the system.
        #
        # Nothing is approved that would not have been approved before: a band
        # score never passes, on any attempt. The only change is that the human
        # is spent last instead of first.
        #
        # What an attacker gains: an impostor whose first attempt lands in the
        # band is told to retake instead of being put in front of a woman
        # reviewer, so he gets a second draw at clearing match_pass. That is
        # bounded at exactly one extra draw by MAX_LIVENESS_ATTEMPTS = 2, which
        # stays at 2 for this reason and is already documented as an abuse limit
        # rather than a spending one. The cost of that extra draw is priced into
        # the choice of match_pass in config.py: the 1.1 expected admissions
        # across the launch is computed with 500 impostors taking TWO attempts
        # each, not one. And an impostor who burns attempts on card after card
        # raises HMAC_MANY_FAILURES or INSTALL_MANY_IDS, which are flags a
        # retake cannot clear.
        banded: list[str] = []
        if liveness_verdict == _BAND:
            banded.append(reasons.LIVENESS_FLAG_BAND)
        if match_verdict == _BAND:
            banded.append(reasons.MATCH_FLAG_BAND)

        if banded and not flags and not signals.attempts_exhausted:
            # `not flags` is load-bearing. If she is already going to a human
            # for a reason a retake cannot fix — the sex word and digit 13
            # disagree, the same card has failed across three accounts, she
            # asked for a woman reviewer herself — then sending her round the
            # loop again wastes her time and delays a review she is getting
            # anyway. Only a case whose ONLY problem is an uncertain score gets
            # the retake.
            return Decision(RETRY_CAPTURE, tuple(found + banded))

        for code in banded:
            flag(code)

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
