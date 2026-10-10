# VERIFICATION REPORT

Spec §12. What changed, test results with real command output, what was
measured, and what was not.

**Verdict: NOT READY.** Blocking items are listed first, as spec §12 requires.

Nothing is deployed. Nothing is committed. Nothing is pushed.

---

## Blocking items

| # | Blocker | Owner |
|---|---|---|
| 1 | **Spec §10's pilot has not been run.** No false-accept or false-reject rate exists for this model on this population. The four thresholds are now chosen from published benchmarks and stated arithmetic rather than left at derived guesses, but **not one of them is measured**. Spec §12 requires pilot goals met or the trade-off documented; there is no pilot data to document. | Owner + ops |
| 2 | **Spec §9.8's adversarial checklist has not been executed.** Eleven pass/fail items, including the printed photo, the screen replay and the male-with-a-female-colleague's-card. `MANUAL_QA.md` lists them all as NOT EXECUTED. | QA |
| 3 | **Firebase per-SMS cost for Egypt is unknown** and may exceed the entire rest of the pipeline. Sign-in is phone OTP, which also violates §2 step 0's "free method". | Owner (D4) |
| 4 | **Deploy-time configuration does not exist**: App Check providers, the Secret Manager IAM grant, the Firestore TTL policy, `FLAG_WEBHOOK_URL`, budget alerts. (D8) | Owner |
| 5 | **Review capacity is short.** The modelled flag rate is now 8.2% to 27.1% depending on where the genuine score distribution really sits, against roughly 11.2% that two women reviewers can absorb. The re-classifications cut the queue by 51% to 63% and that is not enough on its own. Arithmetic and the five proposed changes are under "Human review volume". Reviewers must be women. | Owner |
| 6 | **§9.3 security-rules emulator tests and §9.4 function integration tests on the emulator have not been run.** The rules compile clean against Google's Rules API, and the pipeline is tested with mocked providers, but neither has been exercised on the emulator. | Me, next |

---

## What changed

### Created: `functions/` — 13 modules, 7 callables, 1 scheduled job

Cloud Functions gen2, python312, `europe-west3`, wired into `firebase.json`.

The single most important property, stated at the top of `main.py`: **images are
never written anywhere.** They arrive in the request, live in memory, and are
gone when the function returns. Not Storage, not Firestore, not a temp file, not
a log, not a crash report. There is no cleanup job because there is nothing to
clean up, and no bucket to misconfigure because there is no bucket.

The owner's decision removed even spec §4's flag-evidence exception. That path
was built in full and then **deleted rather than left behind a disabled flag**.

### Changed: `firebase/firestore.rules` (864 → 925 lines)

1. **`notBlockedBy` fixed.** It was defined and never called, so blocking was
   enforced in the app and nowhere else. Now wired to four single-document
   writes, never to a list query, honouring the one-billed-read-per-evaluation
   cost note at its definition.
2. **Whole-app verified gate**, with four named exceptions to avoid a sign-up
   deadlock.
3. **Eleven server-only collections** declared explicitly.

### Changed: `firebase.json` — functions entry, functions emulator port.

### Created: `scripts/privacy_scan` — spec §9.5.

---

## Test results

Command and output, not a claim.

```
$ cd functions && ./.venv/bin/python -m pytest tests/ -q
299 passed in 0.42s
```

Per file:

```
tests/test_nid.py:              84 passed   (spec §9.1 requires >= 40)
tests/test_decisions.py:        53 passed   (spec §9.2)
tests/test_liveness.py:         32 passed
tests/test_pipeline.py:         24 passed   (spec §9.4, mocked providers)
tests/test_faces.py:            24 passed
tests/test_privacy_scan.py:     23 passed
tests/test_ledger_and_dedupe.py 22 passed
tests/test_arabic.py:           20 passed
tests/test_contract.py:         17 passed
```

