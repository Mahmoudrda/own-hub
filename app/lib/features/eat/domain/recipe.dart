/// A recipe, as the Eat tab holds one.
///
/// Pure Dart, no Flutter import, for the same reason `food_library.dart` is
/// pure: the rules that decide whether a dish may be shown to a woman with a
/// nut allergy should be testable without a widget tree.
///
/// ## Two kinds, and the difference is visible on screen
///
/// [RecipeSource.book] and [RecipeSource.authored] are **Rahma's**. Her card,
/// her Egyptian colloquial, her name. Every one of them is written by her and
/// cooked before it publishes.
///
/// [RecipeSource.assembly] is **not a recipe and is not presented as one**: a
/// named combination of verified `foods` rows with stated portions and no
/// cooking step, so its macros are summed rather than invented and its
/// allergens are a union of verified sets rather than a claim. Assemblies
/// render in the app's own visual language under their own heading and
/// **never on her card**, because a woman has to be able to tell in a glance
/// which words are Rahma's.
///
/// ## Null means the row does not say
///
/// Copied from `RecipeRow`: "Null means the row does not say, and a row that
/// does not say never matches a filter." Every nullable field here obeys it, so
/// "under 20 minutes" cannot offer a dish whose time nobody wrote down.
///
/// [allergensFinal] is the exception that proves it, and it is deliberately
/// **not** nullable and deliberately not empty-by-default. An empty set means
/// "checked, and contains none of the sixteen", which is a statement only a
/// signed review is entitled to make. What carries "nobody has checked" is
/// [allergenReviewedBy] being null, which is a different fact and has its own
/// field.
///
/// ## Where the text comes from
///
/// Everything Arabic on this type arrives from `assets/content/rahma_recipes.json`
/// and never from the ARB. `i18n_guard_test.dart` forbids Arabic literals under
/// `lib/`, which is exactly right: her colloquial is content, the interface is
/// Modern Standard, and the two reach the screen through different pipes so
/// they cannot be smeared together. The reverse also holds: no safety sentence
/// is ever on this type. [doneness] and [advisories] are **tokens**, and the
/// MSA sentence each one renders lives in the dictionary.
library;

import 'package:meta/meta.dart';

/// Who wrote it, and therefore how it is drawn.
enum RecipeSource {
  /// From `Rahoma's Recipe Book.pdf`. [Recipe.sourcePage] says which page.
  book,

  /// Written by Rahma afterwards, in the same voice, through the same gate.
  authored,

  /// A combination of verified foods. Not hers, not on her card. See the file
  /// note.
  assembly;

  static RecipeSource fromWire(String wire) => values.firstWhere(
    (v) => v.name == wire,
    // A source nobody recognises is the least trusted thing in the file, so it
    // reads as an assembly: the one kind that never wears her name.
    orElse: () => RecipeSource.assembly,
  );
}

/// How far through authoring it is.
///
/// [published] is the only value that asserts anything. [draft] and [review]
/// both mean "a person is still working on this", and the difference between
/// them is whether it is fit to be read at all.
enum RecipeStatus {
  draft,
  review,
  published;

  static RecipeStatus fromWire(String wire) =>
      values.firstWhere((v) => v.name == wire, orElse: () => RecipeStatus.draft);
}

/// Whether the four macro fields were summed or withheld.
///
/// The same discipline as `stated_figure.dart`: a figure reaches her only when
/// it is true of her. [withheld] means every macro field is null and the screen
/// says nothing at all, rather than a zero or a dash, because a zero is a claim
/// and a dash is a shrug.
enum MacroBasis {
  computed,
  withheld;

  static MacroBasis fromWire(String wire) =>
      values.firstWhere((v) => v.name == wire, orElse: () => MacroBasis.withheld);
}

/// Where a gram figure came from.
enum GramsBasis {
  /// She wrote the grams. Six recipes in the book do.
  stated,

