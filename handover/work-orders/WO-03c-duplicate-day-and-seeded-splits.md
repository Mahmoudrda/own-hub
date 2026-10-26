# WO-03c: Duplicate day in one tap, and lock in the seeded splits
Depends on: none
Size: S
Reads first: `app/lib/features/train/presentation/plan_editor_view.dart` lines 157-189 and 286-358; `app/lib/features/train/domain/my_plan.dart` lines 254-276 (`withCopyOf`); `app/lib/routing/coaching_wiring.dart` lines 253-257 (`coachSplits`)

## Why
The audit said "Duplicate day is missing in the live flow". It is not missing: `PlanEditorView` (used by `ShareWorkoutView` through `_editDays`) has "Add a day", and its sheet lists "Copy of <day>" for every day (`withCopyOf`). That is 2 taps (Add a day, Copy of Upper). It is easy to miss, so this order adds a one-tap "Duplicate" button on each day card, gives the copy a distinct name, and adds tests that lock in that Rahma's three starting splits are offered. No data seeding is needed: `coachSplits()` already returns every programme of `assets/content/starting_programmes.json` (3-day, 4-day, 5-day, each in beginner, intermediate, advanced = 9 rows under "One of the three splits").

## Final result
Plan editor screen ("Edit days and moves"): each day card's action row (Edit, Replace when a split is the source, Remove) gets one more text button "Duplicate" / "نسخ اليوم" with a copy icon. One tap adds a copy at the end of the plan, named "Upper (copy)" / "علوي (نسخة)". When the plan is full (7 days in one week) the button is disabled. Footer is unchanged (one filled "Add a day"). Tap count to duplicate a day from the day list: 1. From the client page: Clients tab (1), client (2), Share a workout (3), pick a split (4), Edit days and moves (5), Duplicate (6).
Start-from list in "Share a workout": unchanged (9 rows). Note in the report: three splits x three levels.

## Files to edit or create
| path | file action | change |
|---|---|---|
| app/lib/features/train/domain/my_plan.dart | edit | `withCopyOf` takes optional `suffix` params and names the copy |
| app/lib/features/train/presentation/plan_editor_view.dart | edit | `_DayAction` Duplicate |
| app/test/features/train/my_plan_test.dart | edit | UNVERIFIED path: `ls app/test/features/train | grep -i plan` and use the file that tests `withCopyOf` |
| app/test/features/private_coaching/plans/plan_screens_test.dart | edit | duplicate tap test, splits test |

## Steps
1. File `my_plan.dart`, method `withCopyOf(int i)` (about line 254). Change the signature and the two titles. Before:
```dart
  MyPlan withCopyOf(int i) {
```
After:
```dart
  MyPlan withCopyOf(int i, {String suffixEn = '', String suffixAr = ''}) {
```
and in the `AuthoredSession(` it builds (about line 264) replace `titleEn: s.titleEn,` with `titleEn: _clip('${s.titleEn}$suffixEn', kMaxCustomNameLength),` and `titleAr: s.titleAr,` with `titleAr: _clip('${s.titleAr}$suffixAr', kMaxCustomNameLength),`. The existing call in `plan_editor_view.dart` line 184 (`_plan.withCopyOf(i)`) keeps working because both are optional (it gives the old identical name; leave it).
2. File `plan_editor_view.dart`, class `_PlanEditorViewState`, add a method after `_remove` (about line 108):
```dart
  void _duplicate(int i) {
    final copy = lookupAppL10n(const Locale('en')).copySuffix;
    final copyAr = lookupAppL10n(const Locale('ar')).copySuffix;
    _state.save(_plan.withCopyOf(i, suffixEn: ' $copy', suffixAr: ' $copyAr'));
  }
```
3. Same file, in the day card `Wrap(` of `_DayAction`s (about line 333-356), add between the Replace and Remove actions:
```dart
                      _DayAction(
                        key: ValueKey('plan-duplicate-$i'),
                        label: l10n.duplicate,
                        icon: Icons.copy_outlined,
                        onPressed: plan.isFull ? null : () => _duplicate(i),
                      ),
```
`_DayAction.onPressed` is typed `VoidCallback` (line 388); change its type to `VoidCallback?` (line 388-389: `final VoidCallback onPressed;` -> `final VoidCallback? onPressed;`) and the constructor stays `required this.onPressed`.
4. Add strings, run the script.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| duplicate | Duplicate | نسخ اليوم |
| copySuffix | (copy) | (نسخة) |

Write `/tmp/ownhub-wo03c.json`, run `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03c.json && flutter gen-l10n`. Use the getter names the script prints (replace `duplicate` and `copySuffix` in steps 2 and 3 if they differ).

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| plan_screens_test.dart | `plan editor: Duplicate adds a named copy in one tap` | Pump `PlanEditorView` with a `CoachPlanEditState` holding a 3-day plan (copy the existing editor test setup in this file). Tap `plan-duplicate-0`. Assert the plan has 4 days, day 3's English title is `<day 0 title> (copy)`, its moves equal day 0's moves, its sessionId differs from day 0's. |
| same | `plan editor: Duplicate is off when the week is full` | Plan of 7 days; `tester.widget<TextButton>(find.byKey(const ValueKey('plan-duplicate-0')).first).onPressed` is null. UNVERIFIED that the key resolves to the `TextButton` (it is on `_DayAction` which builds `TextButton.icon`); if `find` returns the `_DayAction`, use `find.descendant(of: find.byKey(...), matching: find.byType(TextButton))`. |
| `coach_meal_catalog_test.dart` neighbour: new test in plan_screens_test.dart | `the seeded splits are offered: 3 families, 3 levels` | Load the file: `StartingProgrammes.adopt(File('assets/content/starting_programmes.json').readAsStringSync())`; call `coachSplits()` (import from `package:own_hub/routing/coaching_wiring.dart`); assert length 9, and the set of `programId`s' families (`programmeFamily(id)`) has length 3. Call `StartingProgrammes.reset()` in `tearDown`. |
Run: `cd app && flutter test test/features/private_coaching/plans/plan_screens_test.dart` plus the my_plan test file you edited.

## Verify
`flutter analyze lib/features/train lib/routing/coaching_wiring.dart` -> `No issues found!`; tests -> `All tests passed!`.

## Do not
Do not rename the existing "Copy of ..." rows in the Add a day sheet. Do not change the starting programmes JSON. No em dashes. Do not commit.

## Done checklist
- [ ] Duplicate button  - [ ] Copy named  - [ ] Splits test  - [ ] Tests pass

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-03d.