278 before the threshold work, 299 after. The 21 new tests are the
re-classifications (an unknown governorate recorded rather than flagged and
never rejected, a disagreeing printed birth date retaking before it flags, an
unreadable النوع word retrying on a male digit too, an uncertain score retaking
before it reaches a reviewer and still never approving), the two liveness
invariants, the four threshold pins, and the five that take the score scale
straight off the live provider objects.

### Firestore rules, before and after

Validated with Google's Firebase Rules API `projects/own-hub:test` — read-only,
nothing deployed.

```
BEFORE (git show HEAD:firebase/firestore.rules):
  3 issue(s)
  WARNING: Unused function: notBlockedBy. @ line 132
  WARNING: Invalid function name: exists. @ line 133
  WARNING: Invalid variable name: request. @ line 134

AFTER:
  RULES COMPILE CLEAN — 0 issues
```

### Privacy scan, live project

```
$ ./functions/.venv/bin/python scripts/privacy_scan --project own-hub --skip-logs
Privacy scan — project own-hub

Firestore: 0 root collection(s)
Storage: own-hub-personal — 0 object(s)
Storage: own-hub.firebasestorage.app — 0 object(s)
Cloud Logging: SKIPPED

PRIVACY SCAN CLEAN — nothing forbidden found.
```

**Be careful how this is read.** The project is empty, so a clean scan proves
the scanner runs, not that it detects. The detectors are unit-tested separately
(23 tests) against ASCII, Eastern Arabic and Persian 14-digit runs, base64 JPEG
and PNG payloads, raw image magic bytes, and — equally important — against
things that must NOT trip it: SHA-256 digests, UUIDs, timestamps and longer
digit runs. A scanner that cries wolf gets switched off.

### Compute, measured locally

```
synthetic 12MP JPEG: 8984 KiB
model load (cold, once per instance): 0.035s
decode+downscale 12MP: 78.0 ms/image
YuNet detect @1024px: 18.1 ms/image
SFace embed: 8.2 ms/face
HMAC-SHA256 id_hmac: 0.9 us
```

Apple arm64, not Cloud Run x86. Flagged, not extrapolated.

### Cost ledger, computed not asserted

```
worst case: 12000 uUSD = $0.0120
cap:        50000 uUSD = $0.05
typical single verification: 3000 uUSD = $0.0030
```

---

## Measured cost per verification

| Line | Per verification | At 50,000 |
|---|---|---|
| Cloud Vision, 2 units @ $0.0015 | **$0.00300** | $150.00 |
| Cloud Run compute (~2.5 s @ 1 vCPU / 1 GiB) | ~$0.00007 | ~$3.50 |
| Firestore, ~6 ops | ~$0.00004 | ~$2.00 |
| Secret Manager (cached per instance) | ~$0 | < $1.00 |
| Liveness (self-hosted) | $0 | $0 |
| Face match (self-hosted) | $0 | $0 |
| **Total** | **~$0.0031** | **~$157** |
| Firebase phone-auth SMS | **UNKNOWN** | **UNKNOWN** |

Against the $0.05 ceiling: **6% of it**. Against spec §2's projected $0.019 for
the AWS path: **16% of it**. A male applicant costs $0.0030 and makes zero
liveness or face-match calls — asserted by a test that counts provider calls,
not by intention.

Worst case inside the attempt limits: **$0.012**, still a quarter of the cap.

**The ceiling was not relaxed** when the numbers got smaller. It is a safety
rail against a runaway loop, not a budget estimate, and a test asserts it stays
at 50,000.

---

## The accuracy/threshold trade-off

### Models and licences

| Model | Role | Licence | Size |
|---|---|---|---|
| YuNet `2023mar` | detection + 5 landmarks | **MIT** | 232,589 B |
| SFace `2021dec` | 128-D embedding | **Apache 2.0** | 38,696,353 B |