  /// Somebody weighed it in an Egyptian kitchen and recorded who, when and
  /// which product in [RecipeIngredient.gramsNote].
  measured,

  /// From the household-measure table. Permitted only where the ingredient
  /// contributes under 20 kcal a serving, because an Egyptian `علبة زبادي` is
  /// not a US tub and the difference is about 40 kcal.
  estimated,

  /// The book does not say and nobody has weighed it. Fine in review, never in
  /// [RecipeStatus.published].
  unknown;

  static GramsBasis fromWire(String wire) =>
      values.firstWhere((v) => v.name == wire, orElse: () => GramsBasis.unknown);
}

/// Free or paid. Modelled now, sold never — see `recipe_access_gate.dart`.
enum RecipeTier {
  free,
  pro;

  static RecipeTier fromWire(String wire) =>
      values.firstWhere((v) => v.name == wire, orElse: () => RecipeTier.free);
}

/// One line of her ingredient list.
@immutable
class RecipeIngredient {
  const RecipeIngredient({
    required this.ingredientRef,
    required this.qtyTextAr,
    required this.gramsBasis,
    this.foodId,
    this.grams,
    this.gramsNote,
    this.optional = false,
    this.servingSideOnly = false,
    this.brandHint,
  });

  factory RecipeIngredient.fromJson(Map<String, Object?> json) =>
      RecipeIngredient(
        ingredientRef: json['ingredientRef']! as String,
        qtyTextAr: json['qtyTextAr']! as String,
        gramsBasis: GramsBasis.fromWire(json['gramsBasis'] as String? ?? ''),
        foodId: json['foodId'] as String?,
        grams: json['grams'] as int?,
        gramsNote: json['gramsNote'] as String?,
        optional: json['optional'] as bool? ?? false,
        servingSideOnly: json['servingSideOnly'] as bool? ?? false,
        brandHint: json['brandHint'] as String?,
      );

  /// Stable within the recipe. Steps name it in [RecipeStep.usesRefs].
  final String ingredientRef;

  /// Into `foods`. **Null blocks publication**: an ingredient nobody can look
  /// up is an allergen nobody can check.
  final String? foodId;

  /// Her words, verbatim, and what the screen shows first at full size.
  final String qtyTextAr;

  final int? grams;
  final GramsBasis gramsBasis;
  final String? gramsNote;

  /// She wrote `اختياري` beside it.
  final bool optional;

  /// A serving suggestion rather than part of the dish: `تتقدم مع: ½ رغيف`.
  final bool servingSideOnly;

  /// The brand she names, kept as her aside while [foodId] points at the
  /// generic. Shipping a brand dependency means a recipe that breaks when a
  /// product is reformulated, and an allergen claim about someone else's
  /// packet.
  final String? brandHint;
}

/// One of her steps. [textAr] is a slice of [Recipe.bodyAr], never a rewrite.
@immutable
class RecipeStep {
  const RecipeStep({
    required this.index,
    required this.textAr,
    required this.usesRefs,
    this.minutes,
    this.tempC,
    this.tool,
    this.isTimer = false,
  });

  factory RecipeStep.fromJson(Map<String, Object?> json) => RecipeStep(
    index: json['index']! as int,
    textAr: json['textAr']! as String,
    usesRefs: ((json['usesRefs'] as List?) ?? const []).cast<String>(),
    minutes: json['minutes'] as int?,
    tempC: json['tempC'] as int?,
    tool: json['tool'] as String?,
    isTimer: json['isTimer'] as bool? ?? false,
  );

  /// 1-based, and her numbering where she numbered.
  final int index;

  /// Her sentence. A test asserts this is a substring of [Recipe.bodyAr].
  final String textAr;

  final int? minutes;
  final int? tempC;

  /// `oven`, `air_fryer`, `pan`, `pot`, `fridge`, `freezer`, `blender`.
  final String? tool;

  final List<String> usesRefs;

