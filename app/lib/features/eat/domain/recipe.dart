/// A recipe, as the Eat tab holds one.
///
/// Pure Dart, no Flutter import, for the same reason `food_library.dart` is
/// pure: the rules that decide whether a dish may be shown to a woman with a
/// nut allergy should be testable without a widget tree.
///
/// ## Two kinds, and the difference is visible on screen
///
/// [RecipeSource.book] and [RecipeSource.authored] are **recipes with a person
/// behind them**, and which person is on the row: [Recipe.authoredBy]. A book
/// card is Rahma's, in her Egyptian colloquial, with her name. An authored one
/// may be Own Hub's kitchen's ([kOwnHubKitchen]): written in the app's neutral
/// voice, in English and Egyptian Arabic, never drawn as hers. A book card
/// publishes once Rahma has signed it. One of Own Hub's kitchen publishes on the
/// automated check ([RecipeVerification]) and carries no person's name.
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
/// `lib/`, which is exactly right: her words are content, the interface is the
/// app's own voice, and the two reach the screen through different pipes so
/// they cannot be smeared together. The reverse also holds: no safety sentence
/// is ever on this type. [doneness] and [advisories] are **tokens**, and the
/// sentence each one renders lives in the dictionary.
library;

import 'package:meta/meta.dart';

import 'meal_images.dart';

/// The `authoredBy` of a recipe Own Hub's kitchen wrote, and of the structured
/// record behind every book card. Never Rahma: a card written here is not hers.
const String kOwnHubKitchen = 'ownhub_kitchen';

/// Who wrote it, and therefore how it is drawn.
enum RecipeSource {
  /// From `Rahoma's Recipe Book.pdf`. [Recipe.sourcePage] says which page.
  book,

  /// Written afterwards through the same gate: by Rahma, in her voice, or by
  /// Own Hub's kitchen ([kOwnHubKitchen]), in English and Egyptian Arabic.
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

  static RecipeStatus fromWire(String wire) => values.firstWhere(
    (v) => v.name == wire,
    orElse: () => RecipeStatus.draft,
  );
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

  static MacroBasis fromWire(String wire) => values.firstWhere(
    (v) => v.name == wire,
    orElse: () => MacroBasis.withheld,
  );
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

  static GramsBasis fromWire(String wire) => values.firstWhere(
    (v) => v.name == wire,
    orElse: () => GramsBasis.unknown,
  );
}

/// What the page actually gives by way of an ingredient list.
///
/// Her book is a Canva page, not a database, and it is not uniform. Most cards
/// give a measure for nearly everything. Five name what goes in and mostly not
/// how much. One — `Lahma bel basl` — has no ingredient list at all and is
/// written as a method.
///
/// This exists so the screen can **say which**, rather than printing an
/// "Ingredients" heading over "the meat, the oil, the onion" and letting a
/// woman conclude the app lost the amounts.
enum IngredientsBasis {
  /// A measure for essentially every line.
  measures,

  /// She names them; she mostly does not say how much.
  few,

  /// No ingredient list on the page. What goes in is named in the steps.
  none;

