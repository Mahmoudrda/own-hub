# Phase 1 — QA report

Run 2026-09-18 against `app/` at the state described in the handoff (40 routes, 39
views). Judged against `PHASE1-ACCEPTANCE.md` (32 cases: 28 P0, 4 P1).

## Tool runs — real numbers

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found!** (ran in 2.0s), exit 0 |
| `flutter test` | **431 tests, all passed**, exit 0 |

Both run once, via `~/development/flutter/bin/flutter`. Flutter 3.47.4.
No `ENOSPC`. Disk went from 3.0 Gi free to 8.9 Gi during the session (the brief
said ~11 GB; it was **3 GB** when I started — worth knowing).

Note the count: the handoff says **429** tests passing, the suite reports **431**.

---

## 1. Verdict

**No — Phase 1 is not done.** Four P0 cases fail outright and eight more have no
executable test. The blockers: **P0-ONB-01 / P0-ONB-03** (the programme ignores
every answer she gave — `selectStartingProgram` returns `catalogue.first`),
**P0-LOG-05** (a changed set is silently discarded and never saved), and
**P1-RULE-09** (R08 offers no undo, and the source guard that is supposed to
protect rule 9 does not scan `lib/features/train/` at all).

---

## 2. The 32 cases

Status key: PASS / FAIL / NOT COVERED / UNTESTABLE. "Reaches P01/E01/E09" cases
are judged on their Phase 1 half only.

### P0 — 28

