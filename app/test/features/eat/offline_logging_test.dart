// P0-LOG-09 — "Log offline, sync later", the meal half.
//
// From TEST-CASES.csv: precondition "Airplane mode", steps "Log a set and a meal
// offline > re-enable network", expected "Both save locally and appear
// immediately. They sync on reconnect with no duplicates and no data loss."
//
// `PHASE1-ACCEPTANCE.md` marked this "not yet reachable" because Eat did not
// exist; the set half was closed in Phase 1 and this is the half that closes
// now. `PHASE2-ACCEPTANCE.md` lists it among the eleven Phase 1 rows to re-run
// at the end of Phase 2 — "the real proof that the week and logging machinery
// joined up".
//
// The subtle assertion is the last group. G5 §4.2: because the five-second undo
// happens BEFORE the write, an undo offline is not a compensating write sitting
// in the sync queue — it is **the absence of a write**. A write-then-delete
// design would push two operations through the reconnect and could fire G6's
// once-a-day points hook for a meal she cancelled.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_day_reader.dart';
import 'package:own_hub/features/eat/domain/meal_log_service.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';

const _dayId = '2026-09-15';
final _at = DateTime(2026, 9, 15, 13, 12);

final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl'],
  allergens: const <String>{},
  sizes: const [
    FoodSize(id: 'M', label: 'Medium', kcal: 470, proteinG: 21),
    FoodSize(id: 'L', label: 'Large', kcal: 610, proteinG: 27),
  ],
);

final _library = FoodLibrary([_koshari]);

ParsedItem _entry({String size = 'M'}) => ParsedItem(
  food: _koshari,
  size: _koshari.sizeById(size)!,
  servings: 1,
  sourceText: 'Koshari bowl',
);

({InMemoryMealRepository repository, MealLogService service}) _offline() {
  final repository = InMemoryMealRepository();
  repository.store.days[_dayId] = const MealDay(dayId: _dayId);
  repository.goOffline();
  return (
    repository: repository,
    service: MealLogService(
      repository: repository,
      library: _library,
      guard: const AllergyGuard(DietaryConstraints.none),
    ),
  );
}

MealWrite _writeOf(MealLogOutcome outcome) {
  expect(outcome, isA<MealLogPrepared>());
  return (outcome as MealLogPrepared).write;
}

