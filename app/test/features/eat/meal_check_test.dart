// E13's arithmetic: a changed weight recomputes from the values per 100 g,
// each figure is rounded once, an item with no numbers counts for nothing,
// and the total is the sum of what the cards say.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_check.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';

ScannedItem _egg({double grams = 100}) => ScannedItem(
  nameEn: 'Boiled egg',
  nameAr: 'بيض مسلوق',
  grams: grams,
  matched: true,
  source: MealScanSource.usda,
  fdcId: 173424,
  per100g: const Macros(
    kcal: 155,
    proteinG: 12.6,
    carbsG: 1.12,
    fatG: 10.6,
    fiberG: 0,
  ),
);

const ScannedItem _sauce = ScannedItem(
  nameEn: 'Mystery sauce',
  nameAr: 'صوص',
  grams: 30,
  matched: false,
);

const ScannedItem _koshary = ScannedItem(
  nameEn: 'Koshari',
  nameAr: 'كشري',
  grams: 400,
  matched: true,
  source: MealScanSource.dish,
  dishKey: 'koshary',
  dishNameEn: 'Koshary',
  dishNameAr: 'كشري',
  review: 'estimated from a standard recipe, pending dietitian review',
  per100g: Macros(kcal: 150, proteinG: 5, carbsG: 27, fatG: 2.5),
  ingredients: [
    ScannedIngredient(nameEn: 'rice, cooked', grams: 100, matched: true),
    ScannedIngredient(nameEn: 'lentils, cooked', grams: 60, matched: true),
  ],
);

