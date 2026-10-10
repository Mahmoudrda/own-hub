# Own Hub, launch QA plan

The question this answers is not "do the tests pass". They pass: 4,026 app tests,
206 security-rules tests, 360 back-end tests, analyser clean. The question is
whether the thing is ready to put in front of a woman in Egypt, which is a
different question and has never been asked of this build in the shape it
actually ships in.

Two validators run this plan in parallel. **Round one walks the product. Round
two audits its claims.** The two halves share no setup, no fixture and no
result. Neither may read the other's findings before writing its own. A fixing
agent works from both.

Everything already listed in `docs/release/OWN-HUB-BEFORE-PROD.xlsx` is out of
scope: the App Check debug token, the four legal pages, counsel, the two store
accounts, the signing fingerprints, the verification pilot, the eleven
adversarial tests, signing the recipes, recruiting the reviewers, the Cloudflare
token, the pilot data, the icon decision, the "cheap" number, the pepper choice,
the lockout reset, the billing budget, and the seven engineering items on the
"Mine" sheet. This plan works around them and says where they bite.

---

## 1. The surface under test

### 1.1 What ships

`FeatureFlags.shipped` (`app/lib/domain/flags/feature_flags.dart:173`) is the
default assigned at `app/lib/routing/app_router.dart:4091`. It is much smaller
than the screen inventory suggests.

| On | Off |
|---|---|
| `today`, `train`, `eat`, `progress`, `cycle`, `privacyCentre` | `accountRequired`, `signUp`, `verification`, `adminConsole`, `community` and all four children, `coachApp`, `coachPlanning`, `coachPortfolio`, `coachedLife`, `marketplace`, `payments`, `assistant`, `recipeTiering` |

Two flows are ungated by design and therefore also ship: `account` (so she can
always leave: export, privacy centre, deletion) and `onboarding` (so nobody is
stranded half-registered). Both are asserted in
`app/test/routing/feature_gating_test.dart`.

So the product a woman gets is roughly 53 screens: `T01`-`T08`, `R01`-`R13`,
`E01`-`E11`, `Y01`-`Y14`, `P01`-`P04`, `A01`-`A04`, `O01`-`O05`, plus `C02`
(the language chooser, reachable from Profile). Everything else in
`app/lib/routing/app_routes.dart` is code she cannot reach.

### 1.2 The four different apps the tests build

This matters more than anything else in this section, because it is where the
green suite and the real product part company.

| Shape | Where | Who uses it |
|---|---|---|
| `FeatureFlags.shipped` | the default in `AppRouter` | **the app she installs** |
| `FeatureFlags.everything` / `allOff.with_({every feature: true})` | the tap crawler (`test/qa/tap_crawler_test.dart:98`), the large-text sweep (`test/qa/large_text_sweep_test.dart:40`), `test/foundations_test.dart` | most sweeps |
| `allOff.with_({every feature: true})` **with `accountRequired` on** | `test/release_readiness_test.dart:31` | the store-build guards |
| a hand-picked subset | `test/journeys/tabs_live_journey_test.dart:52` | a few journey tests |

**Nobody has swept the app in the shape it ships.** The crawler's "1,102 taps,
zero exceptions, zero placeholder screens" and the sweep's "no overflow at 1.6x
across 161 screens" are both measurements of a different build: one where
Community is a tab, coaching exists, sign-up is the front door and the assistant
answers. Round one's first job is to make that measurement for the first time
against the shipping set.

There is a reason nobody has. `app/test/domain/flags/flag_independence_test.dart`
is a source guard that forbids a test file from containing the literal
`FeatureFlags.shipped` unless the defaults are what the test is about: 34 tests
failed at once when Phase 3 was switched on, and the guard exists so a test can
never silently depend on a flag default. **A new sweep must therefore build the
shipping set explicitly**, as
`FeatureFlags.allOff.with_({Feature.today: true, Feature.train: true,
Feature.eat: true, Feature.progress: true, Feature.cycle: true,
Feature.privacyCentre: true})`, and say in a comment that the list is the
shipping set copied deliberately. Do not reference the constant and do not edit
the guard.

### 1.3 What the owner has already been told is missing

Read but do not re-derive: `RESIDUAL_RISKS.md` (ten named risks),
`DECISIONS_NEEDED.md` (D4, D5, D9 open), `AUDIT.md` §0 and §2,
`VERIFICATION_REPORT.md` (six blocking items; item 6 is that the emulator rules
tests and the on-emulator function tests have never been run),
`MANUAL_QA.md` at the repo root (adversarial, every row NOT EXECUTED),
`app/MANUAL_QA.md` (a **different** file: the ID-capture device matrix, four
devices, every row in both locales, run in `flutter run --release`),
`docs/plan/RECIPES-PLAN.md` §3.4, `docs/qa/02-QA-REPORT.md` and
`docs/qa/03-UX-REVIEW.md` in the main working tree (the previous round's method
and its twenty findings F1 to F20).

---

## 2. Severity, by consequence

Not adjectives. Each level is defined by what happens if it ships.

### S1, blocks launch

One of these is true:

* a woman is told something untrue about her body, her cycle, her food or her
  safety;
* a woman with a declared allergy can reach a dish that contains it, or is told
  a dish is safe;
* a privacy sentence on screen is false against the code behind it;
* she cannot complete a core action (log a session, log a meal, log a period,
  change her language, delete her account) or cannot get back out of a screen;
* a control on a safety path is dead or misleading;
* a dark feature is reachable, or a testing aid is reachable in a release shape;
* Apple or Google will reject on it, or the reviewer cannot use the app;
* she loses data she entered.

Worked examples from this codebase's own history: Home showing another woman's
week; "That's Tuesday done" on a Thursday; "39 dishes are hidden because of what
you avoid" when none of them were; eighteen screens killing a navigation tab.

### S2, ships with a written note

It is wrong, a woman will notice, and it does not hurt her or get the app
rejected. It must be recorded in `RESIDUAL_RISKS.md` before submission so that
nobody discovers it as a surprise.

Examples: a tap target under 44pt; a screen five taps deep that should be two;
copy that addresses the team rather than her; a filter that can only ever select
nothing but says so honestly.

### S3, cosmetic

Alignment, spacing, a stroke weight, an inconsistent radius, an abbreviation.
Fix if cheap, note if not, never block on it.

**When in doubt, size it by the sentence "what does this do to the woman who
meets it".** If the answer contains the words wrong, unsafe, stuck, or lied,
it is S1.

---

## 3. What each validator must produce

A finding that a fixing agent cannot act on is not a finding.

Round one writes `docs/release/QA-ROUND-1.md`.
Round two writes `docs/release/QA-ROUND-2.md`.
Neither touches the other's file, and neither edits product code.

Every finding carries, in this order:

1. **Id** `R1-14a`, derived from the case number, letter-suffixed if one case
   yields several.
2. **Case** the case number from this plan, or `UNPLANNED` with a one-line
   reason it was worth recording anyway.
3. **Severity** S1, S2 or S3, with the one-sentence consequence that justifies
   it. Not "important" or "minor".
4. **Where** screen id and route (`E05`, `/eat/e05`), plus locale (`en`/`ar`),
   text scale, and device size used.
5. **What was observed** the exact string, the exact pixel figure, the exact
   sequence of taps. `"Dinner, your usual · Tuesdays" on a first meal ever
   logged` is a finding. `"the header is wrong"` is not.
6. **Where in the code** `path:line`. Absolute or repo-relative, but real.
7. **Repro** a command, verbatim, that a fixing agent can paste. A failing test
   is the strongest form of this; a `flutter test` invocation with a
   `--dart-define` and a screen id is the next strongest.
8. **Evidence artefact** one of: the path of a test file added under
   `app/test/qa/round1/` or `app/test/qa/round2/` that fails on the defect; a
   dumped semantics tree; a quoted log line; a computed number with its
   arithmetic shown.

Each round also ends with:

* a **summary table** of every case number in its half and one of `PASS`,
  `FAIL`, `BLOCKED` (with the reason it could not be run), `N/A`;
* a **top-of-file verdict**, three lines: how many S1, how many S2, and whether
  the validator would put this in front of a woman.

Things a validator must not write: "looks unfinished", "feels rough", "could be
better", "consider improving". If it cannot be stated as an observation with a
location, it is not ready to be reported.

Round one must not read `docs/release/QA-ROUND-2.md` and round two must not read
`docs/release/QA-ROUND-1.md`. If the same defect appears in both, that is a
signal about how visible it is, and the fixing agent should treat it as more
urgent, not as duplicated work.

---

## 4. The environment, and exactly what it cannot see

### 4.1 The iOS blocker, stated precisely

The installed iOS 26.3 simulator runtime is arm64-only.
`google_mlkit_face_detection` (`app/pubspec.yaml`) ships no arm64 simulator
slice. The link fails before the app starts, so **`flutter run`, `flutter drive`
and `flutter test -d <udid>` are all unavailable on iOS this session.** There is
no workaround inside this session: excluding arm64 for the simulator produces an
x86_64 binary that the arm64-only runtime will not load, and removing the plugin
changes the product under test.

### 4.2 The substitute

Widget tests that boot the real app (`OwnHubApp`) through the real router, at a
real device size, in both locales. The existing harnesses already do this and are
the model to copy:

* `app/test/qa/tap_crawler_test.dart` opens every route over Home and taps every
  node a screen reader can activate, one at a time on a freshly opened screen.
  Tagged `qa`. Writes a TSV to `$OWNHUB_QA_REPORT`.
* `app/test/qa/large_text_sweep_test.dart` sets
  `tester.view.physicalSize = Size(1170, 2532)`, `devicePixelRatio = 3`,
  `platformDispatcher.textScaleFactorTestValue = 1.6`, opens every route and
  fails on a thrown overflow.
* `app/test/journeys/*.dart` boot the app and walk a whole feature, asserting
  through the semantics tree rather than through widget types.
* `app/test/journeys/dead_controls_journey_test.dart` taps through
  `tester.semantics.tap(find.semantics.byLabel(...))`, so a control a screen
  reader cannot reach cannot pass.

Locale is forced at run time with `--dart-define=OWNHUB_LOCALE=ar`
(`app/lib/main.dart:144`), read before the first frame. **No test uses it.** In a
widget test the locale is set by passing `locale: const Locale('ar')` into the
`MaterialApp`, which is what the ~83 per-screen Arabic tests do.

There is no shared test harness. The device-size idiom is copy-pasted into about
67 files as a private `_phone(WidgetTester)`. Two files publish it:
`app/test/features/coachbrand/coachbrand_test_host.dart` is the complete one
(device size, locale, theme and `textScale`), and
`app/test/features/assistant/assistant_test_host.dart` is the same without
`textScale`. Use the coachbrand one, or promote it to `app/test/support/`.

**A trap to avoid and to report.** Many `_host()` copies build
`MediaQueryData(textScaler: ...)` from scratch instead of
`MediaQuery.of(context).copyWith(...)`. A bare `MediaQueryData` zeroes the window
size, so those widgets lay out against nothing and any size assertion in them is
meaningless. `app/test/features/today/today_view_test.dart` documents the trap
and uses `copyWith`; `app/test/features/train/train_view_test.dart:28` and
`app/test/ui/app_nav_bar_test.dart:33` do not. This is a round-two case (R2-13a).

