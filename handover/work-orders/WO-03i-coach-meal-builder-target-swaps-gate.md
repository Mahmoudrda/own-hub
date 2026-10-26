# WO-03i: Rahma's meal builder: daily target, swaps, the eating-history gate, and only signed recipes
Depends on: WO-03h (model and server), WO-03g (same file; do 03g first to avoid merge pain)
Size: L
Reads first: `app/lib/features/private_coaching/presentation/plans/share_meal_plan_view.dart` lines 72-100, 296-420, 484-548; `app/lib/routing/coaching_wiring.dart` lines 267-282; `app/test/features/private_coaching/plans/coach_meal_catalog_test.dart` (all); `app/lib/features/eat/domain/recipe.dart` lines 695-727; `app/tool/build_rahma_recipes.py` lines 850-870 and 1100-1115

## Why
C7: Rahma creates meal plans with a kcal and protein target, offers approved swaps, and uses her 39 recipes from the shared book. Three safety rules apply: (1) no calorie or macro target for a client with a flagged eating-history answer; (2) a recipe whose allergens nobody has signed must not be offered to a client at all; (3) she must be able to turn her book recipes off until she confirms the allergen sheet.

## Final result
Screen "Share a meal plan", top to bottom (unchanged items kept): plan name field; templates list (only while the plan is empty); "How many days" chips; day chips; allergies line; the NEW card below it; the day card with four slots; figures line; preview; save as template; footer `Publish to Mariam` (the only filled button).
NEW card A, shown when the client is NOT flagged: title `Daily target for her` / `الهدف اليومي ليها`; two number fields side by side: `Calories` / `السعرات` (key `meal-goal-kcal`, hint `1600`) and `Protein (g)` / `البروتين (جم)` (key `meal-goal-protein`, hint `110`); one line under them `Between 1200 and 4000 calories, 30 to 250 g protein.` / `من 1200 لـ 4000 سعر، ومن 30 لـ 250 جم بروتين.` Empty fields mean no target. A target needs both fields; one alone shows the error line `Fill in both numbers, or leave both empty.` / `املي الرقمين، أو سيبيهم فاضيين.`
NEW card B, shown INSTEAD of card A when the client is flagged (`intake.eatingHistoryFlag`): amber card (key `meal-gate-banner`) with `Her answers on eating mean you review her first. You can send a menu without calorie or protein targets.` / `إجاباتها عن الأكل معناها إنك تراجعيها بنفسك الأول. تقدري تبعتي منيو من غير سعرات أو بروتين مطلوب.` and no fields. Her day totals line (`meal-figures`) is also hidden for her, so no number appears on this screen for a flagged client.
Each recipe row gets a text button `Swaps (2)` / `البدائل (2)` (key `meal-swaps-<day>-<slot>-<index>`, `Swaps` with no count when none), after the remove icon. It opens a sheet: title `Approved swaps` / `بدائل متاحة`, search field, rows of recipes with checkboxes (up to 3 ticked; the 4th is ignored with the text `Three at most.` / `3 بس.`), filled button `Save swaps` / `حفظ البدائل`. Tap path to add swaps to a dish: Swaps (1), tick (2), tick (3), Save swaps (4). One swap: 3 taps.
Recipe lists (the add sheet and the swaps sheet) show only recipes whose allergens are known (signed by a person, or checked by the Own Hub script), never an unsigned book recipe. How the owner turns her 39 book recipes off or on: see "Owner gate" below.
Tap path to put one dish in a slot: `Add` for the slot (1), the dish (2), `add-confirm` (3) = 3 taps. A whole day from a saved template: 0 extra taps (pick the template in the list, it fills every day).

## Files to edit or create
| path | file action | change |
|---|---|---|
| app/lib/features/private_coaching/presentation/plans/share_meal_plan_view.dart | edit | goal card, gate card, swaps button, hide figures |
| app/lib/features/private_coaching/presentation/plans/swap_picker_sheet.dart | create | the sheet |
| app/lib/routing/coaching_wiring.dart | edit | `coachMealCatalog` keeps only recipes with known allergens |
| app/test/features/private_coaching/plans/coach_meal_catalog_test.dart | edit | catalog gate tests |
| app/test/features/private_coaching/plans/plan_screens_test.dart | edit | 5 widget tests |
| app/tool/recipe_signoff.json | edit (owner step only) | see Owner gate |

