// Z02, Z04, Z06, Z07 — the four browse lists.
//
// One widget serves all four. The design draws them as four screens, and they
// differ only in their title, their filter chips and which safety column they
// are anxious about — so four copies would be four places to fix the next time
// the safety rule changes, on the feature whose entire purpose is that rule.
//
// ## The names on these rows are CONTENT, not copy
//
// §3.3: the library "carries its own display text because it is content from a
// build-time bundle, not copy from the dictionary. So every CSV carries
// `name_en` and `name_ar`, and none of this passes through `6-v2/i18n/` or the
// ARB." A row therefore renders `name_ar` under `ar` and `name_en` under `en`,
// read from the imported row — which is exactly why the importer refuses a row
// that has only one of them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/presentation/collection_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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

const String _foodHeader =
    'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n';

const String _exerciseHeader =
    'exerciseId,name_en,name_ar,equipment,pattern,contraindicationTags,quiet,'
    'floorOnly,videoFile,thumbFile\n';

/// Two foods, one of them untagged, read through the real importer so the view
/// is fed the shape it will actually receive.
List<ImportRow> _foods() {
  final plan = validateImport(
    collection: ContentCollection.foods,
    table: parseCsv(
      '$_foodHeader'
      'koshari,Koshari,كشري,plate,430,13,78,7,gluten,vegetarian\n',
    ),
    uploadedMedia: const {},
    existingIds: const {},
  );
  return plan.writes;
}

/// One food the library knows nutritionally and one it does not.
///
/// Every macro at zero is what an unauthored row looks like — not a food that
/// happens to be calorie-free, which is why the chip reads every macro rather
/// than any one of them.
List<ImportRow> _foodsOneWithoutMacros() {
  final plan = validateImport(
    collection: ContentCollection.foods,
    table: parseCsv(
      '$_foodHeader'
      'koshari,Koshari,كشري,plate,430,13,78,7,gluten,vegetarian\n'
      'ful,Ful medames,فول مدمس,bowl,0,0,0,0,none,vegan\n',
    ),
    uploadedMedia: const {},
    existingIds: const {},
  );
  return plan.writes;
}

/// One exercise with its clip filmed and one without.
List<ImportRow> _exercisesOneWithoutAVideo() {
  final plan = validateImport(
    collection: ContentCollection.exercises,
    table: parseCsv(
      '$_exerciseHeader'
      'goblet_squat,Goblet squat,القرفصاء بالدمبل,dumbbell,squat,knee,false,'
      'false,goblet_squat.mp4,goblet_squat.jpg\n'
      'glute_bridge,Glute bridge,جسر المؤخرة,none,hinge,none,true,true,,\n',
    ),
    uploadedMedia: const {'goblet_squat.mp4', 'goblet_squat.jpg'},
    existingIds: const {},
  );
  return plan.writes;
}

