"""The challenge-response logic, on the parts that can be tested without a face.

`evaluate_frames` end to end needs real photographs of a real person turning
their head, which rule of engagement 7 forbids committing and spec §9.6/§9.8
covers with a live smoke test and an adversarial checklist. Those are recorded
as NOT EXECUTED in VERIFICATION_REPORT.md rather than implied to be covered
here.

What IS testable here is every decision the evaluator makes once landmarks
exist: the challenge generator, the mirror-invariant pattern matcher, and the
confidence weighting. Those are where the reasoning lives.
"""

from __future__ import annotations

import pytest

from identity import config, providers_selfhosted as sh


# ---------------------------------------------------------- the challenge


def test_a_challenge_always_starts_centred():
    # The first frame is the baseline every later frame is measured against.
    # Without a known-centred origin the yaw series has no zero.
    for _ in range(50):
        assert sh.random_challenge()[0] == "face_centre"


def test_a_challenge_has_the_configured_number_of_steps():
    assert len(sh.random_challenge()) == config.CHALLENGE_STEPS


def test_challenges_are_not_all_the_same():
    # A fixed sequence is not a challenge: an attacker who knows it can
    # pre-record it. This is a weak statistical check, not a randomness test,
    # but it would catch the sequence being accidentally hard-coded.
    seen = {sh.random_challenge() for _ in range(200)}
    assert len(seen) > 5, "the challenge is not being randomised"


def test_every_step_is_from_the_known_pool():
    for _ in range(50):
        for step in sh.random_challenge():
            assert step in sh.CHALLENGE_POOL


# ------------------------------------------------------- step satisfaction


def test_a_centred_step_needs_a_centred_head():
    assert sh._step_satisfied("face_centre", 0.0)
    assert sh._step_satisfied("face_centre", config.YAW_CENTRE_MAX)
    assert not sh._step_satisfied("face_centre", config.YAW_CENTRE_MAX + 0.01)


def test_a_turn_step_needs_a_real_turn():
    assert sh._step_satisfied("turn_left", config.YAW_TURN_MIN)
    assert not sh._step_satisfied("turn_left", config.YAW_TURN_MIN - 0.01)
    assert sh._step_satisfied("turn_right", -config.YAW_TURN_MIN)
    assert not sh._step_satisfied("turn_right", -config.YAW_TURN_MIN + 0.01)


def test_the_dead_zone_satisfies_nothing():
    # A frame between YAW_CENTRE_MAX and YAW_TURN_MIN is ambiguous, and an
    # ambiguous capture must become uncertain rather than be forced into a
    # verdict.
    middle = (config.YAW_CENTRE_MAX + config.YAW_TURN_MIN) / 2
    assert not sh._step_satisfied("face_centre", middle)
    assert not sh._step_satisfied("turn_left", middle)
    assert not sh._step_satisfied("turn_right", -middle)


def test_a_blink_step_is_judged_on_pose_like_a_centred_one():
    # A blink is captured head-on; whether the eyes closed is judged separately
    # and advisorily.
    assert sh._step_satisfied("blink", 0.0)
    assert not sh._step_satisfied("blink", config.YAW_TURN_MIN)


def test_an_unknown_step_satisfies_nothing():
    assert not sh._step_satisfied("jump", 0.0)


# ------------------------------------------------- the mirror-invariant match


TURN = config.YAW_TURN_MIN + 0.05
STEPS = ("face_centre", "turn_left", "face_centre", "turn_right")


def test_a_correct_sequence_matches():
    assert sh._pattern_matches([0.0, TURN, 0.0, -TURN], STEPS)


def test_the_mirrored_sequence_also_matches():
    # Front cameras mirror their preview, and whether the delivered frames are
    # mirrored depends on the platform and the camera API. An absolute test for
    # "turned left" would test our client's pixel conventions, not her
    # behaviour, and would fail every woman on whichever platform got it the
    # other way round.
    assert sh._pattern_matches([0.0, -TURN, 0.0, TURN], STEPS)


