# WO-01a: fix the two failing tests (reminder bank race)
Depends on: none
Size: S (under 1 hour)
Reads first:
- `app/lib/app_state/notification_sync.dart` lines 62-81 (the bank and `_loadBank`) and lines 370-398 (`reapply`)
- `app/test/features/train/training_reminders_test.dart` lines 1-35 and 108-130 (imports and `setUp`)
- `app/test/app_state/getting_started_test.dart` lines 1-35 and 94-103 (imports and `setUp`)

## Why
Two tests fail on the current tree: `app/test/features/train/training_reminders_test.dart:284` ("applied" has 2 entries, expected 1) and `app/test/app_state/getting_started_test.dart:242` ("tips" is empty, expected `kNudgesUnanswered - 1` = 2). Neither is caused by batch A, the kitten removal or today's date. Root cause, found by running both with a stack trace printed inside the fake scheduler:

1. `NotificationSync.reapply` calls `_loadBank(scheduler)` on the first call in a process. `_loadBank` reads `assets/content/notification_lines.json` and, when the bank is not empty, calls `reapplyLast(scheduler)` with `now: null`, which means the real clock.
2. `rootBundle.loadString` decodes the file in a separate isolate only when the file is 50 KiB or larger (`packages/flutter/lib/src/services/asset_bundle.dart`, `data.lengthInBytes < 50 * 1024` decodes at once). Before commit `fe5a732` (25 Oct 2026, "Notifications: remove the playful tone and 20 filler calm lines") the file was 63,520 bytes, so the decode finished after the test had ended. That commit cut it to 27,257 bytes, so the decode now finishes inside the first test that schedules anything, and a second `apply` lands in the middle of it.
3. In `training_reminders_test` that second `apply` is the second entry in `applied`. In `getting_started_test` the second `apply` runs with the real date (26 Oct 2026) against a tip series anchored on 14 Oct 2026, so the series is over and `scheduler.tips` (which reads `applied.last`) is empty.

The production behaviour (first plan with fixed texts, then the same plan again in the new words) is intended and stays. The fix is in the two tests: they must not load the real bank, so they set the bank to the empty one, which `NotificationSync` already allows (`@visibleForTesting static set bank`). With an empty bank every note keeps its fixed text, which is what both tests assert.

## Final result
No screen changes. No production code changes. Both tests pass, and so does everything else in both files.

## Files to edit or create
| path | create or edit | what changes in one line |
|---|---|---|
| app/test/features/train/training_reminders_test.dart | edit | two imports and one line in `setUp` |
| app/test/app_state/getting_started_test.dart | edit | one import and one line in `setUp` |

## Steps
1. See the red state first. Run, from `~/ownhub/app`:
   `flutter test test/features/train/training_reminders_test.dart test/app_state/getting_started_test.dart`
   Expect the last lines to name exactly these two failures and nothing else:
   `training_reminders_test.dart: Home reminder offer her days, preselected from her week, are set once allowed` and
   `getting_started_test.dart: the meal photo tip only where she can take one the plan leaves it out and marks it done`.
   If a different test fails too, stop and follow "If stuck".
2. File `app/test/features/train/training_reminders_test.dart`. Anchor: the line `import 'package:own_hub/app_state/app_snapshot.dart';` (about line 16). Add these two lines directly under it:
   ```dart
   import 'package:own_hub/app_state/notification_sync.dart';
   import 'package:own_hub/features/train/domain/notification_voice.dart';
   ```
3. Same file. Anchor: in `void main()`, the first `setUp(() {` (about line 116), whose first line is `AppRouter.featureFlags = FeatureFlags.everything;`. Before:
   ```dart
     setUp(() {
       AppRouter.featureFlags = FeatureFlags.everything;
   ```
   After:
   ```dart
     setUp(() {
       // The real bank loads on the first schedule and sets the plan again
       // with the real clock; these tests count the first plan only.
       NotificationSync.bank = NotificationVoice.empty;
       AppRouter.featureFlags = FeatureFlags.everything;
   ```
4. File `app/test/app_state/getting_started_test.dart`. Anchor: the line `import 'package:own_hub/features/train/domain/notification_plan.dart';` (about line 23). Add directly under it:
   ```dart
   import 'package:own_hub/features/train/domain/notification_voice.dart';
   ```
   (`notification_sync.dart` is already imported there, line 13.)
5. Same file. Anchor: in `void main()`, the first `setUp(() {` (about line 98), whose first line is `SharedPreferences.setMockInitialValues({});`. Before:
   ```dart
     setUp(() {
       SharedPreferences.setMockInitialValues({});
       _clean();
   ```
   After:
   ```dart
     setUp(() {
       // The real bank loads on the first schedule and sets the plan again
       // with the real clock; these tests read the first plan only.
       NotificationSync.bank = NotificationVoice.empty;
       SharedPreferences.setMockInitialValues({});
       _clean();
   ```
6. Run both files again (command in "Verify").

## Strings to add
None.

## Tests to add or change
| file | test name | exact arrange, act and assert in words |
|---|---|---|
| app/test/features/train/training_reminders_test.dart | her days, preselected from her week, are set once allowed (existing) | Unchanged body. With the empty bank set in `setUp`, saving the sheet calls `apply` once, so `fake.applied` has length 1 (line 284). |
| app/test/app_state/getting_started_test.dart | the plan leaves it out and marks it done (existing) | Unchanged body. `NotificationSync.reapply(scheduler, text, now: _landed)` is the only `apply`, so `scheduler.tips` is the two tips of 15 and 16 October (line 242). |

Command: `cd ~/ownhub/app && flutter test test/features/train/training_reminders_test.dart test/app_state/getting_started_test.dart`

## Verify
1. The command above ends with `All tests passed!` and no `-N` failure counter (the counter reads like `+40: All tests passed!`; the exact number is not important).
2. `cd ~/ownhub/app && flutter analyze lib test` ends with `No issues found!`.
3. `cd ~/ownhub/app && dart format --output=none --set-exit-if-changed test/features/train/training_reminders_test.dart test/app_state/getting_started_test.dart` prints `Formatted 2 files (0 changed)`.
4. `git -C ~/ownhub diff --stat -- app/lib` shows no new change from this order (only the other, older uncommitted changes).

## Do not
- Do not change `notification_sync.dart` or the bank file `app/assets/content/notification_lines.json`. The double schedule is intended in production.
- Do not make the tests wait for the bank (no `Future.delayed`, no `runAsync`). They would pass or fail by timing.
- Do not delete or loosen the two assertions (`hasLength(1)`, `hasLength(kNudgesUnanswered - 1)`).
- Do not add `NotificationVoice.empty` anywhere else; other test files that need the real bank set it themselves (`app/test/app_state/notification_voice_state_test.dart`).

## Done checklist
- [ ] Step 1 showed exactly the two known failures
- [ ] Both files edited as above
- [ ] Both test files pass together
- [ ] `flutter analyze lib test` clean
- [ ] `dart format` check on the two files clean
- [ ] No file other than the two test files changed by this order

## If stuck
Anchor not found, or a different test fails after two tries: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-01b. Do not touch `notification_sync.dart`.
