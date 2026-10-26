# WO-03e: Multi-week programmes: data, server limits, and which day is "today"
Depends on: WO-03d
Size: L
Reads first: `app/lib/features/train/domain/my_plan.dart` lines 30-100, 190-300, 335-365; `app/lib/features/private_coaching/presentation/client/coach_today.dart` (26 lines); `functions/coaching/plans.py` lines 36-60, 135-190; `contracts/coaching_contract.json` (search `planMaxDays`); `app/test/contracts/coaching_contract_test.dart`

## Why
Finding from the code: a coach plan today is one week, and Today cannot follow more. Three facts: `kMaxPlanDays = 7` and `CoachingLimits.planMaxDays = 7` cap a plan at 7 days (client parse `MyPlan.tryParse` takes 7; the server refuses more); `todaysWorkoutDay` is `planDayForSlot(plan, doneThisWeek, stage)`, a rotation by the sessions finished THIS calendar week, so it never moves past the first week; and one week of Rahma's split is about 17 to 19 KB of JSON against `planBodyMaxBytes = 60000`. So "Week 1, Week 2" needs a week number on each day, higher limits, and a Today rule that uses the start date. Rule decided here (owner can change): the week of today is `1 + floor(days since startsOn / 7)` in Cairo, and after the last week the last week repeats. Before the start date Today shows nothing from the coach (the member's own Today card shows, as already happens when a coach plan has no day for today).

## Final result
- Limits (contract, both sides): `planMaxWeeks = 4`; `planBodyMaxBytes = 120000`; a workout holds up to 7 days per week and 4 weeks. A meal plan is still at most `planMaxDays = 7` days.
- Each day has `week` (1 to 4, default 1). Weeks are numbered without gaps, each has 1 to 7 days.
- `todaysWorkoutDay(plan, done, stage, {startsOn, now})` picks, among the days of the current week that suit her stage, day number `done % count`. With one week or no `startsOn` it behaves as today (no change for existing plans).
- No screen in this order (WO-03f draws the weeks).

## Files to edit or create
| path | file action | change |
|---|---|---|
| contracts/coaching_contract.json | edit | `planMaxWeeks`, `planBodyMaxBytes` |
| functions/coaching/coaching_contract.json | edit | same copy |
| app/lib/features/private_coaching/domain/coaching_contract.dart | edit | const, `all` map |
| app/lib/features/train/domain/my_plan.dart | edit | `week` on `MyPlanDay`, caps, `weekCount`, week-aware copies |
| app/lib/features/private_coaching/presentation/plans/coach_plan_logic.dart | edit | `_withDay`, `stampSafetyTags` keep `week`; size check |
| functions/coaching/plans.py | edit | day key `week`, per-week checks |
| app/lib/features/private_coaching/presentation/client/coach_today.dart | edit | week-aware `todaysWorkoutDay` |
| tests (3 files, see below) | edit | |