  /// True only for a step she is standing over. A day in the fridge is not
  /// something to count down on a phone.
  final bool isTimer;
}

/// A named part of a card that the book heads separately: a sauce, a bechamel.
///
/// Not a separate recipe, and never counted as one.
@immutable
class RecipeComponent {
  const RecipeComponent({
    required this.componentId,
    required this.headingAr,
    required this.ingredients,
    required this.steps,
  });

  factory RecipeComponent.fromJson(Map<String, Object?> json) =>
      RecipeComponent(
        componentId: json['componentId']! as String,
        headingAr: json['headingAr']! as String,
        ingredients: _ingredients(json['ingredients']),
        steps: _steps(json['steps']),
      );

  final String componentId;

  /// As the book prints it: `Chocolate sauce`, `طحينه لايت:`, `البشاميل:`.
  final String headingAr;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
}

/// One of two complete alternative methods on a single card.
///
/// `Cheese cake` is the only one today. A variant is **not** a separate recipe
/// and must not be counted as one.
@immutable
class RecipeVariant {
  const RecipeVariant({
    required this.variantId,
    required this.labelAr,
    required this.ingredients,
    required this.steps,
  });

  factory RecipeVariant.fromJson(Map<String, Object?> json) => RecipeVariant(
    variantId: json['variantId']! as String,
    labelAr: json['labelAr']! as String,
    ingredients: _ingredients(json['ingredients']),
    steps: _steps(json['steps']),
  );

  final String variantId;
  final String labelAr;
  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
}

/// A section of her book: its English title and its PS line, verbatim.
@immutable
class RecipeSection {
  const RecipeSection({
    required this.sectionId,
    required this.titleEn,
    required this.psLineEn,
    required this.order,
    required this.markKey,
    this.titleAr,
    this.psLineAr,
  });

  factory RecipeSection.fromJson(Map<String, Object?> json) => RecipeSection(
    sectionId: json['sectionId']! as String,
    titleEn: json['titleEn']! as String,
    psLineEn: json['psLineEn']! as String,
    order: json['order']! as int,
    markKey: json['markKey']! as String,
    titleAr: json['titleAr'] as String?,
    psLineAr: json['psLineAr'] as String?,
  );

  final String sectionId;

  /// Verbatim, including `Salty fulling Breakfast`. Her spelling is hers and is
  /// not a typo to fix; it is the voice the product is built on.
  final String titleEn;
  final String? titleAr;

  /// Verbatim, including the missing `PS:` on section three.
  final String psLineEn;
  final String? psLineAr;

  final int order;
  final String markKey;
}

@immutable
class Recipe {
  const Recipe({
    required this.recipeId,
    required this.source,
    required this.sectionId,
    required this.orderInSection,
    required this.status,
    required this.version,
    required this.titleEn,
    required this.titleSearch,
    required this.bodyAr,
    required this.ingredients,
    required this.steps,
    required this.variants,
    required this.components,
    required this.macroBasis,
    required this.allergensDerived,
    required this.allergensExtra,
    required this.allergensRemoved,
    required this.allergensFinal,
    required this.advisories,
    required this.dietTags,
    required this.authoredBy,
    required this.tier,
    required this.brandHints,
    this.titleAr,
    this.closingAr,
    this.serves,
    this.activeMinutes,
    this.totalMinutes,
    this.kcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
    this.egpPerServing,
    this.egpPricedAt,
    this.doneness,
    this.sourcePage,
    this.allergenReviewedBy,
    this.allergenReviewedAt,
    this.cookedBy,
    this.cookedAt,
    this.markKey,
  });

