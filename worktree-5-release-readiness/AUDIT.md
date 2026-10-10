# AUDIT — identity verification backend

Spec §7. Scope: the server side (`functions/`, `firebase/`). The Flutter client
is another worker's and is described only where the contract touches it.

State at the time of writing: **nothing is deployed, nothing is committed.**
All evidence below is from commands executed locally against this worktree and,
where noted, read-only calls against the live `own-hub` project.

---

## 0. Critical defects, ranked

Spec §7 item 6. Ranked by what happens if it ships unaddressed.

| # | Defect | Status |
|---|---|---|
| 1 | **Client sent its own liveness outcome.** The Flutter worker's first contract draft had `liveness: {outcome, sessionId}`. A patched APK sending `outcome: "pass"` bypasses the entire product. | **FIXED** — the field is ignored; only `sessionId` is read. Held by an AST test. |
| 2 | **Server returned internal reason codes to the handset.** `{outcome, reasons}` with real codes is a free oracle telling an attacker which control to work on. | **FIXED** — `reasons` now carries a 5-value user-safe vocabulary, mapped many-to-few so it cannot be inverted. 9 tests. |
| 3 | **`notBlockedBy` defined but never called.** Blocking was enforced in the app and nowhere else, so a client that skips the app's check could comment on, follow, or message someone who had blocked them. | **FIXED** — wired to 4 single-document writes. Rules compiler: 3 warnings before, 0 after. |
| 4 | **Threshold units silently interchangeable.** Spec §3's four numbers are Rekognition units; our scores are two other scales. Carrying them across produces false accepts that nothing detects. | **FIXED** — scale is part of the type, mismatch raises. A real instance of this bug existed in `config.py` and was caught by a test. |
| 5 | **No verification backend existed at all.** `functions/` was empty; `firebase.json` had no functions entry; the app's `VerificationRepository` was a fake that could never verify anyone. | **FIXED** — 7 callables, 13 modules, 278 tests. |
| 6 | **Firebase phone-auth SMS cost unknown** and plausibly larger than the whole rest of the pipeline. | **OPEN** — D4. Unverified, see §2 Step 0 below. |
| 7 | **No pilot data.** Every threshold is derived, not measured. No FAR/FRR exists. | **OPEN** — D5, spec §10. |

---

## 1. Architecture map

### What exists now, server side

```
functions/
  main.py                       7 callables + 1 scheduled job
  requirements.txt              pinned exactly
  .gcloudignore
  identity/
    nid.py                      pure parser, no I/O           (spec §8)
    arabic.py                   pure النوع reader, no I/O
    config.py                   every dial + the scale guard  (spec §3)
    reasons.py                  48 internal codes, 5 user-safe
    decisions.py                spec §3's matrix, pure
    ledger.py                   spec §6's budget, pure core
    dedupe.py                   id_hmac + registry, pure core
    providers.py                3 interfaces + mocks
    providers_selfhosted.py     Vision OCR, challenge liveness, SFace match
    faces.py                    YuNet + SFace, geometry
    pipeline.py                 spec §2's ordering
    store.py                    Firestore transactions, Secret Manager
  models/
    face_detection_yunet_2023mar.onnx     232,589 B   MIT
    face_recognition_sface_2021dec.onnx   38,696,353 B Apache 2.0
    MODEL-LICENCES.txt, LICENCE-yunet-MIT.txt, LICENCE-sface-Apache-2.0.txt
  tests/                        9 files, 278 tests
scripts/privacy_scan            spec §9.5
firebase/firestore.rules        925 lines (was 864)
firebase.json                   functions entry added
```

### Callables

| Name | Auth | Paid | Purpose |
|---|---|---|---|
| `record_consent` | uid + App Check | no | spec §2 step 1, before camera |
| `start_verification` | uid + App Check | no | mints single-use uid-bound session + server-chosen challenge |
| `verify_identity` | uid + App Check | **yes** | spec §2 steps 3-8 in one round trip |
| `list_verification_flags` | `admin` | no | review queue: codes, scores, handle |
| `schedule_verification_review` | `womanReviewer` | no | book a video call or gym visit |
| `decide_verification_flag` | `womanReviewer` | no | record the live review's outcome |
| `expire_stale_reviews` | scheduled hourly | no | 72h SLA → `RETRY_REQUIRED` |