Both checked against the upstream OpenCV Zoo directory READMEs on 2026-09-25 and
recorded with their SHA-256s in `functions/models/MODEL-LICENCES.txt`. A test
recomputes both digests and fails if a model is swapped without updating the
licence record.

Rejected, with reasons, in the same file: InsightFace/ArcFace pretrained packs
(non-commercial), `dlib_face_recognition_resnet_model_v1` (unresolved training
provenance), FaceNet ports (same), any hosted face API (sending her face to a
third party is the thing this design exists to avoid).

### The thresholds, and why

**Final values, self-hosted providers, set 25 September 2026.**

| Dial | Cosine | Mapped 0-100 | Was |
|---|---|---|---|
| `match_pass` | **0.42** | **71.0** | 0.45 / 72.5 |
| `match_flag` | **0.28** | **64.0** | 0.28 / 64.0 |
| `liveness_pass` | own scale | **75.0** | 82.0 |
| `liveness_flag` | own scale | **55.0** | 55.0 |

Reference points on the same cosine axis: OpenCV's published same-identity cut
for this exact graph is 0.363 (mapped 68.15); their published best-accuracy cut
on the hardest cross-age benchmark is 0.277 (mapped 63.85).

#### The published sources

1. **opencv_zoo, `models/face_recognition_sface/sface.py`**, the reference
   implementation for the exact ONNX graph in `functions/models/`:
   `self._threshold_cosine = 0.363`, `self._threshold_norml2 = 1.128`, and
   `1 if cosine_score >= self._threshold_cosine else 0`.
2. **OpenCV's DNN face tutorial** (`doc/tutorials/dnn/dnn_face`): accuracy and
   the best-accuracy cosine cut, per benchmark.

   | Benchmark | Accuracy | Cosine cut |
   |---|---|---|
   | LFW | 99.60% | 0.363 |
   | CALFW | 93.95% | 0.340 |
   | AgeDB-30 | 94.90% | 0.277 |
   | CPLFW | 91.05% | 0.275 |
   | CFP-FP | 94.80% | 0.212 |

3. **DocFace+**, arXiv:1809.05620, on matching ID-document photos to selfies: a
   publicly available general face matcher (SphereFace) reaches a true accept
   rate of **59.29% +/- 1.55 at a false accept rate of 0.1%**, against
   97.51% +/- 0.40 for a matcher trained on ID-selfie pairs.
4. **opencv_zoo SFace README**: reports one accuracy figure, 0.9940, with no
   statement of which dataset it is on. Quoted nowhere below for that reason.
5. **A per-threshold false-match-rate table for this model: no source found.**
   The impostor model below is derived from source 2, not quoted from anywhere.

#### Assessing the previous reasoning

The previous worker set `match_pass` to 0.45 on the argument that card-to-live
is harder than the photo pairs 0.363 was calibrated on, and that a man admitted
to a women-only community is unrecoverable while a woman waiting a day is not.

The second half is correct and is why the accept bar sits above OpenCV's cut at
all. The first half does not support the conclusion, and source 2 is the
counter-example: **as the pairs get harder, the published best cut falls**, from
0.363 on frontal LFW to 0.277 on thirty-year age gaps to 0.212 on
frontal-to-profile. Difficulty moves the genuine distribution down. It does not
move the impostor distribution up. Raising the accept bar because the domain is
hard buys very little against false accepts and pays for it in genuine women
pushed into the band, which in this product is a video call.

So the accept bar is set by the impostor tail and by nothing else.

#### How 0.42 was derived

Model different identities as cosine ~ Normal(0, s), mean zero because two
unrelated embeddings in a 128-D space are near-orthogonal. Solve s from source
2's LFW row: 99.60% accuracy over an equal split of genuine and impostor pairs
is a 0.40% false match rate at cosine 0.363, so s = 0.363 / 2.652 = **0.137**.

| Cosine | Mapped | False match rate |
|---|---|---|
| 0.363 | 68.15 | 0.401% |
| 0.400 | 70.00 | 0.174% |
| **0.420** | **71.00** | **0.108%** |
| 0.450 | 72.50 | 0.051% |

