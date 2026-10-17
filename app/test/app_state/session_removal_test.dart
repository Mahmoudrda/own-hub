// A session she logged by mistake can be corrected or removed after its five
// seconds, and removing it takes its own credit back with it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/rewards/award_table.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final DateTime tue = DateTime(2026, 10, 13, 10);

const PrescribedSet _first = PrescribedSet(
  exerciseId: 'squat',
  order: 1,
  reps: 10,
);
const PrescribedSet _second = PrescribedSet(
  exerciseId: 'squat',
  order: 2,
  reps: 10,
);

WorkoutDay _gobletDay(String id) => WorkoutDay(
  id: id,
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: const [
    PlannedMove(
      exerciseId: 'goblet_squat',
      name: 'Goblet squat',
      prescriptionLabel: '',
      sets: [
        PrescribedSet(
          exerciseId: 'goblet_squat',
          order: 1,
          weightKg: 10,
          reps: 10,
        ),
      ],
    ),
  ],
);

/// One live session through the app's own wiring: started, one set of goblet
/// squats at [kg] flushed (the bests are measured as it lands), finished and
/// credited on [on].
Future<TrainSession> _liveSession(double kg, DateTime on) async {
  final repo = AppRouter.trainRepository;
  final session = await repo.startSession(_gobletDay(dayKey(on)));
  await repo.flushMove(
    sessionId: session.id,
    exerciseId: 'goblet_squat',
    sets: [
      LoggedSet(
        prescribed: const PrescribedSet(
          exerciseId: 'goblet_squat',
          order: 1,
          weightKg: 10,
          reps: 10,
        ),
      ).recording(SetOutcome(weightKg: kg, reps: 10)),
    ],
  );
  final finished = await repo.finishSession(
    sessionId: session.id,
    durationSec: 1200,
  );
  RewardsState.instance.creditSession(
    sessionId: session.id,
    source: SessionSource.live,
    today: AppRouter.todayRepository,
    progress: AppRouter.progressStore,
    now: on,
  );
  return finished;
}

