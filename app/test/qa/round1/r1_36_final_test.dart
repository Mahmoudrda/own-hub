// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-36 tap depth, R1-51 the three back results verified, R1-26 "No nuts".
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

void main() {
  useShippingApp();

  testWidgets('R1-51 what back really does on O01, R05, R08', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    for (final id in ['O01','R05','R08']) {
      if (id == 'O01') { await boot(t, locale: const Locale('en')); }
      else { await open(t, appDestinations[id]!.name, locale: const Locale('en')); }
      final b = tappables(t).map((e)=>e.label).join(' | ');
      await t.binding.handlePopRoute();
      await settle(t); t.takeException();
      print('$id back: top=${topScreen(t)}  before=[$b]');
      print('   after=[${tappables(t).map((e)=>e.label).join(" | ")}]');
    }
    s.dispose();
  });

  testWidgets('R1-36 taps from Home to logging a period', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await boot(t, locale: const Locale('en'));
    for (var i = 0; i < 6; i++) { if (topScreen(t) == 'O05') break; await tapLabel(t, 'Continue'); }
    await tapLabel(t, 'I will start tomorrow');
    var taps = 0;
    print('start: ${topScreen(t)}');
    await tapLabel(t, RegExp('Your profile')); taps++;
    print('tap $taps -> ${topScreen(t)}');
    await tapLabel(t, RegExp('My cycle')); taps++;
    print('tap $taps -> ${topScreen(t)}  ${tappables(t).map((e)=>e.label).take(6).join(" | ")}');
    await tapLabel(t, RegExp('Track periods and symptoms')); taps++;
    await tapLabel(t, 'Continue'); taps++;
    print('tap $taps -> ${topScreen(t)}');
    await tapLabel(t, RegExp('Save preferences')); taps++;
    print('tap $taps -> ${topScreen(t)}  ${tappables(t).map((e)=>e.label).join(" | ")}');
    // now find the way to Y09
    await tapLabel(t, RegExp('Calendar')); taps++;
    print('tap $taps -> ${topScreen(t)}  ${tappables(t).map((e)=>e.label).join(" | ")}');
    await tapLabel(t, RegExp('Note a period')); taps++;
    print('tap $taps -> ${topScreen(t)}  TOTAL TAPS FROM HOME = $taps');
    s.dispose();
  });

  testWidgets('R1-26 No nuts, with the book and an allergy', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    EatAppState.instance.seedRecipeBook(RecipeBook.fromJson((jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync()) as Map).cast<String, Object?>()));
    await AppRouter.dietaryRepository.save(allergies: <AllergenTag>{});
    await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
    for (final f in ['No nuts','Cheap','No oven','Ready in the fridge']) {
      if (!hasLabel(t, RegExp(RegExp.escape(f)))) { print('$f: chip absent'); continue; }
      await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
      await tapLabel(t, RegExp(RegExp.escape(f)));
      final txt = paintedText(t).where((e)=>e.contains('Nothing')||e.contains('nothing')||e.contains('no ')||e.contains('hidden')||e.contains('checked')).toList();
      print('$f -> ${txt.join(" | ")}');
    }
    s.dispose();
  });
}
