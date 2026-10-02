"""Server-side configuration. Spec §3: never Remote Config, never client code.

Two kinds of thing live here.

**Constants** are compiled in. They are the ones whose value is an engineering
fact (a payload ceiling, a working resolution) rather than a policy dial.

**ThresholdSet** is the policy dial, and it carries the single most important
safety property in this file: *a threshold set knows which provider's score
scale it was calibrated for, and refuses to be used against any other.*

Why that matters more than it looks
-----------------------------------
Spec §3 starts the dials at LIVENESS_PASS 90, LIVENESS_FLAG 70, MATCH_PASS 90,
MATCH_FLAG 75. Those are AWS Rekognition confidence units — a percentage whose
meaning is defined by Rekognition's own calibration.

Our self-hosted matcher returns a cosine similarity in [-1, 1] from a different
model trained on different data. It can be mapped onto 0-100 so it satisfies the
same interface, and it is. But **a mapped cosine of 90 is not the same event as
a Rekognition confidence of 90.** They are different quantities that happen to
share a range.

If someone swaps the provider and keeps the numbers, nothing crashes, no test
goes red, and the system quietly starts admitting people it should not. Spec §10
ranks a false accept above every other failure mode, and a silent unit mismatch
is the most likely way to produce one. So the scale is part of the type:
`ThresholdSet` carries a `liveness_scale` and a `match_scale`, each must equal
the corresponding provider's `score_scale`, and `for_providers` raises rather
than returning a plausible answer. See tests/test_decisions.py.

There are THREE scales, not two, because our own liveness score and our own
match score are not the same quantity either. A test caught this very file
claiming match_pass 80 was "cosine ~0.45" when the mapping puts 0.45 at 72.5 —
which is the bug this machinery exists to catch, found in the machinery's own
configuration.

Recorded in RESIDUAL_RISKS.md under "threshold drift".
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

# ---------------------------------------------------------------- deployment

REGION = "europe-west3"
"""Frankfurt. Everything about her is already there: the `(default)` Firestore
database and the `own-hub-personal` Storage bucket. Anywhere else adds a
cross-region hop to every Firestore call in the request path and puts the
compute that touches her ID in a different jurisdiction from the data it
writes."""

VISION_ENDPOINT = "eu-vision.googleapis.com"
"""Cloud Vision's EU-only endpoint.

The default `vision.googleapis.com` routes to whatever region Google chooses,
which in practice means the image crosses the Atlantic. `eu-vision` is Google's
documented commitment to process nothing outside the EU for the duration of the
call. This is the difference between a privacy page that can say "processed in
the EU" and one that has to say "processed in the United States" to Egyptian
women who were promised otherwise. Spec §11 requires the processing regions to
be documented; this is the Vision half of that."""

MEMORY_MIB = 1024
TIMEOUT_SEC = 120
MAX_INSTANCES = 20
"""A cost ceiling, not a capacity plan. 50,000 verifications over six months is
about 12 an hour. Twenty concurrent instances is far above any honest peak and
exists so a runaway loop cannot turn an unbounded bill into the story of the
quarter."""

ENFORCE_APP_CHECK = True
"""Spec §5: App Check enforced on every callable in the flow.

Safe to turn on now, and that is worth stating because the usual reason this
gets left off is fear of breaking a live client: there is no live client. The
Flutter app contains zero `httpsCallable` calls today, so nothing can break.
Turning it on before any client code is written means no one ever has to do the
risky version of this change.

Debug providers are a client-side concern (spec §5: dev builds only) and cannot
be configured from here.
"""

# ------------------------------------------------------------ request limits

MAX_IMAGE_BYTES = 8 * 1024 * 1024
MAX_TOTAL_BYTES = 24 * 1024 * 1024
"""Checked on base64 length BEFORE decoding. A decompression bomb is a real
attack against any endpoint that takes an image: a 2 MB JPEG can expand to
gigabytes of pixels and kill the instance. Pixel dimensions are re-checked after
decode in faces.py, because a JPEG's byte size says nothing about how many
pixels it holds."""

MAX_PIXELS = 40_000_000
WORKING_LONG_EDGE = 1024
"""Every image is downscaled to this on its longest edge before detection.