### Packages, with versions

`firebase-functions 0.6.0`, `firebase-admin 7.7.0`,
`google-cloud-firestore 2.21.0`, `google-cloud-vision 3.15.0`,
`google-cloud-secret-manager 2.30.0`, `google-cloud-storage 2.19.0`,
`opencv-python-headless 4.10.0.84`, `numpy 1.26.4`.

Two pins that are load-bearing rather than tidy:
- **headless** OpenCV: the GUI build pulls X11/GTK shared objects that do not
  exist in the Functions runtime. Using the wrong one is an ImportError that
  appears only after deploy.
- **numpy <2**: opencv-python-headless 4.10 is built against the numpy 1.x ABI.
  numpy 2 produces a crash inside `cv2`, not a resolver error.

### Firebase configuration

Project `own-hub` (681714989950). Firestore `(default)`, `europe-west3`.
Functions gen2, python312, `europe-west3`, 1 GiB, 120 s, max 20 instances.
Buckets: `own-hub.firebasestorage.app` (us-east1, content library),
`own-hub-personal` (europe-west3). **Neither is touched by this service.**

### Every place data is written

| Collection | Written by | Contents |
|---|---|---|
| `nidRegistry/{id_hmac}` | server | `uid`, `state`, `pepper_version` |
| `verificationJobs/{id}` | server | outcome, codes, bands, attempt, spend, timestamps |
| `verification_flags/{id}` | server | codes, scores, scale labels, route, SLA |
| `verificationSessions/{id}` | server | uid, challenge steps, consumed, expiresAt |
| `verificationLedger/{uid}` | server | µUSD spent, attempt counters, operation ids |
| `verificationBehaviour/{hash}` | server | failure count |
| `verificationInstalls/{hash}` | server | up to 10 id_hmacs |
| `verificationStats/{day}` | server | daily session count (kill switch) |
| `verificationReviewAccess/{id}` | server | reviewer uid, flag id, action, time |
| `users/{uid}.verification` | server | `decidedAt`, `imagesDeletedAt` only |
| `users/{uid}/consents/{id}` | server | version + timestamp only |
| Auth custom claims | server | `verified: true`, merged with existing |

**No image is written anywhere.** No bucket is written at all.

---

## 2. Gap table

Spec §7 item 2. Status against spec §§1-6.

