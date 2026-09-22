// P01 and P02 through the REAL router, against the real catalogue.
//
// # The blind spot this covers
//
// Every other progress test builds `ProgressView` or `MilestonesView` directly
// and hands it a summary it constructed itself. That proves the screens render
// what they are given and says nothing about what the router gives them — and
// the router gave them an EMPTY catalogue:
//
//     catalogue: MilestoneCatalogue.unauthored   // count == 0
//
// With an empty catalogue P01's milestone tile renders `null` (it withholds
// rather than say "2 of 0") and P02 lists nothing. Two hundred and forty-three
// tests passed in that state. The same shape of gap hid Y04's missing
// `onSaved`, which is why this mirrors `cycle_router_journey_test.dart`.
//
// # Why "0 of 8" is the right assertion
//
// `progress_view.dart` renders the tile's meta as
// `summary.milestoneCount <= 0 ? null : countOfTotal(earned, total)`. So the
// figure is present **only** when the router passes a real catalogue, and the
// total is the catalogue's own size. Revert the wiring and this goes red while
// every widget test stays green, which is exactly the property wanted.
//
// Eight, not twelve, is correct and deliberate: four of the twelve milestones
// the prototype shows are inferred rather than authored, and shipping an
// inferred milestone is the same defect as shipping an inferred tier ladder.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('P01 counts the milestones that actually exist', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app('P01'));
    await tester.pumpAndSettle();

    expect(
      find.text('0 of 8'),
      findsOneWidget,
      reason:
          'The router passed MilestoneCatalogue.unauthored, whose count is 0, '
          'so the tile withheld its figure entirely and P01 said nothing about '
          'milestones at all.',
    );
  });

  testWidgets('P02 lists the authored milestones', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_app('P02'));
    await tester.pumpAndSettle();

    // "Came back" is the eighth and the one P02 says it most wants her to
    // have. It exists as a row only because the catalogue is authored.
    expect(find.text('Came back'), findsOneWidget);
    expect(find.text('First session'), findsOneWidget);
  });

  testWidgets('P02 does not claim twelve while eight are authored', (
    tester,
  ) async {
    // The honest half, and the one worth guarding. P02's heading is checked
    // against the real catalogue size rather than printed, so it stays hidden
    // until the other four are written. A heading that claimed twelve over a
    // list of eight would be the same defect as "Level 7 · Regular".
    _phone(tester);
    await tester.pumpWidget(_app('P02'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Twelve in all. None are secret, and none are for filling in a profile.',
      ),
      findsNothing,
      reason: 'eight are authored; the heading may only appear when twelve are',
    );
  });

  testWidgets('P03 and P04 are reachable and render', (tester) async {
    // Both hang off P01 and neither had a route until this phase. A screen
    // that throws on open is not caught by a test that never opens it.
    for (final id in ['P03', 'P04']) {
      _phone(tester);
      await tester.pumpWidget(_app(id));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$id threw on open');
    }
  });
}
