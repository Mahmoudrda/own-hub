/// What a coach asks for — and nothing about what was done.
///
/// G14 §1.1 says the moves on a split's day slot have a shape "identical to
/// G2's `assignment.workout.moves[]` … so materialisation is a **copy, not a
/// translation**". One type therefore serves both the template and the draft,
/// and `SplitApplicator` copies values rather than mapping fields. A mapper is
/// where a field quietly goes missing.
///
/// ## There is no field here that could hold a result
///
/// §2.1: "a prescribed value is never a result", and spine C8 makes the two
/// differently-typed rather than differently-named. [PrescribedMove] carries
/// what was asked for; what she actually did lives in `SetOutcome`, in another
/// library, with no constructor that takes one of these. So "rule 1 is not a
/// discipline, it is a shape" holds here by construction, and
/// `PrescriptionOnlyValidator` is the second line rather than the first.
///
/// ## Why the load is a kind and a number, not a `weightKg`
///
/// Two reasons, and both are rules. G2's contract is
/// `prescribedLoad.kind ∈ {kg, bodyweight, seconds}`, so a bodyweight move
/// prescribes **no number at all** rather than a zero. And no type in this
/// feature may carry a `weightKg` field: nothing about a coach's planning
/// tools is allowed to become somewhere a woman's body weight could be stored
/// or ranked.
library;

import 'package:meta/meta.dart';

/// The session lengths K20 and W04 offer. Hard-bounded, per G14 §1.1.
const List<int> kSessionMinuteOptions = <int>[10, 15, 20, 30, 35, 45];

/// W04's rest-between-sets chips.
const List<int> kRestBetweenSetsOptions = <int>[30, 45, 60];

/// At most this many moves on one day. G14 §1.1's `moves` cap.
const int kMaxMovesPerDay = 20;

/// At most this many approved alternatives on one day.
const int kMaxApprovedAlternatives = 5;

/// What the load on a prescribed move *is*.
///
/// `bodyweight` carries no number, which is why this is an enum and not a
/// nullable double with a convention attached to it.
enum PrescribedLoadKind {
  kg('kg'),
  bodyweight('bodyweight'),
  seconds('seconds');

  const PrescribedLoadKind(this.wireName);

  /// The token G2's assignment stores. Never the Dart name.
  final String wireName;

  static PrescribedLoadKind? fromWire(String wire) {
    for (final kind in values) {
      if (kind.wireName == wire.trim().toLowerCase()) return kind;
    }
    return null;
  }
}

/// The load a move is prescribed with.
@immutable
class PrescribedLoad {
  const PrescribedLoad._(this.kind, this.value);

  /// A number of kilograms to reach for. The value is the *prescription*; her
  /// result is recorded elsewhere, by a different type.
  const PrescribedLoad.kg(num value) : this._(PrescribedLoadKind.kg, value);

  /// Nothing to carry. Deliberately valueless: a bodyweight move prescribing
  /// `0 kg` reads as "zero kilograms", which is a number nobody meant.
  const PrescribedLoad.bodyweight()
    : this._(PrescribedLoadKind.bodyweight, null);

  /// A hold, in seconds.
  const PrescribedLoad.seconds(int value)
    : this._(PrescribedLoadKind.seconds, value);

  final PrescribedLoadKind kind;

  /// Null for [PrescribedLoadKind.bodyweight], always.
  final num? value;

  Map<String, Object?> toWire() => <String, Object?>{
    'kind': kind.wireName,
    if (value != null) 'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is PrescribedLoad && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() =>
      'PrescribedLoad(${kind.wireName}${value == null ? '' : ' $value'})';
}

/// One move, as the plan asks for it.
@immutable
class PrescribedMove {
  const PrescribedMove({
    required this.exerciseId,
    required this.order,
    required this.sets,
    required this.load,
    this.reps,
    this.holdSeconds,
    this.note,
  });

  /// Always an id from the bundled pack. §2.10: a planner selects, it never
  /// generates — so a move that is not in the library cannot be prescribed.
  final String exerciseId;

  /// Position in the session, 1-based. Ordering is the coach's, not a ranking.
  final int order;

  final int sets;
  final PrescribedLoad load;

  /// Null for a timed hold.
  final int? reps;

  /// Null for a counted move.
  final int? holdSeconds;

  /// "Keep 12 kg and aim for 12 reps." Shown to her; never parsed.
  final String? note;

  /// A new instance carrying the same values.
  ///
  /// This is what makes "copied **by value**" checkable rather than asserted:
  /// after `SplitApplicator.materialise`, no object in the draft is the same
  /// object as one in the template, so there is nothing for a later edit of the
  /// template to reach through. A test proves it with `identical`.
  PrescribedMove copy() => PrescribedMove(
    exerciseId: exerciseId,
    order: order,
    sets: sets,
    load: load,
    reps: reps,
    holdSeconds: holdSeconds,
    note: note,
  );

  Map<String, Object?> toWire() => <String, Object?>{
    'exerciseId': exerciseId,
    'order': order,
    'sets': sets,
    'prescribedLoad': load.toWire(),
    if (reps != null) 'reps': reps,
    if (holdSeconds != null) 'holdSeconds': holdSeconds,
    if (note != null) 'note': note,
  };

  @override
  String toString() => 'PrescribedMove($exerciseId #$order)';
}

/// W04's "easier option" — a substitution the coach has approved in advance.
///
/// It exists so a woman can swap mid-session **without waiting for a reply**,
/// which is the whole point of approving it beforehand.
@immutable
class ApprovedAlternative {
  const ApprovedAlternative({
    required this.exerciseId,
    required this.forExerciseId,
  });

  final String exerciseId;
  final String forExerciseId;

  ApprovedAlternative copy() =>
      ApprovedAlternative(exerciseId: exerciseId, forExerciseId: forExerciseId);

  Map<String, Object?> toWire() => <String, Object?>{
    'exerciseId': exerciseId,
    'forExerciseId': forExerciseId,
  };

  @override
  bool operator ==(Object other) =>
      other is ApprovedAlternative &&
      other.exerciseId == exerciseId &&
      other.forExerciseId == forExerciseId;

  @override
  int get hashCode => Object.hash(exerciseId, forExerciseId);

  @override
  String toString() => 'ApprovedAlternative($exerciseId for $forExerciseId)';
}
