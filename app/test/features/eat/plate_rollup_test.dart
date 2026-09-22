// The suggestion rollup — G5 §1.1 and the ranking E01/E04 render.
//
// Three properties carry the weight here, and each one is a bug that would be
// invisible in review:
//
//  1. **Idempotent on replay.** Spine C4's correction — "commutative is not
//     idempotent" — means an increment replayed after a reconnect counts the
//     same meal twice. The counters are absolute per (plate, date) instead, so
//     a replay writes the same number again and changes nothing.
//  2. **Twice before it is a plate.** E09 promises "log something twice and it
//     becomes a one-tap plate", so a one-off meal must not be suggested back to
//     her forever.
//  3. **Bounded regardless of tenure.** 40 plates, 28 days. A five-year user's
//     document is the same size as a one-month user's, which is what makes
//     "needs a migration to reach 100k MAU" a no.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/plate_rollup.dart';

const _rollup = PlateRollup();

PlateObservation _obs(
  String plateId, {
  required String dayId,
  required DateTime at,
  MealSlot slot = MealSlot.lunch,
  int timesToday = 1,
}) => PlateObservation(
  plateId: plateId,
  items: [PlateItem(foodId: '${plateId}_food', size: 'M')],
  dayId: dayId,
  slot: slot,
  at: at,
  timesToday: timesToday,
);

/// Logs [plateId] on each of [days], one serving per day.
EatPrefs _loggedOn(
  List<String> days, {
  String plateId = 'p1',
  MealSlot slot = MealSlot.lunch,
  EatPrefs from = const EatPrefs(),
  PlateRollup rollup = _rollup,
}) {
  var prefs = from;
  for (final day in days) {
    prefs = rollup.record(
      prefs,
      _obs(
        plateId,
        dayId: day,
        at: DateTime.parse('${day}T13:00:00'),
        slot: slot,
      ),
    );
  }
  return prefs;
}