| ID | Status | Test that establishes it | Note |
|---|---|---|---|
| `P0-A11Y-01` | **PASS** | all 42 widget test files — every one has `Locale('ar')` **and** `TextScaler.linear(1.6)`; `foundations_test.dart` asserts RTL mirroring + Arabic glyphs | Strongest coverage in the suite. No file is missing either check. |
| `P0-FR-01` | **PASS** (T06) | `today/day_one_test.dart` — "Nothing logged yet", says what will appear, offers smallest start, no tour | E09 (Eat) **not yet reachable**. No case id cited in the test. |
| `P0-FR-02` | **PASS** | `today/first_week_view_test.dart` (cites `P0-FR-02`) | Five steps, "is not a deadline", nothing expires, no failure state. |
| `P0-LOG-01` | **FAIL** | `train/mid_set_view_test.dart`, `train/resting_view_test.dart` | One tap, save and undo all work. But **the rest timer does not run** — `RestingView` is a `StatelessWidget` with no `Timer`/`Ticker`, frozen at `0:38`. Case requires "Rest timer starts itself". See D2. |
| `P0-LOG-02` | **PASS** | `domain/log_command_bus_test.dart`, `train/resting_view_test.dart` | Undo ahead of the write; nothing queued to resurface. Genuinely well tested. |
| `P0-LOG-03` | **PASS** | `train/mid_set_view_test.dart`, `train/move_logged_view_test.dart` | "the session does not end" explicitly asserted. |
| `P0-LOG-04` | **PASS** | `train/logged_from_memory_view_test.dart`, `domain/session_test.dart` | +15 not +30, "No personal best from this one". |
| `P0-LOG-05` | **FAIL** | `train/change_set_view_test.dart` | Two taps / no keyboard pass. **"Set saves" does not**: `onSaved` hands `ChangedSet` to the router, which stores `lastChangedSet` — **never read by anything** — and navigates. No repository write, no bus submit. See B1. |
| `P0-LOG-09` | **NOT COVERED** | `data/outbox_test.dart`, `domain/log_command_bus_test.dart` | The primitives are tested and correct. **`Outbox` is not wired to any view or repository** — it appears only in `data/sync/` and its own test. No end-to-end offline path. E01 not yet reachable. |
| `P0-LOG-12` | **PASS** (T02/R12) | `domain/session_test.dart`, `train/logged_from_memory_view_test.dart` | `!= live` test; guard fails build if a source is unclassified. P01 **not yet reachable**. |
| `P0-NAV-01` | **NOT COVERED** | — | `ui/app_nav_bar_test.dart` tests the bar's labels/selection only. **Nothing measures tap depth** to any screen. |
| `P0-ONB-01` | **FAIL** | `onboarding/starting_program_view_test.dart` | **The programme respects no answer.** See B2. |
| `P0-ONB-02` | **PASS** (composed) | `onboarding/starting_program_view_test.dart` + `today/day_one_test.dart` | Defaults render a programme; T06 has a card. No test actually walks O01→O05 accepting defaults. |
| `P0-ONB-03` | **FAIL** | `train/workout_day_view_test.dart` | Test asserts only that the *string* "Quiet · no equipment · floor" renders. **No equipment filter exists.** See B2. |
| `P0-RWD-01` | **PASS** (R10 half) | `data/outbox_test.dart` | dedupeKey identifies the event; an increment without one throws. Correctly distinguishes commutative from idempotent. P01 **not yet reachable**. |
| `P0-RWD-02` | **NOT COVERED** | — | **No daily points cap exists anywhere in `lib/`.** Grep for `dailyCap|pointsCap|maxPoints|dailyLimit` returns nothing. |
| `P0-VER-01` | **NOT COVERED** (end-to-end) | `signup/welcome_view_test.dart` (cites it, covers C01 only) | Each screen C06–C13 is tested individually; **no test walks the happy path**. C10/C11 are UNTESTABLE (below). |
| `P0-VER-02` | **PASS** (structural) | — (no test) | Manifest carries **only `INTERNET`** — no `READ_SMS`/`RECEIVE_SMS` in any variant. Rule held, but **no test asserts the manifest**; autofill itself needs a device. |
| `P0-VER-03` | **UNTESTABLE** here | — | iOS keyboard AutoFill needs a device. No SMS permission is requested (as above). |
| `P0-VER-04` | **PASS** | `signup/checking_view_test.dart`, `signup/being_checked_view_test.dart` | "an undecided check goes to a reviewer, not to a rejection"; C14 amber not error; everything but community open. |
| `P0-VER-05` | **PASS** | `signup/woman_reviewer_view_test.dart` (cites `P0-VER-05`) | No selfie requested on either branch. F8 caveat still applies. |
| `P0-VER-06` | **PASS** (D8 clause) | `signup/checking_view_test.dart` — "D8 — 'needs another look' lands in the same place, not a refusal" | The CSV itself records that no dedicated rejection screen or copy exists. Routing behaviour is correct. |
| `P0-VER-07` | **NOT COVERED** | — | No offline handling on C10/C11/C12. Offline/retry copy now **exists but is unused** — see D1. |
| `P0-VER-08` | **PASS** | `signup/code_view_test.dart`, `signup/phone_number_view_test.dart` | `kVerificationCodeLength == 6` drives the widget; Arabic asserts "ستة أرقام" and rejects "أربعة أرقام". D2a correctly landed. |
| `P0-WEEK-01` | **NOT COVERED** | `domain/week_key_test.dart` (cites it), `today/today_view_test.dart` | The "no daily streak counter" clause **passes**. The clause that gives the case its name — "log the third session → week flips to counted, points award once" — has **no counting or award logic to test**. |
| `P0-WEEK-02` | **NOT COVERED** | `today/quiet_week_view_test.dart` | Copy only. `repairedByRestWeek` is a display `bool` on `TodayDay`; **there is no rest-week ledger, no banking, no repair mechanic**. P01 not yet reachable. |
| `P0-WEEK-03` | **PASS** (T05 half) | `today/tier_slip_view_test.dart` | "shown once" genuinely tested via `noticeSeen(NoticeKind.tierSlip, WeekKey.of(...))`; "Kept, all of it" asserted; no error variant, no "lost"/"missed". P01 not yet reachable. |
| `P0-WEEK-04` | **NOT COVERED** | — | No points engine, so "pays no points" cannot be asserted. |

### P1 — 4

| ID | Status | Test that establishes it | Note |
|---|---|---|---|
| `P1-RULE-03` | **PASS** | `product_rules_test.dart` (source scan + ARB scan), `domain/week_key_test.dart`, `today/today_view_test.dart` | See §6 — this one is genuinely airtight. |
| `P1-RULE-07` | **UNTESTABLE** here | `signup/youre_in_view_test.dart` (the promise copy) | No provider, no storage. Holds **structurally**: `CaptureService` returns no bytes/path/URL and `VerificationResult` has no field for an image. Cannot be verified as the case asks ("inspect all storage and provider logs"). |
| `P1-RULE-08` | **PASS** (structural) | `product_rules_test.dart` — regex guard for `classifyGender\|detectGender\|genderFrom(Image\|Face\|…)` etc. | Correctly exempts face *detection*. C10/C11 runtime behaviour UNTESTABLE (no camera). |
| `P1-RULE-09` | **FAIL** | `domain/log_command_bus_test.dart`, `train/mid_set_view_test.dart`, `today/already_did_it_view_test.dart` | R07/R09/R13/T02 are correct. **R08 is a logging action with no undo at all**, and the source guard misses `lib/features/train/`. See B1 and B3. |

