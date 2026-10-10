# Idea Council report: Own Hub, 2 to 3 October 2026

Branch `council/2026-10-02`. Local only (this repo ignores `*.md`). Nothing pushed, nothing deployed.

## 1. Confirmed brief

Own Hub is a women-only fitness app for Egypt, in Arabic (MSA) and English. She signs up with her phone number and is verified as a woman with her Egyptian national ID and a live selfie. She then gets a weekly training plan, meals built from Rahma Mohsen's real recipes, and cycle and progress tracking, with her data kept private.

- **Money:** free at launch. A paid Pro is planned 3 to 4 weeks later at about EGP 99/month or EGP 699/year (unvalidated).
- **First session:** install, sign up by SMS, get verified (or routed to a woman reviewer), answer four setup questions, get her week, start day 1, log a meal.
- **Customer evidence:** none yet. The forecast is 10,000 users in 2 months.
- **Constraints:**
  - Both stores at once; neither store account is ready yet.
  - Sign-up and verification must be live.
  - Firebase stays in europe-west3, with App Check enforced.
  - Verification must cost at most USD 0.05, and images are never stored.
  - The PDPL 151/2020 lawyer must sign off.

## 2. Core value and Protected List

**Core value:** "I join a space that is truly women only, because every member proved it with her ID and a live selfie, and my ID and face photos are never kept. From day one I get training that fits me, Rahma's real recipes, and cycle and progress tracking that stay private."

**Protected List (unchanged by every fix):**
1. No ID or selfie image is ever stored.
2. The server decides; the client is never trusted.
3. The verified claim is merged into existing claims, never replaces them.
4. The whole-app gate is fail-closed.
5. Consent comes before any camera.
6. Account and onboarding stay open while unverified, so she can export and erase.
7. The sex gate runs before any paid call, with only coarse reasons shown.
8. Cost and abuse rails.
9. Human review is a live encounter with a woman reviewer.
10. europe-west3 and App Check enforced.
11. Local-first personal data.
12. Rahma's recipes and the owner's art.
13. No paywall can lock anything without a payment rail.
14. The admin console and testing aids are compiled out of release builds.

## 3. Fixed

Every item below was verified by a test that failed first, plus the final full QA (section 7).

| ID | What changed | Commits |
|---|---|---|
| S1, S21 | Consent contract aligned; honest error on C09b; record_consent is a no-op when consent already exists | 5fde6b0, b53b411 |
| S2 | App Check on the client (Play Integrity, App Attest); refusals reach the app as app_check_missing | 64c1a66, 497744b, 2136929 |
| S22 | A release build without the keystore fails instead of debug-signing | dcc2948 |
| S13, S16 | Review-queue indexes; TTL fields; records expire after a decision | 269da59, 952b323 |
| S3, S8, S12, S19 | Real review loop: request_review after a consent sentence; a reviewer tool on her own login; phone released per flag and logged; server-written verification state read at start-up; install and operation ids; hardened, transactional decisions; mint retry | ccf663d, 2847f44, 80309a6, 4564677, aaf5492, c92b87d, 2135853 |
| S4 | Real server deletion: journal, sweeper, second sweep, client stops writes first, gate closes after | 952b323, 0f1c955, d6cb5c4, eab0c55, 2a91fa3 |
| S17 | Health data local by default; opt-in backup with its own consent; rules refuse without it | d7166aa, 5fab902, f073120, ce26560 |
| S9 | Privacy manifest, Play Data safety, 5 Android permissions removed, false provider claim removed, website rewritten (EN and AR) | b24abbb, dd3f284, 28f5ead, 083b504 |
| S6, S7 | Per-uid caps before the sharded global counter; one open flag; REJECTED_FAILED goes to review; booking SLA | f0ee312, 981d57d, b5101ba, 70016a1 |
| S14 | Structured logs with no personal data; alert policies; Crashlytics with no identifier and no messages | beafa61, b8349fb, 3088611 |
| N1 (loop 3) | Only phone sign-in accounts may use the women-facing functions or write their data | fd415b7 |
| R1, N2, N5, N6 | Verified woman offline is not locked out; a fresh claim is the truth; the remembered flag is bound to the uid; stale reads dropped; no Android backup | 0bbedc5, 32787f4, 2554789, 28668cd |
| P1, P2, P3 | No screen promises a feature that is switched off (11 screens, EN and AR, each promise returns when its flag is turned on); the real OWN HUB mark on the welcome screen; the pending health withdrawal is bound to one account | 76b136a, 5eda870, 8c5cc59 |
| G4, G6 | Home after setup; no coach role while coaching is off | b6e0e9a, 32de4a2 |

## 4. Still open (ranked)

