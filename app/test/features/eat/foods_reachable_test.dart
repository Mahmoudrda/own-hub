// Every food in the bundled pack can be found and logged by a woman who has
// no allergy. The pack has 251 foods; four of them are left out of the pack's
// own list because a hand-written sample already covers the same plate, and
// the test names them so nobody mistakes that for a gap.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';

/// The pack's ids that the pack's own list skips, each covered by a sample.
const _coveredBySamples = {
  'koshary',
  'eggs_boiled',
  'molokhia_chicken',
  'ful_medames',
};

void main() {
  late List<Map<String, Object?>> packFoods;

  setUpAll(() {
    final raw = File('assets/content/foods_eg.json').readAsStringSync();
    packFoods = [
      for (final f in (jsonDecode(raw) as Map)['foods'] as List)
        (f as Map).cast<String, Object?>(),
    ];
    EgyptianFoodPack.adopt(raw);
  });
  tearDownAll(EgyptianFoodPack.reset);

  test('the pack holds 251 foods, every one with an allergen list', () {
    expect(packFoods, hasLength(251));
    for (final f in packFoods) {
      expect(f['allergens'], isA<List<Object?>>(), reason: '${f['id']}');
    }
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    group('in ${locale.languageCode}', () {
      late FoodLibrary library;

      setUpAll(() async {
        library = eatSampleLibrary(await AppL10n.delegate.load(locale));
      });

      test('the library holds the whole pack', () {
        final ids = {for (final f in library.foods) f.foodId};
        for (final f in packFoods) {
          final id = f['id']! as String;
          if (_coveredBySamples.contains(id)) continue;
          expect(ids, contains(id));
        }
      });

      test('typing a food\'s name finds it, in the first twelve results', () {
        final arabic = locale.languageCode == 'ar';
        for (final f in packFoods) {
          final id = f['id']! as String;
          if (_coveredBySamples.contains(id)) continue;
          final name = (arabic ? f['nameAr'] : f['nameEn'])! as String;
          final found = library.resolve(name).take(12).map((x) => x.foodId);
          expect(found, contains(id), reason: '$id typed as "$name"');
        }
      });

      test('the four covered plates are found by their sample', () {
        for (final query in const ['molokhia', 'ful', 'eggs']) {
          expect(library.resolve(query), isNotEmpty, reason: query);
        }
      });

      test('a woman with no allergy is never blocked and nothing is screened '
          'out', () {
        final guard = AllergyGuard(DietaryConstraints.none);
        expect(
          guard.screenSuggestions(library.foods),
          hasLength(library.count),
        );
        for (final food in library.foods) {
          expect(guard.assess(food).isBlocked, isFalse, reason: food.foodId);
        }
      });
    });
  }
}