Face recognition gains nothing from a 4000-pixel selfie — SFace consumes a
112x112 aligned crop either way — and detection time scales with pixel count.
1024 keeps a card's printed portrait (typically 300-500 px wide in a phone photo)
well above the detector's useful floor while cutting detection time by about an
order of magnitude against a raw 12 MP frame. The biggest single lever on the
compute line of the cost model."""

# ---------------------------------------------------------------- ID parsing

MIN_AGE = 18
"""Spec §1. Derived from the birth date encoded in digits 2-7. Outcome
`REJECTED_NOT_ELIGIBLE`."""

MAX_AGE_PLAUSIBLE = 110
"""A birth date implying a 130-year-old is an OCR failure, not a
supercentenarian. Caught as a bad read (`RETRY_CAPTURE`), never as a
rejection."""

# ------------------------------------------------------- score scales

SCALE_REKOGNITION = "rekognition-confidence-0-100"
"""AWS Rekognition confidence percentages, as spec §3's starting values assume."""

SCALE_SFACE_COSINE_MAPPED = "sface-cosine-mapped-0-100"
"""A SFace cosine similarity in [-1, 1] mapped affinely onto 0-100. See
`faces.map_cosine_to_100` for the exact mapping and why it is linear rather
than something cleverer."""

SCALE_SELFHOSTED_LIVENESS = "selfhosted-challenge-composite-0-100"
"""The weighted composite in `providers_selfhosted._confidence`.

A THIRD scale, and it needs to be one. It is tempting to say "liveness and match
both come from our own code, so one label covers both" — that is exactly the
mistake this machinery exists to prevent. The match score is a cosine put
through a linear map; the liveness score is a weighted sum of a pose-pattern
boolean, a yaw spread and a frame-consistency term. They share a range and
nothing else, and a threshold tuned on one is meaningless against the other.

A test caught this file claiming match_pass 80 was "cosine ~0.45" when the
mapping puts 0.45 at 72.5. The numbers below are the corrected ones.
"""


@dataclass(frozen=True)
class ThresholdSet:
    """The four dials from spec §3, plus the scale EACH PAIR was calibrated on.

    Two scale fields, not one. Liveness and match are separate measurements from
    separate providers and their numbers are not interchangeable even when both
    providers are ours. `for_providers` refuses to hand these numbers to a
    provider that speaks a different scale, which is the mechanism that makes a
    silent unit mismatch impossible rather than merely discouraged.
    """

    liveness_scale: str
    match_scale: str
    liveness_pass: float
    liveness_flag: float
    match_pass: float
    match_flag: float
    calibrated_from: str
    """Where these numbers came from, in words. "spec §3 starting values,
    NOT tuned" is an honest value and is the current one."""

    def __post_init__(self) -> None:
        if not self.liveness_flag <= self.liveness_pass:
            raise ValueError("liveness_flag must not exceed liveness_pass")
        if not self.match_flag <= self.match_pass:
            raise ValueError("match_flag must not exceed match_pass")

    def for_providers(
        self, liveness_scale: Optional[str], match_scale: Optional[str]
    ) -> "ThresholdSet":
        """Assert this set belongs to these providers, then return it.

        Called on every decision. The cost is two string comparisons; the thing
        it buys is that swapping a provider without recalibrating raises a loud
        error at the first request instead of producing false accepts nobody
        notices for a month.

        A `None` scale means that stage did not run and has nothing to check —
        the male early exit reaches a decision with no liveness score at all.
        """
        for given, expected, what in (
            (liveness_scale, self.liveness_scale, "liveness"),
            (match_scale, self.match_scale, "match"),
        ):
            if given is not None and given != expected:
                raise ThresholdScaleMismatch(
                    f"{what} thresholds are calibrated for {expected!r} and "
                    f"cannot judge a score from a provider reporting {given!r}. "
                    f"Spec §10 ranks a false accept above every other failure, "
                    f"and carrying thresholds across score scales is the most "
                    f"likely way to cause one. Calibrate a new ThresholdSet "
                    f"from pilot data (spec §10) instead of reusing this one."
                )
        return self


