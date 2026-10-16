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
