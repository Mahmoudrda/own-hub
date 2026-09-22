// Z08 → Z09 → commit. The most important flow in this feature.
//
// G16 §3.1: "The file is parsed and validated **in full** before anything is
// written. If any row fails, nothing is written at all."
//
// The validator already proves that as arithmetic. What these tests prove is
// that the *screen* keeps the same promise — that the button is not offered when
// the batch cannot commit, that tapping it does not write, and that the
// confirmation is an inline state rather than a dialog.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/csv_parser.dart';
import 'package:own_hub/features/admin/domain/import_validator.dart';
import 'package:own_hub/features/admin/domain/text_source.dart';
import 'package:own_hub/features/admin/presentation/admin_widgets.dart';
import 'package:own_hub/features/admin/presentation/bulk_import_view.dart';
import 'package:own_hub/features/admin/presentation/import_check_view.dart';
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

ImportPlan _plan(String csv) => validateImport(
  collection: ContentCollection.foods,
  table: parseCsv(csv),
  uploadedMedia: const {},
  existingIds: const {},
);

const String _header =
    'foodId,name_en,name_ar,portions,kcal,proteinG,carbsG,fatG,allergens,dietTags\n';

ImportPlan _cleanPlan() =>
    _plan('$_header koshari,Koshari,K,plate,430,13,78,7,gluten,vegetarian\n');

ImportPlan _brokenPlan() => _plan(
  '${_header}koshari,Koshari,K,plate,430,13,78,7,gluten,vegetarian\n'
  'ful,Ful,F,bowl,220,12,30,6,,vegetarian\n',
);

/// Two rows, both good — and a different count from every other fixture here,
/// so a screen reporting a constant could not pass.
ImportPlan _twoRowPlan() => _plan(
  '${_header}molokhia,Molokhia,M,bowl,180,9,14,8,none,vegetarian\n'
  'fattah,Fattah,F,plate,610,24,70,26,gluten|dairy,none\n',
);

