// What the recipe seed claims about what is in a dish, held against the food
// pack it is computed from.
//
// `tool/build_rahma_recipes.py` links every ingredient row to a food in
// `assets/content/foods_eg.json`, gives it a weight, and sums the recipe's
// figures from the pack. This reads both files off disk and checks the sum
// again with its own arithmetic, so a build that drifted from its inputs, or a
// pack edit that was not followed by a rebuild, fails here rather than on a
// woman's screen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/eat/domain/recipe_validation.dart';
import 'package:own_hub/features/eat/presentation/rahma_recipe_view.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

late RecipeBook _book;
late Map<String, Map<String, Object?>> _pack;
late Map<String, Object?> _signoff;

/// A step's line without her marker (`-1`, `.3`) or her closing full stop.
String _norm(String line) {
  var out = line.trim();
  final marker = RegExp(r'^[-.]\d+\s+');
  out = out.replaceFirst(marker, '');
  while (out.endsWith('.')) {
    out = out.substring(0, out.length - 1);
  }
  return out.trim();
}

bool _holdsLines(List<String> lines, List<String> wanted) {
  for (var at = 0; at + wanted.length <= lines.length; at++) {
    var same = true;
    for (var i = 0; i < wanted.length; i++) {
      if (lines[at + i] != wanted[i]) {
        same = false;
        break;
      }
    }
    if (same) return true;
  }
  return false;
}

