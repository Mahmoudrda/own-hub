/// The food pack, standing in for content that has not been built.
///
/// G5 §1.2 specifies a signed pack of ~1,500 bundled foods and 4,100 in the full
/// download, delivered as a build artefact and never read from Firestore. That
/// pipeline does not exist yet, so these are the foods the prototype actually
/// names — resolved from `AppL10n`, exactly as `TrainRepository` documents for
/// the 124 exercise titles:
///
/// > The library types carry display text because the 124-title library is
/// > content from a build-time bundle, not copy from the dictionary. Until that
/// > pipeline exists the sample rows are resolved from `AppL10n` by the views.
///
/// ## Every food here has `allergens: null`, and that is deliberate
///
/// **No allergen tag has been invented.** `foods.allergens[]` is unauthored —
/// `SCHEMA-SPINE.md` §1 calls it "mandatory, not enrichment",
/// `PHASE1-FINDINGS.md` F7 confirms it is still missing, and `DECISIONS.md`
/// lists it as blocking Phase 2. Null means **unknown**, which is what
/// [AllergyGuard] fails closed on. An empty set here would be a claim that these
/// dishes contain none of what she named — a fabricated safety guarantee shown
/// to a woman with a food allergy, which is the worst thing this feature could
/// produce.
///
/// `dietTags` is null for the same reason, with the same meaning.
///
/// ## There are no Arabic aliases here, and that is a content request
///
/// The real pack carries `names{ar, en, franco, aliases[]}` (G5 §1.2), so a
/// woman running the app in English can still say "كشري" and be understood. This
/// stand-in cannot: every string in `lib/` goes through `AppL10n`, which
/// `i18n_guard_test.dart` enforces, so the only names available here are the
/// ones the *current* locale supplies.
///
/// In practice Arabic input still resolves in the Arabic build, because
/// [FoodLibrary.resolve] matches on substrings and "كشري" is inside
/// "طبق كشري". What is genuinely missing is **cross-locale matching** — Arabic
/// speech against an English interface — and Franco-Arabic input. Both need
/// `names.aliases[]` and `names.franco` from the content pipeline, which G5 §7
/// already lists among the fields it requests and does not add.
///
/// ## The numbers are the prototype's, and they are content
///
/// The kcal and protein figures match the dictionary strings the screens render
/// ("540 kcal · 18 g protein"), so the row and its macros cannot disagree. When
/// the real pack lands, this file is deleted and nothing else changes — which is
/// the point of the library being an interface.
library;

import '../../../l10n/app_l10n.dart';
import '../data/egyptian_food_pack.dart';
import '../domain/food_library.dart';
import '../domain/item_id.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';

/// The foods the Eat screens name, in her language: the hand-written samples
/// first, then the bundled Egyptian dishes once they have loaded.
FoodLibrary eatSampleLibrary(AppL10n l10n) {
  return FoodLibrary([
    Food(
      foodId: 'koshari_bowl',
      names: [l10n.koshariBowl, l10n.koshariBowlMedium, 'koshari'],
      popularity: 95,
      sizes: [
        FoodSize(id: 'S', label: l10n.small, kcal: 380, proteinG: 13),
        FoodSize(id: 'M', label: l10n.medium, kcal: 540, proteinG: 18),
        FoodSize(id: 'L', label: l10n.large, kcal: 700, proteinG: 24),
      ],
    ),
    Food(
      foodId: 'boiled_eggs',
      names: [l10n.boiledEggs, l10n.twoBoiledEggs, 'eggs'],
      popularity: 88,
      sizes: [
        FoodSize(id: '1', label: '1', kcal: 78, proteinG: 6),
        FoodSize(id: '2', label: '2', kcal: 156, proteinG: 13),
        FoodSize(id: '3', label: '3', kcal: 234, proteinG: 19),
      ],
    ),
    Food(
      foodId: 'ful_baladi',
      names: [l10n.fulAndBaladi, 'ful'],
      popularity: 92,
      sizes: [FoodSize(id: 'M', label: l10n.medium, kcal: 410, proteinG: 22)],
    ),
    Food(
      foodId: 'molokhia_chicken',
      names: [l10n.molokhiaWithChicken, 'molokhia'],
      popularity: 80,
      sizes: [FoodSize(id: 'M', label: l10n.medium, kcal: 460, proteinG: 34)],
    ),
    Food(
      foodId: 'eggs_and_tea',
      names: [l10n.eggsAndTea],
      popularity: 75,
      sizes: [FoodSize(id: 'M', label: l10n.medium, kcal: 290, proteinG: 14)],
    ),
    Food(
      foodId: 'lentil_soup_eggs',
      names: [l10n.lentilSoupAndEggs],
      popularity: 70,
      sizes: [FoodSize(id: 'M', label: l10n.medium, kcal: 380, proteinG: 26)],
    ),
    Food(
      foodId: 'chicken_and_rice',
      names: [l10n.chickenAndRice],
      popularity: 68,
      sizes: [FoodSize(id: 'M', label: l10n.medium, kcal: 520, proteinG: 38)],
    ),
    Food(
      foodId: 'koshari_and_salad',
      names: [l10n.koshariBowlAndSalad],
      popularity: 60,
      sizes: [FoodSize(id: 'M', label: l10n.medium, kcal: 600, proteinG: 21)],
    ),
    ...EgyptianFoodPack.foods(l10n),
  ]);
}

