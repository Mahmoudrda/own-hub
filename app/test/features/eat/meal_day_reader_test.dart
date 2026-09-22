// Read-time reconciliation — G5 §4.5.
//
// `arrayUnion` dedupes by whole-element equality, not by `itemId`. So two
// devices correcting the same planned item produce two entries sharing an id,
// and the array has to be reconciled when it is read. The plan is explicit that
// this is convergent rather than exact, and that a map keyed by `itemId` would
// be the real fix (§9 Q11) — raised rather than worked around, because the spine
// declares `slots.<slot>` as an array.
//
// What must be true, and is tested here:
//
//   * the SAME entry wins on every device, whatever order the array arrived in;
//   * the totals are recomputed from the surviving items, so a screen can never
//     show a number that no list of food adds up to.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/meal_day_reader.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';

const _reader = MealDayReader();
const _dayId = '2026-09-15';

MealItem _item(
  String itemId, {
  required int kcal,
  required int proteinG,
  required DateTime loggedAt,
  String foodId = 'koshari_bowl',
  String size = 'M',
}) => MealItem(
  itemId: itemId,
  foodId: foodId,
  servings: 1,
  size: size,
  loggedAt: loggedAt,
  source: MealSource.planned,
  origin: MealOrigin.plan,
  kcal: kcal,
  proteinG: proteinG,
);

MealDay _day(Map<MealSlot, List<MealItem>> slots) =>
    MealDay(dayId: _dayId, slots: slots);

