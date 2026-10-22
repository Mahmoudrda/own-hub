/// A personal best she has just set, in the words the chip on R09 needs.
///
/// Built from what the ledger really recorded when the set was written, so it
/// appears only for a live session and only for a set that beat a best she
/// already had. A first mark on a move she never logged is not one.
library;

import 'package:meta/meta.dart';

import '../../../domain/rewards/personal_best_detector.dart';

enum LiveBestKind { heavier, moreReps, longerHold, harderVersion }

@immutable
class LiveBest {
  const LiveBest({
    required this.exerciseId,
    required this.kind,
    this.loadKg,
    this.reps,
    this.holdSec,
  });

  final String exerciseId;
  final LiveBestKind kind;
  final num? loadKg;
  final int? reps;
  final int? holdSec;
}

/// The improvement in [best], or null when it beat nothing she had.
LiveBest? liveBestOf(PersonalBest best) {
  final was = best.previous;
  if (was == null) return null;
  switch (best.metric) {
    case BestMetric.load:
      final load = best.loadKg;
      final wasLoad = was.loadKg;
      if (load != null && (wasLoad == null || load > wasLoad)) {
        return LiveBest(
          exerciseId: best.exerciseId,
          kind: LiveBestKind.heavier,
          loadKg: load,
          reps: best.reps,
        );
      }
      final reps = best.reps;
      if (load != null && reps != null && reps > (was.reps ?? 0)) {
        return LiveBest(
          exerciseId: best.exerciseId,
          kind: LiveBestKind.moreReps,
          loadKg: load,
          reps: reps,
        );
      }
      return null;
    case BestMetric.reps:
      final reps = best.reps;
      if (reps == null || reps <= (was.reps ?? 0)) return null;
      return LiveBest(
        exerciseId: best.exerciseId,
        kind: LiveBestKind.moreReps,
        loadKg: best.loadKg,
        reps: reps,
      );
    case BestMetric.hold:
      final hold = best.holdSec;
      if (hold == null || hold <= (was.holdSec ?? 0)) return null;
      return LiveBest(
        exerciseId: best.exerciseId,
        kind: LiveBestKind.longerHold,
        holdSec: hold,
      );
    case BestMetric.variation:
      return LiveBest(
        exerciseId: best.exerciseId,
        kind: LiveBestKind.harderVersion,
      );
  }
}

/// The first improvement among [written], or null when none beat a best.
LiveBest? firstLiveBest(Iterable<PersonalBest> written) {
  for (final best in written) {
    final found = liveBestOf(best);
    if (found != null) return found;
  }
  return null;
}