0.42 is the false-match-rate = 0.1% operating point, deliberately the same
operating point source 3 reports at, so this bar is comparable to a published
figure rather than invented.

In people: at 50,000 sign-ups, assume pessimistically that 1% of them (500) are
men attempting a borrowed card, and that each takes both of his two liveness
attempts. 500 x 2 x 0.108% = **1.1 expected admissions across the whole launch**.
At 0.363 the same arithmetic gives 4.0. At 0.45 it gives 0.5, half a man better
than 0.42, bought at roughly 4,000 extra video calls under the central
assumption below. Spec section 10 says that where the goals conflict, choose
fewer false accepts and report the trade-off; 0.42 is where the two curves stop
being worth crossing.

That 1.1 is not a measured false accept rate. It is what the published LFW
figure implies if the impostor distribution on Egyptian cards resembles LFW's.
Same-gender, same-ethnicity and related-person pairs all score higher than
random ones, so the real figure is likely worse, and a sibling attack is not
modelled at all.

#### How 0.28 was kept

Below `match_flag`, once her attempts are used, she is refused by a machine with
no human in the loop. That is the harshest thing this system does, so the floor
has to sit where published evidence makes a refusal defensible. 0.277 is source
2's best-accuracy cut on AgeDB-30, the hardest cross-age row published, and
card-to-live is at heart a cross-age problem: an Egyptian ID photograph can be
seven years old. At a best-accuracy cut the two distributions cross, so below it
a score is at least as likely to have come from a different person as from the
same one. Rounded to 0.28 so the mapped value is exactly 64.0.

Same number as before, better reason for it.

#### How the two liveness numbers were derived

**No published benchmark exists** for the composite in
`providers_selfhosted._confidence`, and none ever will: we wrote it, and it is a
weighted sum of a pose-pattern boolean, a yaw spread and a frame-consistency
term. So these two are arithmetic over that function's own weights, which is at
least checkable.

| Capture | Score |
|---|---|
| pose pattern did NOT match, everything else perfect | 12 + 30 + 15 + 10 = **67** (ceiling) |
| pose pattern matched, minimum legal turn and consistency | 45 + 15 + 0 + 0 = **60** (floor) |
| pattern matched, real turn, consistent frames, no detected blink | 45 + 30 + 15 + 0 = **90** |
| pattern matched, modest turn (spread 0.33), typical consistency (0.75), no detected blink | 45 + 22.5 + 10.7 + 0 = **78.2** |

`liveness_pass = 75` because the last row is a woman who did exactly what she
was asked and whose only failing is our own blink proxy, which
`faces.eye_openness` documents as weak, which spectacles and side lighting move
on their own, and which the composite therefore weights at 10. At 82 she scored
78.2 and got a video call. At 75 she is approved, and **nothing that matters is
given away**: 75 > 67, so the pose pattern must still have matched for anyone to
pass, and all four hard checks (a face in every frame, the same face throughout,
frames that actually differ, a head that actually turned) still gate before any
score is produced.

`liveness_flag = 55` because a capture that matched the pattern cannot score
below 60, so 55 guarantees a liveness **rejection** is only ever handed to a
capture whose pose ordering failed, never to a woman who followed the challenge.
Five points of headroom so that does not depend on float equality.

Both invariants are now tests rather than comments
(`test_nothing_can_pass_liveness_without_the_pose_pattern_matching`,
`test_a_liveness_rejection_can_only_ever_be_a_pattern_failure`).

### What is measured and what is reasoned

**Measured: nothing.** Not one of these four numbers has been observed against
an Egyptian national ID card photographed on an Egyptian phone. Spec section
10's pilot (50 genuine, 20 male, 20 impostor, 20 spoof) has not been run, and
`DECISIONS_NEEDED.md` D5 is still open.

