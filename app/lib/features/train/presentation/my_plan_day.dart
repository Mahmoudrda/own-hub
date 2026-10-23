/// A day of her plan as R03 lists it: the split's own reading of the session,
/// with her target weights put back on the sets.
library;

import '../../../domain/format/number_label.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../domain/custom_workout.dart' show estimateMinutes;
import '../domain/train_repository.dart';
import '../domain/weight_label.dart';

/// [day] with a target weight on every move that has one in [kg] (in the order
/// of the moves). A move without one is left as it is, bodyweight or not.
WorkoutDay withTargetWeights(
  AppL10n l10n,
  String languageCode,
  WorkoutDay day,
  List<double?> kg,
) {
  if (kg.every((w) => w == null)) return day;
  String label(PlannedMove move, double weight) {
    final text = '${weightLabel(weight)} ${l10n.kg}';
    final part = languageCode == 'ar' ? '\u2068$text\u2069' : text;
    return move.prescriptionLabel.isEmpty
        ? part
        : '${move.prescriptionLabel} · $part';
  }

  return WorkoutDay(
    id: day.id,
    title: day.title,
    summary: day.summary,
    constraints: day.constraints,
    planVersion: day.planVersion,
    moves: [
      for (var i = 0; i < day.moves.length; i++)
        if (i < kg.length && kg[i] != null)
          PlannedMove(
            exerciseId: day.moves[i].exerciseId,
            name: day.moves[i].name,
            prescriptionLabel: label(day.moves[i], kg[i]!),
            quiet: day.moves[i].quiet,
            floorOnly: day.moves[i].floorOnly,
            needsEquipment: day.moves[i].needsEquipment,
            cues: day.moves[i].cues,
            videoAssetId: day.moves[i].videoAssetId,
            restSeconds: day.moves[i].restSeconds,
            sets: [
              for (final set in day.moves[i].sets)
                PrescribedSet(
                  exerciseId: set.exerciseId,
                  order: set.order,
                  weightKg: kg[i],
                  reps: set.reps,
                  holdSeconds: set.holdSeconds,
                ),
            ],
          )
        else
          day.moves[i],
    ],
  );
}

/// [day] without the moves in [blocked], the ones her life stage does not
/// allow, with its summary counted again. Null when none are left. A day of her
/// plan goes through the same screening as the catalogue and today's edits.
WorkoutDay? withoutBlockedMoves(
  AppL10n l10n,
  WorkoutDay day,
  Set<String> blocked,
) {
  if (blocked.isEmpty) return day;
  final kept = [
    for (final m in day.moves)
      if (!blocked.contains(m.exerciseId)) m,
  ];
  if (kept.isEmpty) return null;
  if (kept.length == day.moves.length) return day;
  return WorkoutDay(
    id: day.id,
    title: day.title,
    summary: l10n.minutesMinutesMovesMoves(
      countLabel(estimateMinutes(kept)),
      countLabel(kept.length),
    ),
    constraints: day.constraints,
    moves: kept,
    planVersion: day.planVersion,
  );
}
