"""The three seams where money and third parties enter this system.

Acceptance spec item 4. Everything that costs a cent, talks to a vendor, or
could one day be swapped for AWS sits behind one of these three interfaces:

    OcrProvider        read text off a card image
    LivenessProvider   prove a live human is in front of the camera
    FaceMatchProvider  prove that human is the one on the card

Three reasons the indirection earns its keep, beyond the spec asking for it:

  1. **The owner has not chosen a vendor.** The spec names AWS Rekognition Face
     Liveness and CompareFaces, and in the same breath records a stop-and-
     escalate: the only Flutter bridge is `face_liveness_detector` v0.2.11 with
     five likes, six months stale, no named publisher, and there is no AWS
     account. Writing the pipeline against an interface means that decision can
     be made next month without touching the decision logic.

  2. **Every paid call has a declared price.** Each provider reports its cost in
     micro-USD BEFORE it is invoked, which is what lets ledger.py refuse a call
     that would take a woman over her 50,000 µUSD budget. A provider that only
     reveals its cost by being billed cannot be governed.

  3. **Tests must never make a network call.** The mocks below are the default
     in tests, and a test that accidentally reaches Vision would be both slow
     and billed.

## A warning about threshold units, which is not a pedantic point

The spec sets `LIVENESS_PASS 90`, `LIVENESS_FLAG 70`, `MATCH_PASS 90`,
`MATCH_FLAG 75`. Those are AWS Rekognition confidence units: a percentage that
Rekognition's own calibration defines.

Our self-hosted matcher returns a cosine similarity in [-1, 1] from a different
model trained on different data. `SelfHostedFaceMatch` maps that cosine onto
0-100 so it can speak the same interface, and the mapping is documented at the
call site — but **a mapped cosine of 90 is not the same event as a Rekognition
confidence of 90.** They are different quantities that happen to share a scale.

So: the four threshold constants are per-provider, and swapping the provider
without recalibrating them is a silent, serious regression. `ProviderResult`
carries `provider_id` for exactly this reason, and the decision engine refuses
to compare a score against a threshold calibrated for a different provider.
"""

from __future__ import annotations

import abc
from dataclasses import dataclass, field
from typing import Optional, Sequence

from . import reasons

# --------------------------------------------------------------- cost units

MICRO_USD = 1
"""One millionth of a dollar. The ledger's unit.

Integers, not floats, and the reason is that a budget check written in floating
point accumulates error and eventually either refuses a call it should allow or
allows one it should refuse. Money is counted, never measured.
"""

COST_OCR_PER_IMAGE = 1_500
"""$0.0015. Cloud Vision DOCUMENT_TEXT_DETECTION, units 1,001-5,000,000 at
$1.50 per 1,000. Confirmed against Google's published pricing table on
2026-09-25. The first 1,000 units each month are free and are NOT modelled
here: budgeting for the list price and being pleasantly surprised is the right
direction to be wrong in."""

COST_LIVENESS_SESSION = 0
COST_FACE_MATCH = 0
"""Both zero. The owner has decided against AWS entirely: liveness is our own
server-side challenge response and the face match is our own SFace comparison,
so neither carries a per-call vendor charge.

The constants remain, at zero, rather than being deleted. Two reasons:
  * the ledger's arithmetic reads the same whatever a provider costs, so a
    future paid provider is a one-line change here rather than a refactor;
  * a reader comparing this file against spec §6 (which names 15,000 and 1,000)
    needs to see WHY those numbers are not here, not merely fail to find them.

Spec §6's worst case was 4 x 3,000 + 2 x 16,000 = 44,000 uUSD. It is now
4 x 3,000 + 2 x 0 = 12,000. The 50,000 ceiling is unchanged and still enforced:
it is a safety rail against a runaway loop, not a budget estimate, and it does
not get relaxed because the numbers got smaller."""

COST_FREE = 0
"""Self-hosted providers. Not literally free — they burn vCPU-seconds inside a
request we are already paying for — but they add no per-call vendor charge, and
the compute is accounted for once in the Cloud Run line of the cost model
rather than twice."""


# ------------------------------------------------------------- result types


@dataclass(frozen=True)
class ProviderResult:
    """What every provider call returns, successful or not.

    `provider_id` is not decoration. It is written into the job document and
    checked by the decision engine before any score is compared against a
    threshold, because thresholds are calibrated per provider and a silently
    swapped provider is the most plausible way this system starts making wrong
    decisions without anyone noticing.
    """

    provider_id: str
    cost_micro_usd: int
    ok: bool
    reason: Optional[str] = None
    """A reason code from reasons.py when `ok` is False. Never a sentence."""


@dataclass(frozen=True)
class OcrResult(ProviderResult):
    text: str = ""
    """The full recognised text. Held in memory for the length of one request.

    NEVER logged and never persisted. This string contains her name, her
    address, her parents' names and her national ID number: it is the single
    most sensitive value in the process after the images themselves.
    """


@dataclass(frozen=True)
class LivenessResult(ProviderResult):
    confidence: float = 0.0
    """0-100, in this provider's own units. See the warning in the module
    docstring before comparing it to anything."""

    reference_image: Optional[bytes] = None
    """The frame the liveness check itself selected as the best view of her face.

    Acceptance spec item 10: the reference image for face matching comes from
    the server-side result call, never from the client. That ordering is the
    whole point. If the client chose which frame to match against, an attacker
    would perform the liveness challenge with their own face and then hand over
    a photograph of the woman on the card, and the match would pass against an
    image that was never proven live.

    Bytes in memory. Written nowhere unless the evidence bundle is enabled, and
    it is not. See evidence.py.
    """