## Steps
1. Both contract JSON files: find `"planBodyMaxBytes": 60000` and replace with `"planBodyMaxBytes": 120000,` followed on the next line by `"planMaxWeeks": 4` (keep valid commas; the two files must stay identical in `limits`). `coaching_contract.dart`: change line 45 to `static const int planBodyMaxBytes = 120000;`, add `static const int planMaxWeeks = 4;` after line 44, and in the `all` map (about line 112) add `'planMaxWeeks': planMaxWeeks,` after the `'planMaxDays'` entry. UNVERIFIED whether the parity test pins 60000: `grep -n "60000" app/test/contracts/coaching_contract_test.dart app/test/features/private_coaching/*.dart functions/tests/*.py`; update each hit to 120000.
2. File `my_plan.dart`. (a) Constants after line 33: `const int kMaxCoachPlanWeeks = 4;`. (b) `MyPlanDay` (about line 46): add constructor parameter `this.week = 1,` and `final int week;` with doc `/// 1 to 4. A plan of one week has all its days in week 1.`; in `toJson` add `if (week > 1) 'week': week,`; in `tryParse` add `week: _cleanWeek(raw['week']),` to the returned `MyPlanDay(`. Add the helper below `_cleanKg`:
```dart
int _cleanWeek(Object? v) =>
    v is int ? v.clamp(1, kMaxCoachPlanWeeks) : 1;
```
(c) In `MyPlan` add:
```dart
  /// The highest week any day is in (1 for a plan of one week).
  int get weekCount =>
      days.fold<int>(1, (m, d) => d.week > m ? d.week : m);

  List<int> daysOfWeek(int week) => [
    for (var i = 0; i < days.length; i++)
      if (days[i].week == week) i,
  ];

  /// Whole plan copied once more as the next week: every day of the last week
  /// gets a new id and week + 1. Same plan when 4 weeks are already there.
  MyPlan withRepeatedLastWeek() {
    if (weekCount >= kMaxCoachPlanWeeks) return this;
    final last = daysOfWeek(weekCount);
    if (last.isEmpty) return this;
    final next = [...days];
    var plan = this;
    for (final i in last) {
      final id = plan._freshId();
      final s = days[i].session;
      final copy = MyPlanDay(
        session: AuthoredSession(
          sessionId: id,
          titleEn: s.titleEn,
          titleAr: s.titleAr,
          minutes: s.minutes,
          lifeStages: s.lifeStages,
          moves: s.moves,
        ),
        sourceId: days[i].sourceId,
        targetKg: days[i].targetKg,
        week: weekCount + 1,
      );
      next.add(copy);
      plan = MyPlan(days: List.unmodifiable(next), sourceProgrammeId: sourceProgrammeId, name: name, revision: revision);
    }
    return _with(next);
  }
```
(d) `isFull` (line 247-ish: `bool get isFull => days.length >= kMaxPlanDays;`) becomes per week so a week 2 can hold 7 days too:
```dart
  bool get isFull => daysOfWeek(weekCount).length >= kMaxPlanDays;
```
(e) `tryParse`: change `.take(kMaxPlanDays)` (about line 357) to `.take(kMaxPlanDays * kMaxCoachPlanWeeks)`. (f) Keep the week when a day is rebuilt: in `withMoves` (about line 217) the `next[i] = _dayFromMoves(...)` result must keep the week: wrap as `next[i] = _sameWeek(_dayFromMoves(...), day.week);` and in `withDayFrom` (about line 318) add `week: days[i].week,` to its `MyPlanDay(`. In `withCopyOf` (about line 262) add `week: weekCount,` to the `MyPlanDay(` it returns so a copy lands in the last week; in `withNewDay` wrap the new day: `_sameWeek(_dayFromMoves(...), weekCount)`. Add the helper:
```dart
MyPlanDay _sameWeek(MyPlanDay d, int week) => MyPlanDay(
  session: d.session,
  sourceId: d.sourceId,
  targetKg: d.targetKg,
  week: week,
);
```
3. File `coach_plan_logic.dart`: in `_withDay` (about line 147-158) the `MyPlanDay(` gets `week: old.week,`; in `stampSafetyTags` (about line 287-298) the `MyPlanDay(` gets `week: day.week,`.
4. File `plans.py`. `_DAY_KEYS = {"session", "sourceId", "kg", "week"}`. Replace `_check_workout`'s days block (about line 169-175):
```python
    days = body.get("days")
    max_days = LIMITS["planMaxDays"] * LIMITS["planMaxWeeks"]
    _check(isinstance(days, list) and 1 <= len(days) <= max_days)
    seen: set = set()
    for day in days:
        _check_day(day, ids["exercises"], seen)
    weeks = [d.get("week", 1) for d in days]
    _check(all(_is_int(w) and 1 <= w <= LIMITS["planMaxWeeks"] for w in weeks))
    # No gaps, and at most a week's worth of days in each.
    _check(set(weeks) == set(range(1, max(weeks) + 1)))
    _check(all(weeks.count(w) <= LIMITS["planMaxDays"] for w in set(weeks)))
```
`LIMITS` is the contract's `limits` (`common.LIMITS`, line 48 of common.py), so step 1 makes `planMaxWeeks` available.
5. File `coach_today.dart`. Replace the `todaysWorkoutDay` function:
```dart
/// The day of the workout [plan] that comes next for a woman who has done
/// [doneThisWeek] sessions, or null when no day suits [stage]. With several
/// weeks and a [startsOn] date, only the days of the current week count, and
/// the last week repeats once the weeks run out. Before [startsOn] there is
/// no day.
int? todaysWorkoutDay(
  MyPlan plan,
  int doneThisWeek,
  LifeStage? stage, {
  DateTime? startsOn,
  DateTime? now,
}) {
  if (plan.weekCount <= 1 || startsOn == null) {
    return planDayForSlot(plan, doneThisWeek, stage);
  }
  final a = DateTime.parse(cairoDay(startsOn));
  final b = DateTime.parse(cairoDay(now ?? DateTime.now()));
  final gone = b.difference(a).inDays;
  if (gone < 0) return null;
  final week = (1 + gone ~/ 7).clamp(1, plan.weekCount);
  final offered = [
    for (final i in plan.daysOfWeek(week))
      if (suits(plan.days[i].session, stage)) i,
  ];
  if (offered.isEmpty) return null;
  return offered[doneThisWeek % offered.length];
}

/// Which week of [plan] is today (1 based), or null before the start.
int? currentWeekOf(MyPlan plan, DateTime? startsOn, DateTime now) {
  if (plan.weekCount <= 1 || startsOn == null) return null;
  final gone = DateTime.parse(cairoDay(now))
      .difference(DateTime.parse(cairoDay(startsOn)))
      .inDays;
  return gone < 0 ? null : (1 + gone ~/ 7).clamp(1, plan.weekCount);
}
```
Add `import '../../../train/domain/workout_library.dart' show suits;`. UNVERIFIED: `cairoDay(DateTime)` returns `YYYY-MM-DD` (used the same way in `todaysMealDay` in this file, lines 24-25, so yes). Note `startsOn` is date-only local midnight; `cairoDay` on it may shift a day on a phone far from Cairo, so pass it through `DateTime.utc(y,m,d,12)`: in `CoachPlan.fromMap` (WO-03d) change `_dateOnly` to return `DateTime(d.year, d.month, d.day, 12)` (noon). Do that edit now in `coach_plan.dart` if WO-03d is done.
6. Callers: `grep -n "todaysWorkoutDay" -r app/lib` shows `coach_plan_view.dart:184`, `coach_home_card.dart:49`, `app_router.dart:8745` (and an import at 435). At each add `startsOn: <the CoachPlan>.startsOn`: `coach_plan_view.dart` has the plan as `plan` on the widget (UNVERIFIED variable: read lines 150-190), `coach_home_card.dart` uses `workout?.startsOn` (the field `workout` is the `CoachPlan`), `app_router.dart` ~8745 uses `workout?.startsOn` (the local `workout` is `activeCoachWorkoutPlan()`, a `CoachPlan?`).

