/// The rules a recipe must meet before it may reach her screen.
///
/// These are the publication and allergen rules `rahma_seed_test.dart` holds the
/// bundled seed to, written once as code so a recipe arriving from Firestore is
/// held to exactly the same ones. The seed has to pass them too
/// (`recipe_sync_test.dart` checks it), so the two can never drift apart.
///
/// Nothing here edits a recipe. A recipe that breaks a rule is refused, and the
/// whole remote set with it: her text is never corrected on the way in.
library;

import 'recipe.dart';

/// Why [recipe] may not be shown, or an empty list when it may.
///
/// [sectionIds] are the sections of the book it would join. Assemblies are not
/// placed in a section of her book and are not checked against it.
List<String> recipeProblems(Recipe recipe, {required Set<String> sectionIds}) {
  final problems = <String>[];
  void fail(String why) => problems.add('${recipe.recipeId}: $why');

  if (recipe.recipeId.trim().isEmpty) fail('no id');
  if (recipe.titleEn.trim().isEmpty) fail('no title');
  if (recipe.source != RecipeSource.assembly &&
      !sectionIds.contains(recipe.sectionId)) {
    fail('section ${recipe.sectionId} is not in the book');
  }

  // Something to cook from.
  if (recipe.allSteps.isEmpty) fail('no steps');
  if (recipe.ingredients.isEmpty &&
      recipe.ingredientsBasis != IngredientsBasis.none) {
    fail('no ingredients and the card does not say it has none');
  }

  // The allergen set is derived, extended, then reduced by written reasons.
  final expected = {...recipe.allergensDerived, ...recipe.allergensExtra}
    ..removeAll(recipe.allergensRemoved.keys);
  if (!_sameSet(recipe.allergensFinal, expected)) {
    fail('final allergens do not follow from derived, extra and removed');
  }
  recipe.allergensRemoved.forEach((tag, reason) {
    if (reason.trim().isEmpty) fail('removed $tag with no reason');
  });

  // Two people. A signature by the author is not a review.
  final reviewer = recipe.allergenReviewedBy;
  if (reviewer != null &&
      reviewer.isNotEmpty &&
      reviewer == recipe.authoredBy) {
    fail('reviewed by its own author');
  }
  if (recipe.status == RecipeStatus.published) {
    if (!recipe.allergensReviewed) fail('published without a signature');
    for (final i in recipe.ingredients) {
      if (i.foodId == null) fail('published with an ingredient nobody can look up');
      if (!i.optional &&
          !i.servingSideOnly &&
          i.gramsBasis == GramsBasis.unknown) {
        fail('published with a guessed weight');
      }
    }
  }

  // Macros are summed or withheld, never half of each.
  final macros = [recipe.kcal, recipe.proteinG, recipe.carbsG, recipe.fatG];
  if (recipe.macroBasis == MacroBasis.computed
      ? macros.any((m) => m == null)
      : macros.any((m) => m != null)) {
    fail('macros are half summed');
  }

  if (recipe.egpPerServing != null && recipe.egpPricedAt == null) {
    fail('a price with no month');
  }

  // Nothing is sold, so nothing may arrive locked.
  if (recipe.tier != RecipeTier.free) fail('tier ${recipe.tier.name}');

  if (recipe.bodyAr.contains('–') || recipe.bodyAr.contains('—')) {
    fail('an en or em dash in her text');
  }

  return problems;
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
