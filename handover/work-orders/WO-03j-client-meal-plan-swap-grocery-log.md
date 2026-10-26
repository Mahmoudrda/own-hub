# WO-03j: What the client sees of Rahma's meal plan: target, swap in 2 taps, grocery list in 1, log in 1
Depends on: WO-03h
Size: L
Reads first: `app/lib/features/private_coaching/presentation/client/from_your_coach_section.dart` (88 lines); `app/lib/features/private_coaching/presentation/client/coach_meal_row.dart` lines 100-203; `app/lib/features/private_coaching/presentation/client/coach_plan_view.dart` lines 286-345; `app/lib/routing/coaching_wiring.dart` lines 440-520 (`logCoachMeal`); `app/lib/routing/app_router.dart` lines 8780-8815 (`_coachMealSection`)

## Why
Rahma's meal plan must live natively in Eat for her client. The card "Today's meals from your coach" already exists (`FromYourCoachSection`, built by `_coachMealSection`, shown in Eat at `app_router.dart` line 6367), and a row already logs in ONE tap (the non-compact `CoachMealRow` has a "Log this" button, key `<prefix>-log`, which calls `logCoachMeal` with the allergy guard and undo). Verified, nothing to build for logging except a test that locks the tap count. Missing: the target line, a swap, and a grocery list.

## Final result
Eat tab, card "Today's meals from your coach" (title unchanged), top to bottom:
1. NEW, only when the plan has a `goal`: `Your coach's target: 1600 calories and 110 g protein` / `هدف مدربتك: 1600 سعر و110 جم بروتين` (key `coach-goal-line`), and under it, when the day has figures: the planned total in the existing `dayNutritionLine` format (key `coach-planned-line`).
2. Slot headings and dish rows as today. Each recipe row that has `swaps` gets a text button `Swap` / `بدّلي` (key `coach-meal-<slot>-<i>-swap`) beside `Log this`.
3. NEW at the bottom: text button `Grocery list` / `قايمة المشتريات` (key `coach-grocery`).
Swap (2 taps): Swap (1) opens a sheet `Change to` / `غيّريها لـ` with the planned dish first (marked, key `swap-keep`) and each approved swap as a list row (`swap-choice-<recipeId>`); tapping a row (2) closes the sheet and the card now shows that dish with its calories; Log this then logs the swapped dish. A swap lasts for that day slot of that plan on this phone until she changes it back. Calories of the swapped dish come from the existing tables; nothing is sent to the coach.
Grocery list (1 tap from Eat, 2 from the plan screen): a full screen `Grocery list` / `قايمة المشتريات` with the line `For the whole plan, as the dishes are written` / `للخطة كلها، زي ما الأكلات مكتوبة`, then one row per item, name left and amount right (`Chicken breast` `450 g`), each row a checkbox she ticks while shopping (ticks live only while the screen is open). Empty plan: `Nothing to buy yet.` / `مفيش حاجة تتشرى لسه.` No filled button; `Back` in the top bar.
Plan screen (opened from the card): at the top of the meal part the same target line; at the bottom the same `Grocery list` text button.
Log in one tap: Log this (1). If the dish has an allergen she avoids, the existing guard shows its question first (unchanged).

## Files to edit or create
| path | file action | change |
|---|---|---|
| app/lib/app_state/coach_meal_swaps.dart | create | in-memory swap choices |
| app/lib/features/private_coaching/presentation/client/grocery_list.dart | create | pure `groceryFor` |
| app/lib/features/private_coaching/presentation/client/grocery_list_view.dart | create | the screen |
| app/lib/features/private_coaching/presentation/client/from_your_coach_section.dart | edit | goal line, swap, grocery button |
| app/lib/features/private_coaching/presentation/client/coach_meal_row.dart | edit | `onSwap` button |
| app/lib/features/private_coaching/presentation/client/coach_plan_view.dart | edit | goal line, grocery button |
| app/lib/routing/app_router.dart | edit | pass the swap and grocery callbacks |
| app/test/features/private_coaching/client/client_screens_test.dart | edit | 6 tests |

