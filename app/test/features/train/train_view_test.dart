// R01 — Train.
//
// One purpose: pick or start a workout. Today's card with the one Start, a row
// for the plan (R02 holds its tiers and every way to change it), a row for her
// own workouts, and Explore behind a search box and one Filters button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/train/presentation/train_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
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
      // Train and the parts this screen opens onto.
      Feature.train: true,
      Feature.workoutLibrary: true,
      Feature.exerciseLibrary: true,
      Feature.exerciseSwap: true,
      Feature.followAlong: true,
      Feature.program: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('opens on today, with her plan and her workouts one row each', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(TrainView(onSeeProgram: () {}, onBuildOwn: () {})),
    );
    await tester.pumpAndSettle();

    // Her programme, or nothing. It read `programTitle ?? 'Postpartum
    // rebuild'`, and the `R01` builder passes no title, so Home said her
    // session was "Legs and glutes" and Train, one tap later, said her
    // programme was "Postpartum rebuild". Nobody asked her either question.
    expect(find.text('Postpartum rebuild'), findsNothing);
    expect(find.text('Week 3 of 8'), findsNothing);
    expect(find.text('Continue · from Sara'), findsOneWidget);
    expect(find.text('Your plan'), findsOneWidget);
    expect(find.text('My workouts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('what moved to the plan page is gone from Train', (tester) async {
    await tester.pumpWidget(
      _host(TrainView(onSeeProgram: () {}, onBuildOwn: () {})),
    );
    await tester.pumpAndSettle();

    for (final gone in [
      'See the whole program',
      'Switch plan or pick any session',
      'Build my own plan',
      'This week',
      'Short ones that still count',
      'Your muscles',
      'Find a coach',
      'Not feeling it today?',
      'Beginner',
    ]) {
      expect(find.text(gone), findsNothing, reason: gone);
    }
  });

  testWidgets('no tick for a session she has not logged', (tester) async {
    // "Mon ✓" was a dictionary constant drawn `selected: true` on every build,
    // so R01 told every woman she had trained on Monday, for ever, whatever
    // she had done. Which day she trained is not a fact this product holds.
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    for (final chip in ['Mon ✓', 'Mon', 'Thu']) {
      expect(
        find.text(chip),
        findsNothing,
        reason: '"$chip" claims a day the app does not know',
      );
    }
  });

  testWidgets('a programme she is really on is named under Your plan', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(TrainView(onSeeProgram: () {}, programTitle: 'Strong at home')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Strong at home'), findsOneWidget);
  });

  testWidgets('the header has a caption', (tester) async {
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    expect(find.text('Ready when you are.'), findsOneWidget);
  });

  testWidgets('Explore has the search and one Filters button, nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('r01-filters')), findsOneWidget);
    expect(find.byKey(const ValueKey('r01-chip-0')), findsNothing);
    expect(find.byKey(const ValueKey('r01-explore-chips')), findsNothing);
  });

  testWidgets('gentler is a filter now, not a row', (tester) async {
    await tester.pumpWidget(_host(const TrainView()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('r01-filters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r01-gentler')), findsOneWidget);
    expect(find.text('Gentler'), findsOneWidget);
  });

  testWidgets('every way onward fires its own callback', (tester) async {
    var continued = 0;
    var programme = 0;

    await tester.pumpWidget(
      _host(
        TrainView(
          onContinue: () => continued++,
          onSeeProgram: () => programme++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue · from Sara'));
    await tester.tap(find.text('Your plan'));
    await tester.pumpAndSettle();

    expect(continued, 1);
    expect(programme, 1);
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TrainView(onSeeProgram: () {}, onBuildOwn: () {}),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    // No programme name in either language: the Arabic fallback was the same
    // invention as the English one.
    expect(find.text('برنامج ما بعد الولادة'), findsNothing);
    expect(find.text('كمّلي · من سارة'), findsOneWidget);
    expect(find.text('خطتك'), findsOneWidget);
    // English still on screen would mean a string bypassed the dictionary.
    expect(find.text('Postpartum rebuild'), findsNothing);
    expect(find.text('Train'), findsNothing);
    expect(find.text('Your plan'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        TrainView(onSeeProgram: () {}, onBuildOwn: () {}),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason: 'an overflow here hides the programme she came to continue',
    );
  });
}
