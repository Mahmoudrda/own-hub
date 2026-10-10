# Phase 2 — acceptance

Every P0 and P1 case from `TEST-CASES.csv` whose **primary flow** is a Phase 2
screen (E01–E09, P01–P04, A01–A04, Y01–Y14).

**34 cases: 27 P0, 7 P1.**

**Phase 2 is not done until each is an executable, passing test** — not a
document someone has read. Judge each PASS / FAIL / NOT COVERED. "Not covered"
is a real result and must be reported, never rounded up to a pass.

Community, Coaching, the coach application, the portfolio builder, the planning
tools and the Assistant are deliberately **excluded**: those are phase 3, and
listing them here would produce guaranteed failures that teach people to ignore
the suite.

Two notes on the filter. The `scope` column still reads `Post-MVP` on all 63
cycle rows — a vocabulary `DECISIONS.md` D1 withdrew, and `README.md` says not to
filter on it. It was not used. And `P0-NAV-01` / `P0-A11Y-01` carry the literal
screens value `all in-scope`; they are counted in, scoped to the 31 screens
above, exactly as Phase 1 counted them.

| Flow | Screens | P0 | P1 |
|---|---|---|---|
| Eat & food logging | E01–E09 | 6 | 0 |
| Progress & rewards | P01–P04 | 1 | 0 |
| Profile, privacy & Safety Centre | A01–A04 | 1 | 0 |
| My Cycle | Y01–Y14 | 17 | 7 |
| Cross-cutting | all in-scope | 2 | 0 |

The distribution is lopsided and worth naming: **Cycle carries 24 of 34 cases**,
while Progress and Profile carry one each — yet P01 is the completion point for
nine Phase 1 cases and A02 holds the single hardest case in the product
(`P0-DEL-01`). Case count is not a proxy for effort here.

## Cases that reach beyond Phase 2

Verify the Phase 2 half. Mark the rest **not yet reachable** — not failed.

| ID | reaches | which is |
|---|---|---|
| `P0-CYC-03` | T01 | Today (phase 1 — built, so this one is fully verifiable) |
| `P0-CYC-13` | G02 | Support and sharing (phase 3) |
| `P0-CYC-14` | W02, W09 | Coach planning tools (phase 3) |
| `P1-CYC-03` | G02, W02 | Coached + coach planning (phase 3) |

## Cases owned by another phase that land on a Phase 2 screen

Listed so nothing is silently dropped. These are **not** Phase 2's to pass, but
Phase 2 is what makes them completable.

**Phase 1 cases whose remaining half becomes reachable in Phase 2.** These are
the eleven rows `PHASE1-ACCEPTANCE.md` marked "not yet reachable". Re-run them
at the end of Phase 2; they are the real proof that the week and logging
machinery joined up.

| ID | Phase 1 primary | reaches |
|---|---|---|
| `P0-FR-01` | T06 | E09 |
| `P0-LOG-09` | T01 | E01 |
| `P0-LOG-12` | T02 | P01 |
| `P0-RWD-01` | R10 | P01 |
| `P0-RWD-02` | R10 | P01 |
| `P0-WEEK-01` | T01 | P01 |
| `P0-WEEK-02` | T04 | P01 |
| `P0-WEEK-03` | T05 | P01 |
| `P0-WEEK-04` | T04 | P01 |
| `P1-RULE-03` | T01 | P01 |
| `P1-RULE-09` | R07 | E04 |

**Phase 3 cases that touch a Phase 2 screen.** Phase 3 owns them. Phase 2 must
not break them, and the Phase 2 half should be built so they can pass later.

| ID | Phase 3 primary | touches |
|---|---|---|
| `P0-COM-14` | M08 | A04 |
| `P0-SHARE-02` | G02 | A03 |
| `P0-SHARE-03` | G02 | A03 |
| `P0-INTAKE-02` | G17 | A02 |
| `P0-ASK-05` | X02 | Y11 |
| `P0-CYC-15` | G16 | Y12 |
| `P1-RULE-11` | M01 | P01 |
| `P1-HRULE-06` | G02 | A03 |

`P0-CYC-15` deserves a note: it is a cycle case by subject and a coaching case by
primary screen, so Phase 3 owns it. The behaviour it tests — a sharing grant
dying with the relationship — is enforced at read time by `CycleSharingPolicy`
(G9 §3.4 `orphaned`), which **is** Phase 2 work. Build the policy now; the test
runs in phase 3.