**Fonts are never loaded in `flutter test`.** There is no `FontLoader`, no
`loadAppFonts`, no `flutter_test_config.dart` anywhere in the repo. Rubik,
LaBelleAurore and ArefRuqaa are declared in `pubspec.yaml` and none of them
reaches the widget tester, so **every existing overflow and layout assertion in
this codebase was made against Ahem placeholder metrics, not against the metrics
of the font a woman will actually see.** Arabic script metrics in particular have
never been exercised at unit-test level. Round one's first act is to fix that for
its own tests (case R1-00) and to say, per case, whether the result was measured
with real fonts or without.

There are **no goldens**: zero `matchesGoldenFile` calls, no golden directory, no
`goldenFileComparator` override, no visual regression of any kind.

There is **no CI**: no `.github/workflows`, no Makefile, no script that runs all
three test estates. Everything below is run by hand.

```bash
# app suite
cd app && flutter test
cd app && flutter test test/journeys
cd app && OWNHUB_QA_REPORT=/tmp/crawl.tsv flutter test test/qa/tap_crawler_test.dart
cd app && flutter analyze lib test

# Firestore rules: the emulator must already be running on the alternate config
firebase emulators:start --config firebase.emulator.json --project own-hub
cd test/rules && npm test      # node --test --test-concurrency=1 --test-reporter=spec ./*.test.js

# back end
cd functions && ./.venv/bin/python -m pytest tests/ -q

# preflight
cd app && bash tool/release_preflight.sh
```

### 4.3 What the substitute cannot see, and therefore what this plan cannot certify

State this list verbatim in both round reports. It is the honest boundary.

* **Anything involving the camera.** `C10`, `C10b`, `C11`, and the
  `frame_quality` / `frame_budget` capture path. No lens opens in a widget test.
* **Platform permission dialogs** and the deny-then-grant recovery.
* **Real glyph rasterisation on a device.** Even with fonts loaded into the
  tester, a widget test will not show tofu, a missing Arabic subset, a shaping
  failure in a ligature, or a font falling back in a way only the device's shaper
  reveals. It also will not show the 1.28x upscale
  `hand_marks.dart:341-356` applies to LaBelleAurore compounding with the
  system text scaler on a real handset.
* **OS-level right-to-left.** The test forces `Directionality`; a phone set to
  Arabic also mirrors the system chrome, the keyboard, the share sheet and the
  back gesture.
* **Text scaling above 1.6** from the accessibility sliders, and dynamic changes
  while a screen is open.
* **Performance and jank.** Frame times, scroll physics, the first-frame cost,
  the 85 MB bundle's install and cold-start time.
* **Memory.** The 2 to 3 GB Android OOM case in `MANUAL_QA.md` row 1.
* **Safe areas on real hardware**: notch, dynamic island, gesture bar, rounded
  corner clipping.
* **Haptics, keyboard behaviour, IME, autocorrect, the Arabic keyboard.**
* **Real Firestore**: latency, offline queueing, conflict on two devices, the
  merge-by-union behaviour under a real network.
* **App Check, real phone SMS, the reCAPTCHA web-view return**, and therefore
  every one of the seven callables end to end.
* **Dark mode driven by the OS**, if the app has one.
* **The launch screen.** The iOS `LaunchImage` assets are 1x1 placeholders and
  both Android `launch_background.xml` files are stock white; a widget test
  never renders either.
* **Deep links.** Nothing is configured on either platform, so nothing is
  testable.
* **Contrast as an eye sees it on an OLED at low brightness.** Computed ratios
  are a proxy, and a good one, but they are a proxy.

### 4.4 Android, conditionally

If an Android emulator or handset is available, round one may additionally run
the journeys on it and should say so per case. If it is not, say so once, at the
top, and do not silently degrade. Do not report an Android result you did not
observe.

### 4.5 The App Check boundary for sign-up and verification

`IdentityCheck` defaults to `CallableVerificationProvider`
(`app/lib/features/signup/data/identity_check.dart`), and the seven functions
refuse every call without an App Check token. So:

**Can be validated now**, by injecting `app/lib/features/signup/domain/verification_fake.dart`:

* every screen `C01`-`C16` and its copy, in both languages, at 1.6x;
* consent ordering: that `/signup/c10` cannot open a lens until
  `AppRouter.consentRecorded` is true (`app_router.dart:4211`);
* that `C15`'s niqab route reaches no screen in `_opensALens`
  (`app_router.dart:4203`);
* the mapping from the five user-safe reason codes onto what she reads;
* the challenge prompt rendering and its ordering against the session;
* that the client holds no verdict and no image field (already enforced by
  `product_rules_test.dart` RULE 7);
* the error and retry copy for every outcome.

**Cannot be validated now, at all:**

* any real call to `record_consent`, `start_verification`, `verify_identity`;
* whether a real card produces a real decision;
* every row of `MANUAL_QA.md`;
* the SMS cost (D4), the thresholds (D5), the flag rate (D9).

Do not plan theatre around these. Report them as `BLOCKED` with the reason
"App Check debug token not provisioned, OWN-HUB-BEFORE-PROD item 1".

---

## 5. Round one: the walk

**Method.** Boot the real app and use it. Round one never reads a guard's source
to decide whether something is true; it decides by looking at the screen.

**Setup, round one only.**

```bash
cd /Users/mahmoudreda/womens-fitness-app-wireframe/.claude/worktrees/release-readiness/app
flutter pub get
```

Every case is run twice unless it says otherwise: once with the default locale
(English) and once with `--dart-define=OWNHUB_LOCALE=ar`. Every case is run at
the shipping flag set. Where a new test is needed, put it under
`app/test/qa/round1/` and do not modify any existing test file.

The device shape for every case: `physicalSize = Size(1170, 2532)`,
`devicePixelRatio = 3` (a 390x844 logical phone). Text scale 1.0 unless the case
says 1.6.

### A0. The instrument itself

**R1-00. Load the real fonts before measuring anything.**
Add `app/test/qa/round1/font_harness.dart` that loads Rubik 400/500/600/700,
LaBelleAurore 400 and ArefRuqaa 400/700 from `app/assets/fonts/` into a
`FontLoader`, and use it in every round-one test. No existing test does this, so
every layout figure in the repository today was measured against Ahem.
*Passing:* the harness loads, and a deliberate control (a long Arabic string in a
narrow box) lays out differently with the fonts than without, proving they are in
effect.
*Severity:* not a product defect. If the harness cannot be made to work, say so
and mark every layout case `BLOCKED`, because a layout pass measured on Ahem is
not evidence about Rubik or Aref Ruqaa.

**R1-00b. Re-run the two existing sweeps with fonts loaded.**
`app/test/qa/large_text_sweep_test.dart` and `app/test/qa/tap_crawler_test.dart`,
copied into `round1/` unmodified except for the harness and the shipping flag set.
*Passing:* the same results as the originals report.
*Severity:* S1 for any new overflow that appears only once the real fonts are in.
Arabic at 1.6x is where to expect it.

### A. First launch and setup

**R1-01. A clean first launch shows nothing that is not hers.**
Boot with a fresh state (no `shared_preferences`), shipping flags. Read every
string, number and ring on the first screen.
*Passing:* no programme name, no week number, no session count, no logged meal,
no logged walk, no ticked ring, no weight, no level above the first. The day-one
Home (`T06` branch of `T01`) renders. Every figure on screen is either zero, an
invitation, or something she just entered.
*Severity if it fails:* S1. This is finding F1 of `docs/qa/03-UX-REVIEW.md`,
fixed in commit `363a22e`, and it is the single most expensive regression this
product can have.

**R1-02. The setup questions open, and she can leave them.**
First launch opens setup over Home: four questions, `O01`-`O05`.
*Passing:* the four questions render; every question can be skipped; the close
control on each one actually closes; answering is persisted so the second launch
does not ask again; the number of days she picks becomes the weekly target on
both Home and Progress.
*Severity:* S1 if a question cannot be skipped or the X is dead, because both
have shipped dead before; S1 if her answer does not reach the target she is
measured against; S2 if it merely re-asks.

**R1-03. Setup promises nothing that does not exist.**
Read every sentence in `O01`-`O05` against §1.1.
*Passing:* no sentence mentions a coach, the community, an assistant, a payment,
a verification check or a programme the catalogue does not contain.
*Severity:* S1. A pregnancy question that promised "only you and your coach" in a
release with no coach has already shipped once.

**R1-04. First launch in Arabic.**
Same as R1-01 and R1-02 with `OWNHUB_LOCALE=ar`.
*Passing:* every string is Arabic, the layout mirrors, no Latin text except
numerals and brand, nothing overflows, and the four questions are answerable.
*Severity:* S1 for untranslated strings on a first-launch screen, S1 for an
unmirrored layout that puts the primary action on the wrong side, S2 otherwise.

**R1-05. Setup, then a restart, then Home.**
Complete setup, terminate, relaunch.
*Passing:* she is not asked again; Home reflects what she answered; nothing she
entered is lost.
*Severity:* S1 on data loss.

**R1-06. The first sixty seconds contain no contradiction.**
Walk Home, then one tap to Train, then one tap to Eat, and compare what the three
say about her: the day, the week, the programme, the meal slot, the count.
*Passing:* no two screens disagree about what today is, what week it is, what
programme she is on, or what she has done.
*Severity:* S1. Home and Eat contradicting each other one tap apart is finding
F4, and "That's Tuesday done" on a Thursday is commit `5e78faa`.

### B. Today

**R1-07. Log "I already did it" and watch it land.**
From `T01`, open `T02`, log a session.
*Passing:* the undo bar appears, closes by itself within about five seconds,
and tapping Undo inside that window removes the log everywhere. After the
window, the bar is gone rather than present and inert. The session appears on
Home, in the week count, and in Progress, and counts exactly once.
*Severity:* S1 on a double count or a log that lands in one place and not
another; S1 on a bar that never closes (that has shipped).

**R1-08. No logging action raises a confirmation dialog.**
Walk every log entry point in Today, Train and Eat.
*Passing:* every one uses an undo bar or a sheet, never a dialog.
*Severity:* S1. This is product rule 9, and the guard that enforced it passed
for weeks by looking in the wrong folder.

**R1-09. `T04` and `T05` are reachable and their tabs work.**
Open "After a quiet week" and "When a tier slips".
*Passing:* the bottom bar on each is reachable by a finger. The comment at the
head of `app/test/journeys/tabs_live_journey_test.dart` records that `T02` and
`T05` draw their bar inside a `Stack` under a full-screen scrim, so no tab on
either is tappable whatever id it carries. That was reported and not fixed.
Confirm whether it is still true.
*Severity:* S1 if the bottom bar is visible and untappable, because a visible
dead navigation bar is the defect class this product keeps producing.

**R1-10. `T08` resolves to something.**
Push `/today/t08`.
*Passing:* a real screen. `T08` is absent from `firstRunStates`
(`app_router.dart:300`) and has no builder, so it currently renders the
"not built yet" panel. It is only reachable by deep link or a notification
payload today.
*Severity:* S2 now, S1 the day a notification payload can carry it.

**R1-11. The first-week tour counts what it shows.**
Open `T07`.
*Passing:* the ring, the heading and the row count agree with each other, and
any sentence naming a total names the same total. Under shipping flags
`offeredFirstWeekSteps()` returns three, and a fixed string says five (finding
F15).
*Severity:* S2.

### C. Train

