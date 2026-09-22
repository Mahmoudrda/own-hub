// The journey through the REAL router: Y04 → Y03, heavy bleeding → suppressed.
//
// # Why this exists
//
// Every other cycle test builds a widget directly and hands it a `checkIn:`.
// That proves the widgets are right and says nothing about whether anything
// gives them her day. It did not — and the gap was invisible precisely because
// the widget tests were so thorough:
//
//   * `Y04` was built as `CheckInView(onCancel: ...)` with **no `onSaved`**, so
//     "Save check-in" called nothing. She could log heavy bleeding and the sheet
//     closed having told no one.
//   * `Y03` was built with `cycle:` only — no `checkIn:` — so the hub always saw
//     `TodayCheckIn.absent`. The severe branch was unreachable in the app
//     however she logged, while 139 tests passed.
//
// So this drives `AppRouter.onGenerateRoute` rather than a constructor. If the
// wiring is removed, the widget tests stay green and these go red.
//
// # The static
//
// `AppRouter.todayCheckIn` is mutable process state standing in for G3's
// `checkins/{yyyy-MM-dd}` document. It is reset before AND after every test
// here: a leaked check-in would silently change what later tests render, which
// is a worse defect than the one being guarded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// The real router, with the localisation delegates a real screen needs.
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

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppRouter.todayCheckIn = TodayCheckIn.absent;
  });

  tearDown(() async {
    AppRouter.todayCheckIn = TodayCheckIn.absent;
    // She set the feature up inside a test; the next one starts as a woman who
    // never has.
    await AppRouter.cycleRepository.purge();
  });

  testWidgets('what she logs on Y04 leaves the sheet', (tester) async {
    // `onSaved` was passed by nobody. This is the assertion that would have
    // caught it: not "the sheet closed", but "something received what she
    // logged".
    _phone(tester);
    await tester.pumpWidget(_app('Y04'));
    await tester.pumpAndSettle();

    await _tap(tester, find.text('More to log: sleep, bloating, bleeding'));
    await _tap(tester, find.text('Heavy'));
    await _tap(tester, find.text('Save check-in'));

    expect(
      AppRouter.todayCheckIn.bleeding,
      Bleeding.heavy,
      reason:
          'Y04 had no onSaved, so saving told nobody and the severe branch '
          'could never be reached from the running app',
    );
    expect(
      AppRouter.todayCheckIn.cramps,
      isNull,
      reason: 'nothing but the bleeding row was touched',
    );
  });

  testWidgets('Y03 receives it, and heavy bleeding removes the workout', (
    tester,
  ) async {
    // P0-CYC-06, reached the way she reaches it: through the router, from what
    // Y04 stored, rather than from a `checkIn:` handed to a constructor.
    await AppRouter.cycleRepository.completeSetup(
      mode: CycleMode.datesAndSymptoms,
    );
    AppRouter.todayCheckIn = const TodayCheckIn(
      energy: Energy.high,
      cramps: Cramps.none,
      bleeding: Bleeding.heavy,
    );

    _phone(tester);
    await tester.pumpWidget(_app('Y03'));
    await tester.pumpAndSettle();

    expect(find.text('This needs more than a workout change'), findsOneWidget);
    expect(find.text('Find care near you'), findsOneWidget);
    expect(find.text('Rest today'), findsOneWidget);

    for (final forbidden in [
      'A gentler option today',
      'View option',
      'Keep mine',
      'Your planned workout',
      'Start workout',
      'Lentil soup and toast',
    ]) {
      expect(
        find.text(forbidden),
        findsNothing,
        reason: '§2.5: heavy bleeding REMOVES the workout. Found "$forbidden"',
      );
    }
  });

  testWidgets('with nothing logged, Y03 is an ordinary day', (tester) async {
    // The negative control. Without it, the test above would pass just as well
    // against a hub that showed the severe branch to everybody — which is a
    // worse product than the one that showed it to nobody.
    await AppRouter.cycleRepository.completeSetup(
      mode: CycleMode.datesAndSymptoms,
    );

    _phone(tester);
    await tester.pumpWidget(_app('Y03'));
    await tester.pumpAndSettle();

    expect(find.text('This needs more than a workout change'), findsNothing);
    expect(find.text('Find care near you'), findsNothing);
  });

  testWidgets('a woman who never set up still gets the invitation', (
    tester,
  ) async {
    // The branch that rendered `SizedBox.shrink()` — a title bar, a settings
    // gear and nothing between them — for anyone arriving from My profile.
    _phone(tester);
    await tester.pumpWidget(_app('Y03'));
    await tester.pumpAndSettle();

    expect(find.text('Make it work for you'), findsOneWidget);
    expect(find.text('Track periods and symptoms'), findsOneWidget);
  });
}
