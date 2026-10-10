// The domain half of P0-LOG-07 — "Log a meal by typing a sentence."
//
// From TEST-CASES.csv: "Sentence parses into two items with sizes pre-picked,
// adjustable as chips on the row. Resolves with no network."
//
// The parser is also E03's, so the voice half of P0-LOG-08 resolves through
// exactly these tests: a transcript and a typed sentence take the same path.
//
// §2 rule 10 is the one that matters here — **selects, never generates**. The
// assertions that carry weight are the negative ones: an unmatched fragment
// must become a chip and must NOT become a plausible-looking food with an
// invented gram figure, because a wrong guess in a food log is silent.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';

final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl', 'koshari', 'كشري'],
  allergens: const <String>{},
  popularity: 90,
  sizes: const [
    FoodSize(id: 'S', label: 'Small', kcal: 380, proteinG: 13),
    FoodSize(id: 'M', label: 'Medium', kcal: 540, proteinG: 18),
    FoodSize(id: 'L', label: 'Large', kcal: 700, proteinG: 24),
  ],
);

final _eggs = Food(
  foodId: 'boiled_eggs',
  names: const ['Boiled eggs', 'eggs', 'بيض', 'بيضتين'],
  allergens: const <String>{'egg'},
  popularity: 80,
  sizes: const [
    FoodSize(id: '1', label: '1', kcal: 78, proteinG: 6),
    FoodSize(id: '2', label: '2', kcal: 156, proteinG: 13),
    FoodSize(id: '3', label: '3', kcal: 234, proteinG: 19),
  ],
);

final _molokhia = Food(
  foodId: 'molokhia_chicken',
  names: const ['Molokhia with chicken', 'molokhia', 'ملوخية'],
  allergens: const <String>{},
  popularity: 70,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 460, proteinG: 34)],
);

final _parser = MealSentenceParser(FoodLibrary([_koshari, _eggs, _molokhia]));

