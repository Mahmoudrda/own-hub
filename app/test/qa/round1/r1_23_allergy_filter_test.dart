// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-23 / R1-21: with an allergy declared, can she still reach a dish that
// carries it?
@Tags(['qa'])
library;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

RecipeBook _book() => RecipeBook.fromJson((jsonDecode(
  File('assets/content/rahma_recipes.json').readAsStringSync()) as Map).cast<String, Object?>());

void main() {
  useShippingApp();
  for (final tag in [AllergenTag.treeNuts, AllergenTag.sesame, AllergenTag.milk, AllergenTag.gluten]) {
    testWidgets('E05 with ${tag.name} declared', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      EatAppState.instance.seedRecipeBook(_book());
      await AppRouter.dietaryRepository.save(allergies: {tag});
      await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
      final cards = paintedText(t).where((e) => e.contains('kcal')).toList();
      final names = tappables(t).map((e)=>e.label).where((e)=>e.contains('kcal')).toList();
      print('${tag.name}: still offered = ${names.join(" // ")}');
      print('${tag.name}: nutrition lines = ${cards.join(" // ")}');
      s.dispose();
    });
  }
  testWidgets('E06 by direct route with tree nuts declared', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    EatAppState.instance.seedRecipeBook(_book());
    await AppRouter.dietaryRepository.save(allergies: {AllergenTag.treeNuts});
    await open(t, appDestinations['E06']!.name, locale: const Locale('en'));
    print('E06 (no id set): ${paintedText(t).join(" | ")}');
    // now open one of Rahma's cards that carries an allergen, by id
    final book = _book();
    for (final r in book.recipes.take(60)) {
      EatAppState.instance.seedRecipeBook(book);
      EatAppState.instance.openRecipeId = r.recipeId;
      await open(t, appDestinations['E06']!.name, locale: const Locale('en'));
      final txt = paintedText(t);
      print('E06 ${r.recipeId}: ${txt.take(6).join(" | ")}');
      break;
    }
    s.dispose();
  });
}