## P1 — 7 cases

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P1-RULE-04` | Product rule guard | Y03,Y05,Y06 | Suggestions follow logged symptoms, never an inferred phase |
| `P1-RULE-05` | Product rule guard | Y04,Y11 | Severe symptoms replace the workout suggestion |
| `P1-CYC-01` | Product rule guard | Y03,Y05,Y06,Y08 | A cycle phase is not an input to any suggestion |
| `P1-CYC-02` | Product rule guard | Y04,Y11 | Severe symptoms suppress the training suggestion |
| `P1-CYC-03` | Product rule guard | Y12,G02,W02 | Sharing switches are independent, default off, and revoke on the way out |
| `P1-CYC-04` | Product rule guard | Y03,Y04,Y08,Y09,Y10,Y12 | PDPL: cycle data is never sent to analytics under any circumstance |
| `P1-CYC-05` | Product rule guard | Y08,Y10 | Cycle data is not queryable across users at the storage layer |

Every P1 in Phase 2 is a Cycle guard. Eat, Progress and Profile have **no P1 of
their own** — their rule guards sit on Phase 1 or Phase 3 primaries
(`P1-RULE-09` on R07 reaches E04; `P1-RULE-03` and `P1-RULE-11` reach P01). That
is a coverage fact, not an accident to correct here, and it means the Eat and
Progress rules below are protected by P0 behaviour tests plus the Phase 1
guards rather than by a dedicated P1 row.

## P0 — 27 cases

### Eat & food logging — 6

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P0-LOG-06` | Log a usual meal in one tap | E01,E04 | Calm running total, never a countdown |
| `P0-LOG-07` | Log a meal by typing a sentence | E02,E04 | |
| `P0-LOG-08` | Log a meal by voice in Egyptian Arabic | E03,E04 | |
| `P0-LOG-10` | Logging the same planned meal twice corrects it; a second helping is separate | E01,E04 | HANDOFF rule 3 |
| `P0-LOG-11` | Two devices offline log into the same meal slot | E04 | Spine C3 (amended): arrayUnion/increment, not merge |
| `P0-EAT-01` | An allergy conflict fails closed | E02,E04 | Safety: allergies fail closed |

### Progress & rewards — 1

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P0-RWD-03` | A measurement can be undone, and is never comparable | P04 | Rule 9 + rule 11 + spine C7 |

### Profile, privacy & Safety Centre — 1

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P0-DEL-01` | Account and data deletion actually deletes | A02 | Rule 7 + store data-safety declaration |

