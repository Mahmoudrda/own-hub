"""The providers that actually run today: Vision for OCR, OpenCV for faces.

Registered as the defaults because the AWS slot is unfilled (spec §4's
stop-and-escalate: no AWS account, and the only Flutter bridge for Face Liveness
is `face_liveness_detector` v0.2.11 — five likes, six months stale, no named
publisher). See DECISIONS_NEEDED.md D1 and D2.

Cost position, which is the other half of why these exist:

    Vision DOCUMENT_TEXT_DETECTION   $0.0015 per image, x2 sides = $0.0030
    self-hosted liveness             $0
    self-hosted face match           $0
                                     -------
                                     $0.0030 per verification in vendor charges

against spec §2's projected $0.019 for the AWS path. Both are inside the $0.05
cap; the self-hosted path is inside the original brief's $0.01 target and the
AWS path is not.

The honest counterweight, and it is not small: AWS Face Liveness is a trained
passive-liveness model with a vendor behind it. What is implemented here is a
challenge-response scheme built in-house. Section "What this liveness does and
does not stop" in `SelfHostedLiveness` says exactly where the line is. This is a
cost and control trade, not a claim of equivalence.
"""

from __future__ import annotations

import secrets
from dataclasses import dataclass, field
from typing import Callable, Optional, Sequence

import numpy as np

from . import config, faces, providers, reasons

# ------------------------------------------------------------------- OCR


class VisionOcr(providers.OcrProvider):
    """Cloud Vision DOCUMENT_TEXT_DETECTION against the EU endpoint.

    DOCUMENT_TEXT_DETECTION rather than TEXT_DETECTION: the two cost the same
    and the document model is built for dense printed text on a page, which is
    what a national ID card is. TEXT_DETECTION is tuned for sparse text in
    natural scenes (a shop sign, a number plate) and reads a card noticeably
    worse, particularly the small Arabic type the النوع field is set in.

    Authentication is the function's own service account via Application Default
    Credentials. No API key: a key is a bearer credential that has to live
    somewhere, and the somewhere is always eventually a client or a repository.
    """

    provider_id = "gcp-vision-eu"
    score_scale = None  # OCR produces no score
    cost_per_call = providers.COST_OCR_PER_IMAGE

    def __init__(self, client=None):
        self._client = client

    def _get_client(self):
        if self._client is None:
            from google.cloud import vision

            # The endpoint override is the whole point of this class. Without
            # it the image goes to whatever region Google routes to, which in
            # practice means the United States — for a product that promises
            # Egyptian women their data stays in the EU.
            self._client = vision.ImageAnnotatorClient(
                client_options={"api_endpoint": config.VISION_ENDPOINT}
            )
        return self._client

    def read(self, image_jpeg: bytes) -> providers.OcrResult:
        from google.cloud import vision

        try:
            response = self._get_client().document_text_detection(
                image=vision.Image(content=image_jpeg),
                image_context=vision.ImageContext(language_hints=["ar", "en"]),
            )
        except Exception:
            # Deliberately bare. Whatever went wrong, the one thing that must
            # not happen is an exception carrying image bytes or recognised text
            # into a log or a crash report (spec §4: no image bytes in logs,
            # Crashlytics, Analytics or error payloads). Nothing from the
            # exception is propagated.
            #
            # cost_micro_usd is genuinely 0 here, unlike the empty-text branch
            # at the bottom of this method: the request never completed, so
            # Google never counted a unit. This is the ONLY OCR path that is
            # free, and spec §9.4's "a failed call gives the user a retry with
            # no charge" is about exactly this case and no other.
            return providers.OcrResult(
                provider_id=self.provider_id,
                cost_micro_usd=0,
                ok=False,
                reason=reasons.INTERNAL_ERROR,
            )

        if response.error.message:
            return providers.OcrResult(
                provider_id=self.provider_id,
                cost_micro_usd=0,
                ok=False,
                reason=reasons.INTERNAL_ERROR,
            )

        # GOOGLE HAS ALREADY BILLED US BY THIS LINE.
        #
        # Vision charges per image submitted per feature, not per useful answer.
        # A response that arrived — even one carrying no text at all, which is
        # what a blank frame or a photograph of a carpet produces — is a billed
        # unit at COST_OCR_PER_IMAGE. So `cost_micro_usd` is the full price on
        # BOTH branches below, and `ok` says only whether the text is usable.
        #
        # Those two facts used to be conflated: the empty-text branch reported
        # zero cost, the pipeline only debited the ledger when `ok` was true,
        # and the result was a loop that billed Google twice per round and
        # charged the caller's ledger nothing, for ever. Neither the 50,000 µUSD
        # cap nor the 4-submission limit could ever fire against it, because
        # neither counter moved. providers.MockOcr has always reported the cost
        # unconditionally, which is the correct rule, so every test in the suite
        # was exercising a provider that behaved differently from this one.
        text = response.full_text_annotation.text or ""
        return providers.OcrResult(
            provider_id=self.provider_id,
            cost_micro_usd=self.cost_per_call,
            ok=bool(text.strip()),
            reason=None if text.strip() else reasons.NID_UNREADABLE,
            text=text,
        )


