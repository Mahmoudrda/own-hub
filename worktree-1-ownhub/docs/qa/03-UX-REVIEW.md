# Own Hub, first-time user review

> **Status, 24 September 2026.** Every blocker and every major finding in this
> report has been implemented and is on branch `worktree-release-readiness`
> (commit "Make the first sixty seconds hers"). The app is at 3,750 passing
> tests with a clean analyzer. What was done, against this report's own list:
>
> 1. **The first screen is hers.** The repository is born on day one dated
>    today; `T06` renders in the product for the first time; `T07` has a door
>    from ordinary Home; Progress no longer says "All five done" to a woman
>    with nothing done.
> 2. **She is asked.** `O01` to `O05` run on first launch over Home, skippable,
>    persisted, and her days a week becomes her weekly target through
>    `WeeklyGoalService.setTarget`, which had no call site before. 394ms to the
>    first question, 5.5 seconds of app time for the whole walk. A "Your
>    training" row in Profile keeps it editable.
> 3. **Nothing invented.** The three coaches who do not exist, the 12 kg on a
>    no-equipment session, "Last Tuesday", the two borrowed programme names,
>    R01's "Mon ✓" tick and its two ticked circles, and the programme preview
>    over an empty media block on the last screen of setup are all gone.
> 4. **The hidden doors are visible.** Chevron on Home's week block, avatar
>    raised from 32 to 44, a title on `A02`, Saturday and Sunday spelled out.
> 5. **The dead tab is fixed** on all eighteen shipping screens that claimed a
>    tab they were not, with a guard test over the shipping flows.
>
> Two corrections to this report, both verified on a device rather than argued:
> `AppButton` already floors the **tap target** at 44 points, so the 40 measured
> here was the painted block and those items are visual polish rather than
> accessibility failures; and `Icons.chevron_right` already mirrors under RTL,
> so Arabic never showed a backwards chevron. An `AppChevron` helper was added
> anyway, because that correctness depended on a flag in a Material constant
> that nothing in this repository asserted.
>
> Found by driving the app rather than reading it, and also fixed: a rest timer
> that pushed the mid-set screen over whatever she was doing up to 38 seconds
> after she left it; two undo bars at once after logging a meal; and
> symptom-only cycle mode never offering the gentler option, because the only
> screen that asks for that consent is on the dates path.
>
> Still open, and it is a product decision: setup offers 2, 3, 4 or 5 days a
> week while the rewards domain caps a weekly goal at 4. A woman who picks five
> is clamped to four, in the open, with the conflict documented at the call
> site.


Date: 2026-09-24 · Reviewer: staff product design · Build: `.claude/worktrees/release-readiness/app`,
`FeatureFlags.shipped` (`lib/routing/app_router.dart:3627`)

What was measured: the navigation graph recovered from `AppRouter._built` and walked breadth first
under the shipped flags; the app built for the iOS simulator, installed fresh, and photographed;
the semantics tree of fourteen screens dumped with labels and tap-target sizes; the existing tap
crawler re-run (1,063 rows).

---

## 1. Verdict

The app is built, it is fast, it is honest about what it cannot do, and the Arabic build is real
(right to left, Modern Standard Arabic, Western digits, opened automatically because the handset is
Arabic). None of that is in question.

It fails the owner's bar for one reason: **on a fresh install the first screen is not hers.** Home
opens on the prototype's Tuesday, with a 32 minute walk she never took, a programme called "Legs and
glutes" in "Week 3 of 8", "This week, 1 of 3" with the first session already ticked, and a breakfast
of ful and baladi logged at 8:40 AM. One tap away, Eat says "Day 1, no plates yet" and Progress says
"This week, 0 of 3". She is being shown another woman's week, and the app immediately contradicts
itself about it.

The second failure follows from the first: **the onboarding that would make the week hers is
unreachable in this build** (`O01` to `O05` have exactly one inbound route, from `C16`, which lives
in the switched-off sign-up flow), and **the day-one Home and the first-week tour are unreachable
too**, because the seed tells the app she has already logged something. So the product's own answer
to "how does she learn her way around" never renders.

Fix the seed first. Everything else on this list is smaller than that one line.

---

## 2. Tap-depth measurement

### Method

`AppRouter._built` is the only place the navigation graph exists, as `goTo(context, 'XX')` literals
inside each route builder. The graph was parsed from that map, filtered to screens whose flow is on
under `FeatureFlags.shipped`, and walked breadth first from the three shipped tab roots (`T01`,
`R01`, `E01`; `M01` is dark, so the bar is three tabs).

Two corrections were then applied that a naive parse gets wrong, both verified on the running app
and in the semantics dump:

* `T01 > Y03` is drawn only `if (_day.showCycleCard)` (`lib/features/today/presentation/today_view.dart:314`),
  which is false for a new user. My cycle is **not** one tap from Home.
* `T01 > T07` is drawn only in the day-one branch (`today_view.dart:498`), which never renders while
  the repository is seeded. The first-week tour is **not** one tap from Home.
* `Y03` in its not-set-up state offers only two doors, the setup button and the settings gear.

### Distribution (53 built screens that are on in the shipped build)

| Taps from a tab root | Screens |
|---|---|
| 0 (tab roots) | 3 |
| 1 | 13 |
| 2 | 15 |
| 3 | 6 |
| 4 | 2 |
| 5 (after cycle setup) | 5 |
| 6 (after cycle setup) | 3 |
| Unreachable in this build | 6 |

Within two taps: 31 of 47 reachable screens (66 per cent). `test/nav_reachability_test.dart` reports
71.9 per cent, but it measures with every feature on and counts the coach and admin tab bars as
roots, so it is not the shipped number.