| Requirement | Status | Evidence | Fix plan |
|---|---|---|---|
| §1 Only women, by Egyptian NID | **Met** | `decisions.decide`, `nid.parse`; `test_decisions.py` | — |
| §1 Verification once at signup, cannot use app before | **Met (server)** | `firestore.rules` whole-app gate, `isSelfVerified`; rules compile clean | Client `accountRequired` flag is the LAST release step — see RESIDUAL_RISKS #9 |
| §1 (a) card is an Egyptian NID showing a female holder | **Met** | digit 13 + printed النوع, both checked | — |
| §1 (b) live human present | **Partial** | self-hosted challenge response; `test_liveness.py` | Genuinely weaker than commercial passive liveness. RESIDUAL_RISKS #6. Adversarial tests NOT RUN |
| §1 (c) that human is the one on the card | **Met** | SFace 1:1, server side; `providers_selfhosted.SelfHostedFaceMatch` | Thresholds uncalibrated — D5 |
| §1 One NID, one active account | **Met** | `dedupe.judge` + transactional `claim`; 9 tests | — |
| §1 No identity data stored after decision | **Met, exceeded** | no image written at all; `test_contract.py` scans every module for storage calls | — |
| §1 Borderline cases flagged, not silently decided | **Met** | `decisions.PENDING_REVIEW`, 8 FLAG signals; `test_decisions.py` | — |
| §1 Max spend USD 0.05, server-side | **Met** | `ledger.check` before every paid call; worst case measured at 12,000 µUSD | — |
| §1 MIN_AGE 18 from digits 2-7 | **Met** | `config.MIN_AGE`, boundary tests at birthday ±1 day | — |
| §1 Bilingual UI | **N/A here** | client-side | Flutter worker |
| §2 Step 0 account first, free method | **VIOLATED** | app uses phone OTP, not email-link/Google/Apple | **D4.** Owner decision |
| §2 Step 0 report per-SMS cost for Egypt | **UNVERIFIED** | see "Unverified" below | **D4** |
| §2 Step 1 consent before camera | **Met** | `record_consent`; `verify_identity` refuses without it | — |
| §2 Step 2 on-device capture checks | **N/A here** | client-side | Flutter worker |
| §2 Step 3 Vision DOCUMENT_TEXT_DETECTION both sides, in memory | **Met** | `providers_selfhosted.VisionOcr`, EU endpoint | — |
| §2 Step 3 normalize Eastern Arabic + Persian digits | **Met** | `nid.normalise_digits`; tests for both blocks | — |
| §2 Step 3 both sides must agree | **Met** | `pipeline.run`; `test_disagreeing_sides_ask_for_a_retake` | — |
| §2 Step 3 structure validation | **Met** | 84 parser tests | — |
| §2 Step 3 digit 14 NOT validated | **Met** | checksum code deleted; a test greps the module to keep it deleted | — |
| §2 Step 3 read printed gender word | **Met** | `arabic.read_sex_field`, 16 tests | — |
| §2 Step 3 cross-check printed birth date | **Partial** | `Signals.printed_birth_date_disagrees` exists and flags; the OCR extraction of a printed date is **not implemented** | Needs a date-format survey of real cards first |
| §2 Step 3 do not extract name/address/religion | **Met** | never parsed, never stored | — |
| §2 Step 4 gender gate BEFORE paid liveness | **Met** | `test_male_card_never_reaches_a_paid_liveness_call` asserts zero provider calls | — |
| §2 Step 5 HMAC + pepper_version, raw number discarded | **Met** | `dedupe.hash_and_forget`, `del parsed` immediately after | Pepper-leak risk: RESIDUAL_RISKS #8 |
| §2 Steps 6-7 AWS Rekognition | **Deliberate deviation** | owner decided against AWS entirely | D1/D2 closed by owner |
| §2 Step 6 reference image from server, never client | **Met** | `providers_selfhosted._best_frame` picks it | — |
| §2 Step 8 custom claims + token refresh | **Met** | `store.mint_claims` merges rather than replaces; `refreshToken` in response | — |
| §3 Six outcomes | **Met** | `decisions.OUTCOMES` | — |
| §3 All 8 FLAG signals | **Met** | parametrised test per signal | — |
| §3 Thresholds server-side only | **Met** | `config.py`; nothing in Remote Config | — |
| §3 Coarse user-facing messages | **Met** | `reasons.to_user_safe`, many-to-few | — |
| §4 Allowlist enforced | **Met** | `store._allowlisted` raises on an unlisted field | — |
| §4 Flag evidence bundle | **Deliberate deviation — NOT IMPLEMENTED** | owner instruction: never store an image. Built, then deleted rather than left behind a flag | See "Deliberate deviations" |
| §4 AWS AI opt-out policy | **N/A** | no AWS | — |
| §5 Claims server-set only | **Met** | Admin SDK only; rules deny client writes | — |
| §5 Rules deny client writes to verification/consent/hash/flag/config | **Met** | 11 explicit `allow read, write: if false` blocks | — |
| §5 Deny app data unless verified | **Met, with 4 named exceptions** | `isSelfVerified` + comment | D6 answered by coordinator |
| §5 Admin-only paths need `admin` claim | **Met** | `_require_admin` | — |
| §5 App Check enforced on every callable | **Met in code** | `ENFORCE_APP_CHECK = True`, re-checked in `_require_auth` | Play Integrity / App Attest must be provisioned — D8 |
| §5 Every callable checks auth, App Check, limits, ledger first | **Met** | `_require_auth` then consent then `ledger.check` | — |
| §5 Idempotent callables | **Met** | `operation_id`, transactional; `test_a_double_submit_does_not_double_charge` | — |
| §5 sessionId single-use, uid-bound | **Met** | transactional `take`; 3 tests | — |
| §5 Least-privilege IAM | **Not done** | deploy-time | D8 |
| §5 Secrets in Secret Manager, none in repo | **Met** | `store.pepper()` reads at runtime | D8: grant accessor role |
| §5 Scan git history for secrets | **NOT DONE** | — | Run `gitleaks`/`trufflehog` before first push |
| §5 Release builds obfuscated | **N/A here** | client-side | Flutter worker |
| §5 Reviewer allowlist for App/Play review | **NOT IMPLEMENTED** | needs a real review-account uid | RESIDUAL_RISKS #10 |
| §5 Flags written with no PII | **Met** | `reasons.py` is a closed vocabulary; no free-text field exists | — |
| §5 Webhook carries flag id + codes only | **Met** | `_post_flag_webhook` | Needs `FLAG_WEBHOOK_URL` — D8 |
| §5 Admin opens evidence via signed URL | **Deliberate deviation** | no evidence exists; callable deleted | Access log kept |
| §5 72h undecided → RETRY_REQUIRED | **Met** | `expire_stale_reviews` | — |
| §5 Account deletion removes docs, claims, hash binding | **Partial** | registry `state:'closed'` shape implemented and matches the app's manifest row 23 | The deletion Function itself is another worker's |
| §6 Cost ledger in µUSD | **Met** | `ledger.py`, integers throughout | — |
| §6 Refuse if spent + next > 50,000 | **Met** | boundary tests at exactly the cap and one µUSD past it | — |
| §6 Attempt limits 4 OCR / 2 liveness | **Met** | enforced before the provider is contacted | — |
| §6 Global kill switch | **Met** | `DAILY_VERIFICATION_LIMIT`, transactional counter | — |
| §6 Spend alerts configured | **NOT DONE** | Cloud Billing API is disabled on the project | D8 |
| §6 Report measured cost from real runs | **Partial** | provider cost is exact; compute measured locally on arm64, not on Cloud Run | See §4 |