void main() {
  group('P0-LOG-07 — "koshari and 2 eggs"', () {
    test('parses into exactly two items', () {
      final parse = _parser.parse('koshari and 2 eggs');

      expect(parse.items, hasLength(2));
      expect(parse.unresolved, isEmpty);
      expect(parse.items.map((i) => i.food.foodId), [
        'koshari_bowl',
        'boiled_eggs',
      ]);
    });

    test('the sizes are pre-picked, not left for her to choose', () {
      final parse = _parser.parse('koshari and 2 eggs');

      // The one she usually serves.
      expect(parse.items[0].size.id, 'M');
      // The number she said selected the size.
      expect(parse.items[1].size.id, '2');
    });

    test('a count selects a size and is NOT also a multiplier', () {
      final parse = _parser.parse('2 eggs');

      expect(parse.items.single.size.id, '2');
      expect(
        parse.items.single.servings,
        1,
        reason:
            'two eggs is the "2" size once, not the "2" size twice — '
            'multiplying here would log four eggs',
      );
      expect(parse.items.single.kcal, 156);
    });

    test('the totals are what the footer button names', () {
      final parse = _parser.parse('koshari and 2 eggs');

      // E02's "I ate both · 696 kcal".
      expect(parse.kcal, 696);
      expect(parse.proteinG, 31);
    });

    test('a quantity with no matching size becomes a serving count', () {
      final parse = _parser.parse('2 molokhia');

      expect(parse.items.single.size.id, 'M');
      expect(parse.items.single.servings, 2);
      expect(parse.items.single.kcal, 920);
    });
  });

  group('rule 10 — selects, never generates', () {
    test('an unmatched fragment becomes a chip, not a guess', () {
      final parse = _parser.parse('koshari and something I made up');

      expect(parse.items, hasLength(1));
      expect(parse.items.single.food.foodId, 'koshari_bowl');
      expect(parse.unresolved, [
        const UnresolvedFragment('something I made up'),
      ]);
    });

    test('a sentence matching nothing produces no items at all', () {
      final parse = _parser.parse('qqq zzz');

      expect(
        parse.items,
        isEmpty,
        reason:
            'a plausible-looking wrong food in a log is silent — she would '
            'never find out her day was wrong',
      );
      expect(parse.unresolved, hasLength(1));
    });

    test('every size on every item came from that food own sizes[]', () {
      final parse = _parser.parse('koshari and 3 eggs and molokhia');

      for (final item in parse.items) {
        expect(
          item.food.sizes.map((s) => s.id),
          contains(item.size.id),
          reason: 'a gram figure nobody authored must be unreachable',
        );
      }
    });

    test('an empty sentence parses to nothing', () {
      expect(_parser.parse('').isEmpty, isTrue);
      expect(_parser.parse('   ').isEmpty, isTrue);
    });

    test('an empty pack resolves nothing rather than inventing', () {
      const barren = MealSentenceParser(FoodLibrary.empty);
      final parse = barren.parse('koshari and 2 eggs');

      expect(parse.items, isEmpty);
      expect(parse.unresolved, hasLength(2));
    });
  });

  group('the connectors a woman actually types', () {
    test('commas, plus signs and "with" all split', () {
      for (final sentence in [
        'koshari, 2 eggs',
        'koshari + 2 eggs',
        'koshari with 2 eggs',
      ]) {
        final parse = _parser.parse(sentence);
        expect(parse.items, hasLength(2), reason: sentence);
      }
    });

    test('the Arabic waw splits, and the Arabic comma too', () {
      expect(_parser.parse('كشري و بيض').items, hasLength(2));
      expect(_parser.parse('كشري، بيض').items, hasLength(2));
    });
  });

  group('Arabic input', () {
    test('a dialect sentence resolves through the same parser as typing', () {
      // E03's transcript goes through this parser, so the voice path cannot
      // drift from the typed one.
      final parse = _parser.parse('كشري و ملوخية');

      expect(parse.items.map((i) => i.food.foodId), [
        'koshari_bowl',
        'molokhia_chicken',
      ]);
    });

    test('harakat do not prevent a match', () {
      // She types with and without diacritics; a match that depended on exact
      // orthography would fail on most real input.
      expect(_parser.parse('كُشري').items, hasLength(1));
    });

    test('Arabic-Indic digits are read as numbers', () {
      final parse = _parser.parse('٢ eggs');

      expect(parse.items.single.size.id, '2');
      // Read as input; every number the product RENDERS stays Western, which is
      // weightLabel()'s rule and P0-A11Y-01's requirement.
      expect(parse.items.single.kcal, 156);
    });

    test('the Arabic dual is both the number and the food', () {
      expect(_parser.parse('بيضتين').items.single.food.foodId, 'boiled_eggs');
    });
  });

  group('spelled numbers', () {
    test('"two boiled eggs" selects the 2 size', () {
      final parse = _parser.parse('two boiled eggs');
      expect(parse.items.single.size.id, '2');
    });

    test('"a koshari" is one serving', () {
      final parse = _parser.parse('a koshari');
      expect(parse.items.single.servings, 1);
      expect(parse.items.single.size.id, 'M');
    });
  });

  group('sizes are chips on the row, so she never opens a food', () {
    test('changing a size recomputes that row only', () {
      final parse = _parser.parse('koshari and 2 eggs');
      final larger = parse.withSizeAt(0, _koshari.sizeById('L')!);

      expect(larger.items[0].size.id, 'L');
      expect(larger.items[0].kcal, 700);
      expect(larger.items[1].kcal, 156, reason: 'the other row is untouched');
      expect(larger.kcal, 856);
    });

    test('removing a row drops it from the totals', () {
      final parse = _parser.parse('koshari and 2 eggs');
      final fewer = parse.withoutAt(1);

      expect(fewer.items, hasLength(1));
      expect(fewer.kcal, 540);
    });

    test('an out-of-range edit is ignored rather than throwing', () {
      // A stale index from a rebuilt widget must not take her screen down
      // mid-edit.
      final parse = _parser.parse('koshari');
      expect(parse.withSizeAt(9, _koshari.sizeById('L')!).items, hasLength(1));
      expect(parse.withoutAt(9).items, hasLength(1));
    });

    test('the original parse is unchanged by an edit', () {
      final parse = _parser.parse('koshari and 2 eggs');
      parse.withoutAt(0);
      expect(parse.items, hasLength(2), reason: 'edits return a new parse');
    });
  });

  group('matching prefers the whole name over a fragment of one', () {
    test('a longer phrase beats a shorter alias', () {
      final parse = _parser.parse('Molokhia with chicken');
      // "with" is a connector, so this also proves a connector inside a food's
      // own name does not shatter it into unresolved chips.
      expect(parse.items.first.food.foodId, 'molokhia_chicken');
    });

    test('ties are broken by popularity, not by authoring order', () {
      final library = FoodLibrary([
        Food(
          foodId: 'rare_eggs',
          names: const ['eggs'],
          popularity: 1,
          sizes: _eggs.sizes,
        ),
        _eggs,
      ]);
      final parse = MealSentenceParser(library).parse('eggs');

      expect(parse.items.single.food.foodId, 'boiled_eggs');
    });
  });
}