1. **N4: deleting the account and signing up again resets the abuse limits.** Not fixed: closing it means keeping a hashed phone number after deletion, which needs the owner's decision and a legal basis from counsel.
2. **N7: reviewer accounts are password only.** Not fixed: two-factor sign-in needs Identity Platform; this is an owner console step.
4. **S15: capacity is not load-tested.** Not fixed: to be measured during the closed test.
5. **S20: Pro has no payment path.** Not fixed: deliberate; build it only after the price test.
6. **S23: iOS SMS always shows reCAPTCHA.** Not fixed: needs the Apple account and an APNs key.
7. **The C16 pledge is still written for a community (owner's call).** It promises no switched-off feature, so it was left as is.
8. **The lock-screen nudge preview shows a placeholder icon (Low).**

## 5. Out of Code (real-world tests)

- **Play account and the 14-day closed test.** Recruit 20 testers today. If fewer than 12 are active by day 3, recruit again. The store date is day 14 or later.
- **PDPC permit.** Ask the lawyer this week whether an individual Permit covers the app. If no permit is possible, launch only a capped cohort.
- **Lawyer sign-off** on the proposed policy, terms and in-app consent wording. If counsel says a company is needed, form it first.
- **Pilot.** The 11 adversarial tests and 30 women during the closed test. If any man is verified, do not open sign-up.
- **Reviewers.** Run 10 timed mock calls, then size the team as minutes per call × flag rate × daily sign-ups.
- **SMS.** Allow +20 numbers only, turn on fraud protection, and test on Vodafone, Orange, e& and WE.
- **Recipes.** Rahma signs off allergens on all 39.
- **Demand.** A 7-day waitlist before the store date. Then a Pro price interview with 20 users in weeks 2 to 3.

## 6. Assumptions the code makes about customers that nobody has verified

- She accepts being locked out until phone, ID and selfie are done.
- She owns a readable Egyptian ID and is 18 or older.
- She will answer an unknown call from a reviewer.
- Flag rate 8 to 27% (modelled).
- A 72-hour review SLA and bookings within 7 days are acceptable.
- 6 starts and 6 submissions a day are enough.
- Health backup off is the right default.
- MSA rather than Egyptian Arabic.
- EGP 99/699 for Pro.
- 10,000 users in 2 months.

## 7. Final QA (merged branch)

Final run on the merged branch (HEAD 8c5cc59):

- **Backend pytest:** 712 passed.
- **Security rules:** 280 of 280 passed, run on separate emulator ports.
- **App:** flutter analyze clean; flutter test 4,577 passed.
- **Release preflight:** 47 passed. The only failures are the owner-supplied team id and legal links.
- **Release build:** the arm64 split APK is 40.7 MB and signed with the release key. Its only permissions are CAMERA, INTERNET, ACCESS_NETWORK_STATE, READ_GSERVICES and WAKE_LOCK.
- **Release APK on the emulator:** cold start with no crash; welcome, language and phone screens checked visually.
- **Process:** the council's Skeptic re-audited the diff three times (loops 1 to 3, one more than the protocol's limit because loop 2 found a Critical issue). The last pass found no Critical issues; its one High (N1) was then fixed and verified by the tests above.

## 8. Follow-up, 4 October

Done since the report above:
- **Firestore recipe reader:** recipes update without shipping a new app version.
- **Image decoding:** checked from the file header before any decode.
- **Deletion:** now also covers community, coach and assistant data.
- **Waitlist:** a page and its backend.
- **Crash symbols:** the release build script keeps them aside for upload.
- **Lock-screen preview:** shows the real brand mark.
- **SMS price:** found, USD 0.13 per SMS to Egypt.
- **Launch pack:** written to docs/release/launch-pack.

Final run:
- **Backend:** pytest 845.
- **Rules:** 289/289.
- **App:** analyzer clean, 4,611 tests passing.
- **Preflight:** 51 passed. The only failures are the team id and the legal links.
- **Release build:** the obfuscated build via tool/build_release.sh gives an AAB of 80.1 MB and an arm64 APK of 39.2 MB.
- **Emulator:** cold start in 1.7 s with no errors.

Still open:
- **Test-account pre-verification tool for store reviewers.** It was blocked by the permission system and is waiting on the owner's explicit approval.

## 9. Engineering closed, 4 October

Done:
- iPhone release build compiles.
- Store screenshots (EN and AR) generated by a test.
- Arabic mid-set screen and Rahma's text direction fixed.
- Complete deletion: storage, counters, late reports, paged scans.
- Storage rules with tests.
- Waitlist limits tuned for carrier NAT.
- Stable hand-drawn seeds under obfuscation.
- Recipe cache wiped on deletion.

Final checks:
- 4,628 app tests.
- 893 backend tests.
- 289/289 Firestore rules.
- 11/11 Storage rules.
- Preflight 51 passed. The only failures are the team id and the legal links, which need owner values.

No engineering items remain. Deploy-day steps run when the owner says "deploy".
