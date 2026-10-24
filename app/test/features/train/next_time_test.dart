// R10 looks ahead: for up to three loaded moves she weighed, what to lift
// next time. A step up when the sets were done, the same weight when not,
// nothing for bodyweight, nothing after a discard, never a lower figure.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/finish_wipe.dart';

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

  Future<SessionSummary?> session({
    EndedReason reason = EndedReason.finished,
    bool difficult = false,
  }) async {
    state.start(day, repository);
    await Future<void>.delayed(Duration.zero);
    state.setLogged();
    _log(repository, 'live-1', 'hip_thrust', reps: 10, kg: 20);
    _log(repository, 'live-1', 'leg_press', reps: 8, kg: 40);
    _log(repository, 'live-1', 'glute_bridge', reps: 10);
    _log(repository, 'live-1', 'rdl', reps: 10, kg: 30);
    _log(repository, 'live-1', 'curl', reps: 10, kg: 8);
    return state.finish(
      repository: repository,
      today: InMemoryTodayRepository(),
      progress: ProgressStore(),
      reason: reason,
      difficult: difficult,
    );
  }

  test('a step up when the sets were done, the same weight when not', () async {
    final summary = await session();
    expect(summary!.nextTime, const [
      NextTimeMove(name: 'Hip thrust', kg: 22.5, rises: true),
      NextTimeMove(name: 'Leg press', kg: 40, rises: false),
      NextTimeMove(name: 'Romanian deadlift', kg: 35, rises: true),
    ]);
  });

  test('a hard week holds the weight, never lowers it', () async {
    final summary = await session(difficult: true);
    expect(summary!.nextTime.every((m) => !m.rises), isTrue);
    expect(summary.nextTime.first.kg, 20);
  });

  test('nothing for bodyweight and nothing after a discard', () async {
    final discarded = await session(reason: EndedReason.abandoned);
    expect(discarded!.nextTime, isEmpty);
  });

  group('on R10', () {
    final savedFlags = AppRouter.featureFlags;
    setUp(
      () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.finishReveal: true,
      }),
    );
    tearDown(() => AppRouter.featureFlags = savedFlags);

    const live = TrainSession(
      id: 'live-1',
      source: SessionSource.live,
      dateKey: '2026-10-22',
      sets: [],
      completed: true,
    );

    SessionSummary summaryWith(List<NextTimeMove> next) => SessionSummary(
      sessionId: 'live-1',
      source: SessionSource.live,
      moves: 3,
      sets: 9,
      minutes: 20,
      credit: const CreditOutcome(sessionPoints: 30),
      nextTime: next,
    );

    Widget host(Locale locale, SessionSummary summary) => MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: FinishedView(session: live, summary: summary),
      ),
    );

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(finishWipeDuration);
      await tester.pumpAndSettle();
    }

    const next = [
      NextTimeMove(name: 'Hip thrust', kg: 22.5, rises: true),
      NextTimeMove(name: 'Leg press', kg: 40, rises: false),
    ];

    testWidgets('English: a step up and a hold, no drop words', (tester) async {
      await tester.pumpWidget(host(const Locale('en'), summaryWith(next)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('r10-see-details')));
      await tester.pumpAndSettle();
      expect(
        find.text('Next time: 22.5 kg on \u2066Hip thrust\u2069'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Same weight on \u2066Leg press\u2069 next time, until it feels steady',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('Arabic: English move names stay left to right', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Locale('ar'), summaryWith(next)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('r10-see-details')));
      await tester.pumpAndSettle();
      expect(
        find.text('المرة الجاية: 22.5 كجم على \u2066Hip thrust\u2069'),
        findsOneWidget,
      );
      expect(find.textContaining('نفس الوزن على'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing when there is nothing to look ahead to', (
      tester,
    ) async {
      await tester.pumpWidget(host(const Locale('en'), summaryWith(const [])));
      await settle(tester);
      expect(find.byKey(const ValueKey('r10-next-time')), findsNothing);
      expect(find.textContaining('Next time'), findsNothing);
    });
  });
}
