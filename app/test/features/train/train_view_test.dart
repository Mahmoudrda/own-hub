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
import 'package:own_hub/ui/app_week_segments.dart';

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

  testWidgets('opens on her programme, with the week drawn as marks', (
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

    // Her programme, or nothing. It read `programTitle ?? 'Postpartum
    // rebuild'`, and the `R01` builder passes no title, so Home said her
    // session was "Legs and glutes" and Train, one tap later, said her
    // programme was "Postpartum rebuild". Nobody asked her either question.
    expect(find.text('Postpartum rebuild'), findsNothing);
    expect(find.text('Week 2 of 6'), findsOneWidget);
    expect(
      find.text('Week 3 of 8'),
      findsNothing,
      reason: 'the mockup\'s week must never appear over hers',
    );
    expect(find.text('Continue · from Sara'), findsOneWidget);
    expect(find.text('See the whole program'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no tick for a session she has not logged', (tester) async {
    // "Mon ✓" was a dictionary constant drawn `selected: true` on every build,
    // so R01 told every woman she had trained on Monday, for ever, whatever
    // she had done. Which day she trained is not a fact this product holds:
    // §2 rule 3 is weeks not days, and `WeekRollup` keeps session ids with no
    // date on any of them. So the day chips are gone and the marks beside the
    // week count only what has been credited.
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    for (final chip in ['Mon ✓', 'Mon', 'Thu']) {
      expect(
        find.text(chip),
        findsNothing,
        reason: '"$chip" claims a day the app does not know',
      );
    }

    // The marks themselves: nothing logged, nothing ticked. The default was
    // `sessionsThisWeek = 2`, so a bare R01 drew two ticked sessions.
    final marks = tester.widget<AppWeekSegments>(find.byType(AppWeekSegments));
    expect(marks.filled, 0);
    expect(marks.total, 3);
    expect(find.text('0 of 3'), findsOneWidget);
  });

  testWidgets('and the marks count what she really logged', (tester) async {
    await tester.pumpWidget(
      _host(const TrainView(sessionsThisWeek: 2, sessionsPrescribed: 4)),
    );
    await tester.pumpAndSettle();

    final marks = tester.widget<AppWeekSegments>(find.byType(AppWeekSegments));
    expect(marks.filled, 2);
    expect(marks.total, 4);
    expect(find.text('2 of 4'), findsOneWidget);
  });

  testWidgets('the week block says what the marks count', (tester) async {
    // Withdrawing the invented "Week 3 of 8" left the corner of the card empty
    // and the marks alone on the row, which reads as a missing element rather
    // than a decision. "This week" is the heading Home already sets over the
    // same marks.
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    expect(find.text('This week'), findsOneWidget);

    // A programme that states its week replaces it; nothing invents one.
    await tester.pumpWidget(_host(const TrainView(programWeek: 'Week 2 of 6')));
    await tester.pumpAndSettle();

    expect(find.text('Week 2 of 6'), findsOneWidget);
    expect(find.text('This week'), findsNothing);
  });

  testWidgets('a programme she is really on is named', (tester) async {
    await tester.pumpWidget(
      _host(const TrainView(programTitle: 'Strong at home')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong at home'), findsOneWidget);
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
    var gentler = 0;
    var searched = 0;

    await tester.pumpWidget(
      _host(
        TrainView(
          onContinue: () => continued++,
          onSeeProgram: () => programme++,
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
    await tester.pumpAndSettle();

    // The gentler option is the last row of a scrolling body, under a bottom
    // nav bar, so on a short viewport it starts off-screen.
    await tester.ensureVisible(find.text('Not feeling it today?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Not feeling it today?'));
    await tester.pumpAndSettle();

    expect(continued, 1);
    expect(programme, 1);
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

    // No programme name in either language: the Arabic fallback was the same
    // invention as the English one.
    expect(find.text('برنامج ما بعد الولادة'), findsNothing);
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