# -------------------------------------------------------------- liveness

CHALLENGE_POOL = ("face_centre", "turn_left", "turn_right", "blink")


def random_challenge(steps: int = config.CHALLENGE_STEPS) -> tuple[str, ...]:
    """A randomised ordered challenge, server-chosen.

    Always opens with `face_centre`: the first frame is the baseline every
    later frame is measured against, and without a known-centred reference the
    yaw series has no origin.

    `secrets` rather than `random`, because a predictable challenge is no
    challenge at all — an attacker who can predict the sequence can pre-record
    it, which is the entire threat this is meant to address.
    """
    rest = list(CHALLENGE_POOL[1:])
    chosen = ["face_centre"]
    for _ in range(max(0, steps - 1)):
        chosen.append(rest[secrets.randbelow(len(rest))])
    return tuple(chosen)


@dataclass
class ChallengeStore:
    """Where a minted challenge lives between the two callables.

    An interface rather than a Firestore call so the liveness logic is testable
    without an emulator. FirestoreChallengeStore in store.py is the real one.
    """

    put: Callable[[str, dict], None]
    take: Callable[[str], Optional[dict]]
    """`take` must be atomic: read and mark-consumed in one transaction.

    Spec §5 requires a sessionId to be single-use. A read followed by a separate
    write is a race, and the race is exploitable — two concurrent requests with
    the same session id both read "unused" and both proceed.
    """