## Strings to add
None.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| app/test/features/private_coaching/client/client_screens_test.dart (or a new `coach_today_test.dart` beside it) | `two weeks follow the start date` | Plan of 6 days: week 1 = days 0..2, week 2 = days 3..5 (build with `MyPlanDay(week: 2)`). `startsOn` = Cairo Monday; `now` = Monday: `todaysWorkoutDay(plan, 0, null, startsOn:, now:) == 0`; with `done 1` -> 1; `now` = Monday + 8 days, `done 0` -> 3; `now` = + 30 days (past the last week) -> still week 2 (3). Before start -> null. Plan with `weekCount == 1` ignores `startsOn`. |
| app/test/features/train/my_plan_test.dart (UNVERIFIED path) | `repeat last week` | 3-day plan; `withRepeatedLastWeek()` -> 6 days, days 3..5 have `week == 2`, titles equal, all sessionIds unique; repeat 3 more times -> 12 days weeks 1..4; a fifth call returns the same plan (`identical`). `isFull` is per week. `toJson`/`tryParse` round trip keeps `week`. |
| functions/tests/test_coaching_plans.py | `test_weeks_must_have_no_gaps_and_stay_within_limits` | `workout(days=14)` (the helper builds N days; set `week` 1 on the first 7 and 2 on the rest): accepted. Weeks {1,3}: refused `PLAN_INVALID`. Week 5: refused. 8 days all week 1: refused. 29 days: refused. |
| app/test/contracts/coaching_contract_test.dart | existing parity test | passes with the new `planMaxWeeks` in both JSON files and the Dart map. |
Run: `cd app && flutter test test/contracts test/features/private_coaching test/features/train/my_plan_test.dart` and `cd functions && .venv/bin/python -m pytest tests/test_coaching_plans.py tests -q -k "plan or contract"`.

## Verify
Analyze clean; all four commands green; `diff <(python3 -c "import json;print(json.load(open('contracts/coaching_contract.json'))['limits'])") <(python3 -c "import json;print(json.load(open('functions/coaching/coaching_contract.json'))['limits'])")` prints nothing.

## Do not
Do not change the 7-day cap for the member's own plan on write (`isFull` is the only gate; a member's plan has one week). Do not raise `planMaxDays` (the meal plan uses it). Do not change the Firestore rules. No commit.

## Done checklist
- [ ] Limits in 3 places  - [ ] `week` kept through every rebuild  - [ ] Server checks  - [ ] Today follows weeks  - [ ] Tests pass

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw. WO-03g (assign to many) does not need this order after WO-03d; move to it.
