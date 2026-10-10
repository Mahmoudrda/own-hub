# Own Hub demo tour before sign-up: build spec

Branch `onboarding/2026-10-06`, worktree `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding`. This spec builds on the uncommitted value-first work and keeps it.

## 0. Summary

- **First launch.** She opens on C01 Welcome and taps "Show me around". That opens the tour on C04, which is the existing look-around route, rebuilt to host the **real** Home, Workout day, Workout player, Recipes, Week plan, Cycle and Progress widgets. Each one is fed fresh sample objects that refuse writes.
- **Sample state is labelled and stays put.** A "Sample · nothing is saved" badge and a calm "Join Own Hub" button sit on every stop.
- **Real actions open the join sheet.** Any real action opens "Join to make this yours".
- **The tour ends on "Make it mine".** That leads into the existing value-first chain: O03 (your week, with life stage) → O05 → C06 → C07 → C09b → C10/C10b → C11 → C12 → C13 → day 1.
- **The gate is not changed.** `openBeforeVerification` stays as it is. The tour never routes to a product screen; it builds the widgets directly inside C04, which is in the `signup` flow.

## 1. Research findings (with sources)

| Source | What it says | What it means for Own Hub |
|---|---|---|
| Apple HIG, Managing accounts | "Delay sign-in as long as possible… Give them a chance to familiarize themselves with your app before making a commitment." "Ask people to sign in only in exchange for value." | The tour comes first, and Join is offered when she tries a real action. |
| App Review 5.1.1(v) | "If your app doesn't include significant account-based features, let people use it without a login." "Apps may not require users to enter personal information to function, except when directly relevant to the core functionality…" | The women-only check is core and account-based. The tour shows the app's function before any personal data is asked for, which strengthens the case for ID. |
| App Review 5.1.1(i)/(ii) | "Apps that collect user or usage data must secure user consent for the collection, even if… anonymous." | The tour collects nothing. No new analytics events; release analytics stays the Null sink. |
| App Review 4.2 | The app must be "app-like", not a repackaged site. | The tour uses the real native views, not screenshots. |
| App Review 2.1(a) | Provide "an active demo account or fully-featured demo mode". | The tour is **not** fully featured. App Review still needs a pre-verified reviewer account (see §9). |
| Google Play Data safety | "'Collect' means transmitting data from your app off a user's device… data… only processed locally… does not need to be disclosed." | Sample state is in memory only, so nothing is declared for the tour. |
| Google Play User Data | Prominent disclosure and affirmative consent are required before collecting personal or sensitive data. | Consent stays at C09b, after Join. The tour asks for nothing. |
| Google Play App access | "You must provide the necessary information for our team to log in and access all app functionality." | Same as Apple: a reviewer account is needed. |
| Duolingo | Runs the first lesson before asking for an account ("gradual engagement"). Delaying sign-up gave about a 20% DAU lift. Prompts come at moments where saving progress matters. | Join prompts come at the moment of a real action ("make this yours"). |
| Airbnb | Browse, search and read reviews logged out. An account is needed to book. | Browsing is open; acting needs Join. |
| Banking demo modes (Simple and others) | Sample balances and fictional transactions let people learn the UI with no personal data. | A labelled sample week. |
| Headspace, Noom, Flo | A few personalisation questions, then account creation. Flo asks goal → features → registration → period. | O03 comes after she decides to join, as the owner asked. |
| NN/g, Mobile tutorials | Deck-of-cards tutorials gave no success gain (91% vs 94%) and made tasks seem harder (4.92 vs 5.49 out of 7). Onboarding should be "brief, optional", contextual or interactive. | One short line per stop, freely tappable real UI, and Skip/Join always visible. No spotlight overlays. |

## 2. What the code allows