  factory Recipe.fromJson(Map<String, Object?> json) => Recipe(
    recipeId: json['recipeId']! as String,
    source: RecipeSource.fromWire(json['source'] as String? ?? ''),
    sectionId: json['sectionId']! as String,
    orderInSection: json['orderInSection'] as int? ?? 0,
    status: RecipeStatus.fromWire(json['status'] as String? ?? ''),
    version: json['version'] as int? ?? 1,
    titleEn: json['titleEn']! as String,
    titleAr: json['titleAr'] as String?,
    titleSearch: ((json['titleSearch'] as List?) ?? const []).cast<String>(),
    bodyAr: json['bodyAr'] as String? ?? '',
    closingAr: json['closingAr'] as String?,
    ingredients: _ingredients(json['ingredients']),
    steps: _steps(json['steps']),
    variants: [
      for (final v in (json['variants'] as List?) ?? const [])
        RecipeVariant.fromJson((v as Map).cast<String, Object?>()),
    ],
    components: [
      for (final c in (json['components'] as List?) ?? const [])
        RecipeComponent.fromJson((c as Map).cast<String, Object?>()),
    ],
    serves: json['serves'] as int?,
    activeMinutes: json['activeMinutes'] as int?,
    totalMinutes: json['totalMinutes'] as int?,
    kcal: json['kcal'] as int?,
    proteinG: json['proteinG'] as int?,
    carbsG: json['carbsG'] as int?,
    fatG: json['fatG'] as int?,
    macroBasis: MacroBasis.fromWire(json['macroBasis'] as String? ?? ''),
    egpPerServing: json['egpPerServing'] as int?,
    egpPricedAt: DateTime.tryParse(json['egpPricedAt'] as String? ?? ''),
    allergensDerived: _tags(json['allergensDerived']),
    allergensExtra: _tags(json['allergensExtra']),
    allergensRemoved:
        ((json['allergensRemoved'] as Map?) ?? const {})
            .cast<String, Object?>()
            .map((k, v) => MapEntry(k, v as String? ?? '')),
    allergensFinal: _tags(json['allergensFinal']),
    advisories: _tags(json['advisories']),
    dietTags: _tags(json['dietTags']),
    doneness: json['doneness'] as String?,
    sourcePage: json['sourcePage'] as int?,
    authoredBy: json['authoredBy'] as String? ?? '',
    allergenReviewedBy: json['allergenReviewedBy'] as String?,
    allergenReviewedAt: DateTime.tryParse(
      json['allergenReviewedAt'] as String? ?? '',
    ),
    cookedBy: json['cookedBy'] as String?,
    cookedAt: DateTime.tryParse(json['cookedAt'] as String? ?? ''),
    markKey: json['markKey'] as String?,
    tier: RecipeTier.fromWire(json['tier'] as String? ?? ''),
    brandHints:
        ((json['brandHints'] as Map?) ?? const {})
            .cast<String, Object?>()
            .map((k, v) => MapEntry(k, v as String? ?? '')),
  );

  final String recipeId;
  final RecipeSource source;
  final String sectionId;
  final int orderInSection;
  final RecipeStatus status;
  final int version;

  /// Verbatim from the book, arabizi and all: `shorbt 3ads`, `Fool & Ta3mya`,
  /// `Btates bel lahma`. **Not corrected.** The arabizi is the voice; search is
  /// served by [titleSearch], which is never rendered.
  final String titleEn;

  /// Null until Rahma writes it. Not translated from [titleEn] and not filled
  /// from the MSA dictionary: a Modern Standard title over an Egyptian
  /// colloquial body is exactly the register mixing the voice boundary exists
  /// to prevent.
  final String? titleAr;

  /// Normalised forms, for matching only. Never drawn.
  final List<String> titleSearch;

  /// The card as the book prints it, one block, her line breaks.
  final String bodyAr;

  /// Her sign-off, where the book gives it a line of its own.
  final String? closingAr;

  final List<RecipeIngredient> ingredients;
  final List<RecipeStep> steps;
  final List<RecipeVariant> variants;
  final List<RecipeComponent> components;

  final int? serves;
  final int? activeMinutes;
  final int? totalMinutes;

  final int? kcal;
  final int? proteinG;
  final int? carbsG;
  final int? fatG;
  final MacroBasis macroBasis;

