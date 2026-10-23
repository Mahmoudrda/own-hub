// Home, Train and the player all ask for this week's challenge on every
// redraw. The answer is held until the week, the plan, the target or her
// history changes, so a redraw does not walk the whole history twice.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';

PlannedMove _move(String id) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

WorkoutDay _plan() => WorkoutDay(
  id: '2026-10-13',
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: [_move('squat'), _move('bridge')],
);

TrainSession _live(String id, String day) => TrainSession(
  id: id,
  source: SessionSource.live,
  dateKey: day,
  assignmentId: day,
  planVersion: 'p',
  sets: const [],
  durationSec: 600,
  endedReason: EndedReason.finished,
  completed: true,
);

({String sessionId, String exerciseId, List<LoggedSet> sets}) _flush(
  String session,
  String move,
  int reps,
) => (
  sessionId: session,
  exerciseId: move,
  sets: <LoggedSet>[
    for (var i = 1; i <= 3; i++)
      LoggedSet(
        prescribed: PrescribedSet(exerciseId: move, order: i, reps: 10),
      ).recording(SetOutcome(reps: reps)),
  ],
);

void main() {
  final now = DateTime(2026, 10, 13);
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    AppRouter.forgetChallengeMemo();
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.trainRepository.reset();
    AppRouter.forgetChallengeMemo();
  });

  test('the same week, plan and history give the very same answer', () {
    AppRouter.trainRepository.restore(
      sessions: [_live('live-1', '2026-10-06')],
      flushes: [_flush('live-1', 'bridge', 4)],
      sessionCounter: 1,
    );
    final plan = _plan();

    final first = AppRouter.challengeFor(plan, now: now);
    expect(first, isNotNull);
    expect(identical(AppRouter.challengeFor(plan, now: now), first), isTrue);
  });

  test('a new set in her history is seen at once', () {
    AppRouter.trainRepository.restore(
      sessions: [_live('live-1', '2026-10-06'), _live('live-2', '2026-10-13')],
      flushes: [_flush('live-1', 'bridge', 4)],
      sessionCounter: 2,
    );
    final plan = _plan();
    final before = AppRouter.challengeFor(plan, now: now)!;
    expect(before.thisWeek, 0);

    AppRouter.trainRepository.flushes.add(_flush('live-2', 'bridge', 5));
    final after = AppRouter.challengeFor(plan, now: now)!;

    expect(after.thisWeek, 15);
  });

  test('the next week asks again', () {
    AppRouter.trainRepository.restore(
      sessions: [_live('live-1', '2026-10-06')],
      flushes: [_flush('live-1', 'bridge', 4)],
      sessionCounter: 1,
    );
    final plan = _plan();
    final thisWeek = AppRouter.challengeFor(plan, now: now);
    final nextWeek = AppRouter.challengeFor(plan, now: DateTime(2026, 10, 20));

    expect(identical(thisWeek, nextWeek), isFalse);
  });
}
