# Build brief — women-only fitness app, Egypt

This is the refined version of the build instruction. It is written to be handed to agents as-is.
It replaces a shorter instruction that asked for "an MVP in one session"; the substantive changes are
listed at the end under *What changed from the original instruction and why*.

---

## 0. The one decision that changes everything

**131 features is not an MVP.** The single most important input is which slice ships first, because
every stage below inherits it. Until this is decided, agents will either build everything badly or
stall.

**Recommended MVP cut — "she can train, log, and be safe":**

| In | Out of MVP (built later) |
|---|---|
| Sign-up + women-only ID verification (`C01`–`C16`) | Coaching marketplace + payments (`H01`–`H06`, `G01`–`G17`) |
| Client setup + starting program (`O01`–`O05`) | Coach app entirely (`K*`, `W*`, `B*`) |
| Today + logging (`T01`–`T08`) | Community (`M01`–`M17`) |
| Train + workout player (`R01`–`R13`) | My cycle (`Y01`–`Y14`) |
| Eat + logging (`E01`–`E09`) | The assistant (`X01`–`X03`, `K26`, `K27`) |
| Progress + rewards (`P01`–`P04`) | Splits, assessments, portfolio |
| Profile, privacy, Safety Centre (`A01`–`A04`) | Follow-up pictures, reels, stories |

That is **~55 screens of 161**, one role instead of two, and it still delivers the product's actual
promise: quiet workouts, Egyptian food, one-tap logging, and a room only verified women can enter.
Verification stays in because it is the product's reason to exist, not a feature.

**If the owner rejects this cut, stop and get the new cut before Stage 1.** Do not average the two.

---

## 1. Ground truth — what exists today

Read this before believing anything else.

- `6-v2/src/` — 161 screens as code. `inventory.mjs` is the screen register; `kit.mjs` is the
  component kit; `tokens.mjs` is the single source of colour, type, radius and motion.
- `6-v2/prototype/index.html` — the clickable prototype. Published at
  https://claude.ai/artifact/SsY7S53f9ZAHN5S9PMchbZ
- `6-v2/flutter/` — **generated handoff only, not an app.** `app_tokens.dart`, `app_routes.dart`
  (161 routes), `app_en.arb` / `app_ar.arb` (1,789 keys, exact parity), and `HANDOFF.md`, which
  carries the data records, 17 domain rules, the portfolio block schema and the assistant contract.
- `6-v2/i18n/msa/*.json` — the Arabic dictionary (Modern Standard Arabic), 13 files, merged to
  `ar.json`.
- `6-v2/review/ux-review-pass-2.md` — measured UX review: tap depth, journey traces, capability
  coverage.
- `6-v2/research/` — the cited evidence behind the non-negotiable rules.

**There is no `pubspec.yaml` and no Flutter application.** Stage 3 creates it.

---

## 2. Non-negotiable product rules

These came from cited research and a legal check, not taste. An agent that violates one has produced
a defect, not a variation. The full list is `HANDOFF.md` §"Rules the UI depends on"; the ones most
often broken by implementers:

1. **A prescribed value is never a result.** Actual entries start empty.
2. **A coach's message never changes a plan — publishing does.** There is no auto-publish anywhere.
3. **Weeks, not days.** No daily streak counter, ever. Rest weeks repair a missed week automatically.
4. **Suggestions follow symptoms she logged today, never an inferred cycle phase.**
5. **Severe symptoms replace the workout suggestion with medical guidance.**
6. **Face blur defaults to on** for every uploaded image, applied on-device before upload.
7. **ID and selfie images are deleted after verification.** Only the result is retained.
8. **No AI face-gender classification anywhere.** The gate is the national ID number's 13th digit.
   (*Tickle v Giggle*, Full Federal Court of Australia, May 2026.)
9. **Undo, not confirmation.** Five-second undo on every log; no "are you sure" dialogs for logging.
10. **The assistant selects, never generates.** It cannot invent an exercise, an ingredient or a
    quantity, and there is deliberately **no publish tool**.
11. **Nothing is ranked by weight, weight lost, or followers.**

---

## 3. Scale target, as numbers

"Scalable for 100k monthly active users" is not actionable. Design to these, and state the cost
envelope in the plan:

