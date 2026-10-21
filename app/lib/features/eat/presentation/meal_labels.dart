/// What a meal's undo offer says: the food and the slot, in her words.
///
/// Every Eat surface said only "Meal added", which never named what was added
/// or where it went, so she had to remember what she had tapped to know what
/// Undo would take back. One helper for all of them, so the sentence is the
/// same whichever door the meal came in by.
library;

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../today/presentation/today_cards.dart' show mealSlotName;
import '../domain/food_library.dart';
import '../domain/meal_repository.dart';

/// The names of [items], from the pack in her language, or the name she
/// approved for a plate the pack does not hold. Unnamed items are left out.
List<String> mealFoodNames(FoodLibrary library, Iterable<MealItem> items) => [
  for (final item in items)
    if ((library.byId(item.foodId)?.names.first ?? item.name ?? '')
        case final String name when name.trim().isNotEmpty)
      name.trim(),
];

/// "Ful added to Breakfast", or "Ful and 2 more added to Breakfast". Falls
/// back to "Meal added" when nothing in it has a name to say.
String mealAddedLabel(AppL10n l10n, List<String> foods, MealSlot slot) {
  if (foods.isEmpty) return l10n.mealAdded;
  final where = mealSlotName(l10n, slot);
  if (foods.length == 1) return l10n.foodAddedToSlot(foods.first, where);
  return l10n.foodAndCountMoreAddedToSlot(
    foods.first,
    countLabel(foods.length - 1),
    where,
  );
}

/// "Ful removed from Breakfast".
String mealRemovedLabel(AppL10n l10n, String food, MealSlot slot) =>
    l10n.foodRemovedFromSlot(food, mealSlotName(l10n, slot));

/// A food shelf's name in her language.
String foodCategoryLabel(AppL10n l10n, FoodCategory category) =>
    switch (category) {
      FoodCategory.egyptianDishes => l10n.egyptianDishes,
      FoodCategory.proteins => l10n.proteins,
      FoodCategory.dairyAndCheese => l10n.dairyAndCheese,
      FoodCategory.grainsAndBreads => l10n.grainsAndBreads,
      FoodCategory.vegetablesAndSalads => l10n.vegetablesAndSalads,
      FoodCategory.fruitsAndNuts => l10n.fruitsAndNuts,
      FoodCategory.snacksAndDrinks => l10n.snacksAndDrinks,
    };
