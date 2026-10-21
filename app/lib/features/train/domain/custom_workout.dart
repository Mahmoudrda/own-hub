/// A workout she built herself, and the bounds every edit to one keeps.
///
/// A custom workout stores which moves, in which order, with how many sets of
/// how many reps (or seconds) at what target weight. It stores no names and no
/// labels: those are read from the exercise library and the dictionary when the
/// workout is drawn, so a language switch or a renamed move never leaves a
/// stale copy of either behind.
///
/// Nothing here is a result. A target weight is a prescription like any other
/// (spine C8): the session built from it starts with every outcome null.
library;

import 'package:meta/meta.dart';

import 'exercise_library.dart';
import 'train_repository.dart';

const int kMinSets = 1;
const int kMaxSets = 10;
const int kMinReps = 1;
const int kMaxReps = 50;
const int kMinHoldSeconds = 5;
const int kMaxHoldSeconds = 300;
const int kHoldStepSeconds = 5;
const double kMinWeightKg = 1;
const double kMaxWeightKg = 200;
const double kWeightStepKg = 0.5;

/// Most moves one workout holds, and most workouts she can keep.
const int kMaxCustomMoves = 20;
const int kMaxCustomWorkouts = 30;
const int kMaxCustomNameLength = 40;

/// How many deletions are remembered so a deleted workout does not come back
/// from the cloud.
const int kMaxDeletedWorkouts = 100;

/// The `schemaV` a split document is written with.
const int kSplitSchema = 1;

/// One move of a custom workout: exactly one of [reps] and [holdSeconds].
@immutable
class CustomMove {
  const CustomMove({
    required this.exerciseId,
    this.sets = 3,
    this.reps,
    this.holdSeconds,
    this.weightKg,
  }) : assert(
         (reps == null) != (holdSeconds == null),
         'a move is counted in reps or in seconds, never both and never neither',
       );

  /// What a move starts as when she adds it: a timed hold for stretches and
  /// the two patterns that are held, repetitions for everything else.
  factory CustomMove.starter(LibraryExercise exercise) {
    final timed =
        exercise.kind == ExerciseKind.stretch ||
        exercise.pattern == 'mobility' ||
        exercise.pattern == 'core_anti_extension';
    return CustomMove(
      exerciseId: exercise.id,
      sets: exercise.kind == ExerciseKind.stretch ? 2 : 3,
      reps: timed ? null : 10,
      holdSeconds: timed ? 30 : null,
    );
  }

  final String exerciseId;
  final int sets;
  final int? reps;
  final int? holdSeconds;

  /// A target, in kilograms. Null is bodyweight, never zero.
  final double? weightKg;

  bool get timed => holdSeconds != null;