### Every screen, by depth

| Depth | Screens |
|---|---|
| 0 | T01 Today · R01 Train · E01 Eat |
| 1 | A01 Notifications · A02 Profile · E02 Type it · E03 Say it · E04 After a log · E05 Recipes · P01 Your progress · R02 Program · R03 Workout day · R05 Swap a move · R06 Follow-along · R11 Workout library · T02 I already did it |
| 2 | A03 Privacy · A04 Safety Centre · C02 Language · E06 Recipe · E07 Week plan · P02 Milestones · P03 Personal bests · P04 Body privately · R04 Exercise video · R07 Mid-set · R12 Logged from memory · T04 After a quiet week · T05 When a tier slips · T07 Your first week · Y03 My cycle |
| 3 | E08 Grocery list · R08 Change a set · R09 Resting · R13 Move logged · Y01 Set up My cycle · Y12 Cycle settings |
| 4 | R10 Finished · Y02 Dates and preferences |
| 5 | Y04 How are you feeling · Y06 Choose what feels right · Y07 Meals for today · Y08 Calendar · Y10 Your patterns |
| 6 | Y05 Why this suggestion · Y09 Log a period · Y13 About cycle phases |
| Unreachable | O01 · O02 · O03 · O04 · O05 · T03 |

### Over budget

A two-tap budget from a tab root is the project's own target (`P0-NAV-01`).

| Screen | Depth | Why |
|---|---|---|
| R08, R09, R13 | 3 | In-session steps. Correct: a session is a sequence. Not a finding. |
| R10 Finished | 4 | Same. Not a finding. |
| E08 Grocery list | 3 | Recipes, then week plan, then list. Acceptable. |
| **Y01 Set up My cycle** | **3** | Home, avatar, My cycle, Track periods. Behind an unlabelled 32 pixel picture. Finding F7. |
| **Y12 Cycle settings** | **3** | Same door. |
| **Y02 Dates** | **4** | Second step of a setup that is already three taps deep. |
| **Y04, Y06, Y07, Y08, Y10** | **5** | The whole usable half of My cycle sits five taps from Home for a woman who has not set it up. |
| **Y05, Y09, Y13** | **6** | Logging a period is six taps from Home on day one. |
| **O01 to O05** | **unreachable** | Finding F2. |

`T03` is a lock-screen notification landing screen and is correctly entered from outside the app.

---

## 3. Journey traces

Each trace is what a first-time user on a fresh install actually does, walked in the built app.

### J1. The first sixty seconds

```
install > open
  main.dart:145 _initialRoute()
  Feature.accountRequired is false
  so initialRoute = appRoutes['T01'] = /today/t01
> T01 Today
```

**0 taps to Home. No language chooser, no welcome, no onboarding, no permission prompt.**

What she sees, in order, top to bottom (screenshot `/tmp/ownhub/01-firstlaunch.png`):

1. "Tuesday", a "Level 1" pill, a bell, a small pink circle with a person icon.
2. "Walk this morning · 32 min" with "Count it".
3. "Legs and glutes", set as the page title, underlined by hand.
4. "Week 3 of 8" circled in ink.
5. "This week, 1 of 3 · Two more and the week counts", with the first of three rings ticked.
6. A hand-drawn arrow and the word "Up next" pointing at "Start, everything's ready".
7. "I already did it".
8. "Breakfast, your usual · 8:40 AM", "Ful and baladi 410 kcal", "Eggs and tea 290 kcal".
9. Three tabs: Home, Train, Eat.

Items 1 to 8 are all untrue of her. **Fail.** See F1.

### J2. Tell the app how often she can train

```
There is no route. O03 "Days and minutes" is unreachable (F2),
and A02 has no row that opens the intake.
```

**Impossible. Fail.** The weekly target is fixed at 3 in
`lib/features/today/domain/today_repository.dart:95` and no screen in the shipped build calls
`WeeklyGoalService.setTarget`.

### J3. Do today's workout

```
T01 > (Start, everything's ready) R03 > (Start, everything's ready) R07
   > (Done · 12 kg × 10) R09 > (Done) R10
```

**1 tap to the session, 2 to the first set.** Meets the budget. The session itself is coherent:
move by move, set by set, five seconds of undo per set, no confirm dialog anywhere. The content is
the problem, not the flow (F5).

### J4. Log what she ate

```
T01 > (Ful and baladi) E04     = 1 tap, logs it, five second undo
or  T01 > (Eat tab) E01 > (Log on Koshari bowl) E04   = 2 taps
or  T01 > (Say or type what you ate) E02 > type > Log  = 2 taps plus typing
```

**1 tap. Meets the budget.** Rule 9 holds: one tap, a five second undo bar, no confirmation. This is
the best-executed journey in the app.

### J5. See her progress

```
T01 > (tap the words "This week, 1 of 3") P01     = 1 tap
```

Meets the budget numerically and fails in practice: the tap target is a 358 by 159 point block of
body text with no chevron, no card, no button and no underline. See F8.

### J6. Set up My cycle

```
T01 > (unlabelled 32pt avatar) A02 > (My cycle) Y03 > (Track periods and symptoms) Y01
    > (Continue) Y02 > (Save) Y03
```

**3 taps to the setup screen, 5 to a working My cycle.** Budget is 2. **Fail**, and the first tap is
an unlabelled picture. See F7.

### J7. Reach the privacy centre

```
T01 > (avatar) A02 > (Privacy) A03      = 2 taps
also T01 > (bell) A01 > (gear) A03      = 2 taps
```

Meets the budget. What she finds there is one row (F14).