- 100,000 MAU, assume 35% DAU → **35,000 daily actives**.
- Per active day: ~8 reads, ~6 writes (sets, meals, check-ins). → **~280k reads / 210k writes a day**.
- Peak is Egypt evening, 19:00–23:00 Cairo: assume **40% of daily traffic in 4 hours**.
- Video: the single heaviest cost. 124 workout videos, assume 2 sessions/active/week at ~40 MB
  adaptive → **~11 TB/month egress**. Budget CDN accordingly and make download-for-offline a
  first-class feature, not a nice-to-have. Low-data mode is a launch requirement in Egypt.
- Budget ceiling the plan must respect: **state it as a monthly figure and justify the architecture
  against it.** If the design exceeds it, say so in the plan rather than at the end.
- Offline-first: logs must save without signal and sync later. This is not optional — it is how the
  product behaves on a Cairo microbus.

---

## 4. Platform policy

Feature parity by default. Build platform-specific code **only where the OS forces it**, and build
both sides when you do — never ship one platform a capability the other silently lacks:

| Capability | Android | iOS |
|---|---|---|
| Step/workout detection | Health Connect | HealthKit |
| SMS code autofill | SMS Retriever API | iOS AutoFill (no read permission) |
| Notification action for the meal nudge | Notification action button | Notification Content Extension |
| On-device face blur | ML Kit face detection | Vision framework |
| Store billing (if ever used) | Play Billing | StoreKit 2 |

Where a capability exists on only one platform, the other gets an explicit, designed fallback — and
QA tests the fallback, not just the happy path.

---

## 5. Stage 1 — test cases, before any code

Written first, on purpose. **But "all possible scenarios" across 161 screens is thousands of cases and
would consume the session.** Prioritise in this order and stop at the boundary of the MVP cut:

- **P0 — the journeys that are the product.** Full end-to-end, including failure and recovery:
  verification (pass / pending / niqab path / rejected), one-tap set logging, whole-move logging,
  "I already did it", usual-meal logging, voice meal logging, week counting and rest-week repair.
- **P1 — every rule in §2.** One test per rule, written so it *fails* if the rule is violated. These
  are the tests that protect the product from its own implementers.
- **P2 — state coverage per screen in the cut:** loading, empty, error, offline, long content,
  Arabic RTL, large text.
- **P3 — everything else.** Deferred, listed, not written.

**Format:** one row per case — `ID | priority | journey | precondition | steps | expected | rule it
protects | platform (both/android/ios)`. Machine-readable (CSV or a Dart test stub), because Stage 3
must be able to run them and Stage 4 must be able to check them off.

**Every P0 and P1 case must be an executable Flutter test by the end of Stage 3**, not a document.

---

## 6. Stage 2 — one planning agent per feature group

Feature groups for the recommended cut (one agent each):

1. Identity & verification 2. Onboarding & program selection 3. Today & logging
4. Train & workout player 5. Eat & food logging 6. Progress & rewards
7. Profile, privacy & safety 8. Platform foundations (offline sync, i18n/RTL, theming, analytics)

**Each planning agent must output, and will be rejected without:**

- Data model: collections/tables, fields, types, indexes, and the read/write pattern per screen.
- The query for every screen in its group, with the index it needs and its expected cost at the §3
  numbers.
- State machine for anything with more than two states (verification, a session, a sync record).
- Offline behaviour: what is writable offline, how conflicts resolve, what the UI shows while queued.
- Which §2 rules it owns, and where each is enforced — **domain layer, not widgets**.
- Security rules (Firestore rules or equivalent) as code, not prose.
- Explicit interface to the other groups: what it consumes, what it publishes.
- The P0/P1 test IDs from Stage 1 it is accountable for.
- Open questions it could not resolve, named — silence is not an answer.

**Scalability is a review gate, not a wish.** Reject any plan with an unbounded collection scan, a
per-user fan-out write that grows with followers, an unindexed query on a hot path, or a design that
needs a migration to reach 100k MAU.

---

## 7. Stage 3 — implementation agent, end to end

"End to end" means: Flutter UI + domain + data layer + backend + platform channels + the two stores'
build configuration. Not the frontend alone.

**Stack (decide once, record in the plan):**
- Flutter 3.x, Material 3, `useMaterial3: true`. Rubik for both scripts. `flutter_localizations`
  with the existing ARB files.
- Backend: **Firebase is the recommended default** — Auth (phone), Firestore, Cloud Functions,
  Storage, Remote Config, Crashlytics — because it removes an ops burden this team does not have, and
  phone auth in Egypt is first-class. Media goes behind a CDN, not straight out of Storage.