void main() {
  group('dedupe — two corrections of the same item', () {
    /// The same planned item, corrected on two devices to different sizes.
    final earlier = _item(
      'planned-lunch',
      kcal: 470,
      proteinG: 21,
      loggedAt: DateTime(2026, 9, 15, 13, 12),
      size: 'M',
    );
    final later = _item(
      'planned-lunch',
      kcal: 610,
      proteinG: 27,
      loggedAt: DateTime(2026, 9, 15, 13, 40),
      size: 'L',
    );

    test('the later correction wins', () {
      final resolved = _reader.dedupe([earlier, later]);

      expect(resolved, hasLength(1));
      expect(resolved.single.size, 'L');
      expect(resolved.single.kcal, 610);
    });

    test('and it wins regardless of the order they arrived in', () {
      // Two devices hold the same array in different positions. If the winner
      // depended on position, they would render different days.
      expect(_reader.dedupe([earlier, later]).single.size, 'L');
      expect(_reader.dedupe([later, earlier]).single.size, 'L');
    });

    test('a tie on loggedAt is broken deterministically, not by position', () {
      final at = DateTime(2026, 9, 15, 13, 12);
      final small = _item(
        'planned-lunch',
        kcal: 380,
        proteinG: 13,
        loggedAt: at,
        size: 'S',
      );
      final large = _item(
        'planned-lunch',
        kcal: 610,
        proteinG: 27,
        loggedAt: at,
        size: 'L',
      );

      final oneWay = _reader.dedupe([small, large]).single;
      final otherWay = _reader.dedupe([large, small]).single;

      expect(
        oneWay.size,
        otherWay.size,
        reason:
            'both devices must resolve the tie to the same entry, or they '
            'render different days forever',
      );
      // Higher content signature wins — 'S' sorts after 'L' in the signature.
      expect(oneWay.size, 'S');
    });

    test('the total counts the winner once, not both entries', () {
      final day = _day({
        MealSlot.lunch: [earlier, later],
      });

      expect(
        _reader.totals(day).kcalSoFar,
        610,
        reason:
            '470 + 610 would be the stored cache disagreeing with the '
            'items, and the items are truth',
      );
    });
  });

  group('dedupe leaves genuinely distinct items alone', () {
    test('a helping is a separate item and is never merged away', () {
      final first = _item(
        'first',
        kcal: 470,
        proteinG: 21,
        loggedAt: DateTime(2026, 9, 15, 13, 12),
      );
      final helping = MealItem(
        itemId: 'second',
        foodId: 'koshari_bowl',
        servings: 1,
        size: 'M',
        loggedAt: DateTime(2026, 9, 15, 13, 40),
        source: MealSource.planned,
        origin: MealOrigin.plan,
        kcal: 470,
        proteinG: 21,
        helpingOf: 'first',
      );

      final resolved = _reader.dedupe([first, helping]);

      expect(
        resolved,
        hasLength(2),
        reason:
            'identical food, identical size — only the identity differs, '
            'and that is exactly what makes it a second serving',
      );
      expect(_reader.totals(_day({MealSlot.lunch: resolved})).kcalSoFar, 940);
    });
  });

  group('the output order is stable', () {
    test('sorted by time, then by id', () {
      final a = _item(
        'zzz',
        kcal: 100,
        proteinG: 5,
        loggedAt: DateTime(2026, 9, 15, 8),
      );
      final b = _item(
        'aaa',
        kcal: 200,
        proteinG: 9,
        loggedAt: DateTime(2026, 9, 15, 8),
      );
      final c = _item(
        'mmm',
        kcal: 300,
        proteinG: 12,
        loggedAt: DateTime(2026, 9, 15, 13),
      );

      expect(_reader.dedupe([c, a, b]).map((i) => i.itemId), [
        'aaa',
        'zzz',
        'mmm',
      ]);
    });
  });

  group('slots and summaries', () {
    test('only slots with something in them are returned', () {
      final day = _day({
        MealSlot.breakfast: [
          _item(
            'b',
            kcal: 410,
            proteinG: 22,
            loggedAt: DateTime(2026, 9, 15, 8),
          ),
        ],
        MealSlot.lunch: const <MealItem>[],
      });

      expect(_reader.slotsOf(day).keys, [MealSlot.breakfast]);
    });

    test('the Today strip reports what is logged without the whole day', () {
      final day = MealDay(
        dayId: _dayId,
        firstLogAt: DateTime(2026, 9, 15, 8, 40),
        slots: {
          MealSlot.breakfast: [
            _item(
              'b',
              kcal: 410,
              proteinG: 22,
              loggedAt: DateTime(2026, 9, 15, 8),
            ),
          ],
          MealSlot.lunch: [
            _item(
              'l',
              kcal: 540,
              proteinG: 18,
              loggedAt: DateTime(2026, 9, 15, 13),
            ),
          ],
        },
      );

      final summary = _reader.todaySummary(day);
      expect(summary.loggedSlots, {MealSlot.breakfast, MealSlot.lunch});
      expect(summary.itemCount, 2);
      expect(summary.hasAnythingToday, isTrue);
      expect(summary.firstLogAt, DateTime(2026, 9, 15, 8, 40));
    });

    test('an untouched day is the first day, and E09 branches on it', () {
      const day = MealDay(dayId: _dayId);

      expect(_reader.isFirstDay(day), isTrue);
      expect(_reader.todaySummary(day).hasAnythingToday, isFalse);
      expect(_reader.slotsOf(day), isEmpty);
    });

    test('a day with one log is no longer the first day', () {
      final day = _day({
        MealSlot.breakfast: [
          _item(
            'b',
            kcal: 410,
            proteinG: 22,
            loggedAt: DateTime(2026, 9, 15, 8),
          ),
        ],
      });

      expect(_reader.isFirstDay(day), isFalse);
    });
  });

  group('totals are recomputed rather than read from a cache', () {
    test('across every slot', () {
      final day = _day({
        MealSlot.breakfast: [
          _item(
            'b',
            kcal: 410,
            proteinG: 22,
            loggedAt: DateTime(2026, 9, 15, 8),
          ),
        ],
        MealSlot.lunch: [
          _item(
            'l',
            kcal: 696,
            proteinG: 31,
            loggedAt: DateTime(2026, 9, 15, 13),
          ),
        ],
      });

      final totals = _reader.totals(day);
      expect(totals.kcalSoFar, 1106);
      expect(totals.proteinSoFar, 53);
    });

    test('the protein target is passed in, never derived from her food', () {
      final day = _day({
        MealSlot.lunch: [
          _item(
            'l',
            kcal: 696,
            proteinG: 31,
            loggedAt: DateTime(2026, 9, 15, 13),
          ),
        ],
      });

      expect(_reader.totals(day, proteinTargetG: 110).proteinTargetG, 110);
    });
  });
}