### J8. Delete everything

```
T01 > (avatar) A02 > (Your data) sheet > (Delete)   = 3 taps
```

Correct. Deletion confirms in a sheet, which is the documented exemption from rule 9, and the sheet
says plainly that there is nothing on a server to download. Good.

### J9. Find her first week, the tour the product wrote for her

```
T01 has no row for it (the row lives in the day-one branch, which never renders)
T01 > (the unmarked week block) P01 > (Your first week) T07   = 2 taps
```

Reachable only by accident, and P01 labels it **"All five done"** before she has done anything. See
F3 and F6.

---

## 4. Capability coverage

| Capability the release promises | Status | Evidence |
|---|---|---|
| Home / Today | Present | `T01`, `today_view.dart` |
| Today, day one (`T06`) | **Absent in practice** | It is a branch of `T01` taken when `arc.hasAnyLog` is false (`today_view.dart:210`); the seeded repository sets `hasAnyLog: true` (`today_repository.dart:91`), so it can never render on a real first run |
| Train, a session end to end | Present | `R01 > R03 > R07 > R09 > R10` |
| Choosing or changing a programme | **Partial** | `R02 > R11` exists, but every row in `R11` opens the same `R03` (`app_router.dart:886`), and the library holds three entries with invented coach names |
| Eat, log by plate, type or voice | Present | `E01`, `E02`, `E03`, one-tap log with undo |
| Eat, day one (`E09`) | Present | Renders correctly on a fresh install, "Day 1 · No plates yet" |
| Recipes, week plan, grocery list | Present | `E05`, `E07`, `E08` |
| My cycle | Present but deep | Setup at 3 taps, hub at 5; correct symptom-only mode |
| Progress, milestones, personal bests, body | Present | `P01` to `P04`, honest empty states |
| The first-week arc (`T07`) | **Partial** | The screen is built and correct, but its only Home entry point is in a branch that cannot render, and `P01`'s row states "All five done" unconditionally |
| First week done (`T08`) | Partial | Built as a branch of `T07` (`first_week_view.dart:335`) but missing from `firstRunStates` (`app_router.dart:281`), so `/today/t08` resolves to the "not built yet" panel |
| Privacy centre | **Partial** | `A03` ships one row under the shipped flags; everything else in it is community-gated. Scope consequence |
| Safety Centre | **Partial** | `A04` renders a title bar and nothing else: every row is community or coach gated, and `LegalLinks.support` is empty. Scope consequence |
| Account deletion and data export | Present | `A02 > Your data`, honest about there being no server |
| Language switching | Present | `A02 > Language` (`C02` is explicitly un-gated for this reason) |
| Notifications | Partial | `A01` renders, but with no authored copy for any event kind it is permanently an empty state, and the permission row carries sign-up copy |
| Allergies and dietary profile | Present | `A02`, reaches Eat |
| **Setting her goal, days per week, session length, equipment, life stage** | **Absent** | `O01` to `O05` unreachable (F2); `A02` has no intake row; nothing calls `WeeklyGoalService.setTarget` |
| Onboarding inside one minute | **Absent** | There is no onboarding in the shipped build at all |

---

## 5. Findings

Ranked by what they cost a first-time, non-technical user. "Scope consequence" means the problem
exists because a feature is switched off; everything else is a design or wiring fault in what ships.

---

### F1. BLOCKER. Home opens on another woman's week

**What she experiences.** She installs the app, opens it, and the first screen tells her it is
Tuesday (the phone says Thursday), that she walked 32 minutes this morning, that she is in week 3 of
8 of a programme called "Legs and glutes", that she has done 1 of her 3 sessions this week, and that
she ate ful and baladi and eggs and tea for breakfast at 8:40. She did none of it. If she taps Eat
she is told "Day 1, no plates yet". If she taps the week she is told "This week, 0 of 3".

**Evidence.**
* `lib/routing/app_router.dart:3637` `static final InMemoryTodayRepository todayRepository = InMemoryTodayRepository();`
  with no argument, so the day is `defaultDay()`.
* `lib/features/today/domain/today_repository.dart:86` to `:105`: `date: DateTime(2026, 9, 15, 9, 41)`,
  `state: DayState.nothingDone`, `arc: FirstWeekArc(hasAnyLog: true, completed: {logSet, logMeal})`,
  `week: WeekProgress(sessionsLogged: 1, sessionsTarget: 3)`, `walkToCount: true`, `walkMinutes: 32`,
  `mealLoggedAt: 08:40`, two plates, `programWeek: 3`, `programTotalWeeks: 8`.
* `lib/features/today/domain/today_repository.dart:109` `static TodayDay dayOne(...)` exists, is
  correct, and is called by nobody outside tests.
* Screenshot: `/tmp/ownhub/01-firstlaunch.png` (English), `/tmp/ownhub/22-ar-home.png` (Arabic, same
  lie).

**Why it matters.** This is the first screen of a product whose entire positioning is that the
numbers on it are hers. A woman who has never used a fitness app has no way to know these are
samples; she will read them as the app having got her wrong, or as the app being for somebody else.
It also breaks the app's internal consistency in a single tap, which is how trust goes. Every one of
the careful "withhold the figure rather than state it" mechanisms elsewhere in this codebase is
defeated by this one constructor call.

**Fix.** One line: `InMemoryTodayRepository(day: InMemoryTodayRepository.dayOne(date: DateTime.now()))`,
and change `dayOne`'s default date from the frozen `DateTime(2026, 9, 15, 9, 41)` to `DateTime.now()`.
Also change `defaultDay`'s date to `DateTime.now()` so the demo day is at least today. Then add a
guard test that asserts a freshly constructed `AppRouter.todayRepository.day.state == DayState.dayOne`
and `arc.hasAnyLog == false`, so the seed cannot come back. Design fault, not scope consequence.