@dataclass
class SelfHostedLiveness(providers.LivenessProvider):
    """Challenge-response liveness from the selfie frames, server-side.

    ## How it decides

    The client is handed an ordered, server-randomised challenge and captures
    one frame per step. The server then checks, across those frames:

      1. **A face is present in every frame.** Missing faces route to the
         woman-reviewer path, not to a rejection: the most likely cause in this
         product is a face covering, and a niqab is not a failure state.
      2. **It is the same face in every frame.** Every frame is embedded and
         compared pairwise; below FACE_INTRA_SESSION_MIN_COSINE something
         swapped mid-capture.
      3. **The frames are not near-identical.** Catches the same JPEG submitted
         N times.
      4. **The head actually moved.** YAW_SPREAD_MIN across the sequence. This
         is the line a printed photograph cannot cross.
      5. **The movement follows the order demanded.** Under a single global sign
         flip, see `_pattern_matches` for why.

    ## What this liveness does and does not stop

    Stated plainly, because a security control nobody understands the limits of
    is worse than none.

    STOPS:
      * a printed photograph held to the camera — it cannot turn its head;
      * a single still image on a phone screen, for the same reason;
      * the same frame submitted repeatedly;
      * a mid-capture swap between the card's portrait and a live face;
      * a generic pre-recorded "turn your head" clip, because it will not match
        a randomly ordered challenge — see the entropy note below.

    DOES NOT STOP:
      * **a video replay by someone who fetched the challenge first.** The
        challenge is issued before capture. An attacker with a screen and a
        clip library can read the demanded sequence and play the matching
        motions. Randomisation raises the cost of preparation; it does not
        defeat a prepared attacker.
      * **a live person puppeteering in front of the camera** who simply
        performs the challenge. Only the face match stands between them and an
        account, and the face match is the weaker of the two against a good
        impostor.
      * **a 3D mask, or a deepfake driven in real time.** There is no texture
        analysis, no depth, no reflectance model, no moiré detection here. A
        commercial passive-liveness model has all of those.
      * **a screen replay detected by artefacts.** No moiré or screen-edge
        detection is implemented, and a half-working one would be worse than
        none because it would create false confidence.

    Entropy of the randomisation: three action steps drawn with replacement from
    three kinds is 27 orderings, halved to about 13 distinguishable ones by the
    mirror ambiguity below. That is roughly a 1-in-13 chance of a blind guess
    landing. It is a speed bump, not a lock, and spec §9.8's adversarial
    checklist has "a video of a woman replayed on a phone screen" as an explicit
    pass/fail item precisely because this is where it will be tested.

    The design consequence: the uncertain band must be wide and must fall
    through to a human. It is, and it does.
    """

    provider_id: str = "selfhosted-challenge-liveness"
    score_scale: str = config.SCALE_SELFHOSTED_LIVENESS
    """SCALE_SELFHOSTED_LIVENESS, not SCALE_SFACE_COSINE_MAPPED, and the
    difference was a live defect rather than a nicety.

    This class used to declare the cosine scale. `pipeline.run` reads
    `score_scale` off the provider and hands it to `ThresholdSet.for_providers`,
    which compares it against `THRESHOLDS_SELF_HOSTED.liveness_scale` — and that
    has always been SCALE_SELFHOSTED_LIVENESS. So every real verification that
    reached step 8 would have raised ThresholdScaleMismatch and failed, while
    the unit tests stayed green because they build their own Signals with
    matching scales. tests/test_decisions.py even asserted that this exact
    mismatch must raise, so the guard was working perfectly and the wiring was
    pointing it at ourselves.

    What `_confidence` returns is a weighted sum of a pose-pattern boolean, a
    yaw spread and a frame-consistency term. It is not a cosine and it is not a
    cosine put through a linear map, so the cosine label was wrong on the merits
    as well as wrong in its effect. tests/test_liveness.py now asserts that the
    live providers agree with ACTIVE_THRESHOLDS, which is the assertion that was
    missing."""
    cost_per_call: int = providers.COST_FREE
    store: Optional[ChallengeStore] = None
    _frames: dict[str, Sequence[bytes]] = field(default_factory=dict)

    def create_session(self, uid: str) -> str:
        session_id = secrets.token_urlsafe(24)
        if self.store is not None:
            self.store.put(
                session_id,
                {"uid": uid, "steps": list(random_challenge()), "consumed": False},
            )
        return session_id

    def submit_frames(self, session_id: str, frames: Sequence[bytes]) -> None:
        """Frames arrive with the verify call, not with the session.

        They are held in this process's memory for the length of one request
        and are never written anywhere. The dict is keyed by session id and
        cleared in `fetch_result`.
        """
        self._frames[session_id] = frames

    def fetch_result(self, session_id: str, uid: str) -> providers.LivenessResult:
        if self.store is None:
            return self._fail(reasons.SESSION_MISSING)

        record = self.store.take(session_id)
        if record is None:
            return self._fail(reasons.SESSION_MISSING)
        if record.get("uid") != uid:
            # Spec §5: replaying a successful session from another uid must
            # fail. This is the check that enforces it.
            return self._fail(reasons.SESSION_WRONG_ACCOUNT)
        if record.get("consumed"):
            return self._fail(reasons.SESSION_ALREADY_USED)
        if record.get("expired"):
            return self._fail(reasons.SESSION_EXPIRED)

        frames = self._frames.pop(session_id, None)
        if not frames:
            return self._fail(reasons.SESSION_MISSING)

        steps = tuple(record.get("steps") or ())
        return evaluate_frames(frames, steps, self.provider_id, self.score_scale)

    def _fail(self, code: str) -> providers.LivenessResult:
        return providers.LivenessResult(
            provider_id=self.provider_id, cost_micro_usd=0, ok=False, reason=code
        )