void main() {
  group('the weight drives the figures', () {
    test('at the server\'s weight, grams / 100 x per 100 g, rounded once', () {
      final item = CheckItem.scanned('a', _egg());
      expect(item.value(MacroKind.kcal), 155);
      expect(item.value(MacroKind.protein), 13); // 12.6
      expect(item.value(MacroKind.carbs), 1); // 1.12
      expect(item.value(MacroKind.fat), 11); // 10.6
      expect(item.value(MacroKind.fiber), 0);
    });

    test('a changed weight recomputes every figure', () {
      final item = CheckItem.scanned('a', _egg()).withGrams(150);
      expect(item.grams, 150);
      expect(item.value(MacroKind.kcal), 233); // 232.5
      expect(item.value(MacroKind.protein), 19); // 18.9
      expect(item.value(MacroKind.fat), 16); // 15.9
    });

    test('the steps are 10 g, never below 0 or above the ceiling', () {
      var item = CheckItem.scanned('a', _egg(grams: 15));
      item = item.stepGrams(1);
      expect(item.grams, 25);
      item = item.stepGrams(-1).stepGrams(-1).stepGrams(-1);
      expect(item.grams, 0);
      expect(item.value(MacroKind.kcal), 0);
      expect(item.withGrams(99999).grams, kMaxItemGrams);
      expect(item.withGrams(double.nan).grams, 0);
    });

    test('a dish\'s parts scale with its weight', () {
      final dish = CheckItem.scanned('d', _koshary).withGrams(200);
      expect(dish.parts.map((p) => p.grams), [50, 30]);
      expect(dish.value(MacroKind.fiber), isNull, reason: 'not in per100g');
    });
  });

  group('her own figures', () {
    test('a typed figure replaces the computed one and survives a new '
        'weight', () {
      var item = CheckItem.scanned('a', _egg()).withEdit(MacroKind.kcal, 140);
      expect(item.isEdited(MacroKind.kcal), isTrue);
      expect(item.value(MacroKind.kcal), 140);
      item = item.withGrams(200);
      expect(item.value(MacroKind.kcal), 140);
      expect(item.value(MacroKind.protein), 25, reason: 'still computed');
    });

    test('clearing it gives the computed figure back', () {
      final item = CheckItem.scanned(
        'a',
        _egg(),
      ).withEdit(MacroKind.kcal, 140).withEdit(MacroKind.kcal, null);
      expect(item.isEdited(MacroKind.kcal), isFalse);
      expect(item.value(MacroKind.kcal), 155);
    });

    test('a negative figure is read as zero', () {
      final item = CheckItem.scanned('a', _egg()).withEdit(MacroKind.fat, -4);
      expect(item.value(MacroKind.fat), 0);
    });
  });

  group('an item nothing was found for', () {
    test('has no figures and asks for them', () {
      final item = CheckItem.scanned('s', _sauce);
      expect(item.needsNumbers, isTrue);
      expect(item.isComplete, isFalse);
      expect(item.value(MacroKind.kcal), isNull);
    });

    test('counts for nothing in the total until it has energy and '
        'protein', () {
      var check = MealCheck([
        CheckItem.scanned('a', _egg()),
        CheckItem.scanned('s', _sauce),
      ]);
      expect(check.totals.kcal, 155);
      expect(check.incomplete, 1);
      expect(check.canLog, isFalse);
      expect(check.entries('en'), isEmpty);

      check = check.replace(1, check.items[1].withEdit(MacroKind.kcal, 60));
      expect(check.canLog, isFalse, reason: 'protein still unknown');
      expect(check.totals.kcal, 155);

      check = check.replace(1, check.items[1].withEdit(MacroKind.protein, 1));
      expect(check.items[1].needsNumbers, isFalse);
      expect(check.canLog, isTrue);
      expect(check.totals.kcal, 215);
      expect(check.totals.proteinG, 14);
      expect(check.totals.carbsG, 1, reason: 'the sauce carries none');
    });

    test('or can be removed', () {
      final check = MealCheck([
        CheckItem.scanned('a', _egg()),
        CheckItem.scanned('s', _sauce),
      ]).removeAt(1);
      expect(check.canLog, isTrue);
    });
  });

  group('an item only part of which was found', () {
    const partly = ScannedItem(
      nameEn: 'Mixed grill',
      nameAr: 'مشويات',
      grams: 250,
      matched: false,
      source: MealScanSource.ingredients,
      per100g: Macros(kcal: 180, proteinG: 20),
    );

    test('keeps its figures and says they may be low', () {
      final item = CheckItem.scanned('p', partly);
      expect(item.needsNumbers, isFalse);
      expect(item.partlyFound, isTrue);
      expect(item.value(MacroKind.kcal), 450);
    });

    test('stops saying so once she sets a figure herself', () {
      final item = CheckItem.scanned(
        'p',
        partly,
      ).withEdit(MacroKind.kcal, 520);
      expect(item.partlyFound, isFalse);
    });

    test('a fully found item never says so', () {
      expect(CheckItem.scanned('a', _egg()).partlyFound, isFalse);
    });
  });

  group('the total', () {
    test('is the sum of the rounded figures on the cards', () {
      final check = MealCheck([
        CheckItem.scanned('a', _egg()),
        CheckItem.scanned('b', _egg()),
        CheckItem.scanned('d', _koshary),
      ]);
      expect(check.totals.kcal, 155 + 155 + 600);
      expect(check.totals.proteinG, 13 + 13 + 20);
      expect(check.totals.carbsG, 1 + 1 + 108);
      expect(check.totals.fatG, 11 + 11 + 10);
      expect(check.totals.fiberG, 0, reason: 'only the eggs carry fibre');
    });

    test('is empty, with no unknowns, for an empty plate', () {
      expect(MealCheck.empty.totals, const CheckTotals());
      expect(MealCheck.empty.canLog, isFalse);
    });

    test('every scanned item from a result', () {
      final check = MealCheck.fromScan(
        MealScanResult(items: [_egg(), _sauce, _koshary]),
      );
      expect(check.items.map((i) => i.key), ['scan-0', 'scan-1', 'scan-2']);
    });
  });

  group('what is logged', () {
    test('her name, her weight and every figure she approved', () {
      final check = MealCheck([
        CheckItem.scanned('d', _koshary).withGrams(300),
        CheckItem.scanned('a', _egg()).withEdit(MacroKind.fiber, 2),
      ]);
      final entries = check.entries('ar');
      expect(entries, hasLength(2));
      expect(entries[0].name, 'كشري');
      expect(entries[0].foodId, '${kPhotoFoodPrefix}dish_koshary');
      expect(entries[0].grams, 300);
      expect(entries[0].kcal, 450);
      expect(entries[0].carbsG, 81);
      expect(entries[0].fiberG, isNull);
      expect(entries[1].foodId, '${kPhotoFoodPrefix}usda_173424');
      expect(entries[1].fiberG, 2);
      expect(entries[1].food, isNull);
    });

    test('a food from the list keeps its own id and size', () {
      const food = Food(
        foodId: 'boiled_eggs',
        names: ['Boiled eggs'],
        sizes: [
          FoodSize(id: '1', label: '1', kcal: 78, proteinG: 6),
          FoodSize(id: '2', label: '2', kcal: 156, proteinG: 13),
        ],
      );
      final item = CheckItem.library(
        'l',
        food,
        food.sizes.first,
      ).withSize(food.sizes[1]);
      expect(item.hasGrams, isFalse);
      expect(item.withGrams(500).grams, isNull);
      final entry = MealCheck([item]).entries('en').single;
      expect(entry.foodId, 'boiled_eggs');
      expect(entry.food, same(food));
      expect(entry.sizeId, '2');
      expect(entry.name, isNull);
      expect(entry.kcal, 156);
      expect(entry.carbsG, isNull);
    });

    test('one she typed scales with its weight', () {
      final own = CheckItem.own(
        'o',
        name: 'Mum\'s mahshi',
        grams: 200,
        kcal: 300,
        proteinG: 8,
        carbsG: 40,
      );
      expect(own.value(MacroKind.kcal), 300);
      expect(own.withGrams(100).value(MacroKind.kcal), 150);
      expect(own.withGrams(100).value(MacroKind.carbs), 20);
      expect(own.value(MacroKind.fat), isNull);
      final entry = MealCheck([own]).entries('en').single;
      expect(entry.name, 'Mum\'s mahshi');
      expect(entry.foodId, '${kPhotoFoodPrefix}own');
    });
  });
}
