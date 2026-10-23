// Warm-up sets and the live record badge, through the real session state, the
// real bests bridge and the real detector.
//
// A warm-up is saved and shown but is not a working set: she stays on the same
// set, nothing is counted, no best is set, and the summary leaves it out. The
// badge is read from what the ledger really raised when a set was written, so
// it appears only for a live set that beat a best she already had.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rest_timer_prefs.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/personal_best_ledger.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/live_best.dart';
import 'package:own_hub/features/train/domain/session_bests_bridge.dart';
import 'package:own_hub/features/train/domain/set_history.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

PlannedMove _move(String id, int sets, {double? kg, int reps = 10}) =>
    PlannedMove(
      exerciseId: id,
      name: id,
      prescriptionLabel: '',
      sets: [
        for (var i = 1; i <= sets; i++)
          PrescribedSet(exerciseId: id, order: i, weightKg: kg, reps: reps),
      ],
    );

final WorkoutDay _day = WorkoutDay(
  id: '2026-10-21',
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: [
    _move('goblet_squat', 3, kg: 20, reps: 8),
    _move('glute_bridge', 2, reps: 12),
  ],
);

void main() {
  final state = WorkoutSessionState.instance;
  late PersonalBestLedger ledger;
  late InMemoryTrainRepository repository;

  setUp(() {
    state.reset();
    RewardsState.instance.reset();
    TrainingStreakState.instance.reset();
    RestTimerPrefs.instance.reset();
    ledger = PersonalBestLedger();
    final bridge = SessionBestsBridge(ledger: ledger);
    // What the router's flush hook does with a flushed move.
    repository = InMemoryTrainRepository(
      onFlushed: ({session, required exerciseId, required sets}) {
        final bests = bridge.record(
          session: session,
          exerciseId: exerciseId,
          sets: sets,
        );
        if (session == null) return;
        state.noteBests(session.id, bests.counted);
        state.noteLiveBests(session.id, bests.written);
      },
    );
  });

  tearDown(() {
    state.reset();
    RestTimerPrefs.instance.reset();
  });

  Future<void> started() async {
    state.start(_day, repository);
    await Future<void>.delayed(Duration.zero);
  }

  /// A working set, the way R07 does it: the log goes through the bus, the
  /// session moves on, and the write lands when the window closes.
  Future<void> work(double? kg, int reps) async {
    final move = state.currentMove!;
    final order = state.setIndex + 1;
    final session = state.sessionId;
    state.bus.submit(
      UndoableLog(
        describe: 'set',
        commit: () => repository.flushMove(
          sessionId: session,
          exerciseId: move.exerciseId,
          sets: [
            LoggedSet(
              prescribed: PrescribedSet(
                exerciseId: move.exerciseId,
                order: order,
                weightKg: kg,
                reps: reps,
              ),
            ).recording(SetOutcome(weightKg: kg, reps: reps)),
          ],
        ),
      ),
    );
    state.setLogged();
    await state.bus.flushAll();
  }

  Future<void> trainSquatDay(double kg, int reps) async {
    await started();
    await work(kg, reps);
  }

  group('a warm-up is not a working set', () {
    test('she stays on the same set and nothing is counted', () async {
      await started();
      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));

      expect(state.setIndex, 0);
      expect(state.moveIndex, 0);
      expect(state.loggedSetCount, 0);
      expect(state.setsDone, 0);
      expect(state.warmUpsFor('goblet_squat'), hasLength(1));
      expect(state.warmUpsFor('glute_bridge'), isEmpty);
    });

    test('it starts the rest after the move, like any set', () async {
      RestTimerPrefs.instance.setFor(
        'goblet_squat',
        const Duration(seconds: 90),
      );
      await started();
      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));
      expect(state.restMoveId, 'goblet_squat');
      expect(state.restDuration, const Duration(seconds: 90));
    });

    test('taking it back puts her where she was, not a set earlier', () async {
      await started();
      await work(20, 8);
      expect(state.setIndex, 1);

      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));
      expect(state.undoLast(), isTrue);

      expect(state.setIndex, 1, reason: 'the working set stays logged');
      expect(state.loggedSetCount, 1);
      expect(state.warmUpsFor('goblet_squat'), isEmpty);
    });

    test(
      'it never reaches the flushed sets that history is read from',
      () async {
        await started();
        state.warmUpLogged(const SetOutcome(weightKg: 100, reps: 30));
        await work(20, 8);

        expect(repository.flushes, hasLength(1));
        expect(
          lastLoggedOutcome(repository, 'goblet_squat')?.weightKg,
          20,
          reason: 'the "last time" hint is a working set',
        );
      },
    );

    test('and sets no personal best, however heavy it was entered', () async {
      await started();
      state.warmUpLogged(const SetOutcome(weightKg: 100, reps: 30));
      await work(20, 8);

      expect(ledger.bests['goblet_squat']?.loadKg, 20);
    });

    test('the summary counts working sets only', () async {
      await started();
      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));
      await work(20, 8);
      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));
      await work(20, 8);

      final summary = await state.finish(
        repository: repository,
        today: InMemoryTodayRepository(),
        progress: ProgressStore(),
      );
      expect(summary?.sets, 2);
      expect(summary?.moves, 1);
    });

    test('a session of warm-ups alone counts for nothing', () async {
      await started();
      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));

      final summary = await state.finish(
        repository: repository,
        today: InMemoryTodayRepository(),
        progress: ProgressStore(),
      );
      expect(summary?.sets, 0);
      expect(summary?.credit.weekCountedNow, isFalse);
    });

    test('they are cleared for the next session', () async {
      await started();
      state.warmUpLogged(const SetOutcome(weightKg: 10, reps: 8));
      state.reset();
      await started();
      expect(state.warmUpsFor('goblet_squat'), isEmpty);
    });
  });

  group('the live record badge', () {
    Future<void> secondDay(double kg, int reps) async {
      state.reset();
      await trainSquatDay(kg, reps);
    }

    test('a first mark on a move is not a record she beat', () async {
      await trainSquatDay(20, 8);
      expect(ledger.bests['goblet_squat'], isNotNull);
      expect(state.liveBest, isNull);
    });

    test('a heavier set beats her best and says so', () async {
      await trainSquatDay(20, 8);
      await secondDay(22.5, 8);

      final best = state.liveBest;
      expect(best?.kind, LiveBestKind.heavier);
      expect(best?.loadKg, 22.5);
      expect(best?.exerciseId, 'goblet_squat');
    });

    test('more reps at the same weight beats it too', () async {
      await trainSquatDay(20, 8);
      await secondDay(20, 10);

      expect(state.liveBest?.kind, LiveBestKind.moreReps);
      expect(state.liveBest?.reps, 10);
      expect(state.liveBest?.loadKg, 20);
    });

    test('the same set again beats nothing', () async {
      await trainSquatDay(20, 8);
      await secondDay(20, 8);
      expect(state.liveBest, isNull);
    });

    test('a lighter set beats nothing', () async {
      await trainSquatDay(20, 8);
      await secondDay(15, 8);
      expect(state.liveBest, isNull);
    });

    test('it is cleared by the next set she saves', () async {
      await trainSquatDay(20, 8);
      await secondDay(22.5, 8);
      expect(state.liveBest, isNotNull);

      await work(22.5, 8);
      expect(state.liveBest, isNull, reason: 'same set again');
    });

    test('and by taking the set back', () async {
      await trainSquatDay(20, 8);
      await secondDay(22.5, 8);
      state.undoLast();
      expect(state.liveBest, isNull);
    });

    test('it is hidden once she is resting after a different move', () async {
      await trainSquatDay(20, 8);
      await secondDay(22.5, 8);
      expect(state.liveBest, isNotNull);

      // The squat's best is still known, but this rest follows the bridge.
      await work(22.5, 8);
      await work(22.5, 8);
      await work(null, 12);
      state.noteLiveBests(state.sessionId, [
        PersonalBest(
          exerciseId: 'goblet_squat',
          metric: BestMetric.load,
          dateKey: '2026-10-21',
          sessionId: state.sessionId,
          loadKg: 25,
          reps: 8,
          previous: const PreviousBest(loadKg: 22.5, reps: 8),
        ),
      ]);
      expect(state.restMoveId, 'glute_bridge');
      expect(state.liveBest, isNull);
    });

    test('only the live session\'s own sets are noted', () async {
      await trainSquatDay(20, 8);
      state.noteLiveBests('recalled-2026-10-01-plan', [
        PersonalBest(
          exerciseId: 'goblet_squat',
          metric: BestMetric.load,
          dateKey: '2026-10-01',
          sessionId: 'recalled-2026-10-01-plan',
          loadKg: 40,
          reps: 8,
          previous: const PreviousBest(loadKg: 20, reps: 8),
        ),
      ]);
      expect(state.liveBest, isNull);
    });

    test(
      'a recalled session raises no best at all, so there is no badge',
      () async {
        final bridge = SessionBestsBridge(ledger: ledger);
        final recalled = await repository.logRecalled(
          dateKey: '2026-10-01',
          method: RecallMethod.history,
        );
        final bests = bridge.record(
          session: recalled,
          exerciseId: 'goblet_squat',
          sets: [
            LoggedSet(
              prescribed: const PrescribedSet(
                exerciseId: 'goblet_squat',
                order: 1,
                weightKg: 40,
                reps: 8,
              ),
            ).recording(const SetOutcome(weightKg: 40, reps: 8)),
          ],
        );
        expect(bests.written, isEmpty);
        expect(firstLiveBest(bests.written), isNull);
      },
    );
  });

  group('what improved', () {
    PersonalBest best(
      BestMetric metric, {
      num? load,
      int? reps,
      int? hold,
      PreviousBest? previous,
    }) => PersonalBest(
      exerciseId: 'x',
      metric: metric,
      dateKey: '2026-10-21',
      sessionId: 's',
      loadKg: load,
      reps: reps,
      holdSec: hold,
      previous: previous,
    );

    test('nothing without a best to beat', () {
      expect(liveBestOf(best(BestMetric.load, load: 20, reps: 8)), isNull);
    });

    test('a heavier load', () {
      final found = liveBestOf(
        best(
          BestMetric.load,
          load: 22,
          reps: 8,
          previous: const PreviousBest(loadKg: 20, reps: 8),
        ),
      );
      expect(found?.kind, LiveBestKind.heavier);
    });

    test('the same load for more work', () {
      final found = liveBestOf(
        best(
          BestMetric.load,
          load: 20,
          reps: 10,
          previous: const PreviousBest(loadKg: 20, reps: 8),
        ),
      );
      expect(found?.kind, LiveBestKind.moreReps);
      expect(found?.reps, 10);
    });

    test('more reps on a bodyweight move', () {
      final found = liveBestOf(
        best(BestMetric.reps, reps: 14, previous: const PreviousBest(reps: 12)),
      );
      expect(found?.kind, LiveBestKind.moreReps);
      expect(found?.loadKg, isNull);
    });

    test('a longer hold', () {
      final found = liveBestOf(
        best(
          BestMetric.hold,
          hold: 50,
          previous: const PreviousBest(holdSec: 45),
        ),
      );
      expect(found?.kind, LiveBestKind.longerHold);
      expect(found?.holdSec, 50);
    });
  });
}