**Reasoned, from published figures:** the impostor spread (from OpenCV's LFW
accuracy for this graph), the accept bar (the FMR = 0.1% point of that model),
the reject floor (OpenCV's AgeDB-30 cut), and both liveness dials (arithmetic
over our own weighting function).

**Assumed, and the assumptions are the weak part:** that the impostor
distribution on Egyptian ID cards resembles LFW's; that 1% of sign-ups are
impostor attempts; that the error at a published best-accuracy cut splits evenly
between false accepts and false rejects; and every input to the queue model
below. Each is stated where it is used. None is a measurement.

`config.THRESHOLDS_SELF_HOSTED.calibrated_from` says the same thing inside the
configuration, and a test asserts it keeps saying it.

---

## Human review volume: the arithmetic

At 50,000 sign-ups over six months, 273 a day, every percentage point of flag
rate is **500 video calls with a woman reviewer**. No image is ever stored
(`DECISIONS_NEEDED.md` D3), so review cannot be a desk review of a photograph;
it is a live encounter. The owner asked for suspicious cases to be flagged
without reviewing every application, and those two goals are only compatible if
**fewer things flag at all**, not if the numbers move.

### What changed

Every FLAG signal was re-classified against one question: would a human learn
something a retake would not? Each answer is argued at the line that implements
it in `decisions.py`.

| Signal | Was | Now | Why |
|---|---|---|---|
| digit 13 and the printed النوع disagree | FLAG | **FLAG, unchanged** | The card contradicts itself. A retake cannot fix a contradiction and a live encounter settles it. |
| same card failed repeatedly across accounts | FLAG | **FLAG, unchanged** | Behaviour, not image quality. |
| one install tried several different cards | FLAG | **FLAG, unchanged** | Same. |
| she asked for a woman reviewer | FLAG | **FLAG, unchanged** | Her own request. Not a failure. |
| match or liveness in the uncertain band | FLAG on attempt 1 | **retake first, FLAG once attempts are used** | A reviewer cannot see the shadow, the angle or the three-quarter pose that caused it; no image exists by the time she dials in. A second capture can. Never approves on the way. |
| النوع word unreadable, digit 13 female | retake, then FLAG | **unchanged** | Already correct. |
| النوع word unreadable, digit 13 male | FLAG immediately | **retake first, FLAG once attempts are used** | A retake reading ذكر makes him a clean rejection who costs no reviewer; one reading أنثى raises the real conflict flag. |
| printed birth date disagrees with the encoded one | FLAG | **retake first, FLAG once attempts are used** | Age comes from the encoded date, which is already validated. A disagreement is one error-prone OCR pass over small print; one that survives four photographs is not. |
| governorate code unknown | FLAG | **recorded and counted, no review** | Spec section 3 doubts it in the same sentence it lists it: the published list may be incomplete. Only 28 of 100 two-digit codes were ever issued, so most OCR misreads of digits 8-9 land on an unknown one. A reviewer has nothing to look at. |

### What an attacker gains from each downgrade

| Downgrade | What he gains | Why it is acceptable |
|---|---|---|
| band score retakes first | one extra draw at clearing `match_pass` instead of meeting a woman reviewer on his first attempt | Bounded at exactly one extra draw by `MAX_LIVENESS_ATTEMPTS = 2`, which stays at 2 for this reason. The extra draw is already priced into the 1.1 expected admissions above, which is computed with two attempts each. Burning attempts across cards raises `HMAC_MANY_FAILURES` or `INSTALL_MANY_IDS`, which a retake cannot clear. |
| النوع unreadable on a male digit retakes first | he can make us pay for four OCR submissions (12,000 µUSD, inside the 50,000 cap) before reaching the same review | He reaches a video call with a woman reviewer either way. Most such cases now resolve into a clean rejection instead, which is strictly better for us. |
| printed birth date retakes first | a careless forgery gets up to three more attempts to have its printed date read as consistent | The forgery does not change between photographs and the same OCR reads it each time, so this is close to no gain. |
| unknown governorate no longer flags | a forged card carrying a code that was never issued now passes this check silently | Close to worthless. `RESIDUAL_RISKS.md` #1 already states that **nothing** in this system detects a forged card: no hologram, no microprint, no government lookup. Anyone who can print a card can copy a real governorate code off any other card, so the only forgeries this caught were ones that fail on sight. |
| `liveness_pass` 82 to 75 | he can pass with a smaller head turn, lower frame consistency and no detected blink | The pose pattern is still mandatory (75 is above the 67 ceiling of a pattern failure) and all four hard checks still gate. A live person who performs the challenge correctly was never stopped by liveness anyway; `SelfHostedLiveness`'s own docstring lists that under DOES NOT STOP, and the face match is what stands between him and an account. |

