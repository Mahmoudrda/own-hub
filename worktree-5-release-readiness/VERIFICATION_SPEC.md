# VERIFICATION_SPEC.md
## Egyptian National ID + Face Verification: Audit, Harden, Test, Ship

**Owner-issued acceptance standard, received 25 September 2026. This is the
authoritative text, not a summary of it.** Where this spec and any earlier
build brief disagree, this file wins. Do not overwrite this file; per-worker
notes on what changed belong in `VERIFICATION_SPEC_DELTA.md`, and anything
escalated belongs in `DECISIONS_NEEDED.md`.

Do not trust anything that was previously said about the build, including your
own earlier messages. Only code, configuration, and executed test output count
as evidence.

---

## 0. Rules of engagement (read first, follow always)

1. Evidence over claims. Never write "tested", "works", or "done" for anything you did not execute. Paste the command and the relevant output into the report.
2. Never weaken a test, a security rule, or a threshold to make something pass. If something cannot pass, report it.
3. Never make the client the source of truth for any verification outcome. The app displays status; only the server decides it.
4. Never classify gender from a face. Do not call any face attribute or gender prediction API (including Rekognition DetectFaces gender attributes) or any on-device gender model. Gender comes only from the ID card.
5. Never invent a checksum for the 14th digit of the Egyptian national ID. Its algorithm is not public. Do not validate it. Any code that rejects IDs based on a guessed checksum must be removed.
6. Never log, persist, cache, or send to analytics any of these: ID images, selfie images or video, the raw 14-digit ID number, names, addresses, birth dates. Section 4 lists the only things that may be persisted.
7. Test fixtures use synthetic ID numbers only. Never commit real people's ID numbers or images.
8. If you hit a trigger in Section 13, stop and write it to `DECISIONS_NEEDED.md` instead of improvising.

---

## 1. Product requirements (non-negotiable)

- Only women may create an active account. Women are determined by the Egyptian national ID card.
- Verification happens once, at signup, and a user cannot use the app before it completes.
- Verification confirms three things:
  - (a) the card is an Egyptian national ID showing a female holder;
  - (b) a live human is present, not a photo, screen, video, or mask;
  - (c) that live human is the person pictured on the card.
- One national ID can back only one active account.
- No identity data is stored after the decision, except what Section 4 explicitly allows.
- Borderline or inconsistent cases are flagged to the admin for review, not silently approved or silently rejected.
- Maximum provider spend per user: USD 0.05, enforced server-side.
- Minimum age: `MIN_AGE` config, default 18, derived from the birth date encoded in the ID number.
- Bilingual UI (Arabic with correct RTL, and English) for every screen in the flow.

---

## 2. Reference pipeline (audit the current build against this)

The order matters. Cheap checks run before expensive ones, so a male applicant is rejected for about USD 0.003 before liveness is ever paid for.

**Step 0: Account first.** The user signs in with a free method (email link, Google, or Apple) before any paid step, so every cent of spend is tied to a uid. If the current build uses Firebase phone auth, report the per-SMS cost for Egyptian numbers in `AUDIT.md`.

**Step 1: Consent.** Show an explicit consent screen (Arabic + English) before any camera access. It must state:
- what is captured;
- that it is processed by Google Cloud and AWS outside Egypt;
- that nothing is kept for approved or rejected users except a one-way keyed hash of the ID number;
- that flagged cases keep encrypted evidence for up to 72 hours for manual review, then it is deleted.

The user must actively agree. Persist a consent record containing uid, consent version, and timestamp, and nothing else.

**Step 2: Card capture, on device, free.**
- Capture front and back of the card with the live camera only. Disable gallery or file upload.
- On device, check that a card-shaped object is framed, that there is no heavy blur or glare, and that exactly one face is present on the front (ML Kit face detection is fine for this, since it is detection and not recognition).
- Reject bad captures locally with guidance. This costs nothing.

**Step 3: OCR and parsing, server-side, about USD 0.003.**
- Send both images to a callable Cloud Function (2nd gen) in memory. Never write the images to Cloud Storage, Firestore, or disk.
- Run Google Cloud Vision `DOCUMENT_TEXT_DETECTION` on both sides. ML Kit on-device text recognition does not support Arabic script; if the build uses it for the ID number, that is a critical defect.
- Parse the ID number:
  - Normalize Eastern Arabic digits (U+0660 to U+0669) and Persian digits (U+06F0 to U+06F9) to ASCII 0 to 9.
  - Extract exactly one 14-digit sequence. If the number appears on both sides, both reads must agree.
