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

Recipe _recipe(String id) => _book.recipes.firstWhere((r) => r.recipeId == id);

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
    test('thirty-nine of hers and thirty-one of Own Hub\'s kitchen', () {
      // 41 cards are printed; pages 20 and 21 are the same two recipes with one
      // illustration moved, which is a production error in the book.
      final hers = _book.recipes.where((r) => r.source == RecipeSource.book);
      expect(hers, hasLength(39));
      // The eleven are not hers and are never drawn as hers: authored by Own
      // Hub's kitchen, published on the automated check alone, signed by
      // nobody.
      final ours = _book.recipes
          .where((r) => r.source == RecipeSource.authored)
          .toList();
      expect(ours, hasLength(31));
      for (final recipe in ours) {
        expect(recipe.isOwnHub, isTrue, reason: recipe.recipeId);
        expect(recipe.authoredBy, kOwnHubKitchen, reason: recipe.recipeId);
        expect(recipe.recipeId, startsWith('ownhub_'));
        if (recipe.status == RecipeStatus.review) {
          // Held for Rahma's check: no record, so no automated claim either.
          expect(recipe.verification, isNull, reason: recipe.recipeId);
          expect(recipe.autoChecked, isFalse, reason: recipe.recipeId);
          expect(recipe.allergensKnown, isFalse, reason: recipe.recipeId);
        } else {
          expect(recipe.status, RecipeStatus.published, reason: recipe.recipeId);
          expect(recipe.autoChecked, isTrue, reason: recipe.recipeId);
          expect(recipe.verifiedLabel, 'Checked by Own Hub');
        }
        // The check is a script, never a person: no name, ever.
        expect(recipe.allergenReviewedBy, isNull, reason: recipe.recipeId);
        expect(recipe.allergenReviewedAt, isNull, reason: recipe.recipeId);
        expect(recipe.cookedBy, isNull, reason: recipe.recipeId);
        expect(recipe.cookedAt, isNull, reason: recipe.recipeId);
      }
      expect(_book.recipes, hasLength(70));
    });

    test('no recipe claims page 21, because page 21 is page 20 again', () {
      expect(_book.recipes.map((r) => r.sourcePage), isNot(contains(21)));
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

    test('every section line and every title also reads in Egyptian Arabic', () {
      // Her English stays as the book's own title; the Arabic sits under it on
      // the card and replaces the PS line when the app is in Arabic.
      for (final section in _book.sections) {
        expect(section.psLineAr, isNotEmpty, reason: section.sectionId);
      }
      for (final recipe in _book.recipes) {
        expect(recipe.titleAr, isNotEmpty, reason: recipe.recipeId);
        expect(recipe.titleAr, isNot(contains('—')), reason: recipe.recipeId);
      }
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
        _book
            .byId('rahma_makrona_bashmel')!
            .components
            .map((c) => c.componentId),
        containsAll(<String>['bechamel', 'mince']),
      );
    });

    test('the closing letter is in the seed, and is hers', () {
      expect(_book.letterAr, contains('ليه بنحاول ناكل صحي؟'));
      expect(_book.letterAr, contains('Rahma'));
    });

    test('her letter has the two words pdftotext glued back apart', () {
      // `pdftotext` decides on its own where one drawn line ends and the next
      // begins, and on page 26 it decided twice to join two lines with no space
      // at all. `دماغنا` ends one line and `مركزة` starts the next; the extract
      // said `دماغنامركزة`. Those two are the ONLY corrupted words in the whole
      // book, and they are in the one page every woman reads.
      //
      // `page_junctions` in `extract_rahma_book.py` reads the word boxes, which
      // say exactly where each drawn line stops, and `repair_junctions` splits
      // a pair only where the text shows it glued with both neighbours
      // matching. Asserted on the shipped artefact rather than on the script,
      // because the artefact is what a woman reads.
      expect(_book.letterAr, contains('دماغنا مركزة'));
      expect(_book.letterAr, contains('عندك وحبي'));
      expect(_book.letterAr, isNot(contains('دماغنامركزة')));
      expect(_book.letterAr, isNot(contains('عندكوحبي')));
    });

    test('the words that only LOOK glued are left exactly as she wrote them', () {
      // The other half of the rule above, and the more important half. `الفرنمن`
      // and `ونصمعلقة` are single word objects sitting mid-line with normal
      // gaps on both sides of them, so they are hers, in the same class as her
      // `معلة`, `صنية` and `نشطفة`. A repair loose enough to "fix" these would
      // be rewriting her Arabic, which is the one change nobody may make.
      //
      // `ونص` genuinely does end a line on page 17 and `معلقة` genuinely does
      // start the next, so the pair IS a junction — on the other card on the
      // same page. Anchoring the repair on the neighbouring words is what tells
      // the two apart, and this test is what keeps that anchoring honest.
      final oven = _recipe('rahma_oven_tender_chicken');
      final wings = _recipe('rahma_buffalo_sweet_wings');
      expect(oven.bodyAr, contains('الفرنمن'));
      expect(wings.bodyAr, contains('ونصمعلقة'));
    });

    test('a comma that closes a Latin phrase sits after it', () {
      // The page prints `في طاسة non-stick، سخني الزيت`. The comma sits at the
      // far end of the LTR run, and the run came back read the other way round,
      // so the extract had `في طاسة، non-stick سخني`. Same class of defect as
      // the spaces around a digit group.
      for (final id in ['rahma_lahma_bel_basl', 'rahma_btates_bel_lahma']) {
        expect(_recipe(id).bodyAr, contains('طاسة non-stick،'), reason: id);
        expect(
          _recipe(id).bodyAr,
          isNot(contains('طاسة، non-stick')),
          reason: id,
        );
      }
      expect(
        _recipe('rahma_potato_w_eggs').bodyAr,
        contains('fryer،'),
        reason: 'air fryer wraps across her line break with the comma leading',
      );
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
          // The printed page wrapped her lines, and a step joins those soft
          // breaks, so the slice is compared with whitespace collapsed.
          String flat(String t) => t.replaceAll(RegExp(r'\s+'), ' ');
          if (!flat(recipe.bodyAr).contains(flat(step.textAr))) {
            offenders.add('${recipe.recipeId} step ${step.index}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('every quantity phrase is a verbatim slice too', () {
      final offenders = <String>[];
      for (final recipe in _book.recipes.where(
        (r) => r.source == RecipeSource.book,
      )) {
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
      //
      // Two cards are the exception, and the only two: the book prints them as a
      // list of what goes in and nothing else. Their ingredient lines were
      // steps, which is how step 1 of a card came to repeat ingredient 1; they
      // are ingredients now and the card has no method to split.
      const listOnly = {'rahma_simple_oat_meal', 'rahma_cottage_freshy_salad'};
      for (final recipe in _book.recipes) {
        if (listOnly.contains(recipe.recipeId)) {
          expect(recipe.allSteps, isEmpty, reason: recipe.recipeId);
        } else {
          expect(
            recipe.allSteps,
            isNotEmpty,
            reason: '${recipe.recipeId} has no steps in any block',
          );
        }
        expect(recipe.ingredients, isNotEmpty, reason: recipe.recipeId);
      }
    });

    test('her Arabic is in the asset and nowhere in the dictionary', () {
      // The voice boundary, made mechanical. The app's chrome goes through the ARB;
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

    test('no ingredient row is a measure with nothing to measure', () {
      // The defect this catches: her prose wraps at the right margin, so
      // `نص معلقه` ended one line and `baking powder` started the next, and the
      // splitter cut the phrase in half. Fifteen rows came out like that, and a
      // woman scanning the list to shop read "half a spoon" of nothing. Oven
      // Tender Chicken had a row that was the single word `ونص`.
      //
      // A row now carries the line break and closes up on screen, so the rule
      // this asserts is simply: every row names something, not just an amount.
      const measures = {
        'معلقه',
        'معلقة',
        'معالق',
        'معلقتين',
        'كوباية',
        'كوبايتين',
        'كيس',
        'كيسين',
        'رشة',
        'رشه',
        'حبة',
        'حبه',
        'نص',
        'تلت',
        'ربع',
        'علبة',
        'علبه',
        'شريحة',
        'شريحه',
        'شرايح',
        'قطعة',
        'قطعتين',
        'نقطة',
        'نقطتين',
        'مسحة',
        'فص',
        'فصين',
        'اتنين',
        'خمس',
        'واحدة',
        'واحد',
        'كيلو',
        'كيلة',
        'جرام',
        'جم',
        'مل',
        'صغيرين',
        'صغيرة',
        'صغيره',
        'كبار',
        'كبيره',
        'كبيرة',
        'و',
        'من',
        'او',
        'أو',
      };
      final number = RegExp(r'^[\d½¼/\-]+$');
      String bare(String word) => word
          .replaceAll(RegExp(r'^[وب]'), '')
          .replaceAll(RegExp(r'[،.()+]'), '');

      final offenders = <String>[];
      for (final recipe in _book.recipes) {
        for (final ingredient in recipe.ingredients) {
          final words = ingredient.qtyLine
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty);
          final named = words.any(
            (w) =>
                !number.hasMatch(w) &&
                !measures.contains(w) &&
                !measures.contains(bare(w)),
          );
          if (!named) {
            offenders.add('${recipe.recipeId}: ${ingredient.qtyLine}');
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('a row that crosses her line break closes up on screen', () {
      // The stored span keeps the break, so it stays a verbatim slice of
      // `bodyAr` and the substring test above still means something. `qtyLine`
      // is what a row draws, and it is the only thing that changes.
      final lazyCake = _recipe('rahma_lazy_cake');
      final row = lazyCake.ingredients.firstWhere(
        (i) => i.qtyTextAr.contains('baking powder'),
      );
      expect(row.qtyTextAr, 'نص معلقه\nbaking powder');
      expect(row.qtyLine, 'نص معلقه baking powder');
      expect(lazyCake.bodyAr, contains(row.qtyTextAr));
    });

    test('her "or" is one choice, not two things to buy', () {
      // Coconut apple Pudding opens with two yoghurts the book joins with او.
      // They were two rows, which reads as two tubs to buy for one pudding.
      final pudding = _recipe('rahma_coconut_apple_pudding');
      expect(
        pudding.ingredients.first.qtyLine,
        'علبة زبادي يوناني كبيره او زبادي عادي كامل الدسم',
      );
      // Lentil soup prints its two serving suggestions with أو on a line of its
      // own between them. Same rule.
      final soup = _recipe('rahma_shorbet_3ads');
      final sides = soup.ingredients.where((i) => i.servingSideOnly).toList();
      expect(sides, hasLength(1));
      expect(sides.single.qtyLine, contains('أو'));
    });

    test('the cards the book gives no amounts for say so', () {
      // Five cards name what goes in and mostly not how much, and `Lahma bel
      // basl` has no ingredient list on the page at all: it is twelve numbered
      // steps. Eight bare nouns lifted out of the method - "the meat", "the
      // oil", "the onion" - were printed under an Ingredients heading, which
      // reads as the app having lost the amounts rather than as the book never
      // giving them.
      expect(
        _recipe('rahma_lahma_bel_basl').ingredientsBasis,
        IngredientsBasis.none,
      );
      for (final id in [
        'rahma_egg_pizza',
        'rahma_chicken_pizza',
        'rahma_hwawshi',
        'rahma_chicken_lemon',
        'rahma_tuna_wrap',
      ]) {
        expect(_recipe(id).ingredientsBasis, IngredientsBasis.few, reason: id);
      }
      // Everything else does give measures, and must not be quietly demoted.
      final stated = _book.recipes.where(
        (r) =>
            r.source == RecipeSource.book &&
            r.ingredientsBasis == IngredientsBasis.measures,
      );
      expect(stated, hasLength(33));

      // The method-only card keeps her serving line, which the page does print.
      // The nouns of its method (the meat, the oil, the vegetables) are rows
      // too, with our assumed weights, so its figures rest on named rows; the
      // screen draws none of them but the serving line, because the card
      // says it has no list. Every one of them says its weight is ours.
      final lahma = _recipe('rahma_lahma_bel_basl');
      expect(lahma.ingredients.where((i) => i.servingSideOnly), hasLength(1));
      for (final row in lahma.ingredients.where((i) => !i.servingSideOnly)) {
        expect(row.gramsBasis, GramsBasis.estimated, reason: row.qtyLine);
        expect(row.gramsNote, isNotEmpty, reason: row.qtyLine);
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
    test('a draft never reaches a screen', () {
      // `status` had no reader under `lib/` at all: the unsigned marker and the
      // "no nuts" filter are both driven by `allergenReviewedBy`, which is a
      // different fact. So the field was schema with nothing behind it, and a
      // half-written card arriving from Firestore would have been drawn.
      //
      // Vacuous on today's seed, in the same deliberate way as the publication
      // gates below it.
      for (final recipe in _book.recipes) {
        expect(
          recipe.status,
          isNot(RecipeStatus.draft),
          reason: recipe.recipeId,
        );
      }
      final withDraft = RecipeBook.fromJson({
        'recipes': [
          ...(_raw['recipes']! as List),
          {
            ...((_raw['recipes']! as List).first as Map)
                .cast<String, Object?>(),
            'recipeId': 'half_written',
            'status': 'draft',
          },
        ],
        'sections': _raw['sections'],
        'assemblies': const <Object?>[],
      });
      expect(withDraft.byId('half_written'), isNull);
      expect(withDraft.recipes, hasLength(_book.recipes.length));
    });

    test('nothing is published without a signature or the automated check', () {
      // `allergenReviewedBy` has to be a person, and it must not be the person
      // who authored the row. Writing a name into that field to make a recipe
      // visible would be forging a signature on an allergen check, so a recipe
      // nobody signed is published on the automated check or not at all.
      for (final recipe in _book.recipes) {
        if (recipe.status != RecipeStatus.published) continue;
        expect(
          recipe.allergensKnown,
          isTrue,
          reason: '${recipe.recipeId}: neither signed nor auto-checked',
        );
        if (recipe.allergensReviewed) {
          expect(
            recipe.allergenReviewedBy,
            isNot(recipe.authoredBy),
            reason:
                '${recipe.recipeId}: one person cannot review their own work',
          );
        } else {
          expect(recipe.autoChecked, isTrue, reason: recipe.recipeId);
          expect(recipe.cookedBy, isNull, reason: recipe.recipeId);
        }
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
        final expected = {...recipe.allergensDerived, ...recipe.allergensExtra}
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
      // enough. The target is a token and the sentence is copy in the app's voice
      // from the dictionary, so it reads as the app being careful rather than as
      // Rahma being lovely.
      const risky = {
        'rahma_chicken_pizza',
        'rahma_bbq_burger',
        'rahma_hwawshi',
        'rahma_chicken_lemon',
        'rahma_chicken_ranch_salad',
        'rahma_shrimp_white_pasta',
        'rahma_oven_tender_chicken',
        'rahma_buffalo_sweet_wings',
        'rahma_makrona_bashmel',
        'rahma_kebda_meal',
        'rahma_fattah',
        'rahma_btates_bel_lahma',
        'rahma_shakshoka',
        'rahma_potato_w_eggs',
        'rahma_egg_pizza',
        'rahma_yummy_egg_sandwich',
        'rahma_creamy_cottage_cheese',
        'rahma_pancakes',
        'rahma_crepe',
        'rahma_french_toast',
        'rahma_lazy_cake',
        'rahma_bagel',
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

  group('the tripwire reads the words she actually writes', () {
    // Each of these is a word the dictionary did not hold, proven missing by
    // probing the shipped seed. They are asserted on the derived set rather
    // than on the dictionary file, because what matters is that the recipe a
    // woman opens carries the tag, not that a Python list contains a string.

    test('one stock cube has one outcome, whichever way she spells it', () {
      // `مرقة` and `كنور` fired celery; `الشوربة` fired nothing. Same
      // ingredient, two spellings, two different answers, across three cards.
      // In Egypt "الشوربة" in a method almost always means a cube.
      for (final id in [
        'rahma_chicken_lemon',
        'rahma_shorbet_3ads',
        'rahma_lahma_bel_basl',
      ]) {
        expect(
          _recipe(id).allergensFinal,
          contains('celery'),
          reason: '$id says المياه أو الشوربة',
        );
      }
    });

    test('a commercial spice blend is flagged as the blend it is', () {
      // `بهارات` on an Egyptian packet is a blend, and the packet is the only
      // thing that says what is in it. Celery salt, mustard flour and
      // wheat-flour anticaking are all standard. Over-firing costs a reviewer a
      // minute; under-firing costs somebody a reaction.
      for (final id in [
        'rahma_lazy_ranch_fries',
        'rahma_chicken_ranch_salad',
        'rahma_hwawshi',
        'rahma_tuna_wrap',
        'rahma_lahma_bel_basl',
      ]) {
        expect(
          _recipe(id).allergensFinal,
          containsAll(<String>['celery', 'mustard']),
          reason: id,
        );
      }
      // Curry powder is the same class of blend.
      for (final id in [
        'rahma_oven_tender_chicken',
        'rahma_buffalo_sweet_wings',
      ]) {
        expect(_recipe(id).allergensFinal, contains('celery'), reason: id);
      }
    });

    test('soy fires somewhere, which it never did before', () {
      // `soy` fired on nothing in all thirty-nine, which was a statement about
      // the dictionary rather than about the book: deli turkey and an extruded
      // protein snack are the two commonest hidden soy vectors in an Egyptian
      // kitchen and both are in here.
      final withSoy = _book.recipes
          .where((r) => r.allergensFinal.contains('soy'))
          .map((r) => r.recipeId)
          .toSet();
      expect(withSoy, contains('rahma_club_sandwich'));
      expect(withSoy, contains('rahma_bbq_burger'));
    });

    test('a rice cake is not a gluten claim', () {
      // `رايس كيك` was in the gluten list. A plain rice cake is rice and salt,
      // and it was the ONLY gluten claim on Coconut apple Pudding, so a coeliac
      // lost a dish she can eat. Over-firing is cheap where the word really is
      // a vector. This one never was.
      expect(
        _recipe('rahma_coconut_apple_pudding').allergensFinal,
        isNot(contains('gluten')),
      );
    });

    test('one word may fire more than one tag', () {
      // `scan` blanks out the characters a match consumed, so listing a word
      // under three tags as three separate pairs would let the first tag win
      // the characters and silently lose the other two. That is exactly the
      // failure this whole file exists to catch in somebody else's work, and it
      // would have been invisible: the seed would simply have carried one tag.
      final lahma = _recipe('rahma_lahma_bel_basl');
      expect(
        lahma.allergensFinal,
        containsAll(<String>['celery', 'mustard', 'gluten']),
        reason: 'وبهارات اللحمة is all three at once',
      );
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

    test('and it would notice if the seed lost a tag', () {
      // **Read this before quoting "0 unexplained hits" as evidence.** It is
      // not. `check_seed()` audits the same `scan()` that derived
      // `allergensDerived` in the first place, and `allergensExtra` and
      // `allergensRemoved` are empty on all thirty-nine, so the two sides of
      // that comparison are the same computation and the zero is structural.
      //
      // What makes the guard real is that it bites when the seed and the text
      // disagree, and that is what this checks: strip `milk` out of a copy of
      // the seed and the tripwire must fail on it. Without this, the headline
      // above is a tautology wearing a test's clothes.
      final probe = Process.runSync('python3', ['--version']);
      if (probe.exitCode != 0) {
        markTestSkipped('python3 is not on PATH, so the tripwire did not run');
        return;
      }
      final mutated = Directory.systemTemp.createTempSync('tripwire');
      addTearDown(() => mutated.deleteSync(recursive: true));
      final copy = File('${mutated.path}/seed.json');
      final seed = (jsonDecode(
        File('assets/content/rahma_recipes.json').readAsStringSync(),
      ) as Map).cast<String, Object?>();
      var stripped = 0;
      for (final recipe
          in (seed['recipes'] as List).cast<Map<String, Object?>>()) {
        final finals = (recipe['allergensFinal'] as List).cast<String>();
        final said = (recipe['allergensDerived'] as List).contains('milk');
        // Only a recipe whose words say milk is one the tripwire can catch: a
        // dish that is milky only through a linked food has nothing in its text
        // for the reader to contradict.
        if (finals.remove('milk') && said) stripped++;
        recipe['allergensFinal'] = finals;
      }
      expect(stripped, greaterThan(0), reason: 'nothing to mutate');
      copy.writeAsStringSync(jsonEncode(seed));

      final result = Process.runSync('python3', [
        '-c',
        'import sys; sys.path.insert(0, "tool"); '
            'from allergen_tripwire import check_seed; '
            'print(len(check_seed(sys.argv[1])))',
        copy.path,
      ]);
      expect(result.exitCode, 0, reason: result.stderr.toString());
      expect(
        int.parse(result.stdout.toString().trim()),
        stripped,
        reason: 'the tripwire must report every recipe whose text says milk',
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