Nothing that used to be refused is now approved. Every downgrade either defers a
human until a free remedy is exhausted, or removes a review that had nothing for
a human to look at.

### The modelled flag rate

The genuine card-to-live cosine distribution has never been measured, so the
model is run against three proxies, each built from a published
(best-accuracy cut, accuracy) pair from source 2 with a single stated assumption
of sigma = 0.13.

| Proxy | Built from | Genuine cosine |
|---|---|---|
| optimistic | LFW, 99.60% at 0.363 | N(0.708, 0.13) |
| central | AgeDB-30, 94.90% at 0.277 | N(0.490, 0.13) |
| pessimistic | CFP-FP, 94.80% at 0.212 | N(0.423, 0.13) |

Other stated assumptions: 60% of band scores are still in the band on the second
attempt, because retries are correlated (same woman, same card, same habits);
the pose pattern matches 93% of the time; yaw spread ~ N(0.45, 0.14) and
intra-session consistency ~ N(0.80, 0.08), both conditioned on not hard-failing
first; a blink is detected 55% of the time; النوع unreadable after four
photographs 1.0%; sex conflict 0.3%; cross-account behaviour 0.5%; niqab route
elected 2.0%; governorate unknown 1.5%. **None of these is measured.**

**Before this work**, with `match_pass` 0.45, `liveness_pass` 82, the band
reviewed on attempt 1 and the governorate flagging:

| Proxy | Match band | Liveness band | Other | Total flag rate | Calls | Per day | Reviewers |
|---|---|---|---|---|---|---|---|
| optimistic | 2.3% | 15.8% | 5.2% | **22.0%** | 11,014 | 60 | 3.9 |
| central | 32.7% | 15.8% | 5.2% | **46.3%** | 23,137 | 126 | 8.3 |
| pessimistic | 44.6% | 15.8% | 5.2% | **55.8%** | 27,894 | 152 | 10.0 |

**After**, with `match_pass` 0.42, `liveness_pass` 75, the band retaking first
and the governorate recorded only:

| Proxy | Match band | Liveness band | Other | Total flag rate | Calls | Per day | Reviewers |
|---|---|---|---|---|---|---|---|
| optimistic | 0.8% | 3.8% | 3.8% | **8.2%** | 4,084 | 22 | 1.5 |
| central | 14.6% | 3.8% | 3.8% | **20.9%** | 10,466 | 57 | 3.7 |
| pessimistic | 21.3% | 3.8% | 3.8% | **27.1%** | 13,572 | 74 | 4.9 |

Reviewer count is full-time women reviewers at 15 minutes a call, 40-hour weeks,
multiplied by 1.5 for no-shows, reschedules and notes. Sign-ups arrive seven
days a week.

**The cut is 51% to 63% of the queue, and it is not enough on its own.** Two
reviewers can absorb a flag rate of about **11.2%**; one can absorb about 5.6%.
Only the optimistic proxy lands inside that, and only just.

Two further facts the owner needs.