class ThresholdScaleMismatch(RuntimeError):
    """Raised when a score is about to be judged on the wrong scale."""


THRESHOLDS_REKOGNITION = ThresholdSet(
    liveness_scale=SCALE_REKOGNITION,
    match_scale=SCALE_REKOGNITION,
    liveness_pass=90.0,
    liveness_flag=70.0,
    match_pass=90.0,
    match_flag=75.0,
    calibrated_from=(
        "spec §3's starting values, in AWS Rekognition confidence units, for a "
        "provider THIS PROJECT WILL NEVER CALL. The owner has decided against "
        "AWS entirely. Kept only so that the scale guard has a second scale to "
        "refuse, and so a reader comparing against spec §3 can see where those "
        "four numbers went. Never make this ACTIVE_THRESHOLDS."
    ),
)

# ------------------------------------------ where the four numbers came from
#
# READ THIS BEFORE CHANGING ANY OF THE FOUR. They are not arbitrary and they are
# not measured either. Each one is a published number, or arithmetic over
# published numbers, and the arithmetic is written out here so the next person
# can check it rather than take it on trust.
#
# THE PUBLISHED SOURCES (fetched 25 September 2026)
#
#   [1] opencv_zoo, models/face_recognition_sface/sface.py, the reference
#       implementation for THIS EXACT ONNX graph:
#           self._threshold_cosine = 0.363
#           self._threshold_norml2 = 1.128
#           return cosine_score, 1 if cosine_score >= self._threshold_cosine else 0
#
#   [2] OpenCV's own DNN face tutorial (doc/tutorials/dnn/dnn_face) publishes
#       the accuracy and the BEST-ACCURACY cosine cut per benchmark:
#           LFW       99.60%   cosine 0.363
#           CALFW     93.95%   cosine 0.340
#           AgeDB-30  94.90%   cosine 0.277
#           CPLFW     91.05%   cosine 0.275
#           CFP-FP    94.80%   cosine 0.212
#
#   [3] DocFace+ (arXiv:1809.05620), on matching ID-document photos to selfies:
#       a publicly available general face matcher (SphereFace) reaches a true
#       accept rate of only 59.29% +/- 1.55 at a false accept rate of 0.1%,
#       against 97.51% +/- 0.40 for a matcher trained on ID-selfie pairs.
#
# WHAT [2] SETTLES, AND IT IS THE OPPOSITE OF THE OBVIOUS INTUITION
#
# The previous value of match_pass was 72.5 (cosine 0.45), reasoned as: card
# photograph to live face is harder than the photo pairs 0.363 was calibrated
# on, so raise the bar. The first half is true. The second half does not follow,
# and [2] is the counter-example: as the pairs get harder the published best cut
# FALLS (0.363 on frontal LFW, 0.277 on thirty-year age gaps, 0.212 on
# frontal-to-profile). Difficulty moves the GENUINE distribution down; it does
# not move the impostor distribution up. Raising the accept bar because the
# domain is hard buys a little against false accepts and pays for it with a very
# large number of genuine women pushed into the uncertain band, which in this
# product is a video call with a woman reviewer. See REVIEW_ROUTES below and
# RESIDUAL_RISKS.md #7.
#
# HOW match_pass = cosine 0.42 WAS PICKED
#
# The accept bar is the only automated thing standing between a man holding a
# woman's card and an account, so it is set by the IMPOSTOR tail and by nothing
# else. Model different identities as cosine ~ Normal(0, s), mean zero because
# two unrelated embeddings are near-orthogonal, and solve s from [2]'s LFW row:
# 99.60% accuracy over an equal split of genuine and impostor pairs is a 0.40%
# false match rate at cosine 0.363, so s = 0.363 / 2.652 = 0.137.
#
#   cosine   mapped   false match rate at that cut
#   0.363     68.15   0.401%
#   0.400     70.00   0.174%
#   0.420     71.00   0.108%      <- chosen
#   0.450     72.50   0.051%
#
# 0.42 is the false-match-rate = 0.1% operating point. That is deliberately the
# same operating point [3] reports its numbers at, so this bar is comparable to
# a published figure instead of being invented.
#
# Turned into people: at 50,000 sign-ups, assume pessimistically that 1% of them
# (500) are men attempting a borrowed card, and that each gets both of his
# MAX_LIVENESS_ATTEMPTS. 500 x 2 x 0.108% = 1.1 expected admissions across the
# whole launch. At 0.363 the same arithmetic gives 4.0, which is four men inside
# a women-only community and is not acceptable. At 0.45 it gives 0.5, half a man
# better than 0.42, bought at roughly 4,000 additional video calls under the
# middle genuine-score assumption in VERIFICATION_REPORT.md. Spec section 10
# says that when the goals conflict, choose fewer false accepts and report the
# trade-off; 0.42 is where the two curves stop being worth crossing.
#
# HOW match_flag = cosine 0.28 WAS PICKED
#
# Below this, once her attempts are used, she is rejected by a machine with no
# human in the loop. That is the harshest thing this system does, so the floor
# has to sit where published evidence makes a rejection defensible. 0.277 is
# [2]'s best-accuracy cut on AgeDB-30, the hardest cross-age row in the table,
# and card-to-live is at heart a cross-age problem: an Egyptian ID photograph
# can be seven years old. At a best-accuracy cut the two distributions cross, so
# below it a score is at least as likely to have come from a different person as
# from the same one. Rounded to 0.28 so the mapped value is exactly 64.0. The
# previous worker put the floor in the same place; this is a better reason for
# it, not a different number.
#
# HOW THE TWO LIVENESS NUMBERS WERE PICKED
#
# There is NO published benchmark for the composite in
# providers_selfhosted._confidence, because we wrote it. No source found, and
# none will be: it is a weighted sum of a pose-pattern boolean, a yaw spread and
# a frame-consistency term. So these two are arithmetic over that function's own
# weights, which at least is checkable:
#
#   pattern_ok=False ceiling    12 + 30   + 15   + 10 = 67
#   pattern_ok=True  floor      45 + 15   +  0   +  0 = 60
#       (a spread below YAW_SPREAD_MIN and a worst_pair below
#        FACE_INTRA_SESSION_MIN_COSINE both hard-fail before any score is
#        produced, so those two terms cannot contribute less than 15 and 0)
#   pattern_ok, real turn, consistent frames, NO detected blink
#                               45 + 30   + 15   +  0 = 90
#   pattern_ok, modest turn (yaw spread 0.33), typical consistency (0.75),
#   no detected blink           45 + 22.5 + 10.7 +  0 = 78.2
#
# liveness_pass = 75 because that last line is a woman who did exactly what she
# was asked and whose only failing is our own blink proxy, which
# faces.eye_openness documents as weak and which _confidence weights at 10 for
# precisely that reason. At the previous 82 she scored 78.2 and got a video
# call. At 75 she is approved, and nothing that matters is given away: 75 > 67,
# so the pose pattern must still have matched for anyone to pass, and all four
# hard checks (a face in every frame, the same face throughout, frames that
# actually differ, a head that actually turned) still gate before a score is
# produced at all.
#
# liveness_flag = 55 because a pattern_ok capture cannot score below 60, so 55
# guarantees that a liveness REJECTION is only ever handed to a capture whose
# pose ordering failed, and never to a woman who followed the challenge. The
# five points of headroom below 60 are there so that guarantee does not depend
# on float equality at the exact minimum.

