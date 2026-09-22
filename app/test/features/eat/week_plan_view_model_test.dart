// E07 and E08's view model — one document, two screens.
//
// The property that matters while she is actually shopping: a tick changes one
// line and moves nothing. A list that reorders itself under her thumb in a
// market is harder to read than one that does not, and "it survives being
// closed mid-shop" is the screen's whole promise.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/item_id.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/week_plan_view_model.dart';

const _model = WeekPlanViewModel();
const _weekId = '2026-W38';

GroceryLine _line(
  String ingredientId,
  GroceryGroup group, {
  bool ticked = false,
}) => GroceryLine(
  itemKey: groceryItemKey(ingredientId: ingredientId, unit: 'kg'),
  ingredientId: ingredientId,
  group: group,
  ticked: ticked,
);

final _lines = [
  _line('tomatoes', GroceryGroup.vegetables, ticked: true),
  _line('onions', GroceryGroup.vegetables),
  _line('molokhia', GroceryGroup.vegetables),
  _line('chicken', GroceryGroup.protein),
  _line('eggs', GroceryGroup.protein),
  _line('rice', GroceryGroup.cupboard),
];

final _plan = MealPlan(
  weekId: _weekId,
  dinners: const {
    PlanDay.mon: 'molokhia_chicken',
    PlanDay.tue: 'koshari_portioned',
    PlanDay.wed: 'lentil_soup_eggs',
  },
  groceries: {for (final line in _lines) line.itemKey: line},
);

void main() {
  group('E07 — the week plan', () {
    test('always draws five days, planned or not', () {
      final view = _model.build(weekId: _weekId, plan: _plan);

      expect(view.dinners, hasLength(5));
      expect(view.dinners.map((d) => d.day), WeekPlanViewModel.plannedDays);
    });

    test('an unplanned day is an empty row, not a missing one', () {
      final view = _model.build(weekId: _weekId, plan: _plan);

      expect(view.dinners[0].recipeId, 'molokhia_chicken');
      expect(view.dinners[0].isPlanned, isTrue);
      expect(view.dinners[3].recipeId, isNull);
      expect(view.dinners[3].isPlanned, isFalse);
    });

    test('no document at all still renders five rows', () {
      final view = _model.build(weekId: _weekId);

      expect(view.dinners, hasLength(5));
      expect(view.hasPlan, isFalse);
      expect(view.groups, isEmpty);
      expect(view.itemCount, 0);
    });

    test('swapping one dinner leaves the others alone', () {
      final view = _model.build(weekId: _weekId, plan: _plan);
      final swapped = _model.swap(view, PlanDay.tue, 'ful_with_egg');

      expect(swapped.dinners[1].recipeId, 'ful_with_egg');
      expect(swapped.dinners[0].recipeId, 'molokhia_chicken');
      expect(swapped.dinners[2].recipeId, 'lentil_soup_eggs');
    });

    test('a swap does not disturb the grocery list', () {
      final view = _model.build(weekId: _weekId, plan: _plan);
      final swapped = _model.swap(view, PlanDay.tue, 'ful_with_egg');

      expect(swapped.itemCount, view.itemCount);
      expect(swapped.tickedCount, view.tickedCount);
    });
  });

  group('E08 — the grocery list', () {
    test('grouped the way she shops, in that order', () {
      final view = _model.build(weekId: _weekId, plan: _plan);

      expect(view.groups.map((g) => g.group), [
        GroceryGroup.vegetables,
        GroceryGroup.protein,
        GroceryGroup.cupboard,
      ]);
      expect(view.groups[0].lines, hasLength(3));
      expect(view.groups[1].lines, hasLength(2));
      expect(view.groups[2].lines, hasLength(1));
    });

    test('an empty group is omitted rather than drawn blank', () {
      final sparse = MealPlan(
        weekId: _weekId,
        groceries: {
          for (final line in [_line('rice', GroceryGroup.cupboard)])
            line.itemKey: line,
        },
      );
      final view = _model.build(weekId: _weekId, plan: sparse);

      expect(view.groups.map((g) => g.group), [GroceryGroup.cupboard]);
    });

    test('the counts are what the card states', () {
      final view = _model.build(weekId: _weekId, plan: _plan);

      expect(view.itemCount, 6);
      expect(view.tickedCount, 1);
      expect(view.isComplete, isFalse);
    });
  });

  group('ticking as she goes', () {
    test('a tick changes one line and moves nothing', () {
      final view = _model.build(weekId: _weekId, plan: _plan);
      final before = view.groups[0].lines.map((l) => l.ingredientId).toList();

      final ticked = _model.tick(
        view,
        groceryItemKey(ingredientId: 'onions', unit: 'kg'),
        true,
      );

      expect(
        ticked.groups[0].lines.map((l) => l.ingredientId),
        before,
        reason:
            'a list that reorders under her thumb mid-shop is harder to '
            'read than one that does not',
      );
      expect(
        ticked.groups[0].lines
            .firstWhere((l) => l.ingredientId == 'onions')
            .ticked,
        isTrue,
      );
      expect(ticked.tickedCount, 2);
    });

    test('un-ticking works too, and clears the time', () {
      final view = _model.build(weekId: _weekId, plan: _plan);
      final key = groceryItemKey(ingredientId: 'tomatoes', unit: 'kg');

      final unticked = _model.tick(view, key, false);
      final line = unticked.groups[0].lines.firstWhere((l) => l.itemKey == key);

      expect(line.ticked, isFalse);
      expect(line.tickedAt, isNull);
      expect(unticked.tickedCount, 0);
    });

    test('ticking every line completes the shop', () {
      var view = _model.build(weekId: _weekId, plan: _plan);
      for (final group in view.groups) {
        for (final line in group.lines) {
          view = _model.tick(view, line.itemKey, true);
        }
      }

      expect(view.tickedCount, view.itemCount);
      expect(view.isComplete, isTrue);
    });

    test('a tick on an unknown key changes nothing', () {
      final view = _model.build(weekId: _weekId, plan: _plan);
      final same = _model.tick(view, 'not-a-real-key', true);

      expect(same.tickedCount, view.tickedCount);
      expect(same.itemCount, view.itemCount);
    });

    test('the original view is unchanged — edits return a new one', () {
      final view = _model.build(weekId: _weekId, plan: _plan);
      _model.tick(
        view,
        groceryItemKey(ingredientId: 'onions', unit: 'kg'),
        true,
      );

      expect(view.tickedCount, 1);
    });
  });

  test('the same line from two devices converges on one key', () {
    // groceryItemKey is deterministic, so a tick made on a phone and a tablet
    // lands on the same map entry instead of ticking two separate lines.
    expect(
      groceryItemKey(ingredientId: 'tomatoes', unit: 'kg'),
      _lines.first.itemKey,
    );
  });
}