- **The floor is about 6%, whatever the match threshold does.** Even at a
  genuine mean cosine of 0.75, better than LFW, the total flag rate only falls
  to 8.5%, because the remainder is the liveness band, the niqab route and the
  OCR flags. The match dial cannot take the queue below one reviewer.
- **The niqab route is 2 points of that, and it is not waste.** Those are women
  who asked for a woman reviewer. That queue is the product working.

### What to change, if the pilot confirms the central case

In order of leverage.

1. **Run the pilot before launch.** The range above is 3x wide, and the only
   thing that collapses it to a number is spec section 10's 50 genuine, 20 male,
   20 impostor, 20 spoof. Staffing, launch pace and the thresholds themselves
   are all downstream of it. `DECISIONS_NEEDED.md` D5.
2. **Raise the capture resolution of the card portrait.**
   `WORKING_LONG_EDGE = 1024` puts a card portrait at roughly 60 to 150 px wide
   against SFace's 112x112 input, so the genuine distribution is being depressed
   by our own downscale before any threshold sees it. Every +0.05 of genuine
   mean cosine is worth roughly 5 points of flag rate in the central case, which
   is 2,500 calls. Not changed here, because the size of the gain cannot be
   estimated without measuring it, but it is the cheapest lever in the system
   and it should be the pilot's first A/B.
3. **Measure the pose-pattern match rate and fix the instructions, not the
   threshold.** The liveness band is almost entirely pattern failures. At a 93%
   match rate it contributes 6.4% per attempt; at 98% it contributes 3.4%. If
   the pilot shows women failing the pose ordering, the answer is clearer
   on-device guidance.
4. **Ramp the launch behind the measured flag rate.** The queue is a problem at
   273 sign-ups a day, not at 50. Even the pessimistic 27% is 13 calls a day at
   50 sign-ups a day.
5. **If the measured genuine distribution lands near the pessimistic proxy, the
   answer is a different matcher, not a different number.** Source 3 is explicit
   that a general face matcher transfers badly to ID-document-to-selfie, and no
   threshold repairs a matcher that is in the wrong domain. That would be a
   stop-and-escalate under spec section 13, not a tuning exercise.

### The unit bug, found by a test

`config.py` claimed `match_pass = 80` was "cosine ~0.45". The mapping puts 0.45
at 72.5. A test comparing the constant against the mapping caught it.

That is the same class of bug as carrying spec section 3's Rekognition numbers
across to our scores, and it had happened inside the very file that guards
against it. There are now three score scales, each named, each part of the
`ThresholdSet` type, with `ThresholdScaleMismatch` raised rather than a
plausible answer returned.

### The scale guard was pointing at us

A second instance of the same bug, found while setting these thresholds, and
more serious than the first.

`SelfHostedLiveness.score_scale` declared `SCALE_SFACE_COSINE_MAPPED`.
`THRESHOLDS_SELF_HOSTED.liveness_scale` has always been
`SCALE_SELFHOSTED_LIVENESS`. `pipeline.run` reads `score_scale` off the live
provider and hands it to `ThresholdSet.for_providers`, so **every real
verification that reached step 8 would have raised `ThresholdScaleMismatch` and
failed**, for every woman, while the suite stayed green because its tests build
`Signals` with matching scales by hand.

`tests/test_decisions.py` even asserted that this exact pairing must raise. The
guard was working perfectly; the wiring was aimed at ourselves.

Fixed in `providers_selfhosted.py`, and five tests added that take the scale
straight off the live provider objects, exactly as `pipeline.run` does, so the
suite can no longer be green while production is broken.

---

## What this system will and will not stop

### Will stop

- A man using **his own card**: digit 13 is odd and the printed النوع reads ذكر.
  Both sources agree, so it is a rejection with no human involved, for $0.0030,
  and **zero liveness or face-match calls are made** — asserted by a test.
- A man using **a woman's real card**: the face match compares his live face
  against her printed portrait. This is the case the threshold exists for.