---

### F2. BLOCKER. The setup questions are unreachable, and nothing replaces them

**What she experiences.** She is never asked how many days a week she can train, how long she has,
what equipment she owns, what she is training for, or whether she is pregnant, postpartum or
perimenopausal. The app decides for her: three sessions a week, and a single hard-coded workout
containing a 12 kg goblet squat.

**Evidence.**
* `lib/routing/app_router.dart:626` is the only `goTo(context, 'O01')` in the codebase. It is inside
  `'C16'` (the community pledge), whose flow is `signup`, gated by `Feature.signUp`, which is
  `false` in `FeatureFlags.shipped` (`lib/domain/flags/feature_flags.dart`).
* Breadth-first search from all three shipped tab roots reaches 47 screens; `O01` to `O05` are not
  among them.
* `lib/features/account/presentation/profile_view.dart` renders no row that opens the intake. `A02`
  offers My cycle, allergies, language, notifications, privacy, safety, data.
* `grep -rn "intakeRepository" lib/` shows the only readers are the five `O` screens, the snapshot
  and account deletion. Nothing in Today, Train or Eat reads `Intake`.
* `WeeklyGoalService.setTarget` has no call site under `lib/features/` or `lib/routing/`.

**Why it matters.** `DECISIONS.md` D3 says every answer is collected early and stays editable
forever. In this build neither half is true. The audience is women of every age, many postpartum or
perimenopausal, training at home with nothing; the app asks none of that and then prescribes a
weighted squat. It is also the single biggest reason the first minute feels like somebody else's
app: nothing on Home can be hers because she was never asked anything.

**Fix, in order of size.**
1. Smallest: give `A02` a "Your training" row that opens `O01`, and let `O05` return to `A02`
   instead of starting a session. Cost: one row, one callback. This also satisfies D3's "editable
   forever" half for the first time.
2. Correct: run `O01` to `O05` once on first launch. `main.dart:145` already chooses the initial
   route; add a persisted `hasCompletedIntake` flag to `LocalPersistence` and send a first-run user
   to `/onboarding/o01`, with `O05` landing on `T01`. Four questions with every option preselected
   and a Skip on each is well inside the owner's one minute, and it is what makes Home hers.
3. Then make the answers do something: derive `WeekProgress.sessionsTarget` from `Intake.days` and
   filter `sampleWorkoutDay`'s moves by `Intake.equipment`.

Partly a scope consequence (the door was in the sign-up flow), but the absence of any replacement
door is a design fault.

---

### F3. BLOCKER. The day-one screen and the first-week tour cannot render

**What she experiences.** The product's own answer to "how does she discover the app on her own" is
`T06` (day-one Home) with its "Your first week" row leading to `T07`, the three-step tour. She never
sees either. `T06` is a branch of `T01` taken when nothing has been logged; the seed says two things
have been logged. And the `T07` row exists only on that branch, so even after the seed is fixed the
tour vanishes permanently at her first log.

**Evidence.**
* `lib/features/today/presentation/today_view.dart:210` `children: _day.isDayOne ? _dayOne(...) : _today(...)`.
* `today_view.dart:498` `onTap: () => openScreen(context, 'T07', widget.onOpenFirstWeek)` sits inside
  `_dayOne` only. `_today` (lines 219 to 329) has no first-week row.
* `today_repository.dart:91` `arc: FirstWeekArc(hasAnyLog: true, ...)`.
* Screenshot `/tmp/ownhub/01-firstlaunch.png`: no "Your first week" row.
* Semantics dump of `T01` under shipped flags: eleven tappable nodes, none of them `T07`.

**Why it matters.** The owner's bar is that she discovers every workflow unaided. `T07` is the
artefact that was designed to do that, and in the shipped build it is reachable only by tapping an
unmarked paragraph on Home to reach Progress and then spotting a row that wrongly says "All five
done".

**Fix.** Fix F1 first, which makes `T06` render. Then move the "Your first week" row out of the
`_dayOne` branch into `_today`, drawn while `!firstWeekIsComplete(_day.arc)`. It is already counted
correctly against the steps this build offers (`firstWeekDone` and `offeredFirstWeekSteps` in
`today_cards.dart:70` to `:83`), so it will read "0 of 3", then "1 of 3", then disappear. Design
fault.

---

### F4. MAJOR. Home and Train name two different programmes, neither of them hers

**What she experiences.** Home says her session is "Legs and glutes". She taps Train and it says her
programme is "Postpartum rebuild", with a "Mon ✓" chip claiming she trained on Monday. She has never
been pregnant, or she has, and either way nobody asked.

**Evidence.**
* `lib/features/today/presentation/today_cards.dart:300` `child: Text(l10n.legsAndGlutes, style: EditorialType.cover)`.
  The cover title is a dictionary constant, not data: `WorkoutCard` takes `week`, `totalWeeks`,
  `summary` and `weekBlock`, and no title.
* `lib/features/train/presentation/train_view.dart:171` `programTitle ?? l10n.postpartumRebuild`, and
  `lib/features/train/presentation/program_view.dart:119` `title ?? l10n.postpartumRebuild`. The
  `'R01'` builder (`app_router.dart:757`) passes no `programTitle`, so the fallback is what every
  woman sees.
* `train_view.dart:208` to `:213`: three fixed chips, `AppChip(l10n.mon_4jow1, selected: true)`,
  `AppChip(l10n.today, onTap: onOpenToday)`, `AppChip(l10n.thu)` with no action.
