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
  const SessionBestsBridge({required this.ledger, this.exercises});

  /// Where the running bests and the lifetime count live.
  final PersonalBestLedger ledger;

  /// The metric for each move; null reads [allExerciseMetrics] at each use, so
  /// moves the synced library adds later are included. Anything absent can set
  /// no best.
  final Map<String, ExerciseMeta>? exercises;

  Map<String, ExerciseMeta> get _metrics => exercises ?? allExerciseMetrics();

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
      exercises: _metrics,
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
    final metrics = _metrics;
    for (final flush in flushes) {
      if (flush.sessionId == sessionId) continue;
      if (!changed.contains(flush.exerciseId)) continue;
      final session = sessionById(flush.sessionId);
      // A workout she discarded is not hers to have a best from.
      if (session == null || session.endedReason == EndedReason.abandoned) {
        continue;
      }
      _measure(session, flush.sets, metrics);
    }
  }

  /// Works her bests out again for [sessionId] after she corrected a set.
  ///
  /// The running best of each move the session touched is cleared and every
  /// completed session of those moves, this one included, is measured in order
  /// again, so a later best also learns what it really beat (A 50, B typed 500
  /// and fixed to 55, C 60: C now beat 55, not 500). A move the repository
  /// holds no history for goes back to the best its session had beaten.
  /// Nothing is counted or paid: `bestsCount` and the points already given
  /// stay as they were, so a typo that earned a best loses the best but not
  /// the points.
  void reworkSession(
    String sessionId, {
    required InMemoryTrainRepository repository,
  }) {
    final moves = <String>{
      for (final f in repository.flushes)
        if (f.sessionId == sessionId) f.exerciseId,
      for (final e in ledger.bests.entries)
        if (e.value.sessionId == sessionId) e.key,
    };
    if (moves.isEmpty) return;
    final held = <String, PersonalBest>{
      for (final m in moves) m: ?ledger.bests.remove(m),
    };
    _replay(repository, only: moves);
    for (final entry in held.entries) {
      if (ledger.bests.containsKey(entry.key)) continue;
      ledger.bests[entry.key] = entry.value;
      if (entry.value.sessionId == sessionId) ledger.revertBestsOf(sessionId);
    }
  }

  /// Finds the bests her completed sessions earned that her bests do not hold
  /// yet, oldest session first. Nothing is counted or paid, and running it
  /// again changes nothing. Call it once after her snapshot has loaded.
  void backfill({required InMemoryTrainRepository repository}) =>
      _replay(repository);

  void _measure(
    TrainSession session,
    List<LoggedSet> sets,
    Map<String, ExerciseMeta> metrics,
  ) {
    final found = ledger.detector.detect(
      source: measuredSourceOf(session.source),
      sessionId: session.id,
      dateKey: session.dateKey,
      measuredSets: measuredSetsFrom(sets),
      exercises: metrics,
      current: ledger.bests,
    );
    for (final best in found) {
      ledger.bests[best.exerciseId] = best;
    }
  }

  void _replay(InMemoryTrainRepository repository, {Set<String>? only}) {
    final order = <String, int>{};
    final sessions = <TrainSession>[];
    for (final s in repository.sessions) {
      if (!s.completed || s.endedReason == EndedReason.abandoned) continue;
      order[s.id] = sessions.length;
      sessions.add(s);
    }
    sessions.sort((a, b) {
      final byDate = a.dateKey.compareTo(b.dateKey);
      return byDate != 0 ? byDate : order[a.id]!.compareTo(order[b.id]!);
    });
    final bySession = <String, List<List<LoggedSet>>>{};
    for (final flush in repository.flushes) {
      if (only != null && !only.contains(flush.exerciseId)) continue;
      (bySession[flush.sessionId] ??= []).add(flush.sets);
    }
    final metrics = _metrics;
    for (final session in sessions) {
      for (final sets in bySession[session.id] ?? const <List<LoggedSet>>[]) {
        _measure(session, sets, metrics);
      }
    }
  }
}
