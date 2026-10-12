"""The geometry and the model plumbing.

No real face photographs appear here. Rule of engagement 7 forbids committing
real people's images, and the geometric functions do not need one: `yaw_ratio`
and `map_cosine_to_100` take landmark coordinates and a scalar, so they can be
exercised exactly with constructed inputs. What CANNOT be tested without real
faces is whether YuNet finds them and whether SFace separates them — that is
spec §10's pilot, and it is listed as NOT EXECUTED in VERIFICATION_REPORT.md
rather than implied to be covered here.
"""

from __future__ import annotations

import numpy as np
import pytest

from identity import config, faces


def make_face(
    right_eye=(40.0, 50.0),
    left_eye=(80.0, 50.0),
    nose=(60.0, 70.0),
    box=(20.0, 20.0, 80.0, 90.0),
    score=0.99,
) -> faces.Face:
    """Build a YuNet-shaped 15-value row from readable parts.

    Layout, which is not documented anywhere convenient:
      0-3   x, y, w, h
      4-5   right eye     6-7   left eye      8-9   nose tip
      10-11 right mouth   12-13 left mouth    14    score
    """
    row = np.zeros(15, dtype=np.float32)
    row[0:4] = box
    row[4:6] = right_eye
    row[6:8] = left_eye
    row[8:10] = nose
    row[10:12] = (48.0, 88.0)
    row[12:14] = (72.0, 88.0)
    row[14] = score
    return faces.Face(row=row, x=box[0], y=box[1], w=box[2], h=box[3], score=score)


# ------------------------------------------------------------------- yaw


def test_a_centred_face_has_near_zero_yaw():
    # Nose on the perpendicular bisector of the eye line.
    assert abs(faces.yaw_ratio(make_face())) < 1e-6


def test_turning_one_way_gives_a_positive_yaw():
    turned = make_face(nose=(72.0, 70.0))
    assert faces.yaw_ratio(turned) > config.YAW_TURN_MIN


def test_turning_the_other_way_gives_a_negative_yaw():
    turned = make_face(nose=(48.0, 70.0))
    assert faces.yaw_ratio(turned) < -config.YAW_TURN_MIN


def test_yaw_is_invariant_to_how_close_she_holds_the_phone():
    # The same pose at twice the scale must give the same number, or the
    # threshold would mean different things at arm's length and up close.
    near = make_face(right_eye=(40, 50), left_eye=(80, 50), nose=(70, 70))
    far = make_face(right_eye=(80, 100), left_eye=(160, 100), nose=(140, 140))
    assert faces.yaw_ratio(near) == pytest.approx(faces.yaw_ratio(far), abs=1e-6)


def test_yaw_is_invariant_to_head_roll():
    # A woman lying on her side on a sofa must produce the same reading as one
    # sitting upright. Measuring along the image x-axis instead of the eye axis
    # would fail this.
    upright = make_face(right_eye=(40, 50), left_eye=(80, 50), nose=(70, 70))

    theta = np.pi / 4
    rot = np.array([[np.cos(theta), -np.sin(theta)], [np.sin(theta), np.cos(theta)]])
    centre = np.array([60.0, 60.0])

    def spin(point):
        return tuple(rot @ (np.array(point) - centre) + centre)

    rolled = make_face(
        right_eye=spin((40, 50)), left_eye=spin((80, 50)), nose=spin((70, 70))
    )
    assert faces.yaw_ratio(upright) == pytest.approx(faces.yaw_ratio(rolled), abs=1e-5)


def test_degenerate_landmarks_do_not_divide_by_zero():
    both_eyes_same = make_face(right_eye=(50, 50), left_eye=(50, 50))
    assert faces.yaw_ratio(both_eyes_same) == 0.0


# ------------------------------------------------------- the cosine mapping


def test_cosine_mapping_is_monotonic_and_bounded():
    previous = -1.0
    for cosine in np.linspace(-1.0, 1.0, 50):
        mapped = faces.map_cosine_to_100(float(cosine))
        assert 0.0 <= mapped <= 100.0
        assert mapped >= previous
        previous = mapped


def test_cosine_mapping_anchors_match_the_documented_values():
    # The table in map_cosine_to_100's docstring is load-bearing: the
    # self-hosted thresholds were chosen by reading it.
    assert faces.map_cosine_to_100(-1.0) == 0.0
    assert faces.map_cosine_to_100(1.0) == 100.0
    assert faces.map_cosine_to_100(0.0) == 50.0
    assert faces.map_cosine_to_100(0.363) == pytest.approx(68.15, abs=0.01)


def test_the_self_hosted_thresholds_sit_exactly_where_the_comments_claim():
    # config.py's derivation block says match_pass 71.0 IS cosine 0.42 and
    # match_flag 64.0 IS cosine 0.28. Exact, not approximate: both were chosen
    # partly so the mapped value would be a round number, and an edit to either
    # side that leaves the other alone turns the whole derivation into fiction.
    t = config.THRESHOLDS_SELF_HOSTED
    assert faces.map_cosine_to_100(0.42) == pytest.approx(t.match_pass, abs=1e-9)
    assert faces.map_cosine_to_100(0.28) == pytest.approx(t.match_flag, abs=1e-9)


def test_the_self_hosted_accept_bar_is_above_opencvs_published_cut():
    # OpenCV's sample uses cosine 0.363 as the same-identity cut for this exact
    # graph, and their tutorial publishes it as the BEST-ACCURACY cut on LFW —
    # the point where the genuine and impostor distributions cross on easy,
    # frontal pairs. A crossing point is not a safe accept bar for a product
    # where a false accept means a man inside a women-only community, so ours
    # sits above it, at the false-match-rate = 0.1% point instead.
    assert config.THRESHOLDS_SELF_HOSTED.match_pass > faces.map_cosine_to_100(0.363)


