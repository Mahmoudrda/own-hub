I fixed six of the review's seven items and left L6 alone. There were no blocker or high problems to fix, so everything below is a medium or low item that turned out to be small. `flutter analyze` reports no issues and the full `flutter test` run passed all 4,784 tests (the earlier 4,777 plus 7 new ones). Nothing is committed: your rules for this run said never commit, so there are no commit hashes and the changes sit uncommitted in the worktree with the rest of the onboarding work.

| ID | Status | What changed | What proves it |
|---|---|---|---|
| M1 | Fixed | The join sheet now says "First your week, then your number and a quick check that you are a woman. About two minutes, once." If her week is already built, it keeps the old "We just need your number…" line. Both strings, English and Arabic, went in through `tool/add_strings.py`. | Two tests in `look_around_view_test.dart` |
| L1 | Fixed | When the tour is the first screen, the close button now opens the front door instead of doing nothing. | New test in `demo_isolation_test.dart`: tour opened alone, close leads to C01 |
| L2 | Fixed | C04 and C05 now share one builder, `_lookAround`, so C05 handles a woman waiting on her check the same way C04 does. | New test: C05 opened while waiting shows "Back to my check" and returns her without restarting sign-up |
| L3 | Fixed | "Back to my check" on the recipe page now leaves the tour too. | New test: from the recipe page she lands on the route under the tour |
| L4 | Fixed, partly tested | If the recipe file fails to load, the recipes stop now says "…The recipes open with your account." instead of promising a recipe. | A new test checks the bundled recipe file loads inside the tour. The failure case itself has no test, because the recipe library caches its result and can't easily be forced to fail. |
| L5 | Fixed | The "⋮" button on the workout-day screen is only drawn when it does something. In the tour it now opens the join sheet. | One new test in `workout_day_view_test.dart`, one new case in `demo_tour_test.dart` |
| L6 | Not done | No tour funnel events were added. | n/a |

**Two places where I didn't follow the review's suggested fix:**
- **L2:** the review said to move all the C04 logic into one function. I kept the screen IDs written out in each route entry, because `nav_reachability_test` builds the navigation map by reading those IDs from the route table and failed when they moved.
- **L3:** the review suggested popping until a route name or the first route. `exits_and_already_verified_test` forbids any exit that pops to "whatever is first". The fix instead pops back to the tour's own page, then closes it, or opens the front door if nothing is underneath.

**Why L6 was left out:** it isn't a small change. It would add two new analytics events and wire analytics into the tour, which the tour's isolation design currently promises it doesn't do. The analytics code treats adding an event as a deliberate, reviewed decision, and the isolation test's expectations for every control would change. That decision should be yours.

**Also done (from N2):** the code comments in `look_around_view.dart` and `demo_sample.dart` no longer say nothing in the tour touches the network. They now say it asks the network for no data, and mention that crash reporting and App Check still run in the background.

**New things I noticed:**
- The new recipe-fallback string got the awkward generated name `homeCookingYouAlreadyKnowWrittenBy_7q8w1`, because its English starts the same way as an existing string. It works, but the name is ugly.
- N2 (declaring crash logs in the Play Data safety form) and N3 (a pre-verified account for App Store and Play reviewers) are still open. They aren't code changes.

Files changed:
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/routing/app_router.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/look_around_view.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/demo/demo_chrome.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/presentation/demo/demo_stops.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/signup/demo/demo_sample.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/features/train/presentation/workout_day_view.dart`
- `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/lib/l10n/*` (regenerated) and `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/6-v2/i18n/ar-extra.json`
- Tests: `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/test/journeys/demo_isolation_test.dart`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/test/features/signup/demo_tour_test.dart`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/test/features/signup/look_around_view_test.dart`, `/Users/mahmoudreda/ownhub/.claude/worktrees/onboarding/app/test/features/train/workout_day_view_test.dart`