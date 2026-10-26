# WO-03f: Week 1, Week 2 on Rahma's editor and on the client's Plan and Home
Depends on: WO-03e
Size: M
Reads first: `app/lib/features/train/presentation/plan_editor_view.dart` lines 261-358; `app/lib/features/private_coaching/presentation/client/coach_plan_view.dart` lines 60-100 and 156-215; `app/lib/features/private_coaching/presentation/client/coach_home_card.dart` (all 91 lines); `app/lib/features/private_coaching/presentation/plans/share_workout_view.dart` lines 364-380

## Why
With weeks in the data (WO-03e), Rahma needs to add a week in one tap ("Repeat last week"), see which week each day is in, and the client needs to see "Week 2 of 4, starts Sat 1 Nov" so Today does not look arbitrary.

## Final result
Rahma, plan editor ("Edit days and moves"): day cards stay; when the plan has more than one week, a small heading `Week 1`, `Week 2` (existing string `l10n.weekN(countLabel(n))`, English "Week {n}", UNVERIFIED Arabic: `grep -n '"weekN"' app/lib/l10n/app_ar.arb`) sits above the first day of each week. The footer keeps ONE filled button "Add a day". Under the day cards, above "Start from scratch", one new outlined button "Repeat last week" / "كرري آخر أسبوع" (key `plan-repeat-week`), disabled at 4 weeks or an empty plan. Tap path to build a 4 week programme from a split: pick split (1), Edit days and moves (2), Repeat last week (3), (4), (5) = weeks 2, 3, 4 in 3 taps, then Publish. Tap count to add one more week: 1.
Rahma, the "Share a workout" screen: the day list gets the same `Week n` headings, and one line under the plan name when weeks > 1: "4 weeks" / "4 أسابيع" (Western digits).
Client, Plan screen (`CoachPlanView`): when the plan has weeks, one line at the top of the workout part: `Week 2 of 4` / `الأسبوع 2 من 4`; before the start date `Your plan starts 1 Nov` / `خطتك بتبدأ 1 نوفمبر`; the day cards show only the current week's days (position numbers restart each week). A text button below them "See all weeks" / "شوفي كل الأسابيع" (key `plan-all-weeks`, text variant) toggles all weeks with `Week n` headings.
Client, Home card (`CoachHomeCard`): the title line `Today's workout: Upper` gains a second small line `Week 2 of 4` / `الأسبوع 2 من 4` when weeks > 1. Before the start date the card says `Your plan starts Sat 1 Nov` / `خطتك بتبدأ السبت 1 نوفمبر` and has no Start button.

## Files to edit or create
| path | file action | change |
|---|---|---|
| app/lib/features/train/presentation/plan_editor_view.dart | edit | week headings, Repeat last week |
| app/lib/features/private_coaching/presentation/plans/share_workout_view.dart | edit | week headings in the day list |
| app/lib/features/private_coaching/presentation/client/coach_plan_view.dart | edit | week line, current-week days, See all weeks |
| app/lib/features/private_coaching/presentation/client/coach_home_card.dart | edit | week line, not-started text |
| app/test/features/train/plan_editor_view_test.dart | edit | UNVERIFIED path: `ls app/test/features/train | grep plan_editor` |
| app/test/features/private_coaching/client/client_screens_test.dart | edit | week line tests |

