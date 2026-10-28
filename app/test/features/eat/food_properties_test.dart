// F4: properties that hold for every food in the bundled pack, whatever its
// figures are. The golden table (food_golden_test.dart) checks the figures
// against a source; these checks catch a figure or a name that is wrong on its
// face: energy that does not add up, a portion that disagrees with the per
// 100 g line, two foods answering to one word.
//
// Tolerances are the production plan's (F4): energy within the larger of 20 kcal
// and 15 percent of 4P + 4C + 9F. The build refuses the same, so these tests
// guard the shipped file against a hand edit.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';

/// The foods whose energy USDA records outside the four-nine-four sum, each
/// named in `tool/build_food_pack.py` (ATWATER_EXCEPTIONS) with its reason.
const _atwaterExceptions = {
  'kharoub',
  'cocoa_powder',
  'strawberry_jam',
  'baking_powder',
  'spices_and_seasoning',
  'curry_powder',
  'zaatar_mix',
  'spice_blend_store',
};

/// The only foods that carry no energy (ZERO_ENERGY_OK in the build).
const _zeroEnergy = {'karkadeh_unsweetened', 'salt', 'water'};

const _nutrients = ['kcal', 'proteinG', 'carbsG', 'fatG', 'fiberG'];

typedef _Row = Map<String, Object?>;

double _n(Object? v) => (v! as num).toDouble();

bool _atwaterHolds(num p, num c, num f, num kcal) =>
    (4 * p + 4 * c + 9 * f - kcal).abs() <= max(20, 0.15 * kcal);

