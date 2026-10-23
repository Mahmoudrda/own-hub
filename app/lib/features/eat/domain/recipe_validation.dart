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

import 'meal_sentence_parser.dart' show arabicMethodWords;
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

  // Something to cook from: a method. The one exception is a card of the book
  // that prints a list of what goes in and nothing more (every word of it is an
  // ingredient phrase), which has no method to split and says so on screen.
  if (recipe.allSteps.isEmpty && !_isListOnlyCard(recipe)) fail('no steps');
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
  // The automated check is a basis to publish, but only a record that holds up:
  // the right method, a date, and nothing it derived missing from the final
  // allergens. A record that disagrees with its own recipe is a problem even
  // when a signature is there as well.
  final record = recipe.verification;
  if (record != null) {
    if (!record.isAutoCheck) fail('a check by a method nobody knows');
    if (record.checkedAt == null) fail('a check with no date');
    if (!recipe.allergensFinal.containsAll(record.allergensDerived)) {
      fail('the check derived allergens the recipe does not list');
    }
  }
  if (recipe.status == RecipeStatus.published) {
    if (!recipe.allergensKnown) {
      fail('published without a signature or an automated check');
    }
    for (final i in recipe.ingredients) {
      if (i.foodId == null) {
        fail('published with an ingredient nobody can look up');
      }
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

/// The words of [text] left once every one of [phrases] is taken out of it.
/// The Arabic matching data lives in the meal sentence parser, which is the
/// domain file allowed to hold it.
List<String> methodWords(String text, Iterable<String> phrases) =>
    arabicMethodWords(text, phrases);

/// A card of the book whose whole text is its ingredient list.
bool _isListOnlyCard(Recipe recipe) =>
    recipe.source == RecipeSource.book &&
    recipe.ingredients.isNotEmpty &&
    methodWords(recipe.bodyAr, [
      for (final i in recipe.ingredients) i.qtyTextAr,
    ]).isEmpty;