- Validate the structure (use the rules below):
  - Digit 1 is the century: 2 means 1900 to 1999, 3 means 2000 to 2099. Anything else is `STRUCTURE_INVALID`.
  - Digits 2 to 7 are YYMMDD and must form a real calendar date, not in the future.
  - Age from that date must be at least `MIN_AGE`, otherwise `UNDERAGE`.
  - Digits 8 to 9 are the governorate code. Known codes: 01, 02, 03, 04, 11, 12, 13, 14, 15, 16, 17, 18, 19, 21, 22, 23, 24, 25, 26, 27, 28, 29, 31, 32, 33, 34, 35, 88. An unknown code is a FLAG signal, not a rejection, because the list may be incomplete.
  - Digit 13 is gender: even means female, odd means male.
  - Digit 14 is not validated (see Rule 5).
- Read the gender word printed on the back (أنثى means female, ذكر means male) as an independent signal.
- If the printed birth date is readable, cross-check it against the date encoded in the number.
- Do not extract or keep the name, address, religion, or marital status. They are not needed.
- Card expiry does not block verification in this product.
- OCR failures (no 14-digit read, sides disagree, unreadable back) return `RETRY_CAPTURE`, up to the attempt limits in Section 6.

**Step 4: Gender gate, before paying for liveness.**
- If digit 13 is odd, reject immediately as `REJECTED_NOT_ELIGIBLE`. Make no further paid calls.
- If digit 13 and the back gender word disagree, record a FLAG signal and continue.

**Step 5: Duplicate check.**
- Compute `id_hmac = HMAC-SHA256(national_id, ID_PEPPER)`. Keep `ID_PEPPER` in Secret Manager and version it (store `pepper_version` next to the hash).
- If `id_hmac` is already bound to another active account, return `REJECTED_DUPLICATE` with a support path.
- The raw number is discarded from memory after this step.

**Step 6: Liveness, about USD 0.015.**
- The server calls `CreateFaceLivenessSession` with the AWS SDK, bound to the uid, with a short TTL mapping `sessionId -> uid`.
- Do not configure an S3 output bucket. Minimize or disable audit images if the API allows.
- The client runs the Amplify Face Liveness native component through a Flutter bridge. Credentials come from a Cognito identity pool whose role allows only `rekognition:StartFaceLivenessSession`.
- The server calls `GetFaceLivenessSessionResults`. Reject the session if:
  - it belongs to another uid;
  - it was already consumed;
  - its status is not `SUCCEEDED`;
  - it is older than the allowed window.
- The reference image used for face matching must come from this server-side call, never from the client.

**Step 7: Face match, about USD 0.001.**
- Call `CompareFaces` with Source = liveness reference image and Target = the ID front image, with a low `SimilarityThreshold` so you receive the score.
- Take the best match. If no face is detected on the card, return `RETRY_CAPTURE`.

**Step 8: Decision (Section 3), then cleanup.**
- Set Firebase custom claims with the Admin SDK and force a token refresh on the client.
- Delete all in-memory image buffers and the ephemeral session doc.

**Expected provider cost for one full attempt:** 2 Vision units (about 0.003) + liveness (0.015) + CompareFaces (0.001) = about USD 0.019.

---

## 3. Decision matrix

All thresholds live in server-side config (a Firestore config doc readable only by the Admin SDK, or function env). Never use Remote Config or client code for thresholds. The starting values below are not final; Section 10 tunes them.

| Outcome | Conditions |
|---|---|
| `APPROVED` | Digit 13 even, AND back gender word female, AND no FLAG signals, AND liveness confidence >= `LIVENESS_PASS` (start 90), AND similarity >= `MATCH_PASS` (start 90) |
| `PENDING_REVIEW` (flag) | Any FLAG signal. See the list below. |
| `REJECTED_NOT_ELIGIBLE` | Digit 13 odd, or `UNDERAGE` |
| `REJECTED_FAILED` | Liveness confidence < `LIVENESS_FLAG` (start 70), OR similarity < `MATCH_FLAG` (start 75), after the allowed attempts are used |
| `REJECTED_DUPLICATE` | `id_hmac` already bound to an active account |
| `RETRY_CAPTURE` | Capture or OCR quality problem, within attempt limits |

FLAG signals (any one of these sends the case to `PENDING_REVIEW`):
- digit 13 and the back gender word disagree;
- the back gender word is unreadable after retries;
- the printed birth date disagrees with the encoded date;
- the governorate code is unknown;
- liveness confidence is between `LIVENESS_FLAG` and `LIVENESS_PASS`;
- similarity is between `MATCH_FLAG` and `MATCH_PASS`;
- the same `id_hmac` has had more than 2 failed liveness or match attempts across any accounts;
- the same app install has attempted more than 2 different `id_hmac` values.