void main() {
  late List<_Row> foods;
  late FoodLibrary library;

  setUpAll(() async {
    final raw = File('assets/content/foods_eg.json').readAsStringSync();
    foods = [
      for (final f in (jsonDecode(raw) as Map)['foods'] as List)
        (f as Map).cast<String, Object?>(),
    ];
    EgyptianFoodPack.adopt(raw);
    library = FoodLibrary(
      EgyptianFoodPack.allFoods(
        await AppL10n.delegate.load(const Locale('en')),
      ),
    );
  });
  tearDownAll(EgyptianFoodPack.reset);

  Map<String, _Row> sizesOf(_Row f) => (f['sizes']! as Map).map(
    (k, v) => MapEntry(k as String, (v as Map).cast()),
  );

  test('no value is negative, absurd or missing, and only water, salt and '
      'plain hibiscus carry no energy', () {
    expect(foods.map((f) => f['id']).toSet(), hasLength(foods.length));
    for (final f in foods) {
      final id = f['id']! as String;
      final per = (f['per100g']! as Map).cast<String, Object?>();
      for (final key in _nutrients) {
        expect(_n(per[key]), greaterThanOrEqualTo(0), reason: '$id $key');
      }
      expect(_n(per['kcal']), lessThanOrEqualTo(900), reason: '$id kcal/100 g');
      expect(
        _n(per['proteinG']) + _n(per['carbsG']) + _n(per['fatG']),
        lessThanOrEqualTo(100.2),
        reason: '$id macros exceed 100 g of food',
      );
      expect(
        _n(per['fiberG']),
        lessThanOrEqualTo(_n(per['carbsG']) + 0.05),
        reason: '$id fibre exceeds carbohydrate',
      );
      expect(
        _n(per['kcal']) == 0,
        _zeroEnergy.contains(id),
        reason: '$id energy ${per['kcal']}',
      );
      for (final entry in sizesOf(f).entries) {
        final s = entry.value;
        final where = '$id ${entry.key}';
        expect(_n(s['grams']), inInclusiveRange(1, 2000), reason: where);
        expect(_n(s['kcal']), lessThanOrEqualTo(2500), reason: where);
        for (final key in _nutrients) {
          expect(_n(s[key]), greaterThanOrEqualTo(0), reason: '$where $key');
        }
      }
    }
  });

  test('energy is within the larger of 20 kcal and 15 percent of 4P + 4C + 9F, '
      'per 100 g and in every portion, bar the named exceptions', () {
    for (final f in foods) {
      final id = f['id']! as String;
      if (_atwaterExceptions.contains(id) || _zeroEnergy.contains(id)) continue;
      final per = (f['per100g']! as Map).cast<String, Object?>();
      expect(
        _atwaterHolds(
          _n(per['proteinG']),
          _n(per['carbsG']),
          _n(per['fatG']),
          _n(per['kcal']),
        ),
        isTrue,
        reason: '$id per 100 g',
      );
      for (final entry in sizesOf(f).entries) {
        final s = entry.value;
        expect(
          _atwaterHolds(
            _n(s['proteinG']),
            _n(s['carbsG']),
            _n(s['fatG']),
            _n(s['kcal']),
          ),
          isTrue,
          reason: '$id ${entry.key}',
        );
      }
    }
  });

  test('every portion agrees with the per 100 g line for its weight', () {
    // The build works from unrounded weights and then rounds the weight and each
    // figure, so the bound is half a unit for the figure, half a gram of the
    // weight, and a twentieth of a unit of the one-decimal per 100 g line.
    for (final f in foods) {
      final id = f['id']! as String;
      final per = (f['per100g']! as Map).cast<String, Object?>();
      for (final entry in sizesOf(f).entries) {
        final s = entry.value;
        final grams = _n(s['grams']);
        for (final key in _nutrients) {
          final expected = _n(per[key]) * grams / 100;
          final bound = 0.5 + 0.005 * _n(per[key]) + 0.0005 * grams + 1e-9;
          expect(
            (_n(s[key]) - expected).abs(),
            lessThanOrEqualTo(bound),
            reason: '$id ${entry.key} $key ${s[key]} vs $expected',
          );
        }
      }
    }
  });

  test('portions rise: S < M < L in weight, and in energy for any food that '
      'has energy; an unnamed size keeps the 0.6 / 1.0 / 1.5 ratios', () {
    for (final f in foods) {
      final id = f['id']! as String;
      final sizes = sizesOf(f);
      expect(sizes.keys, containsAll(['S', 'M', 'L']), reason: id);
      final s = sizes['S']!, m = sizes['M']!, l = sizes['L']!;
      expect(_n(s['grams']), lessThan(_n(m['grams'])), reason: '$id S < M');
      expect(_n(m['grams']), lessThan(_n(l['grams'])), reason: '$id M < L');
      if (!_zeroEnergy.contains(id)) {
        expect(
          _n(s['kcal']),
          lessThan(_n(m['kcal'])),
          reason: '$id kcal S < M',
        );
        expect(
          _n(m['kcal']),
          lessThan(_n(l['kcal'])),
          reason: '$id kcal M < L',
        );
      }
      final mGrams = _n(m['grams']);
      if (!s.containsKey('label')) {
        expect(
          (_n(s['grams']) - 0.6 * mGrams).abs(),
          lessThanOrEqualTo(1),
          reason: '$id S is 0.6 of M',
        );
      }
      if (!l.containsKey('label')) {
        expect(
          (_n(l['grams']) - 1.5 * mGrams).abs(),
          lessThanOrEqualTo(1),
          reason: '$id L is 1.5 of M',
        );
      }
    }
  });

  group('cooked and raw', () {
    // Same food, raw or dry against cooked. A ratio of cooked to raw energy per
    // 100 g: dry staples fall to about a third by taking up water, meat and
    // eggs rise a little by losing it, a vegetable stays close.
    const pairs = [
      ('lentils_dry', 'lentils_cooked', 0.25, 0.45),
      ('chicken_breast_raw', 'chicken_breast_grilled', 1.1, 1.8),
      ('beef_steak_raw', 'steak_grilled', 1.0, 1.6),
      ('potato_raw', 'potato_boiled', 1.0, 1.3),
      ('zucchini_raw', 'zucchini_cooked', 0.7, 1.1),
      ('egg_whole', 'eggs_boiled', 1.0, 1.2),
    ];

    test('energy per 100 g moves the way cooking moves it', () {
      final byId = {for (final f in foods) f['id']! as String: f};
      for (final (raw, cooked, low, high) in pairs) {
        final rawKcal = _n((byId[raw]!['per100g']! as Map)['kcal']);
        final cookedKcal = _n((byId[cooked]!['per100g']! as Map)['kcal']);
        expect(
          cookedKcal / rawKcal,
          inInclusiveRange(low, high),
          reason: '$cooked over $raw: $cookedKcal / $rawKcal',
        );
      }
    });

    test('meat, fish, potato and anything dry never answer to the bare word; '
        'lentils do, as the boiled food', () {
      for (final food in library.foods) {
        final id = food.foodId;
        final rawMeat =
            id.endsWith('_raw') && food.category == FoodCategory.proteins;
        if (id.endsWith('_dry') || rawMeat || id == 'potato_raw') {
          expect(food.isCookedFirst, isTrue, reason: id);
        }
      }
      for (final word in const ['lentils', 'ads', 'عدس']) {
        expect(library.named(word).map((f) => f.foodId), [
          'lentils_cooked',
        ], reason: word);
      }
    });
  });

  group('names', () {
    test('every name normalises to something', () {
      for (final food in library.foods) {
        for (final name in food.names) {
          expect(
            FoodLibrary.normalise(name),
            isNotEmpty,
            reason: '${food.foodId}: "$name"',
          );
        }
      }
    });

    test('a word the parser accepts as a food name belongs to one food', () {
      final clashes = <String>[];
      for (final food in library.foods) {
        for (final name in food.names) {
          final hits = library.named(name, allowRaw: true);
          final ids = hits.map((h) => h.foodId).toSet();
          if (ids.length != 1 || !ids.contains(food.foodId)) {
            clashes.add('${food.foodId} "$name" -> $ids');
          }
        }
      }
      expect(clashes, isEmpty);
    });
  });

  group('scaling by weight', () {
    test('twice the weight is twice the figures, within a rounding unit', () {
      final random = Random(40);
      for (final food in library.foods) {
        for (var i = 0; i < 25; i++) {
          final g = 1 + random.nextInt(4999);
          final one = food.sizeForGrams(g)!;
          final two = food.sizeForGrams(2 * g)!;
          void same(String name, int? a, int? b) => expect(
            (b! - 2 * a!).abs(),
            lessThanOrEqualTo(1),
            reason: '${food.foodId} $name at $g g: $a then $b',
          );
          same('kcal', one.kcal, two.kcal);
          same('protein', one.proteinG, two.proteinG);
          same('carbs', one.carbsG, two.carbsG);
          same('fat', one.fatG, two.fatG);
          same('fibre', one.fiberG, two.fiberG);
        }
      }
    });

    test('the weight route stays within 15 percent of the per 100 g line', () {
      // sizeForGrams scales the middle portion's whole numbers, so a portion of
      // a few grams (a spice, baking powder) drifts when scaled up a long way.
      final byId = {for (final f in foods) f['id']! as String: f};
      for (final food in library.foods) {
        final per = _n((byId[food.foodId]!['per100g']! as Map)['kcal']);
        for (final g in const [10, 25, 50, 100, 150, 200, 300, 500]) {
          final expected = per * g / 100;
          if (expected < 20) continue;
          final got = food.sizeForGrams(g)!.kcal;
          expect(
            (got - expected).abs() / expected,
            lessThanOrEqualTo(0.15),
            reason: '${food.foodId} at $g g: $got vs $expected',
          );
        }
      }
    });

    test('the middle portion at its own weight is itself', () {
      for (final food in library.foods) {
        final m = food.weighedSize!;
        final again = food.sizeForGrams(m.grams!)!;
        expect(again.kcal, m.kcal, reason: food.foodId);
        expect(again.proteinG, m.proteinG, reason: food.foodId);
      }
    });
  });
}