- **A printed photograph** held to the camera: it cannot turn its head, and the
  yaw spread check is what it fails.
- **A single still image on a screen**: same reason.
- **The same JPEG submitted N times**: consecutive-frame difference.
- **A mid-capture swap** — the card's printed photo for frame one, a real face
  for the rest: every frame is embedded and compared pairwise.
- **A generic pre-recorded "turn your head" clip**: it will not match a randomly
  ordered challenge.
- **A modified client that sends "approved"**, or that sends its own liveness
  outcome: the decision is computed entirely server side and
  `liveness.outcome` is not read. Two tests hold this.
- **Two accounts on one card**: transactional `nidRegistry` claim.
- **Bulk testing of stolen ID numbers**: 4 OCR submissions and a $0.05 ceiling
  per uid; the duplicate check sits behind the sex gate, so it is not an
  enumeration oracle; the cross-account counters surface one install working
  through several cards.
- **A malformed or invented number**: century, real calendar date, not in the
  future, MIN_AGE, plus 27 published governorate codes — non-contiguous, so a
  range check would not do it.
- **An account being told which check failed**: the response carries 5 coarse
  hints, mapped many-to-few. The sex gate, the age gate and every FLAG signal
  map to nothing at all.

### Will NOT stop

- **A well-made forged card with a man's photograph and an even 13th digit.**
  This defeats the design. There is no hologram, UV, microprint or database
  check, and Egypt offers no public validation API. RESIDUAL_RISKS #1.
- **A video replay on a screen by someone who fetched the challenge first.** The
  challenge is issued before capture, so a prepared attacker can play the right
  motions. Randomisation gives roughly 1 in 13 against a blind guess; it is a
  speed bump.
- **A 3D mask, or a real-time deepfake.** No texture analysis, no depth, no
  reflectance model, no moiré detection. A half-working screen detector was
  deliberately not shipped, because it would create false confidence.
- **A verified account handed to someone else afterwards.** Verification happens
  once. Nothing re-checks who holds the phone. In this product's context,
  coercion at sign-up is the version of this that matters, and the system cannot
  see it.
- **Automation, without App Check.** Rate limits keyed on a client-supplied
  install id are forgeable. App Check is the control that actually resists
  automation; it is enforced in code and the providers are not yet provisioned.
- **A leaked pepper.** ~10^10 plausible ID numbers is a sub-minute GPU run
  against HMAC-SHA256. Secrecy of the pepper is the whole defence.
  RESIDUAL_RISKS #8 proposes scrypt at about six cents total.
- **A woman being wrongly flagged.** The flag rate is unknown and could be
  large, and every point of it is 500 video calls.

---

## NOT EXECUTED

Spec's rules of engagement: never write "tested" for anything not executed.

- §9.3 security-rules emulator tests (rules compile clean; not exercised)
- §9.4 emulator integration tests (logic tested with mocks, not on the emulator)
- §9.5 privacy scan against a populated project (scanner runs; project is empty)
- §9.6 live smoke test against real Vision with consenting team members' cards
- §9.7 device end-to-end tests — all nine device/locale/condition rows
- §9.8 adversarial tests — all eleven rows
- §10 pilot — none of the four cohorts
- §5 git-history secret scan
- §11 production readiness checklist — most items are deploy-time
- Real faces through YuNet and SFace. No real face photographs are in this repo
  (rule of engagement 7). The models load, the geometry is tested exactly, the
  detector correctly finds nothing in noise — but detection and separation
  accuracy on real Egyptian cards is the pilot's job.

## Not delivered

- `STORE_DISCLOSURES.md` and `PRIVACY_NOTICE_DRAFT.md` (spec §12). Both need
  the owner's decisions on D4 and on the final processor list before they can be
  written accurately, and a privacy notice drafted from guesses is worse than
  none. The processor list is now short and stable — Google Cloud Vision (EU
  endpoint) is the only third party that ever sees an image — which is most of
  what both documents need.
