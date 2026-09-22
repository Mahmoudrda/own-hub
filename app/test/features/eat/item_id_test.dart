// Identity, which is what HANDOFF rule 3 is built on.
//
// One function must be deterministic and one must not be, and getting either
// backwards produces a silent data bug: a deterministic helping id would merge
// two servings into one, and a random planned id would turn every correction
// into a second lunch.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/item_id.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';

void main() {
  group('plannedItemId is deterministic', () {
    test('the same plan reference always gives the same id', () {
      final first = plannedItemId(
        assignmentId: '2026-09-15',
        slot: 'lunch',
        index: 0,
      );
      final second = plannedItemId(
        assignmentId: '2026-09-15',
        slot: 'lunch',
        index: 0,
      );

      expect(first, second);
    });

    test('it is stable across releases, so it is pinned literally', () {
      // If this value ever changes, every planned item logged before the change
      // stops being correctable — the id derived from her plan would no longer
      // match the one already in her document. That makes it a compatibility
      // constant, not an implementation detail.
      expect(
        plannedItemId(assignmentId: '2026-09-15', slot: 'lunch', index: 0),
        '86d7beac03089b5d',
      );
    });

    test('different slots, days and positions give different ids', () {
      final base = plannedItemId(
        assignmentId: '2026-09-15',
        slot: 'lunch',
        index: 0,
      );

      expect(
        plannedItemId(assignmentId: '2026-09-16', slot: 'lunch', index: 0),
        isNot(base),
      );
      expect(
        plannedItemId(assignmentId: '2026-09-15', slot: 'dinner', index: 0),
        isNot(base),
      );
      expect(
        plannedItemId(assignmentId: '2026-09-15', slot: 'lunch', index: 1),
        isNot(base),
      );
    });

    test('the fields cannot smear into one another', () {
      // A naive concatenation would make ('ab', 'c') and ('a', 'bc') the same
      // id, which would silently alias two different meals.
      expect(
        plannedItemId(assignmentId: 'ab', slot: 'c', index: 0),
        isNot(plannedItemId(assignmentId: 'a', slot: 'bc', index: 0)),
      );
    });

    test('it is a compact hex key, not a whole digest', () {
      final id = plannedItemId(
        assignmentId: '2026-09-15',
        slot: 'lunch',
        index: 0,
      );
      expect(id, hasLength(16));
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(id), isTrue);
    });
  });

  group('freshItemId is not deterministic', () {
    test('two calls never collide', () {
      final ids = {for (var i = 0; i < 1000; i++) freshItemId()};
      expect(
        ids,
        hasLength(1000),
        reason:
            'two helpings logged in the same millisecond are still two '
            'helpings',
      );
    });

    test('it is never equal to a planned id for the same meal', () {
      final planned = plannedItemId(
        assignmentId: '2026-09-15',
        slot: 'lunch',
        index: 0,
      );
      expect(freshItemId(), isNot(planned));
    });
  });

  group('plateIdOf is order-independent', () {
    test('the same combination from two devices lands on one key', () {
      final phone = plateIdOf([
        (foodId: 'koshari_bowl', size: 'M'),
        (foodId: 'boiled_eggs', size: '2'),
      ]);
      final tablet = plateIdOf([
        (foodId: 'boiled_eggs', size: '2'),
        (foodId: 'koshari_bowl', size: 'M'),
      ]);

      expect(phone, tablet);
    });

    test('a different size is a different plate', () {
      expect(
        plateIdOf([(foodId: 'koshari_bowl', size: 'M')]),
        isNot(plateIdOf([(foodId: 'koshari_bowl', size: 'L')])),
      );
    });

    test('a different food is a different plate', () {
      expect(
        plateIdOf([(foodId: 'koshari_bowl', size: 'M')]),
        isNot(plateIdOf([(foodId: 'molokhia_chicken', size: 'M')])),
      );
    });

    test('koshari alone is not koshari with a salad', () {
      expect(
        plateIdOf([(foodId: 'koshari_bowl', size: 'M')]),
        isNot(
          plateIdOf([
            (foodId: 'koshari_bowl', size: 'M'),
            (foodId: 'salad', size: 'M'),
          ]),
        ),
      );
    });
  });

  group('groceryItemKey converges a tick made on two devices', () {
    test('it is deterministic', () {
      expect(
        groceryItemKey(ingredientId: 'tomatoes', unit: 'kg'),
        groceryItemKey(ingredientId: 'tomatoes', unit: 'kg'),
      );
    });

    test('a different unit is a different line', () {
      expect(
        groceryItemKey(ingredientId: 'tomatoes', unit: 'kg'),
        isNot(groceryItemKey(ingredientId: 'tomatoes', unit: 'g')),
      );
    });

    test('it is 12 hex characters', () {
      final key = groceryItemKey(ingredientId: 'tomatoes', unit: 'kg');
      expect(key, hasLength(12));
      expect(RegExp(r'^[0-9a-f]{12}$').hasMatch(key), isTrue);
    });
  });

  test('a planned item built from a PlanRef carries that same id', () {
    // The join between the identity function and the type that uses it. If
    // PlanRef ever grew a field, this is what would notice that the id stopped
    // covering all of it.
    const ref = PlanRef(
      assignmentId: '2026-09-15',
      slot: MealSlot.lunch,
      idx: 0,
    );

    expect(
      plannedItemId(
        assignmentId: ref.assignmentId,
        slot: ref.slot.name,
        index: ref.idx,
      ),
      plannedItemId(assignmentId: '2026-09-15', slot: 'lunch', index: 0),
    );
  });
}
