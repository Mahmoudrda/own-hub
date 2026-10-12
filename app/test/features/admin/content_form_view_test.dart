// Z03 and Z05 — adding or editing one row.
//
// D12 asked for meals and workouts to be addable "from within the app". Bulk
// import is the half that scales; this is the half that lets one food be added
// without editing a CSV and re-importing the library.
//
// ## What these tests are actually about
//
// One rule, twice: **blank is not "none"**. G16 §3.2 — "A mandatory safety
// column must carry an explicit value. `none` is valid and means 'this contains
// no allergens'. Empty is rejected."
//
// Z03's design note says why it is enforced at the point of authorship and not
// only at import: "the guard cannot tell an untagged row from a safe one, so the
// importer refuses to create the ambiguity rather than accepting it quietly."
// A form that let staff save a blank `allergens` would be a supported way to
// create exactly the row the importer exists to reject.
//
// So both directions are asserted, for both screens: blank is refused, and
// "none" is accepted and arrives as ordinary content.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/presentation/content_form_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_field.dart';
import 'package:own_hub/ui/app_toggle.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

/// Types [value] into the field labelled [label].
///
/// Found by the label rather than by index, because an index would silently
/// move the moment a column is added to the schema — which is the one thing
/// this screen is built to survive.
///
/// `AppField` draws its label as a *sibling* of the `TextField` inside the box,
/// not as an ancestor of it, so the field is located through the `AppField`
/// widget's own `label` property and the `TextField` is taken from inside it.
Finder _field(String label) => find.descendant(
  of: find.byWidgetPredicate((w) => w is AppField && w.label == label),
  matching: find.byType(TextField),
);

