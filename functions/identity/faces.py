"""Face detection, alignment and embedding, entirely inside this process.

Two ONNX graphs, both bundled in models/ with their licences and SHA-256s
recorded in models/MODEL-LICENCES.txt:

    YuNet  (MIT, 232 KB)        detect a face, return a box and 5 landmarks
    SFace  (Apache 2.0, 39 MB)  turn an aligned crop into a 128-D embedding

Both licences were checked against the upstream directory READMEs on
2026-09-25 and both permit commercial use. That is not a detail: the models with
the best published accuracy in this field (the InsightFace pretrained packs) are
research-only, and a paid product gating paid accounts is commercial use.

**Nothing in this module writes to disk.** Images arrive as bytes, become numpy
arrays, and are freed when the request returns. The only file this module opens
is the two model graphs, and it opens them read-only, once, at process start.

**Nothing in this module classifies anything about a person.** It detects that a
face is present, finds five landmarks, and produces a similarity between two
faces. It does not and cannot infer sex, age, ethnicity or expression, and
nothing it imports could. Rule of engagement 4 bans face-based gender
classification outright; the way to keep that promise is to not have the
capability in the process.
"""

from __future__ import annotations

import os
import threading
from dataclasses import dataclass
from typing import Optional

import cv2
import numpy as np

from . import config

_MODELS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "models")
_YUNET = os.path.join(_MODELS_DIR, "face_detection_yunet_2023mar.onnx")
_SFACE = os.path.join(_MODELS_DIR, "face_recognition_sface_2021dec.onnx")

_lock = threading.Lock()
_detector = None
_recogniser = None


def _models():
    """Load both graphs once per process, behind a lock.

    Cloud Run can dispatch concurrent requests to one instance, and OpenCV's
    DNN objects are not documented as thread-safe to construct. Loading under a
    lock costs one mutex on the cold path and removes a race that would only
    ever show up under load, which is the worst time to discover it.

    The graphs are then reused across requests. The 39 MB SFace load is roughly
    400 ms; paying it per request would dominate the compute bill.
    """
    global _detector, _recogniser
    if _detector is None or _recogniser is None:
        with _lock:
            if _detector is None:
                _detector = cv2.FaceDetectorYN.create(_YUNET, "", (320, 320))
            if _recogniser is None:
                _recogniser = cv2.FaceRecognizerSF.create(_SFACE, "")
    return _detector, _recogniser


class ImageRejected(ValueError):
    """The bytes were not a usable image. Carries a reason code."""

    def __init__(self, code: str):
        super().__init__(code)
        self.code = code


def decode(image_bytes: bytes) -> np.ndarray:
    """JPEG/PNG bytes to a BGR array, downscaled to the working resolution.

    The pixel-count check happens AFTER decode and BEFORE any processing, and it
    has to be in that order: a JPEG's byte size says nothing about how many
    pixels it holds, so a 2 MB file can decompress to gigabytes of array. That
    is a real denial-of-service against any endpoint accepting images, and the
    byte-length check in main.py does not catch it.
    """
    from . import reasons

    buffer = np.frombuffer(image_bytes, dtype=np.uint8)
    image = cv2.imdecode(buffer, cv2.IMREAD_COLOR)
    if image is None:
        raise ImageRejected(reasons.IMAGE_UNDECODABLE)
    height, width = image.shape[:2]
    if height * width > config.MAX_PIXELS:
        raise ImageRejected(reasons.IMAGE_TOO_LARGE)
    return _downscale(image)


def _downscale(image: np.ndarray) -> np.ndarray:
    """Longest edge to WORKING_LONG_EDGE, preserving aspect ratio.

    INTER_AREA, not the default INTER_LINEAR: for downscaling it averages over
    the source region instead of sampling it, which preserves the fine detail
    the detector needs in a small printed portrait. The default introduces
    aliasing that costs real detections on cards.
    """
    height, width = image.shape[:2]
    longest = max(height, width)
    if longest <= config.WORKING_LONG_EDGE:
        return image
    scale = config.WORKING_LONG_EDGE / longest
    return cv2.resize(
        image, (int(width * scale), int(height * scale)), interpolation=cv2.INTER_AREA
    )


