// E01/E04/E09's view model, tested with no widget in sight.
//
// The assertion that matters most here is ORDER: AllergyGuard.screen() runs
// before PlateRollup.rank(), not after. Both orders produce a correct-looking
// list in a screenshot, and only one of them is safe — a ranker that saw a
// conflicting dish first and had it removed afterwards is how the filter
// eventually gets "fixed" by being moved later.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/day_totals.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_day_view_model.dart';

final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl'],
  allergens: const <String>{},
  popularity: 90,
  sizes: const [
    FoodSize(id: 'S', label: 'Small', kcal: 380, proteinG: 13),
    FoodSize(id: 'M', label: 'Medium', kcal: 470, proteinG: 21),
    FoodSize(id: 'L', label: 'Large', kcal: 610, proteinG: 27),
  ],
);

final _tahini = Food(
  foodId: 'tahini_salad',
  names: const ['Tahini salad'],
  allergens: const <String>{'sesame'},
  popularity: 85,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 220, proteinG: 6)],
);

final _molokhia = Food(
  foodId: 'molokhia_chicken',
  names: const ['Molokhia with chicken'],
  allergens: const <String>{},
  popularity: 70,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 460, proteinG: 34)],
);

final _library = FoodLibrary([_koshari, _tahini, _molokhia]);

/// A plate eaten on [days], so it clears the "twice" threshold.
Plate _plate(
  String id,
  List<PlateItem> items, {
  List<String> days = const ['2026-09-13', '2026-09-14'],
  MealSlot slot = MealSlot.lunch,
  int dow = DateTime.tuesday,
}) => Plate(
  plateId: id,
  items: items,
  dayCounts: {for (final day in days) day: 1},
  slotCounts: {slot: days.length},
  dowCounts: {dow: days.length},
  lastAt: DateTime.parse('${days.last}T13:00:00'),
);

EatDayViewModel _model({DietaryConstraints? constraints}) => EatDayViewModel(
  library: _library,
  guard: AllergyGuard(constraints ?? DietaryConstraints.none),
);

MealDay _dayWith(MealSlot slot) => MealDay(
  dayId: '2026-09-15',
  slots: {
    slot: [
      MealItem(
        itemId: 'a',
        foodId: 'koshari_bowl',
        servings: 1,
        size: 'M',
        loggedAt: DateTime(2026, 9, 15, 8, 40),
        source: MealSource.search,
        origin: MealOrigin.suggestion,
        kcal: 470,
        proteinG: 21,
      ),
    ],
  },
);

final _lunchtime = DateTime(2026, 9, 15, 13, 12);