**Totals: 13 PASS, 4 FAIL, 8 NOT COVERED, 2 UNTESTABLE, 1 PASS-structural-no-test (`P0-VER-02`),
4 PASS with a P01/E01 half not yet reachable.**

---

## 3. New defects

### BLOCKER

**B1 — R08 "Change a set" saves nothing, and offers no undo.**
*Screen: R08 → R09. Rule 9, and P0-LOG-05.*
`ChangeSetView.onSaved` hands a `ChangedSet` to the router
(`lib/routing/app_router.dart:345-349`), which assigns it to
`AppRouter.lastChangedSet` and calls `goTo(context, 'R09')`.
`lastChangedSet` is **written and never read** — grep finds the assignment and the
declaration, no reader. The value never reaches `TrainRepository`, never reaches
`LogCommandBus`, and is never rendered.
Three consequences, all live:
1. The set she corrected is **lost**. She picks 14 kg × 9, taps Save, and nothing
   is recorded.
2. R08's navigation to R09 does **not** use `_goCarryingHandle`, so R09 renders
   with whatever `_pendingHandle` happens to hold.
3. R09 then shows `l10n.set2Saved12Kg10` — *"Set 2 saved · 12 kg × 10"*, the
   **prescribed** numbers — announcing a save of values she explicitly overrode.

*Reproduce:* R07 → "Change" → pick 14 kg → pick 9 → "Save — 12 kg × 8". Lands on
R09 reading "Set 2 saved · 12 kg × 10" with no Undo button.

**B2 — The starting programme ignores every answer she gave.**
*Screens: O01–O05, R03. P0-ONB-01 and P0-ONB-03.*
`selectStartingProgram` (`lib/features/onboarding/domain/starting_program.dart`)
ends with `return catalogue.first;` — the `Intake` parameter is accepted and
**never read**. On top of that, O05's two headline lines are fixed dictionary
entries with no placeholders:
- `threeDaysAWeek15MinutesAt` = `"Three days a week, 15 minutes, at home"`
- `yourWeekMondayTuesdayAndThursdayChange` = `"Your week: Monday, Tuesday and Thursday…"`

A woman who chooses **5 days, 30 minutes, at the gym, with a barbell** is shown
"Three days a week, 15 minutes, at home" and the same beginner programme.
P0-ONB-03's "a barbell move never appears for a home-with-nothing intake" is
unenforceable: no equipment filter exists (this is F7 reaching the screen).

This is the worst instance of the green-suite problem. `starting_program_view_test.dart`
asserts `find.text('Three days a week, 15 minutes, at home')` — the test passes
**because** the string is hardcoded, and would fail the moment the screen became
correct. The code comments are honest about it; the test is not.

### MAJOR

**B3 — The rule 9 source guard does not scan the train feature.**
*`test/product_rules_test.dart`, "RULE 9 — logging never raises a confirmation dialog".*
The guard filters to files whose path contains `/log`, `/today` or `/eat`. The
directories that match are `lib/features/today/**` and `lib/domain/logging/`.
**`lib/features/train/` does not match**, and `lib/features/eat/` does not exist.
So a `showDialog` added to R07, R08, R09 or R13 — the screens `P1-RULE-09` names
first — would not be caught. The guard currently passes vacuously over the exact
code it was written to protect. (No dialog exists today; the *guard* is the defect.)

**B4 — A stale `LogHandle` survives into a later screen and renders a dead Undo.**
*`lib/routing/app_router.dart:383-397`.*
The comment claims `_pendingHandle` "is cleared as soon as it is handed on, so a
stale handle from an earlier set can never be undone by a later screen." **That is
not what the code does** — it is cleared in the `.then()` callback, i.e. when the
pushed route *pops*, so it stays set for that screen's whole lifetime.
Path: R07 logs a set → R09 (handle `h1`) → "I'm ready" pushes R07 → "Change"
pushes R08 → Save pushes a **second** R09, built with `handle: _pendingHandle`,
still `h1`. `h1` is non-null, so `AppUndoBar` renders the Undo button; its window
closed minutes ago, so `h1.undo()` returns `false` and the tap **silently does
nothing**. The guard `AppUndoBar` was designed to have — null handle means no
button — is defeated because the handle is stale rather than absent.
No test exercises the router's handle carrying at all (grep for `_goCarryingHandle`
across `test/` returns nothing). R07→R09 and R07→R13 *are* wired correctly; the
untested edge is the R08 re-entry.