- **The views are pure widgets.** They take repositories and callbacks: `TodayView`, `WorkoutDayView`, `MidSetView`, `RecipesView`, `WeekPlanView`, `CycleHubView`, `ProgressView` and `RahmaRecipeView`. Their only global reads are `AppRouter.screenIsOn` and `featureFlags`, which hide Ask (X01), community (M01) and coached rows. This is exactly the honesty we need: switched-off features don't render.
- **Unwired controls are the leak risk.** Any control whose callback is null falls through `openScreen()` (`lib/features/today/presentation/today_cards.dart:37`) to `AppRouter.goTo`. A single guard in `AppRouter.goTo` (`lib/routing/app_router.dart:6058`) catches every one of those.
- **Persistence never sees fresh objects.** `LocalPersistence` (`lib/app_state/local_persistence.dart:225`) snapshots only the `AppRouter` singletons, and only on `AppChanges.bump()`. Fresh demo instances are never seen by the snapshot or by `CloudStore`.
- **Recipes stay on the phone while signed out.** `EatAppState._liveRecipeSource` returns null when signed out or unverified, so the recipe seed never goes to the network. The tour still passes the seed book in explicitly (`SeededRecipeLibrary().load()`).
- **Sample data that already exists:**
  - `InMemoryTodayRepository.defaultDay()`: one of three sessions done, a walk to count, breakfast logged.
  - `sampleWorkoutDay(l10n)`: the real authored day 1.
  - `sampleMealPlan(weekId)`.
  - `CycleDocument`, `ProgressSummary.from(...)` and the `Rewards` / `WeeklyGoal` constructors.
- **Existing strings to reuse:** `next`, `back`, `close`, `countOfTotal` ("{count} of {total}"), `weJustNeedYourNumberAndA`, `iAlreadyHaveAnAccount`.
- **Constraints:**
  - `baked_in_samples_test` has a ratchet at 117, so new strings must not contain digits.
  - `nav_reachability_test` reads literal `goTo(context, 'X')` calls in builders, so the O03/O05/C04 edges must stay literal.
  - The cycle no-analytics guard must still hold.

## 3. New first-run order and tap counts

```
C01 Welcome  [Show me around] [Skip the tour and join] [I already have an account] + language chips
  └─ C04 Tour: 1 Home → 2 Workout day → 3 Workout player → 4 Recipes → 5 Week plan → 6 Cycle → 7 Progress → End card
       persistent: Sample badge · Join Own Hub · ✕ Leave the tour (pops to C01)
       Join / Make it mine
  └─ O03 Your week (+ life stage) → O05 Her week "Save my week and join" → C06 → C07 → C09b → C10/C10b → C11 → C12 → C13 → Start day 1 → T01+R03
```

Back from O03 returns to the tour on the stop she left, because C04 stays underneath.

| Goal | Taps |
|---|---|
| See any stop | 1 (Show me around) + up to 6 Next, or 2 using the bottom bar |
| Whole tour → O03 | 9 (1 + 7 Next + Make it mine) |
| First workout, full tour | 17 (9 tour taps + O03, O05, C06, C09b, camera Allow, C11, C13, R03) |
| First workout, Join from stop 1 | 10 |
| First workout, "Skip the tour and join" | 9, the same as today |

## 4. Demo stops

Every stop:

- has the badge "Sample · nothing is saved";
- has a coach card at the **top**, under the badge bar, showing "{n} of 7", a title, one line, and Back / Next;
- keeps the real view's own bottom bar, with tabs mapped to stops: Home → 1, Train → 2, Eat → 4;
- is wrapped in `ScreenScope(screenId: <real id>)` so the real illustrations load.

The coach card is a live region: announce the stop title on change. Card copy follows (EN / AR MSA, feminine forms).