@dataclass(frozen=True)
class FaceMatchResult(ProviderResult):
    similarity: float = 0.0
    """0-100, in this provider's own units."""

    raw_score: Optional[float] = None
    """The provider's native score before any mapping onto 0-100 — a cosine for
    the self-hosted matcher. Carried for calibration work only, never persisted
    against a uid: a raw biometric score tied to an account is a small but real
    leak about her face, and the histogram in stats.py gives us the same
    calibration signal with no uid attached."""


# -------------------------------------------------------------- interfaces


class OcrProvider(abc.ABC):
    """Reads text off one card image."""

    provider_id: str = "abstract"
    cost_per_call: int = 0

    @abc.abstractmethod
    def read(self, image_jpeg: bytes) -> OcrResult:
        """Recognise dense printed text. Must not write the image anywhere."""


class LivenessProvider(abc.ABC):
    """Proves a live human was in front of the camera.

    The session model is fixed by acceptance spec item 10 regardless of vendor:
    `create_session` mints a single-use, uid-bound session id; `fetch_result`
    consumes it exactly once and returns both the confidence and the reference
    image the provider itself chose. A session id that has been consumed, or
    that belongs to another uid, must fail.
    """

    provider_id: str = "abstract"
    cost_per_call: int = 0

    @abc.abstractmethod
    def create_session(self, uid: str) -> str: ...

    @abc.abstractmethod
    def fetch_result(self, session_id: str, uid: str) -> LivenessResult: ...


class FaceMatchProvider(abc.ABC):
    """Compares the card portrait against the proven-live reference image."""

    provider_id: str = "abstract"
    cost_per_call: int = 0

    @abc.abstractmethod
    def compare(self, card_jpeg: bytes, reference_jpeg: bytes) -> FaceMatchResult: ...


# ------------------------------------------------------------------- mocks


@dataclass
class MockOcr(OcrProvider):
    """Scripted OCR for tests. Returns whatever text it was handed.

    The two rules below are copied deliberately from
    providers_selfhosted.VisionOcr.read and must not drift from it:

      * usability is `bool(text.strip())`, not `bool(text)`. A page of spaces is
        not text. The mock used the looser test, so a whitespace-only OCR result
        was usable here and unreadable in production — a divergence that would
        have let a test assert a parse path production never takes.
      * the cost is the full per-image price whichever way `ok` lands, because
        Vision bills per image submitted rather than per image it managed to
        read.

    tests/test_contract.py asserts both rules against the live provider rather
    than trusting this docstring.
    """

    texts: Sequence[str] = field(default_factory=list)
    provider_id: str = "mock-ocr"
    cost_per_call: int = COST_OCR_PER_IMAGE
    calls: list[bytes] = field(default_factory=list)

    def read(self, image_jpeg: bytes) -> OcrResult:
        index = len(self.calls)
        self.calls.append(image_jpeg)
        text = self.texts[index] if index < len(self.texts) else ""
        usable = bool(text.strip())
        return OcrResult(
            provider_id=self.provider_id,
            cost_micro_usd=self.cost_per_call,
            ok=usable,
            reason=None if usable else reasons.NID_UNREADABLE,
            text=text,
        )


@dataclass
class MockLiveness(LivenessProvider):
    """Scripted liveness. `confidence` and `reference_image` are whatever the
    test says they are, so the decision matrix can be exercised across the whole
    0-100 range without a vendor, a camera or a face."""

    confidence: float = 99.0
    reference_image: bytes = b"reference"
    ok: bool = True
    reason: Optional[str] = None
    provider_id: str = "mock-liveness"
    cost_per_call: int = COST_LIVENESS_SESSION
    sessions: dict[str, str] = field(default_factory=dict)
    consumed: set[str] = field(default_factory=set)

    def create_session(self, uid: str) -> str:
        session_id = f"mock-session-{len(self.sessions)}"
        self.sessions[session_id] = uid
        return session_id

    def fetch_result(self, session_id: str, uid: str) -> LivenessResult:
        # The mock enforces single-use and uid-binding too, because a test that
        # proves replay is refused is worthless if the fake it runs against
        # never enforced it in the first place.
        owner = self.sessions.get(session_id)
        if owner is None:
            return LivenessResult(self.provider_id, 0, False, reasons.SESSION_MISSING)
        if owner != uid:
            return LivenessResult(self.provider_id, 0, False, reasons.SESSION_WRONG_ACCOUNT)
        if session_id in self.consumed:
            return LivenessResult(
                self.provider_id, 0, False, reasons.SESSION_ALREADY_USED
            )
        self.consumed.add(session_id)
        return LivenessResult(
            provider_id=self.provider_id,
            cost_micro_usd=self.cost_per_call,
            ok=self.ok,
            reason=self.reason,
            confidence=self.confidence,
            reference_image=self.reference_image if self.ok else None,
        )


@dataclass
class MockFaceMatch(FaceMatchProvider):
    similarity: float = 99.0
    ok: bool = True
    reason: Optional[str] = None
    provider_id: str = "mock-facematch"
    cost_per_call: int = COST_FACE_MATCH

    def compare(self, card_jpeg: bytes, reference_jpeg: bytes) -> FaceMatchResult:
        return FaceMatchResult(
            provider_id=self.provider_id,
            cost_micro_usd=self.cost_per_call,
            ok=self.ok,
            reason=self.reason,
            similarity=self.similarity,
        )
