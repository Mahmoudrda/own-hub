// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// T02's scrim, the two filters in full, and Arabic mirroring.
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
import 'package:own_hub/ui/app_nav_bar.dart';
import 'round1_harness.dart';

void main() {
  useShippingApp();
  testWidgets('T02: is the scrim dismissible, and does back reach the bar', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    print('T02 tappable: ${tappables(t).map((e)=>e.label).join(" | ")}');
    print('modal barriers=${find.byType(ModalBarrier).evaluate().length}');
    await t.binding.handlePopRoute(); await settle(t); t.takeException();
    print('after back: top=${topScreen(t)} tappable=${tappables(t).map((e)=>e.label).join(" | ")}');
    // finger on the bar again from a clean T02
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    final r = t.getRect(find.descendant(of: find.byType(AppNavBar), matching: find.text('Train')).first);
    await t.tapAt(r.center); await settle(t);
    print('finger on Train at ${r.center}: top=${topScreen(t)}');
    s.dispose();
  });

  testWidgets('the two filters, full text', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    EatAppState.instance.seedRecipeBook(RecipeBook.fromJson((jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync()) as Map).cast<String, Object?>()));
    await AppRouter.dietaryRepository.save(allergies: <AllergenTag>{});
    for (final f in ['No nuts','Cheap']) {
      await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
      await tapLabel(t, RegExp(RegExp.escape(f)));
      print('$f => ${paintedText(t).join(" | ")}');
    }
    s.dispose();
  });

  testWidgets('R1-57 mirroring: calendar and chevrons', (t) async {
    phone(t);
    for (final loc in ['en','ar']) {
      await open(t, appDestinations['Y08']!.name, locale: Locale(loc));
      final days = paintedText(t).take(12).toList();
      print('$loc Y08 header: ${days.join(" ")}');
      // where does the first weekday cell sit
      final first = paintedText(t).firstWhere((e)=>e=='Mon'||e=='الإثنين'||e=='ن', orElse: ()=>'');
      if (first.isNotEmpty) {
        final rect = t.getRect(find.text(first).first);
        print('  "$first" at x=${rect.left.toStringAsFixed(0)}');
      }
      await open(t, appDestinations['P01']!.name, locale: Locale(loc));
      final chevrons = t.widgetList<Icon>(find.byType(Icon)).map((i)=>i.icon.toString()).toSet();
      print('$loc P01 icons: ${chevrons.take(12).join(" ")}');
    }
  });
}