  static IngredientsBasis fromWire(String wire) => values.firstWhere(
    (v) => v.name == wire,
    // A value this build does not know reads as the least claim, not the most.
    orElse: () => IngredientsBasis.measures,
  );
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
    this.qtyTextEn,
  });

  factory RecipeIngredient.fromJson(Map<String, Object?> json) =>
      RecipeIngredient(
        ingredientRef: json['ingredientRef']! as String,
        qtyTextAr: json['qtyTextAr']! as String,
        qtyTextEn: json['qtyTextEn'] as String?,
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
  ///
  /// **May contain one of her line breaks.** The book wraps mid-phrase — `نص
  /// معلقه` reaches the right margin and `baking powder` starts the next line —
  /// and the phrase is one phrase. The span carries the break so it stays a
  /// verbatim slice of [Recipe.bodyAr]; [qtyLine] is what a row draws.
  final String qtyTextAr;

  /// [qtyTextAr] as one line, for a row a woman reads while shopping.
  ///
  /// Only the line breaks close up. Nothing is reworded, nothing is reordered,
  /// and the stored string stays the verbatim slice the substring test checks.
  String get qtyLine => qtyTextAr.replaceAll('\n', ' ');

  /// The same phrase in English, on a recipe Own Hub wrote. Null on a book card:
  /// her words are never translated.
  final String? qtyTextEn;

  /// The phrase in the language she reads, falling back to [qtyLine] where
  /// there is no English.
  String qtyLineFor({required bool arabic}) =>
      arabic ? qtyLine : (qtyTextEn ?? qtyLine);

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
    this.textEn,
  });

  factory RecipeStep.fromJson(Map<String, Object?> json) => RecipeStep(
    index: json['index']! as int,
    textAr: json['textAr']! as String,
    textEn: json['textEn'] as String?,
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

  /// The same step in English, on a recipe Own Hub wrote. Null on a book card.
  final String? textEn;

  /// The step in the language she reads, falling back to [textAr].
  String textFor({required bool arabic}) =>
      arabic ? textAr : (textEn ?? textAr);

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

/// Recipe id to the painted dish that truly is its main dish. Only exact
/// matches belong here; a recipe with no such dish keeps the drawn mark.
const Map<String, String> kRecipeDishPicture = {
  'rahma_shakshoka': 'shakshuka',
  'rahma_fattah': 'fattah_chicken',
  'rahma_hwawshi': 'hawawshi',
  'rahma_fool_wa_ta3mya': 'ful_taameya_breakfast',
  'ownhub_light_mahshi_peppers': 'mahshi_peppers',
};

/// The record Own Hub's automated check leaves on a recipe it has verified.
///
/// This is a script's statement, never a person's: it says the ingredients all
/// resolve in the food pack, the allergens were derived from the foods and a
/// keyword scan, the figures were recomputed from the grams and the method has
/// steps. It carries no name, and a recipe that has only this still has a null
/// [Recipe.allergenReviewedBy] and [Recipe.cookedBy].
@immutable
class RecipeVerification {
  const RecipeVerification({
    required this.method,
    required this.checkedAt,
    required this.allergensDerived,
    this.macroDeltaPct,
  });

  factory RecipeVerification.fromJson(Map<String, Object?> json) =>
      RecipeVerification(
        method: json['method'] as String? ?? '',
        checkedAt: DateTime.tryParse(json['checkedAt'] as String? ?? ''),
        macroDeltaPct: (json['macroDeltaPct'] as num?)?.toDouble(),
        allergensDerived: _tags(json['allergensDerived']),
      );

  /// The only method this build trusts. A record by any other method is kept
  /// but counts for nothing.
  static const String autoCheckMethod = 'ownhub-auto-check-v1';

  final String method;
  final DateTime? checkedAt;

  /// The largest gap, in percent, between the stated figures and the ones
  /// recomputed from the ingredients.
  final double? macroDeltaPct;

  /// What the check derived: the foods' allergens plus the keyword scan.
  final Set<String> allergensDerived;

  bool get isAutoCheck => method == autoCheckMethod;
}

/// Who stands behind what is said about a recipe's allergens.
enum RecipeCheck {
  /// A person signed it: `allergenReviewedBy` is set.
  signed,

  /// Only Own Hub's automated check. No person has looked at the dish.
  autoChecked,

  /// Nothing. Unknown, and therefore unsafe for a woman with an allergy.
  unchecked,
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
    required this.ingredientsBasis,
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
    this.photoPath,
    this.verification,
    this.reviewNotes = const [],
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
    ingredientsBasis: IngredientsBasis.fromWire(
      json['ingredientsBasis'] as String? ?? '',
    ),
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
    allergensRemoved: ((json['allergensRemoved'] as Map?) ?? const {})
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
    photoPath: _photoPath(json['photoPath']),
    tier: RecipeTier.fromWire(json['tier'] as String? ?? ''),
    brandHints: ((json['brandHints'] as Map?) ?? const {})
        .cast<String, Object?>()
        .map((k, v) => MapEntry(k, v as String? ?? '')),
    reviewNotes: ((json['reviewNotes'] as List?) ?? const []).cast<String>(),
    verification: switch (json['verification']) {
      final Map<dynamic, dynamic> v => RecipeVerification.fromJson(
        v.cast<String, Object?>(),
      ),
      _ => null,
    },
  );

  final String recipeId;

  /// The painted picture: the recipe's own when it has one, else the painted
  /// picture of its main dish where [kRecipeDishPicture] names one, else null
  /// and the screen keeps its drawn mark.
  String? get imageAsset =>
      MealImages.assetFor(recipeId) ??
      switch (kRecipeDishPicture[recipeId]) {
        final foodId? => MealImages.assetFor(foodId),
        null => null,
      };
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
  /// from the dictionary: a title in the app's voice over an Egyptian
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

  /// What the page gives by way of an ingredient list. See [IngredientsBasis]:
  /// the screen says which, rather than letting a short list read as a fault.
  final IngredientsBasis ingredientsBasis;

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

  /// `pregnancy_liver`, `g6pd_fava`. Tokens, not sentences: the copy lives
  /// in the dictionary. Rendered as a note and **never used to filter**,
  /// because this is not something she ticked.
  final Set<String> advisories;

  final Set<String> dietTags;

  /// A token from a fixed vocabulary, not free text, for the same reason
  /// [advisories] are tokens: the sentence a woman reads about undercooked
  /// chicken is safety copy, so it is in the app's voice, it is in the dictionary,
  /// and it is typographically unlike anything Rahma says.
  final String? doneness;

  final int? sourcePage;
  final String authoredBy;

  /// A person's signature on the allergens. Null on a recipe only the automated
  /// check has verified; it is never filled in for one. When set it must differ
  /// from [authoredBy]. Two people, enforced in `firestore.rules` as well as in
  /// Dart, so a bug here cannot bypass it.
  final String? allergenReviewedBy;
  final DateTime? allergenReviewedAt;

  /// Who actually cooked it. Null until a person has: times, temperatures,
  /// quantities and doneness come out of a real kitchen, and the automated
  /// check does not stand in for that.
  final String? cookedBy;
  final DateTime? cookedAt;

  /// A drawn food mark, in the app's own hand. See `food_marks.dart`.
  final String? markKey;

  /// Her photo in the content library (`content/recipes/{id}/{file}`), or
  /// null. A drawn mark stands in wherever it cannot be loaded.
  final String? photoPath;

  final RecipeTier tier;

  /// ingredientRef, or her quantity phrase, to the brand she names.
  final Map<String, String> brandHints;

  /// What Own Hub's automated check recorded, or null. Never a person's name.
  final RecipeVerification? verification;

  /// What a reviewer should know before signing: which amounts are ours, what
  /// the figures leave out. English, for the dashboard; never drawn to a woman.
  final List<String> reviewNotes;

  /// Written by Own Hub's kitchen rather than taken from Rahma's book. It reads
  /// in the app's language and is never drawn as her card.
  bool get isOwnHub =>
      source == RecipeSource.authored && authoredBy == kOwnHubKitchen;

  /// True when a person has signed what is in this dish.
  ///
  /// This is about people only. Whether the allergen list may be relied on at
  /// all is [allergensKnown], which also counts the automated check.
  bool get allergensReviewed =>
      allergenReviewedBy != null && allergenReviewedBy!.isNotEmpty;

  /// True when Own Hub's automated check verified this recipe and its record
  /// holds up: the right method, a date, and nothing derived that the recorded
  /// allergens leave out. A record that disagrees with the recipe it sits on
  /// counts for nothing, and so does any record on a recipe Own Hub did not
  /// write: Rahma's book cards need her signature, never a script's.
  bool get autoChecked {
    final v = verification;
    return source == RecipeSource.authored &&
        v != null &&
        v.isAutoCheck &&
        v.checkedAt != null &&
        allergensFinal.containsAll(v.allergensDerived);
  }

  /// Whether the allergens of this dish are known: a person signed them, or
  /// the automated check verified them.
  ///
  /// Read by `AllergyGuard`: a recipe whose allergens are not known is never
  /// returned to a woman who has declared an allergy, because unknown is unsafe,
  /// never safe by default. For everyone else it stays in the list and carries
  /// a visible note.
  bool get allergensKnown => allergensReviewed || autoChecked;

  /// Who stands behind its allergen list. A person's signature wins.
  RecipeCheck get check => allergensReviewed
      ? RecipeCheck.signed
      : autoChecked
      ? RecipeCheck.autoChecked
      : RecipeCheck.unchecked;

  /// The words that say whose check this is, or null when nobody's.
  ///
  /// A book card that a person signed reads "From Rahma's book". Rahma's name
  /// goes only on her own cards. A recipe that only the automated check has
  /// verified reads "Checked by Own Hub", never anything with a person's name.
  String? get verifiedLabel => switch (check) {
    RecipeCheck.signed =>
      source == RecipeSource.book ? "From Rahma's book" : null,
    RecipeCheck.autoChecked => 'Checked by Own Hub',
    RecipeCheck.unchecked => null,
  };

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

/// A photo uploaded to the content library, or null. Only a path under
/// `content/recipes/` is taken: anything else is not a place the app reads.
String? _photoPath(Object? raw) =>
    raw is String && raw.startsWith('content/recipes/') && !raw.contains('..')
    ? raw
    : null;

List<RecipeIngredient> _ingredients(Object? raw) => [
  for (final i in (raw as List?) ?? const [])
    RecipeIngredient.fromJson((i as Map).cast<String, Object?>()),
];

List<RecipeStep> _steps(Object? raw) => [
  for (final s in (raw as List?) ?? const [])
    RecipeStep.fromJson((s as Map).cast<String, Object?>()),
];

Set<String> _tags(Object? raw) => {
  for (final t in (raw as List?) ?? const [])
    (t as String).trim().toLowerCase(),
};
