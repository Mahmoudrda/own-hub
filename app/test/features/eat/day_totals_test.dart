// The running total is never a countdown.
//
// G5 §1.5 and the enforcement table quoted in PHASE2-ACCEPTANCE.md:
//
// > Calm running total, never a countdown | `DayTotals` (the type itself) | No
// > `remaining`/`target-kcal`/`deficit` field exists in the model (§1.5).
// > Unrepresentable, like C6's `streak`.
//
// test/product_rules_test.dart already scans lib/features/ for the banned
// names, so the *naming* half is covered there and this file covers the
// behavioural half: that the numbers only ever go up, that protein is the only
// target, and that going past it is not an error state.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';

MealItem _item({required int kcal, required int proteinG, int minute = 0}) =>
    MealItem(
      itemId: 'i$kcal-$minute',
      foodId: 'f$kcal',
      servings: 1,
      size: 'M',
      loggedAt: DateTime(2026, 9, 15, 12, minute),
      source: MealSource.search,
      origin: MealOrigin.search,
      kcal: kcal,
      proteinG: proteinG,
    );

void main() {
  group('the type holds three numbers and no fourth', () {
    test(
      'a day with nothing logged is zero, not negative and not a deficit',
      () {
        expect(DayTotals.empty.kcalSoFar, 0);
        expect(DayTotals.empty.proteinSoFar, 0);
        expect(DayTotals.empty.hasAnything, isFalse);
        expect(DayTotals.empty.proteinPercent, 0);
      },
    );

    test('protein is the only target', () {
      const totals = DayTotals(
        kcalSoFar: 1106,
        proteinSoFar: 53,
        proteinTargetG: 95,
      );
      // kcal has a "so far" and no denominator anywhere on the type. If one
      // were added, this expectation is what would have to be edited — which is
      // the visible decision the design is trying to force.
      expect(totals.kcalSoFar, 1106);
      expect(totals.proteinTargetG, 95);
      expect(totals.proteinPercent, closeTo(55.79, 0.01));
    });

    test('the provisional target is named rather than typed in four places', () {
      // G5 §9 Q1: nobody computes this yet. The constant exists so that when a
      // group does, there is one place to change and one place to search for.
      expect(kProvisionalProteinTargetG, 95);
      expect(DayTotals.empty.proteinTargetG, kProvisionalProteinTargetG);
    });
  });

  group('recompute is over the items, because totals are a cache', () {
    test('it sums what she actually logged', () {
      final totals = DayTotals.recompute([
        _item(kcal: 540, proteinG: 18),
        _item(kcal: 156, proteinG: 13, minute: 1),
        _item(kcal: 460, proteinG: 34, minute: 2),
      ]);

      expect(totals.kcalSoFar, 1156);
      expect(totals.proteinSoFar, 65);
    });

    test('an empty day recomputes to empty', () {
      expect(DayTotals.recompute(const <MealItem>[]), DayTotals.empty);
    });

    test('the target is carried through rather than recomputed', () {
      final totals = DayTotals.recompute([
        _item(kcal: 100, proteinG: 10),
      ], proteinTargetG: 120);
      expect(totals.proteinTargetG, 120);
    });
  });

  group('past the target, the bar is simply full', () {
    test('the percentage clamps at 100 instead of overflowing', () {
      const over = DayTotals(
        kcalSoFar: 2400,
        proteinSoFar: 140,
        proteinTargetG: 95,
      );
      expect(over.proteinPercent, 100);
    });

    test('there is no figure describing how far past she is', () {
      // The absence IS the assertion. `proteinSoFar` and `proteinTargetG` are
      // both readable, so a screen COULD subtract them — but nothing in the
      // domain does it, nothing stores it, and no method returns it, so a
      // countdown has to be written from scratch in a widget where a reviewer
      // would see it. That is the same posture WeekKey takes on a streak.
      const over = DayTotals(
        kcalSoFar: 2400,
        proteinSoFar: 140,
        proteinTargetG: 95,
      );
      expect(over.proteinPercent, isNot(lessThan(0)));
      expect(over.hasAnything, isTrue);
    });

    test('a missing target does not divide by zero', () {
      // A screen must never go down because nobody owns the protein target yet.
      const noTarget = DayTotals(
        kcalSoFar: 800,
        proteinSoFar: 40,
        proteinTargetG: 0,
      );
      expect(noTarget.proteinPercent, 0);
      expect(noTarget.kcalSoFar, 800);
    });
  });

  group('the total only ever moves upward as she logs', () {
    test('each log increases it', () {
      final items = <MealItem>[];
      var last = 0;

      for (final kcal in [410, 540, 156, 380]) {
        items.add(_item(kcal: kcal, proteinG: 10, minute: items.length));
        final totals = DayTotals.recompute(items);
        expect(
          totals.kcalSoFar,
          greaterThan(last),
          reason: 'a running total rises; it never drains toward zero',
        );
        last = totals.kcalSoFar;
      }
    });
  });

  test('equality is by value, so a rebuild with the same day is a no-op', () {
    const a = DayTotals(kcalSoFar: 410, proteinSoFar: 22, proteinTargetG: 95);
    const b = DayTotals(kcalSoFar: 410, proteinSoFar: 22, proteinTargetG: 95);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}
