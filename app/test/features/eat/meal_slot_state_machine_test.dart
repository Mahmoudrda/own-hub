// The meal slot state machine — G5 §3.1, including its illegal transitions.
//
// The table in the plan lists the legal moves and then names three illegal
// ones. Testing only the legal moves would leave the illegal ones enforced by
// nothing, which is how `absent → logged` becomes a day document with items and
// no totals.
//
// Rule 1 is the reason `planned` exists at all: a slot with an assignment
// renders the prescription and writes NOTHING. That branch is unreachable in
// the MVP — G2 publishes `assignment.meal == null` for the whole cut — so these
// are the only tests that exercise it, and they are what stop coaching having
// to retrofit the rule later.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_slot_state_machine.dart';

const _machine = MealSlotStateMachine();
const _dayId = '2026-09-15';

final _food = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl'],
  allergens: const <String>{},
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 470, proteinG: 21)],
);

MealDay _dayWith(MealSlot slot, {int items = 1}) => MealDay(
  dayId: _dayId,
  slots: {
    slot: [
      for (var i = 0; i < items; i++)
        MealItem(
          itemId: 'item-$i',
          foodId: 'koshari_bowl',
          servings: 1,
          size: 'M',
          loggedAt: DateTime(2026, 9, 15, 13, i),
          source: MealSource.search,
          origin: MealOrigin.search,
          kcal: 470,
          proteinG: 21,
        ),
    ],
  },
);