/// A resolved entry for [foodId] at its usual size, or null if the pack has
/// changed under us.
///
/// Used by the screens to turn a row the design names into something loggable,
/// so the label and the write read the same object.
ParsedItem? entryFor(FoodLibrary library, String foodId, {String? sizeId}) {
  final food = library.byId(foodId);
  if (food == null) return null;
  final size = sizeId == null ? food.defaultSize : food.sizeById(sizeId);
  if (size == null) return null;
  return ParsedItem(
    food: food,
    size: size,
    servings: 1,
    sourceText: food.names.first,
  );
}

/// The plate rows E01 and E04 offer before she has any history of her own.
///
/// These are the dishes the prototype draws. They are **not** a ranking: a woman
/// with no logs has no frequency to rank by, and inventing one would put a
/// number on the screen that describes nobody.
List<PlateItem> plateItemsFor(List<String> foodIds) => [
  for (final id in foodIds) PlateItem(foodId: id, size: 'M'),
];

// ------------------------------------------------- E05–E08 content labels --
//
// The recipe pack (G5 §1.2, ~120 recipes) has not been built either, so these
// map the ids E07 and E08 use onto the titles the prototype names. Same
// arrangement as the foods above, and they disappear the same way when the real
// pack lands.

/// A recipe title, by id.
String recipeLabel(AppL10n l10n, String recipeId) => switch (recipeId) {
  'molokhia_chicken' => l10n.molokhiaWithChicken,
  'koshari_portioned' => l10n.koshariPortioned,
  'lentil_soup_eggs' => l10n.lentilSoupAndEggs,
  'grilled_chicken_salad' => l10n.grilledChickenAndSalad,
  'ful_with_egg' => l10n.fulWithEgg,
  'ful_with_egg_cumin' => l10n.fulWithEggAndCumin,
  'yoghurt_dates_nuts' => l10n.yoghurtDatesAndNuts,
  _ => l10n.koshariPortioned,
};

/// The weekday a planned dinner sits on.
///
/// Saturday and Sunday have no full-name key in the dictionary — only `sat` and
/// `sun` — so those two render short, exactly as `weekdayLabel` in
/// `today_cards.dart` records. Flagged there rather than papered over with an
/// invented string, and the same applies here.
String weekdayLabelFor(AppL10n l10n, PlanDay day) => switch (day) {
  PlanDay.mon => l10n.monday,
  PlanDay.tue => l10n.tuesday,
  PlanDay.wed => l10n.wednesday,
  PlanDay.thu => l10n.thursday,
  PlanDay.fri => l10n.friday,
  PlanDay.sat => l10n.sat,
  PlanDay.sun => l10n.sun,
};

/// A grocery section heading.
String groceryGroupLabel(AppL10n l10n, GroceryGroup group) => switch (group) {
  GroceryGroup.vegetables => l10n.vegetables,
  GroceryGroup.protein => l10n.protein,
  GroceryGroup.cupboard => l10n.cupboard,
};

/// One grocery line, with its quantity — "Tomatoes 1 kg".
///
/// The quantity is part of the dictionary string rather than computed, because
/// the dictionary ships no parameterised form for it. The fallback returns the
/// id, which is unreachable from [sampleMealPlan] and is deliberately not a
/// guessed translation.
String groceryLabel(AppL10n l10n, String ingredientId) =>
    switch (ingredientId) {
      'tomatoes' => l10n.tomatoes1Kg,
      'onions' => l10n.onions1Kg,
      'molokhia' => l10n.molokhiaFrozen400G,
      'chicken' => l10n.chicken1Kg,
      'eggs' => l10n.eggs20,
      'lentils' => l10n.lentils500G,
      'rice' => l10n.rice1Kg,
      'pasta' => l10n.pasta500G,
      'cumin' => l10n.cumin,
      _ => ingredientId,
    };

/// The week E07 and E08 draw.
///
/// Five dinners and the nine lines they need, keyed the way two devices
/// converge on — `sha1(ingredientId + ':' + unit)`. The prototype's card says
/// "23 items"; the list it draws has nine, and the card's figure is a mockup
/// number with no placeholder form in the dictionary.
MealPlan sampleMealPlan(String weekId) {
  GroceryLine line(
    String ingredientId,
    GroceryGroup group, {
    bool ticked = false,
  }) {
    return GroceryLine(
      itemKey: groceryItemKey(ingredientId: ingredientId, unit: 'kg'),
      ingredientId: ingredientId,
      group: group,
      ticked: ticked,
    );
  }

  final lines = [
    // The prototype draws the first line of each group already ticked.
    line('tomatoes', GroceryGroup.vegetables, ticked: true),
    line('onions', GroceryGroup.vegetables),
    line('molokhia', GroceryGroup.vegetables),
    line('chicken', GroceryGroup.protein),
    line('eggs', GroceryGroup.protein),
    line('lentils', GroceryGroup.protein),
    line('rice', GroceryGroup.cupboard),
    line('pasta', GroceryGroup.cupboard),
    line('cumin', GroceryGroup.cupboard),
  ];

  return MealPlan(
    weekId: weekId,
    dinners: const {
      PlanDay.mon: 'molokhia_chicken',
      PlanDay.tue: 'koshari_portioned',
      PlanDay.wed: 'lentil_soup_eggs',
      PlanDay.thu: 'grilled_chicken_salad',
      PlanDay.fri: 'ful_with_egg',
    },
    groceries: {for (final l in lines) l.itemKey: l},
  );
}
