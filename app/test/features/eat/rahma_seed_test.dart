// What the shipped recipe seed is allowed to say, and what it may not.
//
// This file reads `assets/content/rahma_recipes.json` off disk rather than
// through a bundle, so it is testing the artefact that ships rather than a
// parse of it. Two kinds of assertion live here and they are worth telling
// apart:
//
//   * **Fidelity.** Her titles, her section headings and her sentences, exactly
//     as the book prints them. The substring test is the important one: it is
//     the mechanical proof that the structured view is a *split* of her card
//     rather than a rewrite of it. If it ever goes red, somebody has improved
//     her Arabic, and that is the one change nobody is allowed to make.
//   * **Safety.** What may be published, what may be claimed, and what has to
//     be signed by a second person first. Every one of these passes vacuously
//     today, because nothing is published; they are written now so that the day
//     a row flips to `published`, the gates are already closed behind it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/ui/hand/food_marks.dart';

late RecipeBook _book;
late Map<String, Object?> _raw;

void main() {
  setUpAll(() {
    final file = File('assets/content/rahma_recipes.json');
    expect(
      file.existsSync(),
      isTrue,
      reason:
          'the seed is missing. Rebuild it with '
          '`python3 tool/extract_rahma_book.py && '
          'python3 tool/build_rahma_recipes.py`.',
    );
    _raw = (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
    _book = RecipeBook.fromJson(_raw);
  });

  group('the book is the book', () {
    test('thirty-nine recipes, all of them hers', () {
      // 41 cards are printed; pages 20 and 21 are the same two recipes with one
      // illustration moved, which is a production error in the book.
      expect(_book.recipes, hasLength(39));
      for (final recipe in _book.recipes) {
        expect(recipe.source, RecipeSource.book, reason: recipe.recipeId);
      }
    });

    test('no recipe claims page 21, because page 21 is page 20 again', () {
      expect(
        _book.recipes.map((r) => r.sourcePage),
        isNot(contains(21)),
      );
    });

    test('four sections, character for character', () {
      // Her spelling, including `fulling`, and the missing `PS:` on section
      // three. These are not typos to fix. They are the voice.
      expect(_book.sections.map((s) => s.titleEn).toList(), [
        'Sweet Tooth Breakfast',
        'Salty fulling Breakfast',
        'Lunchy junky yum',
        'Comfy Dinner',
      ]);
      expect(_book.sections.map((s) => s.psLineEn).toList(), [
        'PS: You may need it on your period girl i got you :)',
        'PS: I am keeping you full until lunch dear',
        'WOW I am eating junky healthy food',
        'Eating light to sleep comfy girlie',
      ]);
    });

    test('her titles are hers, arabizi and all', () {
      // `shorbt 3ads` is not corrected to `shorbet ads`, and `Fool & Ta3mya` is
      // not corrected to `Ful and taameya`. Search is served by `titleSearch`,
      // which is never rendered.
      final titles = {for (final r in _book.recipes) r.recipeId: r.titleEn};
      expect(titles['rahma_shorbet_3ads'], 'shorbt 3ads');
      expect(titles['rahma_btates_bel_lahma'], 'Btates bel lahma');
      expect(titles['rahma_fool_wa_ta3mya'], 'Fool & Ta3mya');
      expect(titles['rahma_cookies_shay_blabn'], 'Cookies with shay blabn');
      expect(titles['rahma_makrona_bashmel'], 'Makrona Bashmel');
      expect(titles['rahma_hwawshi'], 'Hwawshi');
      expect(titles['rahma_shakshoka'], 'Shakshoka');
    });

    test('the card with two methods holds both', () {
      // `Cheese cake` prints `طريقتين واختاري منهم` and then two complete
      // alternatives. A variant is not a second recipe and must never be
      // counted as one.
      final cake = _book.byId('rahma_cheese_cake')!;
      expect(cake.variants, hasLength(2));
    });

    test('a sauce inside a card is a component, not a library entry', () {
      // Seven of these exist. Modelling them as recipes would inflate the count
      // dishonestly, which is the whole reason the type has `components[]`.
      expect(
        _book.byId('rahma_crepe')!.components.map((c) => c.componentId),
        contains('chocolate_sauce'),
      );
      expect(
        _book.byId('rahma_kebda_meal')!.components.map((c) => c.componentId),
        contains('light_tahina'),
      );
      expect(
        _book.byId('rahma_makrona_bashmel')!.components.map(
          (c) => c.componentId,
        ),
        containsAll(<String>['bechamel', 'mince']),
      );
    });

    test('the closing letter is in the seed, and is hers', () {
      expect(_book.letterAr, contains('ليه بنحاول ناكل صحي؟'));
      expect(_book.letterAr, contains('Rahma'));
    });
  });

  group('nothing was rewritten', () {
    test('every step is a verbatim slice of the card it came from', () {
      // **The test that proves the structured view is a split, not a
      // paraphrase.** If this goes red, read the diff before touching it: the
      // only ways to break it are to reword one of her sentences or to invent
      // one.
      final offenders = <String>[];
      for (final recipe in _book.recipes) {
        for (final step in [
          ...recipe.steps,
          for (final c in recipe.components) ...c.steps,
          for (final v in recipe.variants) ...v.steps,
        ]) {
          if (!recipe.bodyAr.contains(step.textAr)) {
            offenders.add('${recipe.recipeId} step ${step.index}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('every quantity phrase is a verbatim slice too', () {
      final offenders = <String>[];
      for (final recipe in _book.recipes) {
        for (final ingredient in recipe.ingredients) {
          if (!recipe.bodyAr.contains(ingredient.qtyTextAr)) {
            offenders.add('${recipe.recipeId}: ${ingredient.qtyTextAr}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('every recipe has something to cook from', () {
      // A card that produced no steps at all would mean the splitter silently
      // dropped it, and the screen would show a title over nothing.
      for (final recipe in _book.recipes) {
        expect(
          recipe.allSteps,
          isNotEmpty,
          reason: '${recipe.recipeId} has no steps in any block',
        );
        expect(recipe.ingredients, isNotEmpty, reason: recipe.recipeId);
      }
    });

    test('her Arabic is in the asset and nowhere in the dictionary', () {
      // The voice boundary, made mechanical. MSA chrome goes through the ARB;
      // her Egyptian colloquial comes out of this asset. The two arrive through
      // different pipes, so they cannot be smeared into each other.
      final en = File('lib/l10n/app_en.arb').readAsStringSync();
      final ar = File('lib/l10n/app_ar.arb').readAsStringSync();
      for (final recipe in _book.recipes) {
        for (final line in recipe.bodyAr.split('\n')) {
          if (line.trim().length < 12) continue;
          expect(
            ar.contains(line.trim()),
            isFalse,
            reason: 'her words are in app_ar.arb: ${recipe.recipeId}',
          );
        }
      }
      for (final section in _book.sections) {
        expect(en.contains(section.psLineEn), isFalse, reason: section.titleEn);
        expect(ar.contains(section.psLineEn), isFalse, reason: section.titleEn);
      }
    });

    test('no en dash or em dash reaches a woman', () {
      // A range in the book prints with an en dash; it ships as a plain hyphen.
      // The character changes and the words do not.
      for (final recipe in _book.recipes) {
        expect(
          recipe.bodyAr,
          isNot(anyOf(contains('–'), contains('—'))),
          reason: recipe.recipeId,
        );
      }
      expect(_book.letterAr, isNot(anyOf(contains('–'), contains('—'))));
    });
  });

  group('what may be claimed', () {
    test('nothing is published until two people have signed it', () {
      // Vacuously true today and deliberately so: `allergenReviewedBy` has to be
      // a person, and it must not be the person who authored the row. Writing a
      // name into that field to make a recipe visible would be forging a
      // signature on an allergen check.
      for (final recipe in _book.recipes) {
        if (recipe.status != RecipeStatus.published) continue;
        expect(recipe.allergenReviewedBy, isNotNull, reason: recipe.recipeId);
        expect(
          recipe.allergenReviewedBy,
          isNot(recipe.authoredBy),
          reason: '${recipe.recipeId}: one person cannot review their own work',
        );
        for (final ingredient in recipe.ingredients) {
          expect(
            ingredient.foodId,
            isNotNull,
            reason:
                '${recipe.recipeId}: an ingredient nobody can look up is an '
                'allergen nobody can check',
          );
        }
      }
    });

    test('a published recipe never guesses a weight that matters', () {
      for (final recipe in _book.recipes) {
        if (recipe.status != RecipeStatus.published) continue;
        for (final ingredient in recipe.ingredients) {
          if (ingredient.optional || ingredient.servingSideOnly) continue;
          expect(
            ingredient.gramsBasis,
            isNot(GramsBasis.unknown),
            reason: '${recipe.recipeId}: ${ingredient.qtyTextAr}',
          );
        }
      }
    });

    test('macros are summed or withheld, never half of each', () {
      for (final recipe in _book.recipes) {
        final macros = [
          recipe.kcal,
          recipe.proteinG,
          recipe.carbsG,
          recipe.fatG,
        ];
        if (recipe.macroBasis == MacroBasis.computed) {
          expect(macros, everyElement(isNotNull), reason: recipe.recipeId);
        } else {
          expect(macros, everyElement(isNull), reason: recipe.recipeId);
        }
      }
    });

    test('an EGP figure carries the month it was priced in', () {
      // An undated price in Egypt is wrong within a quarter.
      for (final recipe in _book.recipes) {
        if (recipe.egpPerServing == null) continue;
        expect(recipe.egpPricedAt, isNotNull, reason: recipe.recipeId);
      }
    });

    test('a removed allergen carries a written reason', () {
      for (final recipe in _book.recipes) {
        recipe.allergensRemoved.forEach((tag, reason) {
          expect(
            reason.trim(),
            isNotEmpty,
            reason: '${recipe.recipeId} removed $tag with no reason given',
          );
        });
      }
    });

    test('the final set is derived, extended, then reduced by reasons', () {
      for (final recipe in _book.recipes) {
        final expected =
            {...recipe.allergensDerived, ...recipe.allergensExtra}
              ..removeAll(recipe.allergensRemoved.keys);
        expect(recipe.allergensFinal, expected, reason: recipe.recipeId);
      }
    });

    test('the two Egyptian flags are on the two dishes that need them', () {
      // G6PD deficiency is common enough in Egypt that `Fool & Ta3mya` is a real
      // medical flag, and chicken liver is very high in preformed vitamin A,
      // which is contraindicated in pregnancy. This is a women's app.
      expect(
        _book.byId('rahma_fool_wa_ta3mya')!.advisories,
        contains('g6pd_fava'),
      );
      expect(
        _book.byId('rahma_kebda_meal')!.advisories,
        contains('pregnancy_liver'),
      );
    });

    test('a dish with poultry, mince, liver, eggs or shellfish says when it is '
        'done', () {
      // Her cards end `سيبيه يستوي`. For a general audience that is normal
      // Egyptian cooking; for a shipped app with a duty of care it is not
      // enough. The target is a token and the sentence is Modern Standard copy
      // from the dictionary, so it reads as the app being careful rather than as
      // Rahma being lovely.
      const risky = {
        'rahma_chicken_pizza', 'rahma_bbq_burger', 'rahma_hwawshi',
        'rahma_chicken_lemon', 'rahma_chicken_ranch_salad',
        'rahma_shrimp_white_pasta', 'rahma_oven_tender_chicken',
        'rahma_buffalo_sweet_wings', 'rahma_makrona_bashmel',
        'rahma_kebda_meal', 'rahma_fattah', 'rahma_btates_bel_lahma',
        'rahma_shakshoka', 'rahma_potato_w_eggs', 'rahma_egg_pizza',
        'rahma_yummy_egg_sandwich', 'rahma_creamy_cottage_cheese',
        'rahma_pancakes', 'rahma_crepe', 'rahma_french_toast',
        'rahma_lazy_cake', 'rahma_bagel',
      };
      for (final id in risky) {
        expect(
          _book.byId(id)!.doneness,
          isNotNull,
          reason: '$id contains something that has to be cooked through',
        );
      }
    });

    test('no recipe carries a tier that could lock it', () {
      // Modelled, and inert. Nothing is sold and no paywall exists.
      for (final recipe in _book.recipes) {
        expect(recipe.tier, RecipeTier.free, reason: recipe.recipeId);
      }
    });
  });

  group('the drawings', () {
    test('every mark a recipe names is one we can draw', () {
      // An unmapped mark draws the fallback, which is a real drawing of the
      // wrong dish. Caught here rather than by a woman.
      for (final recipe in _book.recipes) {
        if (recipe.markKey == null) continue;
        expect(
          FoodMarks.all,
          contains(recipe.markKey),
          reason: '${recipe.recipeId} names ${recipe.markKey}',
        );
      }
      for (final section in _book.sections) {
        expect(FoodMarks.all, contains(section.markKey));
      }
    });
  });

  group('assemblies', () {
    test('none ship, and the field exists so the shape is fixed', () {
      // An assembly is a named combination of verified `foods` rows: macros
      // summed rather than invented, allergens unioned rather than claimed. No
      // `foods` row carries verified per-100 g macros yet, so there is nothing
      // honest to build one from.
      expect(_raw['assemblies'], isEmpty);
      expect(_book.assemblies, isEmpty);
    });
  });

  group('the independent reader agrees', () {
    test('the tripwire finds nothing the seed has not accounted for', () {
      // `tool/allergen_tripwire.py` reads her raw Arabic with a dictionary of
      // the words Egyptian women actually write, and reports every allergen tag
      // it finds. It is deliberately a *second* reader: the designed path goes
      // through `foodId` into a verified `foods` row, and that path is only as
      // good as the ingredient list somebody typed. Nobody remembers at eleven
      // at night that زعتر is a sesame blend.
      //
      // Run here rather than left as a step in a README, because a check that
      // has to be remembered is a check that is not run. Skipped, loudly, where
      // there is no python3 — a skip that says so is honest; a silent pass is
      // the vacuous guard this codebase has already shipped twice.
      final probe = Process.runSync('python3', ['--version']);
      if (probe.exitCode != 0) {
        markTestSkipped('python3 is not on PATH, so the tripwire did not run');
        return;
      }
      final result = Process.runSync('python3', ['tool/allergen_tripwire.py']);
      expect(
        result.exitCode,
        0,
        reason:
            'the tripwire read an allergen word in her text that the recipe '
            'neither declares nor explains away:\n${result.stdout}',
      );
    });
  });

  group('it stays small enough to live in the binary', () {
    test('the seed is comfortably under the budget', () {
      final bytes = File('assets/content/rahma_recipes.json').lengthSync();
      expect(
        bytes,
        lessThan(1024 * 1024),
        reason:
            'the whole point of bundling it is an Eat tab that works with no '
            'network; a megabyte of JSON is a different trade',
      );
    });
  });
}
