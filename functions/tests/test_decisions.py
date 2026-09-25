"""Spec §9.2: every row of the decision matrix and every FLAG signal,
including values sitting exactly on each threshold.

`decide` is pure, which is what makes "exactly on the threshold" testable at
all. Against a function that also did I/O these cases would need an emulator and
would be skipped.
"""

from __future__ import annotations

import pytest

from identity import config, decisions, reasons

T = config.THRESHOLDS_SELF_HOSTED


def good(**overrides) -> decisions.Signals:
    """A clean female applicant who should be APPROVED, minus any override."""
    base = dict(
        sex_from_digit="female",
        sex_from_word="female",
        liveness_ran=True,
        liveness_confidence=T.liveness_pass + 5,
        match_ran=True,
        match_similarity=T.match_pass + 5,
        liveness_scale=T.liveness_scale,
        match_scale=T.match_scale,
    )
    base.update(overrides)
    return decisions.Signals(**base)


def outcome(**overrides) -> str:
    return decisions.decide(good(**overrides), T).outcome


# ------------------------------------------------------------- matrix rows


def test_clean_female_applicant_is_approved():
    assert outcome() == decisions.APPROVED


def test_male_digit_with_agreeing_word_is_not_eligible():
    result = decisions.decide(good(sex_from_digit="male", sex_from_word="male"), T)
    assert result.outcome == decisions.REJECTED_NOT_ELIGIBLE
    assert reasons.SEX_DIGIT_MALE in result.reasons


def test_underage_is_not_eligible():
    assert outcome(underage=True) == decisions.REJECTED_NOT_ELIGIBLE


def test_duplicate_is_rejected_duplicate():
    assert outcome(duplicate_of_other_account=True) == decisions.REJECTED_DUPLICATE


def test_closed_registration_is_rejected_duplicate():
    result = decisions.decide(good(registration_closed=True), T)
    assert result.outcome == decisions.REJECTED_DUPLICATE
    assert reasons.REGISTRATION_CLOSED in result.reasons


def test_low_scores_with_attempts_left_is_retry_not_rejection():
    # Spec §3 conditions REJECTED_FAILED on "after the allowed attempts are
    # used". A badly-lit first attempt must get another go.
    assert (
        outcome(match_similarity=T.match_flag - 10, attempts_exhausted=False)
        == decisions.RETRY_CAPTURE
    )


def test_low_scores_with_attempts_exhausted_is_rejected_failed():
    result = decisions.decide(
        good(match_similarity=T.match_flag - 10, attempts_exhausted=True), T
    )
    assert result.outcome == decisions.REJECTED_FAILED
    assert reasons.MATCH_FAILED in result.reasons


def test_low_liveness_with_attempts_exhausted_is_rejected_failed():
    result = decisions.decide(
        good(liveness_confidence=T.liveness_flag - 10, attempts_exhausted=True), T
    )
    assert result.outcome == decisions.REJECTED_FAILED
    assert reasons.LIVENESS_FAILED in result.reasons


def test_unreadable_number_is_retry_capture():
    assert outcome(nid_parse_failure=reasons.NID_BAD_DATE) == decisions.RETRY_CAPTURE


def test_sides_disagreeing_is_retry_capture():
    assert outcome(sides_disagree=True) == decisions.RETRY_CAPTURE


def test_no_face_on_card_is_retry_capture():
    assert outcome(face_not_found_on_card=True) == decisions.RETRY_CAPTURE


def test_implausible_age_is_retry_not_rejection():
    # A 130-year-old is a misread date. Telling her to retake the photo is the
    # truthful response; rejecting her is not.
    assert outcome(age_implausible=True) == decisions.RETRY_CAPTURE


# --------------------------------------------------------- the FLAG signals


