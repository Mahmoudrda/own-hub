// An allergy hides foods she is offered. It never stops her logging a meal,
// because a log records what she already ate.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';

const _sizes = [FoodSize(id: 'M', label: 'Medium', kcal: 400, proteinG: 20)];
const _nuts = AllergyGuard(
  DietaryConstraints(allergies: {'nuts'}, dietary: <String>{}),
);

Food _food(String id, {Set<String>? allergens}) =>
    Food(foodId: id, names: [id], allergens: allergens, sizes: _sizes);

void main() {
  final known = _food('baklava', allergens: {'nuts'});
  final clean = _food('rice', allergens: <String>{});
  final unknown = _food('koshari');

  test('suggestions hide a food known to hold what she avoids only', () {
    final shown = _nuts.screenSuggestions([known, clean, unknown]);
    expect(shown.map((f) => f.foodId), ['rice', 'koshari']);
  });

  test('a known allergen is named, unknown data names nothing', () {
    expect(_nuts.knownAllergens(known), {'nuts'});
    expect(_nuts.knownAllergens(unknown), isEmpty);
    expect(_nuts.knownAllergens(clean), isEmpty);
  });

  for (final food in [known, unknown]) {
    test('${food.foodId} logs for a woman who avoids nuts', () {
      final service = MealLogService(
        repository: InMemoryMealRepository(),
        library: FoodLibrary([food]),
        guard: _nuts,
      );
      final outcome = service.logNew(
        day: const MealDay(dayId: '2026-10-17'),
        slot: MealSlot.lunch,
        entries: [
          ParsedItem(
            food: food,
            size: food.defaultSize,
            servings: 1,
            sourceText: food.foodId,
          ),
        ],
        source: MealSource.search,
        origin: MealOrigin.search,
        at: DateTime(2026, 10, 17, 13),
      );
      expect(outcome, isA<MealLogPrepared>());
    });
  }
}
