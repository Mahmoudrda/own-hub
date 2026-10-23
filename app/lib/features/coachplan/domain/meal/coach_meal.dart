/// W07 — a meal the coach writes herself, and the numbers she is not given.
///
/// G14 §1.6:
///
/// > `resolved` is true only when **every** ingredient carries a `foodId` from
/// > G5's verified pack. One unresolved ingredient ⇒ `resolved:false` and *no
/// > numbers are stored at all* — not a partial total, not an estimate.
///
/// This is §2.10 applied to a human author. The product does not invent a
/// quantity, and neither does a screen on the product's behalf: W07 renders
/// "nutrition details unavailable" from the flag, and the ruleset refuses a
/// document that carries `kcal` while `resolved` is false.
///
/// ## Why the partial total is the interesting case
///
/// "Grandmother's mix, 200 g" among four resolvable ingredients is the real
/// shape of this. Summing the four and showing the total is the tempting
/// behaviour, and it is a lie with a plausible number attached — worse than no
/// number, because a woman counting protein would act on it. [MealNutrition]
/// therefore has **no constructor** that takes figures without the claim that
/// every ingredient resolved, so the partial total is unrepresentable rather
/// than discouraged.
///
/// ## Never written to `foods`
///
/// A coach meal stays in her own collection. W07 says so on screen, and G5's
/// rules deny the write anyway.
library;

import 'package:meta/meta.dart';

/// The most ingredients one coach meal may carry.
const int kMaxMealIngredients = 30;

/// One line of W07's ingredient field.
@immutable
class MealIngredient {
  const MealIngredient({required this.text, this.foodId, this.grams});

  /// What she typed — "200 g yogurt". Shown to the client verbatim, so a dish
  /// stays cookable even when nothing in the pack matches it.
  final String text;

  /// The verified pack's id, when this line resolved to one. Null is the
  /// honest state for "grandmother's mix", and it is what makes the whole
  /// meal's nutrition unavailable.
  final String? foodId;

  final int? grams;

  bool get isResolved => foodId != null;

  Map<String, Object?> toWire() => <String, Object?>{
    'text': text,
    if (foodId != null) 'foodId': foodId,
    if (grams != null) 'grams': grams,
  };

  @override
  String toString() =>
      'MealIngredient("$text"${foodId == null ? '' : ' → $foodId'})';
}

/// The totals, or the stated absence of them.
@immutable
class MealNutrition {
  /// No numbers, because at least one ingredient is not in the verified pack.
  const MealNutrition.unavailable()
    : resolved = false,
      kcal = null,
      proteinG = null;

  /// Every ingredient resolved, so the figures come from the pack.
  const MealNutrition.resolved({
    required int this.kcal,
    required int this.proteinG,
  }) : resolved = true;

  final bool resolved;

  /// Null whenever [resolved] is false — always, and by construction.
  final int? kcal;
  final int? proteinG;

  Map<String, Object?> toWire() => <String, Object?>{
    'resolved': resolved,
    // The ruleset checks this too: totals may exist ONLY when everything
    // resolved. Two independent places, because this is the rule a helpful
    // refactor breaks first.
    if (resolved) 'kcal': kcal,
    if (resolved) 'proteinG': proteinG,
  };

  @override
  String toString() =>
      resolved ? 'MealNutrition($kcal kcal, $proteinG g)' : 'unavailable';
}

/// What one ingredient contributes, when the pack knows it.
typedef IngredientFigures = ({int kcal, int proteinG});

/// Looks one ingredient up in G5's verified pack.
///
/// Returns null when the pack has nothing for it — which is not the same as
/// zero, and is treated as unresolved.
typedef IngredientLookup = IngredientFigures? Function(MealIngredient);

/// Looks one of the coach's own meals up in her collection.
///
/// It lives beside [CoachMeal] rather than beside the planner because two
/// unrelated places need it — W06's write path and the publisher's embedding
/// — and a second copy of the signature is how the two quietly diverge.
typedef CoachMealResolver = CoachMeal? Function(String mealId);

