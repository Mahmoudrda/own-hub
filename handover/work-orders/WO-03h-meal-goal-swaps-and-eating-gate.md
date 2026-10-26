# WO-03h: A meal plan can carry Rahma's kcal and protein target and approved swaps, and the server holds both back for flagged clients
Depends on: WO-03d (for the merged `plans.py`; no code dependency). The eating-history flag itself is made by the intake work order of item C9 (another author). This order reads it as `intake.health.eatingHistory == true` and does nothing special when it is absent.
Size: M
Reads first: `functions/coaching/plans.py` lines 36-60, 195-250 and 280-345; `app/lib/features/private_coaching/domain/coach_plan.dart` lines 14-200; `app/lib/features/private_coaching/presentation/plans/coach_plan_logic.dart` lines 366-420; `functions/coaching/errors.py` lines 84-108; `app/lib/features/private_coaching/domain/coaching_failure.dart` (all)

## Why
Rahma sets "1,600 kcal and 110 g protein a day" for a client, and offers two or three approved swaps per dish so the client can change a meal in two taps without asking her. Rules from the research and the plan (C7, C9, owner decision 2): no calorie or macro target for a client whose eating-history answer is flagged; Rahma reviews that client herself. Today the server rejects any nutrition key in a meal body on purpose (a figure must never disagree with the food tables). A TARGET is a number she chooses, not a table figure, so it gets its own key that cannot be mistaken for one: `goal`. Dish figures stay computed on the phone.

## Final result
- Meal body JSON gets an optional `goal`: `{"kcalPerDay": 1600, "proteinGPerDay": 110}` (both required inside it; kcal 1200 to 4000, protein 30 to 250). The 1200 floor is the plan's proposed default (owner decision 1 in `PRODUCTION-RELEASE-PLAN.md` section 3, still open: change `GOAL_KCAL` in one place if she decides otherwise).
- A recipe item gets an optional `swaps`: up to 3 other recipe ids from the shipped recipe list.
- Publishing a meal plan with a `goal` to a client whose `intake.health.eatingHistory` is true is refused with the new reason `eating_history_hold`. A plan without a goal is still allowed (she may still send a plain menu; it shows no numbers as targets).
- Phone model: `MealGoal`, `MealPlanBody.goal`, `MealItem.swaps`, and the pure function `goalBlockedFor(Intake?)`.

## Files to edit or create
| path | file action | change |
|---|---|---|
| functions/coaching/errors.py | edit | `EATING_HISTORY_HOLD` |
| functions/coaching/plans.py | edit | allow `goal`, `swaps`; hold check |
| app/lib/features/private_coaching/domain/coach_plan.dart | edit | `MealGoal`, `swaps`, parse and JSON |
| app/lib/features/private_coaching/domain/coaching_failure.dart | edit | refusal value |
| app/lib/features/private_coaching/presentation/plans/coach_plan_logic.dart | edit | keep `goal` through edits |
| app/lib/features/private_coaching/domain/subscription.dart | edit | `Intake.eatingHistoryFlag` |
| functions/tests/test_coaching_plans.py | edit | 5 tests |
| app/test/features/private_coaching/models_test.dart | edit | 3 tests |