def test_the_self_hosted_reject_floor_is_not_above_the_hardest_published_cut():
    # The other side of the same argument, and the one that protects her rather
    # than us. Below match_flag she is refused by a machine with no human in the
    # loop. OpenCV's hardest published rows put the genuine/impostor crossing at
    # cosine 0.277 (AgeDB-30, thirty-year age gaps) and 0.212 (CFP-FP,
    # frontal-to-profile), and card-to-live is a cross-age problem: an Egyptian
    # ID photograph can be seven years old. A floor above the cross-age crossing
    # point would be rejecting women whose only failing is that their card is
    # old, so it must not drift upward.
    assert config.THRESHOLDS_SELF_HOSTED.match_flag <= faces.map_cosine_to_100(0.28)


def test_the_four_live_numbers_are_the_ones_the_derivation_argued_for():
    # A blunt pin. These four are the product's entire risk posture and they are
    # provisional, so a silent edit is the thing to make loud. If you are
    # changing them, change this test in the same commit and say why in
    # calibrated_from.
    t = config.THRESHOLDS_SELF_HOSTED
    assert (t.liveness_pass, t.liveness_flag, t.match_pass, t.match_flag) == (
        75.0,
        55.0,
        71.0,
        64.0,
    )


def test_the_live_thresholds_admit_in_the_config_that_they_are_not_measured():
    # The honesty requirement, enforced rather than trusted. Nobody reads a
    # report; the next person to touch this reads calibrated_from.
    said = config.THRESHOLDS_SELF_HOSTED.calibrated_from.upper()
    assert "PROVISIONAL" in said
    assert "NOT " in said and "MEASURED" in said


# ----------------------------------------------------------- frame difference


def test_identical_frames_have_zero_difference():
    frame = np.full((200, 200, 3), 128, dtype=np.uint8)
    assert faces.frame_difference(frame, frame) == 0.0


def test_a_resent_frame_falls_below_the_liveness_floor():
    # The laziest replay of all: the same JPEG N times.
    rng = np.random.default_rng(1)
    frame = rng.integers(0, 255, (200, 200, 3), dtype=np.uint8)
    assert faces.frame_difference(frame, frame) < config.FRAME_DIFF_MIN


def test_genuinely_different_frames_clear_the_floor():
    rng = np.random.default_rng(2)
    a = rng.integers(0, 255, (200, 200, 3), dtype=np.uint8)
    b = rng.integers(0, 255, (200, 200, 3), dtype=np.uint8)
    assert faces.frame_difference(a, b) > config.FRAME_DIFF_MIN


def test_sensor_noise_alone_does_not_count_as_movement():
    # At full resolution two frames of a still scene differ by several units of
    # noise. Downscaling to 64x64 first is what makes this a scene-change
    # measure rather than a noise measure.
    rng = np.random.default_rng(3)
    base = np.full((400, 400, 3), 100, dtype=np.uint8)
    noisy = np.clip(
        base.astype(np.int16) + rng.integers(-4, 5, base.shape), 0, 255
    ).astype(np.uint8)
    assert faces.frame_difference(base, noisy) < config.FRAME_DIFF_MIN


# ------------------------------------------------------------ image intake


def test_undecodable_bytes_are_rejected_with_a_code():
    with pytest.raises(faces.ImageRejected) as caught:
        faces.decode(b"this is not an image")
    assert caught.value.code == "image_undecodable"


def test_a_large_image_is_downscaled_to_the_working_edge():
    import cv2

    big = np.zeros((3000, 4000, 3), dtype=np.uint8)
    encoded = cv2.imencode(".jpg", big)[1].tobytes()
    decoded = faces.decode(encoded)
    assert max(decoded.shape[:2]) == config.WORKING_LONG_EDGE


def test_a_small_image_is_left_alone():
    import cv2

    small = np.zeros((300, 400, 3), dtype=np.uint8)
    encoded = cv2.imencode(".jpg", small)[1].tobytes()
    assert faces.decode(encoded).shape[:2] == (300, 400)


# -------------------------------------------------------------- the models


def test_both_model_graphs_load():
    detector, recogniser = faces._models()
    assert detector is not None and recogniser is not None


def test_the_models_are_loaded_once_and_reused():
    # The 39 MB SFace load is ~400 ms. Paying it per request would dominate the
    # compute bill.
    first = faces._models()
    second = faces._models()
    assert first[0] is second[0]
    assert first[1] is second[1]


def test_detector_returns_nothing_on_an_image_with_no_face():
    rng = np.random.default_rng(4)
    noise = rng.integers(0, 255, (480, 640, 3), dtype=np.uint8)
    assert faces.primary_face(noise) is None


def test_the_bundled_model_files_are_the_ones_the_licence_file_documents():
    # models/MODEL-LICENCES.txt records a SHA-256 for each file next to its
    # licence. If a model is swapped without updating that record, the licence
    # documentation is silently describing a different file.
    import hashlib
    import os
    import re

    models_dir = os.path.join(os.path.dirname(faces.__file__), "..", "models")
    licence_text = open(
        os.path.join(models_dir, "MODEL-LICENCES.txt"), encoding="utf-8"
    ).read()
    documented = set(re.findall(r"\b[0-9a-f]{64}\b", licence_text))

    for name in (
        "face_detection_yunet_2023mar.onnx",
        "face_recognition_sface_2021dec.onnx",
    ):
        with open(os.path.join(models_dir, name), "rb") as handle:
            digest = hashlib.sha256(handle.read()).hexdigest()
        assert digest in documented, f"{name} is not the file MODEL-LICENCES.txt records"
