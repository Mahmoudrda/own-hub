// E02's view model — the parse, and the two edits the design allows.
//
// The asymmetry worth pinning: the guard screens the HISTORY row and does not
// screen what she typed. G5 §5.1 splits those deliberately — the guard filters
// what the app OFFERS, and a dish she named herself is handled at the moment of
// the log by AllergyGuard.assess through MealLogService. Screening her own words
// here would make a dish she is holding silently unloggable, with no sheet to
// explain why.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/presentation/type_it_view_model.dart';

final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl', 'koshari'],
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
  names: const ['Boiled eggs', 'eggs'],
  allergens: const <String>{'egg'},
  popularity: 80,
  sizes: const [
    FoodSize(id: '1', label: '1', kcal: 78, proteinG: 6),
    FoodSize(id: '2', label: '2', kcal: 156, proteinG: 13),
    FoodSize(id: '3', label: '3', kcal: 234, proteinG: 19),
  ],
);

final _tahini = Food(
  foodId: 'tahini_salad',
  names: const ['Tahini salad'],
  allergens: const <String>{'sesame'},
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 220, proteinG: 6)],
);

final _parser = MealSentenceParser(FoodLibrary([_koshari, _eggs, _tahini]));

ParsedItem _historyEntry(Food food) => ParsedItem(
  food: food,
  size: food.defaultSize,
  servings: 1,
  sourceText: food.names.first,
);

TypeItViewModel _model({
  DietaryConstraints? constraints,
  List<ParsedItem> history = const [],
}) => TypeItViewModel(
  parser: _parser,
  guard: AllergyGuard(constraints ?? DietaryConstraints.none),
  history: history,
);

void main() {
  group('P0-LOG-07 — a sentence becomes rows', () {
    test('two items, sizes already picked, ready to log', () {
      final view = _model().build('koshari and 2 eggs');

      expect(view.items, hasLength(2));
      expect(view.items[0].size.id, 'M');
      expect(view.items[1].size.id, '2');
      expect(view.canLog, isTrue);
      expect(view.kcal, 696);
      expect(view.proteinG, 31);
    });

    test('the text she typed is kept exactly', () {
      final view = _model().build('  koshari and 2 eggs  ');
      expect(view.text, '  koshari and 2 eggs  ');
    });

    test('an empty box has nothing to log', () {
      expect(TypeItState.blank.canLog, isFalse);
      expect(_model().build('').canLog, isFalse);
      expect(_model().build('   ').items, isEmpty);
    });

    test('a sentence matching nothing cannot be logged', () {
      final view = _model().build('qqq');

      expect(view.canLog, isFalse);
      expect(view.hasUnresolved, isTrue);
    });
  });

  group('unresolved fragments stay visible', () {
    test('they are kept beside whatever did resolve', () {
      final view = _model().build('koshari and something I made up');

      expect(view.items, hasLength(1));
      expect(view.unresolved, hasLength(1));
      expect(view.unresolved.single.text, 'something I made up');
    });

    test('one unmatched fragment does not block logging the rest', () {
      final view = _model().build('koshari and something I made up');

      expect(
        view.canLog,
        isTrue,
        reason:
            'she typed two things and we understood one; refusing both '
            'would make the box feel broken',
      );
      expect(view.kcal, 540);
    });
  });

  group('sizes are chips on the row', () {
    test('changing one recomputes that row and the total', () {
      final model = _model();
      final view = model.build('koshari and 2 eggs');
      final larger = model.resize(view, 0, _koshari.sizeById('L')!);

      expect(larger.items[0].size.id, 'L');
      expect(larger.items[0].kcal, 700);
      expect(larger.items[1].kcal, 156, reason: 'the other row is untouched');
      expect(larger.kcal, 856);
    });

    test('the text she typed survives an edit', () {
      final model = _model();
      final view = model.build('koshari and 2 eggs');
      final edited = model.resize(view, 1, _eggs.sizeById('3')!);

      expect(edited.text, 'koshari and 2 eggs');
      expect(edited.kcal, 540 + 234);
    });

    test('removing a row drops it from the total', () {
      final model = _model();
      final view = model.build('koshari and 2 eggs');
      final fewer = model.remove(view, 1);

      expect(fewer.items, hasLength(1));
      expect(fewer.kcal, 540);
    });

    test('removing the last row leaves nothing to log', () {
      final model = _model();
      var view = model.build('koshari');
      view = model.remove(view, 0);

      expect(view.canLog, isFalse);
    });

    test('a stale index is ignored rather than crashing her screen', () {
      final model = _model();
      final view = model.build('koshari');

      expect(model.remove(view, 7).items, hasLength(1));
      expect(
        model.resize(view, 7, _koshari.sizeById('L')!).items,
        hasLength(1),
      );
    });
  });

  group('the guard screens what the app OFFERS, not what she typed', () {
    test('a conflicting dish is dropped from "one you have had before"', () {
      final view = _model(
        constraints: const DietaryConstraints(allergies: {'sesame'}),
        history: [_historyEntry(_tahini), _historyEntry(_koshari)],
      ).build('');

      expect(view.history.map((e) => e.food.foodId), ['koshari_bowl']);
    });

    test('the same history is offered in full to a woman without it', () {
      final view = _model(
        history: [_historyEntry(_tahini), _historyEntry(_koshari)],
      ).build('');

      expect(view.history, hasLength(2));
    });

    test('a dish she typed BY NAME still parses', () {
      // She named it herself. The block, if there is one, belongs at the moment
      // of the log where it can be explained — not here, where it would look
      // like the box simply does not know the dish.
      final view = _model(
        constraints: const DietaryConstraints(allergies: {'sesame'}),
      ).build('Tahini salad');

      expect(view.items, hasLength(1));
      expect(view.items.single.food.foodId, 'tahini_salad');
    });
  });
}