## Steps
1. File `errors.py`, after `PLAN_TOO_LARGE = "plan_too_large"` (line 88) add:
```python
EATING_HISTORY_HOLD = "eating_history_hold"
```
2. File `plans.py`. Constants after `GRAMS = (1, 2000)` (about line 49):
```python
GOAL_KCAL = (1200, 4000)
GOAL_PROTEIN_G = (30, 250)
MAX_SWAPS = 3
```
In `_check_item`, recipe branch (about line 205-208) change the allowed keys to `{"kind", "recipeId", "servings", "note", "swaps"}` and after the `servings` check add:
```python
        swaps = item.get("swaps", [])
        _check(isinstance(swaps, list) and len(swaps) <= MAX_SWAPS)
        _check(all(isinstance(s, str) and s in ids["recipes"] and s != item["recipeId"] for s in swaps))
        _check(len(set(swaps)) == len(swaps))
```
In `_check_meal` (about line 231) change `_keys_within(body, {"days"})` to `_keys_within(body, {"days", "goal"})` and after the `days` loop add:
```python
    goal = body.get("goal")
    if goal is not None:
        _keys_within(goal, {"kcalPerDay", "proteinGPerDay"})
        _check(_is_int(goal.get("kcalPerDay")) and GOAL_KCAL[0] <= goal["kcalPerDay"] <= GOAL_KCAL[1])
        _check(_is_int(goal.get("proteinGPerDay")) and GOAL_PROTEIN_G[0] <= goal["proteinGPerDay"] <= GOAL_PROTEIN_G[1])
```
The existing `_has_nutrition_key` test runs on the whole body: `goal`, `kcalPerDay` and `proteinGPerDay` are not in `NUTRITION_KEYS` (compared lowercased and whole), so it passes; do not add them to that set and do not remove `kcal` from it.
In `publish`'s `txn`, after the `if subscriptions.blocked_either(...)` block (about line 295) add:
```python
        if kind == "meal" and body.get("goal") is not None:
            health = (sub.get("intake") or {}).get("health") or {}
            if isinstance(health, dict) and health.get("eatingHistory") is True:
                raise common.refuse(errors.PRECONDITION, errors.EATING_HISTORY_HOLD)
```
UNVERIFIED: how `intake_of` in `subscriptions.py` (line 43) stores `health` (a dict keyed by question id, per `Intake.fromMap` on the phone which accepts both a map and a list). Verify: `sed -n 36,75p functions/coaching/subscriptions.py`. If it stores a list in the contract order, read the key through `common.ENUMS["healthQuestions"]`; the C9 order adds `eatingHistory` to that list. If C9 is not merged yet the key is never true, the hold never fires, and the test below sets it by hand.
3. File `coach_plan.dart`. Add the class after `MealPlanBody`'s imports (before `class MealItem`):
```dart
/// What Rahma wants a client to eat on an ordinary day. Her number, not a food
/// figure; the dish figures still come from the food tables.
class MealGoal {
  const MealGoal({required this.kcalPerDay, required this.proteinGPerDay});

  static const int kcalMin = 1200;
  static const int kcalMax = 4000;
  static const int proteinMin = 30;
  static const int proteinMax = 250;

  final int kcalPerDay;
  final int proteinGPerDay;

  static MealGoal? tryParse(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final k = map['kcalPerDay'];
    final p = map['proteinGPerDay'];
    if (k is! int || p is! int) return null;
    final g = MealGoal(kcalPerDay: k, proteinGPerDay: p);
    return g.isValid ? g : null;
  }

  bool get isValid =>
      kcalPerDay >= kcalMin &&
      kcalPerDay <= kcalMax &&
      proteinGPerDay >= proteinMin &&
      proteinGPerDay <= proteinMax;

  Json toJson() => <String, Object?>{
    'kcalPerDay': kcalPerDay,
    'proteinGPerDay': proteinGPerDay,
  };
}
```
`MealItem`: constructor `_()` add `this.swaps = const <String>[],`; field `final List<String> swaps;` (doc: `/// Recipe ids she approved as swaps, at most 3.`); `MealItem.recipe(String recipeId, double servings, {String? note, List<String> swaps = const <String>[]})` passes `swaps: swaps`. In `fromMap` recipe case: `swaps: readStrings(map['swaps']).take(3).toList()` (`readStrings` is used in subscription.dart for `allergies`; it is in `parse.dart`, already imported here). Because `MealItem.recipe(...)` is `const` and the call with `List` default is const-able, keep the default `const <String>[]`. `toJson` recipe case: add `if (swaps.isNotEmpty) 'swaps': swaps,` inside the map for `MealItemKind.recipe`. `isValid` recipe case: add `&& swaps.length <= 3`.
`MealPlanBody`: constructor `const MealPlanBody({this.days = const <MealDay>[], this.goal});` field `final MealGoal? goal;`; `tryParse` returns `MealPlanBody(days: ..., goal: MealGoal.tryParse(map['goal']))`; `toJson` adds `if (goal != null) 'goal': goal!.toJson(),`; `isValid` adds `&& (goal == null || goal!.isValid)`.
4. File `coach_plan_logic.dart`: `mealPlanWithDays` (about line 383-394) returns `MealPlanBody(days: [...])`; add `goal: body.goal,`. `_replaceDay` (about line 435-447) returns `MealPlanBody(days: days)`; make it `MealPlanBody(days: days, goal: body.goal)`. Add this function at the end of the meal section:
```dart
/// [body] with the target set, or removed with null.
MealPlanBody mealPlanWithGoal(MealPlanBody body, MealGoal? goal) =>
    MealPlanBody(days: body.days, goal: goal);

/// [body] with [item]'s swaps at day/slot/index replaced.
MealPlanBody mealPlanWithSwaps(
  MealPlanBody body,
  int day,
  String slot,
  int index,
  List<String> swaps,
) {
  if (day < 0 || day >= body.days.length) return body;
  final items = [...body.days[day].itemsIn(slot)];
  if (index < 0 || index >= items.length) return body;
  final it = items[index];
  if (it.kind != MealItemKind.recipe) return body;
  items[index] = MealItem.recipe(
    it.recipeId!,
    it.servings!,
    note: it.note,
    swaps: [
      for (final s in swaps)
        if (s != it.recipeId) s,
    ].toSet().take(3).toList(),
  );
  return _replaceDay(body, day, items, slot);
}
```
5. File `subscription.dart`, class `Intake`, add near `needsDoctorAck` (about line 51):
```dart
  /// She answered yes to the eating-history question. Rahma reviews her
  /// herself; the app writes no calorie or macro target for her.
  bool get eatingHistoryFlag => health['eatingHistory'] == true;
```
UNVERIFIED: `health` is the `Map<String, bool>` field (seen in `copyWith` and `fromMap`). The key `eatingHistory` is added to `CoachingEnums.healthQuestions` by the C9 order; if you are doing this before C9, the getter simply returns false.
6. File `coaching_failure.dart`: add the refusal. UNVERIFIED how the enum maps server reasons; read the file, find the line mapping `plan_invalid` to `CoachingRefusal.planInvalid` and add `eating_history_hold` -> `CoachingRefusal.eatingHistoryHold` the same way. Then in `coach_text.dart` (`coachFailureText`, `app/lib/features/private_coaching/presentation/coach/coach_text.dart`) add the case returning `l10n.eatingHistoryHoldNote`. Strings below.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| eatingHistoryHoldNote | This client's answers on eating mean you review her first. A plan with calorie or protein targets cannot be sent. | إجابات العميلة دي عن الأكل معناها إنك تراجعيها بنفسك الأول. مينفعش تتبعت خطة فيها سعرات أو بروتين مطلوب. |
Command: `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03h.json && flutter gen-l10n`.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| test_coaching_plans.py | `test_meal_goal_is_accepted` | `meal()` body plus `"goal": {"kcalPerDay": 1600, "proteinGPerDay": 110}`; `publish(db, req("meal", body))` succeeds; stored body has the goal. |
| same | `test_meal_goal_bounds_and_shape` | kcal 1199, 4001, 1600.5, "1600"; protein 29, 251; an extra key `"carbs": 1`; `goal` as a list: each `refused(..., errors.PLAN_INVALID)`. |
| same | `test_swaps_ids_limits` | A recipe item with 3 valid other ids is ok (ids from `IDS["recipes"]`, read the dict at line 14); 4 swaps, an unknown id, the dish itself, a duplicate: refused. |
| same | `test_goal_is_held_for_an_eating_history_flag` | Put `intake = {"health": {"eatingHistory": True}}` on the subscription doc (copy how `sub1` is created in this file's fixture); publish a meal with goal -> `refused(db, data, errors.EATING_HISTORY_HOLD)`; the same plan without a goal succeeds; flag false with goal succeeds. |
| same | `test_nutrition_keys_are_still_refused` | Body with `"days"[0]["slots"]["lunch"][0]["kcal"] = 5` still `PLAN_INVALID` (regression: the new keys did not open the door). |
| models_test.dart | `MealGoal` and swaps round trip | `MealPlanBody.tryParse` of a body with goal and swaps -> `goal.kcalPerDay == 1600`, item `swaps.length == 2`, `toJson` equal to input; a goal with kcal 100 parses to `goal == null`. |
| models_test.dart | `mealPlanWithDays keeps the goal` | Body with goal, `mealPlanWithDays(body, 3, ...)` -> `goal` still set; `mealPlanWithItem` too. |
| models_test.dart | `Intake.eatingHistoryFlag` | `Intake.fromMap({... 'health': {'eatingHistory': true}})`. UNVERIFIED that `fromMap` keeps unknown keys: it only copies keys in `CoachingEnums.healthQuestions` (subscription.dart lines 78-93), so this test needs C9's list change; write it, and if it fails because C9 is not merged, skip with a comment naming that order. |
Run: `cd functions && .venv/bin/python -m pytest tests/test_coaching_plans.py -q`; `cd app && flutter test test/features/private_coaching/models_test.dart test/features/private_coaching/plans`.

## Verify
Both green; `flutter analyze lib/features/private_coaching` clean.

## Do not
Do not add `kcalPerDay` or `proteinGPerDay` to `NUTRITION_KEYS`. Do not lower the 1200 floor in code. Do not make the server compute or store dish figures. Never relax the hold for any reason. No em dashes. No commit.

## Done checklist
- [ ] Server accepts goal and swaps  - [ ] Hold works  - [ ] Phone model  - [ ] Refusal text EN/AR  - [ ] Tests

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw. Move to WO-03i only if the server tests pass; otherwise stop.