  final int? egpPerServing;

  /// Required whenever [egpPerServing] is set. An undated EGP figure in Egypt
  /// is wrong within a quarter, so the screen renders the month beside it and a
  /// test fails the build when a published one goes stale.
  final DateTime? egpPricedAt;

  final Set<String> allergensDerived;
  final Set<String> allergensExtra;

  /// Tag to the written reason it does not apply. An empty reason is a
  /// validation failure: removing an allergen silently is the one edit in this
  /// file that can hurt somebody.
  final Map<String, String> allergensRemoved;

  /// derived ∪ extra − removed. What the screen names.
  final Set<String> allergensFinal;

  /// `pregnancy_liver`, `g6pd_fava`. Tokens, not sentences: the MSA copy lives
  /// in the dictionary. Rendered as a note and **never used to filter**,
  /// because this is not something she ticked.
  final Set<String> advisories;

  final Set<String> dietTags;

  /// A token from a fixed vocabulary, not free text, for the same reason
  /// [advisories] are tokens: the sentence a woman reads about undercooked
  /// chicken is safety copy, so it is Modern Standard, it is in the dictionary,
  /// and it is typographically unlike anything Rahma says.
  final String? doneness;

  final int? sourcePage;
  final String authoredBy;

  /// Must be non-null and different from [authoredBy] to publish. Two people,
  /// enforced in `firestore.rules` rather than in Dart, so a bug here cannot
  /// bypass it.
  final String? allergenReviewedBy;
  final DateTime? allergenReviewedAt;

  /// Who actually cooked it. Non-null or an authored recipe does not publish:
  /// times, temperatures, quantities and doneness all come out of a real
  /// kitchen or they are guesses wearing a recipe's clothes.
  final String? cookedBy;
  final DateTime? cookedAt;

  /// A drawn food mark, in the app's own hand. See `food_marks.dart`.
  final String? markKey;

  final RecipeTier tier;

  /// ingredientRef, or her quantity phrase, to the brand she names.
  final Map<String, String> brandHints;

  /// True when a person has signed what is in this dish.
  ///
  /// Read by `AllergyGuard`: an unsigned recipe is never returned to a woman
  /// who has declared an allergy, and carries a visible note for everyone else.
  /// It is never silently presented as fine.
  bool get allergensReviewed =>
      allergenReviewedBy != null && allergenReviewedBy!.isNotEmpty;

  /// Everything the woman actually cooks from, in the order the card prints it.
  ///
  /// Her flat steps first, then each component under its own heading. Variants
  /// are deliberately excluded: they are alternatives, and a screen that
  /// concatenated them would tell her to make the cheesecake twice.
  List<RecipeStep> get allSteps => [
    ...steps,
    for (final component in components) ...component.steps,
  ];

  /// Whether [text] matches this recipe, for the local search over the index.
  ///
  /// Matches [titleSearch] and [titleEn] only. It does **not** search her body
  /// text: a woman typing "لبن" wants dishes with milk in them, and a substring
  /// hit on a forty-line card is not that, it is noise that looks like a
  /// feature.
  bool matches(String text) {
    final needle = text.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (titleEn.toLowerCase().contains(needle)) return true;
    if ((titleAr ?? '').contains(needle)) return true;
    return titleSearch.any((t) => t.toLowerCase().contains(needle));
  }
}

List<RecipeIngredient> _ingredients(Object? raw) => [
  for (final i in (raw as List?) ?? const [])
    RecipeIngredient.fromJson((i as Map).cast<String, Object?>()),
];

List<RecipeStep> _steps(Object? raw) => [
  for (final s in (raw as List?) ?? const [])
    RecipeStep.fromJson((s as Map).cast<String, Object?>()),
];

Set<String> _tags(Object? raw) => {
  for (final t in (raw as List?) ?? const []) (t as String).trim().toLowerCase(),
};