- **The Claude API key never ships in the app.** The assistant (post-MVP) calls Claude from a Cloud
  Function. `HANDOFF.md` §"The assistant" holds the contract.
- Analytics: Amplitude, with a tracking plan written *before* events are emitted.

**Order of work:** tokens and theme → localisation and RTL → routing → data layer + security rules →
offline sync → the P0 journeys screen by screen → platform channels → the rest of the cut.

**Rules for the implementation agent:**
- Generate from `tokens.mjs` and the ARB files; do not retype design values or strings.
- Every string through the localisation layer. No hardcoded English or Arabic in widgets.
- The §2 rules live in the domain layer with a test each.
- Commit in working increments with the app compiling at each one. A broken tree is not progress.
- When something cannot be finished, leave a `// TODO(owner):` with what is missing and why — never a
  silent stub that looks complete.

---

## 8. Stage 4 — QA agent

Compares the built app against **three** sources, not one:

1. **The prototype** — screen by screen for the cut, English and Arabic, both platforms.
2. **The feature list** (`features.mjs`) — does each in-scope feature actually do what it claims.
3. **The Stage 1 test cases** — every P0 and P1 executed, pass/fail recorded per platform.

Plus: tap-depth re-measured against the ≤2-tap target; Arabic RTL on every screen; offline behaviour;
large-text and screen-reader passes; and a specific check that **no §2 rule was violated** — that is
the section most likely to have quietly broken.

**Output:** a defect list ranked BLOCKER → NOTE, each with screen ID, platform, the rule or test it
breaks, and a reproduction. Verdict on whether the cut is shippable. **QA does not fix; it reports.**

---

## 9. Definition of done for the agent track

Done is not "code was written". Done is:

- `flutter analyze` clean, `flutter test` green, app builds for **both** an Android emulator and an
  iOS simulator.
- Every P0 and P1 test executable and passing.
- Every in-scope screen reachable, in both languages, with no hardcoded strings.
- Security rules deployed and tested against an unauthorised-read attempt.
- The QA report exists, with no unexplained BLOCKERs.
- A README a new developer can follow from clone to running app.

---

## 10. What the agents cannot do — the owner track

These block launch and **no amount of code removes them**. They are the content of the deployment
runbook that accompanies this brief:

- Apple Developer and Google Play accounts, and store review.
- Firebase/Google Cloud project on a billing account.
- ID verification contract (Valify or uqudo), the data-processing agreement, and PDPC registration.
- Payment rails (Fawry, mobile wallets, cards) — merchant onboarding with commercial registration.
- Amplitude account and tracking-plan approval.
- 124 workout videos and the recipe library — content production.
- Moderation staffing to meet the one-hour promise the Safety Centre makes on screen.
- Legal: minimum age (16 or 18), the written membership policy, and the privacy policy.

---

## What changed from the original instruction, and why

| Original | Refined | Why |
|---|---|---|
| "finish the project as an MVP in one session" | An explicit MVP cut, and an honest statement that the agent track ends at a runnable skeleton | The original had no scope boundary, so "done" was undefinable and the estimate impossible |
| "write all the test cases for all the possible scenarios" | P0–P3 prioritisation, executable by end of Stage 3, with a rule-protecting tier | "All scenarios" across 161 screens is thousands of cases; unprioritised it consumes the whole session and protects nothing in particular |
| "a planning agent for each feature group" | Named groups, plus a rejection contract each plan must satisfy | Without an output contract, plans come back as prose and the implementation agent cannot consume them |
| "in a scaleable way… 100k active users" | Concrete traffic, peak, egress and index requirements, and scalability as a review gate | "Scalable" is unfalsifiable; numbers are testable |
| "if something works only for android build it and do the same for ios" | A platform-capability table with a designed fallback where parity is impossible | The instinct was right; it needed to name the five places the OS actually forces a difference |
| "another agent to qa the output and compare it with the initial design" | QA compares against prototype **and** feature list **and** the test cases, and re-checks the product rules | Comparing to the design alone misses violated domain rules, which is where this product is most fragile |
| (absent) | The non-negotiable rules restated for agents | They are the product. An agent that has not read them will violate them innocently |
| (absent) | The owner track, separated out | Several launch blockers are accounts and contracts, and mixing them into "build the MVP" makes the plan undeliverable |
