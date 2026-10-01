// A woman's training history, built straight into the repository.
//
// Not a `_test.dart` file, so the runner does not execute it.
//
// Shaped the way a live session really is: `startSession` builds one
// [LoggedSet] per prescribed set with a null outcome (spine C8), and
// `flushMove` then records one flush per MOVE carrying the outcomes she agreed
// to. So a 5-move, 3-set session is 15 prescription-only sets under
// `sessions` and 5 flushes of 3 outcome-carrying sets under `flushes`.
//
// Built through `restore` rather than through `startSession`/`flushMove`
// because 800 sessions of the real calls also runs the personal-best bridge
// 4,000 times, and the subject here is the document, not the bridge.

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/routing/app_router.dart';

/// Five moves, the size of a shipped session.
const List<String> kMoves = <String>[
  'goblet_squat',
  'hip_bridge',
  'romanian_deadlift',
  'split_squat',
  'dead_bug',
];

/// Three sets a move, the shipped prescription.
const int kSetsPerMove = 3;

PrescribedSet _prescribed(String exerciseId, int order) => PrescribedSet(
  exerciseId: exerciseId,
  order: order,
  weightKg: 12.5 + order,
  reps: 12 - order,
);

/// Fills `AppRouter.trainRepository` with [sessions] finished sessions, each of
/// five moves and three sets, every set logged.
void fillTrainHistory({required int sessions}) {
  final all = <TrainSession>[];
  final flushes =
      <({String sessionId, String exerciseId, List<LoggedSet> sets})>[];

  for (var s = 0; s < sessions; s++) {
    final id = 'live-${s + 1}';
    final dateKey = '2026-${(s % 12 + 1).toString().padLeft(2, '0')}'
        '-${(s % 28 + 1).toString().padLeft(2, '0')}';
    final sets = <LoggedSet>[
      for (final move in kMoves)
        for (var i = 1; i <= kSetsPerMove; i++)
          LoggedSet(prescribed: _prescribed(move, i)),
    ];
    all.add(
      TrainSession(
        id: id,
        source: SessionSource.live,
        dateKey: dateKey,
        assignmentId: dateKey,
        planVersion: 'plan-2026-03',
        sets: sets,
        durationSec: 1520 + s % 300,
        endedReason: EndedReason.finished,
        completed: true,
      ),
    );
    for (final move in kMoves) {
      flushes.add((
        sessionId: id,
        exerciseId: move,
        sets: <LoggedSet>[
          for (var i = 1; i <= kSetsPerMove; i++)
            LoggedSet(prescribed: _prescribed(move, i)).recording(
              SetOutcome(weightKg: 12.5 + i, reps: 11 - i),
            ),
        ],
      ));
    }
  }

  AppRouter.trainRepository.restore(
    sessions: all,
    flushes: flushes,
    sessionCounter: sessions,
  );
}