void main() {
  group('each collection names itself', () {
    testWidgets('exercises', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Exercises'), findsOneWidget);
    });

    testWidgets('foods', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.foods)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Foods'), findsOneWidget);
    });

    testWidgets('recipes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.recipes)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recipes'), findsOneWidget);
    });

    testWidgets('programmes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.programmes)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Programmes'), findsOneWidget);
    });
  });

  group('the filter chips name the state worth finding', () {
    testWidgets('exercises filter on missing contraindications', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Missing contraindications'), findsOneWidget);
    });

    testWidgets('foods filter on missing allergens', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.foods)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Missing allergens'), findsOneWidget);
    });

    testWidgets('recipes filter on allergens and on a missing photo', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.recipes)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Missing allergens'), findsOneWidget);
      expect(find.text('No photo'), findsOneWidget);
    });

    testWidgets(
      'programmes carry no safety filter, because they carry no tag',
      (tester) async {
        // Not an oversight: a programme holds no ingredient and no movement of
        // its own, so there is nothing for a guard to read off it.
        _phone(tester);
        await tester.pumpWidget(
          _host(const CollectionView(collection: ContentCollection.programmes)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Missing allergens'), findsNothing);
        expect(find.text('Missing contraindications'), findsNothing);
      },
    );

    testWidgets('exercises filter on a move whose clip was never filmed', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No video'), findsOneWidget);
    });

    testWidgets('foods filter on a row the library knows nothing about', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.foods)),
      );
      await tester.pumpAndSettle();

      expect(find.text('No macros'), findsOneWidget);
    });

    testWidgets('"No video" finds the move with no clip, not the one with', (
      tester,
    ) async {
      // The chip is about the clip, not the still beside it: a row carrying a
      // thumbnail and no video is exactly the row this is for.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CollectionView(
            collection: ContentCollection.exercises,
            rows: _exercisesOneWithoutAVideo(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Goblet squat'), findsOneWidget);
      expect(find.text('Glute bridge'), findsOneWidget);

      await tester.tap(find.text('No video'));
      await tester.pumpAndSettle();

      expect(find.text('Glute bridge'), findsOneWidget);
      expect(find.text('Goblet squat'), findsNothing);
    });

    testWidgets('"No macros" finds the unauthored row, not the zero-calorie', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CollectionView(
            collection: ContentCollection.foods,
            rows: _foodsOneWithoutMacros(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('No macros'));
      await tester.pumpAndSettle();

      expect(find.text('Ful medames'), findsOneWidget);
      expect(find.text('Koshari'), findsNothing);
    });

    testWidgets('changing a filter does not throw', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.foods)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missing allergens'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('rows', () {
    testWidgets('a row shows its English name under en', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CollectionView(collection: ContentCollection.foods, rows: _foods()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Koshari'), findsOneWidget);
    });

    testWidgets('and its Arabic name under ar', (tester) async {
      // The bilingual pair earning its keep. This is content from the CSV, not
      // a dictionary string — which is why the importer refuses a row carrying
      // only one of the two.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CollectionView(collection: ContentCollection.foods, rows: _foods()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('كشري'), findsOneWidget);
      expect(find.text('Koshari'), findsNothing);
    });

    testWidgets('a row opens by id, not by position', (tester) async {
      _phone(tester);
      final opened = <String>[];

      await tester.pumpWidget(
        _host(
          CollectionView(
            collection: ContentCollection.foods,
            rows: _foods(),
            onOpenRow: opened.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Koshari'));
      await tester.pumpAndSettle();

      expect(opened, ['koshari']);
    });
  });

  group('an empty collection says so', () {
    // The real state of all four today, and the reason this console was
    // commissioned. A filter row above nothing at all says less than it could.

    testWidgets('each collection names its own emptiness', (tester) async {
      const expected = {
        ContentCollection.exercises: 'No exercises yet',
        ContentCollection.foods: 'No foods yet',
        ContentCollection.recipes: 'No recipes yet',
        ContentCollection.programmes: 'No programmes yet',
      };

      for (final entry in expected.entries) {
        _phone(tester);
        await tester.pumpWidget(_host(CollectionView(collection: entry.key)));
        await tester.pumpAndSettle();

        expect(
          find.text(entry.value),
          findsOneWidget,
          reason: '${entry.key.name} should say "${entry.value}"',
        );
      }
    });

    testWidgets('a collection with rows does not claim to be empty', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CollectionView(collection: ContentCollection.foods, rows: _foods()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No foods yet'), findsNothing);
    });

    testWidgets('a filter that narrows to nothing is not an empty library', (
      tester,
    ) async {
      // "No foods yet" would be false here — there is a food, it just is not
      // the one the chip is looking for. The chip already explains the blank.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CollectionView(collection: ContentCollection.foods, rows: _foods()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Missing allergens'));
      await tester.pumpAndSettle();

      expect(find.text('Koshari'), findsNothing);
      expect(find.text('No foods yet'), findsNothing);
    });
  });

  group('adding one row', () {
    // D12 asked for content to be addable "from within the app". Bulk import is
    // the half that scales; this is the entry point to the half that does not.

    testWidgets('the add action opens the form', (tester) async {
      _phone(tester);
      var added = 0;

      await tester.pumpWidget(
        _host(
          CollectionView(
            collection: ContentCollection.exercises,
            onAdd: () => added++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(added, 1);
    });

    testWidgets('no add button is drawn when there is no form to open', (
      tester,
    ) async {
      // An action that opens nothing is worse than no action. Two of the four
      // collections have no form yet, and this is what keeps that honest on
      // screen rather than only in a comment.
      _phone(tester);
      await tester.pumpWidget(
        _host(const CollectionView(collection: ContentCollection.programmes)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsNothing);
    });
  });

  testWidgets('an empty collection offers the import rather than a form', (
    tester,
  ) async {
    // §intro: one form at a time is not how 124 exercises arrive.
    _phone(tester);
    var imported = 0;

    await tester.pumpWidget(
      _host(
        CollectionView(
          collection: ContentCollection.foods,
          onImport: () => imported++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulk import'));
    await tester.pumpAndSettle();

    expect(imported, 1);
  });

  testWidgets('it mirrors in Arabic at the largest text size', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const CollectionView(collection: ContentCollection.exercises),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('التمارين'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it raises no dialog', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(const CollectionView(collection: ContentCollection.foods)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