@pytest.mark.parametrize(
    "override,expected_flag",
    [
        ({"governorate_unknown": True}, reasons.NID_GOVERNORATE_UNKNOWN),
        ({"printed_birth_date_disagrees": True}, reasons.BIRTH_DATE_MISMATCH),
        ({"sex_from_word": "male"}, reasons.SEX_CONFLICT),
        ({"hmac_failure_count": 3}, reasons.HMAC_MANY_FAILURES),
        ({"install_distinct_hmacs": 3}, reasons.INSTALL_MANY_IDS),
        ({"niqab_path_requested": True}, reasons.NIQAB_PATH_REQUESTED),
    ],
)
def test_each_flag_signal_sends_the_case_to_review(override, expected_flag):
    result = decisions.decide(good(**override), T)
    assert result.outcome == decisions.PENDING_REVIEW
    assert expected_flag in result.flags


def test_unreadable_sex_word_after_retries_is_a_flag():
    result = decisions.decide(
        good(sex_from_word=None, sex_word_retries_exhausted=True), T
    )
    assert result.outcome == decisions.PENDING_REVIEW
    assert reasons.SEX_WORD_UNREADABLE in result.flags


def test_unreadable_sex_word_before_retries_asks_for_another_photo():
    # A second photograph is free; a human reviewer is not.
    result = decisions.decide(
        good(sex_from_word=None, sex_word_retries_exhausted=False), T
    )
    assert result.outcome == decisions.RETRY_CAPTURE


def test_male_digit_with_female_word_is_flagged_not_rejected():
    # THE case this whole cross-check exists for: one mis-OCR'd Arabic-Indic
    # glyph flips digit 13, and a woman turned away by one glyph is the worst
    # outcome this system can produce.
    result = decisions.decide(good(sex_from_digit="male", sex_from_word="female"), T)
    assert result.outcome == decisions.PENDING_REVIEW
    assert reasons.SEX_CONFLICT in result.flags


def test_male_digit_with_unreadable_word_is_flagged_not_rejected():
    result = decisions.decide(
        good(sex_from_digit="male", sex_from_word=None, sex_word_retries_exhausted=True),
        T,
    )
    assert result.outcome == decisions.PENDING_REVIEW


def test_hmac_failure_count_of_exactly_two_is_not_flagged():
    # Spec §3 says "more than 2".
    assert outcome(hmac_failure_count=2) == decisions.APPROVED


def test_install_distinct_hmacs_of_exactly_two_is_not_flagged():
    # One household phone verifying a mother and two daughters is a real
    # Egyptian scenario and must stay under the limit.
    assert outcome(install_distinct_hmacs=2) == decisions.APPROVED


# ------------------------------------------------------- threshold boundaries
# Spec §9.2: "including values at exactly each threshold".


def test_score_exactly_on_match_pass_is_approved():
    assert outcome(match_similarity=T.match_pass) == decisions.APPROVED


def test_score_one_below_match_pass_is_flagged():
    result = decisions.decide(good(match_similarity=T.match_pass - 0.01), T)
    assert result.outcome == decisions.PENDING_REVIEW
    assert reasons.MATCH_FLAG_BAND in result.flags


def test_score_exactly_on_match_flag_is_flagged_not_failed():
    result = decisions.decide(
        good(match_similarity=T.match_flag, attempts_exhausted=True), T
    )
    assert result.outcome == decisions.PENDING_REVIEW


def test_score_just_below_match_flag_is_failed():
    result = decisions.decide(
        good(match_similarity=T.match_flag - 0.01, attempts_exhausted=True), T
    )
    assert result.outcome == decisions.REJECTED_FAILED


def test_liveness_exactly_on_pass_is_approved():
    assert outcome(liveness_confidence=T.liveness_pass) == decisions.APPROVED


def test_liveness_exactly_on_flag_is_flagged():
    result = decisions.decide(
        good(liveness_confidence=T.liveness_flag, attempts_exhausted=True), T
    )
    assert result.outcome == decisions.PENDING_REVIEW


def test_liveness_just_below_flag_is_failed():
    result = decisions.decide(
        good(liveness_confidence=T.liveness_flag - 0.01, attempts_exhausted=True), T
    )
    assert result.outcome == decisions.REJECTED_FAILED


# ------------------------------------------------------------ safety rails


def test_a_stage_that_never_ran_never_approves():
    # The failure mode that matters: approving on the strength of the checks
    # that happened to complete.
    result = decisions.decide(good(match_ran=False, match_similarity=None), T)
    assert result.outcome == decisions.RETRY_CAPTURE