def evaluate_frames(
    frames: Sequence[bytes],
    steps: Sequence[str],
    provider_id: str = "selfhosted-challenge-liveness",
    score_scale: str = config.SCALE_SELFHOSTED_LIVENESS,
) -> providers.LivenessResult:
    """The liveness decision itself, factored out so it is testable directly.

    Returns a confidence on the 0-100 scale `score_scale` names — which is NOT
    a Rekognition confidence. See config.ThresholdSet.
    """
    if not (config.MIN_SELFIE_FRAMES <= len(frames) <= config.MAX_SELFIE_FRAMES):
        return providers.LivenessResult(
            provider_id, 0, False, reasons.LIVENESS_FAILED
        )
    if steps and len(frames) != len(steps):
        return providers.LivenessResult(
            provider_id, 0, False, reasons.LIVENESS_FAILED
        )

    images = []
    for raw in frames:
        try:
            images.append(faces.decode(raw))
        except faces.ImageRejected as rejected:
            return providers.LivenessResult(provider_id, 0, False, rejected.code)

    detected = [faces.primary_face(image) for image in images]
    if any(face is None for face in detected):
        # Routes to the woman-reviewer path. A niqab is not a failure state.
        return providers.LivenessResult(
            provider_id, 0, False, reasons.FACE_NOT_FOUND_IN_REFERENCE
        )

    # 2. The same face throughout.
    embeddings = [faces.embed(img, face) for img, face in zip(images, detected)]
    worst_pair = min(
        faces.cosine(embeddings[i], embeddings[j])
        for i in range(len(embeddings))
        for j in range(i + 1, len(embeddings))
    )
    if worst_pair < config.FACE_INTRA_SESSION_MIN_COSINE:
        return providers.LivenessResult(
            provider_id, 0, False, reasons.FACE_FRAMES_DISAGREE
        )

    # 3. Not the same picture N times.
    smallest_change = min(
        faces.frame_difference(images[i], images[i + 1])
        for i in range(len(images) - 1)
    )
    if smallest_change < config.FRAME_DIFF_MIN:
        return providers.LivenessResult(
            provider_id, 0, False, reasons.LIVENESS_FAILED
        )

    # 4. The head moved.
    yaws = [faces.yaw_ratio(face) for face in detected]
    spread = max(yaws) - min(yaws)
    if spread < config.YAW_SPREAD_MIN:
        return providers.LivenessResult(
            provider_id, 0, False, reasons.LIVENESS_FAILED
        )

    # 5. It moved in the order demanded.
    pattern_ok = _pattern_matches(yaws, steps) if steps else True

    # 6. The blink, advisory only.
    blink_ok = _blink_seen(images, detected, steps) if steps else True

    confidence = _confidence(
        worst_pair=worst_pair,
        spread=spread,
        pattern_ok=pattern_ok,
        blink_ok=blink_ok,
    )
    return providers.LivenessResult(
        provider_id=provider_id,
        cost_micro_usd=providers.COST_FREE,
        ok=True,
        confidence=confidence,
        reference_image=frames[_best_frame(detected)],
    )


def _best_frame(detected: Sequence[faces.Face]) -> int:
    """Which frame becomes the reference image for face matching.

    The most front-on one, by smallest |yaw|, because a three-quarter view
    matches a passport-style card portrait worse than a frontal one does.

    Spec §5 and §10 both insist the reference comes from the server side, never
    the client. This function is that rule: the client sends frames, the SERVER
    picks which one is evidence. If the client chose, an attacker could perform
    the challenge with their own face and nominate a photograph of the woman on
    the card, and the match would pass against an image never proven live.
    """
    return min(range(len(detected)), key=lambda i: abs(faces.yaw_ratio(detected[i])))


def _pattern_matches(yaws: Sequence[float], steps: Sequence[str]) -> bool:
    """Does the yaw series follow the demanded sequence?

    **The mirror problem, and why this accepts either sign.** Front cameras
    mirror their preview, and whether the delivered frames are mirrored depends
    on the platform, the camera API and whether the app un-mirrored them. So an
    absolute test for "turned left" is not a test of her behaviour, it is a test
    of our client's pixel conventions — and it would fail for every woman on
    whichever platform got it the other way round.

    The fix is to accept the series under a SINGLE GLOBAL sign flip: either
    every turn matches the demanded direction, or every turn matches its
    opposite. A per-step flip would accept anything and test nothing; one global
    flip preserves the ordering information, which is what the randomisation is
    for. The cost is a factor of two in entropy, which is recorded in the class
    docstring rather than hidden.
    """
    for sign in (1.0, -1.0):
        if all(
            _step_satisfied(step, sign * yaw) for step, yaw in zip(steps, yaws)
        ):
            return True
    return False


def _step_satisfied(step: str, yaw: float) -> bool:
    if step in ("face_centre", "blink"):
        # A blink is captured head-on, so the pose requirement for a blink step
        # is the same as for a centred one. Whether the eyes actually closed is
        # judged separately and advisorily.
        return abs(yaw) <= config.YAW_CENTRE_MAX
    if step == "turn_left":
        return yaw >= config.YAW_TURN_MIN
    if step == "turn_right":
        return yaw <= -config.YAW_TURN_MIN
    return False


