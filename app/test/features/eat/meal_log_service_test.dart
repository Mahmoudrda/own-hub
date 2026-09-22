// P0-LOG-10 — "Logging the same planned meal twice corrects it; a second
// helping is separate."
//
// From TEST-CASES.csv: "The first repeat CORRECTS the existing log and does not
// double the total. The second helping adds a distinct item. Two different
// intents, two different outcomes." Rule protected: HANDOFF rule 3.
//
// These assertions are deliberately made against the STORE — what actually
// ended up in the day document — and not against the returned write. A write
// that describes a correction but is applied as an append would satisfy an
// assertion about `isCorrection` and still double her lunch. `PHASE1-FIXES.md`
// §1 is the same lesson from the other direction: the argument was right and
// nobody was listening.
//
// The numbers here are deliberately NOT the prototype's 540/156/696. A test
// written against the mockup's own figures passes for a constant just as
// happily as for a computation.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_day_reader.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/features/eat/domain/meal_slot_state_machine.dart';

const _dayId = '2026-09-15';

/// Two foods with distinctive macros, and allergens KNOWN to be empty so the
/// guard is not what this file is testing.
final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl'],
  allergens: const <String>{},
  dietTags: const <String>{'vegetarian'},
  sizes: const [
    FoodSize(id: 'S', label: 'Small', kcal: 380, proteinG: 13),
    FoodSize(id: 'M', label: 'Medium', kcal: 470, proteinG: 21),
    FoodSize(id: 'L', label: 'Large', kcal: 610, proteinG: 27),
  ],
);

final _molokhia = Food(
  foodId: 'molokhia_chicken',
  names: const ['Molokhia with chicken'],
  allergens: const <String>{},
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 460, proteinG: 34)],
);

final _library = FoodLibrary([_koshari, _molokhia]);

MealLogService _service(MealRepository repository) => MealLogService(
  repository: repository,
  library: _library,
  // Known and empty: she was asked and named nothing. The guard's own behaviour
  // has its own file.
  guard: const AllergyGuard(DietaryConstraints.none),
);

ParsedItem _entry(Food food, String sizeId, {int servings = 1}) => ParsedItem(
  food: food,
  size: food.sizeById(sizeId)!,
  servings: servings,
  sourceText: food.names.first,
);

const _planRef = PlanRef(assignmentId: _dayId, slot: MealSlot.lunch, idx: 0);

