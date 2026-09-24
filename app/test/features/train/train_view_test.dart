// R01 — Train.
//
// The tab opens on the thing she is in the middle of. What is worth pinning here
// is the order: her programme first, short sessions above the library, and the
// gentler option offered rather than hidden.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/train/presentation/train_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

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
  // "Continue · from Sara" credits a coach, so this file is about the build
  // that has coaching. Without it the button reads "Continue".
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.coachedLife: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('opens on her programme, with the week she can tap', (
    tester,
  ) async {
    // Week 2 of 6, not the mockup's 3 of 8.
    //
    // This asserted 'Week 3 of 8' while constructing `TrainView()` with no
    // week at all — so it passed against `programWeek ?? l10n.week3Of8`, a
    // fallback whose only job was to state the prototype's week when the real
    // one was unknown. A fixture equal to the mockup's own number cannot tell a
    // value from a constant, which is exactly why this went unnoticed.
    await tester.pumpWidget(_host(const TrainView(programWeek: 'Week 2 of 6')));
    await tester.pumpAndSettle();

    expect(find.text('Postpartum rebuild'), findsOneWidget);
    expect(find.text('Week 2 of 6'), findsOneWidget);
    expect(
      find.text('Week 3 of 8'),
      findsNothing,
      reason: 'the mockup\'s week must never appear over hers',
    );
    expect(find.text('Continue · from Sara'), findsOneWidget);
    expect(find.text('See the whole program'), findsOneWidget);
    // The week, as three chips.
    expect(find.text('Mon ✓'), findsOneWidget);
    expect(find.text('Thu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('short sessions sit above the library', (tester) async {
    // A ten-minute floor session is what gets done on a bad day, and it counts
    // the same. If it ever falls below the library this ordering is broken.
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    final shortHeading = tester.getTopLeft(
      find.text('Short ones that still count'),
    );
    final libraryHeading = tester.getTopLeft(find.text('All workouts'));
    expect(shortHeading.dy, lessThan(libraryHeading.dy));

    expect(find.text('Floor only'), findsOneWidget);
    expect(find.text('Dumbbells'), findsOneWidget);
    // '124 videos' is gone: `WorkoutVideoRepository` states that the 124
    // titles do not exist yet, so the count sat above tiles that all draw the
    // unreleased placeholder.
    expect(find.text('124 videos'), findsNothing);
  });

  testWidgets('the gentler option is offered, not buried', (tester) async {
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    expect(find.text('Not feeling it today?'), findsOneWidget);
    expect(
      find.text('See a gentler option based on your check-in'),
      findsOneWidget,
    );
  });

  testWidgets('short sessions come from data, not from the widget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const TrainView(
          shortSessions: [
            ShortSession(duration: '8 min', constraint: 'Before work'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('8 min'), findsOneWidget);
    expect(find.text('Floor only'), findsNothing);
  });

  testWidgets('every way onward fires its own callback', (tester) async {
    var continued = 0;
    var programme = 0;
    var today = 0;
    var gentler = 0;
    var searched = 0;

    await tester.pumpWidget(
      _host(
        TrainView(
          onContinue: () => continued++,
          onSeeProgram: () => programme++,
          onOpenToday: () => today++,
          onGentlerOption: () => gentler++,
          onSearch: () => searched++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Everything above the fold first: scrolling for the last row would move
    // these out from under the finger.
    await tester.tap(find.byIcon(Icons.search));
    await tester.tap(find.text('Continue · from Sara'));
    await tester.tap(find.text('See the whole program'));
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();

    // The gentler option is the last row of a scrolling body, under a bottom
    // nav bar, so on a short viewport it starts off-screen.
    await tester.ensureVisible(find.text('Not feeling it today?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not feeling it today?'));
    await tester.pumpAndSettle();

    expect(continued, 1);
    expect(programme, 1);
    expect(today, 1);
    expect(gentler, 1);
    expect(searched, 1);
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TrainView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('برنامج ما بعد الولادة'), findsOneWidget);
    expect(find.text('متابعة · من سارة'), findsOneWidget);
    expect(find.text('لا تشعرين بالرغبة اليوم؟'), findsOneWidget);
    // English still on screen would mean a string bypassed the dictionary.
    expect(find.text('Postpartum rebuild'), findsNothing);
    expect(find.text('Train'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const TrainView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'an overflow here hides the programme she came to continue',
    );
  });
}