**B5 — The rest timer never runs.**
*Screen R09. P0-LOG-01's "Rest timer starts itself".*
`RestingView` is a `StatelessWidget`; the file contains zero `Timer`, `Ticker` or
`AnimationController`. `remaining` defaults to `Duration(seconds: 38)` and the
router passes nothing, so the ring is frozen at `0:38` forever. The screen's own
copy — "this starts and stops itself" — is untrue. Tests assert the rendered
string `'0:38'`, which is exactly what a frozen timer produces.

**B6 — R07's button and undo text are fixed strings, not derived from the move.**
*Screen R07. P0-LOG-01: "Snackbar names the same numbers the button named".*
`MidSetView` renders `move.prescriptionLabel` (real data) in the card, but the
button is `l10n.done12Kg10` = `"Done — 12 kg × 10"` and the undo describe is
`l10n.set2Saved12Kg10` = `"Set 2 saved · 12 kg × 10"` — both hardcoded, neither
parameterised. Meanwhile `_recordAgreed(prescribed)` logs the move's **actual**
values. Pass a move of 20 kg × 8 and the card reads "20 kg × 8", the button says
"Done — 12 kg × 10", and 20 kg × 8 is what gets written.
`mid_set_view_test.dart` never passes a `move:` argument, so it only ever exercises
the default 12 kg × 10 move, where all three agree by coincidence. The test cannot
catch this.

### MINOR

**B7 — C13 never receives her name or the real verification time in the running app.**
The dictionary now *has* the parameterised messages, and `YoureInView` uses them
correctly. But the router builds it as `YoureInView(onReadTheRules: …, onCoachSetup: …)`
— **no `firstName`, no `verifiedInSeconds`**. So the shipped screen always shows
the nameless "You're in" and the hardcoded default `74`.
`youre_in_view_test.dart` passes `firstName: 'Nour'` and `verifiedInSeconds: 31`
and asserts "it reports her real verification time, not the mockup 74" — green,
while the app shows 74. Also structural: `VerificationResult` has `decidedAt` but
**no `submittedAt`**, so the real duration is not computable from the domain today.

**B8 — C07's "her number" is correct but unasserted.**
`_sentToNumber()` reads `AuthAwaitingCode.phoneNumber` — this works, and the router
passes the shared `authRepository`. But `code_view_test.dart` only asserts
`findsOneWidget` for `'We sent six digits'`; **no test asserts the number she typed
appears**, so a regression to the `+20 100 555 0132` fallback would be silent.

**B9 — The C13 doc comment contradicts itself.**
`youre_in_view.dart` carries the corrected explanation *and* the superseded one
("this view deliberately takes no `firstName`", "no parameterised messages at all")
under "(Superseded description follows.)". Both describe current behaviour in the
present tense. Confusing for the next reader; the second block should go.

**B10 — Test count drift.** Handoff says 429; the suite reports **431**.

---

## 4. Status of F1–F8