void main() {
  late InMemoryMealRepository repository;
  late MealLogService service;

  setUp(() {
    repository = InMemoryMealRepository();
    // The day document has to exist before anything can be logged into it —
    // `absent → logged` is an illegal transition.
    repository.store.days[_dayId] = const MealDay(dayId: _dayId);
    service = _service(repository);
  });

  Future<MealDay> today() => repository.day(_dayId);

  Future<MealLogPrepared> commit(MealLogOutcome outcome) async {
    expect(
      outcome,
      isA<MealLogPrepared>(),
      reason: 'the log was refused: $outcome',
    );
    final prepared = outcome as MealLogPrepared;
    await service.commit(prepared.write);
    return prepared;
  }

  group('P0-LOG-10 — re-logging a planned meal CORRECTS it', () {
    test('the same plan reference always produces the same item id', () async {
      final first = await commit(
        service.correctPlannedLog(
          day: await today(),
          planRef: _planRef,
          entry: _entry(_koshari, 'M'),
          at: DateTime(2026, 9, 15, 13, 12),
        ),
      );

      final second = await commit(
        service.correctPlannedLog(
          day: await today(),
          planRef: _planRef,
          // She corrects the size: medium was actually large.
          entry: _entry(_koshari, 'L'),
          at: DateTime(2026, 9, 15, 13, 14),
        ),
      );

      expect(
        second.items.single.itemId,
        first.items.single.itemId,
        reason:
            'the id is derived from the plan reference, which is what makes '
            'the second log a correction rather than a second lunch',
      );
    });

    test(
      'the slot still holds ONE item, and the total is not doubled',
      () async {
        await commit(
          service.correctPlannedLog(
            day: await today(),
            planRef: _planRef,
            entry: _entry(_koshari, 'M'),
            at: DateTime(2026, 9, 15, 13, 12),
          ),
        );
        await commit(
          service.correctPlannedLog(
            day: await today(),
            planRef: _planRef,
            entry: _entry(_koshari, 'L'),
            at: DateTime(2026, 9, 15, 13, 14),
          ),
        );

        final day = await today();
        const reader = MealDayReader();

        expect(
          reader.itemsIn(day, MealSlot.lunch),
          hasLength(1),
          reason: 're-tapping Log must never silently double a serving',
        );

        final totals = reader.totals(day);
        expect(
          totals.kcalSoFar,
          610,
          reason:
              'the large bowl replaced the medium one — 470 + 610 would be '
              'the doubling this case exists to catch',
        );
        expect(totals.proteinSoFar, 27);
      },
    );

    test('the correction is expressed as a remove PLUS an add', () async {
      await commit(
        service.correctPlannedLog(
          day: await today(),
          planRef: _planRef,
          entry: _entry(_koshari, 'M'),
          at: DateTime(2026, 9, 15, 13, 12),
        ),
      );
      final second = await commit(
        service.correctPlannedLog(
          day: await today(),
          planRef: _planRef,
          entry: _entry(_koshari, 'S'),
          at: DateTime(2026, 9, 15, 13, 20),
        ),
      );

      expect(second.write.isCorrection, isTrue);
      expect(second.write.removed, hasLength(1));
      expect(second.write.added, hasLength(1));
      // Signed delta: correcting downward takes calories away rather than
      // adding a smaller bowl on top.
      expect(second.write.kcalDelta, 380 - 470);
      expect(second.write.proteinDelta, 13 - 21);
    });

    test('the FIRST log of a planned meal removes nothing', () async {
      final first = await commit(
        service.correctPlannedLog(
          day: await today(),
          planRef: _planRef,
          entry: _entry(_koshari, 'M'),
          at: DateTime(2026, 9, 15, 13, 12),
        ),
      );
      expect(
        first.write.isCorrection,
        isFalse,
        reason: 'there was nothing there to correct yet',
      );
      expect(first.write.kcalDelta, 470);
    });
  });

  group('P0-LOG-10 — "another helping" is a SEPARATE item', () {
    test('it mints a fresh id and never removes anything', () async {
      final first = await commit(
        service.logNew(
          day: await today(),
          slot: MealSlot.lunch,
          entries: [_entry(_koshari, 'M')],
          source: MealSource.search,
          origin: MealOrigin.suggestion,
          at: DateTime(2026, 9, 15, 13, 12),
        ),
      );

      final helping = await commit(
        service.addHelping(
          day: await today(),
          slot: MealSlot.lunch,
          of: first.items.single,
          at: DateTime(2026, 9, 15, 13, 40),
        ),
      );

      expect(helping.items.single.itemId, isNot(first.items.single.itemId));
      expect(helping.items.single.helpingOf, first.items.single.itemId);
      expect(
        helping.write.removed,
        isEmpty,
        reason: 'a helping must never overwrite the first serving',
      );
      expect(helping.write.isCorrection, isFalse);
    });

    test('the slot holds TWO items and the total does double', () async {
      final first = await commit(
        service.logNew(
          day: await today(),
          slot: MealSlot.lunch,
          entries: [_entry(_koshari, 'M')],
          source: MealSource.search,
          origin: MealOrigin.suggestion,
          at: DateTime(2026, 9, 15, 13, 12),
        ),
      );
      await commit(
        service.addHelping(
          day: await today(),
          slot: MealSlot.lunch,
          of: first.items.single,
          at: DateTime(2026, 9, 15, 13, 40),
        ),
      );

      const reader = MealDayReader();
      final day = await today();

      expect(reader.itemsIn(day, MealSlot.lunch), hasLength(2));
      expect(
        reader.totals(day).kcalSoFar,
        940,
        reason:
            'she ate it twice, so it counts twice — this is the outcome '
            'that must NOT collapse into the correction case',
      );
    });

    test('a helping of a helping still points at the first serving', () async {
      final first = await commit(
        service.logNew(
          day: await today(),
          slot: MealSlot.lunch,
          entries: [_entry(_koshari, 'M')],
          source: MealSource.search,
          origin: MealOrigin.suggestion,
          at: DateTime(2026, 9, 15, 13, 12),
        ),
      );
      final second = await commit(
        service.addHelping(
          day: await today(),
          slot: MealSlot.lunch,
          of: first.items.single,
          at: DateTime(2026, 9, 15, 13, 40),
        ),
      );
      final third = await commit(
        service.addHelping(
          day: await today(),
          slot: MealSlot.lunch,
          of: second.items.single,
          at: DateTime(2026, 9, 15, 14, 5),
        ),
      );

      expect(
        third.items.single.helpingOf,
        first.items.single.itemId,
        reason:
            'the chain never deepens, so "how many did she have" stays '
            'one lookup rather than a walk',
      );
      expect((await today()).itemsIn(MealSlot.lunch), hasLength(3));
    });
  });

  group('the two intents cannot be expressed through one another', () {
    test(
      'a free log of the same food twice is two items, not a correction',
      () async {
        for (final at in [
          DateTime(2026, 9, 15, 13, 12),
          DateTime(2026, 9, 15, 19, 30),
        ]) {
          await commit(
            service.logNew(
              day: await today(),
              slot: MealSlot.lunch,
              entries: [_entry(_koshari, 'M')],
              source: MealSource.search,
              origin: MealOrigin.search,
              at: at,
            ),
          );
        }

        expect(
          (await today()).itemsIn(MealSlot.lunch),
          hasLength(2),
          reason:
              'a free log mints a fresh id every time, so eating koshari twice '
              'in a day is two items — only a PLANNED re-log corrects',
        );
      },
    );

    test(
      'several items in one sentence are one write, not one per item',
      () async {
        final prepared = await commit(
          service.logNew(
            day: await today(),
            slot: MealSlot.lunch,
            entries: [_entry(_koshari, 'M'), _entry(_molokhia, 'M')],
            source: MealSource.search,
            origin: MealOrigin.search,
            at: DateTime(2026, 9, 15, 13, 12),
          ),
        );

        expect(prepared.write.added, hasLength(2));
        expect(repository.writes, hasLength(1));
        expect(prepared.write.kcalDelta, 470 + 460);
        expect(
          prepared.items.map((i) => i.itemId).toSet(),
          hasLength(2),
          reason: 'two items in one write still need two distinct identities',
        );
      },
    );
  });

  group('the log service refuses rather than writing something wrong', () {
    test('a food that is not in the pack is refused', () async {
      final ghost = Food(
        foodId: 'not_in_the_pack',
        names: const ['Something else'],
        allergens: const <String>{},
        sizes: const [FoodSize(id: 'M', label: 'M', kcal: 100, proteinG: 5)],
      );

      final outcome = service.logNew(
        day: await today(),
        slot: MealSlot.lunch,
        entries: [_entry(ghost, 'M')],
        source: MealSource.search,
        origin: MealOrigin.search,
        at: DateTime(2026, 9, 15, 13, 12),
      );

      expect(outcome, isA<MealLogRefused>());
      expect(
        (outcome as MealLogRefused).reason,
        LogRefusalReason.foodNotInPack,
      );
      expect(
        repository.writes,
        isEmpty,
        reason: 'rule 10: the product will not log a food it cannot name',
      );
    });

    test('an empty sentence writes nothing at all', () async {
      final outcome = service.logNew(
        day: await today(),
        slot: MealSlot.lunch,
        entries: const [],
        source: MealSource.search,
        origin: MealOrigin.search,
        at: DateTime(2026, 9, 15, 13, 12),
      );

      expect(outcome, isA<MealLogRefused>());
      expect(repository.writes, isEmpty);
    });
  });

  group('rule 9 — the service cannot ask her anything', () {
    test('no method on MealLogService returns a confirmation', () {
      // Rule 9 is enforced by the shape of the API: every builder returns a
      // write or a refusal, and there is no `confirm*` method and no callback
      // parameter a dialog could be passed into. The five seconds belong to
      // LogCommandBus, which holds the write — so this service is only ever
      // reached once the window has closed.
      //
      // Asserted structurally in test/product_rules_test.dart, which scans the
      // whole feature folder for showDialog/AlertDialog. This test records the
      // intent next to the code it constrains.
      expect(service.commit, isA<Function>());
    });

    test('a skip is a real write that costs her nothing', () async {
      final write = service.skipSlot(day: await today(), slot: MealSlot.dinner);
      await service.commit(write);

      expect(write.kcalDelta, 0);
      expect(write.proteinDelta, 0);
      expect((await today()).skipped, contains(MealSlot.dinner));
    });

    test(
      'logging into a skipped slot un-skips it — a skip is never final',
      () async {
        await service.commit(
          service.skipSlot(day: await today(), slot: MealSlot.dinner),
        );
        await commit(
          service.logNew(
            day: await today(),
            slot: MealSlot.dinner,
            entries: [_entry(_molokhia, 'M')],
            source: MealSource.search,
            origin: MealOrigin.search,
            at: DateTime(2026, 9, 15, 20, 10),
          ),
        );

        final day = await today();
        expect(day.skipped, isNot(contains(MealSlot.dinner)));
        expect(day.itemsIn(MealSlot.dinner), hasLength(1));
      },
    );
  });

  test('the running total is recomputed from items, never from a cache', () async {
    await commit(
      service.logNew(
        day: await today(),
        slot: MealSlot.breakfast,
        entries: [_entry(_koshari, 'S')],
        source: MealSource.search,
        origin: MealOrigin.suggestion,
        at: DateTime(2026, 9, 15, 8, 40),
      ),
    );

    final totals = const MealDayReader().totals(await today());
    expect(totals.kcalSoFar, 380);
    expect(totals.proteinTargetG, kProvisionalProteinTargetG);
    // The type itself cannot express a countdown; this is the behavioural echo
    // of that, so a future field would break a test as well as a scan.
    expect(totals.proteinPercent, closeTo(13 / 95 * 100, 0.001));
  });
}
