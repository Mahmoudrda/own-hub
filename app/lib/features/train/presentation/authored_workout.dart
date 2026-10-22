/// A session from the workout library, as the Train screens already draw one.
///
/// The labels are built here, from the dictionary, because they are copy: the
/// owner writes the numbers and the names, and the app says "3 × 12" in the
/// language the member reads.
library;

import '../../../domain/format/day_key.dart';
import '../../../domain/format/number_label.dart';
import '../domain/weight_label.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../domain/custom_workout.dart';
import '../domain/exercise_library.dart';
import '../domain/train_repository.dart';
import '../domain/workout_library.dart';

String _pick(String languageCode, String en, String ar) {
  final mine = languageCode == 'ar' ? ar : en;
  return mine.trim().isNotEmpty ? mine : (languageCode == 'ar' ? en : ar);
}

/// "3 × 12 · Rest 60 seconds". In Arabic each half is its own isolate, so the
/// digits and the Arabic words keep their order inside a right-to-left row
/// instead of the halves swapping places.
String _joined(String languageCode, String amount, String rest) {
  if (languageCode != 'ar') return rest.isEmpty ? amount : '$amount · $rest';
  const open = '\u2068';
  const close = '\u2069';
  final first = '$open$amount$close';
  return rest.isEmpty ? first : '$first · $open$rest$close';
}

/// One move, with its sets prescribed and nothing logged (spine C8).
PlannedMove plannedMoveFrom(
  AppL10n l10n,
  String languageCode,
  AuthoredMove move,
) {
  final amount = move.reps != null
      ? l10n.setsReps(countLabel(move.sets), countLabel(move.reps!))
      : l10n.setsSecondsSeconds(
          countLabel(move.sets),
          countLabel(move.holdSeconds ?? 0),
        );
  final rest = move.restSeconds > 0
      ? l10n.restSecondsSeconds(countLabel(move.restSeconds))
      : '';
  return PlannedMove(
    exerciseId: move.exerciseId,
    name: move.nameEn.trim().isNotEmpty ? move.nameEn : move.nameAr,
    prescriptionLabel: _joined(languageCode, amount, rest),
    quiet: move.quiet,
    floorOnly: move.floorOnly,
    needsEquipment: move.needsEquipment,
    restSeconds: move.restSeconds > 0 ? move.restSeconds : null,
    // The safety line first: it is the one she must not miss.
    cues: [
      for (final text in [
        _pick(languageCode, move.safetyEn, move.safetyAr),
        _pick(languageCode, move.notesEn, move.notesAr),
      ])
        if (text.trim().isNotEmpty) text.trim(),
    ],
    sets: [
      for (var i = 1; i <= move.sets; i++)
        PrescribedSet(
          exerciseId: move.exerciseId,
          order: i,
          reps: move.reps,
          holdSeconds: move.holdSeconds,
        ),
    ],
  );
}

/// The session as today's [WorkoutDay]. Its id is today's day key, the same
/// as the bundled session's, so the session she starts is filed under the day
/// she trained and never under a library id.
WorkoutDay workoutDayFrom(
  AppL10n l10n,
  String languageCode,
  AuthoredProgramme programme,
  AuthoredSession session, {
  required DateTime now,
}) {
  final moves = [
    for (final m in session.moves) plannedMoveFrom(l10n, languageCode, m),
  ];
  return WorkoutDay(
    id: dayKey(now),
    title: session.title(languageCode),
    summary: l10n.minutesMinutesMovesMoves(
      countLabel(session.minutes),
      countLabel(moves.length),
    ),
    constraints: programme.titleEn.isEmpty && programme.titleAr.isEmpty
        ? ''
        : _pick(languageCode, programme.titleEn, programme.titleAr),
    moves: moves,
    planVersion: '${programme.programId}@${programme.version}',
  );
}

/// The Explore row for a session.
LibraryWorkout libraryRowFrom(
  AppL10n l10n,
  String languageCode,
  AuthoredProgramme programme,
  AuthoredSession session,
) => LibraryWorkout(
  id: libraryRowId(programme.programId, session.sessionId),
  title: session.title(languageCode),
  detail:
      '${l10n.nMin(countLabel(session.minutes))} · '
      '${_pick(languageCode, programme.titleEn, programme.titleAr)}',
  quiet: session.quiet,
  needsEquipment: session.needsEquipment,
  minutes: session.minutes,
  exerciseIds: [for (final move in session.moves) move.exerciseId],
);

String _humanise(String exerciseId) {
  final words = exerciseId.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return exerciseId;
  final text = words.join(' ');
  return text[0].toUpperCase() + text.substring(1);
}

/// "3 × 12", or "3 × 30 seconds", with the target weight after it when there
/// is one. Bodyweight says nothing rather than "0 kg".
String customLoadLabel(AppL10n l10n, String languageCode, CustomMove move) {
  final amount = move.timed
      ? l10n.setsSecondsSeconds(
          countLabel(move.sets),
          countLabel(move.holdSeconds ?? 0),
        )
      : l10n.setsReps(countLabel(move.sets), countLabel(move.reps ?? 0));
  final weight = move.weightKg;
  if (weight == null) return amount;
  final kg = '${weightLabel(weight)} ${l10n.kg}';
  return _joined(languageCode, amount, kg);
}

/// One move of a custom workout as the day draws it. The name, the flags and
/// the setup cue come from [exercise] when the library holds it, else from
/// [like], the move this one replaces or edits.
PlannedMove plannedMoveFromCustom(
  AppL10n l10n,
  String languageCode,
  CustomMove move, {
  LibraryExercise? exercise,
  PlannedMove? like,
}) {
  final setup = exercise?.setup(languageCode)?.trim();
  return PlannedMove(
    exerciseId: move.exerciseId,
    name:
        exercise?.name(languageCode) ??
        like?.name ??
        _humanise(move.exerciseId),
    prescriptionLabel: customLoadLabel(l10n, languageCode, move),
    quiet: exercise?.quiet ?? like?.quiet ?? false,
    floorOnly: exercise?.floorOnly ?? like?.floorOnly ?? false,
    needsEquipment: exercise != null
        ? !(exercise.needsNothing ||
              exercise.equipment.every(
                (e) => e == LibraryEquipment.none || e == LibraryEquipment.mat,
              ))
        : like?.needsEquipment ?? false,
    cues: setup != null && setup.isNotEmpty
        ? [setup]
        : (like?.cues ?? const <String>[]),
    videoAssetId: like?.videoAssetId,
    restSeconds: like?.restSeconds,
    sets: [
      for (var i = 1; i <= move.sets; i++)
        PrescribedSet(
          exerciseId: move.exerciseId,
          order: i,
          weightKg: move.weightKg,
          reps: move.reps,
          holdSeconds: move.holdSeconds,
        ),
    ],
  );
}

/// [moves] as today's [WorkoutDay]. The id is today's day key, never the id of
/// a saved workout, for the reason `sampleWorkoutDay` gives.
WorkoutDay customWorkoutDay(
  AppL10n l10n, {
  required String name,
  required List<PlannedMove> moves,
  required DateTime now,
  String constraints = '',
  String? planVersion,
}) => WorkoutDay(
  id: dayKey(now),
  title: name.trim().isEmpty ? l10n.myWorkout : name.trim(),
  summary: l10n.minutesMinutesMovesMoves(
    countLabel(estimateMinutes(moves)),
    countLabel(moves.length),
  ),
  constraints: constraints,
  moves: moves,
  planVersion: planVersion,
);