def _blink_seen(
    images: Sequence[np.ndarray], detected: Sequence[faces.Face], steps: Sequence[str]
) -> bool:
    """Advisory. See faces.eye_openness for why this is weak on purpose.

    Compares each blink frame against the median openness of the NON-blink
    frames from the same session. Every woman is measured against herself, so
    skin tone, eye shape, spectacles and room lighting cancel out instead of
    becoming a hidden bias in a fixed threshold.
    """
    blink_indices = [i for i, step in enumerate(steps) if step == "blink"]
    if not blink_indices:
        return True
    others = [
        faces.eye_openness(images[i], detected[i])
        for i in range(len(images))
        if i not in blink_indices
    ]
    if not others:
        return True
    baseline = float(np.median(others))
    if baseline <= 1e-6:
        return True
    return all(
        faces.eye_openness(images[i], detected[i]) <= baseline * (1 - config.BLINK_DROP_MIN)
        for i in blink_indices
    )


def _confidence(
    *, worst_pair: float, spread: float, pattern_ok: bool, blink_ok: bool
) -> float:
    """Combine the signals into one 0-100 number.

    Weighted rather than all-or-nothing, so that a capture which is clearly the
    same live person but whose pose ordering was ambiguous lands in the flag
    band and reaches a human, instead of being rejected by a single boolean.
    That is the design consequence of the honesty in the class docstring: where
    the signal is weak, widen the uncertain band rather than pretending.

    Weights: the pose pattern carries the most, because it is the only signal
    here a printed photograph cannot fake. Frame consistency is next. The blink
    carries least, because it is the least trustworthy measurement.
    """
    score = 0.0
    score += 45.0 if pattern_ok else 12.0
    score += 30.0 * min(1.0, spread / (config.YAW_SPREAD_MIN * 2.0))
    score += 15.0 * min(1.0, max(0.0, (worst_pair - 0.5) / 0.35))
    score += 10.0 if blink_ok else 0.0
    return round(min(100.0, score), 2)


# ------------------------------------------------------------- face match


@dataclass
class SelfHostedFaceMatch(providers.FaceMatchProvider):
    """1:1 comparison of the card portrait against the liveness reference.

    Server side, always, and that is not a preference. A client that computes
    its own match can simply send `{"match": true}`: the phone is only ever a
    camera. Spec rule of engagement 3 says the same thing in general terms; this
    is where it is actually enforced.
    """

    provider_id: str = "selfhosted-sface"
    score_scale: str = config.SCALE_SFACE_COSINE_MAPPED
    cost_per_call: int = providers.COST_FREE

    def compare(
        self, card_jpeg: bytes, reference_jpeg: bytes
    ) -> providers.FaceMatchResult:
        try:
            card = faces.decode(card_jpeg)
            reference = faces.decode(reference_jpeg)
        except faces.ImageRejected as rejected:
            return providers.FaceMatchResult(
                self.provider_id, 0, False, rejected.code
            )

        card_face = faces.primary_face(card)
        if card_face is None:
            # Spec §2 step 7: no face on the card is RETRY_CAPTURE. Glare, a
            # thumb over the portrait, the back photographed twice.
            return providers.FaceMatchResult(
                self.provider_id, 0, False, reasons.FACE_NOT_FOUND_ON_CARD
            )
        if card_face.w < config.FACE_MIN_CARD_PORTRAIT_PX:
            # Too few pixels for an embedding to mean anything. Forcing one
            # produces a confident-looking number built from noise, which is
            # worse than admitting the scan was poor.
            return providers.FaceMatchResult(
                self.provider_id, 0, False, reasons.FACE_TOO_SMALL_ON_CARD
            )

        reference_face = faces.primary_face(reference)
        if reference_face is None:
            return providers.FaceMatchResult(
                self.provider_id, 0, False, reasons.FACE_NOT_FOUND_IN_REFERENCE
            )

        raw = faces.cosine(
            faces.embed(card, card_face), faces.embed(reference, reference_face)
        )
        return providers.FaceMatchResult(
            provider_id=self.provider_id,
            cost_micro_usd=providers.COST_FREE,
            ok=True,
            similarity=faces.map_cosine_to_100(raw),
            raw_score=raw,
        )
