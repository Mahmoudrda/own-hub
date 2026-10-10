**Own Hub pre-signup tour: review of the uncommitted worktree (branch onboarding/2026-10-06)**

**Verdict:** No blockers and no high-severity problems. The tour meets the owner's brief: it comes before any data entry, real use stays locked until verification, the tour writes nothing, and join is always one tap away. `flutter analyze` reports no issues, and `flutter test` passed all 4,777 tests (including the new `demo_isolation_test`, `demo_tour_test`, `demo_repositories_test` and `value_first_signup_test`). The most useful fix is the join-sheet copy (M1): it says "we just need your number", but the next screen asks about her week.

**How I checked**
- **First launch.** It opens on the welcome screen (C01). The setup questions are not stacked on top before she is verified, because `OnboardingState.isDue` (onboarding_state.dart:108) is false until then.
- **Taps.**
  - Welcome to tour stop 1 is 1 tap. Stop k is k taps. The end card is 8 taps.
  - "Join Own Hub" is 1 tap from every stop, from the recipe detail page and from the join sheet. The end card's "Make it mine" is also 1 tap.
  - From the tour to the phone screen is 3 taps: Join, then "See my week" (O03), then "Save my week and join" (O05), then the phone screen (C06).
- **Gate.** The verification gate is unchanged (app_router.dart:586-623). The tour is in the `signup` flow, and any route asked for inside the tour opens the join sheet instead (app_router.dart:6126-6130).
- **Isolation.**
  - The sample repositories override every write in the Today, Train and Meal interfaces (demo_sample.dart:80-219).
  - The views shown in the tour read no global app state except feature-flag checks.
  - Recipes come from the bundled file, never the server.
  - The only analytics events are the screen views for C01 and C04, and a release build sends analytics nowhere.
- **Labelling and honesty.**
  - "Sample · nothing is saved" is on every stop, on the recipe page and on the end card.
  - Each of the 7 stops has a coach card that explains it in plain words.
  - The assistant and community entry points are hidden by flag checks (today_view.dart:288 and :689), and the coach-credit pills are guarded (cycle_hub_view.dart:273 and :597).
  - The cycle claim ("can suggest a gentler session") is a real, shipped feature.
- **Back and RTL.**
  - System back walks back through the stops and leaves the tour only from stop 1 (look_around_view.dart:188).
  - Back from O03 returns her to the stop she left.
  - The tour's frame uses direction-aware padding, and Back/Next swap sides correctly in Arabic.

**Problems**

**MEDIUM**
- **M1. The join sheet's promise doesn't match the next screen.**
  - Where: `showJoinSheet`, demo_chrome.dart:291-293, using key `weJustNeedYourNumberAndA` (app_ar.arb:1192 and app_en.arb).
  - What's wrong: the sheet says "We just need your number and a quick check…", but Join opens O03 "Your week" (app_router.dart:1016-1018), not the phone screen. The end card says it correctly ("First, one screen to build your week").
  - Fix: change the copy.
    - EN: "First your week, then your number and a quick check that you are a woman. About two minutes, once."
    - AR: "أولًا أسبوعكِ، ثم رقمكِ وتحقّق سريع من أنكِ امرأة. نحو دقيقتين، مرة واحدة."
  - When `intakeRepository.setupDone` is true (Join goes straight to O05), keep the current copy. Pass a `setupDone` flag into `showJoinSheet` to choose between the two.

**LOW**
- **L1. The close button does nothing when the tour is the launch screen.**
  - Where: C04 `onLeave`, app_router.dart:1022-1025, and the same in C05.
  - What's wrong: `_openable` lets a deep link to `/signup/c04` be the first screen. Then `canPop()` is false and the X is a dead button.
  - Fix: `if (navigator.canPop()) navigator.pop(); else navigator.pushReplacementNamed(frontDoor);`