THRESHOLDS_SELF_HOSTED = ThresholdSet(
    liveness_scale=SCALE_SELFHOSTED_LIVENESS,
    match_scale=SCALE_SFACE_COSINE_MAPPED,
    liveness_pass=75.0,
    liveness_flag=55.0,
    match_pass=71.0,
    match_flag=64.0,
    calibrated_from=(
        "PROVISIONAL. Chosen from published benchmarks and arithmetic, and NOT "
        "MEASURED on Egyptian ID cards photographed on Egyptian phones. No "
        "false-accept rate, false-reject rate or flag rate has been observed "
        "for any of these four numbers on this product's real population. "
        "Match: match_pass 71.0 IS cosine 0.42, the false-match-rate = 0.1% "
        "point of an impostor model solved from OpenCV's published LFW figure "
        "for this exact graph (99.60% at cosine 0.363); match_flag 64.0 IS "
        "cosine 0.28, OpenCV's published best-accuracy cut on AgeDB-30 (0.277), "
        "the hardest cross-age row they publish. Tests assert both mappings "
        "rather than trusting this sentence. Liveness: no published benchmark "
        "exists for our own composite, so 75 and 55 are arithmetic over "
        "providers_selfhosted._confidence's own weights: 75 sits above the 67 a "
        "pattern failure can reach and below the 78.2 a compliant woman reaches "
        "without a detected blink, and 55 sits below the 60 a pattern-matched "
        "capture can reach. The derivation block above this line shows the "
        "working. Spec section 10's pilot must replace all four before "
        "production, and VERIFICATION_REPORT.md records the flag rate each one "
        "implies."
    ),
)
"""The numbers the self-hosted path runs on today, and the honest label on them.

They are not spec section 3's numbers, and they must not be: see the module
docstring. They are also not measured. `calibrated_from` says so in the
configuration itself rather than in a document nobody reads, because the next
person to touch this file is the person who needs to know."""