/// A meal in `coaches/{coachUid}/meals/{mealId}`.
@immutable
class CoachMeal {
  CoachMeal({
    required this.mealId,
    required this.name,
    required List<MealIngredient> ingredients,
    required this.nutrition,
    this.servings = 1,
    this.prepMinutes,
    List<String> labels = const <String>[],
    this.note,
    this.updatedAt,
  }) : ingredients = List<MealIngredient>.unmodifiable(ingredients),
       labels = List<String>.unmodifiable(labels);

  /// Builds one with its nutrition **derived**, never passed in.
  ///
  /// The only way to get a [CoachMeal] with figures on it is for every
  /// ingredient to resolve, because this is where the figures come from and it
  /// refuses to add up a subset.
  factory CoachMeal.compose({
    required String mealId,
    required String name,
    required List<MealIngredient> ingredients,
    required IngredientLookup lookup,
    int servings = 1,
    int? prepMinutes,
    List<String> labels = const <String>[],
    String? note,
    DateTime? updatedAt,
  }) => CoachMeal(
    mealId: mealId,
    name: name,
    ingredients: ingredients,
    nutrition: nutritionFor(ingredients, lookup),
    servings: servings,
    prepMinutes: prepMinutes,
    labels: labels,
    note: note,
    updatedAt: updatedAt,
  );

  /// All of them, or none of them.
  ///
  /// An empty ingredient list resolves to unavailable rather than to zero: a
  /// meal with nothing in it has no verified total either, and `0 kcal` on a
  /// screen is a number somebody could believe.
  static MealNutrition nutritionFor(
    List<MealIngredient> ingredients,
    IngredientLookup lookup,
  ) {
    if (ingredients.isEmpty) return const MealNutrition.unavailable();
    var kcal = 0;
    var proteinG = 0;
    for (final ingredient in ingredients) {
      if (!ingredient.isResolved) return const MealNutrition.unavailable();
      final figures = lookup(ingredient);
      if (figures == null) return const MealNutrition.unavailable();
      kcal += figures.kcal;
      proteinG += figures.proteinG;
    }
    return MealNutrition.resolved(kcal: kcal, proteinG: proteinG);
  }

  final String mealId;
  final String name;
  final List<MealIngredient> ingredients;
  final MealNutrition nutrition;
  final int servings;
  final int? prepMinutes;
  final List<String> labels;
  final String? note;
  final DateTime? updatedAt;

  /// The lines W07 names as the reason there are no figures.
  List<MealIngredient> get unresolvedIngredients => <MealIngredient>[
    for (final ingredient in ingredients)
      if (!ingredient.isResolved) ingredient,
  ];

  /// The pack ids on this meal, for the allergy guard to screen.
  Set<String> get foodIds => <String>{
    for (final ingredient in ingredients)
      if (ingredient.foodId != null) ingredient.foodId!,
  };

  /// The payload that is embedded **by value** in a published assignment.
  ///
  /// A reference to `coaches/{coachUid}/meals/{id}` would force the client to
  /// read another user's document, which the ruleset denies and should keep
  /// denying. Embedding also means a later edit here does not silently change
  /// a published day — the same property a split has.
  /// [slotNote] is what the coach wrote for **this day**, when she wrote one.
  /// It takes the `note` key ahead of the dish's own standing note, because an
  /// instruction for today is the more specific of the two and a day can only
  /// show one.
  Map<String, Object?> toEmbeddedValue({
    required int servings,
    String? slotNote,
  }) => <String, Object?>{
    'name': name,
    'ingredients': <Map<String, Object?>>[
      for (final ingredient in ingredients) ingredient.toWire(),
    ],
    'servings': servings,
    'nutrition': nutrition.toWire(),
    if ((slotNote ?? note) != null) 'note': slotNote ?? note,
  };

  Map<String, Object?> toWire() => <String, Object?>{
    'name': name,
    'ingredients': <Map<String, Object?>>[
      for (final ingredient in ingredients) ingredient.toWire(),
    ],
    'servings': servings,
    if (prepMinutes != null) 'prepMinutes': prepMinutes,
    'labels': List<String>.of(labels),
    if (note != null) 'note': note,
    'nutrition': nutrition.toWire(),
  };

  @override
  String toString() => 'CoachMeal($mealId, ${nutrition.resolved})';
}