* Screenshots `/tmp/ownhub/01-firstlaunch.png` and `/tmp/ownhub/02-R01.png`.

**Why it matters.** "Postpartum rebuild" is not a neutral placeholder in a women's fitness app in
Egypt. Shown to a nineteen year old it is absurd; shown to a woman who lost a pregnancy it is cruel.
And two names for one programme, one tap apart, tells her the app does not know what she is doing.

**Fix.** Give `WorkoutCard` a `title` parameter and pass `trainRepository.today()?.title`, rendering
nothing when the plan has not said, exactly as the week badge already does
(`today_cards.dart:230` to `:235` documents that pattern). Do the same in `train_view.dart:171` and
`program_view.dart:119`: no programme name until there is one. Replace the three fixed day chips
with the days the plan actually holds, or draw no chips. Design fault.

---

### F5. MAJOR. The first set she is ever asked to do cites a workout she never did, and needs equipment the same screen says she does not need

**What she experiences.** She taps "Start, everything's ready". `R03` says "15 minutes, 5 moves ·
Quiet · no equipment · floor" and then lists "Goblet squat 3 × 10 · 12 kg suggested". She taps Start
and `R07` says, in the sage-coloured note: "Last Tuesday: 10 kg × 10, every set finished. So we
added 2 kg."

**Evidence.**
* `lib/features/train/presentation/workout_day_view.dart:43` `sampleWorkoutDay` is the only workout
  in the build. Line 47 `constraints: l10n.quietNoEquipmentFloor`; lines 61 to 90 the goblet squat
  with `needsEquipment: true` and three `PrescribedSet(weightKg: 12, reps: 10)`.
* `lib/features/train/presentation/mid_set_view.dart:362` to `:372`. The note is guarded by
  `statesHerFigure(states: const (12, 10), hers: (prescribed?.weightKg, prescribed?.reps))`, which is
  a good guard; it fails here only because the seeded prescription is literally 12 kg by 10, so every
  woman is that woman.
* Screenshots `/tmp/ownhub/10-R03.png`, `/tmp/ownhub/14b-R07.png`.

**Why it matters.** This is the moment of highest trust and highest risk: she is about to lift. The
app asserts a training history she does not have, uses it to justify a load, and contradicts its own
"no equipment" promise two lines above. A beginner with no dumbbell has no idea what to do next; a
beginner with a 12 kg dumbbell may try it.

**Fix.** Two separate changes.
1. `sampleWorkoutDay` must not carry a load for a woman with no history. Give the goblet squat
   `weightKg: null` and a prescription label that says "as heavy as feels easy for 10" until a
   previous set exists, or drop the move from the first session and keep the four bodyweight moves,
   which then matches "no equipment".
2. The `statesHerFigure` guard should compare against a real previous set rather than the literal
   `(12, 10)`. Draw the note only when `trainRepository` holds a logged set for that exercise, and
   parameterise the string as "{was} by {reps} last time, so we added {step}". Design fault (the
   seed), with a content gap behind it.

---

### F6. MAJOR. Progress tells a woman with nothing that her first week is finished

**What she experiences.** `P01` is otherwise scrupulously honest: "Counted weeks 0 of 4", "This week,
0 of 3", "Milestones 0 of 8", "Nothing saved yet" on bests. In the middle of that, the row "Your
first week" carries the subtitle **"All five done"**.

**Evidence.** `lib/features/progress/presentation/progress_view.dart:135` `subtitle: l10n.allFiveDone`,
a constant with no data behind it. Screenshot `/tmp/ownhub/04-P01.png`. The arc offers three steps in
this build, not five, because two belong to Community (`today_cards.dart:70`).

**Why it matters.** It is the one false line on an otherwise truthful screen, and it sits on the only
route to `T07` that exists (see F3), so it actively discourages the tap that would teach her the app.

**Fix.** Replace with the same counted subtitle Home's day-one branch already uses:
`l10n.countOfTotal(countLabel(firstWeekDone(arc)), countLabel(offeredFirstWeekSteps().length))`.
`ProgressView` will need the arc passed in from the `'P01'` builder (`app_router.dart:1043`), which
already has `todayRepository` in scope. Design fault.

---

### F7. MAJOR. Half the product lives behind an unlabelled 32 point circle

**What she experiences.** My cycle, Language, Notifications settings, Privacy, the Safety Centre,
Allergies and "delete everything" are reached only through a small pink circle containing a generic
person glyph, in the top corner of Home, with no text beside it. Tapping it lands her on a screen
with **no title at all**: just a back arrow, an illustration, a picture of a person, and a list.

**Evidence.**
* `lib/features/today/presentation/today_view.dart:252` `AppAvatar(size: 32, ...)`. Measured in the
  semantics tree: **32 by 32 points**, against 44 by 44 (iOS HIG) and 48 by 48 (Material). Every
  other control in the masthead measures 48 by 48.
* `lib/ui/app_avatar.dart` gives it `Semantics(label: l10n.yourProfile)`, so VoiceOver is fine; the
  problem is sighted, non-technical discovery, and the tap size.
* `lib/features/account/presentation/profile_view.dart:161` `appBar: AppTopBar(onBack: widget.onBack)`,
  no `title`. Screenshot `/tmp/ownhub/06-A02.png` confirms an untitled page.
* Journey J6: My cycle setup is three taps, all of them through this control.

**Why it matters.** The audience is defined as women who have never used a fitness app. A picture of
a person in a corner is a learned convention, not an obvious one, and at 32 points it is also the
hardest thing on the screen to hit. Two of the six shipped features (My cycle, the privacy centre)
have no other door.

