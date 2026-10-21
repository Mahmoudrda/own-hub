// The seeded recipes must not say less about allergens than the dish they are
// made of. A recipe row that declares "none" over a food row that declares fava
// would pass the importer and show a woman who avoids fava a dish she cannot
// eat, so each seeded recipe is held to the seeded food of the same dish and to
// the dish in the bundled food pack.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/seed_library.dart';

const _spelling = {'dairy': 'milk', 'egg': 'eggs', 'nuts': 'tree_nuts'};

Set<String> _tags(Iterable<String> raw) => {
  for (final t in raw)
    if (t != 'none') _spelling[t] ?? t,
};

/// Seeded recipe id to the seeded food id of the same dish.
const _seedFoodOf = {
  'lentil_soup': 'shorbet_ads',
  'koshari_home': 'koshary',
  'taameya_home': 'taameya',
  'molokhia_with_chicken': 'molokhia',
  'mahshi_koussa': 'mahshi_zucchini',
  'shakshuka': 'shakshuka',
  'roz_bel_laban': 'roz_bel_laban',
  'om_ali': 'om_ali',
};

/// Seeded recipe id to the dish in the bundled food pack.
const _packDishOf = {
  'lentil_soup': 'shorbet_ads',
  'ful_with_oil_and_cumin': 'ful_bel_zeit',
  'koshari_home': 'koshary',
  'taameya_home': 'taameya',
  'molokhia_with_chicken': 'molokhia_chicken',
  'mahshi_koussa': 'mahshi_zucchini',
  'shakshuka': 'shakshuka',
  'roz_bel_laban': 'roz_bel_laban',
  'om_ali': 'om_ali',
};

void main() {
  final recipes = {
    for (final r in seedRowsFor(ContentCollection.recipes)) r.id: r,
  };
  final foods = {for (final r in seedRowsFor(ContentCollection.foods)) r.id: r};
  final pack = {
    for (final f
        in (jsonDecode(File('assets/content/foods_eg.json').readAsStringSync())
                as Map)['foods']
            as List)
      (f as Map)['id'] as String: (f['allergens'] as List).cast<String>(),
  };

  test('every seeded recipe is mapped to a dish in the food pack', () {
    expect(_packDishOf.keys.toSet(), recipes.keys.toSet());
    for (final dish in _packDishOf.values) {
      expect(pack, contains(dish));
    }
  });

  test('a seeded recipe carries every allergen its seeded food does', () {
    _seedFoodOf.forEach((recipeId, foodId) {
      expect(
        _tags(recipes[recipeId]!.list('allergens')),
        _tags(foods[foodId]!.list('allergens')),
        reason: '$recipeId against the seeded food $foodId',
      );
    });
  });

  test('a seeded recipe carries every allergen the pack dish does', () {
    _packDishOf.forEach((recipeId, dish) {
      final declared = _tags(recipes[recipeId]!.list('allergens'));
      expect(
        declared.containsAll(pack[dish]!),
        isTrue,
        reason:
            '$recipeId declares $declared, the pack says $dish has ${pack[dish]}',
      );
    });
  });
}
