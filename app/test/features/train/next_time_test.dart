// R03 looks ahead: for up to three loaded moves she weighed, what to lift
// today. A step up when the sets were done, the same weight when not,
// nothing for bodyweight, nothing after a discard, never a lower figure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

PlannedMove _loaded(String id, String name) => PlannedMove(
  exerciseId: id,
  name: name,
  prescriptionLabel: '',
  needsEquipment: true,
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

PlannedMove _bodyweight(String id) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

void _log(
  InMemoryTrainRepository repo,
  String sessionId,
  String id, {
  required int reps,
  double? kg,
}) => repo.flushMove(
  sessionId: sessionId,
  exerciseId: id,
  sets: [
    for (var i = 1; i <= 3; i++)
      LoggedSet(
        prescribed: PrescribedSet(exerciseId: id, order: i, reps: 10),
      ).recording(SetOutcome(reps: reps, weightKg: kg)),
  ],
);

void main() {
  final state = WorkoutSessionState.instance;
  late InMemoryTrainRepository repository;

  setUp(() {
    state.reset();
    RewardsState.instance.reset();
    TrainingStreakState.instance.reset();
    repository = InMemoryTrainRepository();
  });

  final day = WorkoutDay(
    id: '2026-10-22',
    title: 'Glutes',
    summary: '',
    constraints: '',
    moves: [
      _loaded('hip_thrust', 'Hip thrust'),
      _loaded('leg_press', 'Leg press'),
      _bodyweight('glute_bridge'),
      _loaded('rdl', 'Romanian deadlift'),
      _loaded('curl', 'Curl'),
      _loaded('row', 'Row'),
    ],
  );

  Future<void> session({EndedReason reason = EndedReason.finished}) async {
    state.start(day, repository);
    await Future<void>.delayed(Duration.zero);
    state.setLogged();
    _log(repository, 'live-1', 'hip_thrust', reps: 10, kg: 20);
    _log(repository, 'live-1', 'leg_press', reps: 8, kg: 40);
    _log(repository, 'live-1', 'glute_bridge', reps: 10);
    _log(repository, 'live-1', 'rdl', reps: 10, kg: 30);
    _log(repository, 'live-1', 'curl', reps: 10, kg: 8);
    await state.finish(
      repository: repository,
      today: InMemoryTodayRepository(),
      progress: ProgressStore(),
      reason: reason,
    );
  }

  List<NextTimeMove> next({bool difficult = false}) => nextWeightsFor(
    repository: repository,
    moves: day.moves,
    difficult: difficult,
  );

  test('a step up when the sets were done, the same weight when not', () async {
    await session();
    expect(next(), const [
      NextTimeMove(name: 'Hip thrust', kg: 22.5, rises: true),
      NextTimeMove(name: 'Leg press', kg: 40, rises: false),
      NextTimeMove(name: 'Romanian deadlift', kg: 35, rises: true),
    ]);
  });

  test('a hard week holds the weight, never lowers it', () async {
    await session();
    final held = next(difficult: true);
    expect(held.every((m) => !m.rises), isTrue);
    expect(held.first.kg, 20);
  });

  test('nothing for bodyweight and nothing after a discard', () async {
    await session(reason: EndedReason.abandoned);
    expect(next(), isEmpty);
  });

  group('on R03', () {
    Widget host(Locale locale) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: WorkoutDayView(repository: repository, day: day),
    );

    testWidgets('English: a step up and a hold, no drop words', (tester) async {
      await tester.runAsync(session);
      await tester.pumpWidget(host(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.text('Today: 22.5 kg on Hip thrust'), findsOneWidget);
      expect(
        find.text(
          'Same weight on Leg press as last time, until it feels steady',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Arabic: English move names stay left to right', (
      tester,
    ) async {
      await tester.runAsync(session);
      await tester.pumpWidget(host(const Locale('ar')));
      await tester.pumpAndSettle();
      expect(
        find.text('النهارده: 22.5 كجم على \u2066Hip thrust\u2069'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing without history', (tester) async {
      await tester.pumpWidget(host(const Locale('en')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('r03-weights-today')), findsNothing);
      expect(find.textContaining('Today:'), findsNothing);
    });
  });
}
