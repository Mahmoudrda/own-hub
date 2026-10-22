/// Warm-up sets.
///
/// A warm-up is saved with the session and shown beside the move, but it is
/// not a working set: it does not move her to the next set, it earns no
/// personal best, and the finish summary leaves it out. It never enters the
/// flushed sets that bests, volume and the summary are read from.
library;

import '../../../domain/training/prescribed_set.dart';

/// About half of [workingKg], to the nearest half kilo. Null when there is no
/// working weight, or half of it is under a kilo and not worth loading.
double? warmUpWeightKg(num? workingKg) {
  if (workingKg == null || workingKg <= 0) return null;
  final half = (workingKg * 0.5 * 2).round() / 2;
  return half < 1 ? null : half;
}

/// The warm-up set that goes with a working set: lighter when the move is
/// loaded, otherwise the same figure.
///
/// [lastKg] is the weight she lifted last time on this move; when she has
/// none, the prescribed weight stands in. A bodyweight move keeps its figure.
SetOutcome warmUpOutcomeFor(PrescribedSet prescribed, {num? lastKg}) {
  final base = lastKg != null && lastKg > 0 ? lastKg : prescribed.weightKg;
  final weight = warmUpWeightKg(base);
  return SetOutcome(
    weightKg: weight,
    reps: prescribed.reps,
    holdSeconds: prescribed.holdSeconds,
  );
}