User-facing messages are coarse and neutral: "Verified", "Under review", "Verification unsuccessful", "Please retake the photo". Never expose scores, reason codes, or which check failed, because that teaches bypass.

---

## 4. Data handling allowlist

Persisting anything outside this list is a defect.

| Data | Where | Retention |
|---|---|---|
| `id_hmac` + `pepper_version`, bound to uid | Firestore, Admin-only collection | Life of the account. Deleted on account deletion unless the account was banned. |
| Verification status, reason codes, scores, attempt counts, cost ledger, timestamps | Firestore, Admin-only | Life of the account |
| Consent record (uid, consent version, timestamp) | Firestore, Admin-only | Life of the account |
| Ephemeral session state (uid, stage, `sessionId`, attempt counters). No images, no raw ID. | Firestore with a TTL policy, plus explicit delete on completion | Maximum 1 hour |
| Flag evidence bundle: ID front image + liveness reference image + scores. FLAGGED CASES ONLY. | Dedicated private Cloud Storage bucket, uniform access, no public access, encrypted, lifecycle delete, plus an hourly scheduled function deleting objects older than 72 hours | Maximum 72 hours |

Things that must never exist anywhere: raw ID numbers, names, addresses, birth dates, back-of-card images, liveness video, selfies of approved or rejected users, OCR text dumps, and image bytes in logs, Crashlytics, Analytics, or error payloads.

AWS AI services opt-out: Face Liveness may retain selfie video to improve the service unless the account opts out. Configure an AWS Organizations AI services opt-out policy covering Rekognition, attach it, and record proof (policy JSON + attachment) in the report.

---

## 5. Security requirements

- Verification status and eligibility live in custom claims (for example `vf: true`, `vstatus`), set only by the Admin SDK.
- Firestore and Storage security rules:
  - deny all client writes to verification, consent, hash, flag, and config data;
  - deny all app data reads and writes unless `request.auth.token.vf == true`;
  - admin-only paths require an `admin` claim.
- Firebase App Check is enforced (Play Integrity on Android, App Attest on iOS) on every callable function in the flow. Debug providers are only allowed in dev builds.
- Every callable function checks auth, App Check, the attempt limits, and the cost ledger before doing any work.
- Callable functions are idempotent. A double tap or retry must not double-charge or create duplicate sessions.
- A liveness `sessionId` is single-use and uid-bound. Replaying a successful session from another uid must fail.
- Least-privilege IAM:
  - the server-side AWS principal gets only `CreateFaceLivenessSession`, `GetFaceLivenessSessionResults`, and `CompareFaces`;
  - the Cognito role gets only `StartFaceLivenessSession`;
  - the GCP service account gets only Vision + the needed Firestore/Storage roles.
- Secrets (AWS keys, `ID_PEPPER`, webhook URLs) live in Secret Manager via Firebase function secrets. There are no secrets in the Flutter app or in the repo. Scan the git history too and report findings.
- Release builds use `--obfuscate --split-debug-info`.
- App Store and Play review: create a reviewer account that is marked verified by a server-side allowlist of specific uids, configurable and removable. Never use a client flag or a hidden gesture.

**Admin review flow:**
- Flags are written to a `verification_flags` collection (reason codes, scores, flag id, uid, timestamps; no PII).
- A notification with only the flag id and reason codes is POSTed to `FLAG_WEBHOOK_URL`.
- An in-app admin screen, visible only with the `admin` claim, lists flags. It opens evidence through an admin-only callable that returns a signed URL valid for 5 minutes and writes an access log entry.
- The admin approves or rejects. The server sets claims and deletes the evidence immediately.
- Flags not decided within 72 hours: evidence is purged and the user is moved to `RETRY_REQUIRED` (one fresh attempt, still within the cost cap).

**Account deletion:** removes the user's docs, claims, `id_hmac` binding (unless banned), and any flag evidence.

---

## 6. Cost control

- Keep a per-uid cost ledger in micro-USD:
  - Vision: 1,500 per image;
  - Liveness: 15,000;
  - CompareFaces: 1,000.