## Steps
1. File `coaching_wiring.dart`, `coachMealCatalog` (about line 267-282): the filter `if (seeded == null || seeded.contains(r.recipeId)) r,` becomes
```dart
      for (final r in eat.recipeBook.recipes)
        if ((seeded == null || seeded.contains(r.recipeId)) &&
            r.allergensKnown)
          r,
```
`allergensKnown` is true for a person-signed recipe and for an Own Hub kitchen recipe checked by the script (`recipe.dart` lines 696-726).
2. File `share_meal_plan_view.dart`, state (about line 80): add
```dart
  final TextEditingController _kcal = TextEditingController();
  final TextEditingController _protein = TextEditingController();
```
and dispose them in `dispose()`. In `initState`-equivalent: `late` initial text from `widget.existing?.meal?.goal`: add an `initState`:
```dart
  @override
  void initState() {
    super.initState();
    final g = widget.existing?.meal?.goal;
    if (g != null) {
      _kcal.text = '${g.kcalPerDay}';
      _protein.text = '${g.proteinGPerDay}';
    }
  }
```
Add the getters:
```dart
  bool get _flagged => widget.subscription.intake?.eatingHistoryFlag ?? false;

  /// Null when both fields are empty or the client is flagged. Throws nothing:
  /// a half-filled or out-of-range pair is reported by [_goalProblem].
  MealGoal? get _goal {
    if (_flagged) return null;
    final k = int.tryParse(_kcal.text.trim());
    final p = int.tryParse(_protein.text.trim());
    if (k == null || p == null) return null;
    final g = MealGoal(kcalPerDay: k, proteinGPerDay: p);
    return g.isValid ? g : null;
  }

  bool get _goalProblem {
    if (_flagged) return false;
    final empty = _kcal.text.trim().isEmpty && _protein.text.trim().isEmpty;
    return !empty && _goal == null;
  }
```
3. Same file, `_publish` (WO-03g changed it; the meal body argument is `meal: _body`). Before `final problems = _problems();` add:
```dart
    if (_goalProblem) {
      setState(() => _error = l10n.fillInBothNumbersOrLeaveBothEmpty);
      return;
    }
```
and replace every use of `meal: _body` in `_publish` and `_saveTemplate` (`body: _body.toJson()`) by `_bodyToSend` with the getter
```dart
  MealPlanBody get _bodyToSend => mealPlanWithGoal(_body, _goal);
```
Also in `_preview` (about line 210-224) `meal: _body` -> `meal: _bodyToSend`. The server's hold (WO-03h) is the second wall; this is the first.
4. Same file, `build`: insert after the `meal-flag-banner` block (about line 354) and before the day `AppCard`:
```dart
            if (_flagged)
              AppCard(
                key: const ValueKey('meal-gate-banner'),
                variant: AppCardVariant.amber,
                children: [
                  Text(l10n.herAnswersOnEatingMeanYouReview, style: AppText.titleS),
                ],
              )
            else
              AppCard(
                variant: AppCardVariant.outlined,
                borderRadius: AppRadius.md,
                children: [
                  Text(l10n.dailyTargetForHer, style: AppText.titleS),
                  Row(
                    children: [
                      Expanded(
                        child: AppField(
                          key: const ValueKey('meal-goal-kcal'),
                          controller: _kcal,
                          label: l10n.calories,
                          hint: '1600',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onChanged: (_) => setState(() => _error = ''),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AppField(
                          key: const ValueKey('meal-goal-protein'),
                          controller: _protein,
                          label: l10n.proteinGrams,
                          hint: '110',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          onChanged: (_) => setState(() => _error = ''),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    l10n.targetRangeLine,
                    style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
```
UNVERIFIED parameter names of `AppField` (`hint`, `keyboardType`): `sed -n 1,80p app/lib/ui/app_field.dart`; adapt as in WO-03b. Also UNVERIFIED that `l10n.calories` and `l10n.proteinGrams` do not already exist with other wording: `grep -n '"calories"\|"protein' app/lib/l10n/app_en.arb`; the add_strings script reuses an existing getter when the English text matches. Budget: this screen is a builder, not a counted screen; confirm with `grep -n "ShareMealPlan\|meal-" app/test/qa/screen_budget_test.dart` (UNVERIFIED).
5. Same file: hide the day figures line for a flagged client. The `meal-figures` widget (about line 377, inside the day card, `Text(... key: const ValueKey('meal-figures') ...)`) gets the extra condition `!_flagged &&` in front of its existing condition (read lines 372-392 first).
6. Same file, `_itemRow` (about line 484-545): after the `IconButton` remove (before the closing `],` of the `Row`) add, for recipe items only:
```dart
          if (item.kind == MealItemKind.recipe)
            TextButton(
              key: ValueKey('meal-swaps-$dayIndex-$slot-$index'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => unawaited(_swaps(dayIndex, slot, index, item)),
              child: Text(
                item.swaps.isEmpty
                    ? l10n.swaps
                    : l10n.swapsN(countLabel(item.swaps.length)),
              ),
            ),
```
and the method (next to `_add`):
```dart
  Future<void> _swaps(int day, String slot, int index, MealItem item) async {
    final picked = await showAppSheet<List<String>>(
      context: context,
      children: [
        SwapPickerSheet(
          catalog: widget.catalog,
          language: Localizations.localeOf(context).languageCode,
          exclude: item.recipeId!,
          initial: item.swaps,
        ),
      ],
    );
    if (picked == null || !mounted) return;
    setState(
      () => _body = mealPlanWithSwaps(_body, day, slot, index, picked),
    );
  }
```
7. Create `swap_picker_sheet.dart`:
```dart
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_field.dart';
import 'coach_plan_logic.dart';

class SwapPickerSheet extends StatefulWidget {
  const SwapPickerSheet({
    super.key,
    required this.catalog,
    required this.language,
    required this.exclude,
    required this.initial,
  });

  final MealCatalog catalog;
  final String language;
  final String exclude;
  final List<String> initial;

  @override
  State<SwapPickerSheet> createState() => _SwapPickerSheetState();
}

class _SwapPickerSheetState extends State<SwapPickerSheet> {
  late final List<String> _picked = [...widget.initial];
  final TextEditingController _q = TextEditingController();
  bool _full = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  String _title(String id) {
    final r = widget.catalog.recipe(id)!;
    final ar = r.titleAr;
    return widget.language == 'ar' && ar != null && ar.isNotEmpty
        ? ar
        : r.titleEn;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final q = _q.text.trim().toLowerCase();
    final ids = [
      for (final r in widget.catalog.recipes)
        if (r.recipeId != widget.exclude &&
            (q.isEmpty || _title(r.recipeId).toLowerCase().contains(q)))
          r.recipeId,
    ].take(40).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.approvedSwaps, style: AppText.titleL),
        AppField(
          key: const ValueKey('swaps-search'),
          controller: _q,
          label: l10n.search,
          onChanged: (_) => setState(() {}),
        ),
        if (_full)
          Text(l10n.threeAtMost, style: AppText.bodyM.copyWith(color: AppColors.error)),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final id in ids)
                CheckboxListTile(
                  key: ValueKey('swap-$id'),
                  value: _picked.contains(id),
                  title: Text(_title(id)),
                  onChanged: (on) => setState(() {
                    if (on == true) {
                      if (_picked.length >= 3) {
                        _full = true;
                      } else {
                        _picked.add(id);
                        _full = false;
                      }
                    } else {
                      _picked.remove(id);
                      _full = false;
                    }
                  }),
                ),
            ],
          ),
        ),
        AppButton(
          l10n.saveSwaps,
          key: const ValueKey('swaps-save'),
          onPressed: () => Navigator.of(context).pop(<String>[..._picked]),
        ),
      ],
    );
  }
}
```
UNVERIFIED: `l10n.search` exists (`grep -n '"search"' app/lib/l10n/app_en.arb`); if not, use `l10n.searchMoves`-style new string `Search dishes` / `دوّري على أكلة`.
8. Strings (below), then `add_strings.py`.