---

## 3. Data-flow trace

Spec §7 item 3. For each piece of identity data: where it enters, everywhere it
travels, everywhere it could persist.

### Card front image
- **Enters:** `verify_identity` request body, base64, field `front`.
- **Travels:** `_decode_image` (size-checked before decode) → `pipeline.Inputs`
  → `VisionOcr.read` (HTTPS to `eu-vision.googleapis.com`) →
  `SelfHostedFaceMatch.compare` → `faces.decode` → numpy array.
- **Could persist:** nowhere. Not written to Storage, Firestore, disk or a temp
  file. `Outcome` has no field that survives the call. Explicitly `del`-ed at
  the end of `verify_identity`.
- **Third-party retention:** Google Cloud Vision, EU endpoint. Google's
  documented position is that Vision does not store request images for these
  features; this is a contractual matter, not something the privacy scan can
  verify.
- **Logs:** the Vision exception handler is bare and propagates nothing from the
  exception, because a client-library error can quote the request.

### Card back image
Identical path; additionally read by `arabic.read_sex_field`.

### Selfie frames (3-8)
- **Enters:** `verify_identity`, field `frames`.
- **Travels:** decode → `SelfHostedLiveness.submit_frames` (an in-process dict,
  keyed by session id) → `evaluate_frames` → `faces.decode`/`detect`/`embed`.
  The dict entry is `pop`-ed in `fetch_result`.
- **Could persist:** nowhere. One frame is selected as the reference image and
  passed to the face match **in memory**; with the evidence bundle deleted it is
  then dropped.

### The raw 14-digit number
- **Enters:** derived from Vision's OCR text, never sent by the client.
- **Travels:** `nid.first_valid` → `ParsedNid.number` →
  `dedupe.hash_and_forget`.
- **Ends:** `del parsed` on the line after the hash is computed (spec §2 step
  5). `ParsedNid` has no `to_dict`, no `__str__`, and a test asserts it exposes
  no serialisation helper.
- **Could persist:** only as `HMAC-SHA256(pepper, number)`, as a document id.

### Name, address, religion, marital status
- **Enters:** inside Vision's `full_text_annotation.text`.
- **Travels:** held in `OcrResult.text` for the length of the call. Only
  14-digit runs and the النوع word are read out of it.
- **Could persist:** nowhere. Never parsed, never stored, never logged.

