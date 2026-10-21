/// The starting content library — `DECISIONS.md` **D20**.
///
/// > "**D20 — Seed the library content now; the owner replaces it later.**
/// > Allergens, contraindication tags and the rest are authored as working seed
/// > data so the safety guards have something to read, rather than staying
/// > inert. **This is data, not the founder's voice** — no script, caption or
/// > coaching copy is written on his behalf."
///
/// ## What was actually broken
///
/// `AllergyGuard` is built, correct and fully tested, and it could protect
/// nobody: `foods.allergens[]` was unauthored, so every assessment resolved to
/// "unknown, therefore unsafe" and `P0-EAT-01` could not pass. The same hole ran
/// through `exercises.contraindicationTags`. A guard with no content to read is
/// not a guard; it is a screen that interrupts every woman equally.
///
/// This file is the content. Nothing here is a feature — it is rows.
///
/// ## `none` is an answer; blank is the absence of one
///
/// G16 §3.2: "A mandatory safety column must carry an **explicit** value. `none`
/// is valid and means 'this contains no allergens'. Empty is rejected." So every
/// `allergens` and every `contraindicationTags` cell below carries a value, and
/// the ones that say `none` say it because somebody checked, not because nobody
/// did. `validateImport` refuses the blank; `CollectionStatus.missingASafetyTag`
/// counts it; neither can tell a blank from an oversight, which is the whole
/// reason the blank is refused rather than defaulted.
///
/// ## The vocabularies are borrowed, never invented
///
/// A tag nothing can match is the same as no tag at all — it reads as authored
/// and filters nothing. So each column uses the vocabulary its consumer already
/// speaks:
///
///   * **`allergens`** — `AllergenTag` in `lib/features/account/domain/dietary_profile.dart`
///     is what a woman can actually name: `nuts`, `dairy`, `gluten`,
///     `shellfish`. `AllergyGuard` compares case- and whitespace-insensitively,
///     so these are lowercase single tokens. `sesame` and `egg` are also
///     authored below, truthfully, although **no capture surface can name them
///     yet** — the tag is right and the other half is missing, which is a
///     content fact worth recording rather than a reason to under-tag a dish.
///   * **`contraindicationTags`** — `ContraindicationTag`, G14 §1.5: `high_impact`,
///     `jumping`, `deep_knee_flexion`, `loaded_twisting`, `pelvic_floor_load`,
///     `breath_hold_valsalva`, `prone_position`, `supine_load`, `overhead_load`,
///     `wrist_load`. That plan says the vocabulary "must also exist on the
///     exercise library as `exercises[].contraindicationTags[]`", and
///     `firebase`'s own `isTag()` admits exactly these ten. A move tagged with
///     anything else intersects nothing and is filtered by nothing.
///   * **`equipment`** — `Equipment` in `lib/features/onboarding/domain/intake.dart`:
///     `none`, `mat`, `dumbbells`, `bands`. `selectStartingProgram` compares
///     against her answers using these, so a programme spelled otherwise reads
///     as kit she does not own.
///
/// ## Why `name_ar` is written as escapes
///
/// G16 §3.3: the library "carries its own display text because it is **content
/// from a build-time bundle, not copy from the dictionary**", and none of it
/// passes through the ARB. `test/i18n_guard_test.dart` does not know about
/// content — it fails any Arabic character in a non-comment line anywhere under
/// `lib/`, and its allowlist is capped at three entries.
///
/// So the Arabic here is `\u` escapes, with the readable name on the comment
/// line above every row. The runtime string is ordinary Arabic; only the source
/// spelling changes. **This is a workaround, not the right end state** — the
/// right one is a fourth allowlist entry in that guard, which is a shared file
/// this work was not permitted to edit. The exact change is in the handover
/// note. Once it is applied, every escape below can become the plain Arabic in
/// the comment above it.
///
/// ## Media is named nowhere, deliberately
///
/// `videoFile`, `thumbFile` and `photoFile` are blank on every row. §3.4 refuses
/// a row naming a file the upload does not contain — "a validation failure, not
/// a broken link discovered later by a woman mid-workout" — and no media has
/// been shot. The columns are optional precisely so a library can be imported
/// before its filming is finished, so blank here is the honest value and the
/// only importable one.
///
/// ## What these numbers are worth
///
/// Macros are per the portion named in `portions`, and the composite Egyptian
/// dishes are estimates from published recipe aggregates rather than a
/// laboratory assay — the range is cited per row where it matters. The
/// **allergens** are the part authored to be relied on: a wrong allergen is
/// worse than an empty library, because the guard then clears a dish it should
/// block. Where a dish is commonly cooked two ways, the seed tags the riskier
/// one and says so.
library;

import 'content_schema.dart';
import 'csv_parser.dart';
import 'import_validator.dart';

// ---------------------------------------------------------------- public API

/// Every seeded row, across all four collections.
///
/// Shaped for `InMemoryContentRepository(rows: seedContentLibrary())`. Seeding
/// through the constructor is deliberately **not** recorded as a write: it is
/// the library's starting state, not something staff did.
List<ImportRow> seedContentLibrary() => [
  for (final collection in ContentCollection.values) ...seedRowsFor(collection),
];

