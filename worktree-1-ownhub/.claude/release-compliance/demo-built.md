I've built the tour, but three parts of the spec weren't true of the code or the content, so I built them differently (listed below). `flutter analyze` is clean and the full `flutter test` run passed 4777 with 0 failing. R1-12a passed on this run even though today is a Tuesday. Nothing is committed, pushed or stashed, and I haven't run it on a simulator or device. The only screenshots are test renders I saved to `/tmp/ownhub-demo/shots/`.

**What she sees now.** C01 has "Show me around" as its main button, with a line under it: "The tour uses a sample week. No account, and nothing is saved." Below that are "Skip the tour and join" and "I already have an account". The tour (C04) uses the real Home, Workout day, Workout player, Recipes, Week plan, Cycle and Progress screens with a sample week, then an end card. Every stop and the end card carry the "Sample · nothing is saved" badge, a "Join Own Hub" button and a close button. Each stop has a short card at the top ("n of 7", title, one line, Back and Next). The bottom bar's Home, Train and Eat move between stops, and system back steps back a stop, leaving the tour from stop 1.

**How it stays a demo.** Any real action opens "Join to make this yours" (Join Own Hub / Keep looking), one sheet at a time. Join, the sheet's Join and "Make it mine" all lead to O03, or to O05 if her week is already saved. Back from O03 returns her to the stop she left. A woman waiting on her check sees "Back to my check" instead. The tour's sample objects refuse every write and nothing in it reaches the app's real data. `AppRouter.goTo` now opens the sheet instead of navigating when called from inside the tour. The verification gate itself is unchanged.

**Tap counts from first launch**
| Goal | Taps |
|---|---|
| (a) See a workout in the demo | 1 (today's workout card on Home), 2 for the full workout day, 3 for the workout player |
| (b) Reach sign-up (O03) | 1 with "Skip the tour and join", 2 with "Show me around" then Join, 9 through the whole tour. Add 2 to reach the phone number. |
| (c) First real workout after the check | 9 when skipping the tour (unchanged), 10 joining from stop 1, 17 after the whole tour |

**Where I built it differently from the spec**
1. **Recipes stop.** With `asked: false`, the real recipe screen hides Rahma's whole book behind the allergy question, so "open the first recipe" was impossible. The sample now acts as a woman who was asked and avoids nothing, and the book shows with its existing "not checked yet" line. Lazy Cake opens in full, read-only; every other recipe opens the join sheet. **Decision for you:** keep this, or hide the book in the tour.
2. **Refused workout saves.** These don't fail with an error as specified; they never complete. A failed save that nothing catches is reported to Crashlytics in a release build, which would send something from the tour.
3. **Two coach lines changed to stay true.**
   - Workout: "Each move shows its sets and what to aim for", because day 1 is bodyweight only, with no weights.
   - Week plan: "A week of dinners planned for you, with one shopping list that covers them all." There is no swap-a-dinner feature, and the shopping list doesn't follow a swap.
4. I reused the existing "Today's workout", "Rahma's recipes" and "Your progress" strings. That means the Arabic for "Your progress" reads "تقدّمك", not "تقدّمكِ".
5. In waiting mode the sheet uses the existing line "The app opens as soon as your check is done."
6. Tapping "Count it" on Home hides the walk row on screen until she leaves the stop. Nothing is saved.
7. The real app widget can't take a navigation observer, so the full-app test checks routes a different way. It taps every control on every stop and confirms:
   - nothing opens except the sheet, Lazy Cake and the three exits;
   - nothing on the phone is written;
   - analytics get only the C01 and C04 screen views, plus "sign-up started" when she joins;
   - verification and cloud sync get zero calls.

**Files (all under `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app`)**
- New code:
  - `lib/app_state/demo_mode.dart`
  - `lib/features/signup/demo/demo_sample.dart`
  - `lib/features/signup/presentation/demo/demo_stops.dart`
  - `lib/features/signup/presentation/demo/demo_chrome.dart`
- Changed code:
  - `lib/features/signup/presentation/look_around_view.dart` (rewritten as the tour)
  - `lib/features/signup/presentation/welcome_view.dart`
  - `lib/routing/app_router.dart`
  - `lib/app_state/onboarding_state.dart` (comment only)
- Strings: 26 new EN/AR strings added with `tool/add_strings.py`, so `lib/l10n/*` and `6-v2/i18n/ar-extra.json` were regenerated.
- New tests:
  - `test/features/signup/demo_tour_test.dart` (48 cases)
  - `test/features/signup/demo_repositories_test.dart` (8)
  - `test/journeys/demo_isolation_test.dart` (10)
- Updated tests:
  - `look_around_view_test.dart`, `welcome_view_test.dart`, `flag_aware_promises_test.dart` (in `test/features/signup/`)
  - `test/journeys/value_first_signup_test.dart` (7 new tour cases)
  - `test/routing/verification_gate_test.dart` (a deep link to Home with the tour open still lands on C01)
  - `test/nav_reachability_test.dart` (the C01, C04 and C05 links)
  - `test/qa/round4/r4_02_nav_bar_claim_test.dart` (C04 and C05 drop off the list; 17 remain)
  - `test/foundations_test.dart`

**Not done**
- No simulator or device run.
- No App Review / Play reviewer account. That is a server-side release blocker.
- No website line.
- No tour analytics.

**Other things I noticed**
- On English at phone width, the Join button and close button wrap onto a second line under the badge. Arabic fits on one line.
- The real week-plan screen (E07) already says "built from recipes you have logged before. Swap any of them." There is no swap feature, and tapping a dinner opens the recipe. The tour now shows this to everyone.
- With no check-in, the Cycle stop shows only "How are you feeling?", which is thin.