def test_missing_liveness_never_approves():
    result = decisions.decide(good(liveness_ran=False, liveness_confidence=None), T)
    assert result.outcome == decisions.RETRY_CAPTURE


def test_niqab_path_never_touches_the_scores():
    # She is not made to fail a face match she cannot pass.
    result = decisions.decide(
        decisions.Signals(
            sex_from_digit="female",
            sex_from_word="female",
            niqab_path_requested=True,
            liveness_ran=False,
            match_ran=False,
        ),
        T,
    )
    assert result.outcome == decisions.PENDING_REVIEW
    assert reasons.NIQAB_PATH_REQUESTED in result.flags


def test_hard_rejection_beats_a_flag():
    # A man whose card also has an unknown governorate is rejected, not queued.
    # The flag queue is a scarce resource for ambiguous women.
    result = decisions.decide(
        good(sex_from_digit="male", sex_from_word="male", governorate_unknown=True), T
    )
    assert result.outcome == decisions.REJECTED_NOT_ELIGIBLE


def test_decision_refuses_a_reason_code_that_is_not_in_reasons_py():
    # The guard that stops a free-text sentence about a woman reaching a
    # document support staff can read.
    with pytest.raises(ValueError, match="not in reasons.py"):
        decisions.Decision(decisions.APPROVED, ("she looks like a man",))


def test_decision_refuses_an_unknown_outcome():
    with pytest.raises(ValueError, match="unknown outcome"):
        decisions.Decision("MAYBE", ())


# ------------------------------------------------- the threshold-scale guard


def test_rekognition_thresholds_refuse_to_judge_a_cosine_derived_score():
    # The catch the coordinator asked to be made loud: a mapped SFace cosine is
    # not a Rekognition confidence, and carrying the numbers across is the most
    # likely way to cause a silent false accept.
    with pytest.raises(config.ThresholdScaleMismatch):
        decisions.decide(
            good(match_scale=config.SCALE_SFACE_COSINE_MAPPED),
            config.THRESHOLDS_REKOGNITION,
        )


def test_self_hosted_thresholds_refuse_to_judge_a_rekognition_score():
    with pytest.raises(config.ThresholdScaleMismatch):
        decisions.decide(
            good(match_scale=config.SCALE_REKOGNITION), config.THRESHOLDS_SELF_HOSTED
        )


def test_our_own_liveness_scale_is_not_interchangeable_with_our_own_match_scale():
    # The subtlest version, and the one that was actually wrong in config.py
    # before a test caught it: two scores we compute ourselves are still
    # different quantities. A weighted challenge composite is not a mapped
    # cosine, and a threshold tuned on one is meaningless against the other.
    with pytest.raises(config.ThresholdScaleMismatch):
        decisions.decide(
            good(liveness_scale=config.SCALE_SFACE_COSINE_MAPPED), T
        )


def test_matching_scales_are_accepted():
    assert decisions.decide(good(), T).outcome == decisions.APPROVED


def test_a_stage_that_did_not_run_has_no_scale_to_check():
    # The male early exit reaches a decision with no liveness score at all, so a
    # None scale must not raise.
    result = decisions.decide(
        decisions.Signals(sex_from_digit="male", sex_from_word="male"), T
    )
    assert result.outcome == decisions.REJECTED_NOT_ELIGIBLE


def test_threshold_sets_declare_where_their_numbers_came_from():
    for threshold_set in (
        config.THRESHOLDS_REKOGNITION,
        config.THRESHOLDS_SELF_HOSTED,
    ):
        assert threshold_set.calibrated_from, "a dial with no provenance is a guess"
        assert threshold_set.liveness_scale and threshold_set.match_scale


def test_a_threshold_set_with_flag_above_pass_is_refused():
    with pytest.raises(ValueError):
        config.ThresholdSet(
            liveness_scale="x",
            match_scale="x",
            liveness_pass=70,
            liveness_flag=90,
            match_pass=90,
            match_flag=75,
            calibrated_from="broken",
        )