void main() {
  group('P0-LOG-09 — it saves locally and appears immediately', () {
    test('the meal is hers the moment she taps, with no signal', () async {
      final (:repository, :service) = _offline();

      await service.commit(
        _writeOf(
          service.logNew(
            day: await repository.day(_dayId),
            slot: MealSlot.lunch,
            entries: [_entry()],
            source: MealSource.search,
            origin: MealOrigin.suggestion,
            at: _at,
          ),
        ),
      );

      // Visible to her straight away...
      final local = await repository.day(_dayId);
      expect(local.itemsIn(MealSlot.lunch), hasLength(1));
      expect(const MealDayReader().totals(local).kcalSoFar, 470);

      // ...and not yet on the server.
      expect(repository.store.days[_dayId]!.itemsIn(MealSlot.lunch), isEmpty);
      expect(repository.pending, hasLength(1));
    });

    test('it syncs on reconnect, exactly once', () async {
      final (:repository, :service) = _offline();

      await service.commit(
        _writeOf(
          service.logNew(
            day: await repository.day(_dayId),
            slot: MealSlot.lunch,
            entries: [_entry()],
            source: MealSource.search,
            origin: MealOrigin.suggestion,
            at: _at,
          ),
        ),
      );

      await repository.goOnline();

      expect(
        repository.store.days[_dayId]!.itemsIn(MealSlot.lunch),
        hasLength(1),
      );
      expect(repository.pending, isEmpty);
    });

    test('reconnecting twice does not log it twice', () async {
      final (:repository, :service) = _offline();

      await service.commit(
        _writeOf(
          service.logNew(
            day: await repository.day(_dayId),
            slot: MealSlot.lunch,
            entries: [_entry()],
            source: MealSource.search,
            origin: MealOrigin.suggestion,
            at: _at,
          ),
        ),
      );

      await repository.goOnline();
      await repository.goOnline();

      expect(
        repository.store.days[_dayId]!.itemsIn(MealSlot.lunch),
        hasLength(1),
        reason: 'the queue drained once; a second drain has nothing to replay',
      );
    });

    test('several meals logged offline all survive, in order', () async {
      final (:repository, :service) = _offline();

      for (final slot in [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.dinner,
      ]) {
        await service.commit(
          _writeOf(
            service.logNew(
              day: await repository.day(_dayId),
              slot: slot,
              entries: [_entry()],
              source: MealSource.search,
              origin: MealOrigin.suggestion,
              at: _at,
            ),
          ),
        );
      }

      expect(repository.pending, hasLength(3));
      await repository.goOnline();

      final day = repository.store.days[_dayId]!;
      expect(day.itemsIn(MealSlot.breakfast), hasLength(1));
      expect(day.itemsIn(MealSlot.lunch), hasLength(1));
      expect(day.itemsIn(MealSlot.dinner), hasLength(1));
      expect(
        const MealDayReader().totals(day).kcalSoFar,
        1410,
        reason: 'no data loss: three meals at 470 each',
      );
    });
  });

  group('a planned meal corrected offline still corrects', () {
    test('the deterministic id means one item, not two', () async {
      final (:repository, :service) = _offline();
      const planRef = PlanRef(
        assignmentId: _dayId,
        slot: MealSlot.lunch,
        idx: 0,
      );

      for (final size in ['M', 'L']) {
        await service.commit(
          _writeOf(
            service.correctPlannedLog(
              day: await repository.day(_dayId),
              planRef: planRef,
              entry: _entry(size: size),
              at: _at,
            ),
          ),
        );
      }

      await repository.goOnline();

      final day = repository.store.days[_dayId]!;
      expect(
        day.itemsIn(MealSlot.lunch),
        hasLength(1),
        reason:
            'a correction made with no signal is still a correction when '
            'it reaches the server',
      );
      expect(day.itemsIn(MealSlot.lunch).single.size, 'L');
      expect(const MealDayReader().totals(day).kcalSoFar, 610);
    });
  });

  group('§4.2 — an undo offline is the ABSENCE of a write', () {
    test('nothing is queued, so nothing resurfaces on reconnect', () {
      fakeAsync((async) {
        final (:repository, :service) = _offline();
        final bus = LogCommandBus();

        final prepared = service.logNew(
          day: MealDay(
            dayId: _dayId,
            slots: const <MealSlot, List<MealItem>>{},
          ),
          slot: MealSlot.lunch,
          entries: [_entry()],
          source: MealSource.search,
          origin: MealOrigin.suggestion,
          at: _at,
        ) as MealLogPrepared;

        final handle = bus.submit(
          UndoableLog(
            describe: 'Food logged',
            commit: () => service.commit(prepared.write),
          ),
        );

        async.elapse(const Duration(seconds: 2));
        expect(handle.undo(), isTrue);
        async.elapse(const Duration(seconds: 10));

        expect(
          repository.writes,
          isEmpty,
          reason: 'the write never reached the repository at all',
        );
        expect(
          repository.pending,
          isEmpty,
          reason:
              'a write-then-delete design would leave a compensating write in '
              'the queue, and G6 could award points for a meal she cancelled',
        );

        bus.dispose();
      });
    });

    test('a log left alone offline commits when the window closes', () {
      fakeAsync((async) {
        final (:repository, :service) = _offline();
        final bus = LogCommandBus();

        final prepared = service.logNew(
          day: MealDay(dayId: _dayId),
          slot: MealSlot.lunch,
          entries: [_entry()],
          source: MealSource.search,
          origin: MealOrigin.suggestion,
          at: _at,
        ) as MealLogPrepared;

        bus.submit(
          UndoableLog(
            describe: 'Food logged',
            commit: () => service.commit(prepared.write),
          ),
        );

        async.elapse(const Duration(seconds: 6));

        expect(repository.writes, hasLength(1));
        expect(
          repository.pending,
          hasLength(1),
          reason: 'saved on her phone, waiting for signal — not an error',
        );

        bus.dispose();
      });
    });
  });
}