**R1-12. A whole session, start to finish.**
`R01` → `R02` → `R03` → start → log a set → rest → next move → finish (`R10`).
*Passing:* the session advances move by move and never hands back the same move
twice; every set logged is counted once; finishing updates Home, the week, the
points and Progress consistently; the finished screen names *today*, not a
hard-coded day.
*Severity:* S1 on any of it.

**R1-13. The first session she is ever asked to do claims no history.**
On a fresh install, read `R03` and the first set prompt.
*Passing:* no "last Tuesday you lifted", no prescribed weight on a workout whose
own subtitle says no equipment, no "0 kg" for a bodyweight set.
*Severity:* S1. All three shipped once (`363a22e`).

**R1-14. Walk away from a rest.**
Start a rest (`R09`), navigate away, wait past the rest duration.
*Passing:* the mid-set screen does not push itself over whatever she is now
doing. The rest route checks whether it is still on top before acting.
*Severity:* S1. It pushed over her up to 38 seconds later once.

**R1-15. The workout library is honest.**
Open `R11`.
*Passing:* every row opens a different session; no row credits a coach who does
not exist; choosing a row changes what she gets.
*Severity:* S1 if every row opens the same session, S2 if names are invented.

**R1-16. Swap a move, `R05`.**
*Passing:* `R05` opens without trapping her behind a modal sheet with no
dismissal, the swap takes effect in the session, and the bottom bar (if drawn)
is reachable.
*Severity:* S1 if she cannot get out.

**R1-17. Change a set, `R08`, and log from memory, `R12`/`R13`.**
*Passing:* both write a log that appears in the same places as a live set, and
a set logged from memory never sets a personal best (the dictionary says so;
confirm the behaviour matches).
*Severity:* S1 if a copied number sets a best, because P03 then tells her
something false about herself.

**R1-18. Train in Arabic at 1.6x.**
Run R1-12 with `OWNHUB_LOCALE=ar` and text scale 1.6.
*Passing:* no card clips, no number is cut, no row overlaps, the rest timer is
legible, and the session still completes.
*Severity:* S1 if the session cannot be completed, S2 for clipping.

### D. Eat, and the allergy path

**R1-19. Log a meal.**
`E01` → `E02` (type it) → save.
*Passing:* one undo bar, not two; the bar's text matches what happened and stops
claiming it after she undoes; the log appears on Home's meal row; `E04` opens
after the log lands, not before.
*Severity:* S1 on a double bar or a bar that still says "Food logged" after an
undo. Both shipped.

**R1-20. `E04` names the slot the hour is actually in, and claims no pattern.**
Log one meal, ever, and read the `E04` header.
*Passing:* the slot follows the hour through the same rule Home uses. No
sentence asserts a weekly habit to a woman with one log.
*Severity:* S1. Commit `e8b0059` is exactly this defect.

**R1-21. The allergy question, `E10`.**
Open the recipe library for the first time.
*Passing:* the question is asked once, before any allergen-tagged recipe is
visible; nothing on it is drawn as a dead control; the filled button is the live
one; sixteen tags are offerable; "no, nothing" writes an answer rather than a
default; discarding a declaration after ticking something asks first, in a sheet,
not a dialog.
*Severity:* S1. The screen previously opened with a disabled filled button above
the only live control, and threw a declaration away in one tap with nothing said.

**R1-22. Declare an allergy and read what the book says.**
Declare sesame. Then declare molluscs (which appear in none of the 39 recipes).
*Passing:* the book empties, and the reason given is **two separate sentences**:
one saying the recipes are not signed off yet, one saying what she avoids. The
screen must not tell a woman who avoids molluscs that 39 dishes are hidden
because of what she avoids.
*Severity:* S1. That sentence shipped and is the subject of commit `4078abc`.

**R1-23. Reach an unsafe recipe by a side door.**
With sesame declared, open a recipe that carries sesame by direct route
(`/eat/e06` with the id), the way a bookmark or a share would.
*Passing:* a full interstitial before the card, not a dialog, saying what the
dish contains. The app never says the dish is safe.
*Severity:* S1.

**R1-24. No recipe shows a number nobody verified.**
Open ten recipes across the four sections.
*Passing:* no calorie figure, no macro, no invented quantity. A recipe with
almost no quantities says so rather than printing bare nouns under an
Ingredients heading. No recipe prints a step twice.
*Severity:* S1 for an invented number a woman eats to; S2 for a duplicated step
(four recipes printed every step twice before `4078abc`).

**R1-25. Rahma's words are hers.**
Open `E11` and five recipe cards in Arabic.
*Passing:* no glued words, no truncated line, no paraphrase, no Latin
punctuation inside her Arabic. Her letter renders whole.
*Severity:* S2, unless a word change alters an instruction, then S1.

**R1-26. The two filters that can select nothing say so.**
Apply "Cheap" and "No nuts" in `E05`.
*Passing:* each says in its own words that nothing in this build can match,
rather than falling through to a generic "nothing matches that", which reads as
a fault in the app.
*Severity:* S2.

**R1-27. Week plan and grocery list, `E07` and `E08`.**
*Passing:* the grocery list can be shopped from: one purchasable line per item,
no phrase split across two rows, no "or" pair listed as two purchases. Any
recipe that cannot produce a list says so.
*Severity:* S2.

### E. My cycle

**R1-28. Set it up, `Y01` → `Y02` → `Y03`.**
*Passing:* the whole setup completes; the hub renders; Home's cycle card appears
only after setup.
*Severity:* S1 if setup cannot complete.

**R1-29. Symptom-only mode, `Y14`.**
Choose the symptom-only path at `Y01`.
*Passing:* no dates, no estimates, no calendar. The consent that lets the app
offer a gentler session is reachable **on this path**, not only on the dates
path she chose not to take.
*Severity:* S1. That consent was previously unreachable for every woman who
chose symptom-only, which silently disabled the gentler option for exactly the
women most likely to want it.

**R1-30. The severe branch, `Y11`.**
Log severe cramps or heavy bleeding at `Y04`.
*Passing:* the hub switches to the severe state; **no workout of any kind is
offered, and no gentler option is offered either**; the medical sentence is
present and correct in both languages; the emergency line (call 122) is present
where the copy says it is.
*Severity:* S1 on any workout surfacing on a severe day.

**R1-31. The two routes to care on `Y11`.**
Tap "Find care near you" and "Read NHS guidance on period pain".
*Passing:* whatever happens is true. Today both call `showHonestNotice` with
"maps are not connected in this build" and "opening web links is not connected
in this build" (`app_router.dart:1969`-`1975`), while `url_launcher` is a
dependency and `openExternalLink` is used for the legal links elsewhere in the
same router. Establish which is true.
*Severity:* S1. A woman in severe pain meeting a button that says the app cannot
open a link, in an app that can open links, is the worst possible place for a
stale honest-notice. Also record whether citing **NHS** guidance to an Egyptian
woman is the intended source; `why_suggestion_view.dart:79` flags it as an open
question.

**R1-32. Log a period, `Y09`, and delete one.**
*Passing:* both work; deleting asks nothing more than the product's undo rule
allows; the calendar and the patterns screen agree afterwards.
*Severity:* S1 on data loss.

**R1-33. `Y05` "Why this suggestion" tells the truth.**
*Passing:* the reason named matches the suggestion actually shown, and cites a
source.
*Severity:* S1 if the stated reason is not the operative one.

**R1-34. Cycle settings and sharing, `Y12`.**
*Passing:* every sharing row that mentions a coach or the community is absent
under shipping flags, not present and inert. Deleting cycle data works and says
what it removed.
*Severity:* S1 for a sharing toggle that promises a recipient who does not exist.

**R1-35. The whole cycle flow in Arabic at 1.6x.**
*Passing:* no overflow, no clipping, the calendar mirrors correctly, weekday
order is right-to-left, and the phase names are legible.
*Severity:* S1 for a mirrored calendar that reads the wrong direction, S2 for
clipping.

**R1-36. Tap depth from Home to logging a period.**
Count the taps on a fresh install.
*Passing:* record the number. `docs/qa/03-UX-REVIEW.md` §2 measured six and
called it finding F7 (the door to My cycle is an unlabelled 32pt circle).
Confirm or refute against the current build.
*Severity:* S2, and name it as such rather than escalating on taste.

### F. Progress

**R1-37. Progress with nothing done.**
Fresh install, open `P01`.
*Passing:* no "All five done", no full bar, no "0 of 0" at 100 per cent, no
personal best she has not set.
*Severity:* S1. Two of those three shipped.

**R1-38. Progress after one session.**
*Passing:* every figure moves by exactly what she did, and agrees with Home and
Train.
*Severity:* S1 on disagreement.

**R1-39. `P04` Body, privately.**
Save a measurement.
*Passing:* the undo bar names what she can take back; nothing claims a photo has
been saved; **the screen does not tell her a photo is encrypted on her phone**
unless a store exists. The dictionary carries
`photoCompareStoredOnYourPhoneAnd = "Photo compare, stored on your phone and
encrypted in the app."` while `app/lib/app_state/account_data.dart:212` says
"There is no encrypted photo store in this build and no key to destroy".
Establish which one a woman reads.
*Severity:* S1 if she reads the encryption claim. It is a privacy sentence that
is false.

**R1-40. `P02` and `P03`.**
*Passing:* milestones and bests are earned, not drawn; no best is set by a
session logged from memory.
*Severity:* S1.

### G. Account, language, privacy, deletion

**R1-41. Change her language, `C02`, mid-session.**
From Profile, switch English to Arabic and back.
*Passing:* the whole app changes, including the screen she is on; the choice
survives a restart; nothing she has logged is lost or re-rendered wrongly;
numbers and dates follow the new locale.
*Severity:* S1 on data loss or a half-translated app after the switch.

**R1-42. The privacy centre, `A03`.**
*Passing:* every row present is a row that does something under shipping flags;
the banner's claim ("your logs, weight and photos stay on this phone") is true
against what the app actually writes to Firestore. Note that finding F14 records
deletion is not on this screen, it is one screen back under "Your data".
*Severity:* S1 if the banner is false, because her logs do sync to Firestore
under her own uid; S2 for the placement of deletion.

**R1-43. "Talk to a human".**
*Passing:* whatever this control does, it is honest.
`app_router.dart:1630` makes `onTalkToAHuman` null when `LegalLinks.support`
is empty, and all four `LegalLinks` constants are `''` today.
*Severity:* S1 if a row is drawn and inert; S2 if it is absent and there is then
no support route anywhere in the app, which is itself a store-rejection risk (see
R2-52).

**R1-44. Export everything.**
*Passing:* the export contains what she entered and nothing invented; it says
what it cannot contain (measurements, photos) rather than omitting silently.
*Severity:* S1 if it claims completeness it does not have.

**R1-45. Delete her account, end to end.**
*Passing:* every step of `app/lib/features/account/domain/deletion_manifest.dart`
runs; the app returns to a genuine first-run state, not a logged-in state with
empty screens; nothing she logged survives a restart; the confirmation copy
states what is and is not removed, truthfully (row 34 has no photo store to
destroy).
*Severity:* S1 on anything surviving, and S1 on the app being unusable
afterwards.

**R1-46. The Safety Centre, `A04`.**
*Passing:* under shipping flags, the community rows are absent rather than
present and inert. Any blocking or reporting control that is drawn must do
something, and if nothing reads a report, the screen must say so.
`testBuildNoModerationTeamIsConnected` and `testReportSavedNobodyReadsItIn`
exist in the dictionary; establish whether a woman can reach them.
*Severity:* S1 for a reporting control that silently does nothing; S1 for a
safety promise that is false; S2 for an honest "nobody reads this yet" that is
reachable in a shipping build (record it, it may be intended).

