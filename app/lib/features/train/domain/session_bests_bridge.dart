/// The bridge from a flushed move to a personal best.
///
/// `train_repository.dart` states that the Train feature "does not award points
/// and does not write personal bests. Those belong to the rewards group; G4 only
/// states whether a session is *eligible* for one." This class keeps that true.
/// It owns no rule of its own: it converts (`measuredSetsFrom`), it joins the
/// two source enums (`measuredSourceOf`), and it hands the result to
/// [PersonalBestLedger], which is rewards-group code. Every decision about what
/// counts as a best is made there or in the detector.
///
/// ## Where this runs in production
///
/// On the server. G4 writes `users/{uid}/sessions/{sessionId}`, a Cloud Function
/// reads the write, derives `measuredSets`, detects, and writes the best and the
/// counter — `firestore.rules` denies the whole `rewards` map to clients, so a
/// phone could not do this even if it tried. [record] is that Function's body,
/// and `InMemoryTrainRepository.onFlushed` is its trigger.
///
/// ## Fail closed on a session it does not know
///
/// A flush whose session the repository never minted arrives with no source, and
/// [record] refuses it. Assuming `live` would be the convenient choice and it is
/// the wrong one: `unplanned` and `recalled` sessions flush through the same
/// method, and R12 promises on screen that copied numbers set nothing.
library;

import '../../../domain/rewards/personal_best_detector.dart';
import '../../../domain/rewards/personal_best_ledger.dart';
import '../../../domain/training/prescribed_set.dart';
import 'exercise_metrics.dart';
import 'measured_sets.dart';
import 'train_repository.dart';

/// Detection, run over one flushed move.
class SessionBestsBridge {
  const SessionBestsBridge({
    required this.ledger,
    this.exercises = bundledExerciseMetrics,
  });

  /// Where the running bests and the lifetime count live.
  final PersonalBestLedger ledger;

  /// The metric for each move. Anything absent can set no best.
  final Map<String, ExerciseMeta> exercises;

  /// Records whatever this flush beat.
  ///
  /// Shaped to match `InMemoryTrainRepository.onFlushed`, so wiring it is
  /// `onFlushed: bridge.record` and there is no adapter closure to get wrong.
  SessionBests record({
    TrainSession? session,
    required String exerciseId,
    required List<LoggedSet> sets,
  }) {
    // No session, no source, no best. See the library comment.
    if (session == null) return SessionBests.none;

    return ledger.apply(
      source: measuredSourceOf(session.source),
      sessionId: session.id,
      dateKey: session.dateKey,
      measuredSets: measuredSetsFrom(sets),
      exercises: exercises,
    );
  }

  /// Takes back what [sessionId] did to her bests, once she removed it.
  ///
  /// The ledger drops its counted bests and puts each running best it set back
  /// to the one it beat. Then her other sessions' moves, as [flushes] holds
  /// them in order, are measured against that, so a later lift that beat the
  /// older best but not the removed one becomes her best again. Nothing here
  /// counts or pays: those were paid when they happened.
  void forget(
    String sessionId, {
    Iterable<({String sessionId, String exerciseId, List<LoggedSet> sets})>
        flushes =
        const [],
    TrainSession? Function(String id)? sessionById,
  }) {
    final changed = ledger.forgetSession(sessionId);
    if (changed.isEmpty || sessionById == null) return;
    for (final flush in flushes) {
      if (flush.sessionId == sessionId) continue;
      if (!changed.contains(flush.exerciseId)) continue;
      final session = sessionById(flush.sessionId);
      // A workout she discarded is not hers to have a best from.
      if (session == null || session.endedReason == EndedReason.abandoned) {
        continue;
      }
      final found = ledger.detector.detect(
        source: measuredSourceOf(session.source),
        sessionId: session.id,
        dateKey: session.dateKey,
        measuredSets: measuredSetsFrom(flush.sets),
        exercises: exercises,
        current: ledger.bests,
      );
      for (final best in found) {
        ledger.bests[best.exerciseId] = best;
      }
    }
  }
}