Future<void> _type(WidgetTester tester, String label, String value) async {
  final field = _field(label);
  expect(
    field,
    findsOneWidget,
    reason: 'no field is labelled "$label" on this form',
  );
  await tester.enterText(field, value);
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// A complete exercise, minus whatever the caller wants to leave out.
Future<void> _fillExercise(
  WidgetTester tester, {
  String id = 'goblet_squat',
  String nameEn = 'Goblet squat',
  String nameAr = 'القرفصاء بالدمبل',
  String tags = 'knee',
}) async {
  await _type(tester, 'Exercise id', id);
  await _type(tester, 'Name (English)', nameEn);
  await _type(tester, 'Name (Arabic)', nameAr);
  await _type(tester, 'Contraindication tags', tags);
}

/// A complete food, minus whatever the caller wants to leave out.
///
/// **Carbs and fat joined this list when they became drawable.** Both are
/// `required: true` in the schema and always have been, but `_labelFor` had no
/// case for either, so the fields were not drawn and a "complete" food here was
/// four-sevenths of one — which is precisely why Z05 authored rows the importer
/// refused. When the labels were minted and the cases added, three bilingual
/// tests started finding three "Required" markers instead of one, and the
/// "none is accepted" test stopped saving at all. Those failures were correct.
///
/// Filling them here also does a second job: [_type] asserts the field exists
/// before typing, so if `_labelFor` ever loses these cases this helper fails
/// loudly rather than quietly reverting Z05 to producing rejected foods.
Future<void> _fillFood(
  WidgetTester tester, {
  String id = 'koshari',
  String nameEn = 'Koshari',
  String nameAr = 'كشري',
  String kcal = '430',
  String protein = '13',
  String carbs = '68',
  String fat = '12',
  String allergens = 'gluten',
  String diet = 'vegetarian',
}) async {
  await _type(tester, 'Food id', id);
  await _type(tester, 'Name (English)', nameEn);
  await _type(tester, 'Name (Arabic)', nameAr);
  await _type(tester, 'kcal', kcal);
  await _type(tester, 'Protein g', protein);
  await _type(tester, 'Carbs g', carbs);
  await _type(tester, 'Fat g', fat);
  await _type(tester, 'Allergens', allergens);
  await _type(tester, 'Diet tags', diet);
}

void main() {
  group('Z03 — an exercise', () {
    testWidgets('it names itself and draws the fields the design draws', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const ContentFormView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add an exercise'), findsOneWidget);
      expect(find.text('Exercise id'), findsOneWidget);
      expect(find.text('Name (English)'), findsOneWidget);
      expect(find.text('Name (Arabic)'), findsOneWidget);
      expect(find.text('Equipment'), findsOneWidget);
      expect(find.text('Contraindication tags'), findsOneWidget);
    });

    testWidgets('a blank contraindication tag is refused, and says why', (
      tester,
    ) async {
      // The design shows this field in its error state deliberately. Blank and
      // "none" are different facts and the guard cannot tell them apart.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.exercises,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillExercise(tester, tags: '');
      await _save(tester);

      expect(saved, isNull, reason: 'a blank safety tag must not be saveable');
      expect(
        find.text(
          'Write “none” when there are none. Blank is not the same thing.',
        ),
        findsWidgets,
      );
    });

    testWidgets('"none" is accepted, and arrives as ordinary content', (
      tester,
    ) async {
      // §3.2: "`none` is valid and means 'this contains no allergens'." Nothing
      // treats it specially — which is exactly what makes it an answer rather
      // than an absence.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.exercises,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillExercise(tester, tags: 'none');
      await _save(tester);

      expect(saved, isNotNull);
      expect(saved!['contraindicationTags'], 'none');
    });

    testWidgets('a blank required name is refused as Required, not as a tag', (
      tester,
    ) async {
      // The two ideas are different — `name_ar` is required and is not a safety
      // column — and telling her to "write none" for a missing Arabic name
      // would be nonsense.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.exercises,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillExercise(tester, nameAr: '');
      await _save(tester);

      expect(saved, isNull);
      expect(find.text('Required'), findsOneWidget);
    });

    testWidgets('nothing is red before she has tried to save', (tester) async {
      // A form that turns red on open tells her she is wrong for opening it.
      _phone(tester);
      await tester.pumpWidget(
        _host(const ContentFormView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Required'), findsNothing);
    });

    testWidgets('quiet and floor only are toggles, never blank', (
      tester,
    ) async {
      // Both are required booleans. A text field would let staff type
      // "maybe", and `notABoolean` is a validation failure rather than a
      // default — "a silent default puts jumping into her quiet programme".
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.exercises,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quiet'), findsOneWidget);
      expect(find.text('Floor only'), findsOneWidget);
      expect(find.byType(AppToggle), findsNWidgets(2));

      await _fillExercise(tester);
      await tester.tap(find.text('Quiet'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved!['quiet'], 'true');
      expect(saved!['floorOnly'], 'false');
    });

    testWidgets('a saved exercise passes the importer that guards the library', (
      tester,
    ) async {
      // The strongest assertion here: a row authored on this screen and a row
      // imported from a CSV are the same kind of thing. If the form could
      // produce something `validateImport` refuses, staff would have two
      // contradictory descriptions of a valid exercise.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.exercises,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillExercise(tester);
      await _type(tester, 'Equipment', 'dumbbell');
      await _save(tester);

      final schema = ContentSchema.of(ContentCollection.exercises);
      final plan = validateImport(
        collection: ContentCollection.exercises,
        table: parseCsv(
          '${schema.columnNames.join(',')}\n'
          '${[for (final c in schema.columnNames) csvField(saved![c]!)].join(',')}\n',
        ),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(
        plan.problems,
        isEmpty,
        reason:
            'the form produced a row its own importer refuses: '
            '${plan.problems}',
      );
      expect(plan.writes.single.id, 'goblet_squat');
    });
  });

  group('Z05 — a food', () {
    testWidgets('it names itself and draws the fields the design draws', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const ContentFormView(collection: ContentCollection.foods)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a food'), findsOneWidget);
      expect(find.text('Food id'), findsOneWidget);
      expect(find.text('kcal'), findsOneWidget);
      expect(find.text('Protein g'), findsOneWidget);
      expect(find.text('Allergens'), findsOneWidget);
      expect(find.text('Diet tags'), findsOneWidget);
    });

    testWidgets('a blank allergens cell is refused', (tester) async {
      // Where it matters most. Knowing a dish is koshari does not tell the app
      // whether it contains nuts, and `AllergyGuard` reads the blank as
      // "unknown, therefore unsafe" and starts interrupting women who have no
      // allergy at all.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillFood(tester, allergens: '');
      await _save(tester);

      expect(saved, isNull);
      expect(
        find.text(
          'Write “none” when there are none. Blank is not the same thing.',
        ),
        findsWidgets,
      );
    });

    testWidgets('"none" is accepted on a food too', (tester) async {
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillFood(tester, allergens: 'none');
      await _save(tester);

      expect(saved, isNotNull);
      expect(saved!['allergens'], 'none');
    });

    testWidgets('a saved food passes the importer that guards the library', (
      tester,
    ) async {
      // Z03's assertion, for foods — and the one that could not be made while
      // `carbsG` and `fatG` had no label. Both are `required: true`, so with
      // the fields undrawn this screen could only ever author a row
      // `validateImport` refuses: a form that looked like it worked and
      // produced nothing importable.
      //
      // The two halves have to agree. If the form can produce something its
      // own importer rejects, staff hold two contradictory descriptions of a
      // valid food and only one of them is enforced.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillFood(tester);
      await _save(tester);

      expect(
        saved,
        isNotNull,
        reason: 'a complete food must save; if this is null a field is missing',
      );

      final schema = ContentSchema.of(ContentCollection.foods);
      final plan = validateImport(
        collection: ContentCollection.foods,
        table: parseCsv(
          '${schema.columnNames.join(',')}\n'
          '${[for (final c in schema.columnNames) csvField(saved![c]!)].join(',')}\n',
        ),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(
        plan.problems,
        isEmpty,
        reason:
            'the form produced a food its own importer refuses: '
            '${plan.problems}',
      );
      expect(plan.writes.single.id, 'koshari');
    });

    group('it is bilingual, and both halves are required', () {
      // §3.3: the library "carries its own display text because it is content
      // from a build-time bundle, not copy from the dictionary". The missing
      // half is not a translation that can be supplied later — it is the browse
      // list having nothing to draw for half the product's readers.

      testWidgets('an English name alone is refused', (tester) async {
        _phone(tester);
        Map<String, String>? saved;

        await tester.pumpWidget(
          _host(
            ContentFormView(
              collection: ContentCollection.foods,
              onSave: (row) => saved = row,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _fillFood(tester, nameAr: '');
        await _save(tester);

        expect(saved, isNull);
        expect(find.text('Required'), findsOneWidget);
      });

      testWidgets('an Arabic name alone is refused', (tester) async {
        _phone(tester);
        Map<String, String>? saved;

        await tester.pumpWidget(
          _host(
            ContentFormView(
              collection: ContentCollection.foods,
              onSave: (row) => saved = row,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _fillFood(tester, nameEn: '');
        await _save(tester);

        expect(saved, isNull);
        expect(find.text('Required'), findsOneWidget);
      });

      testWidgets('both together are accepted and both are carried', (
        tester,
      ) async {
        _phone(tester);
        Map<String, String>? saved;

        await tester.pumpWidget(
          _host(
            ContentFormView(
              collection: ContentCollection.foods,
              onSave: (row) => saved = row,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await _fillFood(tester);
        await _save(tester);

        expect(saved!['name_en'], 'Koshari');
        expect(saved!['name_ar'], 'كشري');
      });

      testWidgets('the Arabic name field asks to read right-to-left under en', (
        tester,
      ) async {
        // Content direction follows the content, not the interface — the same
        // rule `AppField` documents for a phone number in the other direction:
        // "Forced for content that is always one direction regardless of the
        // app's language."
        //
        // This asserts the **request**, on the `AppField`, and not the
        // `TextField` inside it. `lib/ui/app_field.dart` declares
        // `textDirection` and never passes it on, so the parameter is inert
        // today for every caller including `phone_number_view.dart`. That is an
        // upstream defect in a shared widget this feature may not edit, and it
        // is reported. When it is fixed, this screen is already correct and
        // this test needs no change.
        _phone(tester);
        await tester.pumpWidget(
          _host(const ContentFormView(collection: ContentCollection.foods)),
        );
        await tester.pumpAndSettle();

        final arabic = tester.widget<AppField>(
          find.byWidgetPredicate(
            (w) => w is AppField && w.label == 'Name (Arabic)',
          ),
        );
        final english = tester.widget<AppField>(
          find.byWidgetPredicate(
            (w) => w is AppField && w.label == 'Name (English)',
          ),
        );

        expect(arabic.textDirection, TextDirection.rtl);
        expect(english.textDirection, TextDirection.ltr);
      });
    });

    testWidgets('a macro that is not a whole number is refused', (
      tester,
    ) async {
      // §3.5: "macros numeric and non-negative". The importer refuses it, so
      // the form must too, or the two disagree about the same library.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _fillFood(tester, kcal: '-12');
      await _save(tester);

      expect(saved, isNull);
      expect(find.text('Check the number and try again.'), findsOneWidget);
    });

    testWidgets('Eastern Arabic digits are refused, not silently misread', (
      tester,
    ) async {
      // Dart's `\d` is `[0-9]`, which `import_validator.dart` relies on for the
      // same reason: guessing at a calorie figure would put an unverifiable
      // number in front of a woman.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            onSave: (row) => saved = row,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      await _type(tester, 'معرّف الأكلة', 'koshari');
      await _type(tester, 'الاسم (بالإنجليزي)', 'Koshari');
      await _type(tester, 'الاسم (بالعربي)', 'كشري');
      await _type(tester, 'سعرة', '٤٣٠');
      await _type(tester, 'البروتين (جم)', '13');
      await _type(tester, 'مسببات الحساسية', 'gluten');
      await _type(tester, 'وسوم النظام الغذائي', 'vegetarian');
      await tester.tap(find.text('احفظي'));
      await tester.pumpAndSettle();

      expect(saved, isNull);
    });
  });

  group('the form is the contract, not a copy of it', () {
    test('every safety column in the schema is one this form can author', () {
      // The gap that would matter most: a safety column with no label would be
      // withheld, and staff would have a form that cannot express the one thing
      // the console exists to capture. Asserted against the schema so that
      // adding a safety column to a CSV fails here rather than quietly.
      const labelled = {
        'exerciseId',
        'foodId',
        'name_en',
        'name_ar',
        'equipment',
        'contraindicationTags',
        'allergens',
        'dietTags',
        'kcal',
        'proteinG',
        'quiet',
        'floorOnly',
      };

      for (final collection in [
        ContentCollection.exercises,
        ContentCollection.foods,
      ]) {
        for (final column in ContentSchema.of(collection).safetyTagColumns) {
          expect(
            labelled,
            contains(column),
            reason:
                '$column is a mandatory safety column on ${collection.name} '
                'and this form has no label for it, so it cannot be authored '
                'here at all',
          );
        }
      }
    });

    testWidgets('a column the dictionary cannot label is not drawn', (
      tester,
    ) async {
      // `carbsG` and `fatG` are required and have no string in either language.
      // They are withheld rather than labelled with an invented English word or
      // with the raw column name — and the consequence is reported rather than
      // hidden.
      _phone(tester);
      await tester.pumpWidget(
        _host(const ContentFormView(collection: ContentCollection.foods)),
      );
      await tester.pumpAndSettle();

      expect(find.text('carbsG'), findsNothing);
      expect(find.text('fatG'), findsNothing);
      expect(find.text('portions'), findsNothing);
    });

    testWidgets('editing never drops a column the form could not draw', (
      tester,
    ) async {
      // The failure this guards: opening a food to fix its allergens, saving,
      // and silently losing its carbohydrate figure because there is no English
      // word for it. Data loss through a form is worse than a form that asks
      // for less.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            values: const {
              'foodId': 'koshari',
              'name_en': 'Koshari',
              'name_ar': 'كشري',
              'portions': 'plate',
              'kcal': '430',
              'proteinG': '13',
              'carbsG': '78',
              'fatG': '7',
              'allergens': '',
              'dietTags': 'vegetarian',
            },
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _type(tester, 'Allergens', 'gluten');
      await _save(tester);

      expect(saved!['carbsG'], '78');
      expect(saved!['fatG'], '7');
      expect(saved!['portions'], 'plate');
      expect(saved!['allergens'], 'gluten');
    });

    testWidgets('an existing row arrives in the fields', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const ContentFormView(
            collection: ContentCollection.exercises,
            values: {
              'exerciseId': 'goblet_squat',
              'name_en': 'Goblet squat',
              'name_ar': 'القرفصاء بالدمبل',
              'contraindicationTags': 'knee',
              'quiet': 'true',
              'floorOnly': 'false',
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('goblet_squat'), findsOneWidget);
      expect(find.text('Goblet squat'), findsOneWidget);
      expect(
        tester.widget<AppToggle>(find.byType(AppToggle).first).value,
        isTrue,
      );
    });
  });

  group('Z06 — a recipe', () {
    // Recipes could not be authored on this screen **at all** until twelve
    // labels were minted — not partly: `recipeId` is the id column and
    // `minutes` is required, so the form could neither say which row it was
    // about nor produce one the importer would accept.

    testWidgets('it names itself and draws the recipe columns', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const ContentFormView(collection: ContentCollection.recipes)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a recipe'), findsOneWidget);
      expect(find.text('Recipe id'), findsOneWidget);
      expect(find.text('Minutes'), findsOneWidget);
      expect(find.text('Ingredients'), findsOneWidget);
      expect(find.text('Photo file'), findsOneWidget);
      expect(find.text('Allergens'), findsOneWidget);
      expect(find.text('Diet tags'), findsOneWidget);
    });

    testWidgets('a recipe authored here passes the importer', (tester) async {
      // Z03's and Z05's assertion, for the third collection: a row authored on
      // this screen and a row imported from a CSV are the same kind of thing.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.recipes,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _type(tester, 'Recipe id', 'om_ali');
      await _type(tester, 'Name (English)', 'Om Ali');
      await _type(tester, 'Name (Arabic)', 'أم علي');
      await _type(tester, 'Minutes', '45');
      await _type(tester, 'Ingredients', 'pastry|milk|nuts');
      await _type(tester, 'Allergens', 'nuts|dairy');
      await _type(tester, 'Diet tags', 'vegetarian');
      // Two different people, or the rules refuse the write.
      await _type(tester, 'Author', 'content_team');
      await _type(tester, 'Allergens checked by', 'qa_reviewer');
      await _save(tester);

      expect(
        saved,
        isNotNull,
        reason:
            'a complete recipe must save; if this is null a field is '
            'missing from the form',
      );

      final schema = ContentSchema.of(ContentCollection.recipes);
      final plan = validateImport(
        collection: ContentCollection.recipes,
        table: parseCsv(
          '${schema.columnNames.join(',')}\n'
          '${[for (final c in schema.columnNames) csvField(saved![c]!)].join(',')}\n',
        ),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(
        plan.problems,
        isEmpty,
        reason:
            'the form produced a recipe its own importer refuses: '
            '${plan.problems}',
      );
      expect(plan.writes.single.id, 'om_ali');
      expect(plan.writes.single.list('allergens'), ['nuts', 'dairy']);
    });

    testWidgets('a blank allergens cell is refused on a recipe too', (
      tester,
    ) async {
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.recipes,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _type(tester, 'Recipe id', 'om_ali');
      await _type(tester, 'Name (English)', 'Om Ali');
      await _type(tester, 'Name (Arabic)', 'أم علي');
      await _type(tester, 'Minutes', '45');
      await _type(tester, 'Diet tags', 'vegetarian');
      await _save(tester);

      expect(saved, isNull);
      expect(
        find.text(
          'Write “none” when there are none. Blank is not the same thing.',
        ),
        findsWidgets,
      );
    });
  });

  group('Z07 — a programme', () {
    testWidgets('it names itself and draws the programme columns', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const ContentFormView(collection: ContentCollection.programmes)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add a programme'), findsOneWidget);
      expect(find.text('Programme id'), findsOneWidget);
      expect(find.text('Weeks'), findsOneWidget);
      expect(find.text('Days a week'), findsOneWidget);
      expect(find.text('Session length'), findsOneWidget);
      expect(find.text('Quiet'), findsOneWidget);
    });

    testWidgets('a programme authored here passes the importer', (
      tester,
    ) async {
      // A programme carries no safety column — it holds no ingredient and no
      // movement of its own — so what this proves is the other half: four
      // required numbers, a required boolean, and a bilingual name.
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.programmes,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _type(tester, 'Programme id', 'six_week_return');
      await _type(tester, 'Name (English)', 'Six week return');
      await _type(tester, 'Name (Arabic)', 'العودة في ستة أسابيع');
      await _type(tester, 'Weeks', '6');
      await _type(tester, 'Days a week', '4');
      await _type(tester, 'Session length', '40');
      await _type(tester, 'Equipment', 'dumbbell|mat');
      // Quiet is a toggle and starts false, which is the safe direction: a
      // programme is not promised as quiet unless somebody says so.
      await tester.tap(find.text('Quiet'));
      await tester.pumpAndSettle();
      await _save(tester);

      expect(saved, isNotNull, reason: 'a complete programme must save');
      expect(saved!['quiet'], 'true');

      final schema = ContentSchema.of(ContentCollection.programmes);
      final plan = validateImport(
        collection: ContentCollection.programmes,
        table: parseCsv(
          '${schema.columnNames.join(',')}\n'
          '${[for (final c in schema.columnNames) csvField(saved![c]!)].join(',')}\n',
        ),
        uploadedMedia: const {},
        existingIds: const {},
      );

      expect(
        plan.problems,
        isEmpty,
        reason:
            'the form produced a programme its own importer refuses: '
            '${plan.problems}',
      );
      expect(plan.writes.single.id, 'six_week_return');
      expect(plan.writes.single.number('weeks'), 6);
      expect(plan.writes.single.boolean('quiet'), isTrue);
    });

    testWidgets('a missing session length is refused as Required', (
      tester,
    ) async {
      _phone(tester);
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.programmes,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _type(tester, 'Programme id', 'six_week_return');
      await _type(tester, 'Name (English)', 'Six week return');
      await _type(tester, 'Name (Arabic)', 'العودة في ستة أسابيع');
      await _type(tester, 'Weeks', '6');
      await _type(tester, 'Days a week', '4');
      await _save(tester);

      expect(saved, isNull);
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('the house rules', () {
    testWidgets('it raises no dialog, on either screen', (tester) async {
      // Rule 9. A form is the likeliest place for "discard your changes?" to
      // appear, and it may not.
      _phone(tester);
      for (final collection in ContentCollection.values) {
        await tester.pumpWidget(_host(ContentFormView(collection: collection)));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.byType(Dialog), findsNothing);
      }
    });

    testWidgets('closing returns without saving', (tester) async {
      _phone(tester);
      var closed = 0;
      Map<String, String>? saved;

      await tester.pumpWidget(
        _host(
          ContentFormView(
            collection: ContentCollection.foods,
            onClose: () => closed++,
            onSave: (row) => saved = row,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(closed, 1);
      expect(saved, isNull);
    });

    testWidgets('it mirrors in Arabic at the largest text size', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const ContentFormView(collection: ContentCollection.exercises),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('أضيفي تمرينًا'), findsOneWidget);
      expect(find.text('وسوم الموانع'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('أضيفي تمرينًا'))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the error reads in Arabic too', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const ContentFormView(collection: ContentCollection.foods),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('احفظي'));
      await tester.pumpAndSettle();

      expect(
        find.text('اكتبي «none» لو مفيش. والخانة الفاضية مش نفس الحاجة.'),
        findsWidgets,
      );
      expect(find.text('مطلوب'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