ACTIVE_THRESHOLDS = THRESHOLDS_SELF_HOSTED
"""Which set is live. Changes with the provider, never independently of it."""

# ------------------------------------------------------- liveness geometry
# Self-hosted only. Unused when a vendor liveness provider is active.

MIN_SELFIE_FRAMES = 3
MAX_SELFIE_FRAMES = 8
"""Three is the floor for saying anything about liveness: with two frames you
cannot distinguish "she moved" from "the camera moved"."""

CHALLENGE_STEPS = 4
CHALLENGE_TTL_SEC = 300
"""Five minutes between asking for a challenge and submitting frames. Long
enough for a woman who has to find her card in another room; short enough that a
harvested challenge goes stale before a replay rig can be built around it."""

YAW_CENTRE_MAX = 0.10
YAW_TURN_MIN = 0.16
"""The gap between them is a dead zone on purpose: a frame landing in it
satisfies neither "centred" nor "turned", so an ambiguous capture becomes
uncertain rather than being forced into a verdict."""

YAW_SPREAD_MIN = 0.22
"""The line a printed photograph cannot cross. A still image held to the camera
produces a flat yaw series however the phone is waved, because the ratio is
normalised by interocular distance and measured in the eye-axis frame."""

FRAME_DIFF_MIN = 3.0
"""Mean absolute difference, 0-255, between consecutive frames at 64x64 grey.
Catches the laziest replay: the same JPEG sent N times."""

BLINK_DROP_MIN = 0.35
"""A blink frame's eye-openness must fall 35% below this woman's own median
across the other frames. Relative, not absolute, and that is the point: a fixed
eye-contrast cut does not survive a change of skin tone, eye shape, spectacles
or room lighting, and would quietly fail for whole groups of people."""

FACE_INTRA_SESSION_MIN_COSINE = 0.50
"""The floor for "the same face in every frame". Higher than the card-to-selfie
bar on purpose: these frames are seconds apart, same camera, same light, same
person. Below this, something swapped — which is exactly the attack of holding
the card's photo up for frame one and your own face for the rest."""

FACE_DETECT_SCORE_MIN = 0.85
FACE_MIN_CARD_PORTRAIT_PX = 60
"""Below this there is not enough signal for an embedding to mean anything, and
forcing one produces a confident-looking number built from noise. Too small
routes to RETRY_CAPTURE, never to a rejection."""

# ------------------------------------------------------------- cost control
# Spec §6.