### Birth date and governorate
- Derived in memory from the number, used for the age check and the unknown-code
  flag, then discarded with `ParsedNid`.

### Scores
- `liveness_confidence` and `match_similarity` ARE persisted, on the flag
  document, because spec §4 row 2 allowlists scores and a reviewer about to
  spend fifteen minutes on a video call needs to know whether the case is
  borderline-at-79 or nowhere-near-at-40. They travel with `scoreScales` so the
  number is not read on the wrong scale.

### Crash reports / analytics
- No Crashlytics or Analytics SDK is present in `functions/`. Nothing in this
  service emits either.

---

## 4. Provider calls, cost, and order

Spec §7 item 4.

| # | Call | Cost (µUSD) | When |
|---|---|---|---|
| 1 | Cloud Vision DOCUMENT_TEXT_DETECTION — front | 1,500 | step 3 |
| 2 | Cloud Vision DOCUMENT_TEXT_DETECTION — back | 1,500 | step 3 |
| — | *gender gate* | 0 | **step 4 — a male card exits here** |
| — | *duplicate check* (1 Firestore read) | ~0 | step 5 |
| 3 | self-hosted liveness | 0 | step 6 |
| 4 | self-hosted face match | 0 | step 7 |

**Per successful verification: 3,000 µUSD = USD 0.0030.**
**Per male applicant: 3,000 µUSD, and zero liveness/match calls** (asserted by
test, not by intention).
**Worst case within the attempt limits: 12,000 µUSD = USD 0.012**, against the
USD 0.05 ceiling.

Vision's price was confirmed against Google's published pricing table on
2026-09-25: $1.50 per 1,000 units for units 1,001–5,000,000;
first 1,000 units/month free (not modelled — budgeting at list price and being
pleasantly surprised is the right direction to be wrong in).

### Compute, measured

Executed locally, `functions/.venv`, on Apple arm64. **These are not Cloud Run
numbers** — x86 Cloud Run will differ, and this is flagged rather than
extrapolated.

```
synthetic 12MP JPEG: 8984 KiB
model load (cold, once per instance): 0.035s
decode+downscale 12MP: 78.0 ms/image
YuNet detect @1024px: 18.1 ms/image
SFace embed: 8.2 ms/face
HMAC-SHA256 id_hmac: 0.9 us
```

For one verification (2 card images + 4 frames): ~6 decodes (468 ms worst case
at 12 MP, far less at realistic capture sizes), ~6 detections (108 ms), ~6
embeddings (49 ms). Call it 0.3–0.7 s of CPU, plus two Vision round trips.

At Cloud Run tier-1 rates (vCPU $0.000024/s, memory $0.0000025/GiB-s) and a
~2.5 s billed request at 1 vCPU / 1 GiB, compute is roughly **USD 0.00007 per
verification** — about 2% of the Vision line. **UNVERIFIED:** I could not
confirm whether `europe-west3` is Cloud Run tier 1 or tier 2; the Cloud Billing
API is disabled on this project and the pricing page would not yield the
regional table. Either way it is negligible against $0.003.

### At 50,000 verifications over six months

| Line | Amount |
|---|---|
| Cloud Vision (100,000 units) | **USD 150.00** |
| Cloud Run compute | ~USD 3.50 |
| Firestore (~6 ops/verification) | ~USD 2 |
| Secret Manager (cached per instance) | < USD 1 |
| **Total** | **~USD 157, or USD 0.0031 per verification** |
| Firebase phone-auth SMS | **UNKNOWN — D4** |

---

## 5. Third-party Flutter liveness bridge assessment

Spec §7 item 5.

| | |
|---|---|
| Package | `face_liveness_detector` |
| Version | 0.2.11 |
| Likes | 5 |
| Last publish | ~6 months before 2026-09-25 |
| Publisher | none named |
| Should we vendor it? | **No — should not be used at all** |
| Min iOS/Android | not assessed; moot |

**Not independently verified by me.** These figures come from the coordinator's
pub.dev search and are recorded as given.

**Assessment:** this is the only Flutter bridge for AWS Amplify Face Liveness,
and it holds the camera in a KYC flow. Five likes, six months stale and an
anonymous publisher is not an acceptable supply-chain position for that. The
realistic options were to vendor and maintain it ourselves (a real ongoing
cost), write a platform channel against the native Amplify SDKs, or not use AWS
liveness.

