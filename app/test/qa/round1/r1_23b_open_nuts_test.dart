// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-23: she declares tree nuts, then taps "Yoghurt, dates and nuts".
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
  testWidgets('tree nuts declared, she opens the nut dish', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    EatAppState.instance.seedRecipeBook(
      RecipeBook.fromJson(
        (jsonDecode(
          File('assets/content/rahma_recipes.json').readAsStringSync(),
        ) as Map).cast<String, Object?>(),
      ),
    );
    await AppRouter.dietaryRepository.save(allergies: {AllergenTag.treeNuts});
    print(
      'declared: ${AppRouter.dietaryRepository.read().allergies?.map((e) => e.name)}',
    );
    await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
    print('WHAT SHE SEES: ${paintedText(t).join(" | ")}');
    print('WHAT SHE CAN OPEN: ${tappables(t).map((e) => e.label).join(" | ")}');
    // She cannot open it, because it is not there.
    //
    // Stale measurement. This case was written when the nut dish was drawn to a
    // woman who had declared tree nuts and a tap on it opened the wrong recipe
    // entirely, so it walked the tap and printed where she landed. Both halves
    // are fixed: `RecipeRow` carries allergens now and E10's promise ("dishes
    // that contain it are hidden from your recipes") is kept, so the row is
    // gone before she can reach it. There is no tap left to walk, and the thing
    // worth asserting is the absence.
    //
    // Asserted three ways on purpose, because "hidden" must mean hidden and not
    // merely un-drawn: the name is not painted, no control carries it, and
    // `tapControl` finds nothing to activate.
    expect(
      paintedText(t).where((e) => e.contains('Yoghurt, dates and nuts')),
      isEmpty,
      reason: 'a declared tree-nut allergy must hide the nut dish',
    );
    expect(
      tappables(t).where((e) => e.label.contains('Yoghurt, dates and nuts')),
      isEmpty,
      reason: 'and it must not be reachable by a screen reader either',
    );
    expect(
      await tapControl(t, RegExp('Yoghurt, dates and nuts')),
      isFalse,
      reason: 'there must be nothing left to activate',
    );
    print('TOP=${topScreen(t)}');
    print(
      'interstitial? sheets=${find.byType(BottomSheet).evaluate().length} dialogs=${find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length}',
    );
    s.dispose();
  });
}