**Fix.**
1. `AppAvatar(size: 44)` on `T01` and wherever else it is a control, or wrap it in a 44 point
   `SizedBox` with the picture centred.
2. Give `A02` its title: `AppTopBar(title: l10n.profileAndSettings, onBack: ...)`. The route table
   already calls it "Profile and settings" (`app_routes.dart`).
3. Put a labelled row on Home for My cycle rather than relying on `showCycleCard`, which is false
   until setup and therefore hides the feature from exactly the women who have not found it. A row
   reading "My cycle · set it up" costs nothing to a woman who skips it, and P0-CYC-03's "skipping
   costs nothing" is satisfied by it disappearing once she declines, not by never appearing.

Design fault.

---

### F8. MAJOR. The only door to Progress is an unmarked paragraph

**What she experiences.** To reach Progress, personal bests, milestones, body measurements, the rest
week explainer and (per F3) the first-week tour, she must tap the words "This week, 1 of 3 / Two more
and the week counts" in the middle of Home. Nothing about that block says it is tappable: no chevron,
no card, no underline, no button.

**Evidence.**
* `lib/features/today/presentation/today_view.dart:270` to `:291`,
  `WeekCard(open: true, ..., onTap: () => openScreen(context, 'P01', widget.onOpenWeek))`.
* `lib/features/today/presentation/today_cards.dart:552` to `:553`: when `open` is true the block is
  wrapped in `HandPressable`, which is an `InkWell` with `NoSplash.splashFactory` and no chevron, no
  border and no role beyond "tappable".
* Semantics dump of `T01`: a 358 by 159 point tap target labelled "This week, 1 of 3 Two more and the
  week counts."
* Screenshot `/tmp/ownhub/01-firstlaunch.png`.

**Why it matters.** Six built screens (`P01` to `P04`, `T04`, `T05`) plus `T07` hang off this one
invisible affordance. A woman who never guesses it has a three-screen app.

**Fix.** Add a chevron at the end of the "Two more and the week counts" line, or add a short text
action under the rings ("See your progress") using the same underlined text-button treatment the rest
of the app uses for secondary actions. Both are one widget. Design fault.

---

### F9. MAJOR. The workout library invents three coaches and then ignores what she picks

**What she experiences.** Train, then the magnifier, then "All workouts". Three rows: "Floor legs, no
jumping · 10 min · beginner · Nour", "Quiet full body · 15 min · beginner · Mariam", "Upper body at
home · 20 min · easy · Habiba". She taps "Upper body at home" and gets "Legs and glutes".

**Evidence.**
* `lib/features/train/presentation/workout_library_view.dart:89` to `:110`, with
  `lib/l10n/app_en.arb:244`, `:265`, `:290` and the matching Arabic at `app_ar.arb:244`, `:265`,
  `:290`.
* `lib/routing/app_router.dart:886` `'R11': ... onOpenWorkout: (_) => goTo(context, 'R03')`. The
  argument is discarded.

**Why it matters.** "No invented people" is one of the product's stated rules, and these are three
invented Egyptian women's names presented as instructors, in both languages, two taps from Home. The
discarded argument then breaks the one promise the screen makes.

**Fix.** Remove the three names from the detail strings ("10 min · beginner" is true and sufficient)
until a real library exists. Either make `onOpenWorkout` carry the id the way `E05`'s `onOpenRecipe`
already does (`app_router.dart:952`), or, while there is only one workout, replace the library's body
with the same honest empty state `P03` uses: the filters are there, the titles are not authored yet.

---

### F10. MAJOR. She cannot change how often she trains, and the app measures her against a number she never chose

**What she experiences.** Every screen counts her week against three sessions. Nothing anywhere lets
her change it, and the copy is unconditional: "Two more and the week counts", "Three sessions makes
the week count".

**Evidence.** `today_repository.dart:95` and `:115` both hard-code `sessionsTarget: 3`.
`WeeklyGoalService.setTarget` (`lib/domain/rewards/weekly_goal_service.dart:256`) is referenced only
in two comments under `lib/features/`. `O03` is the screen that would set it and it is unreachable
(F2).

**Why it matters.** The product's strongest emotional promise is weeks rather than days and never
shaming a missed day. A target she did not choose is the one way that promise can still shame her: a
woman who can train twice a week will end every week one short, for ever.

**Fix.** Comes free with F2, item 3: derive the target from `Intake.days`. Until then, add a "How
often" control on `P01` or `A02` that calls `setTarget`. Design fault with a scope cause.

---

### F11. MINOR. Notifications says "your check is done", which is sign-up language for a feature that is switched off

**What she experiences.** She taps the bell on Home (the second most prominent control on the app's
first screen) and reads "Turn on notifications so we can tell you when your check is done." There is
no check in this build. Below it, an empty state. The gear in the corner, which has no label and no
tooltip, opens Privacy, not notification settings.

**Evidence.**
* `lib/features/account/presentation/notifications_view.dart:137` `title: l10n.turnOnNotificationsSoWeCanTell`,
  whose English is "Turn on notifications so we can tell you when your check is done." (an ID
  verification string).
* `notifications_view.dart:120` to `:125`: `IconButton(onPressed: onOpenSettings, icon: Icon(Icons.settings))`
  with no `tooltip`. Measured 48 by 48, labelled `(UNLABELLED)` in the semantics dump.
* `lib/routing/app_router.dart:1087` `onOpenSettings: () => goTo(context, 'A03')`.
* The permission row is drawn as a list item with no chevron and no button styling, so it does not
  read as the action it is.
* Screenshot `/tmp/ownhub/08-A01.png`.

