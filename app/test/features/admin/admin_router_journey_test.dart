// The admin console through the REAL router, against the real seeded library.
//
// # The blind spot this covers
//
// Every other admin test builds `CollectionView` or `ContentFormView` directly
// and hands it rows it constructed itself. That proves the screens render what
// they are given, and says nothing about what the router gives them.
//
// The router gave them no way to open a row. `CollectionView` has exposed an
// `onOpenRow` callback since it was built — it fires on every row tap — and
// **not one route builder passed it**. So `AppRouter.adminEditingRow` was only
// ever read or cleared, never populated; `ContentFormView._isEditing` is
// `values.isNotEmpty`, so it could never be true; and "Edit a food" was a
// string the running app had no path to.
//
// 331 admin tests passed in that state. The console could add a row and import
// a CSV, and could not open the row it had just saved.
//
// This is the same shape of gap as P01's empty catalogue and Y04's missing
// `onSaved`, which is why it mirrors `progress_router_journey_test.dart`.
//
// # Why the title is the right assertion
//
// `ContentFormView._title` returns the "Edit …" phrase only when `widget.values`
// is non-empty, and that map reaches it from `AppRouter.adminRowValues` through
// `onOpenRow`. Unwire the callback and every one of these goes red while the
// widget tests stay green — which is exactly the property wanted.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _app(String screenId) {
  return MaterialApp(
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(const Locale('en')),
    onGenerateRoute: AppRouter.onGenerateRoute,
    onUnknownRoute: AppRouter.onUnknownRoute,
    initialRoute: appRoutes[screenId]!.name,
  );
}

/// The English name of the first stored row, read from the same repository the
/// router hands the screen — so this follows the seed rather than pinning a
/// dish name a content update would break.
String _firstName(ContentCollection collection) {
  final rows = AppRouter.contentRepository.rowsNow(collection);
  expect(
    rows,
    isNotEmpty,
    reason:
        'the library ships seeded, so every collection has rows before anyone '
        'imports anything. An empty collection here means the seed is no '
        'longer wired into AppRouter.contentRepository.',
  );
  return rows.first.value('name_en');
}

Future<void> _openFirstRow(WidgetTester tester, ContentCollection c) async {
  final name = _firstName(c);
  final finder = find.text(name);
  await tester.scrollUntilVisible(
    finder.first,
    120,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  // `AppRouter.adminEditingRow` is static, so it survives between tests in this
  // file exactly as it survives between screens in the running app. Resetting
  // it here keeps each test independent; the PRODUCT fix for the same hazard is
  // that `onAdd` clears it, which the negative control below proves.
  final savedFlags = AppRouter.featureFlags;
  setUp(() {
    AppRouter.adminEditingRow = const <String, String>{};
    // The console is off in the first release and compiled out of a release
    // build, so this file turns it on rather than inheriting a default it no
    // longer has. What is being tested is the console, not the flag.
    AppRouter.featureFlags = FeatureFlags.everything;
  });
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('the library the router hands the console is the seeded one', () {
    testWidgets('Z04 lists stored foods rather than an empty collection', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app('Z04'));
      await tester.pumpAndSettle();

      // "Nothing yet" is the empty state. Its absence is the assertion: the
      // console reads a stocked library at startup, not one staff must fill
      // before the screens show anything at all.
      expect(find.text(_firstName(ContentCollection.foods)), findsWidgets);
    });
  });

  group('a stored row can be opened, which is what makes the form an edit', () {
    testWidgets('Z04 -> tap a food -> the form opens as an EDIT', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app('Z04'));
      await tester.pumpAndSettle();

      await _openFirstRow(tester, ContentCollection.foods);

      expect(
        find.text('Edit a food'),
        findsOneWidget,
        reason:
            'the router passed the row values through onOpenRow, so _isEditing '
            'is true. With onOpenRow unwired the tap does nothing at all and '
            'the list is still on screen.',
      );
    });

    testWidgets('Z06 -> tap a recipe -> Z12 opens as an EDIT', (tester) async {
      // D18. Recipes had no form to open at all until Z12 existed, and no way
      // in until Z06 carried onAdd and onOpenRow.
      _phone(tester);
      await tester.pumpWidget(_app('Z06'));
      await tester.pumpAndSettle();

      await _openFirstRow(tester, ContentCollection.recipes);

      expect(find.text('Edit a recipe'), findsOneWidget);
    });

    testWidgets('Z07 -> tap a programme -> Z13 opens as an EDIT', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app('Z07'));
      await tester.pumpAndSettle();

      await _openFirstRow(tester, ContentCollection.programmes);

      expect(find.text('Edit a programme'), findsOneWidget);
    });
  });

  group('adding and editing are different journeys', () {
    testWidgets('the NEGATIVE CONTROL — Add opens a blank form, not an edit', (
      tester,
    ) async {
      // Without this, the edit assertions above could be passing over a form
      // that says "Edit" no matter how it was opened.
      _phone(tester);
      await tester.pumpWidget(_app('Z04'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('Add a food'), findsOneWidget);
      expect(
        find.text('Edit a food'),
        findsNothing,
        reason: 'an empty values map must not read as editing something',
      );
    });

    testWidgets('Add starts blank even after a form was left WITHOUT closing', (
      tester,
    ) async {
      // The real hazard, and the one the `setUp` above deliberately does not
      // cover for. `adminEditingRow` is shared module state cleared by the
      // form's own close button — so leaving by the admin nav bar, or by the
      // Android system back gesture, leaves it populated.
      //
      // This test never presses close. It opens a row, walks away the way the
      // nav bar does, and then taps Add. Revert `onAdd`'s clearing line and
      // this goes red with "Edit a food" on a form that is adding a new one.
      _phone(tester);
      await tester.pumpWidget(_app('Z04'));
      await tester.pumpAndSettle();

      await _openFirstRow(tester, ContentCollection.foods);
      expect(find.text('Edit a food'), findsOneWidget);

      // Away, without closing. The Android system back gesture pops the route
      // without ever calling the form's `onClose`, so the static survives
      // exactly as it does in the running app. (Pumping a second MaterialApp
      // would NOT do this: Flutter updates the existing element tree and the
      // Navigator keeps its history, so the form stays on screen.)
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        AppRouter.adminEditingRow,
        isNotEmpty,
        reason:
            'precondition: the row really did survive being walked away from, '
            'otherwise this test proves nothing about onAdd',
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(
        find.text('Add a food'),
        findsOneWidget,
        reason:
            'onAdd clears adminEditingRow, so a row left open by another route '
            'cannot pre-fill the next add with someone else values',
      );
      expect(find.text('Edit a food'), findsNothing);
    });
  });
}