**R1-47. `A01` Notifications.**
*Passing:* the copy is about training, not about an identity check; the gear has
a name; the permission row reads as an action.
*Severity:* S2 (F11 and F12 appear fixed; confirm rather than assume).

**R1-48. The account flow in Arabic at 1.6x.**
*Passing:* no overflow, no clipping, and deletion still completes.
*Severity:* S1 if deletion cannot complete.

### H. Navigation integrity

**R1-49. Every tab is live from every screen that draws the bar.**
Under shipping flags the bar is three tabs: Home (`T01`), Train (`R01`), Eat
(`E01`). Community (`M01`) is dark and must not be drawn. Open each of the ~53
shipping screens, and on every one that draws `AppNavBar`, tap each of the three
tabs.
*Passing:* every tap arrives somewhere. No screen marks a tab active that it is
not. No tab is drawn but untappable.
*Severity:* S1. Eighteen screens did this once. Two guards exist and neither
closes it: `app/test/ui/nav_bar_claims_test.dart` scans six feature folders only,
matches only the literal pattern `activeScreenId: '<ID>'`, and knows only the
three tab ids, so a computed id, a nested folder or a fourth tab escapes it; and
**the tap crawler has a skip list** at `tap_crawler_test.dart:~79` containing
`{'Home','Train','Community','Eat','Today','Clients','Chats','Earnings','Back','رجوع'}`,
so it never taps a bottom-nav label except on `T01` and `K07`. The crawler's
"1,102 taps, zero exceptions" therefore says nothing at all about whether tabs are
live from other screens. This case is the only thing that does.

**R1-50. Community is not a tab.**
*Passing:* the bar shows three destinations, not four, and no screen offers a
route into `M01`-`M17`.
*Severity:* S1.

**R1-51. Back works everywhere.**
From each shipping screen, use the system back and the drawn back control.
*Passing:* she never lands somewhere she was not, never lands on a blank, and is
never trapped.
*Severity:* S1 on a trap.

**R1-52. Every control on every shipping screen, tapped once.**
Run the crawler method, but with `FeatureFlags.shipped` rather than everything
on, over `appDestinations` filtered to the shipping flows.
*Passing:* zero exceptions, zero "not built yet" panels, and every reported
"no visible effect" is an already-selected option tapped again.
*Severity:* S1 for an exception or a placeholder, S1 for a control that looks
live and changes nothing, S3 for a genuine no-op.

**R1-53. No route resolves to `NotBuiltYet` under shipping flags.**
Push every route in `appDestinations` whose flow is on.
*Passing:* none.
*Severity:* S1.

**R1-54. Deep-push a dark route.**
Push `/community/m01`, `/coaching/h01`, `/assistant/x01`, `/admin/z01`,
`/signup/c10` directly.
*Passing:* the gated ones render `FeatureOff` and never `NotBuiltYet`; the admin
ones resolve to null in a release shape; none opens a lens.
`app/test/routing/feature_gating_test.dart` already asserts the `FeatureOff` path
and `release_readiness_test.dart` already asserts the admin one, so this case is
confirming them by hand at the shipping flag set rather than at `allOff`.
*Severity:* S1.

### I. How it renders

**R1-55. The 1.6x sweep, at shipping flags.**
Re-run the large-text method over the shipping surface only.
*Passing:* no thrown overflow.
*Severity:* S1 for an overflow on a shipping screen.

**R1-56. Clipping, which the sweep cannot see.**
The existing sweep fails only on a thrown `RenderFlex` overflow. Text that is
truncated, ellipsised, or clipped by a fixed-height box throws nothing. On each
of these at 1.6x in **both** languages, read the third line of every card:
`T01`, `T07`, `R03`, `R10`, `E01`, `E05`, `E06`, `Y03`, `Y11`, `P01`, `A03`.
*Passing:* no card loses a line, no number is cut, no label is ellipsised to
ambiguity (a truncated Arabic word can invert a meaning).
*Severity:* S1 if a safety or medical sentence is cut, S2 otherwise.

**R1-57. Right-to-left mirroring, judged not by taste but by direction.**
In Arabic, on every shipping screen: which side is the primary action on, which
way do chevrons point, which way does the progress bar fill, which way does the
calendar read, which way does a slider move, which way does a back gesture go.
*Passing:* every one mirrors. Thirteen of the 32 drawn marks are documented as
mirroring in Arabic (commit `866b4e7`); confirm the runner runs the way the page
reads.
*Severity:* S1 for a chevron or a progress direction that contradicts the
reading direction, S2 for a mark that does not mirror.

**R1-58. Empty states.**
Reach the empty state of: Home day one, Eat day one (`E09`), the recipe book
with an allergy declared, Progress with nothing done, the cycle hub before
setup, notifications with nothing in it, the grocery list with no plan.
*Passing:* each one is `AppEmptyState` (there is exactly one shared widget, at
`app/lib/ui/app_empty_state.dart`, with 16 call sites), each says what is absent
and what she can do about it, and none reads as a fault or a warning. The
product's own rule is that the empty state **is** the onboarding: there is no
tour and no tutorial anywhere.
*Severity:* S2, unless it blames her (S1), or unless a screen invents its own
empty card instead of using the shared one (S3 but report it, because it is the
measurable answer to whether the design is one system).

**R1-59. Error states.**
Force a save failure and a read failure on Home, Eat and Cycle.
*Passing:* she is told her work is safe on the phone when it is, and told it is
not when it is not. No raw exception text. No silent swallow.
*Note for the validator:* there is **no shared error widget**. The convention is
`AppCardVariant.error` composed by hand in 10 files, so expect inconsistency and
record its shape rather than its taste.
*Severity:* S1 for a false reassurance.

**R1-60. Loading states.**
*Passing:* anything slower than a frame shows something; nothing flashes an
empty state and then fills; nothing shows a spinner forever.
*Note:* there is **no loading or skeleton widget anywhere**, and
`CircularProgressIndicator` appears zero times in `lib/`. Loading is handled in
the data layer, so a screen renders final state or nothing. On a slow Egyptian
network that is an empty state showing where data is coming, which reads as "you
have nothing".
*Severity:* S1 where an empty state is shown while a fetch is in flight, because
it is a false statement about her data for the length of the fetch; S2 otherwise.

**R1-61. Tap targets, measured.**
On the shipping surface, measure every interactive node from the semantics tree.
*Passing:* nothing under 44 logical pixels in either dimension.
*Where to look, and where not to:* `docs/qa/03-UX-REVIEW.md` F13 listed
`height: 40` call sites as offenders, and that is **no longer the right read**.
`AppButton` (`app/lib/ui/app_button.dart:122`) wraps every variant in
`BoxConstraints(minHeight: height < 44 ? 44 : height)`, so a `height: 40` is a
visual height with a 44 tap target behind it, and
`app/test/ui/app_button_test.dart` asserts exactly that per variant. The same
floor is in `app_chip_row.dart:70`, `app_white_button.dart:53`,
`app_log_button.dart:51` and `app_undo_bar.dart:65`. **The real risk is every
control that does not go through one of those five**, plus
`app/lib/features/eat/presentation/type_it_view.dart:308`, which sets
`materialTapTargetSize: MaterialTapTargetSize.shrinkWrap` and so opts out of
Material's own 48dp floor.
*Severity:* S2, except on a safety path (`Y11`, `A04`, the allergy question),
where S1.