**Fix.** New string: "Turn notifications on, so we can remind you at the hour you usually train."
Give the gear `tooltip: l10n.settings` and point it at `A02` (which is what the file's own comment at
line 93 says the design intends), or remove it. Draw the permission row as an `AppButton`. Copy and
wiring fault; the empty inbox itself is a content gap already recorded in the previous QA report.

---

### F12. MINOR. Three icon-only controls have no accessible name

**What she experiences.** With VoiceOver on, three controls announce nothing: the search magnifier on
Train, the settings gear on Notifications, and the close control on Mid-set.

**Evidence.** Semantics dump under shipped flags: `R01` node 1 = `48x48 (UNLABELLED)` (navigates to
`R11`); `A01` node 2 = `48x48 (UNLABELLED)` (navigates to `A03`); `R07` node 1 = `48x48 (UNLABELLED)`.
The crawler log agrees (`/tmp/ownhub/crawl.tsv`, rows `R01 0`, `A01 1`, `R04 0`, `R09 0`, `R11 0`,
`R13 0`).

**Why it matters.** The previous QA round fixed back buttons; these survived because they are custom
icons rather than the standard back affordance. `R07`'s is the one that matters most: it is the
escape hatch from a live session.

**Fix.** Add `tooltip:` to each `IconButton`, or wrap in `Semantics(button: true, label: ...)`. The
dictionary already has `search`, `settings` and `close`.

---

### F13. MINOR. Text buttons are under the minimum tap size

**What she experiences.** "I already did it" on Home is 40 points tall. On a 68 year old's phone that
is a miss.

**Evidence.** `lib/features/today/presentation/today_cards.dart:281` `height: 40` for the non-evening
secondary action. The same `height: 40` appears in `change_set_view.dart:342`, `type_it_view.dart:322`,
`say_it_view.dart:308`, `check_in_view.dart:162`, `body_privately_view.dart:432` and
`gentler_option_view.dart:136` and `:146`; `cycle_settings_view.dart:295` is 36 and
`cycle_hub_view.dart:472` is 30.

**Fix.** Raise `AppButtonVariant.text` to a 44 point minimum height in `lib/ui/app_button.dart` rather
than per screen; the underline treatment does not need to grow with it.

---

### F14. MINOR. The privacy centre is one row, and "delete my data" is not in it

**What she experiences.** She taps Privacy expecting to find what the app knows about her and how to
delete it. She gets a sage banner ("Your logs, weight and photos stay on this phone") and a single
row, "Cycle information". Deletion lives one screen back, under "Your data".

**Evidence.** Screenshot `/tmp/ownhub/07-A03.png`. Semantics dump of `A03` under shipped flags: one
content row. `lib/features/account/presentation/privacy_view.dart` gates the profile visibility, the
bests visibility, blur and coach sharing rows behind community and coaching.

**Why it matters.** Mostly a scope consequence: four of the five rows belong to features that are off.
But the placement of deletion is a design choice, and Privacy is where a non-technical woman looks
for it.

**Fix.** Add a "Your data" row to `A03` that opens the same sheet `A02` opens. One line, one shared
callback. The banner is good and should stay.

---

### F15. MINOR. The first-week screen counts three steps and then talks about five

**What she experiences.** `T07` shows a ring reading "2 of 3", a heading "2 done, 1 waiting", three
rows, and then a note: "Finishing all five is not a deadline."

**Evidence.** `lib/features/today/presentation/first_week_view.dart:319`
`AppSageNote(l10n.finishingAllFiveIsNotADeadline)`, `lib/l10n/app_en.arb:1779`. The count above it is
computed from `offeredFirstWeekSteps()`, which returns three while Community is dark. Screenshot
`/tmp/ownhub/09-T07.png`.

**Fix.** Parameterise: "Finishing all {n} is not a deadline." Scope consequence made visible by an
unparameterised string.

---

### F16. MINOR. Saturday and Sunday are abbreviated on Home while the other five days are spelled out

**What she experiences.** On five days Home says "Tuesday". On the other two it says "Sat" and "Sun".

**Evidence.** `lib/features/today/presentation/today_cards.dart:100` to `:115`; the comment names the
gap. `app_en.arb` has no `saturday` or `sunday` key.

**Fix.** Add the two dictionary entries in both languages. Twelve words of translation.

---

### F17. NOTE. `/today/t08` resolves to the "not built yet" panel

`T08` is a branch of `T07` (`first_week_view.dart:335`) but, unlike `T06`, `E09`, `M17`, `Y11` and
`Y14`, it is missing from `firstRunStates` (`app_router.dart:281`). So it stays in `appDestinations`,
resolves, finds no builder and renders `NotBuiltYet`. Only reachable by deep link or a notification
payload, so it costs a user nothing today, but it breaks the rule the set exists to enforce. Add
`'T08'` to the set.

---

### F18. NOTE. The bottom bar stops growing at 1.35x text

`lib/ui/app_nav_bar.dart:166` `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.35)`. Defensible
(platform tab bars do the same) and the labels are still legible, but for a woman at the largest
accessibility sizes the three tab names stay noticeably smaller than everything else on the screen.
Worth a decision rather than a default: a two-line bar at extreme sizes would also work.

---

### F19. NOTE. Two pieces of copy talk about the design rather than to her

`lib/features/eat/presentation/eat_view.dart:593` "No countdown, no red numbers. Protein is the only
target, and it is a bar that fills." and `first_week_view.dart` "The same points the rest of the app
gives. Nothing extra for opening it." Both are the team reassuring itself. A first-time user does not
know there could have been a countdown. Not wrong, just not addressed to her.

