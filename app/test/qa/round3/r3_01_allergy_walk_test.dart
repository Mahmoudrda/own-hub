// ignore_for_file: avoid_print
//
// R3-01. The allergy path, end to end, for EVERY allergen the app offers,
// in both languages.
//
// Round one found one dish. This walks all sixteen tags through the real E10
// screen and then reads E05 and the Eat home, because the fix did not add a
// tag to one row — it turned a whole list off for anyone who declares
// anything, and the question a second walk has to ask is what she is left
// holding.
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

import '../round1/round1_harness.dart';

/// A dish row, in either language: every one carries a nutrition line.
bool _looksLikeDish(String label) =>
    label.contains('kcal') ||
    label.contains('سعرة') ||
    label.contains('سعرات') ||
    label.contains('g protein') ||
    label.contains('جم بروتين');

RecipeBook _book() => RecipeBook.fromJson(
  (jsonDecode(
    File('assets/content/rahma_recipes.json').readAsStringSync(),
  ) as Map).cast<String, Object?>(),
);

/// The four rows the prototype draws, by the name a woman reads.
const List<String> _protoEn = <String>[
  'Koshari, portioned',
  'Yoghurt, dates and nuts',
  'Ful with egg and cumin',
  'Molokhia with chicken',
];

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('E05 for every declared allergen, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      final rows = <String>[];
      final book = _book();

      for (final tag in AllergenTag.values) {
        wipe();
        EatAppState.instance.seedRecipeBook(book);
        await AppRouter.dietaryRepository.save(allergies: <AllergenTag>{tag});
        final ok = await open(
          t,
          appDestinations['E05']!.name,
          locale: Locale(loc),
        );
        final painted = paintedText(t);
        final taps = tappables(t);
        // Anything that looks like a dish row: the prototype rows all carry a
        // kcal line, Rahma's cards carry a minutes line.
        final dishes = taps
            .where((e) => _looksLikeDish(e.label))
            .map((e) => e.label)
            .toList();
        final nut = painted.where((e) => e.contains('Yoghurt')).toList();
        rows.add(
          '${tag.name.padRight(12)} ok=$ok  dishRows=${dishes.length}  '
          'nutDishPainted=${nut.length}  '
          'paintedLines=${painted.length}  taps=${taps.length}',
        );
        // The one dish a woman who named an allergen may be offered is a recipe
        // a person has signed whose contents do not hold it. The prototype rows
        // are unchecked and are never among them.
        final safeTitles = {
          for (final r in book.recipes)
            if (r.allergensReviewed && !r.allergensFinal.contains(tag.wireName))
              r.titleEn,
        };
        final offered = dishes
            .where((d) => !safeTitles.any(d.contains))
            .toList();
        expect(
          offered,
          isEmpty,
          reason:
              'E05 offered a dish to a woman who declared ${tag.name} '
              'that is unchecked, or contains it',
        );
        expect(ok, isTrue, reason: 'E05 threw with ${tag.name} declared');
      }

      print('=== R3-01 E05, $loc ===');
      for (final r in rows) {
        print('  $r');
      }
      s.dispose();
    });
  }

  // What the screen SAYS when it has emptied itself. Printed, and read as a
  // woman would, in the report.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('E05 empty-state wording, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      EatAppState.instance.seedRecipeBook(_book());
      await AppRouter.dietaryRepository.save(
        allergies: <AllergenTag>{AllergenTag.treeNuts},
      );
      await open(t, appDestinations['E05']!.name, locale: Locale(loc));
      print('=== R3-01 E05 EMPTY, $loc ===');
      for (final line in paintedText(t)) {
        print('  | $line');
      }
      print('  CONTROLS: ${tappables(t).map((e) => e.label).join(" // ")}');
      s.dispose();
    });
  }

  // Not a claim about her body: a woman who declares an allergen that appears
  // in nothing still loses everything, so the screen must say the library is
  // unchecked, not that she avoids it.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('Eat home with an allergy declared, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      for (final tag in <AllergenTag>[
        AllergenTag.molluscs,
        AllergenTag.treeNuts,
      ]) {
        wipe();
        EatAppState.instance.seedRecipeBook(_book());
        await AppRouter.dietaryRepository.save(allergies: <AllergenTag>{tag});
        final ok = await open(
          t,
          appDestinations['E01']!.name,
          locale: Locale(loc),
        );
        print('=== R3-01 E01 with ${tag.name}, $loc  ok=$ok ===');
        for (final line in paintedText(t)) {
          print('  | $line');
        }
        print('  CONTROLS: ${tappables(t).map((e) => e.label).join(" // ")}');
      }
      s.dispose();
    });
  }

  // The reference point: no allergy declared. If the prototype rows are gone
  // here too, the fix took the tab away from everybody.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('E05 with nothing declared still has its rows, $loc', (
      t,
    ) async {
      phone(t);
      final s = t.ensureSemantics();
      EatAppState.instance.seedRecipeBook(_book());
      await open(t, appDestinations['E05']!.name, locale: Locale(loc));
      final taps = tappables(t).map((e) => e.label).toList();
      final dishes = taps.where(_looksLikeDish).toList();
      print('=== R3-01 E05 UNASKED, $loc: ${dishes.length} dish rows ===');
      for (final d in dishes) {
        print('  | $d');
      }
      if (loc == 'en') {
        for (final name in _protoEn) {
          expect(
            paintedText(t).any((e) => e.contains(name)),
            isTrue,
            reason: 'the prototype row "$name" vanished for everybody',
          );
        }
      }
      s.dispose();
    });
  }
}