@dataclass(frozen=True)
class Face:
    """One detected face: YuNet's raw 15-value row, plus the readable parts.

    `row` is kept intact because `FaceRecognizerSF.alignCrop` consumes it
    directly — it uses the five landmarks to warp the face to the canonical
    112x112 pose SFace was trained on. Skipping the alignment and feeding a
    plain crop costs a large amount of accuracy, silently.
    """

    row: np.ndarray
    x: float
    y: float
    w: float
    h: float
    score: float

    @property
    def right_eye(self) -> np.ndarray:
        return self.row[4:6]

    @property
    def left_eye(self) -> np.ndarray:
        return self.row[6:8]

    @property
    def nose(self) -> np.ndarray:
        return self.row[8:10]


def detect(image: np.ndarray) -> list[Face]:
    """Every face in the image above FACE_DETECT_SCORE_MIN, largest first.

    The detector's input size is set to the actual image size on every call.
    YuNet is a fixed-input graph and `setInputSize` is what rescales the
    internal anchors; forgetting it is the single most common way this model
    silently returns nothing.
    """
    detector, _ = _models()
    height, width = image.shape[:2]
    detector.setInputSize((width, height))
    _, raw = detector.detect(image)
    if raw is None:
        return []
    faces = [
        Face(row=row, x=row[0], y=row[1], w=row[2], h=row[3], score=float(row[14]))
        for row in raw
        if float(row[14]) >= config.FACE_DETECT_SCORE_MIN
    ]
    faces.sort(key=lambda f: f.w * f.h, reverse=True)
    return faces


def primary_face(image: np.ndarray) -> Optional[Face]:
    """The largest confident face, or None.

    Largest rather than highest-scoring, and the difference matters on a card:
    laminate glare and the background pattern occasionally produce a small
    high-confidence false positive, while the portrait is always the biggest
    real face in the frame.
    """
    faces = detect(image)
    return faces[0] if faces else None


def embed(image: np.ndarray, face: Face) -> np.ndarray:
    """Align, crop and embed one face into SFace's 128-D space."""
    _, recogniser = _models()
    aligned = recogniser.alignCrop(image, face.row)
    return recogniser.feature(aligned)


def cosine(a: np.ndarray, b: np.ndarray) -> float:
    """Cosine similarity between two embeddings, in [-1, 1].

    Uses the recogniser's own `match` rather than a hand-rolled dot product,
    because SFace's features are not unit-normalised on output and OpenCV's
    implementation handles that. A hand-rolled version silently returns a
    different, smaller number, which would make every threshold in config.py
    wrong by an amount nobody could see.
    """
    _, recogniser = _models()
    return float(recogniser.match(a, b, cv2.FaceRecognizerSF_FR_COSINE))


def map_cosine_to_100(score: float) -> float:
    """Map a cosine in [-1, 1] onto the 0-100 scale the providers interface uses.

    Linear, deliberately. A sigmoid or a calibrated probability would look more
    sophisticated and would be a lie: calibrating a score into a probability
    requires a labelled sample from the population you are calibrating for, and
    we have none. Spec §10's pilot is where that sample comes from.

    A linear map is honest about being a change of units and nothing more:

        cosine 0.28  ->  64.0        (self-hosted match_flag is 62)
        cosine 0.363 ->  68.2        (OpenCV's published same-identity cut)
        cosine 0.45  ->  72.5        (self-hosted match_pass is 80)
        cosine 1.00  ->  100.0

    Note that the resulting numbers are NOT comparable with Rekognition
    confidences even though they share a range. config.ThresholdSet refuses to
    let them be compared. See the warning in config.py.
    """
    return max(0.0, min(100.0, (score + 1.0) * 50.0))


