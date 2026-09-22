/// §2 rule 1: **a prescribed value is never a result.**
///
/// This is the rule implementers break most innocently, because pre-filling the
/// weight she was asked to lift into the box recording what she *did* lift feels
/// like a convenience. It is not: it turns a plan into a record of something that
/// may never have happened, and every number downstream — adherence, personal
/// bests, progression — inherits the lie.
///
/// Spine C8 makes it unrepresentable rather than forbidden. [PrescribedSet] has
/// no field capable of holding a result, and [SetOutcome] has no field capable of
/// holding a prescription. There is no single object with both, so there is no
/// widget that can copy one into the other by accident.
library;

import 'package:meta/meta.dart';

/// What the plan asked for. Authored by a coach or generated from her programme.
///
/// Both numbers are nullable: a bodyweight move prescribes no weight, and a
/// time-based hold prescribes no reps.
@immutable
class PrescribedSet {
  const PrescribedSet({
    required this.exerciseId,
    required this.order,
    this.weightKg,
    this.reps,
    this.holdSeconds,
  });

  final String exerciseId;
  final int order;
  final double? weightKg;
  final int? reps;
  final int? holdSeconds;

  // There is deliberately no `actual…` field, no `toOutcome()`, and no
  // `copyWith` that could produce one. To record a result you must construct a
  // SetOutcome from what she actually did.
}

/// What she actually did. Starts empty and stays empty until she logs.
@immutable
class SetOutcome {
  const SetOutcome({
    this.weightKg,
    this.reps,
    this.holdSeconds,
    this.skipped = false,
  });

  /// An explicitly skipped set. Distinct from an unlogged one: skipping is a
  /// decision she made, not-logging is an absence.
  const SetOutcome.skipped() : this(skipped: true);

  final double? weightKg;
  final int? reps;
  final int? holdSeconds;
  final bool skipped;

  /// True only when she recorded something. An unlogged set is not a zero.
  bool get isLogged => !skipped && (reps != null || holdSeconds != null);
}

/// A set as stored: the prescription, and the outcome if there is one yet.
@immutable
class LoggedSet {
  const LoggedSet({required this.prescribed, this.outcome});

  final PrescribedSet prescribed;

  /// Null until she logs. Never derived from [prescribed].
  final SetOutcome? outcome;

  bool get isLogged => outcome?.isLogged ?? false;

  /// Records a result against this prescription.
  ///
  /// Takes the outcome as an argument rather than defaulting to the prescribed
  /// numbers, so "log it as prescribed" is something the UI must say explicitly
  /// with her values, not something that happens when a field is left alone.
  LoggedSet recording(SetOutcome actual) =>
      LoggedSet(prescribed: prescribed, outcome: actual);
}

/// Adherence counts logged sets only.
///
/// A prescribed set that was never logged contributes nothing — it is not
/// counted as done, and it is not counted as failed either.
class AdherenceCalculator {
  const AdherenceCalculator();

  /// Sets she logged, over sets prescribed. Returns null for an empty session
  /// rather than 0.0, because "no sets prescribed" is not "0% adherence".
  double? ratio(List<LoggedSet> sets) {
    if (sets.isEmpty) return null;
    final logged = sets.where((s) => s.isLogged).length;
    return logged / sets.length;
  }

  /// Guard used by the session repository before a write.
  ///
  /// A session created live must be born with nothing logged (spine C8). A
  /// recalled or unplanned session is logged after the fact and is exempt.
  bool hasNoPrefill(List<LoggedSet> sets) =>
      sets.every((s) => s.outcome == null);
}