| # | Real widget and sample data | Coach title / line (EN) | AR MSA | Moves to another stop | Opens join sheet |
|---|---|---|---|---|---|
| 1 | `TodayView`. `DemoTodayRepository(day: demoDay())`. `demoDay` is `defaultDay(date: now)` with `programWeek` and `programTotalWeeks` set to null (no "Week 3 of 8": that programme doesn't exist). `level: sample.summary.level`, `sessionTitle: sampleWorkoutDay.title`, `offerCycleSetup: false`. | **Home, your day at a glance** · Own Hub is a fitness app for women only. Home shows today's workout, what you have eaten and how your week is going. This week is a sample, so tap anything. | **الرئيسية، يومكِ في لمحة** · Own Hub تطبيق لياقة للنساء فقط. تعرض الرئيسية تمرين اليوم، وما تناولتِه، وسير أسبوعكِ. هذا الأسبوع عيّنة، فاضغطي على ما تشائين. | Workout card → 2; week block → 7; cycle card → 6; tabs | Meal, plates, count walk, recall (T02), profile, notifications, first-week row |
| 2 | `WorkoutDayView(day: sampleWorkoutDay(l10n), repository: demoTrain, lifeStage: null)` | **Today's workout** · Quiet sessions you can do at home. Each move shows its sets and the weight to aim for. Trained without your phone? You can log it afterwards. | **تمرين اليوم** · جلسات هادئة تؤدّينها في البيت. تُظهر كل حركة مجموعاتها والوزن المقترح. تدرّبتِ دون هاتفكِ؟ يمكنكِ تسجيل ذلك بعدها. | Back → 1 | Start, Already did it, a move, Not today |
| 3 | `MidSetView(move: day.moves.first, moveNumber: 1, moveCount: day.moves.length, repository: demoTrain, bus: demoBus)` | **During a workout** · One move at a time. Tap when a set is done, and Own Hub keeps count and times your rest. | **أثناء التمرين** · حركة واحدة في كل مرة. اضغطي عند إنهاء كل مجموعة، ويتولّى Own Hub العدّ وتوقيت راحتكِ. | Close → 2 | Log set (call `handle.undo()` first, so nothing appears logged), Pause, Change set |
| 4 | `RecipesView(book: seedBook, constraints: DietaryConstraints.unknown, asked: false)` | **Rahma's recipes** · Home cooking you already know, written by coach Rahma Mohsen. Open the first recipe to see one in full. | **وصفات رحمة** · طبخ البيت الذي تعرفينه، كتبته المدرّبة رحمة محسن. افتحي الوصفة الأولى لتريها كاملة. | Week-plan tile → 5; tabs. The **first recipe in the book** pushes `RahmaRecipeView` read-only, inside `DemoScope`, as an unnamed route (Share opens the join sheet). | Every other recipe, search, allergies (E10), letter (E11) |
| 5 | `WeekPlanView(repository: demoMeal, now: now)` with `sampleMealPlan(thisWeek)` | **Your week of dinners** · A week of dinners, planned for you. Swap any you do not fancy, and the shopping list follows. | **عشاء أسبوعكِ** · عشاء أسبوع كامل مخطَّط لكِ. بدّلي ما لا يعجبكِ، وتتبعه قائمة التسوّق. | Back → 4; the sample recipe id opens as in stop 4 | Swap, regenerate, grocery list, other recipes |
| 6 | `CycleHubView`. `cycle: CycleDocument(mode: datesAndSymptoms, cycleLengthDays: 29, lastPeriod: start = today−9, recentStarts: two earlier starts)`, `checkIn: TodayCheckIn.absent`, `periods: matching sample`, `now` | **Your cycle, if you want it** · Log your period and how you feel. On harder days Own Hub can suggest a gentler session. Cycle data stays on your phone unless you choose to back it up. | **دورتكِ، إن أردتِ** · سجّلي دورتكِ وكيف تشعرين. وفي الأيام الأصعب يمكن أن يقترح Own Hub جلسة ألطف. تبقى بيانات الدورة على هاتفكِ ما لم تختاري نسخها احتياطيًّا. | Tabs | Check-in, add dates, settings, suggestions toggle, gentler option, meals, rest, calendar and patterns tabs. Find care and guidance use the router's existing honest notices. |
| 7 | `ProgressView(summary: ProgressSummary.from(goal: WeeklyGoal(sessionsTarget: 3, countedWeeks: 2, currentRun: 2), rewards: Rewards(level: 2, sessionsLogged: 7, …), milestoneCount: authoredMilestones.count), firstWeek: demoDay.arc)` | **Your progress** · Your weeks, your personal bests and your milestones, counted only from what you log. | **تقدّمكِ** · أسابيعكِ وأفضل أرقامكِ الشخصية وإنجازاتكِ، محسوبة فقط مما تسجّلينه. | Back → 6; tabs | Milestones, bests, body, first week, rest week, tier |

The end card is drawn by the host, not by a real view:

- **Title:** "That is Own Hub" / "هذا هو Own Hub"
- **Lines:**
  - "To make it yours, join with your phone number." / "لتجعليه لكِ، انضمّي برقم هاتفكِ."
  - "Own Hub is for women only, so we check your ID once, with a quick selfie. The photos are deleted after the check." / "Own Hub للنساء فقط، لذا نتحقّق من هويتكِ مرة واحدة مع صورة ذاتية سريعة. تُحذف الصور بعد التحقّق."
  - "First, one screen to build your week. Own Hub opens for you once the check is done." / "أولًا، شاشة واحدة لنبني أسبوعكِ. ويُفتح لكِ Own Hub بعد اكتمال التحقّق."
- **Buttons:**
  - **Make it mine** / اجعليه لي (Join)
  - **See the tour again** / أعيدي الجولة (goes to stop 1)
  - `iAlreadyHaveAnAccount` (→ C06)

Chrome strings:

| Element | EN | AR |
|---|---|---|
| Badge | Sample · nothing is saved | عيّنة · لا يُحفظ شيء |
| Bar button | Join Own Hub | انضمّي إلى Own Hub |
| ✕ tooltip | Leave the tour | إنهاء الجولة |
| Bar button, waiting mode (opened from C14) | Back to my check | العودة إلى تحقّقي |
| Join sheet title | Join to make this yours | انضمّي ليصبح هذا لكِ |
| Join sheet body | `weJustNeedYourNumberAndA` (existing) | existing |
| Join sheet buttons | Join Own Hub / Keep looking | انضمّي إلى Own Hub / تابعي التصفّح |
| C01 primary | Show me around | خذيني في جولة |
| C01 secondary | Skip the tour and join | تخطّي الجولة وانضمّي |
| C01 footnote | The tour uses a sample week. No account, and nothing is saved. | تستخدم الجولة أسبوعًا تجريبيًّا. دون حساب، ولا يُحفظ شيء. |

Copy rules:

- No em dashes, no digits.
- Add all of it with `python3 tool/add_strings.py`.
- Never claim community, coaches, the assistant or video.
- Coach marks name only what renders at the shipping flags.

System back behaviour: previous stop; on stop 1 it pops to C01 (use `PopScope`). The stop index lives in host state and is never stored, so a relaunch starts again at C01.

## 5. How demo mode is isolated

1. **`DemoScope`** (new, `lib/app_state/demo_mode.dart`). An `InheritedWidget` holding `requestJoin(BuildContext)`, with `static DemoScope? maybeOf(context)`.
2. **Guard in `AppRouter.goTo`.** Add as the first line:
   ```dart
   if (DemoScope.maybeOf(context) case final demo?) { demo.requestJoin(context); return; }
   ```
   This catches every unwired `openScreen` fallback, so no product route can be pushed from inside the tour.
3. **Exits are outside the scope.** The tour's exits (Join, Make it mine, ✕, sign in) call closures created in the C04 route builder. Their `BuildContext` is an ancestor of `DemoScope`, so they are not intercepted.
4. **Fresh sample objects only.** `DemoSample.build(l10n, now)` is created once in the host's `initState` and never touches an `AppRouter` singleton. It builds `DemoTodayRepository`, `DemoTrainRepository` and `DemoMealRepository`, which extend the `InMemory*` versions. Every write method (`applyLog`, `recordPlate`, `swapDinner`, `tickGrocery`, `countWalk`, `logRecalledSession`, `completeStep`, `startSession`, `flushMove`, `swapMove`, `finishSession`, `logRecalled`, `logUnplanned`) does three things:
   - calls `onRefused()`, which opens the join sheet;
   - leaves state unchanged;
   - completes. Methods returning a `TrainSession` return `Future.error(const DemoWriteRefused())`.

   `markNoticeSeen` is a silent no-op. Nothing calls `AppChanges.bump()`, `OnboardingState`, `CycleAppState`, `EatAppState.session` or `WorkoutSessionState`.
5. **No Firebase.** The tour builds no callable, Firestore, auth or cloud object. Recipe refresh stays null-sourced while signed out or unverified. The boot-time Firebase, App Check and Crashlytics setup is app-wide and unchanged: Crashlytics is release-only and carries no user identifiers.
6. **Analytics.** No new events. The only event is the existing `screenViewed{C04, signup}`, which goes to the debug sink in debug builds and nowhere in release. `signUpStarted` fires only when she taps Join. The cycle stop emits nothing.
7. **Women-only promise.** The tour shows no real person's content: no community, no coach profiles, no other members. Only the sample and Rahma's published recipes.

## 6. Exiting to sign-up from anywhere

`onJoin` in both the C01 and C04 builders sets the same state and keeps the literal routes, so the reachability parser still sees them:

```dart
OnboardingState.instance.beforeSignup = true;
unawaited(analytics.track(AnalyticsEvent.signUpStarted));
goTo(context, intakeRepository.setupDone ? 'O05' : 'O03');
```

- **Waiting mode** (C04 opened from C14, `signedInUid != null || awaitingReviewer`): the button reads "Back to my check" and the action pops. This is today's behaviour, kept.
- **"I already have an account":** `goTo(context, 'C06')`.
- **✕:** `Navigator.maybePop`.

## 7. How the earlier value-first changes move

- **C01:** the primary button changes from "Set up my week" (→ O03) to "Show me around" (→ C04). The old action moves to the text button "Skip the tour and join". The language chips stay.
- **Unchanged:** O03 (short, with life stage), O05 "Save my week and join", `beforeSignup` semantics (cleared on code accepted and on sign-out), C06/C07 fixes, C09b-first trainee path, C12, C13 "Start day 1", the C14 saved-week line, `isDue` and `_firstRunStack`.
- **C05** stays as "C04 with the join sheet raised", kept for design review.
- **C03** is untouched.
- **The old `PreviewWorkout` rows are removed.** "Quiet full body 15 min" previewed content that doesn't exist; the tour uses the real authored day 1 instead.

## 8. Files

**New**
- `app/lib/app_state/demo_mode.dart`: `DemoScope`, `DemoWriteRefused`.
- `app/lib/features/signup/demo/demo_sample.dart`: `DemoSample.build`, `demoDay()`, the sample cycle and progress, and the three `Demo*Repository` classes.
- `app/lib/features/signup/presentation/demo/demo_stops.dart`: `enum DemoStop`, the copy for each stop, and a builder per stop that wires the callbacks (to a stop, or to `requestJoin`).
- `app/lib/features/signup/presentation/demo/demo_chrome.dart`: badge bar, coach card, end card, `showJoinSheet()`.

**Changed**
- `app/lib/features/signup/presentation/look_around_view.dart`: rewritten as the tour host. The class name `LookAroundView` is kept. Parameters: `onJoin`, `onLeave`, `onSignIn`, `waiting`, `openJoinPrompt`, `initialStop`, and `sample` (injectable for tests).
- `app/lib/features/signup/presentation/welcome_view.dart`: adds `onLookAround`, the three actions and the footnote.
- `app/lib/routing/app_router.dart`: C01/C04/C05 builders, the `goTo` guard, comments on C04 and the gate (no gate code change).
- `app/lib/l10n/*` and `6-v2/i18n/ar-extra.json`, both via `tool/add_strings.py`.

**Tests to add**
- `test/features/signup/demo_tour_test.dart`:
  - each stop renders the real widget type (`TodayView` … `ProgressView`);
  - the badge and Join button are on every stop and the end card;
  - Next/Back and "{n} of 7";
  - bottom-bar tabs switch stops;
  - Arabic is right-to-left;
  - no overflow at text scale 2.0;
  - every join trigger listed in §4 opens the sheet, and "Keep looking" keeps the stop.
- `test/features/signup/demo_repositories_test.dart`: every write method refuses, calls `onRefused` and leaves state unchanged; Log set on stop 3 leaves nothing logged.
- `test/journeys/demo_isolation_test.dart`, on the real `OwnHubApp`, running the tap-crawler over every tour control. Assert:
  - the `NavigatorObserver` sees no push except the C04 sheet, the sample recipe page and the exits to O03/O05/C06;
  - all `AppRouter` singletons are unchanged: `todayRepository.day.state == dayOne`, meal day empty, `cycleRepository.current == null`, `intakeRepository.setupDone == false`, `progressStore` unchanged, `OnboardingState` flags unchanged;
  - an in-memory `SnapshotStorage` records zero writes;
  - a recording analytics sink gets only `screenViewed{C04}`, plus `signUpStarted` after Join, and nothing on the cycle stop;
  - a fake `VerificationBackend` and cloud transport see zero calls;
  - `AppRouter.goTo` under `DemoScope` pushes nothing and opens the sheet.
- `test/routing/verification_gate_test.dart`: new case. Signed out with the tour open, `pushNamed('/today/t01')` still resolves to C01.

**Tests to update**
- `test/journeys/value_first_signup_test.dart`: C01 → C04; "Skip the tour and join" → O03; tour Join, sheet Join and Make it mine → O03, or O05 when the week is saved; Back from O03 returns to the same stop.
- `test/features/signup/welcome_view_test.dart`: three actions, footnote, tap targets.
- `test/features/signup/look_around_view_test.dart`: replace the `PreviewWorkout` cases.
- `test/qa/round4/r4_02_nav_bar_claim_test.dart`: C04/C05 now show the real tab of the stop, so re-pin the all-on list with a reason.
- `test/nav_reachability_test.dart`: C01 → C04, and C04 → O03/O05/C06.
- `test/journeys/first_run_journey_test.dart`, `test/release_readiness_test.dart` and `test/journeys/dead_controls_journey_test.dart`, wherever they assert the C01 copy.
- Confirm still green: `baked_in_samples_test` (ceiling stays 117), `i18n_guard_test`, the cycle no-analytics guard, `tap_crawler_test`, `large_text_sweep_test`, `flag_independence_test` (set flags explicitly in new tests).

## 9. Out of scope, and owner calls

- **Store review account (release blocker, not code).** Apple 2.1 and Play's App access rule both need a working reviewer account with access to everything. The tour is not "fully featured", so a pre-verified reviewer phone with a fixed OTP is needed on the server side.
- **Recipes in the tour.** One recipe opens in full; the rest open the join sheet. Owner to confirm, or open all of Rahma's recipes.
- **Tour funnel analytics** (which stop she joined from) waits until an analytics service is chosen. It would be a new allow-listed event.
- **Website.** Optional: a "Take the tour before you join" line on the EN/AR site. Not part of this build.

## Sources
- https://developer.apple.com/design/human-interface-guidelines/managing-accounts
- https://developer.apple.com/app-store/review/guidelines/ (2.1(a), 4.2, 5.1.1(i), (ii), (v))
- https://support.google.com/googleplay/android-developer/answer/10787469 (Data safety: definition of "collect", on-device processing)
- https://support.google.com/googleplay/android-developer/answer/10144311 (User Data, prominent disclosure)
- https://support.google.com/googleplay/android-developer/answer/15748846 (App access for review)
- https://www.appcues.com/blog/best-user-onboarding-examples and https://goodux.appcues.com/blog/duolingo-user-onboarding (Duolingo)
- https://community.withairbnb.com/t5/Hosting/How-guests-can-find-my-house-without-login/m-p/469936 (Airbnb browse logged out)
- https://finovate.com/bank_simple_innovations_1_2_demo_mode_after_login/ and https://www.altkomsoftware.com/blog/mobile-onboarding-in-banking/ (banking demo modes)
- https://goodux.appcues.com/blog/headspaces-mindful-onboarding-sequence, https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel, https://help.flo.health/hc/en-us/articles/4406826484500-Setting-up-your-Flo-account
- https://www.nngroup.com/articles/mobile-tutorials/ and https://www.nngroup.com/articles/onboarding-tutorials/