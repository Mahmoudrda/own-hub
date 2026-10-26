library;

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
          final scale =
              (item.servings ?? 1) / ((r.serves ?? 1) <= 0 ? 1 : r.serves!);
          for (final RecipeIngredient ing in r.ingredients) {
            if (ing.optional || ing.servingSideOnly) continue;
            if (ing.foodId != null && ing.grams != null) {
              addFood(ing.foodId!, ing.grams! * scale);
            } else {
              final text =
                  (language == 'ar'
                          ? ing.qtyTextAr
                          : (ing.qtyTextEn ?? ing.qtyTextAr))
                      .replaceAll('\n', ' ')
                      .trim();
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
