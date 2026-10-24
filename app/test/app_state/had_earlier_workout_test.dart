// Activation counts only the first workout: what "an earlier one" means.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

const _move = PlannedMove(
  exerciseId: 'squat',
  name: 'Squat',
  prescriptionLabel: '',
  sets: [PrescribedSet(exerciseId: 'squat', order: 1, reps: 10)],
);

WorkoutDay _day(String id) => WorkoutDay(
  id: id,
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: const [_move],
);

Future<String> _finished(InMemoryTrainRepository repo, String day) async {
  final session = await repo.startSession(_day(day));
  await repo.finishSession(sessionId: session.id, durationSec: 600);
  return session.id;
}

void main() {
  test('the very first workout has no earlier one', () async {
    final repo = InMemoryTrainRepository();
    final id = await _finished(repo, '2026-10-01');
    expect(
      WorkoutSessionState.hadEarlierWorkout(const CreditOutcome(), repo, id),
      isFalse,
    );
  });

  test('a finished session before this one is an earlier workout', () async {
    final repo = InMemoryTrainRepository();
    await _finished(repo, '2026-10-01');
    final id = await _finished(repo, '2026-10-02');
    expect(
      WorkoutSessionState.hadEarlierWorkout(const CreditOutcome(), repo, id),
      isTrue,
    );
  });

  test(
    'a week with a logged session before it is an earlier workout',
    () async {
      final repo = InMemoryTrainRepository();
      final id = await _finished(repo, '2026-10-01');
      expect(
        WorkoutSessionState.hadEarlierWorkout(
          const CreditOutcome(loggedBefore: 1),
          repo,
          id,
        ),
        isTrue,
      );
    },
  );
}