void main() {
  group('Z08 — choosing a file', () {
    testWidgets('it names itself and offers the four collections', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(const BulkImportView()));
      await tester.pumpAndSettle();

      expect(find.text('Bulk import'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Foods'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
      expect(find.text('Programmes'), findsOneWidget);
    });

    testWidgets('the collection can be changed', (tester) async {
      _phone(tester);
      final chosen = <ContentCollection>[];

      await tester.pumpWidget(
        _host(BulkImportView(onCollectionChanged: chosen.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Recipes'));
      await tester.pumpAndSettle();

      expect(chosen, [ContentCollection.recipes]);
    });

    testWidgets('it offers to choose a CSV file', (tester) async {
      _phone(tester);
      var chose = 0;

      await tester.pumpWidget(
        _host(BulkImportView(onChooseFile: () => chose++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose a CSV file'));
      await tester.pumpAndSettle();

      expect(chose, 1);
    });

    testWidgets('choosing a file is offered in a word as well', (tester) async {
      _phone(tester);
      var chose = 0;

      await tester.pumpWidget(
        _host(BulkImportView(onChooseFile: () => chose++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();

      expect(chose, 1);
    });

    testWidgets('with no source behind it, nothing is offered as live', (
      tester,
    ) async {
      // There is no file picker in `pubspec.yaml`. A "Choose a file" button
      // that opened nothing would send staff looking for a file dialog that is
      // never coming, so the control is drawn as plainly not live instead.
      _phone(tester);
      var chose = 0;

      await tester.pumpWidget(
        _host(
          BulkImportView(
            source: const UnavailableTextSource(),
            onChooseFile: () => chose++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminUnavailableAction), findsOneWidget);

      await tester.tap(find.text('Choose a file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a CSV file'));
      await tester.pumpAndSettle();

      expect(chose, 0);
    });

    testWidgets('the file cannot be checked until one is chosen', (
      tester,
    ) async {
      // Offering "Check the file" with no file is a button that can only
      // disappoint. Disabled is the honest state.
      _phone(tester);
      var checked = 0;

      await tester.pumpWidget(
        _host(BulkImportView(onCheckFile: () => checked++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check the file'));
      await tester.pumpAndSettle();

      expect(checked, 0);
    });

    testWidgets('with a file chosen, checking it is available', (tester) async {
      _phone(tester);
      var checked = 0;

      await tester.pumpWidget(
        _host(
          BulkImportView(
            chosenFileName: 'foods.csv',
            onCheckFile: () => checked++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Check the file'));
      await tester.pumpAndSettle();

      expect(checked, 1);
    });

    testWidgets('it states the contract before the file is chosen', (
      tester,
    ) async {
      // The design's point: "The expected columns are on screen before the file
      // is chosen, so a mismatch is caught by reading rather than by failing."
      _phone(tester);
      await tester.pumpWidget(_host(const BulkImportView()));
      await tester.pumpAndSettle();

      expect(find.text('Columns it expects'), findsOneWidget);
      expect(find.text('Column'), findsOneWidget);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('foodId'), findsOneWidget);
      expect(find.text('allergens'), findsOneWidget);
      expect(find.text('yes'), findsWidgets);
    });

    testWidgets('the bilingual pair is stated as one decision', (tester) async {
      // §3.3. A file carrying only one of the two is not half-translated, it is
      // a browse list with nothing to draw for half the product's readers — so
      // the contract states them together and marks them "yes, both".
      _phone(tester);
      await tester.pumpWidget(_host(const BulkImportView()));
      await tester.pumpAndSettle();

      expect(find.text('name_en / name_ar'), findsOneWidget);
      expect(find.text('yes, both'), findsOneWidget);
    });

    testWidgets('the table is the chosen collection\'s contract, not a copy', (
      tester,
    ) async {
      // Read off ContentSchema, so choosing exercises shows the exercise
      // columns rather than a table that was typed once for foods.
      _phone(tester);
      await tester.pumpWidget(
        _host(const BulkImportView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      expect(find.text('exerciseId'), findsOneWidget);
      expect(find.text('contraindicationTags'), findsOneWidget);
      expect(find.text('foodId'), findsNothing);
    });

    testWidgets('an optional column is not marked required', (tester) async {
      // There is no "no" in the dictionary, and an empty cell under "Required"
      // already reads as one. `videoFile` is optional because a library may be
      // imported before its filming is finished.
      _phone(tester);
      await tester.pumpWidget(
        _host(const BulkImportView(collection: ContentCollection.exercises)),
      );
      await tester.pumpAndSettle();

      final schema = ContentSchema.of(ContentCollection.exercises);
      expect(schema.column('videoFile')!.required, isFalse);
      expect(find.text('videoFile'), findsOneWidget);
    });

    testWidgets('it mirrors in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          const BulkImportView(),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('استيراد جماعي'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Z09 — the dry run', () {
    testWidgets('it says plainly that nothing has been written', (
      tester,
    ) async {
      // The banner is the screen's promise, and it is a real dictionary string.
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _cleanPlan())));
      await tester.pumpAndSettle();

      expect(find.text('Import check'), findsOneWidget);
      expect(find.text('Nothing has been written yet.'), findsOneWidget);
    });

    testWidgets('a clean file says how many rows are ready', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _twoRowPlan())));
      await tester.pumpAndSettle();

      expect(find.text('2 rows ready'), findsOneWidget);
    });

    testWidgets('a failing file claims nothing is ready', (tester) async {
      // One row of the two passed, and `writes` is still empty — §3.1 refuses
      // the whole batch. Naming a number of ready rows beside a list of
      // failures would promise a write that is not going to happen.
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _brokenPlan())));
      await tester.pumpAndSettle();

      expect(find.textContaining('rows ready'), findsNothing);
    });

    testWidgets('a failing row is named by its line number', (tester) async {
      // §3.1: every bad row is named. The line number is the one the
      // spreadsheet's own gutter shows, and the column is named as the file
      // names it.
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _brokenPlan())));
      await tester.pumpAndSettle();

      expect(find.text('Rows with problems'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('allergens'), findsOneWidget);
    });

    testWidgets('the failing rows are headed Row and Problem', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _brokenPlan())));
      await tester.pumpAndSettle();

      expect(find.text('Row'), findsOneWidget);
      expect(find.text('Problem'), findsOneWidget);
    });

    testWidgets('returning to the file is offered in words', (tester) async {
      // The common case by far: the file was wrong. With a batch that cannot
      // commit the primary button is disabled, so without this the screen
      // offers nothing she can act on.
      _phone(tester);
      var backs = 0;

      await tester.pumpWidget(
        _host(ImportCheckView(plan: _brokenPlan(), onBack: () => backs++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back to the file'));
      await tester.pumpAndSettle();

      expect(backs, 1);
    });

    testWidgets('a clean plan reports no problems', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _cleanPlan())));
      await tester.pumpAndSettle();

      expect(find.text('allergens'), findsNothing);
    });

    testWidgets('a batch that cannot commit does not offer to', (tester) async {
      // The heart of §3.1. One bad row, and the import is not available at all
      // — not available-then-refused, which is how "just import the good ones"
      // becomes a feature request.
      _phone(tester);
      var committed = 0;

      await tester.pumpWidget(
        _host(
          ImportCheckView(plan: _brokenPlan(), onCommit: () => committed++),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();

      expect(committed, 0);
    });

    testWidgets('the fix-and-retry note is shown when rows failed', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _brokenPlan())));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Fix these rows and import again. Nothing is saved until every row '
          'passes.',
        ),
        findsOneWidget,
      );
    });
  });

  group('Z09 — committing is confirmed in place, never in a dialog', () {
    testWidgets('the first tap confirms and writes nothing', (tester) async {
      // Rule 9 forbids a dialog; §3.1 makes this destructive enough to deserve
      // a question. `cycle_deletion_machine.dart` settled the shape: the
      // confirmation is a STATE, and the footer changes in place.
      _phone(tester);
      var committed = 0;

      await tester.pumpWidget(
        _host(ImportCheckView(plan: _cleanPlan(), onCommit: () => committed++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();

      expect(committed, 0, reason: 'the first tap asks, it does not write');
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Cancel'), findsOneWidget);

      // And it asks in words. Everything a dialog would have said, in the place
      // the answer is given — which is the whole point of the inline state.
      expect(find.text('Import everything?'), findsOneWidget);
    });

    testWidgets('the question is withdrawn when she backs out', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(ImportCheckView(plan: _cleanPlan())));
      await tester.pumpAndSettle();

      expect(find.text('Import everything?'), findsNothing);

      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();
      expect(find.text('Import everything?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Import everything?'), findsNothing);
    });

    testWidgets('confirming writes exactly once', (tester) async {
      _phone(tester);
      var committed = 0;

      await tester.pumpWidget(
        _host(ImportCheckView(plan: _cleanPlan(), onCommit: () => committed++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();

      expect(committed, 1);
    });

    testWidgets('backing out writes nothing and restores the offer', (
      tester,
    ) async {
      _phone(tester);
      var committed = 0;

      await tester.pumpWidget(
        _host(ImportCheckView(plan: _cleanPlan(), onCommit: () => committed++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(committed, 0);
      expect(find.text('Cancel'), findsNothing);
      expect(find.text('Import everything'), findsOneWidget);
    });

    testWidgets('a double tap on the confirmation does not write twice', (
      tester,
    ) async {
      // A bulk import run twice is the library written twice. The machine
      // guards it; this is the rendered proof.
      _phone(tester);
      var committed = 0;

      await tester.pumpWidget(
        _host(ImportCheckView(plan: _cleanPlan(), onCommit: () => committed++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Import everything'));
      await tester.pumpAndSettle();

      final confirm = find.text('Import everything');
      await tester.tap(confirm);
      await tester.pump();
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm, warnIfMissed: false);
      }
      await tester.pumpAndSettle();

      expect(committed, 1);
    });
  });

  testWidgets('Z09 counts in Western digits under ar', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(ImportCheckView(plan: _brokenPlan()), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('١'), findsNothing);
    expect(find.text('٣'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
