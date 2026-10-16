// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-22 to R1-26: the recipe book, with the book actually loaded.
@Tags(['qa'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

RecipeBook _book() => RecipeBook.fromJson(
  (jsonDecode(
    File('assets/content/rahma_recipes.json').readAsStringSync(),
  ) as Map).cast<String, Object?>(),
);

void main() {
  useShippingApp();
  testWidgets('E05 and E11 with the book seeded', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    final book = _book();
    EatAppState.instance.seedRecipeBook(book);
    print('book recipes=${book.recipes.length}');
    await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
    print('E05: ${paintedText(t).join(" | ")}');
    EatAppState.instance.seedRecipeBook(book);
    await open(t, appDestinations['E11']!.name, locale: const Locale('en'));
    print('E11: ${paintedText(t).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-22 declare sesame, then molluscs', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    for (final tag in [AllergenTag.sesame, AllergenTag.molluscs]) {
      EatAppState.instance.seedRecipeBook(_book());
      AppRouter.dietaryRepository.reset();
      await AppRouter.dietaryRepository.save(allergies: {tag});
      await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
      print('=== ${tag.name} declared, E05 says:');
      print('   ${paintedText(t).join(" | ")}');
    }
    s.dispose();
  });

  testWidgets('R1-21 the allergy question, ticking one', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['E10']!.name, locale: const Locale('en'));
    print('E10 before: ${tappables(t).map((e) => e.label).join(" | ")}');
    await tapLabel(t, 'Sesame');
    print('E10 after ticking Sesame, painted: ${paintedText(t).join(" | ")}');
    print(
      'E10 after ticking Sesame, tappable: ${tappables(t).map((e) => e.label).join(" | ")}',
    );
    // now try to leave without saving
    //
    // `tapControl`, not `tapLabel`: E10's back arrow is an IconButton named by
    // `MaterialLocalizations.backButtonTooltip` (app_scaffold.dart:202), so its
    // semantics label is empty and the regex below only ever matched the
    // TOOLTIP printed above. The control is reachable; the matcher was reading
    // the wrong field, and this case never got past this line.
    final left = await tapControl(t, RegExp(r'^(Back|ارجعي)$'));
    expect(left, isTrue, reason: 'E10 must have a way back');
    print(
      'after Back: top=${topScreen(t)} sheets=${find.byType(BottomSheet).evaluate().length} dialogs=${find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length}',
    );
    print('   painted: ${paintedText(t).join(" | ")}');
    s.dispose();
  });
}