void main() {
  group('a plate becomes a plate on the SECOND time', () {
    test('one log remembers it but does not suggest it', () {
      final prefs = _loggedOn(['2026-09-14']);

      expect(prefs.plates, hasLength(1), reason: 'it is remembered');
      expect(
        _rollup.rank(prefs, now: DateTime(2026, 9, 15)),
        isEmpty,
        reason: 'a meal she ate once is not yet one of her usuals',
      );
    });

    test('the second log makes it a one-tap plate', () {
      final prefs = _loggedOn(['2026-09-14', '2026-09-15']);

      expect(
        _rollup.rank(prefs, now: DateTime(2026, 9, 15)).map((p) => p.plateId),
        ['p1'],
      );
    });

    test('twice on the SAME day also counts as twice', () {
      var prefs = _loggedOn(['2026-09-15']);
      prefs = _rollup.record(
        prefs,
        _obs(
          'p1',
          dayId: '2026-09-15',
          at: DateTime(2026, 9, 15, 19),
          timesToday: 2,
        ),
      );

      expect(prefs.plates['p1']!.timesEaten, 2);
      expect(_rollup.rank(prefs, now: DateTime(2026, 9, 15)), hasLength(1));
    });
  });

  group('idempotent on replay — spine C4', () {
    test('replaying the same observation changes nothing', () {
      final observation = _obs(
        'p1',
        dayId: '2026-09-15',
        at: DateTime(2026, 9, 15, 13),
      );

      final once = _rollup.record(const EatPrefs(), observation);
      final twice = _rollup.record(once, observation);
      final thrice = _rollup.record(twice, observation);

      expect(
        thrice.plates['p1']!.timesEaten,
        1,
        reason:
            'an offline write that replays on reconnect must not turn one '
            'lunch into three',
      );
      expect(thrice.plates['p1']!.dayCounts, {'2026-09-15': 1});
    });

    test('the histograms do not move on a replay either', () {
      final observation = _obs(
        'p1',
        dayId: '2026-09-15',
        at: DateTime(2026, 9, 15, 13),
        slot: MealSlot.lunch,
      );

      final once = _rollup.record(const EatPrefs(), observation);
      final twice = _rollup.record(once, observation);

      expect(
        twice.plates['p1']!.slotCounts[MealSlot.lunch],
        once.plates['p1']!.slotCounts[MealSlot.lunch],
        reason:
            'the histograms move by the DELTA in an absolute count, so '
            'they inherit idempotency rather than quietly losing it',
      );
      expect(twice.plates['p1']!.slotCounts[MealSlot.lunch], 1);
    });

    test('a genuinely larger count does move the histogram', () {
      var prefs = _rollup.record(
        const EatPrefs(),
        _obs('p1', dayId: '2026-09-15', at: DateTime(2026, 9, 15, 13)),
      );
      prefs = _rollup.record(
        prefs,
        _obs(
          'p1',
          dayId: '2026-09-15',
          at: DateTime(2026, 9, 15, 19),
          timesToday: 3,
        ),
      );

      expect(prefs.plates['p1']!.dayCounts['2026-09-15'], 3);
      expect(prefs.plates['p1']!.slotCounts[MealSlot.lunch], 3);
    });
  });

  group('the 28-day window', () {
    test('logs outside it are pruned and stop counting', () {
      var prefs = _loggedOn(['2026-08-01', '2026-08-02']);
      expect(_rollup.rank(prefs, now: DateTime(2026, 8, 2)), hasLength(1));

      // Seven weeks later she eats it once more.
      prefs = _rollup.record(
        prefs,
        _obs('p1', dayId: '2026-09-20', at: DateTime(2026, 9, 20, 13)),
      );

      expect(
        prefs.plates['p1']!.dayCounts.keys,
        ['2026-09-20'],
        reason:
            'the August keys fell out of the window and were deleted on '
            'write, which is what bounds the document',
      );
      expect(
        _rollup.rank(prefs, now: DateTime(2026, 9, 20)),
        isEmpty,
        reason:
            'inside the window it has been eaten once, so it is not a '
            'usual any more',
      );
    });

    test('the count means "this month", which is what the copy says', () {
      final prefs = _loggedOn(['2026-09-01', '2026-09-08', '2026-09-15']);

      expect(
        _rollup.timesEatenWithin(prefs.plates['p1']!, DateTime(2026, 9, 15)),
        3,
      );
    });
  });

  group('ranking', () {
    test('most often first', () {
      var prefs = _loggedOn(['2026-09-10', '2026-09-11'], plateId: 'twice');
      prefs = _loggedOn(
        ['2026-09-12', '2026-09-13', '2026-09-14'],
        plateId: 'thrice',
        from: prefs,
      );

      expect(
        _rollup.rank(prefs, now: DateTime(2026, 9, 15)).map((p) => p.plateId),
        ['thrice', 'twice'],
      );
    });

    test('a tie is broken by what she eats in THIS slot', () {
      var prefs = _loggedOn(
        ['2026-09-10', '2026-09-11'],
        plateId: 'breakfast_plate',
        slot: MealSlot.breakfast,
      );
      prefs = _loggedOn(
        ['2026-09-12', '2026-09-13'],
        plateId: 'dinner_plate',
        slot: MealSlot.dinner,
        from: prefs,
      );

      expect(
        _rollup
            .rank(prefs, now: DateTime(2026, 9, 15), slot: MealSlot.dinner)
            .first
            .plateId,
        'dinner_plate',
        reason: '"what she eats at this hour"',
      );
      expect(
        _rollup
            .rank(prefs, now: DateTime(2026, 9, 15), slot: MealSlot.breakfast)
            .first
            .plateId,
        'breakfast_plate',
      );
    });

    test('then by what she eats on THIS weekday — E04 "Tuesdays"', () {
      // 8 and 15 September 2026 are Tuesdays; 9 and 16 are Wednesdays.
      var prefs = _loggedOn([
        '2026-09-08',
        '2026-09-15',
      ], plateId: 'tuesday_plate');
      prefs = _loggedOn(
        ['2026-09-09', '2026-09-16'],
        plateId: 'wednesday_plate',
        from: prefs,
      );

      expect(
        _rollup
            .rank(prefs, now: DateTime(2026, 9, 16), weekday: DateTime.tuesday)
            .first
            .plateId,
        'tuesday_plate',
      );
    });

    test('the order is deterministic, so two devices agree', () {
      final prefs = _loggedOn(['2026-09-10', '2026-09-11'], plateId: 'a');
      final other = _loggedOn(
        ['2026-09-10', '2026-09-11'],
        plateId: 'b',
        from: prefs,
      );

      final first = _rollup.rank(other, now: DateTime(2026, 9, 15));
      final second = _rollup.rank(other, now: DateTime(2026, 9, 15));
      expect(first.map((p) => p.plateId), second.map((p) => p.plateId));
    });

    test('rule 11 — the only source of a ranking is her own prefs', () {
      // There is no parameter on rank() through which another woman's data
      // could arrive, and no cross-user read anywhere in this group. The
      // assertion is the signature itself; this pins it so a future overload
      // taking a cohort would break a test.
      final prefs = _loggedOn(['2026-09-10', '2026-09-11']);
      final ranked = _rollup.rank(prefs, now: DateTime(2026, 9, 15));

      expect(ranked.every((p) => prefs.plates.containsKey(p.plateId)), isTrue);
    });
  });

  group('bounded by construction', () {
    test('the cap evicts the least-used plate, not the oldest', () {
      const small = PlateRollup(cap: 2);
      var prefs = const EatPrefs();

      // A daily staple, logged long ago and often.
      prefs = _loggedOn(
        ['2026-09-01', '2026-09-02', '2026-09-03', '2026-09-04'],
        plateId: 'staple',
        from: prefs,
        rollup: small,
      );
      prefs = _loggedOn(
        ['2026-09-10', '2026-09-11'],
        plateId: 'regular',
        from: prefs,
        rollup: small,
      );
      // A one-off, logged most recently.
      prefs = _loggedOn(
        ['2026-09-14'],
        plateId: 'one_off',
        from: prefs,
        rollup: small,
      );

      expect(prefs.plates.keys, hasLength(2));
      expect(
        prefs.plates.keys,
        containsAll(['staple', 'regular']),
        reason:
            'evicting the oldest would drop the breakfast she has had '
            'every day for a year',
      );
      expect(prefs.plates.containsKey('one_off'), isFalse);
    });

    test('the document never exceeds the cap however much she logs', () {
      const small = PlateRollup(cap: 3);
      var prefs = const EatPrefs();

      for (var i = 0; i < 25; i++) {
        prefs = _loggedOn(
          ['2026-09-10', '2026-09-11'],
          plateId: 'plate_$i',
          from: prefs,
          rollup: small,
        );
        expect(prefs.plates.length, lessThanOrEqualTo(3));
      }
    });

    test('the shipped caps are the ones the security rules assert', () {
      expect(kPlateCap, 40);
      expect(kPlateWindow, const Duration(days: 28));
      expect(const PlateRollup().cap, kPlateCap);
      expect(const PlateRollup().window, kPlateWindow);
    });
  });

  group('rule 3 — no consecutive-day counter exists', () {
    test('a plate counts distinct DAYS, and cannot express a run', () {
      final prefs = _loggedOn(['2026-09-10', '2026-09-11', '2026-09-12']);
      final plate = prefs.plates['p1']!;

      // Three days in a row. The type can say "three days"; there is nothing on
      // it that can say "three in a row", and nothing that would change if the
      // days were scattered.
      expect(plate.daysEatenOn, 3);

      final scattered = _loggedOn([
        '2026-09-01',
        '2026-09-09',
        '2026-09-14',
      ], plateId: 'p2');
      expect(scattered.plates['p2']!.daysEatenOn, 3);
    });
  });

  test('the repository routes rollups through this one implementation', () async {
    // Not a second copy of the window and the eviction rule living in the fake.
    final repository = InMemoryMealRepository();
    await repository.recordPlate(
      _obs('p1', dayId: '2026-09-15', at: DateTime(2026, 9, 15, 13)),
    );
    await repository.recordPlate(
      _obs('p1', dayId: '2026-09-16', at: DateTime(2026, 9, 16, 13)),
    );

    final prefs = await repository.prefs();
    expect(prefs.plates['p1']!.timesEaten, 2);
  });
}
