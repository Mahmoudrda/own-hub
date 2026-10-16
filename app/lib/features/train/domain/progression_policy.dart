/// When a loaded move earns a heavier weight, and when it does not.
///
/// A suggestion, never a prescription: nothing here is written into a plan or a
/// log (§2 rule 1). R07 and R08 show it as a line she can take or leave, and
/// what she lifts is whatever she taps.
///
/// **The thresholds are not signed off.** "Every target set at the target reps,
/// then the next load up" is the common double-progression rule, drafted for
/// launch and pending the trainer's approval (D47). A coached woman's increase
/// is a suggestion her coach approves ([ProgressionDecision.requiresCoachApproval]).
library;

import 'package:meta/meta.dart';

/// What to do with the weight next time.
@immutable
class ProgressionDecision {
  const ProgressionDecision({
    required this.action,
    required this.suggestedWeightKg,
    this.requiresCoachApproval = false,
  });

  /// `increase`, `hold` or `review`.
  final String action;

  /// The weight to use. Null only when there is no recorded weight to start
  /// from: nothing is invented.
  final double? suggestedWeightKg;

  /// True for an increase that belongs to a coached woman, which her coach
  /// approves before it reaches her.
  final bool requiresCoachApproval;

  @override
  String toString() =>
      'ProgressionDecision($action, $suggestedWeightKg'
      '${requiresCoachApproval ? ', needs approval' : ''})';
}

/// The next weight for a move, from the last session's work on it.
///
/// - [previousWeightKg] is what she last lifted, or null with no history.
/// - [completedReps] is the reps of each work set she logged, in order.
/// - [availableWeightsKg] is what she can pick from; it is not changed.
///
/// An increase needs exactly [targetSets] sets, every one at [targetReps] or
/// more, no pain, no difficulty, no break, and a heavier weight to go to. Pain
/// or a return after a break asks for a review at the weight she had; anything
/// else holds it.
///
/// Throws [ArgumentError] for a weight that is negative or not finite, a
/// negative rep count, or a target that is not positive, before it decides
/// anything.
ProgressionDecision suggestProgression({
  required double? previousWeightKg,
  required List<int> completedReps,
  required int targetSets,
  required int targetReps,
  required List<double> availableWeightsKg,
  required bool difficult,
  required bool painReported,
  required bool returningAfterBreak,
  required bool coached,
}) {
  bool valid(double w) => w.isFinite && w >= 0;
  if (previousWeightKg != null && !valid(previousWeightKg)) {
    throw ArgumentError.value(previousWeightKg, 'previousWeightKg');
  }
  for (final w in availableWeightsKg) {
    if (!valid(w)) throw ArgumentError.value(w, 'availableWeightsKg');
  }
  if (completedReps.any((r) => r < 0)) {
    throw ArgumentError.value(completedReps, 'completedReps');
  }
  if (targetSets < 1) throw ArgumentError.value(targetSets, 'targetSets');
  if (targetReps < 1) throw ArgumentError.value(targetReps, 'targetReps');

  ProgressionDecision hold(String action) =>
      ProgressionDecision(action: action, suggestedWeightKg: previousWeightKg);

  if (previousWeightKg == null) return hold('hold');
  if (painReported || returningAfterBreak) return hold('review');
  if (difficult) return hold('hold');
  final finished =
      completedReps.length == targetSets &&
      completedReps.every((r) => r >= targetReps);
  if (!finished) return hold('hold');

  final higher = [
    for (final w in availableWeightsKg)
      if (w > previousWeightKg) w,
  ]..sort();
  if (higher.isEmpty) return hold('hold');
  return ProgressionDecision(
    action: 'increase',
    suggestedWeightKg: higher.first,
    requiresCoachApproval: coached,
  );
}