void main() {
  group('TrainRepository.replaceSet', () {
    test('corrects the set where it landed, and only that set', () async {
      final repo = InMemoryTrainRepository();
      await repo.flushMove(
        sessionId: 's1',
        exerciseId: 'squat',
        sets: [
          LoggedSet(prescribed: _first).recording(const SetOutcome(reps: 10)),
          LoggedSet(prescribed: _second).recording(const SetOutcome(reps: 10)),
        ],
      );

      await repo.replaceSet(
        sessionId: 's1',
        exerciseId: 'squat',
        set: LoggedSet(prescribed: _second)
            .recording(const SetOutcome(reps: 7)),
      );

      final sets = repo.loggedSetsFor(sessionId: 's1', exerciseId: 'squat');
      expect(sets.map((s) => s.outcome!.reps), [10, 7]);
      // The plan is untouched: only the outcome changed.
      expect(sets.last.prescribed.reps, 10);
      expect(repo.flushes, hasLength(1));
    });

    test('a set never written is recorded by the correction', () async {
      final repo = InMemoryTrainRepository();
      await repo.replaceSet(
        sessionId: 's1',
        exerciseId: 'squat',
        set: LoggedSet(prescribed: _first).recording(const SetOutcome(reps: 8)),
      );
      expect(
        repo
            .loggedSetsFor(sessionId: 's1', exerciseId: 'squat')
            .single
            .outcome!
            .reps,
        8,
      );
    });
  });

  group('TrainRepository.removeSession', () {
    test('takes the session and every set written to it', () async {
      final repo = InMemoryTrainRepository();
      final day = WorkoutDay(
        id: '2026-10-13',
        title: 'Legs',
        summary: '',
        constraints: '',
        moves: const [
          PlannedMove(
            exerciseId: 'squat',
            name: 'Squat',
            prescriptionLabel: '',
            sets: [_first],
          ),
        ],
      );
      final session = await repo.startSession(day);
      await repo.flushMove(
        sessionId: session.id,
        exerciseId: 'squat',
        sets: [
          LoggedSet(prescribed: _first).recording(const SetOutcome(reps: 10)),
        ],
      );
      await repo.flushMove(
        sessionId: 'other',
        exerciseId: 'squat',
        sets: [
          LoggedSet(prescribed: _first).recording(const SetOutcome(reps: 9)),
        ],
      );

      final removed = await repo.removeSession(session.id);

      expect(removed?.id, session.id);
      expect(repo.sessionById(session.id), isNull);
      expect(repo.flushes.map((f) => f.sessionId), ['other']);
      expect(await repo.removeSession(session.id), isNull);
    });
  });

  group('RewardsState.uncreditSession', () {
    late ProgressStore progress;
    late InMemoryTodayRepository today;
    final rewards = RewardsState.instance;

    setUp(() {
      rewards.reset();
      TrainingStreakState.instance.reset();
      progress = ProgressStore();
      today = InMemoryTodayRepository();
    });

    test('the session leaves the week, her count, her points and Home', () {
      final first = rewards.creditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: tue,
      );
      final before = progress.rewards.points;
      expect(today.day.week.sessionsLogged, 1);
      expect(TrainingStreakState.instance.sessionsByDay[dayKey(tue)], 1);

      final removed = rewards.uncreditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        sessionPoints: first.sessionPoints,
        now: tue,
      );

      expect(removed, isTrue);
      final week = progress.weeks[WeekKey.of(tue).id]!;
      expect(week.creditedSessionIds, isEmpty);
      expect(week.sessionsLogged, 0);
      expect(progress.rewards.sessionsLogged, 0);
      // Her first session's milestone was this session's alone.
      expect(first.milestonesEarned, contains('first_session'));
      expect(progress.rewards.milestones, isNot(contains('first_session')));
      expect(rewards.awardIds, isNot(contains('milestone:first_session')));
      expect(
        progress.rewards.points,
        before - first.sessionPoints - first.milestonePoints,
      );
      expect(today.day.week.sessionsLogged, 0);
      expect(today.creditedSessions, isNot(contains('live-1')));
      expect(TrainingStreakState.instance.sessionsByDay[dayKey(tue)], isNull);
    });

    test('logging the same session again after removing it counts again', () {
      rewards.creditSession(
        sessionId: 'recalled-2026-10-13-planned',
        source: SessionSource.recalled,
        today: today,
        progress: progress,
        now: tue,
      );
      rewards.uncreditSession(
        sessionId: 'recalled-2026-10-13-planned',
        source: SessionSource.recalled,
        today: today,
        progress: progress,
        now: tue,
      );
      final again = rewards.creditSession(
        sessionId: 'recalled-2026-10-13-planned',
        source: SessionSource.recalled,
        today: today,
        progress: progress,
        now: tue,
      );

      expect(again.alreadyCredited, isFalse);
      expect(progress.weeks[WeekKey.of(tue).id]!.sessionsLogged, 1);
      expect(today.day.week.sessionsLogged, 1);
    });

    test('a week that already counted stays counted', () {
      progress.goal = progress.goal.copyWith(sessionsTarget: 1);
      final outcome = rewards.creditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: tue,
      );
      expect(outcome.weekCountedNow, isTrue);

      rewards.uncreditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        sessionPoints: outcome.sessionPoints,
        now: tue,
      );

      final week = progress.weeks[WeekKey.of(tue).id]!;
      expect(week.sessionsLogged, 0);
      expect(week.counted, isTrue);
    });

    test('an id never credited changes nothing', () {
      expect(
        rewards.uncreditSession(
          sessionId: 'nobody',
          source: SessionSource.live,
          today: today,
          progress: progress,
          now: tue,
        ),
        isFalse,
      );
      expect(progress.rewards.sessionsLogged, 0);
    });

    test('the preview names what the credit would pay, and pays nothing', () {
      final preview = rewards.previewSession(
        sessionId: 'recalled-2026-10-13-planned',
        source: SessionSource.recalled,
        progress: progress,
        now: tue,
      );
      expect(preview.loggedAfter, 1);
      expect(progress.rewards.points, 0);
      expect(progress.weeks, isEmpty);

      final real = rewards.creditSession(
        sessionId: 'recalled-2026-10-13-planned',
        source: SessionSource.recalled,
        today: today,
        progress: progress,
        now: tue,
      );
      // Milestones are paid by the credit itself and are not previewed.
      expect(preview.points, real.sessionPoints + real.weekPoints);
    });
  });

  group('a milestone she earned before stays', () {
    setUp(() {
      RewardsState.instance.reset();
      TrainingStreakState.instance.reset();
    });

    test('removing a later session leaves her first session milestone', () {
      final progress = ProgressStore();
      final today = InMemoryTodayRepository();
      final rewards = RewardsState.instance;
      rewards.creditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: tue,
      );
      final second = rewards.creditSession(
        sessionId: 'live-2',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: tue.add(const Duration(hours: 2)),
      );
      final before = progress.rewards.points;

      rewards.uncreditSession(
        sessionId: 'live-2',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: tue,
      );

      expect(progress.rewards.milestones, contains('first_session'));
      expect(progress.rewards.points, before - second.sessionPoints);
    });

    test('a closed week loses the session from its count and its bar', () {
      final progress = ProgressStore();
      final today = InMemoryTodayRepository();
      final rewards = RewardsState.instance;
      progress.goal = progress.goal.copyWith(sessionsTarget: 1);
      rewards.creditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: tue,
      );
      final nextWeek = tue.add(const Duration(days: 7));
      rewards.closeStaleWeeks(progress: progress, now: nextWeek);
      final key = WeekKey.of(tue);
      expect(progress.weeks[key.id]!.isClosed, isTrue);
      expect(progress.goal.recent8.last.sessionsLogged, 1);

      rewards.uncreditSession(
        sessionId: 'live-1',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: nextWeek,
      );

      final week = progress.weeks[key.id]!;
      expect(week.creditedSessionIds, isEmpty);
      expect(week.counted, isTrue, reason: 'a counted week stays counted');
      final bar = progress.goal.recent8.firstWhere((b) => b.week == key);
      expect(bar.sessionsLogged, 0);
      expect(bar.counted, isTrue);
      expect(bar, isA<WeekBar>());
    });
  });

  group('removing a session takes its bests back', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await const ThisPhoneWipe().clearPersistence();
    });
    tearDown(() async => const ThisPhoneWipe().clearPersistence());

    test(
      'the best, its points and the tally go back to her earlier one',
      () async {
        final progress = AppRouter.progressStore;
        await _liveSession(10, tue);
        expect(progress.bests['goblet_squat']!.loadKg, 10);
        expect(progress.rewards.bestsCount, 1);

        final wed = tue.add(const Duration(days: 1));
        final second = await _liveSession(14, wed);
        expect(progress.bests['goblet_squat']!.loadKg, 14);
        expect(progress.rewards.bestsCount, 2);
        final bestId = 'best:goblet_squat:${second.id}';
        expect(RewardsState.instance.awardIds, contains(bestId));
        final pointsBefore = progress.rewards.points;
        final sessionPaid =
            RewardsState.instance.grantedPoints['session:${second.id}']!;

        await AppRouter.trainRepository.removeSession(second.id);
        RewardsState.instance.uncreditSession(
          sessionId: second.id,
          source: SessionSource.live,
          today: AppRouter.todayRepository,
          progress: progress,
          bests: AppRouter.sessionBests,
          train: AppRouter.trainRepository,
          now: wed,
        );

        expect(progress.bests['goblet_squat']!.loadKg, 10);
        expect(progress.rewards.bestsCount, 1);
        expect(
          AppRouter.personalBestLedger.countedIds,
          isNot(contains(bestId)),
        );
        expect(RewardsState.instance.awardIds, isNot(contains(bestId)));
        expect(
          progress.rewards.points,
          pointsBefore - sessionPaid - kPersonalBestPoints,
        );
      },
    );

    test(
      'a later lift that beat the older best becomes her best again',
      () async {
        final progress = AppRouter.progressStore;
        await _liveSession(10, tue);
        final wed = tue.add(const Duration(days: 1));
        final peak = await _liveSession(16, wed);
        // Below the peak, so not a best when it was lifted; above the first.
        await _liveSession(12, wed.add(const Duration(days: 1)));
        expect(progress.bests['goblet_squat']!.loadKg, 16);

        await AppRouter.trainRepository.removeSession(peak.id);
        RewardsState.instance.uncreditSession(
          sessionId: peak.id,
          source: SessionSource.live,
          today: AppRouter.todayRepository,
          progress: progress,
          bests: AppRouter.sessionBests,
          train: AppRouter.trainRepository,
          now: wed,
        );

        expect(progress.bests['goblet_squat']!.loadKg, 12);
      },
    );

    test('her only best goes, with its milestone', () async {
      final progress = AppRouter.progressStore;
      final only = await _liveSession(10, tue);
      expect(progress.rewards.milestones, contains('first_personal_best'));

      await AppRouter.trainRepository.removeSession(only.id);
      RewardsState.instance.uncreditSession(
        sessionId: only.id,
        source: SessionSource.live,
        today: AppRouter.todayRepository,
        progress: progress,
        bests: AppRouter.sessionBests,
        train: AppRouter.trainRepository,
        now: tue,
      );

      expect(progress.bests, isEmpty);
      expect(progress.rewards.bestsCount, 0);
      expect(progress.rewards.milestones, isEmpty);
      expect(progress.rewards.points, 0);
    });
  });

  group('a removed session stays removed', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await const ThisPhoneWipe().clearPersistence();
    });
    tearDown(() async => const ThisPhoneWipe().clearPersistence());

    test('through a relaunch and a merge, and her credit holds', () async {
      final repo = AppRouter.trainRepository;
      final progress = AppRouter.progressStore;
      final session = await repo.logRecalled(
        dateKey: dayKey(tue),
        method: RecallMethod.plan,
        assignmentId: 'planned',
      );
      RewardsState.instance.creditSession(
        sessionId: session.id,
        source: SessionSource.recalled,
        today: AppRouter.todayRepository,
        progress: progress,
        now: tue,
      );
      // The copy the server took before she removed it.
      final serverCopy = CloudDocuments.capture().firstWhere(
        (doc) => doc.path == 'sessions/${session.id}',
      );
      expect(serverCopy.data['removed'], isNull);

      await repo.removeSession(session.id);
      RewardsState.instance.uncreditSession(
        sessionId: session.id,
        source: SessionSource.recalled,
        today: AppRouter.todayRepository,
        progress: progress,
        now: tue,
      );
      final points = progress.rewards.points;
      final logged = progress.rewards.sessionsLogged;
      final week = progress.weeks[WeekKey.of(tue).id]!.sessionsLogged;

      // What the cloud is told: the same document, marked removed, in a
      // shape the rules accept as an update (same source, nothing logged).
      final tombstone = CloudDocuments.capture().firstWhere(
        (doc) => doc.path == 'sessions/${session.id}',
      );
      expect(tombstone.data['removed'], isTrue);
      expect(tombstone.data['source'], 'recalled');
      expect(tombstone.data['loggedSetCount'], 0);
      expect(tombstone.data['sets'], isEmpty);
      expect(tombstone.data['updatedAt'], kServerTime);

      // Relaunch: only the phone's own document survives.
      final document = jsonEncode(AppSnapshot.capture());
      await const ThisPhoneWipe().clearPersistence();
      AppSnapshot.restore(document);
      expect(repo.sessionById(session.id), isNull);
      expect(repo.isRemoved(session.id), isTrue);

      // The server still holds the copy without the mark.
      expect(CloudDocuments.mergeIn([serverCopy]), 0);
      expect(repo.sessions.map((s) => s.id), isNot(contains(session.id)));

      expect(progress.rewards.points, points);
      expect(progress.rewards.sessionsLogged, logged);
      expect(progress.weeks[WeekKey.of(tue).id]!.sessionsLogged, week);
    });

    test('a new phone does not take back a session marked removed', () {
      final taken = CloudDocuments.mergeIn([
        const CloudDoc(
          collection: 'sessions',
          id: 'live-3',
          data: <String, Object?>{
            'source': 'live',
            'dateKey': '2026-10-13',
            'sets': <Object?>[],
            'loggedSetCount': 0,
            'removed': true,
          },
        ),
      ]);
      expect(taken, 0);
      expect(AppRouter.trainRepository.sessions, isEmpty);
    });

    test('logging the same recalled session again lifts the removal', () async {
      final repo = AppRouter.trainRepository;
      final first = await repo.logRecalled(
        dateKey: dayKey(tue),
        method: RecallMethod.plan,
        assignmentId: 'planned',
      );
      await repo.removeSession(first.id);
      expect(repo.isRemoved(first.id), isTrue);

      await repo.logRecalled(
        dateKey: dayKey(tue),
        method: RecallMethod.plan,
        assignmentId: 'planned',
      );

      expect(repo.isRemoved(first.id), isFalse);
      final docs = CloudDocuments.capture()
          .where((doc) => doc.path == 'sessions/${first.id}')
          .toList();
      expect(docs, hasLength(1));
      expect(docs.single.data['removed'], isNull);
    });
  });
}
