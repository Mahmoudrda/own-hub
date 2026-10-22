/// What she actually lifted last time, for the screens that talk about it.
///
/// R07 carried a sage note reading "Last Tuesday: 10 kg × 10, every set
/// finished. So we added 2 kg." It was guarded by `statesHerFigure` against the
/// prescription `(12, 10)` — a good guard, defeated by the fact that the one
/// workout in the build prescribed exactly 12 kg × 10 to everybody. So the very
/// first set a woman was ever asked to do cited a Tuesday she had not trained.
///
/// A progression note is a claim about her history, so it has to be read from
/// her history. This is where that read lives.
///
/// ## Why the flushes and not the sessions
///
/// [InMemoryTrainRepository] keeps two things. `sessions` holds the session
/// documents, whose `sets` are the *prescriptions* the session was born with —
/// `flushMove` never writes an outcome back into them, exactly as the real
/// collection would not before the Cloud Function ran. `flushes` is the record
/// of what reached the server, and a [LoggedSet] in a flush carries the outcome
/// she agreed to. Her history is the second one.
///
/// ## Why the live session is excluded
///
/// "Last time" means a previous session, not the set she did ninety seconds
/// ago. Passing the live session id keeps the note about progression between
/// sessions rather than about the set she is in the middle of.
library;

import '../../../domain/training/prescribed_set.dart';
import 'train_repository.dart';

/// The most recent set she logged for [exerciseId], or null when she has never
/// logged one.
///
/// Returns null for anything that is not an [InMemoryTrainRepository]: there is
/// no history read on the [TrainRepository] interface (G4 reads the libraries
/// and writes one collection), and inventing one here would put a query on
/// every implementation for the sake of one sage note. Null is the honest
/// answer for a repository that cannot say.
SetOutcome? lastLoggedOutcome(
  TrainRepository? repository,
  String? exerciseId, {
  String? exceptSessionId,
}) {
  if (exerciseId == null) return null;
  if (repository is! InMemoryTrainRepository) return null;

  for (final flush in repository.flushes.reversed) {
    if (flush.exerciseId != exerciseId) continue;
    if (exceptSessionId != null && flush.sessionId == exceptSessionId) continue;
    if (_abandoned(repository, flush.sessionId)) continue;
    for (final set in flush.sets.reversed) {
      final outcome = set.outcome;
      // A skipped set is an absence, not a result — the same rule
      // `measured_sets.dart` applies before anything is compared.
      if (outcome != null && outcome.isLogged) return outcome;
    }
  }
  return null;
}

/// What she did on [exerciseId] the last time she trained it, as the sets in
/// order, and the day of that session.
///
/// Every set that session logged for the move, not only the last one: a
/// progression is about whether all of them were finished. Null when she has
/// never logged the move, or for a repository that cannot say (see
/// [lastLoggedOutcome]).
({List<SetOutcome> sets, String? dateKey})? lastSessionSets(
  TrainRepository? repository,
  String? exerciseId, {
  String? exceptSessionId,
}) {
  if (exerciseId == null) return null;
  if (repository is! InMemoryTrainRepository) return null;

  String? last;
  for (final flush in repository.flushes.reversed) {
    if (flush.exerciseId != exerciseId) continue;
    if (exceptSessionId != null && flush.sessionId == exceptSessionId) continue;
    if (_abandoned(repository, flush.sessionId)) continue;
    if (flush.sets.any((s) => s.isLogged)) {
      last = flush.sessionId;
      break;
    }
  }
  if (last == null) return null;
  final sets = <SetOutcome>[
    for (final flush in repository.flushes)
      if (flush.sessionId == last && flush.exerciseId == exerciseId)
        for (final set in flush.sets)
          if (set.outcome != null && set.outcome!.isLogged) set.outcome!,
  ];
  return (sets: sets, dateKey: repository.sessionById(last)?.dateKey);
}

