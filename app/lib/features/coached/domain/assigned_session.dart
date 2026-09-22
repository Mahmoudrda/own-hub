/// Running a session her coach assigned — G06, G07, G08, G09.
///
/// This is G4's player wearing the coach's numbers. This feature owns none of
/// the session schema: the sets are G4's `LoggedSet`, the undo is G3's
/// `LogCommandBus`, and the rest timer is a value computed from *her coach's*
/// `restSec` rather than a product default.
///
/// ## Three properties that are rules
///
///  1. **A prescription is never a result.** [AssignedSession.start] builds one
///     `LoggedSet` per prescribed set with a null outcome and refuses to start
///     if anything arrives already logged — the same assertion
///     `InMemoryTrainRepository` makes, restated at this boundary because a
///     coached session is a second way in.
///  2. **Coach approval is never required to stop.** [stop] takes no coach, no
///     reason and no message. It cannot send anything: this file does not
///     import the message repository at all, so "finish early" is structurally
///     incapable of waiting for a reply. `P0-ASSIGN-01` asserts it.
///  3. **A swap is today only.** [swap] records a substitution on the running
///     session and returns a session whose moves differ; nothing it returns can
///     be written to a published plan, because nothing here can address one.
///
/// ## Rest seconds
///
/// [restFor] returns null when the coach set none, and a null is *not* a zero
/// and *not* a default. G07 may only say "Sara set 45 seconds between these
/// sets" when she actually did; with no coach seconds the screen falls back to
/// the app's own rest copy, which claims nothing about her.
library;

import 'package:meta/meta.dart';

import '../../../domain/training/prescribed_set.dart';
import 'g2_contract.dart';

/// How hard it felt. G09's three chips.
enum SessionEffort { easy, aboutRight, hard }

/// How a session ended.
///
/// `stoppedEarly` is a decision she made and is recorded as one. It is not a
/// failure, it needs nobody's approval, and the summary counts what she did
/// rather than what was left.
enum SessionEnd { finished, stoppedEarly }

/// A move as it is being run: the coach's prescription, her outcomes so far,
/// and whatever she swapped it for.
@immutable
class RunningMove {
  const RunningMove({
    required this.assigned,
    required this.sets,
    this.swappedFor,
    this.skipped = false,
  });

  final AssignedMove assigned;

  /// One per prescribed set. Every outcome starts null.
  final List<LoggedSet> sets;

  /// The approved alternative she chose, if she swapped.
  final ApprovedAlternative? swappedFor;

  /// Explicitly skipped — distinct from unlogged, which is an absence.
  final bool skipped;

  /// What the screen shows as the move's name.
  String get name => swappedFor?.name ?? assigned.name;

  /// Her coach's seconds between these sets, or null when she set none.
  int? get restSec => assigned.restSec;

  /// Sets with an outcome. Never counts a prescription.
  int get loggedSetCount => sets.where((s) => s.isLogged).length;

  int get skippedSetCount =>
      sets.where((s) => s.outcome?.skipped ?? false).length;

  RunningMove recording(int index, SetOutcome outcome) {
    final next = List<LoggedSet>.of(sets);
    next[index] = next[index].recording(outcome);
    return RunningMove(
      assigned: assigned,
      sets: next,
      swappedFor: swappedFor,
      skipped: skipped,
    );
  }

  RunningMove swappedTo(ApprovedAlternative alternative) => RunningMove(
    assigned: assigned,
    sets: sets,
    swappedFor: alternative,
    skipped: skipped,
  );

  RunningMove markSkipped() => RunningMove(
    assigned: assigned,
    sets: sets,
    swappedFor: swappedFor,
    skipped: true,
  );

  @override
  String toString() => 'RunningMove($name $loggedSetCount/${sets.length})';
}

/// A coached session in progress.
@immutable
class AssignedSession {
  const AssignedSession({
    required this.id,
    required this.dateKey,
    required this.planVersion,
    required this.moves,
    required this.workout,
    this.end,
    this.effort,
    this.note,
    this.durationSec = 0,
  });

  /// Minted once, reused on every retry, so a replayed offline write collides
  /// with itself rather than creating a second session.
  final String id;

  final String dateKey;

  /// **Pinned at start and never re-read.** A revision published while this is
  /// running changes nothing that is running or already logged.
  final String planVersion;

  final AssignedWorkout workout;
  final List<RunningMove> moves;

  final SessionEnd? end;
  final SessionEffort? effort;

  /// "Knees felt fine today." Optional, and optional means null.
  final String? note;

  final int durationSec;

  bool get isFinished => end != null;

  int get setsLogged => moves.fold(0, (sum, m) => sum + m.loggedSetCount);

  int get setsPrescribed => moves.fold(0, (sum, m) => sum + m.sets.length);

  int get setsSkipped => moves.fold(0, (sum, m) => sum + m.skippedSetCount);

  /// The moves she skipped outright, by name.
  List<String> get skippedMoves =>
      moves.where((m) => m.skipped).map((m) => m.name).toList();

  AssignedSession copyWith({
    List<RunningMove>? moves,
    SessionEnd? end,
    SessionEffort? effort,
    String? note,
    int? durationSec,
  }) => AssignedSession(
    id: id,
    dateKey: dateKey,
    planVersion: planVersion,
    workout: workout,
    moves: moves ?? this.moves,
    end: end ?? this.end,
    effort: effort ?? this.effort,
    note: note ?? this.note,
    durationSec: durationSec ?? this.durationSec,
  );