## Owner gate (how Rahma's 39 recipes are turned off until she signs)
The 39 book recipes in `app/assets/content/rahma_recipes.json` carry `allergenReviewedBy: rahma_mohsen`, dated 2026-10-19, copied from `app/tool/recipe_signoff.json` (39 entries, verified). That is a draft stamp the owner still has to confirm with Rahma (`docs/owner/OWNER-TODO.md` line 99). The in-app gate is `allergensKnown` (step 1): a book recipe without `allergenReviewedBy` is not offered to a coach. To hold them until she confirms: set the file content to `{"recipes": {}}`, then run `cd app && python3 tool/build_rahma_recipes.py` (UNVERIFIED arguments: open the head of the script; its docstring at line 21 explains the sign-off file), run `flutter test test/features/eat/rahma_seed_test.dart` (it may pin the signed count; if it fails say so in QUESTIONS.md, do not edit it), and rebuild. When she confirms, restore the 39 entries with her real dates. The 11 Own Hub kitchen recipes stay available either way (`autoChecked`). Do NOT run this in this order; it is an owner step. The work order only adds the code gate and its tests.

## Strings to add
| key | English | Egyptian Arabic |
|---|---|---|
| dailyTargetForHer | Daily target for her | الهدف اليومي ليها |
| calories | Calories | السعرات |
| proteinGrams | Protein (g) | البروتين (جم) |
| targetRangeLine | Between 1200 and 4000 calories, 30 to 250 g protein. | من 1200 لـ 4000 سعر، ومن 30 لـ 250 جم بروتين. |
| fillInBothNumbersOrLeaveBothEmpty | Fill in both numbers, or leave both empty. | املي الرقمين، أو سيبيهم فاضيين. |
| herAnswersOnEatingMeanYouReview | Her answers on eating mean you review her first. You can send a menu without calorie or protein targets. | إجاباتها عن الأكل معناها إنك تراجعيها بنفسك الأول. تقدري تبعتي منيو من غير سعرات أو بروتين مطلوب. |
| swaps | Swaps | البدائل |
| swapsN | Swaps ({n}) | البدائل ({n}) |
| approvedSwaps | Approved swaps | بدائل متاحة |
| threeAtMost | Three at most. | 3 بس. |
| saveSwaps | Save swaps | حفظ البدائل |
Parameterised: `Swaps ({n})` with `n` String. Command: `cd app && python3 tool/add_strings.py /tmp/ownhub-wo03i.json && flutter gen-l10n`.