| ID | Still true? | Evidence |
|---|---|---|
| **F1** — no parameterised strings | **Partly fixed.** | The dictionary now has **exactly 3** parameterised keys, in both languages with proper Arabic: `weSentSixDigitsToPhone{phone}`, `youreInName{name}`, `verifiedInSecondsSecondsYourIdPhoto{seconds}`. C07 genuinely shows her number. **But** the remaining baked-in sample data is intact — 62 strings with a person's name, 41 with a kg value, 28 with a weekday, 28 with EGP. O03 and O05 are unchanged, which is what makes B2 a blocker. And C13's two new strings are never supplied by the router (B7). |
| **F2** — no error/offline vocabulary | **Partly fixed, and now worse in a new way.** | Copy now exists: `youAreOfflineEverythingYouLogIs`, `tryAgain`, `thatDidNotSaveTapToTry`, `thatCodeIsNotRightCheckThe`, `checkTheNumberAndTryAgain`, `somethingWentWrongAtOurEndNothing`. **All six are unused** — no view references any of them. `permission/allow access` is still **0**. C07 still clears the boxes silently and its header comment still says "no failure copy exists yet". The words were written; nothing was wired. |
| **F3** — camera screens unverifiable | **Still true.** | `UnavailableCaptureService` is the only implementation and is what the router injects. Tests pin the disabled shutter (`button.onPressed, isNull`). Rules 7/8 hold structurally. |
| **F4** — "Pick a different program" → R11 | **Still true.** | `onChangeProgram: () => goTo(context, 'R11')`. Owner decision, unchanged. |
| **F5** — catalogue has no content | **Still true.** | `kStartingProgramCatalogue` holds one entry; `_copyFor` has one `case`. Test "a programme with no authored copy renders no card" confirms the behaviour is deliberate. |
| **F6** — life stage collected, nothing acts on it | **Still true.** | `selectStartingProgram` takes no clinical decision; `LifeStage` is recorded only. |
| **F7** — libraries have no safety tags | **Still true**, and it now has a visible consequence. | No `contraindicationTags`/`allergens`. This is the root cause of **P0-ONB-03 failing** (B2). |
| **F8** — niqab paths indistinguishable in the domain | **Still true.** | `woman_reviewer_view_test` asserts both branches submit `VerificationMethod.niqabFriendly`; only the `ReviewerPath.video`/`.gym` callback differs, and the router stores it in `lastReviewerPath`, which nothing reads. |

---

## 5. Divergences from the design, by screen

| Screen | Divergence |
|---|---|
| **O05** | Headline and week line are fixed strings; a woman's actual days/minutes/place are never shown (B2). Design intent is "the four questions come back as a named programme". |
| **R07** | Button label and undo text hardcoded to 12 kg × 10 rather than derived from the move (B6). Card *does* use real data, so the screen can contradict itself. |
| **R08** | Design (`screens-train.mjs:118`) routes `Save — 12 kg × 8` → `R09`. Implemented, but the saved value is dropped on the floor (B1). The design's R09 note — "the confirmation names the same numbers the button named" — is broken on this path. |
| **R09** | Design metric is "0 taps required… the timer ends itself if she puts the phone down". The timer does not run (B5). |
| **C13** | Renders the nameless greeting and `74 seconds` in the app despite having correct parameterised strings available (B7). |
| **C07** | Correct vs. the design (six boxes, her number). No divergence; the gap is test coverage (B8). |
| *(accepted, per findings)* | 44pt tap targets vs. 40 drawn; wrapping equipment chips; no fake status bar; C12 keeps its Continue button. All still as recorded. |

---

## 6. What the suite does genuinely well

Worth saying, because it is the standard the failures should be held to:

- **Rule 3 is airtight.** Three independent enforcement points: a source-wide regex
  scan, an ARB copy scan, and `WeekKey` having no arithmetic — ordering without
  `+`, `difference` or `isAdjacentTo`, so a run length is not reconstructible.
  `today_view_test` additionally asserts the week is the *only* progress indicator.
- **Rule 1 is enforced by type.** `PrescribedSet` has no result field, `SetOutcome`
  has no prescription field, and `hasNoPrefill` guards session creation. R07 does
  not pre-fill; it builds the outcome from an explicit gesture.
- **`P0-LOG-12`'s regression guard is exemplary** — `allSourcesAreClassified` fails
  the build if a new `SessionSource` is added without deciding what it earns.
- **`P0-RWD-01`** correctly distinguishes commutative from idempotent, and makes the
  dangerous case unconstructible via an assert.
- **Arabic coverage is complete** across all 42 widget test files, with no exceptions.

---

## 7. Recommended order of work

1. **B2** — make `selectStartingProgram` read the intake, and parameterise O05's
   two lines. Unblocks P0-ONB-01 and P0-ONB-03. Depends on F7 for the equipment filter.
2. **B1** — route R08's `ChangedSet` through `LogCommandBus` and carry the handle
   to R09. Unblocks P0-LOG-05 and P1-RULE-09.
3. **B3** — widen the rule 9 guard to all of `lib/features/`; add a test for the
   router's handle carrying (covers **B4**).
4. **B4** — clear `_pendingHandle` when it is consumed, or pass it as a route
   argument rather than static state.
5. **B5**, **B6**, **B7** — the rest timer, derived logging copy, C13's wiring.
6. Wire the six unused error strings (**F2**) — needed for P0-VER-07.
7. Then P0-NAV-01, P0-RWD-02, P0-WEEK-01/02/04 need mechanics that do not yet exist.