  @override
  String toString() =>
      'AssignedSession($id @$planVersion $setsLogged/$setsPrescribed)';
}

/// What G09 reports.
///
/// Built only from outcomes. `setsCompleted` counts sets with a result;
/// `setsPrescribed` is the denominator and is labelled as one. There is no
/// field here that a prescription could be copied into.
@immutable
class SessionSummary {
  const SessionSummary({
    required this.setsCompleted,
    required this.setsPrescribed,
    required this.setsSkipped,
    required this.skippedMoves,
    required this.end,
    this.durationSec = 0,
  });

  final int setsCompleted;
  final int setsPrescribed;
  final int setsSkipped;
  final List<String> skippedMoves;
  final SessionEnd end;
  final int durationSec;

  /// Null rather than 0.0 for an empty session: "no sets prescribed" is not
  /// "0% adherence".
  double? get ratio =>
      setsPrescribed == 0 ? null : setsCompleted / setsPrescribed;

  @override
  String toString() =>
      'SessionSummary($setsCompleted/$setsPrescribed, ${end.name})';
}

/// Starts, runs, swaps, stops and finishes a coached session.
///
/// Every method is a pure function from a session to a session, so the whole of
/// G06–G09's behaviour is testable with no widget and no repository.
class AssignedSessionController {
  const AssignedSessionController();

  /// Begins the session for [assignment].
  ///
  /// Throws when the assignment has no workout — an assignment with no workout
  /// is a rest day, and starting one is a caller's mistake rather than an empty
  /// screen.
  AssignedSession start(CoachAssignment assignment, {String? sessionId}) {
    final workout = assignment.workout;
    if (workout == null) {
      throw StateError(
        'There is no workout on ${assignment.dateKey}. Absence means rest.',
      );
    }

    final moves = <RunningMove>[];
    for (final move in workout.moves) {
      final sets = [for (final p in move.sets) LoggedSet(prescribed: p)];
      // Spine C8 at this boundary too. A coached session is a second way in,
      // and a second way in is where a rule quietly stops applying.
      if (!const AdherenceCalculator().hasNoPrefill(sets)) {
        throw StateError(
          'A session cannot be born with anything logged. A prescribed value '
          'is never a result (spine C8).',
        );
      }
      moves.add(RunningMove(assigned: move, sets: sets));
    }

    return AssignedSession(
      // Deterministic in the date and the version, so a retry collapses.
      id:
          sessionId ??
          'coached-${assignment.dateKey}-${assignment.planVersion}',
      dateKey: assignment.dateKey,
      planVersion: assignment.planVersion,
      workout: workout,
      moves: moves,
    );
  }

  /// Records one set's outcome.
  ///
  /// Takes the outcome rather than defaulting to the prescription, so "as
  /// prescribed" is something the screen says with her numbers and never
  /// something that happens because a field was left alone.
  AssignedSession recordSet(
    AssignedSession session, {
    required int moveIndex,
    required int setIndex,
    required SetOutcome outcome,
  }) {
    final moves = List<RunningMove>.of(session.moves);
    moves[moveIndex] = moves[moveIndex].recording(setIndex, outcome);
    return session.copyWith(moves: moves);
  }

  /// The coach's rest seconds for a move, or null when she set none.
  int? restFor(AssignedSession session, int moveIndex) =>
      session.moves[moveIndex].restSec;

  /// Swaps a move for one the coach approved in advance.
  ///
  /// Throws when the alternative is not on the assignment's own list: an
  /// unapproved swap is a different act (asking her), and letting it through
  /// here would make "coach-approved" a label rather than a fact.
  AssignedSession swap(
    AssignedSession session, {
    required int moveIndex,
    required String toExerciseId,
  }) {
    final move = session.moves[moveIndex];
    final approved = move.assigned.alternatives
        .where((a) => a.exerciseId == toExerciseId)
        .toList();
    if (approved.isEmpty) {
      throw StateError(
        '$toExerciseId is not on the approved list for ${move.assigned.name}. '
        'Approved first, ask second.',
      );
    }
    final moves = List<RunningMove>.of(session.moves);
    moves[moveIndex] = move.swappedTo(approved.first);
    return session.copyWith(moves: moves);
  }

  /// Skips a move. Needs no approval and sends nothing.
  AssignedSession skipMove(AssignedSession session, {required int moveIndex}) {
    final moves = List<RunningMove>.of(session.moves);
    moves[moveIndex] = moves[moveIndex].markSkipped();
    return session.copyWith(moves: moves);
  }

  /// Ends the session early.
  ///
  /// **No coach parameter, no reason, no message.** An assigned session is
  /// still hers to stop, and this method's signature is where that is true.
  AssignedSession stop(AssignedSession session, {int durationSec = 0}) =>
      session.copyWith(end: SessionEnd.stoppedEarly, durationSec: durationSec);

  /// Ends the session normally.
  AssignedSession finish(
    AssignedSession session, {
    int durationSec = 0,
    SessionEffort? effort,
    String? note,
  }) => session.copyWith(
    end: SessionEnd.finished,
    durationSec: durationSec,
    effort: effort,
    note: note,
  );

  /// G09's numbers, counted from outcomes only.
  SessionSummary summarise(AssignedSession session) => SessionSummary(
    setsCompleted: session.setsLogged,
    setsPrescribed: session.setsPrescribed,
    setsSkipped: session.setsSkipped,
    skippedMoves: session.skippedMoves,
    end: session.end ?? SessionEnd.finished,
    durationSec: session.durationSec,
  );
}