- **L2. A deep link to C05 ignores the "waiting on my check" state.**
  - Where: app_router.dart:1030-1046.
  - What's wrong: the C05 builder has no `waiting` handling. A signed-in woman waiting on her check who opens `/signup/c05` gets "Join Own Hub", and Join restarts sign-up.
  - Fix: build C05 by calling the C04 builder's logic with `openJoinPrompt: true`. Pull the C04 closure into one private function that takes `openJoinPrompt`, so both routes share `waiting`, `onJoin` and `onLeave`.
- **L3. "Back to my check" on the recipe page doesn't reach the check.**
  - Where: look_around_view.dart:153 together with app_router.dart:1007-1011.
  - What's wrong: the waiting branch of `onJoin` calls `navigator.pop()` once, which closes only the recipe page and leaves her on the tour.
  - Fix: in the waiting branch, use `navigator.popUntil((r) => r.settings.name != appRoutes['C04']!.name && r is! MaterialPageRoute<void> || r.isFirst)`. Simpler: give the recipe page a `RouteSettings(name: '/signup/c04/recipe')` and `popUntil` past both names.
- **L4. If the recipe seed fails to load, the recipes stop's instruction is false.**
  - Where: look_around_view.dart:100 (`onError: (_) {}`).
  - What's wrong: the stop's line says "Open the first recipe to see one in full", but with no book every row opens the join sheet instead.
  - Fix: on error, set `_bookFailed = true` and have the recipes stop's `line()` fall back to a line that doesn't promise a recipe. Add a test that the bundled seed loads in the tour.
- **L5. A disabled "⋮" button sits on the workout-day stop.**
  - Where: workout_day_view.dart:296-303. `onMore` is never passed, in the real R03 route (app_router.dart:1801) or in the tour (demo_stops.dart:145).
  - What's wrong: it looks like a broken control.
  - Fix: render the `IconButton` only when `widget.onMore != null`, and pass `onMore: join` in demo_stops.dart:145.
- **L6. There is no way to measure the tour funnel.**
  - Where: demo_isolation_test.dart:373 confirms only the screen views for C01 and C04 are recorded.
  - What's wrong: the owner can't see which stop women leave at, or which stop leads to Join.
  - Fix: add `AnalyticsEvent.tourStopViewed {stop: index}` and `tourJoinTapped {from: stop|sheet|end}` with no identifiers, fired from `_show` and `onJoin` in look_around_view.dart. Update the isolation test's expected list. They stay local until an analytics service and its consent exist.

**NOTE (not defects in the diff)**
- **N1. Life stage collected before sign-up stays on the phone if she never finishes.** O03 asks it before sign-up and keeps it on the phone even if she abandons, with no in-app way to clear it before she has an account. This is a settled decision (3-plan.md:145), and uninstalling removes it.
- **N2. Crashlytics and App Check run during the tour** (firebase_boot.dart:134 and :150). They are app-wide, carry nothing personal, and the tour's on-screen copy only claims "nothing is saved", so it stays honest. Two follow-ups:
  - The code comments in demo_mode.dart and look_around_view.dart say nothing calls the network. That isn't strictly true, so soften them.
  - Make sure the Play Data safety form declares crash logs.
- **N3. App Review will still need a pre-verified review account.** The tour doesn't replace it, and an Apple or Google reviewer can't pass a women-only ID check. Put the credentials and a short explanation in the App Store Connect and Play review notes before submitting. I found no such provision in the repo.

**What is genuinely good**
- The tour is built from the real screens with fresh sample repositories, not mock-ups.
- The route guard that turns any navigation inside the tour into the join sheet is a robust, structural guarantee, and it is tested.
- A refused write that must return a result never completes, rather than failing, so the tour can't produce a crash report.
- The sample badge, the explanation card on every stop, and the end card that says what joining involves before she starts make the tour honest and easy to follow.

The review is in this reply only; I didn't write a report file. The main files are:
- /Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/look_around_view.dart
- /Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/demo/demo_chrome.dart
- /Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/demo/demo_stops.dart
- /Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/demo/demo_sample.dart
- /Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/routing/app_router.dart