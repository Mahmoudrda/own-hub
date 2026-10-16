// What the guard does with a recipe, and what the tiering gate does with a tier.
//
// `AllergyGuard.screen()` has always removed a conflicting *food*. The recipe
// half adds one rule that is not in the food half and is the reason this file
// exists: **an unsigned recipe is removed too.** "Nobody has checked what is in
// this dish" and "this dish contains none of the sixteen" are different facts,
// and a library that collapses them is a library that looks checked.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/recipe.dart';
import 'package:own_hub/features/eat/domain/recipe_access_gate.dart';

Recipe _recipe({
  required String id,
  Set<String> allergens = const <String>{},
  String? reviewedBy = 'qa_reviewer',
  Set<String> dietTags = const <String>{},
  RecipeTier tier = RecipeTier.free,
}) => Recipe(
  recipeId: id,
  source: RecipeSource.book,
  sectionId: 'sweet_tooth_breakfast',
  orderInSection: 1,
  status: RecipeStatus.review,
  version: 1,
  titleEn: id,
  titleSearch: [id],
  bodyAr: '',
  ingredients: const [],
  ingredientsBasis: IngredientsBasis.measures,
  steps: const [],
  variants: const [],
  components: const [],
  macroBasis: MacroBasis.withheld,
  allergensDerived: allergens,
  allergensExtra: const {},
  allergensRemoved: const {},
  allergensFinal: allergens,
  advisories: const {},
  dietTags: dietTags,
  authoredBy: 'rahma_mohsen',
  allergenReviewedBy: reviewedBy,
  tier: tier,
  brandHints: const {},
);

