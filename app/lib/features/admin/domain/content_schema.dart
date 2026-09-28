/// The four CSV contracts — G16 §3.4, and the templates in
/// `6-v2/content/templates/`.
///
/// This is the single description of what a content file may contain. The
/// importer validates against it, the exporter writes from it, and Z08 draws its
/// "columns it expects" table from it, so the contract staff are shown, the
/// contract enforced and the contract written back out cannot drift apart.
///
/// ## Required, and mandatory-safety, are two different ideas
///
/// Both refuse a blank cell, and they are still not the same:
///
///   * [ContentColumn.required] — the row is unusable without it. A food with no
///     `name_ar` is invisible to half the product's readers.
///   * [ContentColumn.safetyTag] — the row is *dangerous* without it.
///     `SCHEMA-SPINE.md` §1: `contraindicationTags[]` and `allergens[]` are
///     "mandatory, not enrichment… without them the safety rules are
///     decorative". `AllergyGuard` reads a missing tag as *unknown, therefore
///     unsafe* and fails closed, so a blank cell does not degrade the feature —
///     it starts interrupting women who have no allergy at all.
///
/// Every safety column is also required. The distinction exists because Z01
/// leads with **how many rows are missing a safety tag**, which is a narrower
/// and more alarming number than how many rows are incomplete.
///
/// ## `none` is a value; blank is not
///
/// §3.2: "A mandatory safety column must carry an explicit value. `none` is
/// valid and means 'this contains no allergens'. Empty is rejected." Nothing in
/// this file treats `none` specially — it is ordinary content — and that is the
/// point. The only thing refused is the absence of an answer.
///
/// ## Why `programs`, not `programmes`
///
/// The collection is spelled `programmes` on screen and `programs` in the file
/// name, the Firestore collection and the storage prefix. Both spellings are
/// deliberate and neither is a typo: `firebase/firestore.rules` already matches
/// `/programs/{id}`, and `6-v2/content/templates/programs.csv` is the file staff
/// are handed. The enum reads the way the product speaks; [fileName] and
/// [storagePrefix] read the way the data is addressed.
library;

import 'package:meta/meta.dart';

/// The four collections this console maintains.
///
/// These are exactly the four that `firebase/firestore.rules` opens to
/// `isAdmin()` and leaves readable to any signed-in account. There is
/// deliberately no fifth: nothing here addresses anything but the content
/// library.
enum ContentCollection { exercises, foods, recipes, programmes }

/// One column of one CSV, and every rule that applies to it.
@immutable
class ContentColumn {
  const ContentColumn(
    this.name, {
    this.required = false,
    this.list = false,
    this.numeric = false,
    this.boolean = false,
    this.safetyTag = false,
    this.media = false,
    this.video = false,
  });

  final String name;

  /// A blank cell is refused.
  final bool required;

  /// Pipe-separated: `dumbbell|barbell`, `vegetarian|vegan`.
  final bool list;

  /// A whole number, zero or more. §3.5: "macros numeric and non-negative".
  final bool numeric;

  /// `true` or `false`, in any case, and nothing else. An unrecognised value is
  /// refused rather than read as false — `quiet` decides whether a move is
  /// offered to a woman training in a flat with neighbours below, and a silent
  /// default puts jumping into her quiet programme.
  final bool boolean;

  /// Blank here is a safety failure, not merely an incomplete row.
  final bool safetyTag;

  /// Names a file that must be present in the media upload. §3.4: "A row naming
  /// a file that was never uploaded is a validation failure, not a broken link
  /// discovered later by a woman mid-workout."
  final bool media;

  /// Of the media columns, the ones that name a moving picture rather than a
  /// still.
  ///
  /// This exists for one caller — Z11, whose rows say "CSV + videos" for
  /// exercises and "CSV + photos" for recipes. Without it that sentence would
  /// be retyped on the screen as a `switch` over the four collections, which is
  /// the contract written down in a second place and free to drift from this
  /// one. `thumbFile` is deliberately **not** a video: it is the still frame
  /// beside the clip, and a collection whose only media were thumbnails would
  /// not be exporting videos.
  final bool video;
}