def test_a_wrong_ordering_does_not_match():
    # This is what the randomisation buys: a pre-recorded clip performing the
    # turns in the other order trips here.
    assert not sh._pattern_matches([0.0, TURN, -TURN, 0.0], STEPS)


def test_a_per_step_sign_flip_does_not_match():
    # The critical property. Allowing the sign to flip PER STEP would accept any
    # sequence of turns and test nothing at all; only ONE global flip is allowed,
    # which is what preserves the ordering information.
    assert not sh._pattern_matches([0.0, TURN, 0.0, TURN], STEPS)


def test_a_still_head_does_not_match_a_turn_challenge():
    # The printed photograph. It cannot turn.
    assert not sh._pattern_matches([0.0, 0.0, 0.0, 0.0], STEPS)


def test_a_challenge_of_only_centred_steps_matches_a_still_head():
    # Documented behaviour, not a bug: pose ordering is not the only gate.
    # YAW_SPREAD_MIN in evaluate_frames is what a still photograph actually
    # fails, and random_challenge never produces an all-centred challenge
    # because it draws its action steps from turn/blink only.
    assert sh._pattern_matches([0.0, 0.0], ("face_centre", "face_centre"))
    assert "face_centre" not in sh.CHALLENGE_POOL[1:]


# ----------------------------------------------------------- the confidence


def _score(**kwargs):
    base = dict(worst_pair=0.85, spread=config.YAW_SPREAD_MIN * 2, pattern_ok=True,
                blink_ok=True)
    base.update(kwargs)
    return sh._confidence(**base)


def test_an_ideal_capture_scores_at_the_top():
    assert _score() == 100.0


def test_a_perfect_capture_clears_the_pass_bar():
    assert _score() >= config.THRESHOLDS_SELF_HOSTED.liveness_pass


def test_a_pattern_failure_drops_into_the_flag_band_not_a_rejection():
    # The design consequence of being honest about a weak signal: where the
    # measurement is uncertain, widen the band and send it to a human rather
    # than rejecting on one boolean.
    score = _score(pattern_ok=False)
    t = config.THRESHOLDS_SELF_HOSTED
    assert t.liveness_flag <= score < t.liveness_pass, (
        f"a pattern failure scored {score}; it must land between "
        f"{t.liveness_flag} and {t.liveness_pass}"
    )


def test_a_missed_blink_alone_never_rejects():
    # The eye-openness proxy is weak (see faces.eye_openness) and must never be
    # the sole reason anyone is turned away.
    assert _score(blink_ok=False) >= config.THRESHOLDS_SELF_HOSTED.liveness_flag


def test_no_head_movement_at_all_scores_below_the_pass_bar():
    assert _score(spread=0.0) < config.THRESHOLDS_SELF_HOSTED.liveness_pass


def test_frames_of_different_people_score_low():
    score = _score(worst_pair=0.2, pattern_ok=False, spread=0.0, blink_ok=False)
    assert score < config.THRESHOLDS_SELF_HOSTED.liveness_flag


def test_the_score_is_bounded():
    assert 0.0 <= _score(worst_pair=5.0, spread=99.0) <= 100.0


def test_the_pose_pattern_is_weighted_above_every_other_signal():
    # It is the only signal here a printed photograph cannot fake, so it must
    # carry the most. If someone reweights these, this catches it.
    loss_from_pattern = _score() - _score(pattern_ok=False)
    loss_from_blink = _score() - _score(blink_ok=False)
    loss_from_frames = _score() - _score(worst_pair=0.5)
    assert loss_from_pattern > loss_from_blink
    assert loss_from_pattern > loss_from_frames


# --------------------------------------------------- session single-use rules


def test_frame_count_outside_the_allowed_range_fails():
    too_few = [b"x"] * (config.MIN_SELFIE_FRAMES - 1)
    result = sh.evaluate_frames(too_few, STEPS)
    assert result.ok is False


def test_a_frame_count_that_does_not_match_the_challenge_fails():
    # Four prompts, four frames. A client sending a different number has not
    # performed the challenge it was given.
    frames = [b"x"] * 5
    assert sh.evaluate_frames(frames, STEPS).ok is False
