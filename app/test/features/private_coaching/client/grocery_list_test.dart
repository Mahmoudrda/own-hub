import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/presentation/client/grocery_list.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/coach_plan_logic.dart';

import '../plans/plans_support.dart';

void main() {
  test('groceryFor adds weights by food and lists the rest by words', () {
    final cat = MealCatalog(
      recipes: [
        recipe(
          'r1',
          serves: 2,
          ingredients: [
            const RecipeIngredient(
              ingredientRef: 'ing1',
              qtyTextAr: 'دجاج',
              qtyTextEn: 'Chicken',
              gramsBasis: GramsBasis.stated,
              foodId: 'chicken',
              grams: 50,
            ),
            const RecipeIngredient(
              ingredientRef: 'ing2',
              qtyTextAr: 'رشة ملح',
              qtyTextEn: '1 pinch salt',
              gramsBasis: GramsBasis.stated,
            ),
            const RecipeIngredient(
              ingredientRef: 'ing3',
              qtyTextAr: 'بصل اختياري',
              qtyTextEn: 'Optional onion',
              gramsBasis: GramsBasis.stated,
              optional: true,
            ),
            const RecipeIngredient(
              ingredientRef: 'ing4',
              qtyTextAr: 'طبق جانبي',
              qtyTextEn: 'Side dish',
              gramsBasis: GramsBasis.stated,
              servingSideOnly: true,
            ),
          ],
        ),
      ],
      foods: FoodLibrary([food('rice'), food('chicken')]),
    );

    final meal = MealPlanBody(
      days: [
        MealDay(
          label: 'Day 1',
          slots: {
            'lunch': [MealItem.food('rice', 100), MealItem.recipe('r1', 1)],
            'dinner': [MealItem.food('rice', 100)],
          },
        ),
      ],
    );

    final list = groceryFor(meal, cat, 'en');

    expect(list.length, 3);
    expect(list[0].name, '1 pinch salt');
    expect(list[0].grams, 0);

    expect(list[1].name, 'Food chicken');
    expect(list[1].grams, 25);

    expect(list[2].name, 'Food rice');
    expect(list[2].grams, 200);

    // Assert optional and side-only are missing
    expect(list.any((l) => l.name.contains('onion')), isFalse);
    expect(list.any((l) => l.name.contains('Side')), isFalse);
  });
}