## Tests to add or change
| file | test | arrange, act, assert |
|---|---|---|
| coach_meal_catalog_test.dart | `an unsigned book recipe is not offered` | Build the catalog from the real asset with one book recipe's `allergenReviewedBy` removed (copy how this file builds `coachMealCatalog`'s inputs; if it only calls the function, load the asset JSON, delete the key for `rahma_lazy_cake`, load via `SeededRecipeLibrary` test hook, UNVERIFIED: read the file). Assert `catalog.recipe('rahma_lazy_cake') == null` and a signed one is present. |
| same | `all 11 kitchen recipes stay` | Count of catalog recipes with `isOwnHub` is 11 and the book ones 39 with the shipped asset. |
| plan_screens_test.dart | `meal: target needs both numbers` | Enter kcal 1600 only, publish: `meal-error` shows the fill-in text and the fake repository got no call. Enter both, publish: the recorded `meal.goal.kcalPerDay == 1600`, `proteinGPerDay == 110`. |
| same | `meal: flagged client sees the gate, no target fields, no figures` | Subscription with `intake` health `eatingHistory: true` (needs the C9 list; build the `Intake` directly with `health: {'eatingHistory': true}`, which the constructor accepts); assert `meal-gate-banner` exists, `meal-goal-kcal` does not, `meal-figures` does not; publish sends `meal.goal == null`. |
| same | `meal: swaps in 3 taps` | Add a recipe item; tap `meal-swaps-0-lunch-0`, tick two `swap-<id>`, tap `swaps-save`; assert the body's item has 2 swaps and the button reads `Swaps (2)`; ticking a 4th shows `Three at most.` |
| same | `meal: out of range target is held back` | kcal 900 with protein 100: the pair is invalid, `meal-error` shows the fill-in text. |
Run: `cd app && flutter test test/features/private_coaching/plans`.

## Verify
Analyze clean; tests `All tests passed!`; Arabic pump shows the target card and sheet without overflow on a 320 px width (the repo's small phone sizes: use the helper that `test/qa` uses, UNVERIFIED name: `grep -rn "320" app/test/qa | head -3`).

## Do not
Do not show any number for a flagged client. Do not accept a target below 1200 in the UI (the field check mirrors the server). Never offer unsigned recipes. Do not edit `rahma_recipes.json` by hand. Do not touch `recipe_signoff.json` in this order. No em dashes. No commit.

## Done checklist
- [ ] Catalog gate  - [ ] Target card  - [ ] Gate card  - [ ] Swaps sheet  - [ ] Strings EN/AR  - [ ] Tests

## If stuck
Stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-03j only if WO-03h passed.
