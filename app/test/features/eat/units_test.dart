// Portions by weight: units turn into whole grams, the figures scale from the
// food's own weighed size, and a food with no weight offers no units at all.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/units.dart';

Food _food(String? category, {int? grams = 200}) => Food(
  foodId: 'x',
  names: const ['X'],
  category: category,
  sizes: [
    FoodSize(id: 'S', label: 'S', kcal: 100, proteinG: 4, grams: grams),
    FoodSize(
      id: 'M',
      label: 'M',
      kcal: 200,
      proteinG: 8,
      carbsG: 20,
      fatG: 10,
      fiberG: 4,
      grams: grams,
    ),
    FoodSize(id: 'L', label: 'L', kcal: 300, proteinG: 12, grams: grams),
  ],
);

void main() {
  group('grams from a unit', () {
    test('an ounce is 28.35 g', () {
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.oz, 2), 57);
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.oz, 1), 28);
    });

    test('grams are grams', () {
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.g, 150), 150);
    });

    test('ml equals grams for a drink or a soup, and is not offered for a '
        'solid', () {
      expect(FoodUnits.gramsFor(_food('drink'), FoodUnit.ml, 250), 250);
      expect(FoodUnits.gramsFor(_food('soup'), FoodUnit.ml, 300), 300);
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.ml, 250), isNull);
    });

    test('a cup is 240 ml of a drink, and a typical weight of a solid', () {
      expect(FoodUnits.gramsFor(_food('drink'), FoodUnit.cup, 1), 240);
      expect(FoodUnits.gramsFor(_food('soup'), FoodUnit.cup, 0.5), 120);
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.cup, 1), 200);
      expect(FoodUnits.gramsFor(_food('salad'), FoodUnit.cup, 2), 200);
      expect(FoodUnits.gramsFor(_food('bread'), FoodUnit.cup, 1), isNull);
    });

    test('a piece and a serving are the medium size', () {
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.piece, 1), 200);
      expect(FoodUnits.gramsFor(_food('main'), FoodUnit.serving, 1.5), 300);
    });

    test('nonsense amounts are refused', () {
      final food = _food('main');
      for (final amount in [0.0, -1.0, double.nan, double.infinity, 10000.0]) {
        expect(FoodUnits.gramsFor(food, FoodUnit.g, amount), isNull);
      }
    });
  });

  group('which units a food offers', () {
    test('only when its grams are known', () {
      expect(FoodUnits.availableFor(_food('main', grams: null)), isEmpty);
    });

    test('a solid has no millilitres, a drink has both', () {
      expect(
        FoodUnits.availableFor(_food('main')),
        containsAll([FoodUnit.g, FoodUnit.oz, FoodUnit.cup, FoodUnit.piece]),
      );
      expect(
        FoodUnits.availableFor(_food('main')),
        isNot(contains(FoodUnit.ml)),
      );
      expect(
        FoodUnits.availableFor(_food('drink')),
        containsAll([FoodUnit.ml, FoodUnit.cup]),
      );
      expect(
        FoodUnits.availableFor(_food('sandwich')),
        isNot(contains(FoodUnit.cup)),
      );
    });

    test('approximate units say so', () {
      expect(FoodUnits.isApproximate(_food('main'), FoodUnit.piece), isTrue);
      expect(FoodUnits.isApproximate(_food('main'), FoodUnit.cup), isTrue);
      expect(FoodUnits.isApproximate(_food('drink'), FoodUnit.cup), isFalse);
      expect(FoodUnits.isApproximate(_food('main'), FoodUnit.oz), isFalse);
      expect(FoodUnits.isApproximate(_food('main'), FoodUnit.g), isFalse);
    });
  });

  group('figures scale from the medium size', () {
    test('100 g of a 200 g, 200 kcal portion is 100 kcal', () {
      final size = FoodUnits.sizeFor(_food('main'), FoodUnit.g, 100)!;
      expect(size.id, 'g100');
      expect(size.kcal, 100);
      expect(size.proteinG, 4);
      expect(size.carbsG, 10);
      expect(size.fatG, 5);
      expect(size.fiberG, 2);
      expect(size.grams, 100);
    });

    test('a figure the pack does not carry stays unknown', () {
      final food = Food(
        foodId: 'y',
        names: const ['Y'],
        sizes: [
          FoodSize(id: 'M', label: 'M', kcal: 200, proteinG: 8, grams: 200),
        ],
      );
      final size = food.sizeForGrams(50)!;
      expect(size.kcal, 50);
      expect(size.carbsG, isNull);
    });

    test('a weight id resolves back to the same portion', () {
      final food = _food('main');
      final size = food.sizeById('g150')!;
      expect(size.kcal, 150);
      expect(size.grams, 150);
      expect(Food.gramsOfSizeId('g150'), 150);
      expect(Food.gramsOfSizeId('M'), isNull);
      expect(Food.gramsOfSizeId('g0'), isNull);
    });

    test('a food with no weight cannot resolve a weight id', () {
      expect(_food('main', grams: null).sizeById('g150'), isNull);
    });

    test('the amount shown for a weight is read back in its unit', () {
      expect(FoodUnits.amountFromGrams(_food('main'), FoodUnit.oz, 57), 2.0);
    });
  });
}
