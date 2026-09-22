// P0-MEAL / P0-INTAKE-03 / P0-INTAKE-04 at the client's end of the coached
// meal path — G10 and G11.
//
// The point of these is that this feature **adds no safety logic of its own**.
// Every verdict below comes from `AllergyGuard`, and every write from
// `MealLogService`. A second implementation of either would be the weaker one.
//
// The foods are deliberately not the suite's usual koshari fixtures: a sesame
// bowl at 617 kcal and a lentil soup at 288, so a test that recognised the
// fixture rather than reading the guard would fail.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/g2_contract.dart';
import 'package:own_hub/features/coached/domain/planned_meal.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_slot_state_machine.dart';

const _assignmentId = '2026-09-19';

final _sesameBowl = Food(
  foodId: 'sesame_freekeh_bowl',
  names: const ['Freekeh bowl with tahini'],
  allergens: const {'sesame'},
  dietTags: const {'vegetarian'},
  popularity: 41,
  sizes: const [
    FoodSize(id: 'M', label: 'Medium', kcal: 617, proteinG: 23),
    FoodSize(id: 'L', label: 'Large', kcal: 806, proteinG: 31),
  ],
);

final _lentilSoup = Food(
  foodId: 'lentil_soup',
  names: const ['Lentil soup'],
  allergens: const <String>{},
  dietTags: const {'vegetarian'},
  popularity: 66,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 288, proteinG: 17)],
);

/// A dish the pack knows nothing about the allergens of.
final _unknownDish = Food(
  foodId: 'aunts_stew',
  names: const ["Aunt's stew"],
  popularity: 3,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 430, proteinG: 26)],
);

final _library = FoodLibrary([_sesameBowl, _lentilSoup, _unknownDish]);

MealAssignment _assignment() => MealAssignment(
  slots: {
    MealSlot.lunch: [
      AssignedMealItem(
        foodId: 'sesame_freekeh_bowl',
        servings: 1,
        sizeId: 'M',
        coachNote: 'Add the salad if you are still hungry after.',
        alternatives: const ['lentil_soup'],
      ),
      AssignedMealItem(foodId: 'lentil_soup', servings: 1, sizeId: 'M'),
    ],
  },
);

PlannedMealService _service(AllergyGuard guard) => PlannedMealService(
  library: _library,
  guard: guard,
  logs: MealLogService(
    repository: InMemoryMealRepository(),
    library: _library,
    guard: guard,
  ),
);

MealDay _day() => const MealDay(dayId: _assignmentId, tz: 'Africa/Cairo');