- Before every paid call, refuse if `spent + next_call_cost > 50,000`.
- Attempt limits per uid: maximum 4 OCR submissions (front + back pairs) and maximum 2 liveness attempts. Worst case is 4 x 3,000 + 2 x 16,000 = 44,000, which is under the cap.
- Global kill switch: `DAILY_VERIFICATION_LIMIT` in server config. When exceeded, new sessions get "try again later" and an alert is sent.
- Configure spend alerts: AWS Budgets on Rekognition, and a GCP budget alert on the Firebase project. Record their configuration in the report.
- Report the measured cost per verification from real runs (Section 10), not the theoretical number.

---

## 7. Phase 1: Audit (no code changes yet)

Produce `AUDIT.md` containing:

1. An architecture map of what actually exists: screens, functions, providers, packages (with versions), Firebase config, security rules, and every place data is written.
2. A gap table: every requirement in Sections 1 to 6 with the columns Requirement | Status (Met / Partial / Missing / Violated) | Evidence (file:line or command output) | Fix plan.
3. A data-flow trace: for each piece of identity data, where it enters, every place it travels, and every place it could persist, including logs, crash reports, analytics, and provider-side retention.
4. The list of provider calls with the cost of each and the order they happen in.
5. A third-party Flutter liveness bridge assessment: package name, version, last publish date, open issues, whether you should vendor it, and its minimum iOS/Android versions.
6. A critical-defects summary at the top, ranked.

---

## 8. Phase 2: Fix

- Fix every Partial, Missing, and Violated item.
- Keep provider calls behind interfaces (`OcrProvider`, `LivenessProvider`, `FaceMatchProvider`) so they can be mocked in tests and swapped later.
- Keep the ID parser as a pure, dependency-free module with no I/O, so it is fully unit-testable.
- One commit per logical fix, with messages referencing the gap table row.

---

## 9. Phase 3: Test

All automated tests run in CI with a single command, documented in the README.

**9.1 Unit tests for the ID parser (minimum 40 cases).** Cover:
- valid female and male numbers;
- Eastern Arabic, Persian, and mixed digits;
- 13 and 15 digit inputs;
- spaces and line breaks inside the number;
- two different 14-digit sequences in one OCR blob;
- century 1 and 4;
- month 00 and 13;
- 29 Feb in leap and non-leap years;
- 31 April;
- a future date;
- the `MIN_AGE` boundary (birthday today, tomorrow, yesterday);
- governorate 88, 20, and 99;
- a back gender word that is present, absent, or contradictory;
- a printed birth date that disagrees.

**9.2 Decision matrix tests.** Every row and every FLAG signal in Section 3, including values at exactly each threshold.

**9.3 Security rules tests** using `@firebase/rules-unit-testing` on the emulator. Prove that:
- a client cannot write any verification field, claim-like field, hash, flag, or config;
- an unverified user cannot read or write app data;
- a non-admin cannot read flags or evidence;
- a verified user can use the app.

**9.4 Function integration tests** on the emulator with mocked providers. Cover:
- the happy path;
- male early exit, asserting that zero liveness or CompareFaces calls were made;
- duplicate `id_hmac`;
- replay of a `sessionId` from another uid;
- a consumed session;
- a missing App Check token;
- a missing auth token;
- the cost cap, asserting that the call after the cap is refused before hitting the provider;
- attempt limits;
- idempotent double submit;
- provider timeout and 5xx, where the user gets retry and no charge is recorded for failed calls;
- the flag path, where evidence is written, the webhook fires, and the admin decision sets claims and deletes evidence;
- 72-hour expiry purges evidence and moves the user to `RETRY_REQUIRED`.

**9.5 Privacy tests.** After running the integration suite and the live smoke test:
- scan every Firestore collection, every Storage bucket, and Cloud Logging for the test window;
- assert there are no 14-digit sequences (ASCII or Eastern Arabic), no JPEG/PNG magic bytes or base64 image payloads outside the flag bucket, and no Arabic name strings from test cards;
- assert the flag bucket is empty after the purge job runs.

Ship this scan as a reusable script (`scripts/privacy_scan`).

**9.6 Live smoke test** against real Vision and Rekognition in the staging project, using consenting team members' real cards. Record only scores and outcomes, never images, in the report.

**9.7 Device end-to-end tests.** Automate with `integration_test` where possible. Anything you cannot run yourself goes into `MANUAL_QA.md` as a checklist with exact steps and expected results, for a human to execute. Required coverage:
- a low-end Android (2 to 3 GB RAM);
- a mid-range Android;
- the oldest supported iOS version;
- a current iPhone;
- Arabic and English locales;
- low light and strong glare;
- airplane mode mid-flow;
- killing the app during liveness;
- denying and then granting camera permission.

