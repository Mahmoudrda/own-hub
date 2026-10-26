// A coach can only put into a meal plan what the server accepts in one
// (functions/coaching/content_ids.json): the bundled recipes and the food pack.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/coaching_wiring.dart';

Set<String> _allowed(String key) {
  final ids = jsonDecode(
    File('../functions/coaching/content_ids.json').readAsStringSync(),
  );
  return {for (final id in (ids as Map)[key] as List) id as String};
}

void main() {
  setUp(() {
    EgyptianFoodPack.adopt(
      File('assets/content/foods_eg.json').readAsStringSync(),
    );
  });

  testWidgets('every food on offer is one the server accepts, koshary too', (
    t,
  ) async {
    for (final locale in ['en', 'ar']) {
      final l10n = lookupAppL10n(Locale(locale));
      final ids = {
        for (final f in coachMealCatalog(l10n).foods.foods) f.foodId,
      };
      expect(ids, _allowed('foods'), reason: locale);
      expect(ids, contains('koshary'));
      expect(ids, isNot(contains('koshari_bowl')));
    }
  });

  test('the bundled recipes are exactly the ones the server accepts', () async {
    SeededRecipeLibrary.resetCache();
    final book = await SeededRecipeLibrary(
      readAsset: (key) async => File(key).readAsStringSync(),
    ).load();
    expect({for (final r in book.recipes) r.recipeId}, _allowed('recipes'));
    expect(SeededRecipeLibrary.seededIds, _allowed('recipes'));
  });

  test('all 11 kitchen recipes stay', () async {
    final book = await SeededRecipeLibrary(
      readAsset: (key) async => File(key).readAsStringSync(),
    ).load();
    EatAppState.instance.recipeBook = book;
    final l10n = lookupAppL10n(const Locale('en'));
    final catalog = coachMealCatalog(l10n);
    final kitchen = catalog.recipes.where((r) => r.isOwnHub).length;
    final bookRecipes = catalog.recipes.where((r) => !r.isOwnHub).length;
    expect(kitchen, 11);
    expect(bookRecipes, 39);
  });

  test('an unsigned book recipe is not offered', () async {
    final raw = jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final recipes = ((raw['recipes'] as List).cast<Map<String, Object?>>()).map((r) {
      if (r['recipeId'] == 'rahma_lazy_cake') {
        final copy = Map<String, Object?>.from(r);
        copy.remove('allergenReviewedBy');
        return copy;
      }
      return r;
    }).toList();
    final modifiedJson = Map<String, Object?>.from(raw)..['recipes'] = recipes;
    final book = RecipeBook.fromJson(modifiedJson);
    EatAppState.instance.recipeBook = book;
    final l10n = lookupAppL10n(const Locale('en'));
    final catalog = coachMealCatalog(l10n);
    expect(catalog.recipe('rahma_lazy_cake'), isNull);
    expect(catalog.recipe('rahma_pancakes'), isNotNull);
  });
}