/// A workout she discarded keeps its flushes in the list; none of it is
/// history. A flush whose session is not known is kept, as before.
bool _abandoned(InMemoryTrainRepository repository, String sessionId) =>
    repository.sessionById(sessionId)?.endedReason == EndedReason.abandoned;

/// One finished session of one move.
typedef MoveSessionHistory = ({
  String sessionId,
  String dateKey,
  List<SetOutcome> sets,
  SetOutcome? best,
});

/// Her last [limit] finished sessions of [exerciseId], newest first.
///
/// Only sessions that finished and counted: a workout still under way or one
/// she discarded is not history. Within a session a set logged twice reads as
/// its latest outcome. Empty for a repository that cannot say.
List<MoveSessionHistory> moveHistory(
  TrainRepository? repository,
  String exerciseId, {
  int limit = 5,
}) {
  if (repository is! InMemoryTrainRepository || limit <= 0) return const [];

  final seen = <String>[];
  for (final flush in repository.flushes) {
    if (flush.exerciseId == exerciseId && !seen.contains(flush.sessionId)) {
      seen.add(flush.sessionId);
    }
  }

  final rows = <({int at, MoveSessionHistory row})>[];
  for (var i = 0; i < seen.length; i++) {
    final session = repository.sessionById(seen[i]);
    if (session == null ||
        !session.completed ||
        session.endedReason == EndedReason.abandoned) {
      continue;
    }
    final sets = [
      for (final set in repository.loggedSetsFor(
        sessionId: session.id,
        exerciseId: exerciseId,
      ))
        set.outcome!,
    ];
    if (sets.isEmpty) continue;
    rows.add((
      at: i,
      row: (
        sessionId: session.id,
        dateKey: session.dateKey,
        sets: sets,
        best: bestOutcome(sets),
      ),
    ));
  }

  rows.sort((a, b) {
    final byDay = b.row.dateKey.compareTo(a.row.dateKey);
    return byDay != 0 ? byDay : b.at.compareTo(a.at);
  });
  return [for (final r in rows.take(limit)) r.row];
}

/// The set that counts most: the heaviest, then the most reps; for a bodyweight
/// move the most reps; for a hold the longest. Null for no sets.
SetOutcome? bestOutcome(List<SetOutcome> sets) {
  SetOutcome? best;
  for (final set in sets) {
    if (best == null || _beats(set, best)) best = set;
  }
  return best;
}

bool _beats(SetOutcome a, SetOutcome b) {
  final aw = a.weightKg ?? 0, bw = b.weightKg ?? 0;
  if (aw != bw) return aw > bw;
  final ar = a.reps ?? 0, br = b.reps ?? 0;
  if (ar != br) return ar > br;
  return (a.holdSeconds ?? 0) > (b.holdSeconds ?? 0);
}

/// The moves of a finished session with the sets she logged, in the order she
/// did them. A set written twice reads as its latest outcome; sets a recalled
/// session carries itself are used for a move with no flush of its own.
List<({String exerciseId, List<LoggedSet> sets})> loggedMovesOf(
  InMemoryTrainRepository repository,
  TrainSession session,
) {
  final ids = <String>[];
  for (final flush in repository.flushes) {
    if (flush.sessionId == session.id && !ids.contains(flush.exerciseId)) {
      ids.add(flush.exerciseId);
    }
  }
  for (final set in session.sets) {
    if (!ids.contains(set.prescribed.exerciseId)) {
      ids.add(set.prescribed.exerciseId);
    }
  }
  final moves = <({String exerciseId, List<LoggedSet> sets})>[];
  for (final id in ids) {
    var sets = repository.loggedSetsFor(sessionId: session.id, exerciseId: id);
    if (sets.isEmpty) {
      sets = [
        for (final s in session.sets)
          if (s.prescribed.exerciseId == id && s.isLogged) s,
      ];
    }
    if (sets.isNotEmpty) moves.add((exerciseId: id, sets: sets));
  }
  return moves;
}
