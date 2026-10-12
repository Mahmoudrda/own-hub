// Z01 — Content library, the landing tab.
//
// The screen's whole argument, from its design note: it "leads with how many
// rows lack a mandatory safety tag rather than how many rows exist. An
// incomplete library is the failure mode that matters, and a total hides it — a
// food with no allergens value is not a smaller library, it is a guard that
// fails closed on every woman."
//
// So the assertions here are about *what leads*, not merely what renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/presentation/content_library_view.dart';
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
  testWidgets('it names the four collections this console maintains', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(const ContentLibraryView()));
    await tester.pumpAndSettle();

    expect(find.text('Content library'), findsWidgets);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Foods'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Programmes'), findsOneWidget);
  });

  testWidgets('it says on its face that none of this is a member\'s data', (
    tester,
  ) async {
    // D12: "**An admin is staff, not a member.** The console manages the
    // *content library*. It is not a window into anyone's account." The guard
    // over this feature's source keeps it true; this is where it is said out
    // loud, because Z01 is the screen a "look up a member" box would be added
    // to first.
    _phone(tester);
    await tester.pumpWidget(_host(const ContentLibraryView()));
    await tester.pumpAndSettle();

    expect(
      find.text(
        "Nothing here is a member's data. This console manages the library "
        'only.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the promise is made in Arabic too', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentLibraryView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('مفيش هنا أي بيانات لعضوة. اللوحة دي بتدير المكتبة بس.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty library states no counts it does not have', (
    tester,
  ) async {
    // The real state of this product today: nothing is authored. The screen
    // must not imply otherwise, and must not invent an encouraging number.
    _phone(tester);
    await tester.pumpWidget(_host(const ContentLibraryView()));
    await tester.pumpAndSettle();

    expect(find.text('Missing a safety tag'), findsNothing);
  });

  testWidgets('a collection missing safety tags says so, and counts them', (
    tester,
  ) async {
    // The design's line: "{count} rows · {missing} missing a safety tag". The
    // size is stated, and the alarm is stated beside it — a total on its own
    // hides exactly the failure this screen exists to surface.
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentLibraryView(
          status: {
            ContentCollection.foods: CollectionStatus(
              rows: 118,
              missingASafetyTag: 4,
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('118 rows · Missing a safety tag'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('a fully tagged collection states its size and nothing else', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentLibraryView(
          status: {
            ContentCollection.foods: CollectionStatus(
              rows: 118,
              missingASafetyTag: 0,
            ),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('118 rows'), findsOneWidget);
    expect(find.textContaining('Missing a safety tag'), findsNothing);
  });

  testWidgets('an unknown collection claims no count at all', (tester) async {
    // Absent and zero are different claims. Every collection is absent today,
    // and "0 rows" would be an assertion this screen cannot support.
    _phone(tester);
    await tester.pumpWidget(_host(const ContentLibraryView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('rows'), findsNothing);
  });

  testWidgets('the row count is Western digits and comma-grouped under ar', (
    tester,
  ) async {
    // P0-A11Y-01 again, on a number large enough to need a separator —
    // `countLabel`, never NumberFormat.
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentLibraryView(
          status: {
            ContentCollection.foods: CollectionStatus(
              rows: 4100,
              missingASafetyTag: 0,
            ),
          },
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('4,100 صف'), findsOneWidget);
  });

  testWidgets('each collection opens its own list', (tester) async {
    _phone(tester);
    final opened = <ContentCollection>[];

    await tester.pumpWidget(
      _host(ContentLibraryView(onOpenCollection: opened.add)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();

    expect(opened, [ContentCollection.recipes]);
  });

  testWidgets('bulk import is one tap from the landing tab', (tester) async {
    // §intro: adding 124 exercise videos and an Egyptian food library one form
    // at a time is not a feature. The import is the primary action here.
    _phone(tester);
    var imported = 0;

    await tester.pumpWidget(
      _host(ContentLibraryView(onImport: () => imported++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulk import'));
    await tester.pumpAndSettle();

    expect(imported, 1);
  });

  testWidgets('counts are Western digits under ar', (tester) async {
    // P0-A11Y-01. `countLabel`, never NumberFormat — under an Arabic locale
    // intl would render "١٢٤" and the accessibility case fails.
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentLibraryView(
          status: {
            ContentCollection.exercises: CollectionStatus(
              rows: 124,
              missingASafetyTag: 124,
            ),
          },
        ),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('124'), findsOneWidget);
    expect(find.text('١٢٤'), findsNothing);
  });

  testWidgets('it mirrors in Arabic and survives the largest text size', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        const ContentLibraryView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مكتبة المحتوى'), findsWidgets);
    expect(
      Directionality.of(tester.element(find.text('الحركات'))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('it raises no dialog', (tester) async {
    // Rule 9 is guarded over the source tree as well; this is the rendered
    // proof for the screen a future "are you sure?" would most likely land on.
    _phone(tester);
    await tester.pumpWidget(_host(const ContentLibraryView()));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