**9.8 Adversarial tests.** Add these to `MANUAL_QA.md`; each needs a pass/fail result before launch:
- a man with his own card;
- a man with a consenting female colleague's card;
- a printed photo held up to liveness;
- a video of a woman replayed on a phone screen;
- the ID shown on a screen instead of the physical card;
- a photocopy of the ID;
- a modified client that sends "approved";
- two accounts with the same card;
- a woman whose card photo is many years old;
- glasses;
- hijab;
- niqab flow (the copy must explain, respectfully, that the face must be visible privately for a few seconds and nothing is stored).

---

## 10. Phase 4: Pilot and threshold tuning

Before production, run a staging pilot with consenting participants:
- at least 50 genuine female verifications across the device matrix;
- at least 20 male attempts with their own cards;
- at least 20 impostor attempts (a male face with a consenting female card);
- at least 20 spoof attempts (print, screen replay, video).

Report in `VERIFICATION_REPORT.md`:
- a confusion matrix;
- the false accept rate, false reject rate, and flag rate;
- score distributions for liveness and similarity per group;
- measured cost per verification (mean and max);
- median time to complete.

Tune `LIVENESS_PASS`, `LIVENESS_FLAG`, `MATCH_PASS`, and `MATCH_FLAG` from this data. The goals, in priority order:
1. zero false accepts in the impostor and spoof groups;
2. a false reject rate for genuine women under 5%;
3. a flag rate under 10%.

State the final thresholds and the reasoning. If the goals conflict, choose fewer false accepts and report the trade-off.

---

## 11. Phase 5: Production readiness checklist

Each item needs evidence in the report.

- Separate dev, staging, and prod Firebase projects and AWS environments. There is no shared secret between them.
- The AWS region chosen for Face Liveness is verified to support it, and the processing regions for AWS, Vision, and Functions are documented.
- The AWS AI services opt-out policy is attached and verified.
- App Check is enforced in prod, and the debug provider is absent from release builds.
- Budget alerts, the daily kill switch, and the flag webhook are tested end to end.
- Crashlytics and Analytics are verified to carry no PII (inspect real payloads from a test run).
- Camera permission strings exist in Arabic and English. Any required iOS privacy manifest entries are present.
- `STORE_DISCLOSURES.md` contains drafted answers for Apple privacy labels and the Google Play Data safety form that accurately describe processing without retention, the 72-hour flag evidence, the keyed hash, and third-party processors.
- The App Store and Play reviewer account works and is documented.
- `PRIVACY_NOTICE_DRAFT.md` contains the consent and privacy text for legal review, in Arabic and English, covering purpose, processors, cross-border processing, retention, and user rights (access, correction, withdrawal, deletion).
- Account deletion is verified to remove everything specified in Section 5.
- Minimum OS versions are set to what the liveness bridge requires, and documented.
- A rollback plan exists: how to disable new verifications without breaking existing verified users.

---

## 12. Deliverables and definition of done

Deliverables in the repo:
- `AUDIT.md`
- `VERIFICATION_REPORT.md`: what changed, test results with command output, pilot results, final thresholds, measured costs, and checklist evidence
- `MANUAL_QA.md`: with results filled in, or clearly marked NOT EXECUTED
- `RESIDUAL_RISKS.md`
- `STORE_DISCLOSURES.md`
- `PRIVACY_NOTICE_DRAFT.md`
- `DECISIONS_NEEDED.md`: empty if none
- `scripts/privacy_scan`

`RESIDUAL_RISKS.md` must at least cover:
- a forged card carrying a man's photo and an even 13th digit;
- a verified account being handed to someone else after signup;
- provider outages;
- threshold drift;
- dependence on a third-party Flutter liveness bridge.

Done means all of the following are true:
- every row in the gap table is Met;
- all automated tests pass in CI;
- the privacy scan is clean;
- the adversarial checklist has no failures;
- pilot goals are met or the trade-off is documented;
- measured worst-case cost per user is at or below USD 0.05;
- `DECISIONS_NEEDED.md` is empty or explicitly accepted by the owner.

Anything short of this is reported as NOT READY, with the blocking items listed first.

---

## 13. Stop and escalate triggers

Write to `DECISIONS_NEEDED.md` and stop work on that item if any of these happen:
- the current build depends on a provider not in this spec;
- any path would exceed USD 0.05 per user;
- Face Liveness is unavailable in a suitable region;
- the Flutter liveness bridge cannot be made to work reliably on both platforms;
- a requirement here conflicts with a platform policy;
- pilot results cannot reach zero false accepts without a false reject rate above 15%;
- you find evidence that real identity data was already persisted somewhere. Report it immediately, including where and how much.