**Resolved:** the owner chose self-hosted liveness. The dependency is
eliminated, not mitigated. The risk traded for it is in RESIDUAL_RISKS #6.

---

## 6. Deliberate deviations from the spec

Recorded here so the gap table reads as decisions rather than misses.

1. **§4's flag evidence bundle: not implemented.** Owner's instruction — no
   image is stored, in any bucket, for any duration, for any case. It was built
   in full (bucket config, lifecycle rule, signed URLs, hourly purge, 72-hour
   RETRY_REQUIRED) and then **deleted rather than left behind a disabled flag**,
   because a dormant path that writes ID images to a bucket is what gets
   switched on by accident later. Consequence: human review is a live video call
   or a gym visit, not a desk review of a photograph. The queue was rebuilt
   around scheduling. Capacity arithmetic in RESIDUAL_RISKS #7.

2. **§2 steps 6-7's AWS providers: not implemented.** Owner's decision. The
   `LivenessProvider` / `FaceMatchProvider` interfaces remain so a future
   provider drops in, but no AWS class exists — an empty class that raises is
   still a class someone can wire up, and there is no AWS account to wire it to.

3. **§5's claim names.** Spec says "for example `vf: true`, `vstatus`". The
   existing 864 lines of `firestore.rules` already read
   `request.auth.token.verified` and `request.auth.token.coachV == 'active'`.
   Matching the existing file beats matching an illustrative example.
   Confirmed by the coordinator (D7).

4. **§3's four threshold values.** They are Rekognition units for a provider we
   will never call, and carrying them across would be a silent false-accept
   generator. `THRESHOLDS_REKOGNITION` is kept, marked never-active, purely so
   the scale guard has a second scale to refuse. The live numbers are on our own
   scales and are labelled as derived, not measured.

5. **§5's "deny all app data unless verified", with four named exceptions.**
   `users/{uid}`, consents, deletion requests and the safety collections escape
   the gate. Applied literally, §5 deadlocks sign-up: the verification flow
   writes `users/{uid}`, so requiring the claim to write it means the claim can
   never be earned. Confirmed by the coordinator (D6).

6. **`worst_case_micro_usd` returns 12,000, not spec §6's 44,000.** Same
   arithmetic, different inputs, because liveness and CompareFaces are now zero.
   The 50,000 ceiling is unchanged and still enforced.

---

## 7. Things I could not verify

Stated rather than estimated.

- **Firebase per-SMS price for Egyptian numbers** (§2 step 0). The Firebase
  limits page carries no pricing and defers to Identity Platform; the
  coordinator independently failed to get the regional table from either
  `https://firebase.google.com/pricing` or the Cloud Identity Platform pricing
  page. My web-search budget was exhausted. **D4.** It sits outside the µUSD
  ledger because the SMS is spent before `verify_identity` is ever called, and
  it could plausibly exceed everything else in the pipeline.
- **Whether `europe-west3` is Cloud Run tier 1 or tier 2.** Cloud Billing API
  is disabled on `own-hub` (`SERVICE_DISABLED`, confirmed by a real 403), and I
  did not enable it. Immaterial to the total.
- **AWS pricing** for Face Liveness and CompareFaces. Taken from the spec as
  given; no AWS account exists to check a bill against. Now moot.
- **The pub.dev metrics** for `face_liveness_detector`. Relayed, not measured.
- **Whether YuNet finds and SFace separates real faces.** No real face
  photographs are in this repo (rule of engagement 7). The models load, the
  geometry is tested exactly, and the detector correctly finds nothing in noise
  — but detection and separation accuracy on real Egyptian ID cards is spec
  §10's pilot and is **NOT EXECUTED**.
- **Anything about the live project's data.** `scripts/privacy_scan` runs clean
  against `own-hub`, but the project is empty (0 Firestore collections, 0
  Storage objects), so that result is a smoke test of the scanner, not evidence
  about privacy. The scanner's detectors are unit-tested separately (21 tests).
- **Git history secret scan** (§5). Not run.
