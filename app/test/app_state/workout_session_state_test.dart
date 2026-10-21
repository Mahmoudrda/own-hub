// The session she is doing, while she is doing it: one session per start, one
// bus for the whole session, undo that puts her back, and a finish that writes
// the last set before anything is credited (D41, G01, G02, G10).

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

PlannedMove move(String id, int sets) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '',
  sets: [
    for (var i = 1; i <= sets; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

final WorkoutDay day = WorkoutDay(
  id: '2026-10-13',
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: [move('squat', 3), move('bridge', 2)],
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

  Future<void> started() async {
    state.start(day, repository);
    await Future<void>.delayed(Duration.zero);
  }

  test('one start is one session', () async {
    await started();
    expect(repository.flushes, isEmpty);
    expect(repository.liveSessionId, 'live-1');
    state.start(day, repository); // already live: left alone
    await Future<void>.delayed(Duration.zero);
    expect(repository.liveSessionId, 'live-1');
  });

  test('sets done and total follow the position, swaps included', () async {
    await started();
    expect(state.setsTotal, 5);
    expect(state.setsDone, 0);
    state.setLogged();
    state.setLogged();
    expect(state.setsDone, 2);
    state.moveLogged();
    expect(state.setsDone, 3);
  });

  test('undo puts her back on the set she took back', () async {
    await started();
    state.setLogged();
    state.setLogged();
    expect(state.setIndex, 2);
    expect(state.undoLast(), isTrue);
    expect(state.setIndex, 1);
    expect(state.loggedSetCount, 1);
    state.moveLogged();
    expect(state.moveIndex, 1);
    expect(state.undoLast(), isTrue);
    expect(state.moveIndex, 0);
    expect(state.setIndex, 1);
    expect(state.undoLast(), isTrue);
    expect(state.undoLast(), isFalse);
  });

  test('finish writes the last set before it credits anything', () async {
    await started();
    final today = InMemoryTodayRepository();
    final progress = ProgressStore();
    // The last set is still inside its five seconds when she finishes.
    state.bus.submit(
      UndoableLog(
        describe: 'last set',
        commit: () => repository.flushMove(
          sessionId: 'live-1',
          exerciseId: 'bridge',
          sets: [
            LoggedSet(
              prescribed: const PrescribedSet(
                exerciseId: 'bridge',
                order: 2,
                reps: 10,
              ),
            ).recording(const SetOutcome(reps: 10)),
          ],
        ),
      ),
    );
    final summary = await state.finish(
      repository: repository,
      today: today,
      progress: progress,
    );
    expect(repository.flushes, hasLength(1));
    expect(summary, isNotNull);
    expect(summary!.sets, 1);
    expect(summary.credit.sessionPoints, 30);
    expect(progress.rewards.sessionsLogged, 1);
    expect(state.lastSummary, same(summary));
  });

  test('leaving the workout commits what is still inside its window', () async {
    await started();
    var written = false;
    state.attachScreen();
    state.bus.submit(
      UndoableLog(describe: 'a set', commit: () async => written = true),
    );
    state.detachScreen();
    await Future<void>.delayed(Duration.zero);
    expect(written, isTrue);
  });

  test('flushAll commits everything and leaves no timer behind', () {
    fakeAsync((async) {
      final bus = LogCommandBus();
      var commits = 0;
      for (var i = 0; i < 3; i++) {
        bus.submit(UndoableLog(describe: '$i', commit: () async => commits++));
      }
      expect(async.pendingTimers, hasLength(3));
      bus.flushAll();
      expect(
        async.pendingTimers,
        isEmpty,
        reason: 'cancelled before any await',
      );
      async.flushMicrotasks();
      expect(commits, 3);
    });
  });

  test(
    'relabel puts the same live day in another language, in place',
    () async {
      state.start(day, repository);
      await started();
      final arabic = WorkoutDay(
        id: day.id,
        title: 'ساقين',
        summary: '',
        constraints: '',
        moves: day.moves,
      );
      state.relabel(arabic);
      expect(state.day?.title, 'ساقين');

      final other = WorkoutDay(
        id: day.id,
        title: 'Other',
        summary: '',
        constraints: '',
        moves: [move('squat', 3)],
      );
      state.relabel(other);
      expect(
        state.day?.title,
        'ساقين',
        reason: 'a different plan is not a label',
      );
    },
  );
}