**R1-62. Every interactive node has a name.**
From the semantics tree, list every node with a tap action and an empty label.
*Passing:* the list is empty.
*Severity:* S1 for an unlabelled control on a safety path or an escape hatch
(`R07`'s close), S2 otherwise.

### J. Containment, from the inside

**R1-63. Nothing on a shipping screen mentions a dark feature.**
Read every string rendered on the ~53 shipping screens.
*Passing:* no mention of a coach, the community, a follower, an assistant, a
payment, an earnings figure, a verification check, a reviewer, or a paid recipe
tier, except where the sentence is honestly about their absence.
*Note:* `app/test/release_readiness_test.dart` already has a group
"the first release names nothing it has switched off" with a per-screen loop, and
a group "the controls that used to lead nowhere". Both run with **every feature
on plus `accountRequired`**, which is not the shipping shape. This case is the
same question asked of the app she installs. Read by eye; round two audits the
guard's scope separately (R2-11).
*Severity:* S1.

**R1-63b. Reduced motion.**
Set `disableAnimations` and `accessibleNavigation` and walk the shipping surface.
`handMotionOff` (`app/lib/ui/hand/draw_on.dart:12-15`) is the single place this
is read.
*Passing:* every hand mark is simply there rather than drawing itself, every
press changes colour without moving, and nothing becomes invisible or unreachable
because its entrance animation was the thing that revealed it.
*Severity:* S1 if a control is unreachable with animations off, S2 otherwise.
Nothing in the app reads `boldText`, `highContrast` or `invertColors`; record that.

**R1-64. No testing aid is reachable.**
*Passing:* no screen index, no printed test code, no test payment rail, no admin
route. `AppRouter.testingAidsAllowed` requires `kDebugMode`
(`app_router.dart:730`), so a widget test in debug mode **will** show them.
Run this case with the flags set as `release_readiness_test.dart` sets them and
record what a release shape would show.
*Severity:* S1.

**R1-65. `E09`, `T06`, `Y11`, `Y14` are branches, not screens.**
*Passing:* each renders as a state of its hub, reached by being in that state,
and none of them is also reachable as a stale route.
*Severity:* S2.

**R1-66. Two runs of the same walk produce the same app.**
Run R1-01 twice from a clean state.
*Passing:* identical. Anything that differs between two clean first launches is
either randomised on purpose or is a seed leaking.
*Severity:* S1 if seeded content differs.

---

## 6. Round two: the audit

**Method.** Round two does not open the app. It reads the artefacts and attacks
the claims: every sentence the product says about a woman, every guard that says
the product is fine, every manifest that says what the product collects. Round
one can see a screen that renders perfectly and says something false; round two
is the half that catches it.

**Setup, round two only.** Nothing to boot. Work from the source tree at
`/Users/mahmoudreda/womens-fitness-app-wireframe/.claude/worktrees/release-readiness`.
Where a case needs a new test to prove a point, put it under
`app/test/qa/round2/`. Do not modify an existing test file; if an existing guard
is vacuous, write a **new** test that proves it is vacuous and report the
original's path and line.

### K. The claim audit

The defect class: copy that asserts a fact about her, or about the product, that
is not true. Six instances have shipped. The dictionary has 2,270 keys.

**R2-01. Every sentence that asserts a habit, a history or a pattern.**
Grep `app/lib/l10n/app_en.arb` for: `usual`, `always`, `every`, `weekly`,
`again`, `as you do`, `you normally`, `last`, `since`, weekday names, and the
Arabic equivalents in `app_ar.arb`. For each hit, find its render site and
establish what state it is true in.
*Passing:* every such sentence is either parameterised from her data or is true
of every woman on her first day.
*Severity:* S1 per instance on a shipping screen.

**R2-02. The baked-in ratchet, examined rather than counted.**
`app/test/baked_in_samples_test.dart` holds `_ceiling = 117`: 117 strings in the
dictionary still carry the prototype's own figures. The test only forbids the
number rising.
*Do:* list all 117. For each, determine whether its render site is on a shipping
screen.
*Passing:* the count of shipping-screen instances is zero. Report the list with
render sites; that list is the fixing agent's work queue.
*Severity:* S1 per shipping-screen instance, S2 for one behind a dark flag.

**R2-03. Every privacy sentence, against the code behind it.**
Build the list: every ARB value matching `never`, `only you`, `nobody`, `no one`,
`private`, `encrypt`, `deleted`, `stays on this phone`, `not stored`, `we do not`,
and the Arabic equivalents. There are at least 40. For each, name the mechanism
that makes it true and cite `path:line`.
*Passing:* every one has a mechanism.
*Known suspects to resolve explicitly:*
* `photoCompareStoredOnYourPhoneAnd` ("encrypted in the app") against
  `app/lib/app_state/account_data.dart:212` ("There is no encrypted photo store
  in this build");
* `everythingHereIsSavedOnYourPhone` and any "stays on this phone" banner
  against the fact that her logs sync to Firestore under her uid;
* `onlyYouAndYourCoachEverSee` and `offByDefaultCoachingNeverRequiresIt` in a
  release with no coach;
* `bothImagesAreDeletedAfterTheCheck` and
  `yourIdPhotoAndSelfieHaveBeen` against `AUDIT.md` §3, which is the one place
  they are actually substantiated.
*Severity:* S1 per false claim, whether or not it is currently reachable,
because the flag that hides it is one line.

**R2-04. Every sentence that tells her something about her body.**
Grep for medical, physiological and nutritional assertions: phase names, symptom
explanations, "safe movements", "cleared for postpartum", vitamin and allergen
statements, the pregnancy advisories.
*Passing:* each is sourced or hedged, and none diagnoses. The product's own rule
is "we avoid what hurts, we do not diagnose".
*Severity:* S1 per diagnosis or unsourced physiological claim.

**R2-05. Marketing and capability claims.**
Grep for `verified`, `every member`, `guarantee`, `safe`, `checked`, `women only`.
*Passing:* nothing claims a guarantee the system cannot give.
`RESIDUAL_RISKS.md` §1 is explicit: the wording must be "we check a government
ID", never "we guarantee every member is a woman".
`thisIsTheWholeReasonTheCommunity` says "every member is verified before she can
see or say anything"; check it against §1 and against the fact that verification
is off.
*Severity:* S1.

**R2-06. Arabic that says something the English does not.**
For every key flagged in R2-01 to R2-05, compare `app_en.arb` and `app_ar.arb`
meaning, not just presence. Key parity is already perfect (2,270 each), so the
risk is divergence of meaning, not absence.
*Passing:* no Arabic string is stronger, weaker or differently scoped than its
English.
*Severity:* S1 where a safety or privacy claim differs.

**R2-07. The fifteen identical EN/AR values.**
`aa`, `arabicText_vqu26`, `csv`, `n012100`, `n1`, `n1210`, `n20`, `n23`, `n38`,
`n48126`, `n54`, `n71`, `n84`, `n92`, `nasmCpt`.
*Passing:* each is genuinely non-translatable.
*Severity:* S2.

### L. The guard audit: guards that pass because they measure nothing

The defect class, in this codebase's own words: "a guard that matches nothing
looks exactly like one that works". It has happened at least four times: the
rule 9 guard that filtered to three folders and never looked at `lib/features/train/`;
the rule 7 regex whose trailing `\b` meant `idPhotoUrl` could never match; the
allergen tripwire that looked for `زبادي` when she writes `الزبادي`; the
threshold-scale guard that was correct and aimed at the wrong thing.

**R2-08. Every source-scanning guard gets a positive control.**
Inventory every test that scans source with a `RegExp` and asserts `isEmpty`.
At minimum: `product_rules_test.dart` (rules 3, 7, 8, 9, 11, the API-key scan),
`i18n_guard_test.dart`, `nav_bar_claims_test.dart`, `baked_in_samples_test.dart`,
`nav_reachability_test.dart`, `release_readiness_test.dart`, and any guard in
`functions/tests/test_contract.py`.
*Do:* for each, construct a string that **must** match and prove the pattern
catches it, and a string that must not and prove it does not. Two of the rule
guards already carry their own positive control (`product_rules_test.dart:246`
and `:400`); the rest do not.
*Passing:* every guard has a proven positive control.
*Severity:* S1 for any guard on a safety rule that cannot be proven to bite; S2
otherwise.

**R2-09. Every guard's scope, against what it claims to cover.**
For each guard, list what it does **not** look at.
*Known, and to be confirmed and reported with the current numbers:*
* `nav_bar_claims_test.dart` covers six feature folders, only
  `lib/features/<f>/presentation` (recursive within it), only the literal
  `activeScreenId: '<ID>'`, only the tab ids `T01`/`R01`/`E01`. Dark flows,
  computed ids and a fourth tab all escape.
* `product_rules_test.dart` rule 9 scans `/features/` and `/domain/logging`.
* `product_rules_test.dart` `_ownSource()` excludes `/l10n/app_l10n`.
*Passing:* every exclusion is either justified in a comment or reported.
*Severity:* S2 for a documented gap, S1 where the gap covers a shipping safety
surface.

**R2-10. Every exemption in a guard, proved not to be a hole.**
Three exist: the deny-list exemption in `product_rules_test.dart:38-74`, the
`lib/firebase_options.dart` exemption at `:390`, and the `_arabicAllowed` map in
`i18n_guard_test.dart`.
*Passing:* each has a paired test that proves the exemption cannot hide a real
violation. Two already do; check `_arabicAllowed` and check that every entry in
it is still needed.
*Severity:* S1.

**R2-11. Guards that run at the wrong flag set.**
List every test that sets `AppRouter.featureFlags` and record which shape it uses
(§1.2). Report every guard that asserts something about "the release" while
building a different app from the one that ships.
*Passing:* the report exists and names each one. `release_readiness_test.dart:31`
builds every feature on plus `accountRequired`, which is not `FeatureFlags.shipped`.
*Severity:* S1 if a store-build guard proves its property only of a build that
will never be submitted.

**R2-12. The 1.6x sweep's blind spot, stated.**
`large_text_sweep_test.dart` fails only on a thrown exception, and it swallows
long-animation exceptions in `_settle`. It therefore cannot see clipping,
ellipsis, a fixed-height box, or an overflow inside an animation that is still
running.
*Passing:* the limitation is written down and a case exists (R1-56) that covers
it by another method.
*Severity:* S2 for the guard; the defects it misses are sized on their own.

**R2-13. Tests whose fixtures do not resemble real data.**
The four recipes that printed 22 steps instead of 11 were missed because "every
fixture was hand built with no components". Audit the fixtures under
`app/test/fixtures/` and the in-test constructors for the Eat, Train and Cycle
suites.
*Passing:* every fixture exercises the shapes the real seed contains: recipes
with components, ingredient lists with "or" pairs, recipes with no quantities,
sessions with bodyweight sets, cycles with a symptom-only profile.
*Severity:* S1 where a real-data shape is untested on a safety surface.

**R2-13a. Tests that lay out against nothing.**
The device-size helper is copy-pasted into about 67 files. Some build
`MediaQueryData(textScaler: ...)` from scratch instead of
`MediaQuery.of(context).copyWith(...)`; a bare `MediaQueryData` zeroes the window
size, so the widget lays out against a zero-sized screen and **every size, overflow
and position assertion in that file is meaningless**.
`app/test/features/today/today_view_test.dart` documents the trap and uses
`copyWith`; `app/test/features/train/train_view_test.dart:28` and
`app/test/ui/app_nav_bar_test.dart:33` do not.
*Do:* list every test file that constructs a bare `MediaQueryData`, and for each,
name one assertion in it that is therefore not evidence.
*Passing:* the list is reported. The recommendation is one shared harness at
`app/test/support/`, promoted from
`app/test/features/coachbrand/coachbrand_test_host.dart`, which is the only copy
that gets device size, locale, theme and text scale all right.
*Severity:* S2, S1 where the meaningless assertion is the only thing guarding a
shipping screen's layout.

**R2-13b. Tests that have never been run.**
`VERIFICATION_REPORT.md` blocking item 6 records that the emulator security-rules
tests and the on-emulator function integration tests **have not been run**. The
brief's "206 security-rules tests" is a count of cases, not a passing result: the
suite is 165 `test(...)` cases plus 43 `describe(...)` suites across 12 files in
`test/rules/`.
*Do:* start the emulator on the alternate config and run them.

```bash
firebase emulators:start --config firebase.emulator.json --project own-hub
cd test/rules && npm test
```

`firebase.emulator.json` puts Firestore on 127.0.0.1:8088 and Auth on
127.0.0.1:9098, deliberately not the 8080/9099 in the default `firebase.json`.
The harness reads `firebase/firestore.rules` verbatim, so it tests the deployed
file rather than a copy.
*Passing:* all of them pass, and the count is recorded. Also run
`cd functions && ./.venv/bin/python -m pytest tests/ -q` and record the number
(360 collected today, against a stale "299 passed" in the report).
*Severity:* S1 for any rules failure, since the rules are what actually protects
her data; S2 for the stale figures in the report.

### M. Mock and live divergence

The defect class, three instances so far: the mock Vision provider charged
unconditionally and the live one did not (a 118,000 dollar a month hole); the
mock treated a whitespace-only read as usable and the live one did not; the
liveness provider and the threshold set declared different score scales, which
would have failed every real verification while the suite stayed green.

**R2-14. Every interface with more than one implementation.**
Inventory them. At minimum `VerificationProvider` (fake vs
`CallableVerificationProvider`), `VerificationRepository`, the three provider
interfaces in `functions/identity/providers.py` against
`providers_selfhosted.py`, every `InMemory*Repository` in `AppRouter` against
its cloud counterpart, and `CloudStore`.
*For each:* is there a test that drives both through the same script and asserts
they agree? Name it, or report its absence.
*Passing:* every pair has a parity test. One exists for Vision
(commit `6791719`); the others are unknown until this case runs.
*Severity:* S1 for a pair where disagreement costs money, admits someone, or
loses her data; S2 otherwise.

**R2-15. The in-memory repositories against Firestore.**
`AppRouter` holds `InMemoryIntakeRepository`, `InMemoryTodayRepository`,
`InMemoryTrainRepository` and a progress store; her logs also sync to Firestore.
*Passing:* the merge behaviour is the same in both, in particular the
merge-by-union that stops signing in from deleting the week she logged before she
had an account.
*Severity:* S1 on any path where one implementation loses data the other keeps.

**R2-16. Firestore rules against the client's assumptions.**
For each of the four paths exempt from the verified gate (`users/{uid}`,
consents, deletion requests, the safety collections), confirm the client writes
only what the rule allows, and that `isSelfVerified` has not been tidied into a
uniform gate.
*Passing:* the exemption comment is intact and the four paths still work.
*Severity:* S1. `RESIDUAL_RISKS.md` §9 names this as a trap whose failure is
invisible from the rule that causes it.

**R2-17. Born-state versus updated-state in the rules.**
The escalation in commit `64e20c8` found documents that could be *born* holding
what they could never be *changed* to: a coach page born with a five-star rating,
a post born with 99,000 likes, a user document born with a plaintext national ID.
*Passing:* every collection in `firebase/firestore.rules` validates create and
update against the same field constraints.
*Severity:* S1 per instance.

### N. Reachability and containment, from the source

**R2-18. Every dark flow has a gating decision.**
`AppRouter.decidedFlows` must contain every flow in `appRoutes`.
*Passing:* asserted already in `feature_gating_test.dart`; confirm it still holds
and that no flow was added without a decision.
*Severity:* S1.

**R2-19. Nothing routes into a dark flow.**
Parse every `goTo(context, 'XX')` literal in `app_router.dart`. For each edge,
check the source flow is on under `FeatureFlags.shipped` and the destination is
too.
*Passing:* no edge crosses from a shipping screen into a dark one.
*Severity:* S1.

**R2-20. Nothing is orphaned.**
For every public method on a repository or service in `lib/domain` and
`lib/app_state`, find a call site.
*Passing:* every one has one. `WeeklyGoalService.setTarget` had none, which is
how the app imposed three sessions a week on everybody.
*Severity:* S1 where the orphan is a setting she is supposed to control, S2
otherwise.

**R2-21. Every `firstRunStates` branch has a builder, and every route without a
builder is in `firstRunStates`.**
*Passing:* the two sets agree. `T08` is currently in neither (finding F17), so it
resolves to the "not built yet" panel.
*Severity:* S2 today, S1 once a notification payload can name it.

**R2-22. The admin console.**
`resolvesInThisBuild` (`app_router.dart:441`) blocks the admin flow when
`kReleaseMode` is true. Note that this is route-level unreachability, not
tree-shaking: the admin code is still linked into the binary.
*Passing:* no admin route resolves in a release shape, and no admin string is
reachable from any shipping screen.
*Severity:* S1 if a route resolves; S2 for the strings remaining in the binary,
recorded rather than fixed.

**R2-23. Testing aids need a debug build, not a flag.**
`testingAidsAllowed` is `kDebugMode && !featureFlags.isOn(Feature.accountRequired)`.
`accountRequired` is **off** in the shipping flags, so the second half of that
conjunction is true in the app she installs, and `kDebugMode` is the only thing
standing between her and the screen index, the printed test code and the test
payment rail.
*Passing:* `kDebugMode` is genuinely false in a `--release` build and no other
path re-enables the aids. Check every `isTestMode` getter
(`coach_portfolio_state.dart:61`, `coach_profile_state.dart:49`,
`coaching_link_state.dart:77`).
*Severity:* S1. A single boolean is the whole defence and the failure is silent.

### O. Safety, audited

**R2-24. The allergy interlock cannot be opened by accident.**
`AllergyGuard.screen()` removes any food with `allergens == null` when she has
declared an allergy, and `allergy_interlock_test.dart:41` fails the build the
moment any food carries allergen data while `eatConstraints` returns
`DietaryConstraints.none` for an unasked profile.
*Passing:* the interlock is intact; `none` is only ever returned for a woman who
was asked and named nothing; no path returns `none` for a woman who was never
asked.
*Severity:* S1.

**R2-25. The allergen vocabulary is complete and its aliases are total.**
Sixteen tokens per `RECIPES-PLAN.md` §3.4. `AllergenTag.fromWire` must still
accept the four old spellings (`nuts`, `dairy`, `gluten`, `shellfish`) so a saved
profile does not silently lose a declaration, and `shellfish` must map to **both**
`crustaceans` and `molluscs`.
*Passing:* the alias table is total and tested.
*Severity:* S1. A dropped declaration is a woman eating something she told the
app she cannot.

**R2-26. The tripwire fires, and fires on the right words.**
The dictionary in `RECIPES-PLAN.md` §3.4 must match longest-first (`فول سوداني`
before `فول`), must cover the definite article (`الزبادي` as well as `زبادي`),
and must be proven to fire at least once per tag.
*Passing:* for each of the sixteen tags, a positive control exists. Report any
tag that fires on nothing across all 39 recipes, because that is
indistinguishable from a broken pattern.
*Severity:* S1.

**R2-27. Two signatures, enforced where a Dart bug cannot bypass it.**
`authoredBy != allergenReviewedBy`, enforced in `firebase/firestore.rules` on the
`recipes` write.
*Passing:* the rule exists and a rules test proves it refuses equal names.
*Severity:* S1.

**R2-28. The app never certifies.**
Grep the dictionary for any sentence that says a dish is safe, fine, or suitable
for her.
*Passing:* none. The standing line must be present on every recipe card.
*Severity:* S1.

**R2-29. The severe gate has one definition and one call site per consumer.**
`app/lib/features/cycle/domain/severe_symptom_gate.dart` defines severe as
`cramps == severe || bleeding == heavy`.
*Passing:* nothing anywhere re-implements that test; no widget can render a
workout on a severe day by forgetting a case (`day_suggestion.dart:11` says the
type is shaped to make it unrepresentable, so confirm the type still is).
*Severity:* S1.

**R2-30. The gentler option is unreachable on a severe day, and reachable on the
symptom-only path.**
*Passing:* both.
*Severity:* S1.

**R2-31. The two care routes on `Y11`.**
Establish, from the source, whether `url_launcher` can open a map and a URL
today, and therefore whether `mapsAreNotConnectedInThisBuild` and
`openingWebLinksIsNotConnectedIn` are still true. `openExternalLink` is used for
the legal links in the same router.
*Passing:* the notice matches the capability.
*Severity:* S1.

**R2-32. Blocking and reporting.**
`AUDIT.md` §0 defect 3 records that `notBlockedBy` was defined and never called,
so blocking was enforced in the app and nowhere else. It is now wired to four
single-document writes.
*Passing:* the rules still call it; a rules test proves a blocked account cannot
comment, follow or message; and under shipping flags the app does not draw a
blocking control for a community that does not exist.
*Severity:* S1.

**R2-33. The deletion manifest is complete and honest.**
Walk every row of `app/lib/features/account/domain/deletion_manifest.dart`
against what the app actually writes, locally and in Firestore.
*Passing:* no row is a no-op that the copy presents as an erasure; row 34
(the photo store key) says plainly that there is nothing to destroy; the
registry `state: 'closed'` shape matches the server's.
*Severity:* S1.

**R2-34. Rule 7 holds on the client.**
There is nowhere on the handset to put an ID image, a selfie, a document number,
a legal name or a date of birth.
*Passing:* `product_rules_test.dart` RULE 7 passes **and** its positive control
still proves the pattern bites, including the mid-word continuation case
(`idPhotoUrl`) that a trailing `\b` used to miss.
*Severity:* S1.

**R2-35. Rule 8: sex comes from the number, never a face.**
*Passing:* no classifier anywhere; face **detection** for blur is permitted and
must be distinguishable from classification in the code.
*Severity:* S1.

**R2-36. Rules 3 and 11: no streak, no ranking.**
*Passing:* both guards pass and both bite.
*Severity:* S1 for rule 11 on a women-only product; S2 for rule 3.

### P. Design and finish, judged by measurement

The owner asked whether the designs and icons are clean and ready. That is a
taste question, so this section replaces taste with numbers wherever it can and
says plainly where it cannot.

**R2-37. The 32 marks, inventoried and named.**
They are `CustomPainter` paths drawn in code: 26 native `case` arms in
`ArtMarkPainter._draw` (`app/lib/ui/hand/art_marks.dart`) and 6 borrowed from
`FoodMarkPainter` through the `ArtMarkPainter.borrowed` map at `art_marks.dart:179`
(`bowlSalad`, `steak`, `toastEgg`, `breakfast`, `bruschetta`, `pasta`). The names
live in `app/lib/theme/app_art.dart` as `static const String`s, and placement is
the 166-entry table in `app/lib/theme/screen_art.dart`.
*Passing:* the count is 32, none is an image asset, `pubspec.yaml` bundles zero
illustrations, and `app/assets/art/LICENCE.md` still records that all 57 Canva
WebPs were deleted.
*Also report:* the names are **strings, not an enum**, so a typo is a runtime
fallback rather than a compile error. `app/test/theme/app_art_test.dart` is the
only thing standing behind that.
*Severity:* S1 for any third-party artwork still in the tree, which is a licensing
exposure rather than a design opinion; S2 for the string-keyed API.

**R2-38. The two rules the marks were drawn under.**
Every figure has a plain circle for a head, no face and no hair, because whether
a woman covers her hair is not a position an empty state should take.
*Passing:* holds across all 32.
*Severity:* S1 for any mark that takes that position.

**R2-38b. Mirroring: thirteen or fourteen?**
Commit `866b4e7` says "thirteen of the thirty two mirror in Arabic". The
`ArtMarkPainter.facing` set at `art_marks.dart:197` lists **fourteen**:
`running, dance, strong_arms, squat_weights, lunge_kneeling, plank,
stretch_seated, side_stretch, rest_floor, trainers, spin_bike, boxing_gloves,
plate_mixed, steak`.
*Passing:* resolve which is right and whether every mark that depicts direction of
travel is in the set. A runner that runs against the reading direction is the
defect the set exists to prevent.
*Severity:* S2.

**R2-39. The placement rules in `screen_art.dart` hold.**
Four are stated in its header: each mark matches what the screen is for; the
sensitive screens (cycle, privacy, safety centre, body measurements, every
waiting screen) use only meditation, stretching or the yoga mat; **no treat ever
appears via `ScreenArt`**; never the same picture twice on one screen.
*Passing:* all four, across the shipping screens. Note that `FoodMarks` is a
**separate** 16-name vocabulary for recipe cards and does contain
`cake_slice`, `cookie` and `fries`. A treat reaching a screen through `ScreenArt`
is the failure; a treat on a recipe card she opened is not.
*Severity:* S1 for an intense mark on a cycle, privacy or safety screen, because
the calm rule is a product decision about women in pain; S2 otherwise.
`app/test/theme/screen_art_test.dart` already covers the count rules; this case
is about the judgement ones.

**R2-39b. No mark is announced or tappable.**
Every mark is wrapped in `ExcludeSemantics` (`art_marks.dart:122`).
*Passing:* no mark appears in the semantics tree anywhere, and none carries a tap
action. `HandNote` is the deliberate exception because it is real text.
*Severity:* S2.

**R2-39c. Marks are deterministic.**
The wobble is seeded from `handSeed(['art-mark', markKey])`, so a mark must be
pixel-identical on every rebuild.
*Passing:* two renders of the same mark are identical. A shimmering mark is a bug.
*Severity:* S2.

**R2-40. Colour is defined once, and spacing is not defined at all.**
`AppColors` (`app/lib/theme/app_tokens.dart`, generated from
`6-v2/src/tokens.mjs`) holds 38 colours. `HandInk` and `BookInk` are roles over
them, not copies.
*Do:* report every brand-colour hex literal in `lib/features/` (expected: none),
and report **the absence of a spacing scale**. There is no `AppSpacing` anywhere;
the only shared constants are `kStackGap = 10`, `kBodyPadding` and
`kFooterPadding` in `app/lib/ui/app_scaffold.dart:28-31`, and everything else is
a per-file literal `SizedBox(height: 3/6/8/9/10/12)` and
`EdgeInsets.symmetric(horizontal: 13, vertical: 11)`.
*Passing:* the report exists, with a count of distinct vertical-gap values used
across the shipping screens. That number is the answer to "does the design read as
one system", stated as a number rather than a taste.
*Severity:* S3 individually, S2 as a whole if the count is large.

**R2-40b. Generated tokens have not been hand-edited.**
`app_tokens.dart` line 1 says "GENERATED from 6-v2/src/tokens.mjs, do not edit by
hand".
*Passing:* the Dart matches the JS. They can drift silently and nothing checks.
*Severity:* S2.

**R2-41. Contrast, computed over the app's own palette.**
A full WCAG 2.1 implementation already exists at
`app/lib/features/coachbrand/domain/contrast.dart`: `relativeLuminance`,
`contrastRatio`, and `ContrastThresholds` with the documented decision that
`titleL` (20/w600) and `titleM` (17/w600) are held to **4.5:1, not 3.0:1**,
because w600 is not bold under WCAG. **It is applied only to coach-authored
portfolio themes.** The app's own `AppColors` pairs have never been run through
it. The one measured claim, at `recipe_book_tokens.dart:19`, is that
`AppColors.primary` on `AppColors.surface` is **4.58:1**, which is 0.08 above the
floor.
*Do:* run every text-on-background pair the theme actually produces through
`contrastRatio`, using `ContrastThresholds.forTextStyle` mapped onto the nine
`AppText` styles.
*Passing:* every pair meets its threshold. Report each ratio to two decimals with
its token names.
*Severity:* S2 for body text below 4.5:1, S1 for a safety or medical sentence
below it. Report anything within 0.2 of the floor as a fragility note, because a
token nudge would break it silently.

**R2-42. The tap-target floor is a floor, and everything routes through it.**
The 44 minimum is enforced in five widgets and the number `44` is inlined in each
of them: `app_button.dart:122`, `app_chip_row.dart:70`,
`app_white_button.dart:53`, `app_log_button.dart:51`, `app_undo_bar.dart:65`.
There is **no named constant**, so a sixth widget gets no floor and nothing
fails.
*Do:* list every interactive widget in `lib/ui/` and `lib/features/` that is not
one of those five and does not declare a 44 minimum. Report
`type_it_view.dart:308` (`MaterialTapTargetSize.shrinkWrap`) separately, because
it removes a floor rather than failing to add one.
*Passing:* the list is reported, and the recommendation is one named constant
rather than a sixth inlined literal.
*Severity:* S2 per uncovered control, S1 on a safety path.

**R2-43. Right-to-left primitives.**
This is the strongest area in the codebase and the audit should confirm it rather
than assume it. Counts to reproduce: `EdgeInsetsDirectional` 26,
`AlignmentDirectional` 34, `PositionedDirectional` 18, raw `Alignment.centerLeft`
and friends **0**, `TextAlign.left`/`right` **0**, `EdgeInsets.fromLTRB` 38 and
every one of them symmetric.
*The one known offender:*
`app/lib/features/progress/presentation/body_privately_view.dart:347`
`padding: EdgeInsets.only(right: 8)` on a padlock in the top bar. In Arabic the
icon moves to the left and its gap stays on the physical right, against the
screen edge instead of the title. Should be `EdgeInsetsDirectional.only(end: 8)`.
*Passing:* the counts hold and that is the only one.
*Severity:* S3 for the padlock, S1 for any newly found instance that puts a
primary action on the wrong side or reverses a direction of travel.

**R2-43b. The one forced-LTR subtree.**
`app/lib/ui/hand/book_card.dart:202` wraps the recipe card in
`Directionality(TextDirection.ltr)`, with the reason stated at `book_card.dart:22`.
*Passing:* the reason still holds and nothing inside that subtree is a control, a
number she reads, or Arabic prose that must read right to left.
*Severity:* S1 if Arabic prose is rendered inside a forced-LTR subtree, because a
sentence that reads the wrong way is unreadable rather than ugly.

**R2-44. Fixed heights around text.**
Distinguish a **floor** from a **fixed box**. `AppButton`, `AppChipRow`,
`AppPill` and `AppField` all take `height` as a `minHeight` and say so in their
headers, so their call sites are not risks. The genuine fixed boxes, to be
checked at 1.6x in Arabic:
* `app/lib/ui/app_segmented.dart:27-28` `SizedBox(height: 44)` around localised
  labels, and the segmented control appears on many screens. Highest value.
* `app/lib/ui/app_nav_bar.dart:241-242` `SizedBox(height: 60)` holding a 32px
  icon box, a 4px gap and a 12px `AppText.nav` label. At 1.6x the label alone
  wants about 25.6px, so 32 + 4 + 25.6 = 61.6 against a 60 box. It is mitigated
  by `Flexible` plus `TextOverflow.ellipsis`, which means it truncates rather
  than throws, **which is exactly why the 1.6x sweep does not see it.** The bar
  also clamps its own scaling at 1.35 (`app_nav_bar.dart:166`), so a woman at the
  largest accessibility sizes gets tab names smaller than the rest of the screen.
* `app/lib/ui/app_media.dart:99-101` `Container(height: 26)` around a 13px badge.
* `app/lib/features/community/presentation/story_viewer_view.dart:295-299`
  `Container(height: 46)` around `AppText.body` with `maxLines: 1` (dark flow).
* `app/lib/features/coachbrand/presentation/look_view.dart:467-469` a 42x28
  swatch beside a label that grows (dark flow).
* `app/lib/features/community/presentation/reels_view.dart:427`
  `FollowPill(height: 30)`: establish whether `FollowPill` treats height as a
  floor or a fixed box (dark flow).
*Passing:* the list is reported with a measured overflow figure at 1.6x in both
languages for the three on the shipping surface.
*Severity:* feeds R1-56. The nav bar is S1 if an Arabic tab name truncates to
ambiguity, because it is the product's primary navigation.
*The correct pattern to cite as the counter-example:*
`app/lib/ui/app_ring_stat.dart:68-75`, a `FittedBox` inside a fixed-size ring with
its reasoning inline.

**R2-45. One empty state, no error state, no loading state.**
`AppEmptyState` (`app/lib/ui/app_empty_state.dart`) is a single shared widget with
16 call sites, and it stacks vertically above textScaler 1.3.
**There is no shared error widget.** The convention is `AppCardVariant.error`
(`app_card.dart:50`) used in 10 files, each composing its own heading, body and
button.
**There is no loading or skeleton widget at all**, and
`grep CircularProgressIndicator lib/` returns zero hits. Loading is handled in
the data layer, so a screen renders final state or nothing.
*Do:* list the 10 hand-built error surfaces and report how many distinct shapes
they take. List every shipping screen that fetches and say what it draws while it
waits.
*Passing:* the report exists. This is the concrete, non-taste answer to "does it
look finished": one empty state is a system, ten different error cards are not,
and no loading vocabulary at all is a gap a slow Egyptian network will find.
*Severity:* S2 for the error inconsistency, S2 for the loading gap, S1 for any
screen that shows a **wrong** state while waiting (an empty state that then fills
reads as "you have nothing" and is a lie for the length of the fetch).

**R2-46. Fonts and their licences.**
Three families ship, all SIL OFL 1.1: **Rubik** 400/500/600/700, which carries
**both** scripts and is the whole interface face for English and Arabic alike;
**LaBelleAurore** 400 for Latin handwriting; **ArefRuqaa** 400/700 for Arabic
handwriting. There is no separate Arabic UI face. Licence texts are bundled as
assets and registered with `LicenseRegistry` at `app/lib/main.dart:34`, so they
appear on the OS licences page.
*Do:* confirm every glyph used by `app_ar.arb` is in the shipped Rubik subset and
in ArefRuqaa. Confirm the script switch at
`app/lib/ui/hand/hand_marks.dart:341-356` picks ArefRuqaa for Arabic and
LaBelleAurore otherwise, and note the 1.28x LaBelleAurore upscale that compounds
with the system scaler.
*Also:* `app/assets/art/LICENCE.md` is **stale**. It still records that Rubik's
OFL text is not in `assets/fonts/` and lists it as open, while `OFL-Rubik.txt`
now exists, is bundled and is registered.
*Passing:* no missing glyph, no missing notice, and the licence file matches the
tree.
*Severity:* S1 for a missing glyph (it is tofu on a device and no widget test
shows it), S1 for a missing licence notice, S2 for the stale record.

**R2-46b. There is no dark mode, and that is deliberate.**
`buildTheme` uses `const ColorScheme.light` only; there is no `ThemeMode`, no
`darkTheme`, no `ColorScheme.dark`. An unshipped inversion is recorded as a note
at `recipe_book_tokens.dart:31-40`.
*Passing:* with the OS in dark mode the app stays light and legible, and nothing
half-inverts (a system-tinted status bar over a light page, a dark keyboard, a
share sheet).
*Severity:* S2.

**R2-46c. `DESIGN.md` does not exist.**
`app/lib/ui/app_chevron.dart:8` quotes `DESIGN.md` as the authority for a
directional-painter rule. `git log --all -- "**/DESIGN.md"` returns nothing: the
file was never committed, in this repo or the main one.
*Passing:* either the file exists or the citation is corrected. The design
language's only cited authority is currently a phantom, and the rules that
actually govern it live as library dartdoc in `hand_tokens.dart`,
`hand_marks.dart`, `app_art.dart`, `screen_art.dart`, `app_empty_state.dart`,
`app_button.dart`, `draw_on.dart` and `hand_surface.dart`.
*Severity:* S2. It is not a defect a woman meets, and it is the reason the next
person to touch the design will get it wrong.

### Q. Store readiness

**R2-47. The iOS privacy manifest against what the app actually does.**
`app/ios/Runner/PrivacyInfo.xcprivacy` declares `NSPrivacyTracking false`, and
**empty** `NSPrivacyTrackingDomains`, `NSPrivacyCollectedDataTypes` and
`NSPrivacyAccessedAPITypes`. Its own header comment says the app "has no backend
wired: pubspec carries no Firebase, no analytics, no ads and no HTTP client".
That is no longer true: `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firebase_storage` and `cloud_functions` all ship, and `shared_preferences` uses
NSUserDefaults (required-reason API CA92.1).
*Passing:* the manifest matches the build.
*Severity:* S1. A manifest that disagrees with App Store Connect's privacy
answers is a rejection, and this one currently declares that an app with phone
sign-in collects nothing.

**R2-48. The permission strings.**
Exactly one usage description exists, `NSCameraUsageDescription`, in English in
`Info.plist` and `en.lproj/InfoPlist.strings`, and in Arabic in
`ar.lproj/InfoPlist.strings`. There is deliberately no photo-library key, so a
woman cannot submit a photo of somebody else's ID card.
*Passing:* the Arabic string says the same thing as the English; both name what
is captured, that nothing is uploaded until she taps send, and that the images
are deleted. Android has one `<uses-permission>`, `CAMERA`, and no writable
rationale string, so the in-app consent screen is the only place the explanation
appears: confirm it appears **before** the runtime prompt in both languages.
*Severity:* S1 for a Play prominent-disclosure failure; S2 for a wording
mismatch between languages.

**R2-49. The reviewer's route into the app.**
`RESIDUAL_RISKS.md` §10: the answer to guideline 2.1(a) is spec §5's server-side
reviewer allowlist, and it is **NOT IMPLEMENTED** because it needs the uid of a
review account that does not exist. It must never be a client flag or a hidden
gesture.
*Passing:* record the state honestly. Note that while `accountRequired` is off
there is no gate, so a reviewer can use the app today; the allowlist becomes
blocking on the release that flips the gate.
*Severity:* S1 from the release that flips `accountRequired`, S2 before it.

**R2-50. Guideline 5.1.1(v).**
Requiring a government ID for a fitness app is the accepted exposure recorded in
`RESIDUAL_RISKS.md` §10.
*Passing:* the justification is written down where a submission can quote it, and
the app's own copy matches it.
*Severity:* S2, recorded, not fixable here.

**R2-51. Age rating and the age gate.**
`site/config.json` records that the age number (16 or 18) is set by counsel, is
not enforceable in a release with no account, and "must appear identically here,
in the app, and in both store age ratings from the release that introduces
accounts onwards".
*Passing:* the app states no age it cannot enforce, and no store answer is
drafted from a guess.
*Severity:* S1 if the app asserts an age gate it does not enforce.

**R2-52. There is no privacy policy inside the app.**
All four `LegalLinks` constants are `''`
(`app/lib/config/legal_links.dart`), the UI hides the rows rather than showing
broken links, and `onTalkToAHuman` is null. `site/config.json` has
`baseUrl = https://ownhub.example`, which is an RFC 2606 placeholder and will
404 for a reviewer.
*Passing:* record this as the blocking state it is. It is item 2 of
`OWN-HUB-BEFORE-PROD` and is out of scope to fix, **but** the second-order
consequence is in scope: a reviewer opening the app finds no privacy policy and
no support route at all.
*Severity:* S1, owner-blocked.

**R2-53. The launch experience.**
iOS `LaunchImage.imageset` holds 1x1 placeholder PNGs; both Android
`launch_background.xml` files are the stock white stub.
*Passing:* record what a cold start looks like. This is the commonest source of
an "incomplete app" review note.
*Severity:* S2.

**R2-54. The deployment-target mismatch.**
`IPHONEOS_DEPLOYMENT_TARGET = 15.0` in `project.pbxproj` against
`platform :ios, '15.5'` in `app/ios/Podfile`.
*Passing:* they agree.
*Severity:* S2, S1 if it fails validation at archive time.

**R2-55. The release build is signed with the real key.**
`app/android/app/build.gradle.kts` falls back to the **debug** signing config
when `key.properties` is absent, silently. The preflight has a check for this and
the current AAB carries `META-INF/UPLOAD.RSA`.
*Passing:* confirm the preflight check exists and that nothing can produce a
debug-signed release quietly.
*Severity:* S1.

**R2-56. The preflight, run and reconciled.**
Run `app/tool/release_preflight.sh` and reconcile the result against the 33
checks it contains.
*Passing:* exactly two failures, both owner-blocked: `team id filled in`
(`YOUR_TEAM_ID` in `app/ios/ExportOptions.plist`) and `legal links filled in`
(the four empty constants). The four public-URL checks SKIP while
`RELEASE_BASE_URL` is unset.
*Severity:* S1 for any **third** failure, which would be a regression.

**R2-57. Screenshots and store metadata.**
None exist anywhere in the repo: no fastlane directory, no screenshots, no data
safety answers, no content rating answers.
*Passing:* record the absence and what it blocks. Note that
`site/config.json`'s `storeFormsMustAgree` requires both store forms, the iOS
privacy manifest and Part B of the privacy policy to go live in the same release.
*Severity:* S1 for the submission, owner-blocked on items 4 and 5.

### R. Sign-up and verification, inside the boundary

**R2-58. Consent cannot be skipped by a route.**
`AppRouter.consentRecorded` gates `/signup/c10` because `onGenerateRoute` cannot
await the store (`app_router.dart:4205`-`4211`).
*Passing:* no route into `C10`, `C10b` or `C11` exists that does not pass through
`C09b` first.
*Severity:* S1.

**R2-59. The niqab route opens no lens.**
`_opensALens = {'C10','C10b','C11'}` (`app_router.dart:4203`) and `C15` reaches
none of them.
*Passing:* structurally, not by promise.
*Severity:* S1.

**R2-60. The client never holds a verdict.**
*Passing:* the type that used to carry one is gone and the two guards that fail
the build if it returns are intact.
*Severity:* S1.

**R2-61. The five user-safe reason codes map onto readable copy.**
`functions/identity/reasons.py` maps 48 internal codes onto 5 user-safe ones.
*Passing:* each of the five has copy in both languages, each tells her what to do
next, and none of them leaks which control failed.
*Severity:* S1 for a leak (it is a free oracle for an attacker), S2 for missing
copy.

**R2-62. The lockout has no exit.**
`OWN-HUB-BEFORE-PROD` item 17: four unreadable photographs lock a woman out
permanently, with no expiry and no override, and her hint says contact support,
which has nothing to act on and, today, no address.
*Passing:* confirm the state and confirm the copy does not promise a support
route that does not exist.
*Severity:* S1 for the copy, owner-decision for the feature.

**R2-63. A double submit charges once.**
*Passing:* `operation_id` idempotency holds, and the replay check sits **before**
the paid Vision calls, not inside the spend. Commit `6791719` moved it; confirm
it stayed moved and that a test asserts the provider was not called again, not
merely that the ledger stayed flat.
*Severity:* S1.

### S. Localisation, audited

**R2-64. No hardcoded Arabic or English in a widget.**
`i18n_guard_test.dart` enforces it with an allowlist of one presentation file
(`language_view.dart`, the language chooser).
*Passing:* the guard passes, bites, and every allowlist entry is still needed.
*Severity:* S1 for Arabic in a widget (the English build then shows Arabic and no
English test notices), S2 for English.

**R2-65. Numerals, dates and plurals.**
*Passing:* Arabic numerals render the way the product decided (one way, not two);
dates read "8 Sep to 7 Oct" with no dash; plurals are handled by ICU rather than
by concatenation; no string builds a sentence by joining values with a dash.
*Severity:* S2.

**R2-66. Every string that reaches a shipping screen exists in both files and
means the same thing.**
Key parity is already perfect and is asserted by `i18n_guard_test.dart`
(`expect(ek.difference(ak), isEmpty)` both ways, 2,270 keys each). What that guard
does **not** assert: that an Arabic value is non-empty, that it differs from its
English counterpart (an untranslated copy-paste passes), or that ICU placeholders
and argument counts match between the two locales.
*Do:* add the three missing checks, and read every safety, medical and privacy
string in both languages by hand.
*Passing:* no empty Arabic value, no accidental English left in `app_ar.arb`
beyond the fifteen known non-translatables, and every placeholder present in one
locale present in the other with the same name and type.
*Severity:* S1 per divergence on a safety string; S1 for a placeholder mismatch,
because it throws at render time in one language only.

**R2-67. The previous round's open findings, re-checked.**
`docs/qa/03-UX-REVIEW.md` closed with twenty findings. F1 to F6, F9 and F10 were
fixed by commit `363a22e`; F11, F12 and F16 appear fixed (the notifications copy
is now about training, the gear has a tooltip and points at `A02`, and
`saturday`/`sunday` keys exist). Establish the current state of each of the rest,
one line per finding, with `path:line`:
F7 (My cycle lives behind an unlabelled 32pt circle), F8 (the only door to
Progress is an unmarked paragraph), F13 (text-button height, and see R2-42 for why
the original read was superseded by `AppButton`'s 44 floor), F14 (delete my data
is not in the privacy centre), F15 (the first-week screen counts three and says
five), F17 (`T08` is in neither `firstRunStates` nor the builder map, confirmed
still open), F18 (the bottom bar clamps text scaling at 1.35), F19 (copy that
talks about the design), F20 (coined vocabulary: "tier", "counted weeks", "first
steps", and whether "tier" has an Arabic equivalent that carries the meaning).
*Passing:* every one is marked fixed, still open, or superseded, with evidence.
*Severity:* per finding, re-sized against §2 rather than inherited from the
original review's own labels.

---

## 7. Rules that hold across both rounds

* **No shared setup.** Round one boots the app; round two does not. Round two
  writes no test that round one must run, and round one produces no artefact
  round two reads.
* **Neither round reads the other's report** before filing its own.
* **Neither round fixes anything.** If a validator cannot resist, the fix belongs
  in the report as a diff, not in the tree.
* **New tests go under `app/test/qa/round1/` or `app/test/qa/round2/`.** No
  existing test file is modified by either round, so the fixing agent can tell
  what was found from what was already guarded.
* **A case that cannot be run is `BLOCKED` with the reason, never silently
  dropped and never reported as a pass.**
* **The same defect found by both rounds is not duplicated work.** It is a defect
  visible by two independent methods, which makes it more urgent, not less.

---

## 8. What this plan deliberately does not cover, and why

1. **Everything on `docs/release/OWN-HUB-BEFORE-PROD.xlsx`.** The owner already
   knows. Re-planning it would bury the new information in a list he has read.
2. **The verification pilot and the eleven adversarial tests.** They need real
   women, real cards and a provisioned App Check token. No amount of testing here
   substitutes for a confusion matrix, and pretending otherwise is the theatre
   this plan was told to avoid.
3. **Thresholds, false-accept and false-reject rates.** `DECISIONS_NEEDED.md` D5
   is explicit that all four live thresholds are derived from published
   benchmarks and not measured. A validator cannot measure them either.
4. **Reviewer capacity and the flag rate.** `RESIDUAL_RISKS.md` §7 is a staffing
   decision with a 3x-wide modelled range; only the pilot narrows it.
5. **The back end's own correctness beyond its contract with the client.**
   `AUDIT.md` covers `functions/` and `firebase/` in detail and 360 tests run
   against it. This plan checks where the contract touches the app, not the
   pipeline's internals.
6. **Performance, memory and battery.** The iOS route is closed and a widget test
   measures none of them. `MANUAL_QA.md` row 1 (the 2 to 3 GB Android OOM) stays
   where it is.
7. **Real-network behaviour**: offline queueing, conflict between two devices,
   Firestore latency. Not observable from here.
8. **Content authoring.** Cooking and signing the 39 recipes, authoring the foods
   table with verified macros, and growing the programmes catalogue from one to
   twelve are on the "People, not code" sheet. This plan checks that the app
   behaves correctly **while** that content is missing, which is a different and
   testable question.
9. **Copy-editing for tone.** The em dashes are gone and the machine tells were
   swept. This plan checks whether a sentence is **true**, not whether it is
   well-phrased.
10. **The dark flows' internal correctness.** Community, coaching, the
    marketplace, payments and the assistant are off. Both rounds check that they
    are unreachable and that nothing on a shipping screen mentions them. Whether
    the community feed paginates correctly is the QA plan for the release that
    switches it on.
11. **Anything that would require changing the product to observe.** If a case
    can only be run by editing `lib/`, it is out of scope; report the
    unobservability instead.
12. **Building CI.** There is none: no `.github/workflows`, no Makefile, no
    script that runs the app suite, the rules suite and the back-end suite
    together. That is a real gap and it is infrastructure work, not validation.
    Both rounds note it; neither builds it.
13. **Establishing a golden-image baseline.** There are no goldens and no visual
    regression of any kind. Creating one is a project, and a baseline captured
    from a build nobody has validated would freeze whatever is currently wrong.
    Round one measures layout numerically instead.

---

## 9. What the fixing agent gets

Two reports, each with a verdict, a summary table and findings that carry a
location, an exact observation, a `path:line`, a repro command and an artefact.
Plus two directories of new failing tests, one per round, which are the
regression suite for everything found.

The fixing agent's order of work is severity first, then whichever defects both
rounds found independently, then the rest. Nothing in either report is a
suggestion to be weighed; an S1 is a thing that happens to a woman.