COST_CAP_MICRO_USD = 50_000
"""USD 0.05 per uid, enforced server-side before every paid call.

UNCHANGED, deliberately, even though the real worst case is now 12,000 µUSD —
a quarter of it. The ceiling is a safety rail against a runaway loop or a
provider that starts billing differently, not a budget estimate, and it does not
get relaxed because the numbers got smaller. If a paid provider is ever added
back, the rail is already in place and already enforced."""

MAX_OCR_SUBMISSIONS = 4
MAX_LIVENESS_ATTEMPTS = 2
"""The real worst case is now 4 x 3,000 + 2 x 0 = 12,000 µUSD.

Spec §6 wrote it as 4 x 3,000 + 2 x 16,000 = 44,000, because it assumed AWS
liveness at 15,000 and CompareFaces at 1,000. The owner has decided against AWS,
so both of those are zero and the only money in this pipeline is Cloud Vision:
two images per submission at 1,500 each.

`MAX_LIVENESS_ATTEMPTS` stays at 2 even though liveness is now free, and that is
deliberate. It is no longer a spending limit — it is an ABUSE limit. Unlimited
free liveness attempts against one card is exactly the loop an attacker would
use to find the pose sequence that scrapes past the threshold, and "it costs us
nothing" is not a reason to let them.

ledger.worst_case_micro_usd() computes this rather than restating it, so a
future paid provider that breaks the ceiling fails a test instead of quietly
overspending."""

PER_UID_DAILY_START_LIMIT = 6
PER_UID_DAILY_VERIFY_LIMIT = 6
"""S6: one account's daily allowance of start_verification and verify_identity,
checked BEFORE the global kill switch. Without them one account could run the
global counter to DAILY_VERIFICATION_LIMIT and lock every other woman out for
the day. Six covers a real woman's retakes (MAX_OCR_SUBMISSIONS is 4 for life);
the client shows "try again tomorrow", never a review."""

DAILY_COUNTER_SHARDS = 10
"""S6: the global counter is spread over this many documents per day
(verificationStats/{day}_s{n}) so concurrent verifications do not contend on
one document's write limit. The kill switch compares the SUM."""

DAILY_VERIFICATION_LIMIT = 2_000
"""Spec §6's global kill switch. New sessions past this get "try again later"
and an alert.

2,000 a day is roughly seven times the 278/day that 50,000 over six months
implies, so it will not fire in normal operation. It is a blast radius limit for
the case where something automated finds the endpoint."""

# --------------------------------------------------------- human review
#
# Spec §4's flag-evidence row is DELIBERATELY NOT IMPLEMENTED. The owner decided
# that no image is ever stored, in any bucket, for any duration, for any case —
# including flagged ones. The write path, the bucket, the lifecycle rule and the
# hourly purge job were built and then deleted rather than left behind a
# disabled flag, because a dormant code path that writes ID images to a bucket
# is exactly the thing that gets switched on by accident a year later.
#
# The consequence is that human review CANNOT be "look at her photograph". By
# the time a case reaches a reviewer the images no longer exist anywhere. Review
# is therefore a live encounter: a video call with a woman reviewer, or a
# ladies-only gym visit — which is what the app's C15 screen already offers.
# See review.py.

REVIEW_ROUTES = ("video", "gym")
"""Mirrors the Flutter app's own `ReviewerPath` enum (`video` | `gym`) so both
sides use the same words for the same thing."""

REVIEW_REQUEST_PATHS = ("declined", "error", "niqab")
"""The three ways she can ask for a woman reviewer without an automatic check
deciding it for her (contracts/identity_contract.json, request_review.paths):

  niqab     she chose the woman-reviewer route at C09 (NIQAB_PATH_REQUESTED)
  declined  she declined the camera at C09b (CAMERA_DECLINED)
  error     the automatic check could not run for her (REVIEW_REQUESTED_AFTER_ERROR)

None of them carries an image, a frame or a phone number."""

PER_UID_DAILY_REVIEW_LIMIT = 3
"""request_review calls per account per UTC day. A real woman asks once; the
cap bounds a script that would otherwise fill the queue and the webhook."""