def yaw_ratio(face: Face) -> float:
    """A scale- and roll-invariant proxy for head yaw, from three landmarks.

    Geometry: take the eye midpoint E and the unit vector u along the eye axis
    (right eye to left eye). Project the nose tip's offset from E onto u, and
    divide by the interocular distance.

        yaw = ((nose - E) · u) / |left_eye - right_eye|

    Facing the camera, the nose sits on the perpendicular bisector of the eye
    line and the projection is near zero. Turning the head slides the nose along
    the eye axis.

    Dividing by interocular distance makes it invariant to how close she holds
    the phone. Measuring along the eye axis rather than the image x-axis makes
    it invariant to head roll and to phone rotation — a woman lying on her side
    on a sofa produces the same numbers as one sitting upright, which a naive
    horizontal-offset version does not.

    Honest about what this is NOT: it is a geometric proxy, not a calibrated
    pose estimate in degrees. It cannot distinguish a yaw from an off-axis
    camera position, which is why the dead zone between YAW_CENTRE_MAX and
    YAW_TURN_MIN exists and why an ambiguous reading becomes uncertain instead
    of a verdict.
    """
    right, left, nose = face.right_eye, face.left_eye, face.nose
    axis = left - right
    interocular = float(np.linalg.norm(axis))
    if interocular < 1e-6:
        return 0.0
    unit = axis / interocular
    centre = (right + left) / 2.0
    return float(np.dot(nose - centre, unit) / interocular)


def eye_openness(image: np.ndarray, face: Face) -> float:
    """A weak proxy for how open the eyes are. Read the caveat.

    Method: crop a box around each eye landmark, sized relative to the
    interocular distance so it scales with the face, and measure the standard
    deviation of the greyscale patch normalised by the standard deviation of the
    whole face region. An open eye contains a dark iris against bright sclera,
    which is high local contrast. A closed eye is skin and lashes, which is not.

    **This is not an eyelid model.** YuNet gives five landmarks — two eye
    centres, a nose tip, two mouth corners — and none of them is on an eyelid,
    so the standard eye-aspect-ratio method is unavailable without bundling a
    68-point landmark model, and the well-known one of those is trained on a
    research-only dataset (see models/MODEL-LICENCES.txt).

    Consequences, stated plainly so nobody has to rediscover them:
      * spectacles, heavy eye makeup and strong side lighting all move this
        number for reasons that have nothing to do with blinking;
      * it is used only RELATIVELY, against this same woman's other frames in
        the same session, never against a fixed cut — an absolute threshold on
        eye contrast would quietly fail for whole groups of people;
      * a missed blink contributes to the uncertain band and never rejects.
    """
    grey = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    interocular = float(np.linalg.norm(face.left_eye - face.right_eye))
    if interocular < 4:
        return 0.0
    half = max(2, int(interocular * 0.18))

    def patch_std(point: np.ndarray) -> float:
        cx, cy = int(point[0]), int(point[1])
        y0, y1 = max(0, cy - half), min(grey.shape[0], cy + half)
        x0, x1 = max(0, cx - half), min(grey.shape[1], cx + half)
        region = grey[y0:y1, x0:x1]
        return float(region.std()) if region.size else 0.0

    face_y0, face_y1 = max(0, int(face.y)), min(grey.shape[0], int(face.y + face.h))
    face_x0, face_x1 = max(0, int(face.x)), min(grey.shape[1], int(face.x + face.w))
    face_region = grey[face_y0:face_y1, face_x0:face_x1]
    reference = float(face_region.std()) if face_region.size else 0.0
    if reference < 1e-6:
        return 0.0
    return (patch_std(face.right_eye) + patch_std(face.left_eye)) / (2.0 * reference)


def frame_difference(a: np.ndarray, b: np.ndarray) -> float:
    """Mean absolute difference between two frames at 64x64 greyscale, 0-255.

    Downscaling first is what makes this a measure of "did the scene change"
    rather than "is there sensor noise": at full resolution, two consecutive
    frames of a perfectly still scene differ by several units of noise on a
    phone camera, which would make the check meaningless.
    """
    small_a = cv2.resize(cv2.cvtColor(a, cv2.COLOR_BGR2GRAY), (64, 64))
    small_b = cv2.resize(cv2.cvtColor(b, cv2.COLOR_BGR2GRAY), (64, 64))
    return float(np.mean(np.abs(small_a.astype(np.int16) - small_b.astype(np.int16))))