/// The contract for one collection.
@immutable
class ContentSchema {
  const ContentSchema._({
    required this.collection,
    required this.fileName,
    required this.storagePrefix,
    required this.columns,
  });

  final ContentCollection collection;

  /// The CSV file name, both on import and on export. §5's round trip depends
  /// on the two halves agreeing on it.
  final String fileName;

  /// Cloud Storage prefix, per §4. Always under `content/`.
  final String storagePrefix;

  final List<ContentColumn> columns;

  static ContentSchema of(ContentCollection collection) => switch (collection) {
    ContentCollection.exercises => _exercises,
    ContentCollection.foods => _foods,
    ContentCollection.recipes => _recipes,
    ContentCollection.programmes => _programmes,
  };

  /// The id column, which is always the first. §3.4: "`id` is stable and is what
  /// an update matches on."
  String get idColumn => columns.first.name;

  List<String> get columnNames => [for (final c in columns) c.name];

  /// Null when [name] is not part of this contract — which is itself the
  /// "unknown column" finding, rather than something to shrug at.
  ContentColumn? column(String name) {
    for (final c in columns) {
      if (c.name == name) return c;
    }
    return null;
  }

  List<String> get requiredColumns => [
    for (final c in columns)
      if (c.required) c.name,
  ];

  List<String> get safetyTagColumns => [
    for (final c in columns)
      if (c.safetyTag) c.name,
  ];

  List<String> get mediaColumns => [
    for (final c in columns)
      if (c.media) c.name,
  ];

  /// The media columns that name a clip rather than a still. Z11 says
  /// "CSV + videos" for a collection that has any, and "CSV + photos" for one
  /// whose media are all stills.
  List<String> get videoColumns => [
    for (final c in columns)
      if (c.video) c.name,
  ];

  List<String> get listColumns => [
    for (final c in columns)
      if (c.list) c.name,
  ];

  List<String> get numericColumns => [
    for (final c in columns)
      if (c.numeric) c.name,
  ];

  List<String> get booleanColumns => [
    for (final c in columns)
      if (c.boolean) c.name,
  ];

  static const ContentSchema _exercises = ContentSchema._(
    collection: ContentCollection.exercises,
    fileName: 'exercises.csv',
    storagePrefix: 'content/exercises',
    columns: [
      ContentColumn('exerciseId', required: true),
      ContentColumn('name_en', required: true),
      ContentColumn('name_ar', required: true),
      ContentColumn('equipment', list: true),
      ContentColumn('pattern'),
      // The reason the exercise safety filter is inert today: this column is
      // unauthored across the whole library.
      ContentColumn(
        'contraindicationTags',
        required: true,
        list: true,
        safetyTag: true,
      ),
      ContentColumn('quiet', required: true, boolean: true),
      ContentColumn('floorOnly', required: true, boolean: true),
      // Optional: a library may legitimately be imported before its filming is
      // finished. §3.4 requires only that a file which IS named exists.
      ContentColumn('videoFile', media: true, video: true),
      ContentColumn('thumbFile', media: true),
    ],
  );

  static const ContentSchema _foods = ContentSchema._(
    collection: ContentCollection.foods,
    fileName: 'foods.csv',
    storagePrefix: 'content/foods',
    columns: [
      ContentColumn('foodId', required: true),
      ContentColumn('name_en', required: true),
      ContentColumn('name_ar', required: true),
      ContentColumn('portions', list: true),
      ContentColumn('kcal', required: true, numeric: true),
      ContentColumn('proteinG', required: true, numeric: true),
      ContentColumn('carbsG', required: true, numeric: true),
      ContentColumn('fatG', required: true, numeric: true),
      // Where it matters most. Knowing a dish is koshari does not tell the app
      // whether it contains nuts.
      ContentColumn('allergens', required: true, list: true, safetyTag: true),
      ContentColumn('dietTags', required: true, list: true),
    ],
  );