void main() {
  group('which slot this hour belongs to', () {
    test('the boundaries', () {
      expect(
        EatDayViewModel.slotAt(DateTime(2026, 9, 15, 8)),
        MealSlot.breakfast,
      );
      expect(EatDayViewModel.slotAt(DateTime(2026, 9, 15, 13)), MealSlot.lunch);
      expect(
        EatDayViewModel.slotAt(DateTime(2026, 9, 15, 20)),
        MealSlot.dinner,
      );
      expect(EatDayViewModel.slotAt(DateTime(2026, 9, 15, 23)), MealSlot.snack);
    });
  });

  group('the three columns E01 draws', () {
    test('logged is done, this hour is now, the rest are later', () {
      final view = _model().build(
        day: _dayWith(MealSlot.breakfast),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.slots.map((s) => s.slot), [
        MealSlot.breakfast,
        MealSlot.lunch,
        MealSlot.dinner,
      ]);
      expect(view.slots[0].status, SlotStatus.done);
      expect(view.slots[1].status, SlotStatus.now);
      expect(view.slots[2].status, SlotStatus.later);
    });

    test('a done slot carries the items so the column can name them', () {
      final view = _model().build(
        day: _dayWith(MealSlot.breakfast),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.slots[0].items, hasLength(1));
      expect(view.slots[0].items.single.foodId, 'koshari_bowl');
      expect(view.slots[1].hasAnything, isFalse);
    });

    test('a slot already logged is done even when it is this hour', () {
      final view = _model().build(
        day: _dayWith(MealSlot.lunch),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.slots[1].status, SlotStatus.done);
      expect(view.activeSlot, MealSlot.lunch);
    });
  });

  group('the E09 branch', () {
    test('an untouched day is day one', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.isDayOne, isTrue);
      expect(view.totals, DayTotals.empty);
    });

    test('one log ends it permanently', () {
      final view = _model().build(
        day: _dayWith(MealSlot.breakfast),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.isDayOne, isFalse);
    });

    test('day one offers three real starters, not an empty box', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.starters, hasLength(3));
      expect(view.starters.first.primary, isTrue);
      expect(view.starters.skip(1).every((s) => !s.primary), isTrue);
      // Most popular first.
      expect(view.starters.first.key, 'koshari_bowl');
    });
  });

  group('suggestions', () {
    final prefs = EatPrefs(
      plates: {
        'p_koshari': _plate('p_koshari', [
          const PlateItem(foodId: 'koshari_bowl', size: 'M'),
        ]),
        'p_molokhia': _plate(
          'p_molokhia',
          [const PlateItem(foodId: 'molokhia_chicken', size: 'M')],
          days: const ['2026-09-10', '2026-09-11', '2026-09-12'],
        ),
      },
    );

    test('ranked by how often, with the count she can check', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: prefs,
        now: _lunchtime,
      );

      expect(view.suggestions.map((s) => s.key), ['p_molokhia', 'p_koshari']);
      expect(view.suggestions.first.timesEaten, 3);
    });

    test('exactly one row is primary, and it is the top one', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: prefs,
        now: _lunchtime,
      );

      expect(view.suggestions.where((s) => s.primary), hasLength(1));
      expect(view.suggestions.first.primary, isTrue);
    });

    test('a row carries exactly what logging it would write', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: prefs,
        now: _lunchtime,
      );

      final row = view.suggestions.firstWhere((s) => s.key == 'p_koshari');
      expect(row.entries, hasLength(1));
      expect(row.entries.single.food.foodId, 'koshari_bowl');
      expect(row.entries.single.size.id, 'M');
      // The label and the write read the same object, so they cannot drift.
      expect(row.kcal, 470);
      expect(row.proteinG, 21);
    });

    test('a plate whose food has left the pack is not offered', () {
      final stale = EatPrefs(
        plates: {
          'p_gone': _plate('p_gone', [
            const PlateItem(foodId: 'no_longer_shipped', size: 'M'),
          ]),
        },
      );

      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: stale,
        now: _lunchtime,
      );

      expect(
        view.suggestions,
        isEmpty,
        reason:
            'rule 10: the product does not offer a food it can no longer '
            'name or price',
      );
    });
  });

  group('the guard runs BEFORE the ranker', () {
    final prefs = EatPrefs(
      plates: {
        // The conflicting plate is the MOST eaten, so if it were ranked first
        // and filtered afterwards it would still be gone — but if it were
        // filtered at all it must never appear. Ranked most-eaten so that a
        // "filter after ranking" bug cannot hide behind a low position.
        'p_tahini': _plate(
          'p_tahini',
          [const PlateItem(foodId: 'tahini_salad', size: 'M')],
          days: const ['2026-09-10', '2026-09-11', '2026-09-12', '2026-09-13'],
        ),
        'p_koshari': _plate('p_koshari', [
          const PlateItem(foodId: 'koshari_bowl', size: 'M'),
        ]),
      },
    );

    test('a plate containing her allergen never appears', () {
      final view =
          _model(constraints: const DietaryConstraints(allergies: {'sesame'}))
              .build(
                day: const MealDay(dayId: '2026-09-15'),
                prefs: prefs,
                now: _lunchtime,
              );

      expect(view.suggestions.map((s) => s.key), ['p_koshari']);
    });

    test('and the same plate DOES appear for a woman without that allergy', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: prefs,
        now: _lunchtime,
      );

      expect(
        view.suggestions.map((s) => s.key),
        ['p_tahini', 'p_koshari'],
        reason:
            'proves the exclusion above came from the guard and not from '
            'the plate being unrankable for some other reason',
      );
    });

    test('starters are screened too', () {
      final view =
          _model(constraints: const DietaryConstraints(allergies: {'sesame'}))
              .build(
                day: const MealDay(dayId: '2026-09-15'),
                prefs: const EatPrefs(),
                now: _lunchtime,
              );

      expect(view.starters.map((s) => s.key), isNot(contains('tahini_salad')));
    });

    test('unknown constraints leave the suggestions rendering', () {
      // G5 §5.1 item 3: the list is not emptied while her profile is
      // unreadable. The block belongs at the moment of the log.
      final view = _model(constraints: DietaryConstraints.unknown).build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: prefs,
        now: _lunchtime,
      );

      expect(view.suggestions, hasLength(2));
      expect(view.starters, isNotEmpty);
    });
  });

  group('the protein target, which nobody owns yet', () {
    test('falls back to the named provisional constant', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: const EatPrefs(),
        now: _lunchtime,
      );

      expect(view.totals.proteinTargetG, kProvisionalProteinTargetG);
    });

    test('an override on her prefs wins', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: const EatPrefs(proteinTargetGOverride: 110),
        now: _lunchtime,
      );

      expect(view.totals.proteinTargetG, 110);
    });

    test('an explicit argument wins over both', () {
      final view = _model().build(
        day: const MealDay(dayId: '2026-09-15'),
        prefs: const EatPrefs(proteinTargetGOverride: 110),
        now: _lunchtime,
        proteinTargetG: 120,
      );

      expect(view.totals.proteinTargetG, 120);
    });
  });

  test('the running total comes from the items', () {
    final view = _model().build(
      day: _dayWith(MealSlot.breakfast),
      prefs: const EatPrefs(),
      now: _lunchtime,
    );

    expect(view.totals.kcalSoFar, 470);
    expect(view.totals.proteinSoFar, 21);
    expect(view.totals.proteinPercent, closeTo(21 / 95 * 100, 0.001));
  });
}