int _round(double v) => (v + 0.5).floor();

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  setUpAll(() {
    final raw = (jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map).cast<String, Object?>();
    _book = RecipeBook.fromJson(raw);
    final foods =
        (jsonDecode(File('assets/content/foods_eg.json').readAsStringSync())
                as Map)['foods']
            as List;
    _pack = {
      for (final f in foods)
        (f as Map)['id'] as String: f.cast<String, Object?>(),
    };
    _signoff =
        (jsonDecode(File('tool/recipe_signoff.json').readAsStringSync())
                as Map)['recipes']
            as Map<String, Object?>;
  });

  group('the library', () {
    test('holds fifty recipes', () {
      expect(_book.recipes, hasLength(50));
      expect(
        {for (final r in _book.recipes) r.recipeId},
        hasLength(50),
        reason: 'every id is its own',
      );
    });

    test('no step is, or holds, one of the card\'s ingredient lines', () {
      // Cards that list what goes in line by line were split into steps at those
      // lines: step 1 of Lazy Cake was ingredient 1 word for word, and 135 of 172
      // steps held an ingredient phrase. A step may mention a quantity inside
      // her sentence; it may not be the ingredient line itself.
      final offenders = <String>[];
      for (final recipe in _book.recipes) {
        final steps = [
          ...recipe.steps,
          for (final c in recipe.components) ...c.steps,
          for (final v in recipe.variants) ...v.steps,
        ];
        final wanted = [
          for (final i in recipe.ingredients)
            i.qtyTextAr.split('\n').map(_norm).toList(),
        ];
        for (final step in steps) {
          final lines = step.textAr.split('\n').map(_norm).toList();
          for (final ingredient in wanted) {
            if (_holdsLines(lines, ingredient)) {
              offenders.add('${recipe.recipeId} step ${step.index}');
            }
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('every step keeps method text once its ingredient phrases are out', () {
      // The test above catches a step that is a whole ingredient line. This one
      // catches the rest: a step made only of quantity phrases and the words
      // that link them ("on it", "or"), which has nothing in it to do.
      final offenders = <String>[];
      for (final recipe in _book.recipes) {
        final phrases = [for (final i in recipe.ingredients) i.qtyTextAr];
        final steps = [
          ...recipe.steps,
          for (final c in recipe.components) ...c.steps,
          for (final v in recipe.variants) ...v.steps,
        ];
        for (final step in steps) {
          if (methodWords(step.textAr, phrases).isEmpty) {
            offenders.add('${recipe.recipeId} step ${step.index}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('the check is not blind: an ingredient-only step is caught', () {
      final crepe = _book.byId('rahma_crepe')!;
      final phrases = [for (final i in crepe.ingredients) i.qtyTextAr];
      expect(
        methodWords(
          'معلقتين زبادي كامل الدسم على نقطتين فانيليا سايله',
          phrases,
        ),
        isEmpty,
      );
      expect(methodWords('وقلب قلب', phrases), isNotEmpty);
    });

    test('every recipe has computed macros and a number of servings', () {
      for (final recipe in _book.recipes) {
        expect(recipe.macroBasis, MacroBasis.computed, reason: recipe.recipeId);
        expect(recipe.kcal, isNotNull, reason: recipe.recipeId);
        expect(recipe.proteinG, isNotNull, reason: recipe.recipeId);
        expect(recipe.carbsG, isNotNull, reason: recipe.recipeId);
        expect(recipe.fatG, isNotNull, reason: recipe.recipeId);
        expect(recipe.serves, greaterThan(0), reason: recipe.recipeId);
        expect(recipe.reviewNotes, isNotEmpty, reason: recipe.recipeId);
        expect(
          recipe.egpPerServing,
          isNull,
          reason: 'there is no price source',
        );
      }
    });

    test('the figures are the pack summed over the weights, per serving', () {
      // Optional rows, serving suggestions and the second of two alternative
      // methods are not counted. The alternative rows are named in the notes.
      final skipped = <String, Set<int>>{
        'rahma_cheese_cake': {3, 4, 5, 6},
      };
      for (final recipe in _book.recipes) {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0;
        for (var n = 0; n < recipe.ingredients.length; n++) {
          final row = recipe.ingredients[n];
          if (row.optional || row.servingSideOnly) continue;
          if (skipped[recipe.recipeId]?.contains(n) ?? false) continue;
          final per = (_pack[row.foodId]!['per100g'] as Map)
              .cast<String, num>();
          final grams = row.grams!;
          kcal += per['kcal']! * grams / 100;
          protein += per['proteinG']! * grams / 100;
          carbs += per['carbsG']! * grams / 100;
          fat += per['fatG']! * grams / 100;
        }
        final serves = recipe.serves!;
        expect(recipe.kcal, _round(kcal / serves), reason: recipe.recipeId);
        expect(
          recipe.proteinG,
          _round(protein / serves),
          reason: recipe.recipeId,
        );
        expect(recipe.carbsG, _round(carbs / serves), reason: recipe.recipeId);
        expect(recipe.fatG, _round(fat / serves), reason: recipe.recipeId);
      }
    });

    test('every ingredient is a food in the pack, with a weight', () {
      for (final recipe in _book.recipes) {
        for (final row in recipe.ingredients) {
          expect(
            _pack,
            contains(row.foodId),
            reason: '${recipe.recipeId}: ${row.qtyLine}',
          );
          expect(row.grams, greaterThan(0), reason: row.ingredientRef);
          expect(
            row.gramsBasis,
            anyOf(GramsBasis.stated, GramsBasis.estimated),
            reason: row.ingredientRef,
          );
        }
      }
    });

    test('an estimated weight says whose estimate it is', () {
      for (final recipe in _book.recipes) {
        for (final row in recipe.ingredients) {
          if (row.gramsBasis != GramsBasis.estimated) continue;
          expect(
            row.gramsNote ?? row.qtyTextEn,
            isNotEmpty,
            reason: row.ingredientRef,
          );
        }
        if (recipe.ingredients.any(
          (i) =>
              i.gramsBasis == GramsBasis.estimated &&
              i.foodId != 'spices_and_seasoning',
        )) {
          expect(
            recipe.reviewNotes.join(' '),
            contains('ours'),
            reason: '${recipe.recipeId} rests on an amount nobody gave',
          );
        }
      }
    });

    test('what a recipe contains includes everything its foods contain', () {
      for (final recipe in _book.recipes) {
        final fromFoods = <String>{
          for (final row in recipe.ingredients)
            ...((_pack[row.foodId]!['allergens'] as List).cast<String>()),
        };
        expect(
          recipe.allergensFinal,
          containsAll(fromFoods),
          reason: recipe.recipeId,
        );
      }
    });

    test(
      'high protein means twenty grams a serving, and nothing else does',
      () {
        for (final recipe in _book.recipes) {
          expect(
            recipe.dietTags.contains('high_protein'),
            recipe.proteinG! >= 20,
            reason: recipe.recipeId,
          );
          expect(recipe.dietTags, isNot(contains('ramadan')));
        }
      },
    );

    test('the tags that rest on an allergen set need a signature', () {
      // Stricter than the guard on purpose: the automated check is enough to
      // show a recipe to a woman with an allergy, but a tag that says "nut
      // free" or "vegan" is written only for a dish a person has signed.
      for (final recipe in _book.recipes) {
        if (recipe.allergensReviewed) continue;
        expect(
          recipe.dietTags,
          isNot(
            anyOf(
              contains('gluten_free'),
              contains('no_nuts'),
              contains('vegan'),
            ),
          ),
          reason: '${recipe.recipeId} is unsigned, not nut free',
        );
      }
    });
  });

  group('who has signed what', () {
    test('every signed recipe carries a reviewer and a cook', () {
      final published = _book.recipes
          .where((r) => r.allergensReviewed)
          .toList();
      expect(published, hasLength(39));
      for (final recipe in published) {
        expect(recipe.status, RecipeStatus.published, reason: recipe.recipeId);
        expect(
          recipe.allergenReviewedBy,
          'rahma_mohsen',
          reason: recipe.recipeId,
        );
        expect(recipe.cookedBy, 'rahma_mohsen', reason: recipe.recipeId);
        expect(recipe.allergenReviewedAt, DateTime.utc(2026, 10, 19));
        expect(recipe.cookedAt, DateTime.utc(2026, 10, 19));
        expect(
          recipe.allergenReviewedBy,
          isNot(recipe.authoredBy),
          reason: 'one person cannot review their own work',
        );
      }
    });

    test('the sign-off file names only recipes that exist', () {
      expect(
        _signoff.keys.toSet().difference({
          for (final r in _book.recipes) r.recipeId,
        }),
        isEmpty,
      );
      expect(
        _signoff.keys.where(
          (id) => _book.byId(id)!.source == RecipeSource.book,
        ),
        hasLength(39),
        reason: 'all thirty-nine of the book are signed',
      );
    });

    test('a recipe is signed exactly when the sign-off lists it', () {
      for (final recipe in _book.recipes) {
        expect(
          recipe.allergensReviewed,
          _signoff.containsKey(recipe.recipeId),
          reason: recipe.recipeId,
        );
        // Signed or not, every recipe is published, and the ones nobody signed
        // are published on the automated check and nothing else.
        expect(recipe.status, RecipeStatus.published, reason: recipe.recipeId);
        expect(recipe.allergensKnown, isTrue, reason: recipe.recipeId);
        if (!recipe.allergensReviewed) {
          expect(recipe.autoChecked, isTrue, reason: recipe.recipeId);
          expect(recipe.cookedBy, isNull, reason: recipe.recipeId);
          expect(recipe.allergenReviewedBy, isNull, reason: recipe.recipeId);
        }
      }
    });

    test('Own Hub\'s recipes are never drawn as hers, signed or not', () {
      final ours = _book.recipes.where((r) => r.isOwnHub).toList();
      expect(ours, hasLength(11));
      for (final recipe in ours) {
        final signed = _signoff.containsKey(recipe.recipeId);
        expect(recipe.status, RecipeStatus.published, reason: recipe.recipeId);
        expect(recipe.allergensReviewed, signed, reason: recipe.recipeId);
        expect(recipe.autoChecked, isTrue, reason: recipe.recipeId);
        expect(recipe.source, RecipeSource.authored);
        expect(recipe.authoredBy, 'ownhub_kitchen');
        expect(recipe.sourcePage, isNull);
        expect(recipe.titleAr, isNotEmpty);
        expect(recipe.markKey, isNotNull);
        expect(
          recipe.reviewNotes.first,
          contains('not by Rahma'),
          reason: recipe.recipeId,
        );
        if (!signed) {
          expect(recipe.reviewNotes.first, contains('automated check'));
          expect(recipe.reviewNotes.first, contains('no person has cooked'));
        }
      }
    });

    test('a sign-off turns one of Own Hub\'s recipes into a clean publication', () {
      // Built into a temp folder against a copy of the sign-off with one of
      // Own Hub's recipes added; the real file and the real seed are untouched.
      final dir = Directory.systemTemp.createTempSync('ownhub_signoff');
      addTearDown(() => dir.deleteSync(recursive: true));
      final copy = jsonDecode(
        File('tool/recipe_signoff.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final signed = Map<String, Object?>.from(copy['recipes']! as Map)
        ..['ownhub_shish_tawook_bowl'] = {
          'allergenReviewedBy': 'rahma_mohsen',
          'cookedBy': 'rahma_mohsen',
          'at': '2026-10-21T00:00:00Z',
        };
      final signoffFile = File('${dir.path}/signoff.json')
        ..writeAsStringSync(jsonEncode({'recipes': signed}));
      final out = '${dir.path}/rahma_recipes.json';
      final run = Process.runSync(
        'python3',
        ['tool/build_rahma_recipes.py'],
        environment: {
          'OWNHUB_RECIPE_SIGNOFF': signoffFile.path,
          'OWNHUB_RECIPES_OUT': out,
        },
      );
      expect(run.exitCode, 0, reason: '${run.stdout}${run.stderr}');

      final book = RecipeBook.fromJson(
        (jsonDecode(File(out).readAsStringSync()) as Map)
            .cast<String, Object?>(),
      );
      final bowl = book.byId('ownhub_shish_tawook_bowl')!;
      expect(bowl.status, RecipeStatus.published);
      expect(bowl.allergensReviewed, isTrue);
      expect(bowl.authoredBy, 'ownhub_kitchen');
      expect(bowl.allergenReviewedBy, isNot(bowl.authoredBy));
      expect(bowl.reviewNotes.first, contains('not by Rahma'));
      expect(bowl.reviewNotes.join(' '), isNot(contains('has not cooked')));
      expect(bowl.reviewNotes.join(' '), isNot(contains('stays in review')));
      expect(
        recipeProblems(
          bowl,
          sectionIds: {for (final s in book.sections) s.sectionId},
        ),
        isEmpty,
      );
      // Only the one that was listed is signed; the other ten stay published
      // on the automated check.
      expect(
        book.recipes
            .where((r) => r.isOwnHub && r.allergensReviewed)
            .map((r) => r.recipeId),
        ['ownhub_shish_tawook_bowl'],
      );
      expect(
        book.recipes.where((r) => r.isOwnHub && r.autoChecked),
        hasLength(11),
      );
    });

    test('Own Hub\'s recipes read in English and in Egyptian Arabic', () {
      final dash = RegExp('[–—]');
      for (final recipe in _book.recipes.where((r) => r.isOwnHub)) {
        expect(recipe.steps, isNotEmpty, reason: recipe.recipeId);
        for (final step in recipe.steps) {
          expect(step.textEn, isNotEmpty, reason: recipe.recipeId);
          expect(step.textAr, isNotEmpty, reason: recipe.recipeId);
          expect(step.textEn, isNot(contains(dash)));
          expect(step.textAr, isNot(contains(dash)));
          expect(recipe.bodyAr, contains(step.textAr));
        }
        for (final row in recipe.ingredients) {
          expect(row.qtyTextEn, isNotEmpty, reason: row.ingredientRef);
          expect(row.qtyTextAr, isNotEmpty, reason: row.ingredientRef);
          expect(row.gramsBasis, isNot(GramsBasis.unknown));
        }
      }
    });
  });

  group('E05 hides a chip that would select nothing', () {
    testWidgets('with this library: no price and no tag, so no such chips', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          RecipesView(
            recipes: const [],
            book: _book,
            asked: true,
            constraints: DietaryConstraints.none,
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Nobody priced a recipe and none is tagged for Ramadan.
      expect(find.text('Cheap'), findsNothing);
      expect(find.text('Ramadan'), findsNothing);
      // The rest each select something.
      expect(find.text('High protein'), findsOneWidget);
      expect(find.text('Under 20 min'), findsOneWidget);
      await tester.ensureVisible(find.text('No oven'));
      expect(find.text('No oven'), findsOneWidget);
      expect(find.text('Ready in the fridge'), findsOneWidget);
      expect(find.text('No nuts'), findsOneWidget);
    });

    testWidgets(
      'a signed or auto-checked recipe is not marked "Not checked yet"',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _host(
            RecipesView(
              recipes: const [],
              book: RecipeBook(
                schemaVersion: _book.schemaVersion,
                contentVersion: _book.contentVersion,
                sections: _book.sections,
                recipes: [
                  _book.byId('rahma_shakshoka')!,
                  _book.byId('ownhub_egg_spinach_wrap')!,
                ],
                assemblies: const [],
                letterAr: '',
              ),
              asked: true,
              constraints: DietaryConstraints.none,
              onSelectTab: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Shakshoka is signed and Own Hub's wrap passed the automated check, so
        // neither is "not checked"; the wrap says who checked it.
        expect(find.text('Not checked yet'), findsNothing);
        expect(find.text('Checked by Own Hub'), findsOneWidget);
        // The section heading and the card's own badge.
        expect(find.text('From the Own Hub kitchen'), findsNWidgets(2));
      },
    );
  });

  group('E06 for a recipe of Own Hub\'s kitchen', () {
    testWidgets('reads in English, says whose it is and has no printed page', (
      tester,
    ) async {
      _phone(tester);
      final wrap = _book.byId('ownhub_egg_spinach_wrap')!;
      await tester.pumpWidget(_host(RahmaRecipeView(recipe: wrap)));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('e06-own-hub-byline')), findsOneWidget);
      expect(find.text('As it is in the book'), findsNothing);
      expect(find.text(wrap.steps.first.textEn!), findsOneWidget);
      expect(find.text(wrap.steps.first.textAr), findsNothing);
      expect(find.text(wrap.ingredients.first.qtyTextEn!), findsOneWidget);
      expect(
        find.text(
          'The ingredients are generic. Read the label on each product '
          'yourself before use.',
        ),
        findsOneWidget,
      );
      // Checked by the automated pass: the allergens show, nobody is said to
      // have signed nothing off.
      expect(find.textContaining('Nobody has signed off'), findsNothing);
      expect(find.text('Checked by Own Hub'), findsOneWidget);
      for (final allergen in ['Eggs', 'Gluten', 'Milk and dairy', 'Soy']) {
        expect(find.text(allergen), findsOneWidget, reason: allergen);
      }
    });

    testWidgets('reads in Egyptian Arabic when the app is in Arabic', (
      tester,
    ) async {
      _phone(tester);
      final wrap = _book.byId('ownhub_egg_spinach_wrap')!;
      await tester.pumpWidget(
        _host(RahmaRecipeView(recipe: wrap), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();

      expect(find.text(wrap.steps.first.textAr), findsOneWidget);
      expect(find.text(wrap.steps.first.textEn!), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'a card the book prints as a list says so instead of a method',
      (tester) async {
        _phone(tester);
        final oats = _book.byId('rahma_simple_oat_meal')!;
        expect(oats.allSteps, isEmpty);
        await tester.pumpWidget(_host(RahmaRecipeView(recipe: oats)));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('e06-list-only')), findsOneWidget);
        expect(find.text('Steps'), findsNothing);
        expect(find.text('Cook mode'), findsNothing);
      },
    );

    test('fish has its own doneness sentence', () {
      final fish = _book.byId('ownhub_lemon_garlic_tilapia')!;
      expect(fish.doneness, 'fish_flakes');
    });
  });

  test('a published recipe is not hidden from a woman with a nut allergy', () {
    final guard = AllergyGuard(
      const DietaryConstraints(allergies: {'tree_nuts'}),
    );
    final shown = guard.screenRecipes(_book.recipes);
    expect(shown, isNotEmpty);
    // Everything shown has known allergens and holds no tree nut. Own Hub's
    // eleven are checked by the script, so the ones without nuts stay and the
    // two with almonds are gone.
    for (final recipe in shown) {
      expect(recipe.allergensKnown, isTrue, reason: recipe.recipeId);
      expect(recipe.allergensFinal, isNot(contains('tree_nuts')));
    }
    expect(
      shown.where((r) => r.isOwnHub).map((r) => r.recipeId),
      isNot(contains('ownhub_yoghurt_strawberry_chia_parfait')),
    );
    expect(shown.where((r) => r.isOwnHub), isNotEmpty);
  });
}