## Steps
1. File `plan_editor_view.dart`. Day cards loop (about line 286): `for (var i = 0; i < plan.days.length; i++) AppCard(...)`. Prefix it so each first day of a week gets a heading. Change the loop to:
```dart
            for (var i = 0; i < plan.days.length; i++) ...[
              if (plan.weekCount > 1 &&
                  (i == 0 || plan.days[i].week != plan.days[i - 1].week))
                Semantics(
                  header: true,
                  child: Text(
                    l10n.weekN(countLabel(plan.days[i].week)),
                    key: ValueKey('plan-week-${plan.days[i].week}'),
                    style: AppText.titleS,
                  ),
                ),
              AppCard(
                ... (the existing card, unchanged)
              ),
            ],
```
(the existing `AppCard(...)` body at lines 287-358 moves inside unchanged). Then before `AppButton(l10n.startFromScratch` (about line 359) insert:
```dart
            AppButton(
              l10n.repeatLastWeek,
              key: const ValueKey('plan-repeat-week'),
              variant: AppButtonVariant.outlined,
              height: 48,
              fontSize: 16,
              onPressed: plan.isBlank || plan.weekCount >= kMaxCoachPlanWeeks
                  ? null
                  : () => _state.save(_plan.withRepeatedLastWeek()),
            ),
```
`kMaxCoachPlanWeeks` comes from `../domain/my_plan.dart` (already imported at line 28). The member's own plan screen also uses this view; to keep it unchanged for her, show the button only for coaches: add a constructor flag `this.allowWeeks = false,` and field `final bool allowWeeks;`, wrap the button in `if (widget.allowWeeks)`, and pass `allowWeeks: true` from `ShareWorkoutView._editDays` (`share_workout_view.dart` line 152, in `PlanEditorView(` add `allowWeeks: true,`). Same flag guards the week headings (`widget.allowWeeks && plan.weekCount > 1`).
2. File `share_workout_view.dart`, day list loop (about line 364-374, `AppListItem(key: ValueKey('workout-day-$i'), ...)`): wrap the same way, adding before an item whose week differs from the previous one a `Text(l10n.weekN(countLabel(plan.days[i].week)), style: AppText.titleS)` when `plan.weekCount > 1`. After the version line (about line 363) add:
```dart
              if (plan.weekCount > 1)
                Text(
                  l10n.nWeeks(countLabel(plan.weekCount)),
                  key: const ValueKey('workout-weeks'),
                  style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
                ),
```
3. File `coach_plan_view.dart`, `_workout` (about line 156). After `final shown = offeredDays(workout, lifeStage);` and the empty branch, compute the current week and filter. Add before `final today = ...` (line 184):
```dart
    final nowDay = (now ?? DateTime.now)();
    final weekNow = currentWeekOf(workout, plan.startsOn, nowDay);
    final started = workout.weekCount <= 1 ||
        plan.startsOn == null ||
        weekNow != null;
    final visible = workout.weekCount > 1 && !_allWeeks && weekNow != null
        ? [for (final d in shown) if (workout.days[d].week == weekNow) d]
        : shown;
```
`CoachPlanView` is a `StatelessWidget` today (UNVERIFIED: `sed -n 60,75p coach_plan_view.dart`). `_allWeeks` needs state: convert it to a `StatefulWidget` only if it is stateless: keep the widget class and add a small private `StatefulBuilder` around the `See all weeks` toggle by storing the bool in a `ValueNotifier<bool>` created in a new `_WeeksToggle` stateful child that receives a builder. If that is more than 20 lines, use this simpler rule instead and report it: always show the current week only, plus the button "See all weeks" pushing a second route `CoachPlanView(plan: plan, ..., allWeeks: true)` (add `this.allWeeks = false` to the constructor). Use the simpler rule. Then `visible` is `allWeeks || weekNow == null ? shown : current week days`. The loop `for (final d in shown) _dayCard(...)` (about line 186-196) becomes `for (final d in visible)` with `position: visible.indexOf(d)`, and a `Week n` heading above the first day of a week when `allWeeks`. The `today` argument gets the start date: `todaysWorkoutDay(workout, doneThisWeek, lifeStage, startsOn: plan.startsOn, now: nowDay)`. Insert the lines at the very top of the returned list:
```dart
      if (workout.weekCount > 1)
        Text(
          !started
              ? l10n.startsOnDate(dateText(plan.startsOn!))
              : l10n.weekNOfTotalStarts(
                  countLabel(weekNow ?? 1),
                  countLabel(workout.weekCount),
                ),
          key: const ValueKey('plan-week-line'),
          style: AppText.titleS,
        ),
```
Two pieces of UNVERIFIED code here: the widget's `now` field name (line 101 is `final DateTime Function()? now;`, so `now` is right) and the date formatter. The coach side uses `dateText(l10n, DateTime?)` from `desk_text.dart` (see `client_detail_view.dart` line 21 and usage `dateText(l10n, sub.startsAt)`). For the client side use the same function: `dateText(l10n, plan.startsOn)`. Verify the output form: `grep -n "String dateText" -A8 app/lib/features/private_coaching/presentation/desk/desk_text.dart`. If it prints "1 Nov 2026" without a weekday, the strings below still read well; do not build a new formatter.
In the snippet above use `l10n.weekNOfTotal(countLabel(weekNow ?? 1), countLabel(workout.weekCount))` for the started case and `l10n.yourPlanStartsOnDate(dateText(l10n, plan.startsOn))` for the not started case (the names `weekNOfTotalStarts` and `startsOnDate` in the snippet are wrong; use these two).
4. File `coach_home_card.dart`. In `build` after `final day = ...` (line 47-49) pass the start date: `todaysWorkoutDay(plan, doneThisWeek, lifeStage, startsOn: workout?.startsOn)`. Insert under the `coach-home-workout` Text (after line 63):
```dart
        if (plan != null && plan.weekCount > 1 && day != null)
          Text(
            l10n.weekNOfTotal(
              countLabel(plan.days[day].week),
              countLabel(plan.weekCount),
            ),
            key: const ValueKey('coach-home-week'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
```
Add `import '../../../../domain/format/number_label.dart';` (the `countLabel` source, see `coach_day_editor_view.dart` line 14). Before the start date `day == null`, so the existing `yourCoachHasNotSetAPlan` text would show; replace it when `workout?.startsOn` is in the future: in the `Text(day == null ? ... )` expression use
```dart
          day == null
              ? (workout?.startsOn != null && plan != null && plan.weekCount > 1
                    ? l10n.yourPlanStartsOnDate(dateText(l10n, workout!.startsOn))
                    : l10n.yourCoachHasNotSetAPlan)
              : l10n.todaysWorkoutName(plan!.days[day].session.title(lang)),
```
Note `app_router.dart` ~8740 returns null for the card when `todaysWorkoutDay == null` (D11: own Today card shows). That is the right behaviour before the start date; the text above only shows if the card is built in a test. Leave the router alone.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| repeatLastWeek | Repeat last week | كرري آخر أسبوع |
| nWeeks | {n} weeks | {n} أسابيع |
| weekNOfTotal | Week {n} of {total} | الأسبوع {n} من {total} |
| yourPlanStartsOnDate | Your plan starts {date} | خطتك بتبدأ {date} |
| seeAllWeeks | See all weeks | شوفي كل الأسابيع |
| (existing) weekN | Week {n} | verify the Arabic reads "الأسبوع {n}" |
Parameterised: `{n}` String example "2"; `{total}` String "4"; `{date}` String "1 Nov". In the JSON use `"parameterised": {"{n} weeks": {"description": "Weeks in a plan", "placeholders": {"n": {"type": "String", "example": "4"}}}, "Week {n} of {total}": {...n,total}, "Your plan starts {date}": {...date}}`. Command: `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03f.json && flutter gen-l10n`. Use the printed getter names. Arabic for 3 or more weeks: "أسابيع" is right for 3 to 10; for exactly 2 the app's plural helpers are not needed because the line only shows when weeks is 2 to 4 and "2 أسابيع" is understood.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| plan_editor_view_test (path above) | `repeat last week adds a Week 2 heading` | `PlanEditorView(allowWeeks: true, state: CoachPlanEditState(3 day plan), ...)`; tap `plan-repeat-week`; assert `plan-week-1` and `plan-week-2` exist and `plan-day-5` exists. With `allowWeeks: false` the button does not exist. |
| same | `repeat is off at four weeks` | Press it 3 times; the 4th state has `weekCount == 4`; the button's `onPressed` is null. |
| client_screens_test.dart | `client plan shows the current week only` | `CoachPlan` with 2 weeks, `startsOn` Monday, `now` = Monday + 8 days: `plan-week-line` text equals `Week 2 of 4`-style string for 2 weeks (`Week 2 of 2`), only week-2 day cards exist (`plan-workout-day-3`, not `-0`). `plan-all-weeks` tap opens all days. |
| same | `client home card before the start` | `startsOn` = tomorrow, 2 weeks: `coach-home-start` absent. |
Run: `cd app && flutter test test/features/train test/features/private_coaching/client`. Also run `flutter test test/qa/screen_budget_test.dart` (the plan editor is a counted screen if listed; UNVERIFIED: `grep -n "PlanEditor" app/test/qa/screen_budget_test.dart`). If the plan editor now exceeds 5 controls above the fold, move "Repeat last week" into the `Add a day` sheet as a list row instead and update the keys.

## Verify
Analyze clean; the tests print `All tests passed!`; Arabic pump of the plan editor shows no overflow.

## Do not
Do not change the member's own plan screen (`allowWeeks` false there). Do not add a second filled button. No em dashes. No commit.

## Done checklist
- [ ] Editor weeks and button  - [ ] Share screen headings  - [ ] Client plan week line  - [ ] Home card line  - [ ] Strings EN/AR  - [ ] Tests

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw. Move to WO-03g.
