/// E08's lines, made from the dinners on E07.
///
/// Each dinner that is one of Rahma's recipes contributes her own ingredient
/// text, line by line, under that dinner. Nothing is summed, converted or
/// renamed: a woman shopping for her dinner reads what the recipe says. A
/// dinner that is not one of her recipes contributes nothing, so a plan with no
/// such dinner has no list.
///
/// A line is keyed by the recipe id and her `ingredientRef`, so a tick survives
/// the list being built again and two phones converge on one line.
library;

import 'meal_repository.dart';
import 'recipe.dart';

/// The key of one line: the recipe and the ingredient inside it.
String recipeGroceryKey(String recipeId, String ingredientRef) =>
    '$recipeId:$ingredientRef';

/// The lines [plan]'s dinners need, in the order the week runs, each recipe
/// once however many days it is on.
List<GroceryLine> groceryLinesFor(
  MealPlan plan,
  Recipe? Function(String recipeId) recipeOf,
) {
  final days = plan.dinners.keys.toList()
    ..sort((a, b) => a.index.compareTo(b.index));
  final seen = <String>{};
  final lines = <GroceryLine>[];
  for (final day in days) {
    final recipe = recipeOf(plan.dinners[day]!);
    if (recipe == null || !seen.add(recipe.recipeId)) continue;
    for (final ingredient in [
      ...recipe.ingredients,
      for (final component in recipe.components) ...component.ingredients,
    ]) {
      // What is only on the plate beside the dish is not something to buy for
      // the dish.
      if (ingredient.servingSideOnly) continue;
      final text = ingredient.qtyLine.trim();
      if (text.isEmpty) continue;
      lines.add(
        GroceryLine(
          itemKey: recipeGroceryKey(recipe.recipeId, ingredient.ingredientRef),
          ingredientId: ingredient.ingredientRef,
          group: GroceryGroup.cupboard,
          text: text,
          recipeId: recipe.recipeId,
        ),
      );
    }
  }
  return lines;
}
