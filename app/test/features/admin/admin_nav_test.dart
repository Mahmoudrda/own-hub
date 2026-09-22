// The admin bottom bar — G16 §1: "its own bottom navigation: **Library ·
// Import · Media · Export**. Four tabs, matching the trainee and coach bars."
//
// `AppNavBar` normally reads its tab list from the woman's active role. There is
// no admin role in `AppRole`, and adding one would mean editing
// `lib/domain/identity/user_roles.dart`, which is not this feature's to change.
// The bar's own documentation names the way out: "Passing an explicit list is
// for tests and for the design gallery." That is what `adminTabs` is.
//
// Reported to the owner as the wiring decision it is, rather than taken
// silently.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/presentation/admin_nav.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Scaffold(bottomNavigationBar: child),
  );
}

void main() {
  test('four tabs, in the order §1 gives them', () {
    expect(adminTabs.map((t) => t.screenId), [
      'Z01',
      'Z08',
      'Z10',
      'Z11',
    ], reason: 'Library · Import · Media · Export');
  });

  test('every tab points at a screen this console actually builds', () {
    // A bar with a tab that opens nothing is worse than a bar with three tabs.
    for (final tab in adminTabs) {
      expect(tab.screenId, matches(RegExp(r'^Z\d{2}$')));
    }
  });

  testWidgets('each tab is labelled from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const AppNavBar(activeScreenId: 'Z01', destinations: adminTabs)),
    );
    await tester.pumpAndSettle();

    // The design's four words, all four of which now exist. `libraryLabel`
    // carries its suffix because `library` is a Dart keyword — that is the
    // generator avoiding a collision, not a different string.
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Media'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    // A tab is a word; the screen it opens is still called "Content library" in
    // its own app bar. The bar must not be carrying the longer name.
    expect(find.text('Content library'), findsNothing);
  });

  testWidgets('the active tab is not a link to itself', (tester) async {
    final tapped = <String>[];

    await tester.pumpWidget(
      _host(
        AppNavBar(
          activeScreenId: 'Z01',
          destinations: adminTabs,
          onSelect: tapped.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(tapped, isEmpty);

    await tester.tap(find.text('Media'));
    await tester.pumpAndSettle();
    expect(tapped, ['Z10']);
  });

  testWidgets('it reads in Arabic at the largest text size', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(
        const AppNavBar(activeScreenId: 'Z08', destinations: adminTabs),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المكتبة'), findsOneWidget);
    expect(find.text('استيراد'), findsOneWidget);
    expect(find.text('تصدير'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
