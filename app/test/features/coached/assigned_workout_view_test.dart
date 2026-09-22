// G06, G07 and G08 as screens — the player, wearing her coach's numbers.
//
// The assertions that matter are all about what is NOT shown: an unlogged set
// says "Not yet" rather than repeating the prescription, the rest screen claims the
// seconds are her coach's only when they are, and the swap sheet offers the
// approved options above the one that costs a wait.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/presentation/assigned_workout_view.dart';
import 'package:own_hub/features/coached/presentation/rest_between_sets_view.dart';
import 'package:own_hub/features/coached/presentation/swap_exercise_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

void main() {
  group('G06 — prescribed and actual, side by side', () {
    testWidgets('an unlogged set says so, never the prescription', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AssignedWorkoutView(
            sets: [
              SetLine(
                label: 'Set 1',
                prescribed: '17.5 kg × 9',
                actual: '17.5 kg × 9',
              ),
              SetLine(label: 'Set 2', prescribed: '17.5 kg × 9', current: true),
              SetLine(label: 'Set 3', prescribed: '17.5 kg × 9'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Three prescriptions…
      expect(find.text('17.5 kg × 9'), findsNWidgets(4));
      // …and two sets with nothing in the "you did" column.
      expect(find.text('Not yet'), findsNWidgets(2));
      expect(find.text('prescribed'), findsNWidgets(3));
      expect(find.text('you did'), findsNWidgets(3));
    });

    testWidgets('her note is shown, and labelled as hers', (tester) async {
      await tester.pumpWidget(
        _host(
          const AssignedWorkoutView(
            coachNote: 'Keep 17.5 and stop at 7 if the knee talks.',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Her note'), findsOneWidget);
      expect(find.text('From Coach Sara'), findsOneWidget);
      expect(
        find.text('Keep 17.5 and stop at 7 if the knee talks.'),
        findsOneWidget,
      );
    });

    testWidgets('skip is available without asking anyone', (tester) async {
      var skipped = 0;
      await tester.pumpWidget(
        _host(AssignedWorkoutView(onSkip: () => skipped++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(skipped, 1);
    });

    testWidgets('no confirmation dialog appears when a set is completed', (
      tester,
    ) async {
      var completed = 0;
      await tester.pumpWidget(
        _host(AssignedWorkoutView(onCompleteSet: () => completed++)),
      );
      await tester.pumpAndSettle();

      // The button used to say "Complete set 2" from the dictionary even when
      // the screen had been given no sets at all. With no session there is no
      // set two, so it names the action instead.
      await tester.tap(find.text('Log one set'));
      await tester.pumpAndSettle();

      expect(completed, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Are you sure?'), findsNothing);
    });
  });

  group('G07 — the rest timer is the coach\'s', () {
    testWidgets('it runs her seconds and says so', (tester) async {
      await tester.pumpWidget(
        _host(const RestBetweenSetsView(restSeconds: 75, autoStart: false)),
      );
      await tester.pumpAndSettle();

      expect(find.text('1:15'), findsOneWidget);
      // The dictionary line used here said "Sara set 45 seconds between these
      // sets." while the clock counted seventy-five — the mockup's figure,
      // read back to a woman resting to a different one. The attribution
      // stays; the number it invented does not.
      expect(find.text('From Coach Sara'), findsOneWidget);
    });

    testWidgets('with no coach seconds, it claims nothing about her', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const RestBetweenSetsView(autoStart: false)),
      );
      await tester.pumpAndSettle();

      // The clock still runs on the product's own default…
      expect(find.text('1:00'), findsOneWidget);
      // …but the app does not attribute those seconds to a woman who never
      // chose them.
      expect(find.text('From Coach Sara'), findsNothing);
    });

    testWidgets('the clock counts down and ends itself', (tester) async {
      var ready = 0;
      await tester.pumpWidget(
        _host(RestBetweenSetsView(restSeconds: 3, onReady: () => ready++)),
      );
      await tester.pump();
      expect(find.text('0:03'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:00'), findsOneWidget);
      expect(ready, 1, reason: 'zero taps required');
    });

    testWidgets('finishing early is on the screen, next to the timer', (
      tester,
    ) async {
      var finished = 0;
      await tester.pumpWidget(
        _host(
          RestBetweenSetsView(
            autoStart: false,
            onFinishWorkout: () => finished++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finish workout'));
      await tester.pumpAndSettle();

      expect(finished, 1, reason: 'an assigned session is still hers to stop');
      // And nothing asked her to justify it.
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('G08 — approved first, ask second', () {
    testWidgets('the approved options come before the one that costs a wait', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const SwapExerciseView()));
      await tester.pumpAndSettle();

      final approved = tester.getTopLeft(find.text('Box squat to a chair')).dy;
      final ask = tester
          .getTopLeft(find.text('Ask Sara for something else'))
          .dy;
      final skip = tester.getTopLeft(find.text('Skip this exercise')).dy;

      expect(approved, lessThan(ask));
      expect(ask, lessThan(skip));
      expect(
        find.text(
          'Sara approved these in advance, so you do not have to wait for a reply.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('choosing an approved option reports that option', (
      tester,
    ) async {
      SwapOption? chosen;
      await tester.pumpWidget(
        _host(SwapExerciseView(onChoose: (o) => chosen = o)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Glute bridge'));
      await tester.pumpAndSettle();

      expect(chosen?.exerciseId, 'glute_bridge');
    });

    testWidgets('a coach who approved nothing shows no options', (
      tester,
    ) async {
      // An empty list is not the same as null. A coach who approved nothing
      // must not appear to have approved something.
      await tester.pumpWidget(
        _host(const SwapExerciseView(options: <SwapOption>[])),
      );
      await tester.pumpAndSettle();

      expect(find.text('Box squat to a chair'), findsNothing);
      expect(find.text('Ask Sara for something else'), findsOneWidget);
      expect(find.text('Skip this exercise'), findsOneWidget);
    });
  });

  testWidgets('the player renders in Arabic', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _host(const AssignedWorkoutView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