  /// Stays inside the bounds whatever it is handed.
  CustomMove copyWith({
    int? sets,
    int? reps,
    int? holdSeconds,
    double? weightKg,
    bool clearWeight = false,
    bool? timed,
  }) {
    final wantTimed = timed ?? this.timed;
    final nextSets = (sets ?? this.sets).clamp(kMinSets, kMaxSets);
    final nextWeight = clearWeight ? null : (weightKg ?? this.weightKg);
    return CustomMove(
      exerciseId: exerciseId,
      sets: nextSets,
      reps: wantTimed
          ? null
          : (reps ?? this.reps ?? 10).clamp(kMinReps, kMaxReps),
      holdSeconds: wantTimed
          ? (holdSeconds ?? this.holdSeconds ?? 30).clamp(
              kMinHoldSeconds,
              kMaxHoldSeconds,
            )
          : null,
      weightKg: nextWeight == null || nextWeight < kMinWeightKg
          ? null
          : nextWeight.clamp(kMinWeightKg, kMaxWeightKg).toDouble(),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'exerciseId': exerciseId,
    'sets': sets,
    'reps': ?reps,
    'holdSeconds': ?holdSeconds,
    'weightKg': ?weightKg,
  };

  /// Null for anything that is not a move, so one bad row costs that row.
  static CustomMove? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['exerciseId'];
    if (id is! String || id.isEmpty || id.length > 64) return null;
    int? whole(Object? v) => v is num && v.isFinite ? v.round() : null;
    final reps = whole(raw['reps']);
    final hold = whole(raw['holdSeconds']);
    final weight = raw['weightKg'];
    final timed = hold != null && reps == null;
    return CustomMove(exerciseId: id, reps: 10).copyWith(
      sets: whole(raw['sets']) ?? 3,
      timed: timed,
      reps: reps,
      holdSeconds: hold,
      weightKg: weight is num && weight.isFinite ? weight.toDouble() : null,
      clearWeight: weight is! num || !weight.isFinite,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomMove &&
      other.exerciseId == exerciseId &&
      other.sets == sets &&
      other.reps == reps &&
      other.holdSeconds == holdSeconds &&
      other.weightKg == weightKg;

  @override
  int get hashCode =>
      Object.hash(exerciseId, sets, reps, holdSeconds, weightKg);
}

/// A saved workout.
@immutable
class CustomWorkout {
  const CustomWorkout({
    required this.id,
    required this.name,
    required this.moves,
    this.updatedAt,
  });

  final String id;
  final String name;
  final List<CustomMove> moves;
  final DateTime? updatedAt;

  CustomWorkout copyWith({
    String? name,
    List<CustomMove>? moves,
    DateTime? updatedAt,
  }) => CustomWorkout(
    id: id,
    name: name ?? this.name,
    moves: moves ?? this.moves,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'moves': [for (final move in moves) move.toJson()],
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
  };

  static CustomWorkout? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    if (id is! String || !isCustomWorkoutId(id)) return null;
    final name = cleanWorkoutName(raw['name']);
    final rows = raw['moves'];
    if (rows is! List) return null;
    final moves = <CustomMove>[
      for (final row in rows) ?CustomMove.tryParse(row),
    ].take(kMaxCustomMoves).toList();
    if (moves.isEmpty) return null;
    final stamp = raw['updatedAt'];
    return CustomWorkout(
      id: id,
      name: name,
      moves: moves,
      updatedAt: stamp is String ? DateTime.tryParse(stamp) : null,
    );
  }
}

final RegExp _workoutId = RegExp(r'^[a-z0-9_-]{1,40}$');

/// A document id the rules and the cloud both accept.
bool isCustomWorkoutId(String id) => _workoutId.hasMatch(id);

/// Her name for a workout: trimmed, one line, not longer than the field. Empty
/// stays empty, and the caller fills in "My workout".
String cleanWorkoutName(Object? raw) {
  if (raw is! String) return '';
  final one = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length > kMaxCustomNameLength
      ? one.substring(0, kMaxCustomNameLength).trim()
      : one;
}

/// The move's load as the day lists it, read back from [move].
CustomMove customMoveOf(PlannedMove move) {
  final first = move.sets.isEmpty ? null : move.sets.first;
  final hold = first?.holdSeconds;
  return CustomMove(
    exerciseId: move.exerciseId,
    sets: move.sets.isEmpty ? 3 : move.sets.length,
    reps: hold == null ? (first?.reps ?? 10) : null,
    holdSeconds: hold,
    weightKg: first?.weightKg,
  ).copyWith();
}

/// A rounded guess at how long the moves take: forty-five seconds of rest
/// after each set, three seconds a rep. Never under five minutes.
int estimateMinutes(Iterable<PlannedMove> moves) =>
    estimateMinutesOf([for (final move in moves) customMoveOf(move)]);

/// [estimateMinutes] for moves not yet turned into a day.
int estimateMinutesOf(Iterable<CustomMove> moves) {
  var seconds = 0;
  for (final move in moves) {
    final work = move.holdSeconds ?? (move.reps ?? 10) * 3;
    seconds += move.sets * (work + 45);
  }
  final rounded = (seconds / 300).round() * 5;
  return rounded < 5 ? 5 : rounded;
}

/// Whether a target weight means something for this move.
bool usesWeights(LibraryExercise exercise) => exercise.equipment.any(
  (item) => switch (item) {
    LibraryEquipment.dumbbells ||
    LibraryEquipment.kettlebell ||
    LibraryEquipment.barbell ||
    LibraryEquipment.cable ||
    LibraryEquipment.machine ||
    LibraryEquipment.smithMachine => true,
    _ => false,
  },
);
