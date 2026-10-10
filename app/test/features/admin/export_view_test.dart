// Z11 — Export. "Content only, ever."
//
// The screen's own note is the strongest sentence in the design file: "No
// `users/**` path is reachable from here — not logs, not photos, not cycle. The
// app tells her that her ID photo is deleted and her logs are never shown to
// members; an admin bulk-export of user media would make both statements false,
// and under PDPL it is the line between a content catalogue and regulated
// personal data."
//
// `export_manifest_test.dart` proves the manifest cannot express that. This
// proves the screen does not offer it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/presentation/export_view.dart';
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

void main() {
  testWidgets('it offers exactly the four content collections', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(const ExportView()));
    await tester.pumpAndSettle();

    expect(find.text('Export'), findsWidgets);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Foods'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Programmes'), findsOneWidget);
  });

  testWidgets('each row says what its bundle would actually hold', (
    tester,
  ) async {
    // §5: "one CSV per collection, in exactly the import schema … plus the
    // media those rows reference." Read off ContentSchema, so the claim cannot
    // drift from what the bundle contains: exercises name a clip, recipes name
    // a still, and foods and programmes name no media at all.
    _phone(tester);
    await tester.pumpWidget(_host(const ExportView()));
    await tester.pumpAndSettle();

    expect(find.text('What to export'), findsOneWidget);
    expect(find.text('CSV + videos'), findsOneWidget);
    expect(find.text('CSV + photos'), findsOneWidget);
    expect(
      find.text('CSV'),
      findsNWidgets(2),
      reason: 'foods and programmes reference no media',
    );
  });

  testWidgets('the media claim is derived, not typed per collection', (
    tester,
  ) async {
    // Asserted against the schema so that giving a collection a media column
    // fails here rather than leaving the screen quietly lying about it.
    expect(
      ContentSchema.of(ContentCollection.exercises).videoColumns,
      isNotEmpty,
    );
    expect(ContentSchema.of(ContentCollection.recipes).videoColumns, isEmpty);
    expect(
      ContentSchema.of(ContentCollection.recipes).mediaColumns,
      isNotEmpty,
    );
    expect(ContentSchema.of(ContentCollection.foods).mediaColumns, isEmpty);
    expect(
      ContentSchema.of(ContentCollection.programmes).mediaColumns,
      isEmpty,
    );
  });

  testWidgets('it states that no member data is ever included', (tester) async {
    // A real dictionary string, and the one promise this screen has to make on
    // its face rather than in its implementation.
    _phone(tester);
    await tester.pumpWidget(_host(const ExportView()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No member data is ever included: no meals or workouts, no photos, no cycle.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('nothing on this screen offers a member as a subject', (
    tester,
  ) async {
    // The screen may only ever list content collections. If a future "members"
    // or "logs" row appeared here, this fails.
    _phone(tester);
    await tester.pumpWidget(_host(const ExportView()));
    await tester.pumpAndSettle();

    for (final forbidden in [
      'Members',
      'Logs',
      'Cycle',
      'Progress',
      'Check-ins',
      'Measurements',
      'Photos',
    ]) {
      expect(
        find.text(forbidden),
        findsNothing,
        reason: '"$forbidden" is not a content collection',
      );
    }
  });

  testWidgets('a collection can be deselected, and the choice is carried', (
    tester,
  ) async {
    _phone(tester);
    Set<ContentCollection>? exported;

    await tester.pumpWidget(
      _host(ExportView(onExport: (chosen) => exported = chosen)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export the content library'));
    await tester.pumpAndSettle();

    expect(exported, {
      ContentCollection.exercises,
      ContentCollection.foods,
      ContentCollection.programmes,
    });
  });

  testWidgets('exporting nothing is not offered', (tester) async {
    _phone(tester);
    var exports = 0;

    await tester.pumpWidget(
      _host(ExportView(selected: const {}, onExport: (_) => exports++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Export the content library'));
    await tester.pumpAndSettle();

    expect(exports, 0);
  });

  testWidgets('it explains that an export re-imports', (tester) async {
    // §5's round trip, stated on the screen because it is the reason the export
    // is shaped the way it is.
    _phone(tester);
    await tester.pumpWidget(_host(const ExportView()));
    await tester.pumpAndSettle();

    expect(
      find.text('CSVs and media, in the same shape you import them.'),
      findsOneWidget,
    );
  });

  testWidgets('it mirrors in Arabic at the largest text size', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(const ExportView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(find.text('صدّري مكتبة المحتوى'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('it raises no dialog', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(const ExportView()));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });
}