/// The seeded rows of one collection, in a stable order.
///
/// `isUpdate` is false on every row: the id **is** the document id, so re-seeding
/// addresses the same documents and replaces them. Nothing here is duplicated by
/// running it twice, because `ContentStore` keys by id and a second write to the
/// same id replaces rather than appends.
List<ImportRow> seedRowsFor(ContentCollection collection) {
  final schema = ContentSchema.of(collection);
  return [
    for (final values in _valuesFor(collection))
      ImportRow(
        collection: collection,
        id: values[schema.idColumn]!,
        isUpdate: false,
        values: values,
      ),
  ];
}

/// The same rows rendered as the CSV an admin could re-import unchanged.
///
/// This is not a convenience. G16 §5 promises an export "can be edited and
/// re-imported", and running the seed back through `parseCsv` + `validateImport`
/// is how the tests prove every row below satisfies the **real** importer rather
/// than a second opinion written beside it.
String seedCsvFor(ContentCollection collection) {
  final schema = ContentSchema.of(collection);
  final buffer = StringBuffer()
    ..writeln(
      [for (final name in schema.columnNames) csvField(name)].join(','),
    );

  for (final values in _valuesFor(collection)) {
    buffer.writeln(
      [for (final name in schema.columnNames) csvField(values[name] ?? '')]
          .join(','),
    );
  }
  return buffer.toString();
}

List<Map<String, String>> _valuesFor(ContentCollection collection) =>
    switch (collection) {
      ContentCollection.foods => _foods(),
      ContentCollection.exercises => _exercises(),
      ContentCollection.recipes => _recipes(),
      ContentCollection.programmes => _programmes(),
    };

// ----------------------------------------------------------------- builders
//
// Named parameters throughout, so a call site cannot silently swap protein for
// carbohydrate, and every safety column is `required` — the compiler refuses a
// row that forgot to answer.

Map<String, String> _food({
  required String id,
  required String nameEn,
  required String nameAr,
  required String portions,
  required int kcal,
  required int proteinG,
  required int carbsG,
  required int fatG,
  required String allergens,
  required String dietTags,
}) => {
  'foodId': id,
  'name_en': nameEn,
  'name_ar': nameAr,
  'portions': portions,
  'kcal': '$kcal',
  'proteinG': '$proteinG',
  'carbsG': '$carbsG',
  'fatG': '$fatG',
  'allergens': allergens,
  'dietTags': dietTags,
};

Map<String, String> _exercise({
  required String id,
  required String nameEn,
  required String nameAr,
  required String equipment,
  required String pattern,
  required String contraindicationTags,
  required bool quiet,
  required bool floorOnly,
}) => {
  'exerciseId': id,
  'name_en': nameEn,
  'name_ar': nameAr,
  'equipment': equipment,
  'pattern': pattern,
  'contraindicationTags': contraindicationTags,
  'quiet': '$quiet',
  'floorOnly': '$floorOnly',
  // See the file note: no media has been shot, and a row naming a file that was
  // never uploaded is refused by the importer.
  'videoFile': '',
  'thumbFile': '',
  // The exercise library's columns (D42), blank: the seed predates it, and the
  // owner's filmed moves arrive through publish_exercise_library.py.
  'angleVideoFile': '',
  'primaryMuscles': '',
  'secondaryMuscles': '',
  'bodyRegion': '',
  'place': '',
  'level': '',
  'kind': '',
};

/// One seeded recipe row.
///
/// The columns below the first eight arrived with Rahma's recipe book, and the
/// values they get here are the honest ones rather than the convenient ones:
///
///  * `status: review` and `allergenReviewedBy: ''` on every row, because no
///    second person has signed any of these allergen sets. The Firestore rule
///    refuses a write without a reviewer who is not the author, so these rows
///    are exactly as far as a seed can take them.
///  * `macroBasis: withheld` and four empty macro fields. Summing them needs a
///    `foods` row with verified per-100 g values and a gram figure per
///    ingredient, and neither exists. A computed-looking number over an
///    uncomputed base is a fabricated figure driving a woman's eating.
///  * `tier: free`, because nothing is sold.
Map<String, String> _recipe({
  required String id,
  required String nameEn,
  required String nameAr,
  required int minutes,
  required String ingredients,
  required String allergens,
  required String dietTags,
  String advisories = 'none',
  String doneness = '',
  String markKey = 'pot',
  String sectionId = 'lunchy_junky_yum',
}) => {
  'recipeId': id,
  'name_en': nameEn,
  'name_ar': nameAr,
  'minutes': '$minutes',
  'ingredients': ingredients,
  'allergens': allergens,
  'dietTags': dietTags,
  'photoFile': '',
  'sectionId': sectionId,
  // Written for the library rather than taken from her book. Her thirty-nine
  // are `source: book` and live in `assets/content/rahma_recipes.json`, because
  // a forty-line colloquial paragraph does not survive a CSV round trip.
  'source': 'authored',
  // A draft: these sample rows have no method, and a recipe without one
  // cannot reach a member. Written in Z12 with a method, it can be shown.
  'status': 'draft',
  'sourcePage': '',
  'authoredBy': 'content_team',
  'allergenReviewedBy': '',
  'serves': '',
  'activeMinutes': '$minutes',
  'kcal': '',
  'proteinG': '',
  'carbsG': '',
  'fatG': '',
  'macroBasis': 'withheld',
  'egpPerServing': '',
  'egpPricedAt': '',
  'advisories': advisories,
  'doneness': doneness,
  'markKey': markKey,
  'tier': 'free',
  'method_ar': '',
  'method_en': '',
};

