/// The weight R07 and R08 suggest for a loaded move, from her own history.
///
/// Reads what she did the last time she trained the move
/// ([lastSessionSets]) and asks [suggestProgression] what comes next. It never
/// reads a prescription for a figure and never writes one: the answer is a
/// weight and a reason for R07 to show and for R08 to offer among its chips.
///
/// She is never asked whether it hurt or was hard, so neither is assumed:
/// pain and difficulty are not signals this app collects, and inventing them
/// here would be a claim about her body. A break of three weeks or more is
/// the one thing that is known.
library;

import '../../../domain/clock/app_clock.dart';
import '../../../domain/training/prescribed_set.dart';
import 'progression_policy.dart';
import 'set_history.dart';
import 'train_repository.dart';

/// Loads she may pick from, in kg. Dumbbells, plates and machine stacks share
/// one ladder: the next step up is the next number on it.
const List<double> kLoadStepsKg = [
  2,
  3,
  4,
  5,
  6,
  8,
  10,
  12,
  14,
  16,
  18,
  20,
  22.5,
  25,
  27.5,
  30,
  35,
  40,
  45,
  50,
  55,
  60,
];

/// What R08 offers for a loaded move she has no history on, so the first
/// session can still record a weight.
const List<double> kStarterWeightsKg = [4, 6, 8, 10, 12, 15, 20, 25, 30];

/// Days away after which a loaded move asks for a lighter start.
const int kBreakDays = 21;

/// A suggestion, and the weights R08 offers around it.
class LoadAdvice {
  const LoadAdvice({
    required this.decision,
    required this.lastWeightKg,
    required this.startKg,
    required this.optionsKg,
  });

  final ProgressionDecision decision;

  /// What she lifted last time.
  final double lastWeightKg;

  /// The weight the screens open on: a step up after a finished session, a step
  /// down when she is back from a break, otherwise what she lifted.
  final double startKg;

  /// The last weight, the one below it and the suggestion, in order.
  final List<double> optionsKg;
}

/// Advice for [move], or null when it is not a loaded move or she has no
/// weighed history on it.
LoadAdvice? loadAdviceFor(
  TrainRepository? repository,
  PlannedMove? move, {
  String? exceptSessionId,
  bool coached = false,
  DateTime? now,
}) {
  if (move == null || !move.needsEquipment || move.sets.isEmpty) return null;
  final targetReps = [
    for (final s in move.sets)
      if (s.reps != null) s.reps!,
  ];
  if (targetReps.isEmpty) return null;

  final history = lastSessionSets(
    repository,
    move.exerciseId,
    exceptSessionId: exceptSessionId,
  );
  if (history == null) return null;
  final weights = [
    for (final s in history.sets)
      if (s.weightKg != null && s.weightKg! > 0) s.weightKg!,
  ];
  if (weights.isEmpty) return null;
  final previous = weights.last;

  final day = DateTime.tryParse(history.dateKey ?? '');
  final away = day == null ? 0 : (now ?? AppClock.now()).difference(day).inDays;

  final ladder = {...kLoadStepsKg, previous}.toList()..sort();
  final decision = suggestProgression(
    previousWeightKg: previous,
    completedReps: [for (final s in history.sets) s.reps ?? 0],
    targetSets: move.sets.length,
    targetReps: targetReps.reduce((a, b) => a < b ? a : b),
    availableWeightsKg: ladder,
    difficult: false,
    painReported: false,
    returningAfterBreak: away >= kBreakDays,
    coached: coached,
  );
  final below = ladder.where((w) => w < previous).lastOrNull;
  final options = {?below, previous, ?decision.suggestedWeightKg}.toList()
    ..sort();
  return LoadAdvice(
    decision: decision,
    lastWeightKg: previous,
    startKg: decision.action == 'review'
        ? (below ?? previous)
        : (decision.suggestedWeightKg ?? previous),
    optionsKg: options,
  );
}

/// [move] with its sets carrying [kg], for the screen that shows the weight she
/// is about to agree to. The sets are what she is *asked* for: nothing is
/// logged until she taps the button that names the numbers.
PlannedMove withSuggestedWeight(PlannedMove move, double kg, String label) =>
    PlannedMove(
      exerciseId: move.exerciseId,
      name: move.name,
      prescriptionLabel: '$label · ${move.prescriptionLabel}',
      sets: [
        for (final s in move.sets)
          PrescribedSet(
            exerciseId: s.exerciseId,
            order: s.order,
            weightKg: s.weightKg ?? kg,
            reps: s.reps,
            holdSeconds: s.holdSeconds,
          ),
      ],
      cues: move.cues,
      quiet: move.quiet,
      needsEquipment: move.needsEquipment,
      floorOnly: move.floorOnly,
      videoAssetId: move.videoAssetId,
    );