## Steps
1. Create `app/lib/app_state/coach_meal_swaps.dart` (modelled on `coach_client_notes.dart`, same `AppChanges.bump()` pattern):
```dart
/// The dish a client swapped to, per plan, day, slot and place. On this phone,
/// in memory: the plan on the server is never changed by a swap.
library;

import 'app_changes.dart';

class CoachMealSwaps {
  CoachMealSwaps._();

  static final CoachMealSwaps instance = CoachMealSwaps._();

  final Map<String, String> _chosen = <String, String>{};

  String _key(String planId, int day, String slot, int index) =>
      '$planId|$day|$slot|$index';

  /// The recipe id she chose, or null for the planned dish.
  String? chosen(String planId, int day, String slot, int index) =>
      _chosen[_key(planId, day, slot, index)];

  /// Null puts the planned dish back.
  void choose(String planId, int day, String slot, int index, String? recipeId) {
    final k = _key(planId, day, slot, index);
    if (recipeId == null) {
      if (_chosen.remove(k) == null) return;
    } else {
      if (_chosen[k] == recipeId) return;
      _chosen[k] = recipeId;
    }
    AppChanges.bump();
  }
}
```
Limit to report: a swap is forgotten when the app restarts. Follow-up (not in this order): persist with `shared_preferences` (a dependency, `pubspec.yaml` line 65).
2. Create `grocery_list.dart`:
```dart
import '../../../eat/domain/recipe.dart';
import '../../domain/coach_plan.dart';
import '../plans/coach_plan_logic.dart' show MealCatalog;

class GroceryLine {
  const GroceryLine(this.name, this.grams);
  final String name;

  /// 0 when the book gives no weight: the line is the book's own words.
  final int grams;
}

/// Everything to buy for [meal], dishes as written. Weighed ingredients with a
/// known food are added up by food; the rest are listed by their own words.
List<GroceryLine> groceryFor(
  MealPlanBody meal,
  MealCatalog catalog,
  String language,
) {
  final grams = <String, double>{};
  final names = <String, String>{};
  final words = <String>{};
  void addFood(String id, double g) {
    final f = catalog.food(id);
    names[id] = f == null || f.names.isEmpty ? id : f.names.first;
    grams[id] = (grams[id] ?? 0) + g;
  }

  for (final day in meal.days) {
    for (final slot in day.slots.values) {
      for (final item in slot) {
        if (item.kind == MealItemKind.food && item.foodId != null) {
          addFood(item.foodId!, (item.grams ?? 0).toDouble());
        } else if (item.kind == MealItemKind.recipe) {
          final r = catalog.recipe(item.recipeId ?? '');
          if (r == null) continue;
          final scale = (item.servings ?? 1) / ((r.serves ?? 1) <= 0 ? 1 : r.serves!);
          for (final RecipeIngredient ing in r.ingredients) {
            if (ing.optional || ing.servingSideOnly) continue;
            if (ing.foodId != null && ing.grams != null) {
              addFood(ing.foodId!, ing.grams! * scale);
            } else {
              final text = (language == 'ar' ? ing.qtyTextAr : (ing.qtyTextEn ?? ing.qtyTextAr)).replaceAll('\n', ' ').trim();
              if (text.isNotEmpty) words.add(text);
            }
          }
        }
      }
    }
  }
  return [
    for (final e in grams.entries)
      if (e.value > 0) GroceryLine(names[e.key]!, e.value.round()),
    for (final w in words) GroceryLine(w, 0),
  ]..sort((a, b) => a.name.compareTo(b.name));
}
```
UNVERIFIED: `Food.names` is a `List<String>` (used as `f.names.first` in `coach_plan_logic.dart` line 331-333: yes); `Recipe.ingredients` and `serves` (recipe.dart lines 607 and 617); `MealDay.slots` is `Map<String, List<MealItem>>` (coach_plan.dart): yes.
3. Create `grocery_list_view.dart`: `class GroceryListView extends StatefulWidget` with `lines`, `onBack`; state holds `Set<int> _ticked`; body `AppScaffold(appBar: AppTopBar(title: l10n.groceryList, onBack: ...), children: [Text(l10n.forTheWholePlanAsTheDishesAre...), for each line CheckboxListTile(key: ValueKey('grocery-$i'), value: ticked, title: Text(name), secondary: grams == 0 ? null : Text(l10n.gramsAmount(countLabel(grams))), onChanged: ...)])`, empty state `Text(l10n.nothingToBuyYet, key: ValueKey('grocery-empty'))`. Use `l10n.gramsAmount`: UNVERIFIED existing getter; find one with `grep -n '{n} g\|"{grams} g"\|g"' app/lib/l10n/app_en.arb | head`; the grams-with-unit string exists since `itemAmount(l10n, item)` prints grams (in `plan_labels.dart`, 55 lines; read it and reuse its helper for the amount text).
4. File `coach_meal_row.dart`: constructor add `this.onSwap,` and field `final VoidCallback? onSwap;` (doc: `/// Null hides Swap.`). In the non-compact branch (about lines 175-203, the part that builds the trailing `Log this` button with key `'$keyPrefix-log'`), wrap the trailing in a `Row(mainAxisSize: MainAxisSize.min, children: [if (onSwap != null) TextButton(key: ValueKey('$keyPrefix-swap'), onPressed: onSwap, child: Text(l10n.swap)), <the existing OutlinedButton/TextButton>])`. Read lines 150-203 first and keep the existing button exactly as is inside the Row.
5. File `from_your_coach_section.dart`. Constructor add `this.onSwap, this.onGrocery,` with types `final void Function(int day, String slot, int index, MealItem item)? onSwap;` and `final VoidCallback? onGrocery;`. In `build`, `final d = todaysMealDay(plan, now);` is the day index. Resolve the shown item through the swap store: replace `item: day.itemsIn(slot)[i],` by `item: _shown(plan.id, d, slot, i, day.itemsIn(slot)[i]),` with the method
```dart
  MealItem _shown(String planId, int d, String slot, int i, MealItem planned) {
    final id = CoachMealSwaps.instance.chosen(planId, d, slot, i);
    if (id == null || planned.kind != MealItemKind.recipe) return planned;
    return MealItem.recipe(id, planned.servings ?? 1, note: planned.note);
  }
```
and to the row `onSwap: day.itemsIn(slot)[i].swaps.isEmpty || onSwap == null ? null : () => onSwap!(d, slot, i, day.itemsIn(slot)[i]),`. The flags (`flagOf`) were computed from the planned day; recompute them over the shown items: build `final shownDay = MealDay(label: day.label, slots: {for (final s in CoachingEnums.mealSlots) s: [for (var i = 0; i < day.itemsIn(s).length; i++) _shown(plan.id, d, s, i, day.itemsIn(s)[i])]});` and use `flagMealPlan(MealPlanBody(days: [shownDay]), constraints, catalog)` so a swapped dish with an allergen is marked. After the title add the goal lines:
```dart
        if (meal.goal != null) ...[
          Text(
            l10n.yourCoachsTargetLine(
              '${meal.goal!.kcalPerDay}',
              '${meal.goal!.proteinGPerDay}',
            ),
            key: const ValueKey('coach-goal-line'),
            style: AppText.bodyM,
          ),
          if (!dayNutrition(shownDay, catalog).isEmpty)
            Text(
              dayNutritionLine(l10n, dayNutrition(shownDay, catalog)),
              key: const ValueKey('coach-planned-line'),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],
```
(`dayNutrition` and `dayNutritionLine` come from `coach_plan_logic.dart` and `plans/plan_labels.dart`; add the imports the file lacks.) At the end of the card children add `if (onGrocery != null) AppButton(l10n.groceryList, key: const ValueKey('coach-grocery'), variant: AppButtonVariant.text, height: 48, fontSize: 15, onPressed: onGrocery)`. Screen budget on Eat is counted (`test/qa/screen_budget_test.dart`): the card adds up to 2 text buttons per row only for dishes with swaps and one grocery button. Run that test (Verify). If Eat exceeds 5 controls above the fold, move `Grocery list` into the plan screen only and drop `coach-grocery` here (then the tap count is 2).
6. File `app_router.dart`, `_coachMealSection` (about line 8782-8815): add to the `FromYourCoachSection(` call:
```dart
      onSwap: (day, slot, index, item) => unawaited(
        showAppSheet<void>(
          context: context,
          children: [
            Builder(builder: (sheet) {
              final l10n = AppL10n.of(sheet);
              final lang = Localizations.localeOf(sheet).languageCode;
              final catalog = coachMealCatalog(l10n);
              String title(String id) {
                final r = catalog.recipe(id);
                if (r == null) return id;
                final ar = r.titleAr;
                return lang == 'ar' && ar != null && ar.isNotEmpty ? ar : r.titleEn;
              }
              void pick(String? id) {
                CoachMealSwaps.instance.choose(shown.id, day, slot, index, id);
                Navigator.of(sheet).pop();
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.changeTo, style: AppText.titleL),
                  AppListItem(
                    key: const ValueKey('swap-keep'),
                    title: title(item.recipeId!),
                    subtitle: l10n.plannedDish,
                    onTap: () => pick(null),
                  ),
                  for (final id in item.swaps)
                    AppListItem(
                      key: ValueKey('swap-choice-$id'),
                      title: title(id),
                      onTap: () => pick(id),
                    ),
                ],
              );
            }),
          ],
        ),
      ),
      onGrocery: () => unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (route) => GroceryListView(
              lines: groceryFor(
                shown.meal!,
                coachMealCatalog(AppL10n.of(context)),
                Localizations.localeOf(context).languageCode,
              ),
              onBack: () => Navigator.of(route).maybePop(),
            ),
          ),
        ),
      ),
```
`shown` is already the local plan variable (line 8800). Imports: `coach_meal_swaps.dart`, `grocery_list.dart`, `grocery_list_view.dart`, `app_sheet.dart`, `app_list_item.dart` (UNVERIFIED which are already imported in `app_router.dart`; run analyze and add the missing ones).
7. File `coach_plan_view.dart` `_meals` (about line 286-345): at the start of the returned list add the target line (same widget, key `plan-goal-line`) when `meal.goal != null`; at the end add `if (!preview) AppButton(l10n.groceryList, key: const ValueKey('plan-grocery'), variant: AppButtonVariant.text, height: 48, fontSize: 15, onPressed: onGrocery)`, with a new constructor field `final VoidCallback? onGrocery;` (null hides). Wire it in the `H03` route builder in `app_router.dart` (UNVERIFIED line: `grep -n "'H03'" app/lib/routing/app_router.dart`) the same way as step 6's `onGrocery`, using that route's plan.
8. Strings, then `add_strings.py`.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| yourCoachsTargetLine | Your coach's target: {kcal} calories and {protein} g protein | هدف مدربتك: {kcal} سعر و{protein} جم بروتين |
| swap | Swap | بدّلي |
| changeTo | Change to | غيّريها لـ |
| plannedDish | The planned dish | الأكلة المكتوبة في الخطة |
| groceryList | Grocery list | قايمة المشتريات |
| forTheWholePlanAsTheDishesAreWritten | For the whole plan, as the dishes are written | للخطة كلها، زي ما الأكلات مكتوبة |
| nothingToBuyYet | Nothing to buy yet. | مفيش حاجة تتشرى لسه. |
Parameterised: `{kcal}` and `{protein}` String placeholders. Command: `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03j.json && flutter gen-l10n`.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| client_screens_test.dart | `eat card: log is one tap` | Pump `FromYourCoachSection` with a one-day plan (copy this file's existing setup for the card) and a recording `onLog`; tap `coach-meal-lunch-0-log` once; assert `onLog` called once with the item. |
| same | `eat card: goal line and planned total` | Plan body with `goal`: `coach-goal-line` text is `Your coach's target: 1600 calories and 110 g protein`; without a goal neither line exists. |
| same | `swap in two taps and log the swapped dish` | Item with `swaps: ['x']`, `onSwap` wired to a helper that calls `CoachMealSwaps.instance.choose`. Tap `coach-meal-lunch-0-swap` (1), the sheet row `swap-choice-x` (2) (wire the real sheet through the router function by extracting it, or pump a small harness with the same sheet builder); rebuild: the row title is the swapped dish; tap `-log`: `onLog` gets a recipe item with `recipeId == 'x'` and the planned servings. `tearDown`: `CoachMealSwaps.instance.choose(...null)` to clear. |
| same | `swap is hidden for a dish without swaps and for a food item` | No `-swap` key. |
| grocery_list_test.dart (new, beside it) | `groceryFor adds weights by food and lists the rest by words` | Meal with a food item (rice 100 g) twice and a recipe with an ingredient of known food (50 g, serves 2, servings 1) and one with no grams; assert rice 200, the recipe food 25, the words line once, sorted by name, optional and side-only ingredients missing. Use a small hand-built `Recipe`: UNVERIFIED how tests build one; copy from `coach_meal_catalog_test.dart` or load two recipes from the real asset. |
| client_screens_test.dart | `grocery screen ticks rows and shows the empty text` | Pump `GroceryListView(lines: [..2 lines])`, tap `grocery-0` -> checkbox value true; with `lines: []` `grocery-empty` shows. |
Run: `cd app && flutter test test/features/private_coaching/client` and `flutter test test/qa/screen_budget_test.dart`.

## Verify
`flutter analyze lib` -> `No issues found!`; the commands above print `All tests passed!`; Arabic pump of the Eat card with a swap button, goal line and grocery button shows no overflow at 320 px.

## Do not
Do not add any write to the server for a swap. Do not show a calorie target to a client when `goal` is absent. Do not change `logCoachMeal` or the allergy guard. Do not rename existing keys (`coach-meal-<slot>-<i>-log` is used by tests). No em dashes. No commit.

## Done checklist
- [ ] Goal line  - [ ] Swap 2 taps  - [ ] Grocery list  - [ ] One-tap log locked by a test  - [ ] Strings EN/AR  - [ ] Budget test passes

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw. This is the last order of WO-03.