---

### F20. NOTE. Vocabulary a non-technical woman will not recognise

"Tier" (`If a tier slips`, `app_en.arb:1672`), "Counted weeks" (`:515`) and "First steps" as a level
name (`:2111`) are coined terms. They are consistent and they are explained on `P01` itself, which is
why this is a note and not a finding. Worth watching in the first round of user testing: "tier" in
particular has no natural Arabic equivalent that carries the same meaning.

---

## 6. What is genuinely good

* **The Arabic build is not an afterthought.** Set the handset to Arabic and the app opens in Arabic,
  right to left, correctly mirrored, in Modern Standard Arabic addressed to a woman, with Western
  digits and the hand-drawn layer intact (`/tmp/ownhub/22-ar-home.png`). Very few products at this
  stage get that right.
* **Rule 9 holds everywhere it should.** One tap logs, a five second undo bar names what was written,
  and there is no confirmation dialog anywhere in a logging path. `showDialog` and `AlertDialog`
  appear nowhere under `lib/features/`, and the two documented exceptions (account deletion,
  blocking) confirm in a sheet, which is the right shape.
* **The empty states are the best writing in the product.** "No plates yet: log something twice and
  it becomes a one-tap plate here, in the size you actually serve, not in grams." "Nothing saved yet:
  measured against your own history only. A 3 kg dumbbell counts like a 30 kg barbell." Each one says
  what will appear and why it is empty. This is exactly what a first-time user needs, and it is why
  F1 is such a waste: the app already knows how to be honest about emptiness.
* **Eat is the journey to copy.** One tap to log from Home, one tap from the tab, an undo bar that
  closes on time, an honest day-one state, and a permission refusal that routes to the keyboard
  instead of a spinner.
* **My cycle, once reached, respects the woman using it.** Symptom-only mode, "you choose what to
  log", skipping costs nothing, and the not-set-up hub is a real screen rather than a blank.
* **Contrast is sound.** Body text 16.2:1, secondary text 6.0:1, primary 4.6:1, sage 5.1:1 against the
  surface. The tokens below 4.5 (`outline` at 3.3:1) are used for pencil rules and field lines only,
  where 3:1 is the bar. The active tab is marked four ways, not by colour alone.
* **The codebase argues with itself in the right direction.** Nearly every defect in this report has a
  comment three lines away explaining why the same class of defect was fixed somewhere else. The
  discipline is real; F1 is the one place it was not applied to the object that feeds every screen.

---

## 7. The five changes that would most improve the first sixty seconds

In the order I would do them.

1. **Seed the repository with day one, not with the prototype's Tuesday.** `app_router.dart:3637`
   plus a `DateTime.now()` default in `today_repository.dart:109`. One line and one date. It removes
   the walk she never took, the week 3 of 8, the 1 of 3 and the 8:40 breakfast, and it makes `T06`
   render for the first time. Add the guard test so it cannot return. (F1, and it unlocks F3.)

2. **Give her the four questions.** Run `O01` to `O05` on first launch behind a persisted flag in
   `LocalPersistence`, with `O05` landing on `T01`, and add a "Your training" row to `A02` so the
   answers stay editable. Every option is already preselected and every step already has a Skip, so
   the whole thing is inside the minute. (F2.)

3. **Stop naming a programme nobody chose.** Pass a real title into `WorkoutCard`, and render nothing
   where there is none, in `today_cards.dart:300`, `train_view.dart:171` and `program_view.dart:119`.
   Drop the 12 kg goblet squat from the first session, or drop its load. Home and Train then either
   agree or say nothing, and the first set she is asked for is one she can do on a mat. (F4, F5.)

4. **Make the two hidden doors visible.** A chevron or a "See your progress" action on Home's week
   block, a labelled My cycle row on Home, the avatar at 44 points, and a title on `A02`. Four small
   edits that move Progress, personal bests, milestones, body, My cycle, Language, Privacy and data
   deletion from "guess the icon" to "read the row". (F7, F8.)

5. **Put the first-week tour back on Home and tell the truth about it.** Move the "Your first week"
   row out of the day-one branch into the ordinary Home while the arc is incomplete, and replace
   `progress_view.dart:135`'s "All five done" with the counted subtitle. That is the product's own
   self-guided tour, and it is currently reachable only by accident and mislabelled when it is.
   (F3, F6.)

---

### Reproduction notes

```sh
export PATH="$HOME/development/flutter/bin:$PATH"
cd .claude/worktrees/release-readiness/app
flutter build ios --simulator --debug
xcrun simctl uninstall 04852D18-AA25-4FD6-996E-488DECDACA1C com.ownhub.app
xcrun simctl install   04852D18-AA25-4FD6-996E-488DECDACA1C build/ios/iphonesimulator/Runner.app
xcrun simctl launch    04852D18-AA25-4FD6-996E-488DECDACA1C com.ownhub.app
xcrun simctl io        04852D18-AA25-4FD6-996E-488DECDACA1C screenshot first-launch.png
```

Arabic: `xcrun simctl spawn <udid> defaults write -g AppleLanguages -array ar-EG ar en`, then
`flutter run -d <udid>`.

Note that repeated `simctl terminate` and `simctl launch` cycles put this simulator into a state
where every launch draws a blank white page. `flutter run` recovers it, and `P03` and `A04` both
render correctly when opened that way. That is an environment artefact, not a defect in the app; it
was checked before it was discounted.

Screenshots referenced above are in `/tmp/ownhub/`. The graph and semantics measurements came from a
throwaway harness in `app/test/`, which has been removed; the crawler log is `/tmp/ownhub/crawl.tsv`.