void main() {
  group('P0-INTAKE-03 — a conflicting planned row is disabled with its reason', () {
    test('the row is blocked before she taps, and names the allergen', () {
      final service = _service(
        const AllergyGuard(
          DietaryConstraints(allergies: {'sesame'}, dietary: {}),
        ),
      );

      final rows = service.screenAssignment(_assignment(), MealSlot.lunch);

      expect(rows, hasLength(2));
      expect(rows.first.isBlocked, isTrue);
      expect(rows.first.allergens, {'sesame'});
      expect(rows.first.assessment.reason, AllergyBlockReason.namedAllergen);
      // The second row is clear, so one blocked item does not disable the slot.
      expect(rows.last.isBlocked, isFalse);
    });

    test('the log is refused, and the refusal is the guard\'s own', () {
      final service = _service(
        const AllergyGuard(
          DietaryConstraints(allergies: {'sesame'}, dietary: {}),
        ),
      );
      final rows = service.screenAssignment(_assignment(), MealSlot.lunch);

      final outcome = service.logPlanned(
        day: _day(),
        row: rows.first,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13, 20),
      );

      expect(outcome, isA<MealLogRefused>());
      final refused = outcome as MealLogRefused;
      expect(refused.reason, LogRefusalReason.allergenOutstanding);
      expect(refused.assessment!.allergens, {'sesame'});
    });

    test('an explicit acknowledgement clears the block she named', () {
      final service = _service(
        const AllergyGuard(
          DietaryConstraints(allergies: {'sesame'}, dietary: {}),
        ),
      );
      final rows = service.screenAssignment(
        _assignment(),
        MealSlot.lunch,
        acknowledged: const {'sesame'},
      );

      expect(rows.first.isBlocked, isFalse);

      final outcome = service.logPlanned(
        day: _day(),
        row: rows.first,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13, 20),
        acknowledged: const {'sesame'},
      );
      expect(outcome, isA<MealLogPrepared>());
    });
  });

  group('P0-INTAKE-04 — unknown constraints fail closed', () {
    test('with no profile at all, a planned row will not log', () {
      final service = _service(const AllergyGuard(DietaryConstraints.unknown));
      final rows = service.screenAssignment(_assignment(), MealSlot.lunch);

      expect(rows.first.isBlocked, isTrue);
      expect(
        rows.first.assessment.reason,
        AllergyBlockReason.constraintsUnavailable,
      );

      final outcome = service.logPlanned(
        day: _day(),
        row: rows.last,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13, 20),
      );
      expect(
        outcome,
        isA<MealLogRefused>(),
        reason: 'unknown is not absent — the guard holds the line at log time',
      );
    });

    test('a dish with no allergen data blocks a woman who has an allergy', () {
      final service = _service(
        const AllergyGuard(
          DietaryConstraints(allergies: {'shellfish'}, dietary: {}),
        ),
      );
      final assignment = MealAssignment(
        slots: {
          MealSlot.dinner: [
            AssignedMealItem(foodId: 'aunts_stew', servings: 1, sizeId: 'M'),
          ],
        },
      );

      final row = service.screenAssignment(assignment, MealSlot.dinner).single;
      expect(row.isBlocked, isTrue);
      expect(row.assessment.reason, AllergyBlockReason.unknownAllergenData);
    });

    test('a food the pack does not hold is refused, never invented', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      final assignment = MealAssignment(
        slots: {
          MealSlot.lunch: [
            AssignedMealItem(foodId: 'not_in_pack', servings: 1, sizeId: 'M'),
          ],
        },
      );

      final row = service.screenAssignment(assignment, MealSlot.lunch).single;
      expect(row.food, isNull);
      expect(row.isBlocked, isTrue);

      final outcome = service.logPlanned(
        day: _day(),
        row: row,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13),
      );
      expect(
        (outcome as MealLogRefused).reason,
        LogRefusalReason.foodNotInPack,
      );
    });
  });

  group('G11 — one log, corrected in place', () {
    test('logging the same row twice corrects rather than doubles', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      final row = service.screenAssignment(_assignment(), MealSlot.lunch).last;

      final first = service.logPlanned(
        day: _day(),
        row: row,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13, 20),
      ) as MealLogPrepared;

      // Her first log is now in the day.
      final afterFirst = MealDay(
        dayId: _assignmentId,
        slots: {MealSlot.lunch: first.items},
        tz: 'Africa/Cairo',
      );

      final second = service.logPlanned(
        day: afterFirst,
        row: row,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13, 26),
        servings: 2,
      ) as MealLogPrepared;

      // The same deterministic id, so the write replaces rather than appends.
      expect(second.items.single.itemId, first.items.single.itemId);
      expect(second.write.removed, hasLength(1));
      expect(second.write.added, hasLength(1));
      expect(second.items.single.servings, 2);
    });

    test('a second helping is a different method, and removes nothing', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      final row = service.screenAssignment(_assignment(), MealSlot.lunch).last;
      final first = service.logPlanned(
        day: _day(),
        row: row,
        assignmentId: _assignmentId,
        at: DateTime(2026, 9, 19, 13, 20),
      ) as MealLogPrepared;

      final helping = service.addHelping(
        day: MealDay(
          dayId: _assignmentId,
          slots: {MealSlot.lunch: first.items},
          tz: 'Africa/Cairo',
        ),
        slot: MealSlot.lunch,
        of: first.items.single,
        at: DateTime(2026, 9, 19, 14, 5),
      ) as MealLogPrepared;

      expect(helping.write.removed, isEmpty);
      expect(
        helping.items.single.itemId,
        isNot(first.items.single.itemId),
        reason: 'a helping is a second item, not a correction',
      );
      expect(helping.items.single.helpingOf, first.items.single.itemId);
    });

    test('the coach\'s note travels with the row', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      final rows = service.screenAssignment(_assignment(), MealSlot.lunch);
      expect(rows.first.coachNote, contains('salad'));
      expect(rows.last.coachNote, isNull);
    });
  });

  group('the protein target', () {
    test('the coach\'s target is used when she set one', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      expect(
        service.proteinTargetFor(
          const CoachAssignment(
            dateKey: _assignmentId,
            planVersion: 'v4',
            nutrition: NutritionAssignment(proteinTargetG: 88),
          ),
        ),
        88,
      );
    });

    test('with no coach target, this feature invents none', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      expect(
        service.proteinTargetFor(
          const CoachAssignment(dateKey: _assignmentId, planVersion: 'v4'),
        ),
        isNull,
      );
      expect(service.proteinTargetFor(null), isNull);
    });
  });

  group('negative controls', () {
    test('a slot the coach left free yields no rows, not an empty apology', () {
      final service = _service(const AllergyGuard(DietaryConstraints.none));
      expect(
        service.screenAssignment(_assignment(), MealSlot.breakfast),
        isEmpty,
      );
    });

    test('an item that is neither a food nor a recipe cannot be built', () {
      expect(
        () => AssignedMealItem(servings: 1, sizeId: 'M'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => AssignedMealItem(
          foodId: 'lentil_soup',
          recipeId: 'r9',
          servings: 1,
          sizeId: 'M',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a dietary preference never produces a warning sheet', () {
      // The asymmetry G5 insists on: an allergy blocks, a preference filters
      // suggestions silently. A coach-assigned item is not a suggestion, so a
      // non-vegetarian dish for a vegetarian is not blocked here — it is her
      // coach's choice and she can see it.
      final service = _service(
        const AllergyGuard(
          DietaryConstraints(allergies: {}, dietary: {'vegetarian'}),
        ),
      );
      final rows = service.screenAssignment(_assignment(), MealSlot.lunch);
      expect(rows.every((r) => !r.isBlocked), isTrue);
    });
  });
}