  /// Recipes. The **facts** sheet, and deliberately not the text.
  ///
  /// `bodyAr`, `steps[]`, `ingredients[]` and `components[]` are **not columns
  /// here and must not be added.** A forty-line Egyptian colloquial paragraph
  /// with her own line breaks does not survive a CSV round trip, and
  /// `csv_parser.dart` was not built to try. Her text arrives as a JSON sidecar
  /// keyed by `recipeId` — `assets/content/rahma_recipes.json` in the bundle,
  /// `recipes/{id}` in Firestore — and this sheet carries the facts an importer,
  /// a validator and an exporter can all agree on.
  ///
  /// Said here rather than in a plan, so the next reader does not "fix" it.
  static const ContentSchema _recipes = ContentSchema._(
    collection: ContentCollection.recipes,
    fileName: 'recipes.csv',
    storagePrefix: 'content/recipes',
    columns: [
      ContentColumn('recipeId', required: true),
      ContentColumn('name_en', required: true),
      ContentColumn('name_ar', required: true),
      ContentColumn('minutes', required: true, numeric: true),
      ContentColumn('ingredients', list: true),
      ContentColumn('allergens', required: true, list: true, safetyTag: true),
      ContentColumn('dietTags', required: true, list: true),
      ContentColumn('photoFile', media: true),
      // Where it sits in her book, and who wrote it.
      // Not required: a recipe written here may not have been placed in a
      // section of the book yet, and refusing the row for that would make the
      // console unusable for drafting. What may not publish without a signature
      // is enforced in `firestore.rules`, where a Dart bug cannot reach it.
      ContentColumn('sectionId'),
      ContentColumn('source', required: true),
      ContentColumn('status', required: true),
      ContentColumn('sourcePage', numeric: true),
      // Not required, for the same reason, and with the same gate behind it.
      ContentColumn('authoredBy'),
      // The signature that lets a recipe publish. Optional as a column because
      // a draft row legitimately has none; the *publication* gate is in
      // `firestore.rules`, where a Dart bug cannot reach it.
      ContentColumn('allergenReviewedBy'),
      // Facts a screen renders only when they are present.
      ContentColumn('serves', numeric: true),
      ContentColumn('activeMinutes', numeric: true),
      ContentColumn('kcal', numeric: true),
      ContentColumn('proteinG', numeric: true),
      ContentColumn('carbsG', numeric: true),
      ContentColumn('fatG', numeric: true),
      // `computed` or `withheld`. Required, because "we did not compute this"
      // has to be a value somebody wrote rather than the absence of one.
      ContentColumn('macroBasis', required: true),
      // An undated EGP figure in Egypt is wrong within a quarter, so the price
      // and the month it was priced in travel together.
      ContentColumn('egpPerServing', numeric: true),
      ContentColumn('egpPricedAt'),
      // Not allergens and not filtered on: `pregnancy_liver`, `g6pd_fava`.
      // A safety tag all the same, so the validator holds it to the same
      // vocabulary discipline.
      ContentColumn('advisories', required: true, list: true, safetyTag: true),
      // A token from a fixed set, never a sentence. The Modern Standard copy
      // for each one is in the dictionary.
      ContentColumn('doneness'),
      // A drawn food mark, not a photograph. See `food_marks.dart`.
      ContentColumn('markKey'),
      ContentColumn('tier', required: true),
    ],
  );

  static const ContentSchema _programmes = ContentSchema._(
    collection: ContentCollection.programmes,
    fileName: 'programs.csv',
    storagePrefix: 'content/programs',
    columns: [
      ContentColumn('programId', required: true),
      ContentColumn('name_en', required: true),
      ContentColumn('name_ar', required: true),
      ContentColumn('weeks', required: true, numeric: true),
      ContentColumn('daysPerWeek', required: true, numeric: true),
      ContentColumn('sessionLength', required: true, numeric: true),
      ContentColumn('quiet', required: true, boolean: true),
      ContentColumn('equipment', list: true),
      // No safety column, and that is a decision rather than a gap. A programme
      // is a shape — weeks, days, session length. It holds no ingredient and no
      // movement of its own, so there is nothing for a guard to read off it.
    ],
  );
}
