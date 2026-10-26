# WO-01d: confirm the four batch A review items that are already fixed (no edits)
Depends on: WO-01a, WO-01b, WO-01c
Size: S (under 1 hour)
Reads first:
- `docs/plan/RESUME-ROADMAP.md` lines 8-14 (the list of must-fix items)
- `app/test/helpers/control_counter.dart` lines 68-112
- `app/lib/main.dart` lines 464-470 and `app/lib/routing/app_router.dart` lines 6525-6535
- `app/test/store/store_screenshots_test.dart` lines 355-380

## Why
`docs/plan/RESUME-ROADMAP.md` lists six must-fix items from the batch A review. Looking at the tree now, four of them were already fixed after the review was written, so there is nothing to build. A work order that tells an agent to "fix" something that is fixed makes it rewrite working code. This order only runs the proof for each one and writes the result down. The two items that were still open are WO-01b (unused string) and WO-01c (follow-up card).

| # | Review item | State on the tree | Evidence |
|---|---|---|---|
| 1 | The control counter hides the "+" of a row that has no tap | Fixed | `_isRowAdd` (about line 96) only folds a `PlusButton` into a row when `w is AppListItem && w.onTap != null`; `_isPlumbing` (about line 71) skips a no-tap row. Test: `a plus in a row with no tap is a control of its own` in `app/test/qa/control_counter_test.dart` (about line 126). |
| 2 | App killed inside the 5 second Undo window loses the last set | Fixed | `didChangeAppLifecycleState` in `app/lib/main.dart` (about line 468) calls `AppRouter.finishWorkoutIfClosing()` on `AppLifecycleState.paused`; `finishWorkoutIfClosing` is at about line 6530 of `app/lib/routing/app_router.dart`. Test: `the app going to the background inside the window saves the last set` in `app/test/routing/last_log_undo_test.dart` (about line 136). |
| 4 | Stale R13 steps in the store screenshots | Fixed | `finishTheWorkout` in `app/test/store/store_screenshots_test.dart` (about line 362) logs one set, then `finishEarly(tester)` (from `app/test/helpers/pause_menu.dart`, about line 63), and asserts `WorkoutSessionState.instance.lastFinished` has sets. No `I did`, `Next move` or `finishHere` text is searched for any more. |
| 5 | Home coach card lost its tap | Fixed in a different place | The card has no tap (`onOpen` was removed from `app/lib/features/private_coaching/presentation/client/coach_home_card.dart`) because Home with a coach is already at 5 controls (measured by `today_budget_test.dart`: 1 primary + 4 others at 390x844). My coach is one tap away in the Change sheet: row key `change-my-coach` in `app/lib/features/today/presentation/today_view.dart` (about line 536), wired by `onOpenCoach: () => goTo(context, 'H05')` at about line 2509 of `app/lib/routing/app_router.dart`. Test: `a coached woman: her coach is the Today card (D11)` in `app/test/features/today/today_budget_test.dart` (about line 336), which taps `change-my-coach` and expects the callback. |

Known limit of item 2 (report it, do not fix it): the last set is saved when the phone reports `paused`. A crash or a power loss inside the 5 seconds, with no `paused` first, still loses that one set.

Known limit of item 5 (report it): the line "New messages from your coach" on the card is text, not a button. Reaching the chat takes Change then My coach, or You then My coach.

## Final result
No file changes. A short result table in your report: item number, command, last line of the output.

## Files to edit or create
None.

## Steps
1. Item 1: `cd ~/ownhub/app && flutter test test/qa/control_counter_test.dart`. Expected last line: `+25: All tests passed!` (the number may be higher if tests were added; no `-N`).
2. Item 2: `cd ~/ownhub/app && flutter test test/routing/last_log_undo_test.dart`. Expected last line: `+8: All tests passed!`.
3. Item 4: `cd ~/ownhub/app && flutter test test/store/store_screenshots_test.dart`. Expected last line: `+4: All tests passed!`. (Without the environment variable `OWNHUB_SCREENSHOTS_DIR` it draws every step but writes no pictures; that is the intended check. Do not set the variable.)
4. Item 5: `cd ~/ownhub/app && flutter test test/features/today/today_budget_test.dart`. Expected last line: `+25: All tests passed!`.
5. Confirm item 3's other half: `grep -rn "finishHere" ~/ownhub/app/lib ~/ownhub/6-v2/i18n ~/ownhub/6-v2/flutter` prints nothing.
6. For any command whose last line is not `All tests passed!`, copy the first failing test's name and the first 10 lines of its error into your report and stop; do not edit anything (see "If stuck").

## Strings to add
None.

## Tests to add or change
None. Every test named in the table already exists on the tree.

## Verify
The four commands in steps 1 to 4 each end with `All tests passed!`, and step 5 prints nothing.

## Do not
- Do not edit `control_counter.dart`, `main.dart`, `app_router.dart`, the store screenshot test or `coach_home_card.dart` in this order.
- Do not put `onOpen` back on the coach card. It would be a sixth control on Home and `screen_budget_test.dart` would fail.
- Do not set `OWNHUB_SCREENSHOTS_DIR` (it writes picture files into the repo).

## Done checklist
- [ ] Four commands run, last lines copied into the report
- [ ] `grep finishHere` printed nothing
- [ ] The two known limits written in the report as open points, not as bugs fixed

## If stuck
A command fails: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw (test name plus the first 10 lines of its error), and move to WO-01e. Do not try to repair these files; if one was broken after the earlier review it needs a new work order from the planner.
