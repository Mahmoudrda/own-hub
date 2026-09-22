// C04 — Look around, and C05 — the join prompt raised over it.
//
// This is the only screen a woman sees before she has an account, so the thing
// most worth testing is the boundary: she can see a taste of the library, and
// the community stays behind the check. Every route onward leads to the same
// place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_segmented.dart';
import 'package:own_hub/ui/app_sheet.dart';

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
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  group('C04 — what a guest may see', () {
    testWidgets('a taste of the library, and the way in', (tester) async {
      await tester.pumpWidget(_host(const LookAroundView()));
      await tester.pumpAndSettle();

      expect(find.text('Look around'), findsOneWidget);
      expect(find.text('Quiet full body'), findsOneWidget);
      expect(find.text('Floor legs, no jumping'), findsOneWidget);
      expect(find.text('Workouts'), findsOneWidget);
    });

    testWidgets('the community is explicitly held back', (tester) async {
      // The product's central promise. If this card ever stops saying so, the
      // screen is quietly implying a guest can see other women.
      await tester.pumpWidget(_host(const LookAroundView()));
      await tester.pumpAndSettle();

      expect(
        find.text('Members and their posts are behind the check'),
        findsOneWidget,
      );
      expect(find.textContaining('verified women'), findsOneWidget);
    });

    testWidgets('switching tabs is hers to do', (tester) async {
      await tester.pumpWidget(_host(const LookAroundView()));
      await tester.pumpAndSettle();

      expect(
        tester.widget<AppSegmented>(find.byType(AppSegmented)).selectedIndex,
        0,
      );
      await tester.tap(find.text('Recipes'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AppSegmented>(find.byType(AppSegmented)).selectedIndex,
        1,
      );
    });

    testWidgets('previews come from data, not from the widget', (tester) async {
      // The real library does not exist yet; this must be swappable without
      // touching the screen.
      await tester.pumpWidget(
        _host(
          const LookAroundView(
            workouts: [
              PreviewWorkout(title: 'Morning mobility', detail: '8 min'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning mobility'), findsOneWidget);
      expect(find.text('Quiet full body'), findsNothing);
    });
  });

  group('C05 — the join prompt', () {
    testWidgets('tapping a workout asks, over the screen she was on', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const LookAroundView()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quiet full body'));
      await tester.pumpAndSettle();

      expect(find.text('Save this workout?'), findsOneWidget);
      // Still C04 underneath — it is a sheet, not a new page.
      expect(find.text('Look around'), findsOneWidget);
    });

    testWidgets('"Not now" returns her to browsing, not out of the app', (
      tester,
    ) async {
      var joined = 0;
      await tester.pumpWidget(_host(LookAroundView(onJoin: () => joined++)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quiet full body'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(find.text('Save this workout?'), findsNothing);
      expect(find.text('Look around'), findsOneWidget);
      expect(joined, 0);
    });

    testWidgets('every way in leads to the same place', (tester) async {
      var joined = 0;
      await tester.pumpWidget(_host(LookAroundView(onJoin: () => joined++)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join'));
      await tester.pumpAndSettle();
      expect(joined, 1, reason: 'the header button');

      await tester.tap(find.text('Join · about two minutes'));
      await tester.pumpAndSettle();
      expect(joined, 2, reason: 'the locked-community card');

      await tester.tap(find.text('Floor legs, no jumping'));
      await tester.pumpAndSettle();
      // Two "Join" labels exist now — the header button and the sheet's primary
      // action — and both are correct. Scoped to the sheet by structure rather
      // than picked by position, so this keeps working if either moves.
      await tester.tap(
        find.descendant(of: find.byType(AppSheet), matching: find.text('Join')),
      );
      await tester.pumpAndSettle();
      expect(joined, 3, reason: 'the sheet');
    });
  });

  testWidgets('holds up in Arabic at the largest text size', (tester) async {
    await tester.pumpWidget(
      _host(const LookAroundView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Look around'),
      findsNothing,
      reason: 'English here means a string bypassed the dictionary',
    );
    expect(tester.takeException(), isNull);
  });
}