Map<String, String> _programme({
  required String id,
  required String nameEn,
  required String nameAr,
  required int weeks,
  required int daysPerWeek,
  required int sessionLength,
  required bool quiet,
  required String equipment,
}) => {
  'programId': id,
  'name_en': nameEn,
  'name_ar': nameAr,
  'weeks': '$weeks',
  'daysPerWeek': '$daysPerWeek',
  'sessionLength': '$sessionLength',
  'quiet': '$quiet',
  'equipment': equipment,
};

// -------------------------------------------------------------------- foods
//
// Twenty dishes an Egyptian woman actually eats. Every `allergens` cell is
// explicit; `none` means the dish was checked and contains none of the tagged
// classes, not that nobody looked.
//
// Two cooking facts drive most of the tags here, and both are worth stating
// once rather than twenty times:
//
//   * **Samna (ghee) is dairy.** It is a milk product, it is what the ta'leya
//     of molokhia and the garlic sauce of fattah are fried in, and allergen
//     labelling treats milk-derived fat as milk. Trace protein in clarified
//     butter is low and a woman with a dairy allergy is still the person who
//     gets to decide, so these dishes are tagged `dairy` rather than cleared.
//     Tagging in the safe direction costs her a suggestion; clearing in the
//     wrong one costs more.
//   * **Ta'ameya is coated in sesame.** The patties are pressed into sesame
//     seeds before frying, and tahina is the usual accompaniment.
//
// Where a dish is also in the bundled food pack (`assets/content/foods_eg.json`),
// its tags here are at least the pack's, which are derived from the standard
// ingredients and over-inclusive: fava for ful and ta'ameya, celery for dishes
// cooked in stock, coconut and sulphites in om ali.
//
// Every row is a food of the bundled pack, under the pack's id, with the pack's
// medium portion and its labels. The pack's figures are computed from USDA
// FoodData Central by `tool/build_food_pack.py` and are estimates pending
// dietitian review, not clinical figures. A test holds the two in step.