void main() {
  group('resolve — what the slot looks like now', () {
    test('no day document at all is absent', () {
      expect(
        _machine.resolve(day: null, slot: MealSlot.lunch),
        MealSlotState.absent,
      );
    });

    test('an untouched day is absent, which is what renders E09', () {
      expect(
        _machine.resolve(
          day: const MealDay(dayId: _dayId),
          slot: MealSlot.lunch,
        ),
        MealSlotState.absent,
      );
    });

    test('a slot with items is logged', () {
      expect(
        _machine.resolve(day: _dayWith(MealSlot.lunch), slot: MealSlot.lunch),
        MealSlotState.logged,
      );
    });

    test('another slot on a day she has started is empty, not absent', () {
      expect(
        _machine.resolve(
          day: _dayWith(MealSlot.breakfast),
          slot: MealSlot.lunch,
        ),
        MealSlotState.empty,
        reason: 'she has eaten today, so Eat is not on its first-run branch',
      );
    });

    test('a skipped slot reads as skipped', () {
      const day = MealDay(dayId: _dayId, skipped: {MealSlot.dinner});
      expect(
        _machine.resolve(day: day, slot: MealSlot.dinner),
        MealSlotState.skipped,
      );
    });

    test('logging into a skipped slot wins — a skip is never final', () {
      final day = MealDay(
        dayId: _dayId,
        slots: _dayWith(MealSlot.dinner).slots,
        skipped: const {MealSlot.dinner},
      );
      expect(
        _machine.resolve(day: day, slot: MealSlot.dinner),
        MealSlotState.logged,
      );
    });

    group('rule 1 — a prescribed value is never a result', () {
      test('an assignment renders planned', () {
        expect(
          _machine.resolve(
            day: const MealDay(dayId: _dayId),
            slot: MealSlot.lunch,
            hasAssignment: true,
          ),
          MealSlotState.planned,
        );
      });

      test('and the slot is still empty in the document', () {
        // The whole of rule 1 in one assertion: being shown a prescription
        // writes nothing, so there is no logged item to mistake for a result.
        const day = MealDay(dayId: _dayId);
        expect(
          _machine.resolve(day: day, slot: MealSlot.lunch, hasAssignment: true),
          MealSlotState.planned,
        );
        expect(day.itemsIn(MealSlot.lunch), isEmpty);
        expect(day.hasNothingLogged, isTrue);
      });

      test('an assignment never un-logs a slot she has already filled', () {
        expect(
          _machine.resolve(
            day: _dayWith(MealSlot.lunch),
            slot: MealSlot.lunch,
            hasAssignment: true,
          ),
          MealSlotState.logged,
        );
        expect(
          _machine.next(MealSlotState.logged, MealSlotEvent.assignmentArrived),
          MealSlotState.logged,
        );
      });
    });
  });

  group('next — the legal transitions', () {
    test('empty → logged', () {
      expect(
        _machine.next(MealSlotState.empty, MealSlotEvent.logItems),
        MealSlotState.logged,
      );
    });

    test('planned → logged', () {
      expect(
        _machine.next(MealSlotState.planned, MealSlotEvent.logItems),
        MealSlotState.logged,
      );
    });

    test('planned → skipped, and skipped → logged', () {
      expect(
        _machine.next(MealSlotState.planned, MealSlotEvent.skipSlot),
        MealSlotState.skipped,
      );
      expect(
        _machine.next(MealSlotState.skipped, MealSlotEvent.logItems),
        MealSlotState.logged,
      );
    });

    test('logged → corrected, and correcting again is idempotent', () {
      expect(
        _machine.next(MealSlotState.logged, MealSlotEvent.correctPlannedLog),
        MealSlotState.corrected,
      );
      expect(
        _machine.next(MealSlotState.corrected, MealSlotEvent.correctPlannedLog),
        MealSlotState.corrected,
      );
    });

    test('a helping leaves the slot where it was', () {
      expect(
        _machine.next(MealSlotState.logged, MealSlotEvent.addHelping),
        MealSlotState.logged,
        reason: 'a helping adds an item; it does not correct one',
      );
      expect(
        _machine.next(MealSlotState.corrected, MealSlotEvent.addHelping),
        MealSlotState.corrected,
      );
    });

    test('removing the last item empties the slot', () {
      expect(
        _machine.next(MealSlotState.logged, MealSlotEvent.removeLastItem),
        MealSlotState.empty,
      );
    });
  });

  group('next — the illegal transitions §3.1 names', () {
    test('absent → logged throws: a log needs a day document', () {
      expect(
        () => _machine.next(MealSlotState.absent, MealSlotEvent.logItems),
        throwsA(isA<StateError>()),
      );
    });

    test('correcting something that was never logged throws', () {
      for (final from in [
        MealSlotState.absent,
        MealSlotState.empty,
        MealSlotState.planned,
        MealSlotState.skipped,
      ]) {
        expect(
          () => _machine.next(from, MealSlotEvent.correctPlannedLog),
          throwsA(isA<StateError>()),
          reason: '$from has nothing to correct',
        );
      }
    });

    test('a helping with no first serving throws', () {
      for (final from in [
        MealSlotState.empty,
        MealSlotState.planned,
        MealSlotState.skipped,
      ]) {
        expect(
          () => _machine.next(from, MealSlotEvent.addHelping),
          throwsA(isA<StateError>()),
          reason: 'a SECOND serving requires a first one',
        );
      }
    });

    test('undo is not a transition at all', () {
      // §4.2: the five seconds run before the write, so an undone log never
      // changed the slot. Modelling undo as a state change would imply there is
      // something to roll back, and there never is.
      expect(
        () => _machine.next(MealSlotState.logged, MealSlotEvent.undoPending),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('refuseLog — the three conditions checked before any write', () {
    test('no day document refuses the log', () {
      final refusal = _machine.refuseLog(
        day: null,
        food: _food,
        assessment: AllergyAssessment.clear,
      );
      expect(refusal!.reason, LogRefusalReason.noDayContext);
    });

    test('a food outside the pack refuses the log', () {
      final refusal = _machine.refuseLog(
        day: const MealDay(dayId: _dayId),
        food: null,
        assessment: AllergyAssessment.clear,
      );
      expect(refusal!.reason, LogRefusalReason.foodNotInPack);
    });

    test('an outstanding allergen verdict refuses the log', () {
      final refusal = _machine.refuseLog(
        day: const MealDay(dayId: _dayId),
        food: _food,
        assessment: AllergyAssessment.blocked(
          AllergyBlockReason.namedAllergen,
          allergens: {'nuts'},
        ),
      );
      expect(refusal!.reason, LogRefusalReason.allergenOutstanding);
      expect(refusal.assessment!.allergens, {'nuts'});
    });

    test('an ordinary log is not refused', () {
      expect(
        _machine.refuseLog(
          day: const MealDay(dayId: _dayId),
          food: _food,
          assessment: AllergyAssessment.clear,
        ),
        isNull,
      );
    });
  });
}
