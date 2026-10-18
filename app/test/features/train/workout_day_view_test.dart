// R03 — Workout day.
//
// Implements the G4 half of P0-ONB-03 and P1-RULE-01: the day renders the
// prescription, and starting a session creates it with nothing logged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
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

const _day = WorkoutDay(
  id: '2026-09-15',
  title: 'Legs and glutes',
  summary: '15 minutes, 5 moves',
  constraints: 'Quiet · no equipment · floor',
  moves: [
    PlannedMove(
      exerciseId: 'goblet_squat',
      name: 'Goblet squat',
      prescriptionLabel: '3 × 10 · 12 kg suggested',
      sets: [
        PrescribedSet(
          exerciseId: 'goblet_squat',
          order: 1,
          weightKg: 12,
          reps: 10,
        ),
        PrescribedSet(
          exerciseId: 'goblet_squat',
          order: 2,
          weightKg: 12,
          reps: 10,
        ),
      ],
    ),
  ],
);

void main() {
  testWidgets('the day is a list of moves with their prescriptions', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WorkoutDayView()));
    await tester.pumpAndSettle();

    // Counted off the day's own moves, so the line and the list under it
    // cannot disagree. It was the fixed '15 minutes, 5 moves'.
    expect(find.text('15 minutes, 4 moves'), findsOneWidget);
    expect(find.text('Quiet · no equipment · floor'), findsOneWidget);
    expect(find.text('Donkey kick'), findsOneWidget);
    expect(find.text('3 × 12 · bodyweight'), findsOneWidget);
    // The goblet squat is gone, and with it the 12 kg dumbbell this screen
    // prescribed two lines under its own "no equipment" promise, to a woman
    // the app had never asked whether she owns one. See `sampleWorkoutDay`.
    expect(find.text('Goblet squat'), findsNothing);
    expect(find.textContaining('12 kg'), findsNothing);
    expect(find.text('Forearm plank'), findsOneWidget);
    expect(find.text('3 × 30 seconds'), findsOneWidget);
    expect(find.text('Tap any move to watch it or swap it.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one way in: Start. Recalling a session lives on Home', (
    tester,
  ) async {
    // R03 carries a single primary action. "I already did it" (T02) is offered
    // on Home, so the day's screen asks for one decision.
    await tester.pumpWidget(_host(const WorkoutDayView()));
    await tester.pumpAndSettle();

    expect(find.text("Start, everything's ready"), findsOneWidget);
    expect(find.text('I already did it'), findsNothing);
  });

  testWidgets(
    'the week\'s challenge sits on the move it is about, only there',
    (tester) async {
      const note = "Goblet squat: more than last week's 24 reps";
      await tester.pumpWidget(
        _host(
          const WorkoutDayView(
            day: _day,
            challengeExerciseId: 'goblet_squat',
            challengeNote: note,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Under the move's prescription, in the same row.
      expect(find.textContaining(note), findsOneWidget);

      await tester.pumpWidget(
        _host(
          const WorkoutDayView(
            day: _day,
            challengeExerciseId: 'dead_bug',
            challengeNote: note,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining(note),
        findsNothing,
        reason: 'not a move in this day',
      );
    },
  );

  testWidgets('"More" is drawn only when it does something', (tester) async {
    await tester.pumpWidget(_host(const WorkoutDayView()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('More'), findsNothing);

    var opened = 0;
    await tester.pumpWidget(_host(WorkoutDayView(onMore: () => opened++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    expect(opened, 1);
  });

  testWidgets('starting creates the session, then moves on', (tester) async {
    final repository = InMemoryTrainRepository();
    var started = 0;

    await tester.pumpWidget(
      _host(
        WorkoutDayView(
          day: _day,
          repository: repository,
          onStart: () => started++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("Start, everything's ready"));
    await tester.pumpAndSettle();

    expect(started, 1);
  });

  testWidgets('"I already did it" lives on Home, not here', (tester) async {
    await tester.pumpWidget(
      _host(WorkoutDayView(day: _day, repository: InMemoryTrainRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('I already did it'), findsNothing);
  });

  test('P1-RULE-01 — a session is born with every outcome empty', () async {
    // The failure this guards against is helpful pre-filling: a plan that says
    // 12 kg × 10 must not become a record that she lifted 12 kg × 10.
    final repository = InMemoryTrainRepository();
    final session = await repository.startSession(_day);

    expect(session.sets, hasLength(2));
    expect(session.sets.every((s) => s.outcome == null), isTrue);
    expect(session.loggedSetCount, 0);
    expect(session.source, SessionSource.live);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const WorkoutDayView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('الرجلين والأرداف'), findsOneWidget);
    expect(find.text('دونكي كيك'), findsOneWidget);
    expect(find.text('ابدئي، كل حاجة جاهزة'), findsOneWidget);
    expect(find.text('I already did it'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const WorkoutDayView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('G01: with a caller, Start starts nothing of its own', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    var started = 0;
    await tester.pumpWidget(
      _host(WorkoutDayView(repository: repository, onStart: () => started++)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text("Start, everything's ready").first);
    await tester.pumpAndSettle();
    expect(started, 1);
    expect(repository.liveSessionId, isNull, reason: 'one session, the caller');
  });
}