### My Cycle — 17

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P0-CYC-01` | Set up My cycle — dates and symptoms | Y01,Y02,Y03 | Sharing switches default off; no invented cycle length |
| `P0-CYC-02` | Set up My cycle — symptom-only mode | Y01,Y14,Y08 | No phase and no forecast without dates |
| `P0-CYC-03` | Skipping setup leaves the app exactly as it was | Y01,T01 | F80: My cycle is optional, and skipping costs nothing |
| `P0-CYC-04` | Daily check-in — three taps and nothing carried over | Y04,Y03 | Nothing is carried over from yesterday |
| `P0-CYC-05` | A logged symptom changes the suggestion — a date never does | Y03,Y05,Y06 | Suggestions follow logged symptoms |
| `P0-CYC-06` | Severe symptoms remove the workout suggestion entirely | Y04,Y11,Y03 | Severe symptoms replace the workout suggestion |
| `P0-CYC-07` | Route to care — Android including the fallback | Y11 | A route to care always exists |
| `P0-CYC-08` | Route to care — iOS including the fallback | Y11 | A route to care always exists |
| `P0-CYC-09` | Log a period then correct it | Y08,Y09 | A period can be added and edited |
| `P0-CYC-10` | Impossible dates are refused rather than stored | Y09 | Future dates and end-before-start are rejected |
| `P0-CYC-11` | Delete a period and the estimates built on it | Y09,Y08 | Editing or deleting a date clears estimates built on it |
| `P0-CYC-12` | Logged and estimated are distinguishable without colour | Y08 | Estimates are never presented as facts |
| `P0-CYC-13` | Sharing is off by default and each switch is independent | Y12,G02 | Sharing switches are independent and default off |
| `P0-CYC-14` | Revoking a switch removes the coach's derived panel | Y12,W02,W09 | Turning a switch off revokes the coach's derived panels |
| `P0-CYC-16` | Delete cycle data without touching the rest of the app | Y12 | F88: cycle data is deletable on its own |
| `P0-CYC-17` | Offline — a period and a check-in save with no signal | Y04,Y09,Y08 | Logging never requires signal; a replay creates no duplicate |
| `P0-CYC-18` | Meal options follow symptoms and adding is not eating | Y07 | Allergies applied before ranking; adding is not logging |

`P0-CYC-07` is Android-only and `P0-CYC-08` is iOS-only. Per `README.md`, an iOS
row is *untested* until it has run on a simulator; it is never "passing by
parity".

### Cross-cutting — 2

| ID | what it proves | screens | rule it protects |
|---|---|---|---|
| `P0-NAV-01` | Two-tap reachability | all in-scope | |
| `P0-A11Y-01` | Arabic right-to-left across every in-scope screen | all in-scope | |

`P0-NAV-01` has a known Phase 2 problem, recorded rather than discovered.
`G7-profile-privacy-safety.md` §8 measures **A03 at depth 3** (T01→A01→A02→A03)
and **A04 at depth 3**, both exceeding the ≤2-tap target and both counting
against the 80% threshold. G7 declines to fix it unilaterally because rule 16
forbids turning states into routes. Judge the number; do not quietly re-measure
until it passes.

---

## Build order

`PHASES.md` §"Sequence inside a phase" fixes the order, and it is the same for
each flow: **(1)** repository interface and its fake, **(2)** domain rules with
their tests, **(3)** view models tested without widgets, **(4)** screens matched
against the prototype, **(5)** the P0 cases for that flow as executable tests,
**(6)** Firestore rules and indexes for the collections touched, extended and
re-verified. The build stays green at every step.

Two things precede all four flows, because every flow needs them and building
them four times is how they drift:

- **An `AppToggle` switch row.** `app/lib/ui/` has no toggle/switch primitive.
  A03, Y02, Y10 and Y12 are switch-dense. One widget, matching `toggle()` in
  `src/kit.mjs`.
- **Wire the error/offline vocabulary that already exists.** `i18n/msa/14-states.json`
  carries 29 strings in both languages and `PHASE1-QA-REPORT.md` §4 records that
  **none is referenced by any view**. Every `P2-OFF-*` and `P2-ERR-*` row in
  Phase 2 tests a state the product currently has no wired language for.

### Flow 1 — Eat & food logging (E01–E09)

Ordered first: it is the highest write volume in the product, and `P0-LOG-09`
and `P1-RULE-09` are Phase 1 cases that only close once Eat exists.

1. **Repository + fake.** `MealRepository` over `users/{uid}/meals/{yyyy-MM-dd}`
   (spine C3, one document per day), `eatPrefs/current`, `mealPlans/{yyyy-Www}`.
   The fake must be strict where the real one is strict, as
   `InMemoryTrainRepository` is: reject a same-slot write that is a value
   overwrite rather than an `arrayUnion`, or `P0-LOG-11` passes in the fake and
   fails in production.
2. **Domain rules + tests.** `DayTotals`, `MealSlotStateMachine`,
   `MealLogService.correctPlannedLog()` and `.addHelping()` as two methods with
   no shared entry point, `MealSentenceParser` + `FoodLibrary.resolve()`,
   `MealDayReader.dedupe()`, `PlateRollup.rank()`, and `AllergyGuard`. Route
   every log through the existing `LogCommandBus` — do **not** add a second undo
   implementation (`RECONCILIATION.md` §2; G5 §5 concedes this explicitly).
3. **View models.** Day totals, suggestion ranking over ≤40 plates, parse
   results with `unresolved` chips, week plan and grocery ticks.
4. **Screens.** E01–E08 as routes; **E09 is a branch inside the Eat route**, not
   a destination — it is already in `firstRunStates` and `routing_test.dart`
   pins that.
5. **P0 as tests.** `P0-LOG-06`, `-07`, `-08`, `-10`, `-11`, `P0-EAT-01`; then
   re-run Phase 1's `P0-LOG-09` and `P1-RULE-09` end to end.
6. **Rules + indexes.** Extend the single `users/{uid}` block in
   `firebase/firestore.rules` — never add a second block; `firestore_rules_test.dart`
   asserts exactly one. `meals/{day}` already exists; add `eatPrefs/{docId}`
   (pinned to `current`) and `mealPlans/{weekId}`. Exemptions for `meals.slots`
   and `meals.totals` are already in `firestore.indexes.json`; add
   `eatPrefs.plates` and `mealPlans.groceries`.

### Flow 2 — Progress & rewards (P01–P04)

Second, because P01 is where nine Phase 1 cases finish.

1. **Repository + fake.** `WeeksRepository`, `BestsRepository`,
   `MeasurementsRepository` (`latest()` / `historyForOwner()` **only** — no query
   method, G6 §5), `AwardLedger`. Everything except `measurements` is read-only
   to the client.
2. **Domain rules + tests.** `WeekRollup.evaluate()`, `RestWeekRepair.decide()`,
   `TierPolicy` (`earnedTier` monotonic, `displayTier` slipping at most one
   step), `UnlockPolicy.isUnlocked()` reading `earnedTier`, `AwardTable`,
   `DailyCap`, `PersonalBestDetector`. `WeekKey` already exists and already
   refuses arithmetic; build on it rather than beside it. `SessionCredit` in
   `domain/training/session.dart` already keys on `source == live` — reuse it.
3. **View models.** P01's two tier bars and eight week bars from
   `weeklyGoal.recent8`; P02 milestones; P03 bests; P04 measurements.
4. **Screens.** P01–P04. `AppWeekSegments` exists; P01's eight-week bar chart
   does not.
5. **P0 as tests.** `P0-RWD-03`; then Phase 1's `P0-WEEK-01/02/03/04`,
   `P0-RWD-01/02`, `P0-LOG-12`, `P1-RULE-03` against a real P01.
6. **Rules + indexes.** `weeks`, `bests`, `awards` are already `allow write: if
   false` and `measurements` is already owner-read/write. The measurements key
   whitelist from G6 §6 item 6 is **now in the file**, with `isDay(day)`,
   `noRunCounter()` and `requiredMeta()` — and with the K3 metadata fields
   inside the whitelist, which G6 §1.2 records as the bug that would otherwise
   have made its own rule reject every conformant write. `noRunCounter()` also
   gained the three spellings G6 uses and this file lacked: `missedDays`,
   `dailyStreak`, `daysStreak`. A stored count of missed days is exactly what
   P0-WEEK-02 forbids showing, and a field that cannot be written cannot be
   rendered. Index
   exemptions for `measurements.weightKg`, `measurements.body` and `bests.loadKg`
   are already present and asserted by `firestore_indexes_test.dart`.

### Flow 3 — Profile, privacy & Safety Centre (A01–A04)

Third, because deletion needs every collection to exist — which is precisely
`PHASES.md`'s reason for putting it in this phase.

1. **Repository + fake.** `NotificationsRepository`, `BlockService`,
   `ReportService`, `AccountDeletionService`, `PrivacySettingsService`.
2. **Domain rules + tests.** `MediaBlurPolicy.resolve()`,
   `VerificationClaim.imagesDeletedStatement()` (derived from
   `verification.imagesDeletedAt`, never hardcoded), `PublicProfileProjection.build()`
   over an allowlisted field set, the report state machine with `queuedLocal`
   distinct from `submitted`, and the deletion state machine — **Auth locked
   first, Auth record deleted last**.
3. **View models.** Settings rows that delegate writes to the owning group's
   repository; G7 owns the screen, not the field.
4. **Screens.** A01–A04.
5. **P0 as tests.** `P0-DEL-01`, driven off the machine-readable manifest so a
   new collection without a manifest row is a visible omission.
6. **Rules + indexes.** Add `notifications`, `blocks`, `blockedBy` (`read,
   write: if false` for everyone, including its owner), `myReports` inside the
   single `users/{uid}` block; `reports/**` and `deletionRequests/{uid}` are
   top-level and G7's own. `reports` already exists with create-only.

### Flow 4 — My Cycle (Y01–Y14)

Last of the four: it consumes G3's check-ins, G5's ranker and G7's deletion, so
building it last means consuming finished interfaces rather than stubs.

1. **Repository + fake.** `CycleRepository.watch()` over
   `users/{uid}/cycle/current` — **one listener per app session, not a read per
   screen** — and `PeriodRepository` over `users/{uid}/periods/{yyyy-MM-dd}`,
   keyed by start date.
2. **Domain rules + tests.** `SymptomSuggestionResolver.resolve(TodayCheckIn)`,
   `SevereSymptomGate.evaluate()`, the sealed `DaySuggestion`,
   `CycleSharingPolicy.projectionFor()`, `CycleProjectionReconciler.rebuild()`.
   `PhaseEstimator` goes in `presentation/calendar/` and nowhere else, with an
   import test.
3. **View models.** Hub, calendar, patterns, settings.
4. **Screens.** Y01–Y13 as routes, **Y14 as a branch of Y03** — and see the
   routing conflict below, which must be settled before this step.
5. **P0/P1 as tests.** All 17 P0 and all 7 P1.
6. **Rules + indexes.** `cycle/{docId}` and `periods/{day}` exist but are bare
   `allow read, write: if isSelf(uid)`. **Both halves are now done.** G9 §6's
   validators are merged (`docId == 'current'`, the banned
   `phase`/`cycleDay`/`predictedOvulation`/`fertileWindow`/`forecast` keys,
   `stillBleeding == (end == null)`, the 21–45 range, the ≤12/≤6 caps, and
   `allow list: if false` on `cycle` — there is no cycle query, for anyone,
   ever). G9's blocks could not be merged verbatim: they call `noStreak()` and
   `freshStamp()`, and this file had neither, so `noRunCounter()` is used and
   `freshStamp()` is now defined from G13 §6 and G14 §6, which spell it
   identically.

   **The count below was wrong twice over, and is corrected here.** It read
   "three of nine deployed… **six are missing**" and then listed **seven**. The
   three `checkins` symptom exemptions it counted are G3's, not among G9's nine
   at all. The truth: **two** were deployed (`cycle.contextFlags`,
   `periods.start`) and **seven** were missing — `cycle.recentStarts`,
   `cycle.mode`, `cycle.cycleLengthDays`, `cycle.sharing`, `cycle.lastPeriod`,
   `periods.end`, `periods.stillBleeding`. All seven are now in
   `firestore.indexes.json`. Until they were, `periods.stillBleeding` — a
   boolean true for exactly the women currently bleeding — was auto-indexed and
   queryable across every user in a deployed project. G9 §6 R1 is the one to get right: no `match` under
   `users/{uid}/` may grant read on the basis of a relationship or a custom
   claim, and a negative test must prove a fully-shared coach is still denied a
   direct read.

---

## The domain rules each flow must enforce

Quoted from the plans. Every one lives in `domain/`, never in a widget —
`ARCHITECTURE.md` §1: "the eleven rules live in `domain/`, each with a test. A
view model may not restate a rule, and a widget may never contain one."

### Eat — the running total is never a countdown

`G5-eat-food-logging.md` §1.5, *"The running total, and why a countdown is
unrepresentable"*:

> There is **no `kcalRemaining`, no `kcalTarget`, no `deficit`, no `over` field
> anywhere in the G5 domain or data model** — the same technique C6 uses against
> `streak`. A widget cannot render a calorie countdown because nothing computes
> one.

and §5, enforcement table:

> Calm running total, never a countdown | `DayTotals` (the type itself) | No
> `remaining`/`target-kcal`/`deficit` field exists in the model (§1.5).
> Unrepresentable, like C6's `streak`.

The domain type is exactly `class DayTotals { int kcalSoFar; int proteinSoFar;
int proteinTargetG; }`. Protein is the only target; kcal renders as prose
("About 1,106 kcal so far today"). A guard already exists in
`test/product_rules_test.dart` banning `kcalRemaining|caloriesRemaining|
calorieCountdown|remainingCalories|kcalLeft` — extend it to the new feature
folder rather than writing a second one.

Two more Eat rules that are easy to collapse and must not be:

- **Correct vs. second helping**, §1.4: a planned log uses a *deterministic*
  `itemId = sha1(planRef)` and writes `arrayRemove(old) + arrayUnion(new)`, so
  re-logging **corrects**; "another helping" mints a fresh UUID with
  `helpingOf`, so it is **a second item**. §1.4: "There is no code path where
  re-tapping *Log* silently doubles a serving, and none where a helping
  overwrites the first."
- **Allergies fail closed**, §5.1: the guard removes matching foods "**before**
  ranking", and if `profile.allergies` cannot be read it "**fails closed for the
  allergy class**… An unknown constraint is not an absent one." A dietary
  preference gets "**No sheet, no override, no warning**", because "treating a
  preference like an allergy trains her to dismiss the sheet that matters."

### Progress — a rest week repairs a missed week, and no daily streak exists

`G6-progress-rewards.md` §3.1, the week state table and its transition rows:

> | repaired | +1 | −1, and `lastRepairedWeek = key` for G3's T04 | unchanged —
> the run survives, which *is* the repair | unchanged | **0** |

and:

> **Repair is automatic and unasked.** `RestWeekRepair.decide()` runs inside the
> close transaction — no prompt, no confirmation, no permission sought. T04
> reports what already happened. Repaired weeks do **not** earn toward the next
> rest week (only `counted && !repairedByRestWeek` advances `restWeekProgress`),
> so repair cannot fund itself.

`counted` is irreversible and `closedAt` write-once, "so a late-syncing session
can never un-count or reopen a week."

On the daily streak, §5:

> **3 — weeks, not days. No daily streak, ever.** | `WeekKey.of(instant, tz)` /
> `WeekKey.current(tz)` | the only time→bucket function in G6; it can produce
> **nothing but** `yyyy-Www`. There is no day-granularity type for consistency to
> be expressed in.

backed by `SCHEMA-SPINE.md` C6: "**No field named `streak`, and no
daily-consecutive counter, exists anywhere.** Rule 3 is enforced by making it
unstorable. A UI cannot render what the schema cannot hold." G6 §6 item 1
additionally requires `missedDays`, `dailyStreak` and `daysStreak` added to the
banned key set, "a *count of missed days* is precisely what P0-WEEK-02 forbids".
`firestore.rules` currently bans five keys and **not** `missedDays` — add it.

And the rule that makes "nothing earned is taken away" structural, §3.2:

> `UnlockPolicy.isUnlocked(feature)` reads `earnedTier`, which is monotonic; only
> the rendered label moves. T05's "Everything Regular opened" list is true by
> construction, not by remembering to be kind. Slip is capped at one step because
> the formula subtracts one — no code path subtracts two.

### Profile — deletion leaves nothing behind

`G7-profile-privacy-safety.md` §3.3:

> **Order matters and is the guarantee.** Auth is locked before any data is
> touched (so nothing can be written back mid-purge) and the Auth record is
> deleted last (so the request is always attributable and resumable).
> **Firestore does not cascade-delete subcollections**, so every path is deleted
> by explicit enumeration against the manifest in §7.3… there is no "delete the
> user document and hope".

The manifest is **34 rows** and §7.3 is explicit that it *is* the implementation.
Three parts are routinely missed:

> **The client-side half that is easy to miss:** on `authLocked` the app must
> sign out, then `terminate()` and `clearPersistence()` the Firestore instance.
> Without that, the woman's data is still readable from the unbounded offline
> cache on that handset and P0-DEL-01 fails on-device while passing on the
> server. It must **also** call G6's `MeasurementsRepository.purgeLocal()` and
> destroy the photo store's Keychain/Keystore key (manifest rows 33–34).

Two rows are deliberately **not** deletions and A02's copy must say so: row 23
`nidRegistry/{nidHash}` is "**not deleted — closed**", and row 30 `reports/**` is
"**not deleted — pseudonymised**". Both await the same legal sign-off (Q5).

The honest limit, §3.3, which the copy must not overstate:

> If she deletes her account from a second phone, the first phone's encrypted
> photo store survives until that installation next launches, notices the account
> is gone, and self-wipes. The server-side guarantee is complete; the on-device
> guarantee is eventual.

Deletion is also **not offline-capable** and must not pretend to be — §4: "**No
optimistic state, no local tombstone, no progress bar that is not backed by a
server ack**."

### Cycle — private by default, and never reaching analytics

`G9-cycle.md` §1.1: `sharing` is "all **false** (C12)" and

> `sharing.*` is different and absolute — it is false on write, cannot be set
> during setup, and only Y12/G02 can turn it on (C12, HANDOFF 6).

No document exists at all until she completes setup, so before that "the feature
is invisible". `SCHEMA-SPINE.md` C12: "**Cycle data is never readable by a coach
unless she has turned that sharing switch on**… Cycle data is never sent to
analytics under any circumstance."

The revocation guarantee is evaluated at **read** time, §3.4:

> `orphaned` is the state that makes the product's own promise true: *"Cycle
> sharing switched itself off when the coaching ended."* It is evaluated **at
> read time**, exactly as C10 evaluates result consent, so it holds even when her
> handset is offline and no revocation write has synced.

On analytics, §5 — and this is the strongest form available:

> **`lib/features/cycle/` contains zero `AnalyticsGateway` call sites.** The
> strongest available form: the feature does not emit events at all… There is no
> G9-owned event, no G9 property request, and nothing to review.

`cycle_no_analytics_call_sites_test.dart` (an AST scan over the feature folder)
fails the build if one is introduced. The existing `AnalyticsGateway` already
makes the weaker leak impossible — `domain/analytics/analytics_gateway.dart` has
enum keys and a closed value set with no `Map<String, dynamic>` overload — but
G9's test closes the remaining path, "which is sending a *bucketed* symptom as an
int."

And the rule the whole flow is shaped around, §5:

> **Enforced by absence of capability**… The method takes **one** parameter —
> today's check-in — and its signature carries no date, no `CycleDocument`, no
> phase and no clock. A phase cannot influence a suggestion because a phase
> cannot be passed to the only function that produces one.

with severity handled by type, not by branch:

> `DaySuggestion` is a **sealed** type… `Suppressed` **has no workout,
> alternative or session field at all.** There is nothing for Y11 to render even
> if a widget tried.

---

## Named risks

### Cannot be built — the content does not exist

These are content obligations, not engineering tasks. Do not invent any of them.

1. **`foods.allergens[]` and `foods.dietTags[]`.** G5 §9 Q10, marked blocking
   and "**yes, highest priority**": "Without `allergens[]` the safety guard in
   §5.1 cannot function at all." `SCHEMA-SPINE.md` §1 makes them "mandatory, not
   enrichment", and `PHASE1-FINDINGS.md` F7 confirms they are still absent.
   **`P0-EAT-01` cannot pass.** `PHASES.md` already names this on the critical
   path.
2. **`exercises.contraindicationTags[]`.** Same source, same status. Not needed
   by a Phase 2 P0 case directly, but it is the root cause of Phase 1's
   `P0-ONB-03` failure and Y06's alternative-session filtering depends on it.
3. **A capture surface for allergies and dietary preferences.** G5 Q10b and G7
   Q18 agree and both defer to the owner; `RECONCILIATION.md` §4.2 nominates
   **A02**, a Phase 2 screen. Until it exists, `AllergyGuard` fails closed for
   every woman, "and the guard interrupts women who have no allergy" (G7 Q18).
   If A02 is chosen, **G7 hosts the row and G2 writes the field** — two groups
   writing one field is a rejected plan.
4. **The Y11 care directory.** G9 OQ-11: "'Find care near you' needs an Egyptian
   source; the product currently cites NHS guidance, which is British… The
   guidance text needs a named clinical reviewer — the screen gives medical
   advice, and an unreviewed sentence there is the highest-liability string in
   the app." **`P0-CYC-07` and `P0-CYC-08` cannot pass.** Also
   `RECONCILIATION.md` §4 item 10.
5. **Y12's "what was deleted and what was kept" copy.** G9 OQ-8: the check-ins
   are G3's and survive a cycle delete; Y12 must say so. G9 is explicit: "Needs
   copy and an Arabic translation — **I must not invent either**." **`P0-CYC-16`
   cannot fully pass.**
6. **The protein target.** G5 Q1, blocking for E01/E04's bar: G2 defines no
   `nutrition` field, the target needs body mass which lives in G6's private
   `measurements` and "must not spread", so "**no group currently computes it**".
   The dictionary ships the mockup's "95 g" as literal copy.
7. **Tier thresholds.** `DECISIONS.md` D6 delegates them and states: "Until
   written here, no tier number is authoritative." G6 §9.2 adds that T05's copy
   and P01's copy contradict each other and "T05's copy needs an edit". P01
   cannot ship an authoritative tier number.
8. **The twelve milestones.** G6 §9.14: "P02 names eight; I inferred four…
   Sign-off needed on the list and on 25 points each." P02's content is 8/12
   authored.
9. **`sets[].actualHoldSec`.** G6 §7.3 request 1 — absent from G4, so "P03's
   'Plank hold · 45 seconds' **cannot currently be detected**." G6 calls it "the
   one request that blocks shipped behaviour." P03 ships three of its four kinds
   of best.
10. **Cloud STT for Egyptian Arabic.** G5 Q4, blocking for E03 tier 2: vendor,
    PDPL data-processing agreement, consent copy, whether audio may leave Egypt,
    retention. "This is an owner-track item, not solvable in code." Launch tier 1
    (on-device) only, `voiceCloudFallbackEnabled = false`. `P0-LOG-08` is
    testable on tier 1.
11. **A04's one-hour promise.** G7 Q6: A04 says "a woman moderator reads it
    within an hour" alongside "talk to a human, 9am–9pm". "As written, a 02:00
    report breaks the on-screen promise… **code cannot keep this promise; only
    rostered people can.**"

### Cross-group interfaces that do not exist yet

12. **`CheckInRepository.merge()`.** G9 OQ-3: G3 published the `checkins` path
    but no command to write it, and G9 must not write another group's document.
    "**Blocks Y04 until it exists.**" Y04 is the entry point for `P0-CYC-04`,
    `P0-CYC-06` and `P0-CYC-17`.
13. **`workout.easierOption` + a session-level today-only apply.** G9 OQ-4. If
    declined, the fallback is a bundled selection labelled "App suggestion" and
    **the words "coach-approved" must be cut rather than faked** — they are
    currently drawn on Y06.
14. **`EatSuggestionRanker.rank({SymptomContext})`.** G9 OQ-6 — Y07 needs G5's
    ranker parameterised by symptoms with `AllergyGuard.screen()` applied before
    ranking. `P0-CYC-18` depends on it.
15. **`WeeklyGoalService.markPlannedRest(date)`.** See the contradiction below.

### Contradictions with the authoritative files

16. **D5a requires a capped `markPlannedRest`; nothing provides it.**
    `DECISIONS.md` D5a rules that app-advised rest "is not a skip. It costs her
    nothing, exactly as the screen says" and requires "a capped `markPlannedRest`
    from the rewards group… The cap is a number to be set during implementation
    and recorded here." The method exists nowhere in the plans or the code; G6
    publishes no such API; G9 OQ-7 raises it as unresolved and notes "**A false
    promise on the severe-symptom screen is the worst place in the product to
    have one.**" The string is already shipped
    (`app/lib/l10n/app_en.arb`, key `restTodayMarkedAsPlannedRest`). Either G6
    publishes the capped method and the cap is recorded in `DECISIONS.md`, or
    Y11's line changes.
17. **Y11 and Y14 routability.** G9 §5 asserts both are "states of the Y03 route,
    not destinations" with "a navigation-graph test asserts no inbound edge to
    either". `app/lib/routing/app_router.dart` `firstRunStates` contains six ids
    and neither of these; `app/test/routing_test.dart` pins
    `appDestinations.length == 161 - 6 == 155` **and** the exact six-member set.
    Honouring G9 makes it 153 and requires both assertions to change. Settle
    before Cycle step 4.
18. **The spine ownership table still omits G7.** `SCHEMA-SPINE.md` §2 lists
    `users/{uid}` writers as "G1 (create), G2 (profile), G6 (rewards,
    weeklyGoal)" while §1 assigns `privacy` and `notify` to G7. G8 §14 item 17
    records it as a residual tidiness point for the spine owner.

### Suite gaps

19. **G5's two proposed safety tests were never merged.** `P0-EAT-10` (the
    allergy conflict path — "the one safety-critical behaviour in this group")
    and `P0-EAT-11` (the two-devices same-slot merge) are **absent** from
    `TEST-CASES.csv`. G5's proposed `P1-RULE-12` id is occupied by a coach rule.
    The allergy path is covered only by `P0-EAT-01`; HANDOFF rule 3 has no rule
    guard at all, only `P0-LOG-10`.
20. **`P1-RULE-09` omits P04.** G6 §9.15 — P04's add-weight is a logging action
    and the rule-9 guard does not list it, which is exactly what `P0-RWD-03`
    depends on.
21. **The rule-9 source guard is still narrow.** `PHASE1-QA-REPORT.md` B3: the
    guard in `test/product_rules_test.dart` was widened to `/features/`, so a new
    `lib/features/eat/` and `lib/features/cycle/` are now in scope — verify it
    still holds once those folders exist rather than assuming.
22. **A02 promises an export that cannot include P04's photos.** G7 Q17 and
    `RECONCILIATION.md` §5: the photos are local-only with no server copy, so
    "download everything" is narrower than the words, and G7 Q8 records that the
    export artefact, channel and format are undefined.

---

## Phase 2 strings that must exist in the dictionary and do not

Determined from `i18n/ar.json` and `app/lib/l10n/app_en.arb` (en/ar at parity,
asserted by `i18n_guard_test.dart`) and the four screen definitions.

**The prototype copy is already there.** Comparing every literal in
`screens-eat.mjs`, `screens-progress.mjs`, `screens-account.mjs` and
`screens-cycle.mjs` against `ar.json`, the only absentees are the designer's
`metric` and `note` annotations ("1 tap to log · 0 to see today", "private by
default", "no silent 28 days") and JS/CSS fragments. Those are design commentary,
not UI copy, and `PHASE1-FINDINGS.md` already records that annotations swept into
the dictionary are how you can tell they were never meant to be read. **No Phase
2 screen string from the prototype is missing.**

The gaps are of three kinds.

### 1. Parameterised messages — 5 exist, all Phase 1

`app_en.arb` carries five metadata entries: `@weSentSixDigitsToPhone`,
`@youreInName`, `@verifiedInSecondsSecondsYourIdPhoto`,
`@setSetnumberSavedWeightKgReps`, `@moveSavedSetsSets`. Every number on a Phase 2
screen is a baked mockup sample with no placeholder form:

| Screen | Shipped literal | Should be |
|---|---|---|
| E01/E04 | `22 of 95 g`, `53 of 95 g` | `{soFar} of {target} g` |
| E04 | `About 1,106 kcal so far today` | `{kcal}` |
| E04 | `+5 points`, `+31 g` | parameterised |
| E07/E08 | `23 items · about 640 EGP` | `{count}`, `{egp}` |
| P01 | `14 weeks counted · best run 9` | `{counted}`, `{bestRun}` |
| P01 | `14 of 20`, `8 of 10`, `2 of 3` | parameterised |
| P02 | `4 of 12`, `23 of 50`, `day 11 of 18` | parameterised |
| P03 | `12 kg × 10 · 16 September · was 10 kg` | parameterised |
| P04 | `Waist 82 cm`, `Hips 96 cm` | `{value}` |
| A02 | `Mai Farouk`, `Regular · level 7` | `{name}`, `{tier}`, `{level}` |
| A04 | `2 blocked`, `1 · resolved in 40 minutes` | parameterised |
| Y03/Y11 | `Period day 2` | `{day}` |
| Y08 | `Next period estimate: 12 to 14 October` | `{from}`, `{to}` |
| Y10 | `6 logged days · 2 cycles`, `4 of 6 logged days` | parameterised |

Arabic plural categories matter here — `PHASE1-FINDINGS.md` F1: "Arabic has more
than English and a digit substitution would be wrong." Phase 1 hit the same
problem from the other direction: a templated Arabic verb cannot agree in gender
with a varying subject, which is why `moveSavedSetsSets` reads "تم حفظ {move}"
rather than a conjugated form. Expect the same constraint on every row above.

### 2. Plan-mandated sentences that no screen draws — absent, verified

Each returns **zero** matches against the shipped English dictionary:

| Needed by | String |
|---|---|
| G5 §5.1 | the allergen conflict sheet: the named-allergen sentence ("This has sesame — you told us sesame"), **Not this**, **Log it anyway** |
| G7 §4 | the queued report state: "Not sent yet. It will send when you have signal, and the hour starts then." — G7 calls this "the single most misleading thing this group could ship" |
| G7 §3.3 | deletion progress: "Deleting your account", "Your account is gone.", "Still finishing — we will complete this" |
| G7 §5 | A03's rule-7 pending state: "deletion pending", rendered when `verification.imagesDeletedAt` is null |
| G9 §4 | the offline revocation sentence: "Saved on your phone. Sara stops seeing this when you're back online." |
| G9 OQ-8 | Y12's what-was-deleted/what-was-kept explanation (only "Delete cycle data" exists) |
| G7 §7.3 | A02's copy that `reports` are pseudonymised and `nidRegistry` closed rather than deleted |
| G7 Q17 | A02/P04's line that progress photos are local-only and not in the export |

Two that are **already present** and need no work: `notShared` = "Not shared"
and `notSharedNeverMeansNoSymptomsShe`, which is the marker G9 §5 requires so a
coach cannot read absence as wellness.

### 3. Error, offline and permission vocabulary — written, wired nowhere

`i18n/msa/14-states.json` holds 29 strings in both languages covering offline,
retry, server error, camera, microphone and notification permission — including
"We need the microphone to hear what you ate", which is E03's. They are in the
ARB. `PHASE1-QA-REPORT.md` §4 records that **none is referenced by any view**.
Phase 2 adds `P2-OFF-*` and `P2-ERR-*` rows for E01–E04, P04, A01–A04, Y01, Y02,
Y04, Y09, Y10 and Y12; every one tests a state the product has words for and no
wiring to show them. Wiring these is a Phase 2 task, not a Phase 1 leftover.

---

## Starting point

`app/lib/features/` contains only `signup`, `onboarding`, `today` and `train`.
All 31 Phase 2 screens currently resolve to `NotBuiltYet` (`app_router.dart`).
Phase 2 starts from zero implementation, not from a partial one.