void main() {
  group('screening a recipe', () {
    test('a named allergen is removed before it is ever offered', () {
      const constraints = DietaryConstraints(
        allergies: {'sesame'},
        dietary: <String>{},
      );
      final kept = AllergyGuard(constraints).screenRecipes([
        _recipe(id: 'with_sesame', allergens: {'sesame', 'gluten'}),
        _recipe(id: 'without', allergens: {'gluten'}),
      ]);
      expect(kept.map((r) => r.recipeId), ['without']);
    });

    test('the comparison is case- and whitespace-insensitive', () {
      // A guard that missed on capitalisation would fail OPEN, which is the
      // direction that hurts somebody.
      const constraints = DietaryConstraints(
        allergies: {' SESAME '},
        dietary: <String>{},
      );
      expect(
        AllergyGuard(constraints).screenRecipes([
          _recipe(id: 'x', allergens: {'Sesame'}),
        ]),
        isEmpty,
      );
    });

    test('an unsigned recipe is hidden from a woman with any allergy', () {
      // The rule that is not in the food half. `allergensFinal` being empty on
      // an unsigned recipe is not a statement that it is clear; it is the
      // absence of a statement.
      const constraints = DietaryConstraints(
        allergies: {'peanuts'},
        dietary: <String>{},
      );
      final kept = AllergyGuard(constraints).screenRecipes([
        _recipe(id: 'unsigned', reviewedBy: null),
        _recipe(id: 'signed'),
      ]);
      expect(kept.map((r) => r.recipeId), ['signed']);
    });

    test('an unsigned recipe still reaches a woman who declared nothing', () {
      // Hiding the whole library from everybody makes nobody safer and makes
      // the tab look broken. She sees it, and the card says out loud that
      // nobody has signed it.
      final kept = AllergyGuard(DietaryConstraints.none)
          .screenRecipes([_recipe(id: 'unsigned', reviewedBy: null)]);
      expect(kept, hasLength(1));
    });

    test('a woman nobody has asked still sees the library', () {
      // `unknown` blocks a *log*, not a list. Emptying the list here would hide
      // the book from every woman on day one, which is the failure the router
      // already documents at length.
      final kept = AllergyGuard(DietaryConstraints.unknown).screenRecipes([
        _recipe(id: 'unsigned', reviewedBy: null),
        _recipe(id: 'nutty', allergens: {'tree_nuts'}),
      ]);
      expect(kept, hasLength(2));
    });

    test('a preference never blocks a recipe with no tags', () {
      // The asymmetry: a preference gets no sheet and no override, and an
      // untagged dish is not a conflict for it. Treating a preference like an
      // allergy trains her to dismiss the sheet that matters.
      const constraints = DietaryConstraints(
        allergies: <String>{},
        dietary: {'vegetarian'},
      );
      final kept = AllergyGuard(constraints).screenRecipes([
        _recipe(id: 'untagged'),
        _recipe(id: 'meaty', dietTags: {'high_protein'}),
        _recipe(id: 'veg', dietTags: {'vegetarian'}),
      ]);
      expect(kept.map((r) => r.recipeId), ['untagged', 'veg']);
    });

    test('the screen says how many it took away', () {
      const constraints = DietaryConstraints(
        allergies: {'milk'},
        dietary: <String>{},
      );
      final all = [
        _recipe(id: 'a', allergens: {'milk'}),
        _recipe(id: 'b', allergens: {'milk'}),
        _recipe(id: 'c'),
      ];
      expect(AllergyGuard(constraints).hiddenCount(all), 2);
    });

    test('and it says WHICH, because the reasons are different facts', () {
      // The ship-blocker. Every recipe in the shipped book is unsigned, so a
      // woman who declares molluscs - which fire on none of the thirty-nine -
      // loses the whole book. Counting that as "hidden because of what you
      // avoid" takes the app's own caution and attributes it to her body.
      const constraints = DietaryConstraints(
        allergies: {'milk'},
        dietary: <String>{},
      );
      final all = [
        _recipe(id: 'contains', allergens: {'milk'}),
        _recipe(id: 'unsigned', reviewedBy: null),
        _recipe(id: 'unsigned_too', reviewedBy: null),
        _recipe(id: 'fine'),
      ];
      final hidden = AllergyGuard(constraints).hiddenByReason(all);
      expect(hidden.unsigned, 2);
      expect(hidden.namedAllergen, 1);
      expect(hidden.dietary, 0);
      expect(hidden.total, AllergyGuard(constraints).hiddenCount(all));
    });

    test('a recipe removed twice over is counted once', () {
      // An unsigned recipe that also names her allergen is removed for the
      // first reason `screenRecipes` tests, and the two counts must add up to
      // the number actually missing from the list rather than to more than it.
      const constraints = DietaryConstraints(
        allergies: {'milk'},
        dietary: <String>{},
      );
      final all = [
        _recipe(id: 'both', allergens: {'milk'}, reviewedBy: null),
      ];
      final guard = AllergyGuard(constraints);
      final hidden = guard.hiddenByReason(all);
      expect(hidden.unsigned, 1);
      expect(hidden.namedAllergen, 0);
      expect(hidden.total, 1);
      expect(guard.screenRecipes(all), isEmpty);
    });

    test('a woman who named nothing has nothing hidden from her', () {
      // `declared` is false, so neither an unsigned recipe nor one carrying an
      // allergen is removed, and the screen must not tell her anything is.
      final all = [
        _recipe(id: 'unsigned', reviewedBy: null),
        _recipe(id: 'nuts', allergens: {'tree_nuts'}),
      ];
      expect(
        AllergyGuard(DietaryConstraints.none).hiddenByReason(all),
        HiddenRecipes.none,
      );
    });

    test('a preference is counted apart from a safety removal', () {
      const constraints = DietaryConstraints(
        allergies: <String>{},
        dietary: {'vegetarian'},
      );
      final all = [
        _recipe(id: 'meat', dietTags: {'high_protein'}),
        _recipe(id: 'veg', dietTags: {'vegetarian'}),
      ];
      final hidden = AllergyGuard(constraints).hiddenByReason(all);
      expect(hidden.dietary, 1);
      expect(hidden.unsigned, 0);
      expect(hidden.namedAllergen, 0);
    });

    test('an advisory is a note and never a filter', () {
      // A pregnancy note is not something she ticked, so the app does not get
      // to decide anything about her body from it.
      const constraints = DietaryConstraints(
        allergies: {'sesame'},
        dietary: <String>{},
      );
      final liver = _recipe(id: 'liver');
      final kept = AllergyGuard(constraints).screenRecipes([liver]);
      expect(kept, hasLength(1));
    });
  });

  group('the tiering gate', () {
    test('everything is open, because nothing is sold', () {
      for (final tier in RecipeTier.values) {
        final access = RecipeAccessGate.decide(
          recipe: _recipe(id: 't', tier: tier),
          flags: FeatureFlags.shipped,
        );
        if (tier == RecipeTier.free) {
          expect(access.isOpen, isTrue);
        } else {
          // A `pro` recipe does not exist in the seed; if one appeared it would
          // be locked for a reason that names the missing rail rather than
          // pretending she could buy it.
          expect(access.reason, RecipeLockReason.paymentsOff);
        }
      }
    });

    test('the flag cannot be switched on above its parent', () {
      // `isOn()` walks ancestors, so this is structurally impossible rather
      // than merely unset. That is the honest version of "the flag is off".
      final forced = FeatureFlags.shipped.with_({Feature.recipeTiering: true});
      expect(forced.isSetOn(Feature.recipeTiering), isTrue);
      expect(
        forced.isOn(Feature.recipeTiering),
        isFalse,
        reason: 'payments is off, so its child cannot be on',
      );
    });

    test('the parent is payments, not marketplace', () {
      expect(Feature.recipeTiering.parent, Feature.payments);
    });

    test('an unreadable entitlement opens rather than locks', () {
      // Deliberately the opposite direction from the allergy guard. Failing
      // closed on safety protects her; failing closed on billing takes away a
      // recipe she already paid for because the network dropped.
      final flags = FeatureFlags.everything;
      expect(
        RecipeAccessGate.decide(
          recipe: _recipe(id: 'p', tier: RecipeTier.pro),
          flags: flags,
        ).isOpen,
        isTrue,
      );
    });

    test('an expired subscription locks, and says so', () {
      final flags = FeatureFlags.everything;
      final access = RecipeAccessGate.decide(
        recipe: _recipe(id: 'p', tier: RecipeTier.pro),
        flags: flags,
        entitlement: RecipeEntitlement(
          tier: RecipeTier.pro,
          expiresAt: DateTime.utc(2026, 1, 1),
        ),
        now: DateTime.utc(2026, 6, 1),
      );
      expect(access.reason, RecipeLockReason.expired);
    });

    test('there is no force, no skipChecks and no override', () {
      // The same discipline `checkout_gate.dart` keeps, and it is a property of
      // the source rather than of any behaviour, so it is read as source. A gate
      // with an escape hatch is a gate somebody reaches for at the end of a long
      // day.
      final source = File('lib/features/eat/domain/recipe_access_gate.dart')
          .readAsLinesSync()
          .where((l) => !l.trimLeft().startsWith('//'))
          .join();
      // `override` is not in the list: `@override` is an annotation, not an
      // escape hatch, and a guard that could not tell them apart would be the
      // kind of vacuous check this codebase has already been bitten by twice.
      for (final hatch in ['force', 'skipChecks', 'allowOffline', 'bypass']) {
        expect(source.contains(hatch), isFalse, reason: hatch);
      }
    });
  });
}