List<Map<String, String>> _foods() => [
  // كشري
  // Rice, brown lentils, macaroni, chickpeas, fried onion, tomato sauce.
  // GLUTEN from the macaroni — the point G16's own README makes: "knowing a
  // dish is koshari does not tell the app whether it contains nuts".
  _food(
    id: 'koshary',
    nameEn: 'Koshary',
    nameAr: '\u0643\u0634\u0631\u064A',
    portions: 'Medium plate|Small plate',
    kcal: 588,
    proteinG: 19,
    carbsG: 91,
    fatG: 17,
    allergens: 'gluten',
    dietTags: 'vegetarian|vegan',
  ),

  // فول مدمس
  // Slow-cooked fava beans with oil, cumin and lemon. No gluten, no dairy. FAVA
  // is tagged: favism (G6PD deficiency) is why the token exists.
  _food(
    id: 'ful_medames',
    nameEn: 'Ful medames',
    nameAr: '\u0641\u0648\u0644 \u0645\u062F\u0645\u0633',
    portions: 'Medium bowl|Small bowl',
    kcal: 269,
    proteinG: 15,
    carbsG: 40,
    fatG: 6,
    allergens: 'fava',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // طعمية
  // Egyptian falafel: split fava beans, not chickpeas, with parsley, coriander
  // and dill. SESAME — the patties are coated in sesame seeds before frying.
  // FAVA for favism, and GLUTEN because many shops bind the batter with bread or
  // flour.
  _food(
    id: 'taameya',
    nameEn: 'Taameya (Egyptian falafel)',
    nameAr: '\u0637\u0639\u0645\u064A\u0629',
    portions: '4 pieces|2 pieces',
    kcal: 263,
    proteinG: 9,
    carbsG: 21,
    fatG: 17,
    allergens: 'fava|gluten|sesame',
    dietTags: 'vegetarian|vegan',
  ),

  // ملوخية
  // Jute leaves in broth, finished with ta'leya — garlic and coriander fried in
  // samna. DAIRY for the samna. Not tagged vegetarian: the broth is chicken or
  // rabbit in almost every Egyptian kitchen.
  _food(
    id: 'molokhia',
    nameEn: 'Molokhia',
    nameAr: '\u0645\u0644\u0648\u062E\u064A\u0629',
    portions: 'Medium bowl|Small bowl',
    kcal: 138,
    proteinG: 6,
    carbsG: 14,
    fatG: 8,
    allergens: 'celery|dairy',
    dietTags: 'none',
  ),

  // محشي كوسة
  // Courgettes cored and stuffed with rice, parsley, dill and coriander, stewed
  // in tomato. The Egyptian version is meatless, which is why it tags vegan.
  _food(
    id: 'mahshi_zucchini',
    nameEn: 'Stuffed zucchini (kousa)',
    nameAr: '\u0645\u062D\u0634\u064A \u0643\u0648\u0633\u0629',
    portions: 'Medium plate|Small plate',
    kcal: 224,
    proteinG: 4,
    carbsG: 29,
    fatG: 11,
    allergens: 'none',
    dietTags: 'vegetarian|vegan',
  ),

  // محشي كرنب
  // Same stuffing, cabbage leaves.
  _food(
    id: 'mahshi_cabbage',
    nameEn: 'Stuffed cabbage',
    nameAr: '\u0645\u062D\u0634\u064A \u0643\u0631\u0646\u0628',
    portions: 'Medium plate|Small plate',
    kcal: 259,
    proteinG: 4,
    carbsG: 37,
    fatG: 10,
    allergens: 'none',
    dietTags: 'vegetarian|vegan',
  ),

  // أم علي
  // Three allergen classes at once, and the reason a dish name tells you
  // nothing: puff pastry (GLUTEN), milk and cream (DAIRY), almonds and
  // pistachios (NUTS). Raisins and coconut are usual too.
  _food(
    id: 'om_ali',
    nameEn: 'Om Ali',
    nameAr: '\u0623\u0645 \u0639\u0644\u064A',
    portions: 'Medium bowl|Small bowl',
    kcal: 611,
    proteinG: 12,
    carbsG: 56,
    fatG: 39,
    allergens: 'coconut|dairy|gluten|nuts|sulphites',
    dietTags: 'vegetarian',
  ),

  // فتة
  // Layers of toasted baladi bread (GLUTEN), rice, meat and broth, with garlic
  // fried in samna and splashed with vinegar (DAIRY). Meat, so no diet tag.
  _food(
    id: 'fattah',
    nameEn: 'Fattah with meat',
    nameAr: '\u0641\u062A\u0629 \u0628\u0627\u0644\u0644\u062D\u0645\u0629',
    portions: 'Medium plate|Small plate',
    kcal: 778,
    proteinG: 34,
    carbsG: 74,
    fatG: 37,
    allergens: 'celery|dairy|gluten',
    dietTags: 'none',
  ),

  // عيش بلدي
  // Wholemeal wheat. GLUTEN, unambiguously.
  _food(
    id: 'aish_baladi',
    nameEn: 'Aish baladi (Egyptian bread)',
    nameAr: '\u0639\u064A\u0634 \u0628\u0644\u062F\u064A',
    portions: '1 loaf|Half a loaf',
    kcal: 236,
    proteinG: 9,
    carbsG: 50,
    fatG: 2,
    allergens: 'gluten',
    dietTags: 'vegetarian|vegan',
  ),

  // أرز باللبن
  // Rice simmered in milk. DAIRY. Nuts are a common garnish but are not in the
  // dish itself, so they are not tagged here — the garnished version belongs in
  // its own row rather than being tagged onto this one.
  _food(
    id: 'roz_bel_laban',
    nameEn: 'Rice pudding',
    nameAr: '\u0631\u0632 \u0628\u0644\u0628\u0646',
    portions: 'Medium bowl|Small bowl',
    kcal: 290,
    proteinG: 7,
    carbsG: 51,
    fatG: 6,
    allergens: 'dairy',
    dietTags: 'vegetarian|gluten_free',
  ),

  // شكشوكة
  // Eggs poached in tomato and onion. EGG.
  _food(
    id: 'shakshuka',
    nameEn: 'Shakshuka',
    nameAr: '\u0634\u0643\u0634\u0648\u0643\u0629',
    portions: 'Medium plate|Small plate',
    kcal: 295,
    proteinG: 16,
    carbsG: 12,
    fatG: 21,
    allergens: 'egg',
    dietTags: 'vegetarian|gluten_free',
  ),

  // صدر فراخ مشوي
  _food(
    id: 'chicken_breast_grilled',
    nameEn: 'Grilled chicken breast',
    nameAr:
        '\u0635\u062F\u0631 \u0641\u0631\u0627\u062E \u0645\u0634\u0648\u064A',
    portions: '1 breast|Half a breast',
    kcal: 284,
    proteinG: 53,
    carbsG: 0,
    fatG: 6,
    allergens: 'none',
    dietTags: 'high_protein|gluten_free',
  ),

  // شوربة عدس
  // Red lentils, onion, carrot, cumin. Served with bread, but the soup itself
  // carries no gluten — the bread is its own row, which is what lets a woman
  // avoiding gluten still be offered the soup.
  _food(
    id: 'shorbet_ads',
    nameEn: 'Lentil soup',
    nameAr: '\u0634\u0648\u0631\u0628\u0629 \u0639\u062F\u0633',
    portions: 'Medium bowl|Small bowl',
    kcal: 298,
    proteinG: 15,
    carbsG: 42,
    fatG: 9,
    allergens: 'celery',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // بيض مسلوق
  // EGG.
  _food(
    id: 'eggs_boiled',
    nameEn: 'Boiled eggs',
    nameAr: '\u0628\u064A\u0636 \u0645\u0633\u0644\u0648\u0642',
    portions: '2 eggs|1 egg',
    kcal: 155,
    proteinG: 13,
    carbsG: 1,
    fatG: 11,
    allergens: 'egg',
    dietTags: 'vegetarian|gluten_free',
  ),

  // زبادي
  // Plain. DAIRY.
  _food(
    id: 'yoghurt_baladi',
    nameEn: 'Plain baladi yoghurt',
    nameAr: '\u0632\u0628\u0627\u062F\u064A \u0628\u0644\u062F\u064A',
    portions: '1 tub|Half a tub',
    kcal: 138,
    proteinG: 8,
    carbsG: 11,
    fatG: 7,
    allergens: 'dairy',
    dietTags: 'vegetarian|gluten_free',
  ),

  // تمر
  // Dried dates.
  _food(
    id: 'dates',
    nameEn: 'Dates',
    nameAr: '\u062A\u0645\u0631 \u0645\u062C\u0641\u0641',
    portions: '3 dates|2 dates',
    kcal: 59,
    proteinG: 1,
    carbsG: 16,
    fatG: 0,
    allergens: 'none',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // طحينة
  // Tahina is ground sesame. SESAME.
  _food(
    id: 'tahina',
    nameEn: 'Tahini sauce',
    nameAr: '\u0637\u062D\u064A\u0646\u0629',
    portions: '4 tablespoons|2 tablespoons',
    kcal: 187,
    proteinG: 5,
    carbsG: 8,
    fatG: 16,
    allergens: 'sesame',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // أرز أبيض
  // The pack cooks it with butter, so DAIRY, and not vegan.
  _food(
    id: 'roz_abyad',
    nameEn: 'Plain white rice',
    nameAr: '\u0631\u0632 \u0623\u0628\u064A\u0636',
    portions: 'Medium plate|Small plate',
    kcal: 256,
    proteinG: 5,
    carbsG: 51,
    fatG: 3,
    allergens: 'dairy',
    dietTags: 'vegetarian|gluten_free',
  ),

  // سلطة بلدي
  _food(
    id: 'salata_baladi',
    nameEn: 'Egyptian salad',
    nameAr: '\u0633\u0644\u0637\u0629 \u0628\u0644\u062F\u064A',
    portions: 'Medium bowl|Small bowl',
    kcal: 82,
    proteinG: 2,
    carbsG: 9,
    fatG: 5,
    allergens: 'none',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // فطير مشلتت
  // Layered pastry built on wheat flour (GLUTEN) and samna (DAIRY).
  _food(
    id: 'feteer',
    nameEn: 'Feteer meshaltet',
    nameAr: '\u0641\u0637\u064A\u0631 \u0645\u0634\u0644\u062A\u062A',
    portions: '1 piece|Small piece',
    kcal: 518,
    proteinG: 7,
    carbsG: 53,
    fatG: 31,
    allergens: 'dairy|egg|gluten',
    dietTags: 'vegetarian',
  ),
];

// ---------------------------------------------------------------- exercises
//
// The patterns a home or ladies-gym programme is built from, tagged in the G14
// §1.5 vocabulary so `ExerciseCandidateFilter` can intersect them against her
// avoid list and a `refer` outcome.
//
// `quiet` and `floorOnly` are answered truthfully rather than optimistically.
// `quiet` decides whether a move is offered to a woman training in a flat with
// neighbours below, so anything that leaves the floor is `false`; `floorOnly` is
// true only for a move performed lying or kneeling on a mat.
//
// Where a tag looks absent, it is absent on purpose: `none` means the move loads
// nothing on the list, not that it is risk-free for everyone.

List<Map<String, String>> _exercises() => [
  // قرفصاء بالدمبل
  _exercise(
    id: 'goblet_squat',
    nameEn: 'Goblet squat',
    nameAr: '\u0642\u0631\u0641\u0635\u0627\u0621 \u0628\u0627\u0644\u062F\u0645\u0628\u0644',
    equipment: 'dumbbells',
    pattern: 'squat',
    contraindicationTags: 'deep_knee_flexion',
    quiet: true,
    floorOnly: false,
  ),

  // قرفصاء بوزن الجسم
  _exercise(
    id: 'bodyweight_squat',
    nameEn: 'Bodyweight squat',
    nameAr: '\u0642\u0631\u0641\u0635\u0627\u0621 \u0628\u0648\u0632\u0646 \u0627\u0644\u062C\u0633\u0645',
    equipment: 'none',
    pattern: 'squat',
    contraindicationTags: 'deep_knee_flexion',
    quiet: true,
    floorOnly: false,
  ),

  // دفع الحوض
  // Loaded across the hips and braced — intra-abdominal pressure is the reason
  // this is restricted after birth, not the hip extension itself.
  _exercise(
    id: 'hip_thrust',
    nameEn: 'Hip thrust',
    nameAr: '\u062F\u0641\u0639 \u0627\u0644\u062D\u0648\u0636',
    equipment: 'dumbbells',
    pattern: 'hinge',
    contraindicationTags: 'supine_load|pelvic_floor_load',
    quiet: true,
    floorOnly: false,
  ),

  // جسر المقعدة
  // Unloaded, lying on the back.
  _exercise(
    id: 'glute_bridge',
    nameEn: 'Glute bridge',
    nameAr: '\u062C\u0633\u0631 \u0627\u0644\u0645\u0642\u0639\u062F\u0629',
    equipment: 'mat',
    pattern: 'hinge',
    contraindicationTags: 'supine_load',
    quiet: true,
    floorOnly: true,
  ),

  // بلانك
  // Hands on the floor and face down: wrist and prone both apply.
  _exercise(
    id: 'plank',
    nameEn: 'Plank',
    nameAr: '\u0628\u0644\u0627\u0646\u0643',
    equipment: 'mat',
    pattern: 'core',
    contraindicationTags: 'wrist_load|prone_position',
    quiet: true,
    floorOnly: true,
  ),

  // بلانك على الساعدين
  // The same shape on the forearms, which is why it is a separate row: it drops
  // `wrist_load` and is the substitution a wrist referral needs to leave
  // available.
  _exercise(
    id: 'forearm_plank',
    nameEn: 'Forearm plank',
    nameAr: '\u0628\u0644\u0627\u0646\u0643 \u0639\u0644\u0649 \u0627\u0644\u0633\u0627\u0639\u062F\u064A\u0646',
    equipment: 'mat',
    pattern: 'core',
    contraindicationTags: 'prone_position',
    quiet: true,
    floorOnly: true,
  ),

  // بلانك جانبي
  _exercise(
    id: 'side_plank',
    nameEn: 'Side plank',
    nameAr: '\u0628\u0644\u0627\u0646\u0643 \u062C\u0627\u0646\u0628\u064A',
    equipment: 'mat',
    pattern: 'core',
    contraindicationTags: 'wrist_load',
    quiet: true,
    floorOnly: true,
  ),

  // الحشرة الميتة
  _exercise(
    id: 'dead_bug',
    nameEn: 'Dead bug',
    nameAr: '\u0627\u0644\u062D\u0634\u0631\u0629 \u0627\u0644\u0645\u064A\u062A\u0629',
    equipment: 'mat',
    pattern: 'core',
    contraindicationTags: 'supine_load',
    quiet: true,
    floorOnly: true,
  ),

  // الطائر والكلب
  _exercise(
    id: 'bird_dog',
    nameEn: 'Bird dog',
    nameAr: '\u0627\u0644\u0637\u0627\u0626\u0631 \u0648\u0627\u0644\u0643\u0644\u0628',
    equipment: 'mat',
    pattern: 'core',
    contraindicationTags: 'wrist_load',
    quiet: true,
    floorOnly: true,
  ),

  // تجديف بالانحناء
  // Held in a hinge under load. The §1.5 vocabulary has no lumbar-flexion tag,
  // so there is nothing truthful to put here — see the handover note.
  _exercise(
    id: 'bent_over_row',
    nameEn: 'Bent-over row',
    nameAr: '\u062A\u062C\u062F\u064A\u0641 \u0628\u0627\u0644\u0627\u0646\u062D\u0646\u0627\u0621',
    equipment: 'dumbbells',
    pattern: 'pull',
    contraindicationTags: 'none',
    quiet: true,
    floorOnly: false,
  ),

  // تجديف بالمطاط
  // Seated on the floor, no load on the spine.
  _exercise(
    id: 'seated_band_row',
    nameEn: 'Seated band row',
    nameAr: '\u062A\u062C\u062F\u064A\u0641 \u0628\u0627\u0644\u0645\u0637\u0627\u0637',
    equipment: 'bands',
    pattern: 'pull',
    contraindicationTags: 'none',
    quiet: true,
    floorOnly: true,
  ),

  // ضغط الكتف
  _exercise(
    id: 'shoulder_press',
    nameEn: 'Shoulder press',
    nameAr: '\u0636\u063A\u0637 \u0627\u0644\u0643\u062A\u0641',
    equipment: 'dumbbells',
    pattern: 'push',
    contraindicationTags: 'overhead_load',
    quiet: true,
    floorOnly: false,
  ),

  // ضغط على الحائط
  // Standing, hands on a wall — the gentlest press there is, and still wrist.
  _exercise(
    id: 'wall_press_up',
    nameEn: 'Wall press-up',
    nameAr: '\u0636\u063A\u0637 \u0639\u0644\u0649 \u0627\u0644\u062D\u0627\u0626\u0637',
    equipment: 'none',
    pattern: 'push',
    contraindicationTags: 'wrist_load',
    quiet: true,
    floorOnly: false,
  ),

  // ضغط على الركبتين
  _exercise(
    id: 'knee_press_up',
    nameEn: 'Knee press-up',
    nameAr: '\u0636\u063A\u0637 \u0639\u0644\u0649 \u0627\u0644\u0631\u0643\u0628\u062A\u064A\u0646',
    equipment: 'mat',
    pattern: 'push',
    contraindicationTags: 'wrist_load|prone_position|deep_knee_flexion',
    quiet: true,
    floorOnly: true,
  ),

  // الرفعة الرومانية
  // A loaded hinge. Women brace against it, which is what raises intra-abdominal
  // pressure — the reason both tags are here rather than neither.
  _exercise(
    id: 'romanian_deadlift',
    nameEn: 'Romanian deadlift',
    nameAr: '\u0627\u0644\u0631\u0641\u0639\u0629 \u0627\u0644\u0631\u0648\u0645\u0627\u0646\u064A\u0629',
    equipment: 'dumbbells',
    pattern: 'hinge',
    contraindicationTags: 'pelvic_floor_load|breath_hold_valsalva',
    quiet: true,
    floorOnly: false,
  ),

  // اندفاع أمامي
  _exercise(
    id: 'forward_lunge',
    nameEn: 'Forward lunge',
    nameAr:
        '\u0627\u0646\u062F\u0641\u0627\u0639 \u0623\u0645\u0627\u0645\u064A',
    equipment: 'none',
    pattern: 'lunge',
    contraindicationTags: 'deep_knee_flexion',
    quiet: true,
    floorOnly: false,
  ),

  // اندفاع خلفي
  _exercise(
    id: 'reverse_lunge',
    nameEn: 'Reverse lunge',
    nameAr: '\u0627\u0646\u062F\u0641\u0627\u0639 \u062E\u0644\u0641\u064A',
    equipment: 'none',
    pattern: 'lunge',
    contraindicationTags: 'deep_knee_flexion',
    quiet: true,
    floorOnly: false,
  ),

  // صعود على درجة
  _exercise(
    id: 'step_up',
    nameEn: 'Step-up',
    nameAr:
        '\u0635\u0639\u0648\u062F \u0639\u0644\u0649 \u062F\u0631\u062C\u0629',
    equipment: 'none',
    pattern: 'lunge',
    contraindicationTags: 'deep_knee_flexion',
    quiet: true,
    floorOnly: false,
  ),

  // رفع السمانة
  _exercise(
    id: 'calf_raise',
    nameEn: 'Calf raise',
    nameAr: '\u0631\u0641\u0639 \u0627\u0644\u0633\u0645\u0627\u0646\u0629',
    equipment: 'none',
    pattern: 'calf',
    contraindicationTags: 'none',
    quiet: true,
    floorOnly: false,
  ),

  // حمل الحقيبة
  _exercise(
    id: 'suitcase_carry',
    nameEn: 'Suitcase carry',
    nameAr: '\u062D\u0645\u0644 \u0627\u0644\u062D\u0642\u064A\u0628\u0629',
    equipment: 'dumbbells',
    pattern: 'carry',
    contraindicationTags: 'none',
    quiet: true,
    floorOnly: false,
  ),

  // تمرين الدراجة
  _exercise(
    id: 'bicycle_crunch',
    nameEn: 'Bicycle crunch',
    nameAr: '\u062A\u0645\u0631\u064A\u0646 \u0627\u0644\u062F\u0631\u0627\u062C\u0629',
    equipment: 'mat',
    pattern: 'core',
    contraindicationTags: 'supine_load|loaded_twisting',
    quiet: true,
    floorOnly: true,
  ),

  // قفز مع فتح الذراعين
  // `quiet: false`. The neighbours downstairs hear this, and a library that
  // called everything quiet would make the quiet filter meaningless.
  _exercise(
    id: 'jumping_jack',
    nameEn: 'Jumping jack',
    nameAr: '\u0642\u0641\u0632 \u0645\u0639 \u0641\u062A\u062D \u0627\u0644\u0630\u0631\u0627\u0639\u064A\u0646',
    equipment: 'none',
    pattern: 'jump',
    contraindicationTags: 'high_impact|jumping|pelvic_floor_load',
    quiet: false,
    floorOnly: false,
  ),

  // قفز القرفصاء
  _exercise(
    id: 'squat_jump',
    nameEn: 'Squat jump',
    nameAr:
        '\u0642\u0641\u0632 \u0627\u0644\u0642\u0631\u0641\u0635\u0627\u0621',
    equipment: 'none',
    pattern: 'jump',
    contraindicationTags:
        'high_impact|jumping|pelvic_floor_load|deep_knee_flexion',
    quiet: false,
    floorOnly: false,
  ),
];

// ------------------------------------------------------------------ recipes
//
// Ingredient lists, times and allergens. No method, no encouragement and no
// commentary — D20 is explicit that this is data and not the founder's voice.

List<Map<String, String>> _recipes() => [
  // شوربة عدس
  _recipe(
    id: 'lentil_soup',
    nameEn: 'Lentil soup',
    nameAr: '\u0634\u0648\u0631\u0628\u0629 \u0639\u062F\u0633',
    minutes: 25,
    ingredients: 'red lentils|onion|carrot|cumin|lemon',
    allergens: 'celery',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // فول بالزيت والكمون
  _recipe(
    id: 'ful_with_oil_and_cumin',
    nameEn: 'Ful with oil and cumin',
    nameAr: '\u0641\u0648\u0644 \u0628\u0627\u0644\u0632\u064A\u062A \u0648\u0627\u0644\u0643\u0645\u0648\u0646',
    minutes: 15,
    ingredients: 'fava beans|olive oil|cumin|lemon|salt',
    allergens: 'fava',
    dietTags: 'vegetarian|vegan|gluten_free',
  ),

  // كشري بيتي
  _recipe(
    id: 'koshari_home',
    nameEn: 'Home koshari',
    nameAr: '\u0643\u0634\u0631\u064A \u0628\u064A\u062A\u064A',
    minutes: 60,
    ingredients:
        'rice|brown lentils|macaroni|chickpeas|onion|tomato|vinegar|cumin',
    allergens: 'gluten',
    dietTags: 'vegetarian|vegan',
  ),

  // طعمية بيتي
  _recipe(
    id: 'taameya_home',
    nameEn: "Home ta'ameya",
    nameAr: '\u0637\u0639\u0645\u064A\u0629 \u0628\u064A\u062A\u064A',
    minutes: 40,
    ingredients:
        'split fava beans|parsley|coriander|dill|onion|garlic|sesame seeds',
    allergens: 'fava|gluten|sesame',
    dietTags: 'vegetarian|vegan',
  ),

  // ملوخية بالدجاج
  _recipe(
    id: 'molokhia_with_chicken',
    nameEn: 'Molokhia with chicken',
    nameAr: '\u0645\u0644\u0648\u062E\u064A\u0629 \u0628\u0627\u0644\u062F\u062C\u0627\u062C',
    minutes: 50,
    ingredients: 'molokhia leaves|chicken|garlic|ground coriander|ghee',
    allergens: 'dairy|celery',
    dietTags: 'none',
  ),

  // محشي كوسة
  _recipe(
    id: 'mahshi_koussa',
    nameEn: 'Mahshi koussa',
    nameAr: '\u0645\u062D\u0634\u064A \u0643\u0648\u0633\u0629',
    minutes: 75,
    ingredients: 'courgette|rice|parsley|dill|coriander|onion|tomato',
    allergens: 'none',
    dietTags: 'vegetarian|vegan',
  ),

  // شكشوكة
  _recipe(
    id: 'shakshuka',
    nameEn: 'Shakshuka',
    nameAr: '\u0634\u0643\u0634\u0648\u0643\u0629',
    minutes: 20,
    ingredients: 'eggs|tomato|onion|green pepper|cumin',
    allergens: 'egg',
    dietTags: 'vegetarian|gluten_free',
  ),

  // أرز باللبن
  _recipe(
    id: 'roz_bel_laban',
    nameEn: 'Roz bel laban',
    nameAr: '\u0623\u0631\u0632 \u0628\u0627\u0644\u0644\u0628\u0646',
    minutes: 45,
    ingredients: 'rice|milk|sugar|vanilla|cinnamon',
    allergens: 'dairy',
    dietTags: 'vegetarian|gluten_free',
  ),

  // أم علي
  _recipe(
    id: 'om_ali',
    nameEn: 'Om Ali',
    nameAr: '\u0623\u0645 \u0639\u0644\u064A',
    minutes: 40,
    ingredients:
        'puff pastry|milk|cream|sugar|almonds|pistachios|raisins|coconut',
    allergens: 'dairy|gluten|nuts|coconut|sulphites',
    dietTags: 'vegetarian',
  ),
];

// --------------------------------------------------------------- programmes
//
// A programme is a shape — weeks, days, session length — and carries no safety
// column, because it holds no ingredient and no movement of its own.
//
// `beginner_foundations` deliberately repeats the one programme already authored
// in `lib/features/onboarding/domain/starting_program.dart`, field for field. It
// is the programme O05 offers, and a library that disagreed with it would put two
// different answers behind one id.

List<Map<String, String>> _programmes() => [
  // أساسيات المبتدئة
  _programme(
    id: 'beginner_foundations',
    nameEn: 'Beginner foundations',
    nameAr: '\u0623\u0633\u0627\u0633\u064A\u0627\u062A \u0627\u0644\u0645\u0628\u062A\u062F\u0626\u0629',
    weeks: 8,
    daysPerWeek: 3,
    sessionLength: 15,
    quiet: true,
    equipment: 'none',
  ),

  // إعادة البناء بعد الولادة
  // The shape only. What such a programme may actually contain has no signed-off
  // clinical source (G2 §9 Q5), and nothing here decides that.
  _programme(
    id: 'postpartum_rebuild',
    nameEn: 'Postpartum rebuild',
    nameAr: '\u0625\u0639\u0627\u062F\u0629 \u0627\u0644\u0628\u0646\u0627\u0621 \u0628\u0639\u062F \u0627\u0644\u0648\u0644\u0627\u062F\u0629',
    weeks: 12,
    daysPerWeek: 3,
    sessionLength: 20,
    quiet: true,
    equipment: 'mat',
  ),

  // قوة هادئة في البيت
  _programme(
    id: 'quiet_home_strength',
    nameEn: 'Quiet home strength',
    nameAr: '\u0642\u0648\u0629 \u0647\u0627\u062F\u0626\u0629 \u0641\u064A \u0627\u0644\u0628\u064A\u062A',
    weeks: 8,
    daysPerWeek: 4,
    sessionLength: 25,
    quiet: true,
    equipment: 'dumbbells|mat',
  ),

  // أساسيات القوة في الجيم
  // `quiet: false` — a gym programme has no reason to claim it.
  _programme(
    id: 'gym_strength_basics',
    nameEn: 'Gym strength basics',
    nameAr: '\u0623\u0633\u0627\u0633\u064A\u0627\u062A \u0627\u0644\u0642\u0648\u0629 \u0641\u064A \u0627\u0644\u062C\u064A\u0645',
    weeks: 10,
    daysPerWeek: 4,
    sessionLength: 45,
    quiet: false,
    equipment: 'dumbbells',
  ),
];