REVIEW_SLA_HOURS = 72
"""The window a flagged case must be decided in, carried over from spec §5's
72-hour evidence ceiling even though there is no longer any evidence to expire.
Past it the case becomes RETRY_REQUIRED — one fresh attempt, still inside the
cost cap.

RETRY_REQUIRED rather than a rejection, because an undecided flag is OUR failure
to review in time, not hers. Turning our backlog into her rejection would be the
wrong way round."""

# ------------------------------------------------- retention and deletion

DECIDED_RECORD_RETENTION_DAYS = 180
"""How long a DECIDED verification job or review flag is kept before the
Firestore TTL policy deletes it (field `expireAt`). A job or flag still waiting
on a review has no `expireAt` and is never swept. nidRegistry and the review
access log get no TTL at all.

PENDING COUNSEL (PDPL retention); not a legal opinion. 180 days is a
placeholder chosen to cover disputes and a store review, not a number counsel
has approved."""

DELETED_ACCOUNT_MAY_REJOIN = False
"""Whether deleting an account frees her national ID for a new account.

False keeps today's behaviour: the registry entry is CLOSED (state 'closed',
uid None), so the card cannot register again while no personal data stays
linked to it. True deletes the entry instead.

PENDING COUNSEL: the legal pre-review notes that a closed entry means a woman
who deleted voluntarily can never rejoin, which VERIFICATION_SPEC.md may
contradict. Not a legal opinion."""

# --------------------------------------------------- collections and secrets

COL_NID_REGISTRY = "nidRegistry"
COL_VERIFICATION_JOBS = "verificationJobs"
COL_FLAGS = "verification_flags"
COL_SESSIONS = "verificationSessions"
COL_LEDGER = "verificationLedger"
COL_CONSENTS = "consents"
COL_STATS = "verificationStats"
COL_USERS = "users"
COL_CONFIG = "verificationConfig"
COL_REVIEW_ACCESS = "verificationReviewAccess"
"""Who opened which flagged case, and when. Spec §5 required an access log for
evidence; there is no evidence any more, and the log stays anyway. A reviewer
queue that shows reason codes and scores for a named woman is still a capability
that needs a record of every use."""

SECRET_PEPPER = "nid-hash-pepper"
"""The Secret Manager secret id, which is what actually exists in the project.

Spec §4 calls this `ID_PEPPER`. That is the name of the VALUE; `nid-hash-pepper`
is the name of the SECRET RESOURCE that was provisioned for it. Renaming the
resource to match the prose would break a secret that already exists, so the
mapping is recorded here instead.
"""

SECRET_FLAG_WEBHOOK = "flag-webhook-url"
"""Secret Manager secret holding the review-queue webhook URL (S14). The
FLAG_WEBHOOK_URL environment variable overrides it."""

FLAG_WEBHOOK_REQUIRED = True
"""S14: in production a missing webhook is an ERROR log line on every flag
(`flag_webhook_missing`), which the webhook-missing alert policy pages on. It
never fails a verification."""

PEPPER_VERSION = 1
"""Stored beside every hash, per spec §4.

Without it, rotating the pepper is a one-way door: every existing hash becomes
unmatchable and every previously-registered card silently becomes registerable
again, which quietly breaks the one-card-one-account rule. With it, a rotation
can compute both and migrate.
"""

CONSENT_VERSION = 1
"""Bumped whenever the consent text changes. Spec §4 allows exactly three fields
in a consent record — uid, version, timestamp — so the version is the only thing
tying a record to what she was actually shown."""

HEALTH_CONSENT_VERSION = 1
"""Version of the separate health-data and transfer-abroad consent (S17,
PDPL Art. 12). Recorded at users/{uid}/consents/health-v1 by
record_health_consent before her first cycle, check-in, measurement, period,
life-stage or allergy write reaches the cloud; the rules refuse those writes
without it. Bumped whenever that wording changes. The wording is PENDING
COUNSEL and PDPC approval of the consent mechanism."""
