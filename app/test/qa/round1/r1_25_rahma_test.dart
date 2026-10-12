// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-24 / R1-25 / R1-27: Rahma's cards, duplicate steps, the grocery list.
@Tags(['qa'])
library;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

RecipeBook _b() => RecipeBook.fromJson((jsonDecode(
  File('assets/content/rahma_recipes.json').readAsStringSync()) as Map).cast<String, Object?>());

void main() {
  useShippingApp();
  testWidgets('E11 in both languages, with the book', (t) async {
    phone(t);
    for (final loc in ['en','ar']) {
      EatAppState.instance.seedRecipeBook(_b());
      await open(t, appDestinations['E11']!.name, locale: Locale(loc));
      final txt = paintedText(t);
      print('$loc E11 (${txt.length} strings): ${txt.join(" | ")}');
    }
  });
  testWidgets('R1-24 ten of her cards: numbers and duplicate steps', (t) async {
    phone(t);
    final book = _b();
    var dupes = 0, withNumbers = 0;
    for (final r in book.recipes.take(10)) {
      EatAppState.instance.seedRecipeBook(book);
      EatAppState.instance.openRecipeId = r.recipeId;
      await open(t, appDestinations['E06']!.name, locale: const Locale('en'));
      final txt = paintedText(t);
      final seen = <String>{}; final dup = <String>[];
      for (final s in txt) { if (s.length > 20 && !seen.add(s)) dup.add(s); }
      final nums = txt.where((s) => RegExp(r'\d+\s*(kcal|g protein|EGP)').hasMatch(s)).toList();
      if (dup.isNotEmpty) { dupes++; print('DUP ${r.recipeId}: ${dup.join(" // ")}'); }
      if (nums.isNotEmpty) { withNumbers++; print('NUM ${r.recipeId}: ${nums.join(" // ")}'); }
      print('  ${r.recipeId}: ${txt.take(8).join(" | ")}');
    }
    print('of 10 cards: $dupes with a duplicated line, $withNumbers printing a kcal/macro figure');
  });
  testWidgets('R1-27 the grocery list', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    EatAppState.instance.seedRecipeBook(_b());
    await open(t, appDestinations['E08']!.name, locale: const Locale('en'));
    print('E08: ${paintedText(t).join(" | ")}');
    print('E08 tappable: ${tappables(t).map((e)=>"[${e.label}]").join(" | ")}');
    s.dispose();
  });
}
