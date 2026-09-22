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

    expect(find.text('15 minutes, 5 moves'), findsOneWidget);
    expect(find.text('Quiet · no equipment · floor'), findsOneWidget);
    expect(find.text('Glute bridge'), findsOneWidget);
    expect(find.text('3 × 12 · bodyweight'), findsOneWidget);
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.text('Hip thrust hold'), findsOneWidget);
    expect(find.text('3 × 30 seconds'), findsOneWidget);
    expect(find.text('Tap any move to watch it or swap it.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both ways in are on the same screen', (tester) async {
    // Most women train without the phone. "I already did it" is not a fallback,
    // it is the other half of the front door.
    await tester.pumpWidget(_host(const WorkoutDayView()));
    await tester.pumpAndSettle();

    expect(find.text("Start, everything's ready"), findsOneWidget);
    expect(find.text('I already did it'), findsOneWidget);
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

  testWidgets('"I already did it" leads away without starting one', (
    tester,
  ) async {
    final repository = InMemoryTrainRepository();
    var recalled = 0;

    await tester.pumpWidget(
      _host(
        WorkoutDayView(
          day: _day,
          repository: repository,
          onAlreadyDidIt: () => recalled++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('I already did it'));
    await tester.pumpAndSettle();

    expect(recalled, 1);
    expect(repository.flushes, isEmpty);
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

    expect(find.text('الساقان والأرداف'), findsOneWidget);
    expect(find.text('جسر الأرداف'), findsOneWidget);
    expect(find.text('ابدئي، كل شيء جاهز'), findsOneWidget);
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
}
