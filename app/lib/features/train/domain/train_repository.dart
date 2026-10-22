/// What the Train feature reads and writes.
///
/// G4 (`6-v2/plans/G4-train-workout.md`) writes exactly one collection,
/// `users/{uid}/sessions/{sessionId}`, and reads everything else. That asymmetry
/// is the shape of this interface: one command per state transition in §3.1's
/// machine, and plain reads for the libraries.
///
/// **Three things this interface deliberately does not do.**
///
///  1. It has no method that turns a prescription into a result. [startSession]
///     returns a session whose sets are all [LoggedSet] with a null outcome, and
///     the only way to fill one in is [flushMove], which takes the outcomes the
///     caller supplies. Spine C8 — see `domain/training/prescribed_set.dart`.
///  2. It does not flush per set. Per the plan's D2 the server write happens once
///     per **move**, because per-set flushing costs 16 writes a session — 76% of
///     the product's entire write budget for one screen. The five-second undo
///     already makes the log durable locally at the instant of the tap, so she
///     cannot tell the difference.
///  3. It does not award points and does not write personal bests. Those belong
///     to the rewards group; G4 only states whether a session is *eligible* for
///     one, in [PersonalBestEligibility].
///
/// The library types carry display text because the 124-title library is content
/// from a build-time bundle, not copy from the dictionary. Until that pipeline
/// exists the sample rows are resolved from `AppL10n` by the views — the same
/// approach `LookAroundView` takes — so nothing is hardcoded in the meantime.
library;

import 'package:meta/meta.dart';

import '../../../domain/training/prescribed_set.dart';

/// How a session came to exist. Immutable once written.
///
/// `unplanned` is a walk or a studio class: real training with no plan behind it
/// and no sets to measure.
enum SessionSource { live, recalled, unplanned }

/// Which of the two rows she tapped when recalling a session she already did.
enum RecallMethod { plan, history }

/// How a session ended. Null while it is still running.
enum EndedReason { finished, abandoned }

/// A move as the plan prescribes it for today.
@immutable
class PlannedMove {
  const PlannedMove({
    required this.exerciseId,
    required this.name,
    required this.prescriptionLabel,
    required this.sets,
    this.cues = const <String>[],
    this.quiet = false,
    this.needsEquipment = false,
    this.floorOnly = false,
    this.videoAssetId,
    this.restSeconds,
  });

  final String exerciseId;

  /// "Goblet squat".
  final String name;

  /// The prescription as she reads it — "3 × 10 · 12 kg suggested".
  ///
  /// A label, never a source of truth. The numbers that matter are in [sets],
  /// and a bodyweight move renders as "bodyweight" rather than "0 kg".
  final String prescriptionLabel;

  /// What was asked for. Carries no field capable of holding what she did.
  final List<PrescribedSet> sets;

  /// The two or three form cues shown on R04. Never a paragraph.
  final List<String> cues;

  final bool quiet;
  final bool needsEquipment;
  final bool floorOnly;

  /// Identifies the demo loop in the video library. Null until the 124 titles
  /// are produced, which is every move today.
  final String? videoAssetId;

  /// The rest the plan gives after this move, in seconds. Null when the plan
  /// names none; R09 then rests her the standard minute.
  final int? restSeconds;
}

/// One day of the plan: the assignment R03 renders.
@immutable
class WorkoutDay {
  const WorkoutDay({
    required this.id,
    required this.title,
    required this.summary,
    required this.constraints,
    required this.moves,
    this.planVersion,
  });

  /// The assignment's `yyyy-MM-dd` key, or a workout id when she trained off-plan.
  final String id;

  /// "Legs and glutes".
  final String title;

  /// "15 minutes, 5 moves".
  final String summary;

  /// "Quiet · no equipment · floor".
  final String constraints;

  final List<PlannedMove> moves;

  /// Pinned when the session starts, never re-read afterwards, so a plan
  /// republished mid-session cannot change the workout under her.
  final String? planVersion;
}

/// A row in the workout library Train lists under Explore.
@immutable
class LibraryWorkout {
  const LibraryWorkout({
    required this.id,
    required this.title,
    required this.detail,
    this.quiet = false,
    this.needsEquipment = false,
    this.minutes = 10,
    this.posterAssetId,
    this.exerciseIds = const <String>[],
  });

  final String id;

  /// The moves in the session, so Train can offer it only when she can watch
  /// every one of them.
  final List<String> exerciseIds;

  /// "Floor legs, no jumping".
  final String title;

  /// "10 min · beginner · Nour".
  final String detail;

  final bool quiet;
  final bool needsEquipment;
  final int minutes;
  final String? posterAssetId;
}

/// A candidate offered on R05 in place of a move she cannot do today.
@immutable
class MoveAlternative {
  const MoveAlternative({
    required this.exerciseId,
    required this.name,
    required this.reason,
  });

  final String exerciseId;
  final String name;

  /// Why it is offered — "No standing, nothing to hold".
  final String reason;
}

/// A session, live or recalled.
@immutable
class TrainSession {
  const TrainSession({
    required this.id,
    required this.source,
    required this.dateKey,
    required this.sets,
    this.assignmentId,
    this.planVersion,
    this.workoutId,
    this.activity,
    this.recallMethod,
    this.endedReason,
    this.durationSec = 0,
    this.completed = false,
  });

  final String id;

  /// Immutable after create. R12's rule and the reward economy both key off it.
  final SessionSource source;

  /// `yyyy-MM-dd` in Africa/Cairo, not UTC.
  final String dateKey;

  /// Embedded, as the spine requires. Every outcome starts null.
  final List<LoggedSet> sets;

  final String? assignmentId;
  final String? planVersion;
  final String? workoutId;

  /// 'walk', 'class' or 'other' for an unplanned session, which has no sets.
  final String? activity;

  final RecallMethod? recallMethod;
  final EndedReason? endedReason;
  final int durationSec;
  final bool completed;

  /// Sets with an outcome recorded. Never counts a prescription.
  int get loggedSetCount => sets.where((s) => s.isLogged).length;
}

/// §2 rule for R12, expressed the way the plan requires.
///
/// Written as `== live` rather than `!= recalled` on purpose. `unplanned` — a
/// walk, a studio class — entered the schema after the first version of this rule
/// was written elsewhere, and a rule phrased as "not recalled" silently let those
/// through to set a personal best. Phrased this way, anything that is not a
/// measured live session is excluded by construction rather than by a second
/// clause somebody has to remember.
class PersonalBestEligibility {
  const PersonalBestEligibility();

  bool isEligible(TrainSession session) => session.source == SessionSource.live;
}

/// Where the demo loops and follow-along videos come from.
///
/// **The 124 titles do not exist yet**, so the in-memory implementation returns
/// null for every asset and the UI shows [AppMedia]'s placeholder. That is the
/// honest state of the product, not a stub to be papered over.
///
/// Delivery is settled (`DECISIONS.md` D2 and the plan's §8): Cloudflare R2
/// behind a CDN, at a content-addressed path carrying the library version, with
/// `Cache-Control: public, max-age=31536000, immutable`. Public and immutable
/// rather than signed, because a signed URL is unique per request — it collapses
/// the edge cache the zero-egress argument depends on, and it makes a downloaded
/// file unplayable the moment its signature expires.
///
/// A widget that reached for a Firebase Storage download URL instead would cost
/// roughly $1,352 a month in egress at launch scale. Hence an interface: there is
/// one place that decision lives, and it is not a screen.
///
/// The exercise library's short demo clips (R15) are the exception D42
/// records: downloaded once from the content bucket and kept on the phone
/// (`exercise_media_store.dart`). The follow-along titles stay here.
abstract class WorkoutVideoRepository {
  /// The playable URL, or null when the asset has not been produced yet.
  Uri? urlFor(String assetId);

  /// True when the asset is on the device and will play with no signal.
  bool isDownloaded(String assetId);
}

/// Reads the libraries and owns the one collection G4 writes.
abstract class TrainRepository {
  /// Today's assignment, or null when the plan prescribes rest.
  ///
  /// Absence means rest. It is never an error and never a spinner.
  Future<WorkoutDay?> today();

  /// The bundled library. Issues no query: the rows ship with the app, so R11
  /// filters a local list and works with no signal.
  Future<List<LibraryWorkout>> library();

  /// Swap candidates, filtered locally against the same equipment constraints
  /// that produced the prescription.
  Future<List<MoveAlternative>> alternativesFor(String exerciseId);

  /// Begins a live session.
  ///
  /// Throws [StateError] if any set arrives with an outcome already recorded.
  /// That assertion is spine C8 at the boundary: a live session cannot be born
  /// with anything logged.
  Future<TrainSession> startSession(WorkoutDay day);

  /// Records a swap for today only. Never writes to the plan.
  Future<void> swapMove({
    required String sessionId,
    required String fromExerciseId,
    required String toExerciseId,
  });

  /// Persists the outcomes for one move. One write per move, per D2.
  ///
  /// Reachable only when a log's undo window has closed — the five seconds live
  /// ahead of this call, so an undone set never reaches the server at all and
  /// there is nothing queued to resurface when she reconnects.
  Future<void> flushMove({
    required String sessionId,
    required String exerciseId,
    required List<LoggedSet> sets,
  });

  /// Ends a session. Written once; `completedAt` is never rewritten.
  Future<TrainSession> finishSession({
    required String sessionId,
    required int durationSec,
    EndedReason reason = EndedReason.finished,
  });

  /// A session she did without the phone, created already complete.
  ///
  /// The id is deterministic, so a write replayed after reconnect overwrites
  /// itself instead of creating a second session and crediting the week twice.
  Future<TrainSession> logRecalled({
    required String dateKey,
    required RecallMethod method,
    String? assignmentId,
    List<LoggedSet> sets = const <LoggedSet>[],
    int durationSec = 0,
  });

  /// A walk or a class: counted by time alone, with no sets to measure.
  Future<TrainSession> logUnplanned({
    required String dateKey,
    required String activity,
    required int durationSec,
  });

  /// Corrects one set she logged, after its undo window has closed.
  ///
  /// The set is found by its prescription's `order` within [exerciseId] in
  /// [sessionId]; what she did replaces what was written. The prescription is
  /// never touched: this records a different outcome, never a different plan.
  Future<void> replaceSet({
    required String sessionId,
    required String exerciseId,
    required LoggedSet set,
  });

  /// Removes a session she logged by mistake, with every set written to it.
  /// Returns the session, or null when there was none under [sessionId].
  ///
  /// Reachable only when the removal's own undo window has closed. Points and
  /// the week are the rewards group's to take back, not this interface's.
  ///
  /// The removal is remembered, so a copy of the session on the server is
  /// marked removed rather than merged back.
  Future<TrainSession?> removeSession(String sessionId);
}

/// What the server does when a flush lands.
///
/// In production a flush is a write to `users/{uid}/sessions/{sessionId}` and
/// this is the Cloud Function the write triggers — which is why it takes the
/// session rather than only its id: detection needs the source and the date key,
/// and neither is in the flush itself. [TrainSession] is nullable because a
/// flush can arrive under an id no session was started with, and a receiver that
/// assumed `live` in that case would let a recalled session set a personal best.
///
/// It is deliberately **not** a method on [TrainRepository]. The interface's
/// contract says the Train feature "does not award points and does not write
/// personal bests"; a hook on the fake server keeps that true while still
/// letting the in-memory product behave the way the Function will.
typedef FlushedMove = void Function({
  TrainSession? session,
  required String exerciseId,
  required List<LoggedSet> sets,
});

/// An in-memory implementation, for tests and for building screens before there
/// is a Firebase project.
///
/// Deliberately strict where the real one is strict — it enforces the no-prefill
/// rule and the deterministic recall id — because a fake that accepts anything
/// lets a screen pass its tests and then fail in production.
class InMemoryTrainRepository implements TrainRepository {
  InMemoryTrainRepository({
    this.day,
    this.workouts = const <LibraryWorkout>[],
    this.alternatives = const <MoveAlternative>[],
    this.alternativesFinder,
    this.onFlushed,
  });

  /// Today's assignment, or null when the plan prescribes rest.
  final WorkoutDay? day;

  /// The rows the bundled library would ship with.
  final List<LibraryWorkout> workouts;

  /// Swap candidates offered on R05.
  final List<MoveAlternative> alternatives;

  /// Candidates worked out for one move, from the exercise library. When set
  /// it is the only source: a move it finds nothing for has no swap.
  final List<MoveAlternative> Function(String exerciseId)? alternativesFinder;

  /// Run after a flush has landed, the way a Cloud Function runs after a write.
  ///
  /// Null by default, so a repository with no hook behaves exactly as it always
  /// did. `SessionBestsBridge.record` is shaped to match it.
  final FlushedMove? onFlushed;

  final Map<String, TrainSession> _sessions = <String, TrainSession>{};

  /// Sessions she removed, by id, with the two facts the cloud needs to mark
  /// them removed: the source the rules require an update to keep, and the day.
  ///
  /// The rules keep a session with a set in it on the server for good, and the
  /// merge takes back any session the phone does not hold. Without this record
  /// a removed session came back at the next sign-in, after her week and her
  /// points had already been taken down for it.
  final Map<String, RemovedSession> _removed = <String, RemovedSession>{};

  /// Every flush that reached "the server", in order. A test asserts against this
  /// to prove an undone log never arrived.
  final List<({String sessionId, String exerciseId, List<LoggedSet> sets})>
  flushes = [];

  final List<({String from, String to})> swaps = [];

  int _counter = 0;

  String? _liveSessionId;

  /// The id [startSession] most recently minted.
  ///
  /// R07 and R08 default to `sessionId: 'session'`, which is an id no session
  /// was ever started under — so a flush from the running app is attributed to
  /// nothing. This is the id a router passes instead.
  String? get liveSessionId => _liveSessionId;

  /// One session by id, or null when none was started under it.
  TrainSession? sessionById(String id) => _sessions[id];

  @override
  Future<WorkoutDay?> today() async => day;

  @override
  Future<List<LibraryWorkout>> library() async => workouts;

  @override
  Future<List<MoveAlternative>> alternativesFor(String exerciseId) async {
    final finder = alternativesFinder;
    if (finder != null) return finder(exerciseId);
    return alternatives.where((a) => a.exerciseId != exerciseId).toList();
  }

  @override
  Future<TrainSession> startSession(WorkoutDay day) async {
    final sets = [
      for (final move in day.moves)
        for (final prescribed in move.sets) LoggedSet(prescribed: prescribed),
    ];

    // Spine C8 at the boundary. The types make a pre-filled set hard to build;
    // this makes it impossible to persist.
    if (!const AdherenceCalculator().hasNoPrefill(sets)) {
      throw StateError(
        'A live session cannot be born with anything logged. A prescribed '
        'value is never a result (spine C8).',
      );
    }

    final session = TrainSession(
      id: 'live-${++_counter}',
      source: SessionSource.live,
      dateKey: day.id,
      assignmentId: day.id,
      planVersion: day.planVersion,
      sets: sets,
    );
    _sessions[session.id] = session;
    _removed.remove(session.id);
    _liveSessionId = session.id;
    return session;
  }

  @override
  Future<void> swapMove({
    required String sessionId,
    required String fromExerciseId,
    required String toExerciseId,
  }) async {
    swaps.add((from: fromExerciseId, to: toExerciseId));
  }

  @override
  Future<void> flushMove({
    required String sessionId,
    required String exerciseId,
    required List<LoggedSet> sets,
  }) async {
    flushes.add((sessionId: sessionId, exerciseId: exerciseId, sets: sets));

    // The write has landed; now the server reacts to it. Ordered this way on
    // purpose: a hook that threw must not be able to unrecord a log she made.
    onFlushed?.call(
      session: _sessions[sessionId],
      exerciseId: exerciseId,
      sets: sets,
    );
  }

  @override
  Future<TrainSession> finishSession({
    required String sessionId,
    required int durationSec,
    EndedReason reason = EndedReason.finished,
  }) async {
    final existing = _sessions[sessionId];
    final finished = TrainSession(
      id: sessionId,
      source: existing?.source ?? SessionSource.live,
      dateKey: existing?.dateKey ?? '',
      sets: existing?.sets ?? const <LoggedSet>[],
      assignmentId: existing?.assignmentId,
      planVersion: existing?.planVersion,
      durationSec: durationSec,
      endedReason: reason,
      completed: true,
    );
    _sessions[sessionId] = finished;
    return finished;
  }

  @override
  Future<TrainSession> logRecalled({
    required String dateKey,
    required RecallMethod method,
    String? assignmentId,
    List<LoggedSet> sets = const <LoggedSet>[],
    int durationSec = 0,
  }) async {
    // Deterministic: a replayed offline write collides with itself rather than
    // creating a second session and crediting the week twice.
    final id = 'recalled-$dateKey-${assignmentId ?? 'history'}';
    final session = TrainSession(
      id: id,
      source: SessionSource.recalled,
      dateKey: dateKey,
      assignmentId: assignmentId,
      recallMethod: method,
      sets: sets,
      durationSec: durationSec,
      endedReason: EndedReason.finished,
      completed: true,
    );
    // Logged again after she removed it: the same id is hers again.
    _removed.remove(id);
    _sessions[id] = session;
    return session;
  }

  @override
  Future<TrainSession> logUnplanned({
    required String dateKey,
    required String activity,
    required int durationSec,
  }) async {
    final id = 'recalled-$dateKey-$activity';
    final session = TrainSession(
      id: id,
      source: SessionSource.unplanned,
      dateKey: dateKey,
      activity: activity,
      sets: const <LoggedSet>[],
      durationSec: durationSec,
      endedReason: EndedReason.finished,
      completed: true,
    );
    // Logged again after she removed it: the same id is hers again.
    _removed.remove(id);
    _sessions[id] = session;
    return session;
  }

  @override
  Future<void> replaceSet({
    required String sessionId,
    required String exerciseId,
    required LoggedSet set,
  }) async {
    final order = set.prescribed.order;
    // Newest first: a set logged twice is corrected where it last landed.
    for (var i = flushes.length - 1; i >= 0; i--) {
      final flush = flushes[i];
      if (flush.sessionId != sessionId || flush.exerciseId != exerciseId) {
        continue;
      }
      final at = flush.sets.indexWhere((s) => s.prescribed.order == order);
      if (at < 0) continue;
      flushes[i] = (
        sessionId: flush.sessionId,
        exerciseId: flush.exerciseId,
        sets: [
          for (var j = 0; j < flush.sets.length; j++)
            j == at ? set : flush.sets[j],
        ],
      );
      return;
    }
    // Never written: the correction is the first record of it.
    flushes.add((sessionId: sessionId, exerciseId: exerciseId, sets: [set]));
  }

  @override
  Future<TrainSession?> removeSession(String sessionId) async {
    final removed = _sessions.remove(sessionId);
    flushes.removeWhere((f) => f.sessionId == sessionId);
    if (_liveSessionId == sessionId) _liveSessionId = null;
    if (removed != null) {
      _removed[sessionId] = RemovedSession(
        id: sessionId,
        source: removed.source,
        dateKey: removed.dateKey,
      );
    }
    return removed;
  }

  /// The sessions she removed, as the snapshot and the cloud keep them.
  List<RemovedSession> get removedSessions =>
      List<RemovedSession>.unmodifiable(_removed.values);

  /// Whether [sessionId] is one she removed. The merge reads it so a copy
  /// still on the server is never taken back.
  bool isRemoved(String sessionId) => _removed.containsKey(sessionId);

  /// Puts back the sessions she had removed when the app closed.
  ///
  /// Separate from [restore] on purpose: the merge restores the sessions it
  /// folds in, and a removal must not be forgotten by that.
  void restoreRemoved(Iterable<RemovedSession> removed) {
    _removed
      ..clear()
      ..addEntries(
        removed
            .where((r) => !_sessions.containsKey(r.id))
            .map((r) => MapEntry(r.id, r)),
      );
  }

  /// The sets she logged for [exerciseId] in [sessionId], one per set number,
  /// in order. A set written twice reads as its latest outcome.
  List<LoggedSet> loggedSetsFor({
    required String sessionId,
    required String exerciseId,
  }) {
    final byOrder = <int, LoggedSet>{};
    for (final flush in flushes) {
      if (flush.sessionId != sessionId || flush.exerciseId != exerciseId) {
        continue;
      }
      for (final set in flush.sets) {
        if (set.isLogged) byOrder[set.prescribed.order] = set;
      }
    }
    final orders = byOrder.keys.toList()..sort();
    return [for (final order in orders) byOrder[order]!];
  }

  /// Every session she has, as the snapshot keeps them.
  ///
  /// Unmodifiable: a window for the code that writes her training to the phone,
  /// not a second way to add a session. See
  /// `lib/app_state/local_persistence.dart`.
  List<TrainSession> get sessions =>
      List<TrainSession>.unmodifiable(_sessions.values);

  /// Her finished sessions that counted, newest day first (ties: the one saved
  /// last first). Abandoned sessions and sessions still under way are left out.
  List<TrainSession> completedSessions({int limit = 20}) {
    final all = _sessions.values.toList();
    final order = <String, int>{
      for (var i = 0; i < all.length; i++) all[i].id: i,
    };
    final done =
        [
          for (final s in all)
            if (s.completed && s.endedReason != EndedReason.abandoned) s,
        ]..sort((a, b) {
          final byDay = b.dateKey.compareTo(a.dateKey);
          return byDay != 0 ? byDay : order[b.id]!.compareTo(order[a.id]!);
        });
    return done.take(limit).toList();
  }

  /// The counter behind `live-1`, `live-2`, so a session started after a
  /// restart does not reuse an id an earlier one already holds.
  int get sessionCounter => _counter;

  /// Puts back the sessions and the flushes the app was holding when it closed.
  ///
  /// The mirror of [reset]. `workouts` and `alternatives` are content that
  /// shipped with the app and are not restored, for the same reason they are
  /// not deleted: they were never hers.
  void restore({
    Iterable<TrainSession> sessions = const <TrainSession>[],
    Iterable<({String sessionId, String exerciseId, List<LoggedSet> sets})>
        flushes =
        const [],
    Iterable<({String from, String to})> swaps = const [],
    String? liveSessionId,
    int sessionCounter = 0,
  }) {
    _sessions
      ..clear()
      ..addEntries(sessions.map((s) => MapEntry(s.id, s)));
    this.flushes
      ..clear()
      ..addAll(flushes);
    this.swaps
      ..clear()
      ..addAll(swaps);
    _liveSessionId = liveSessionId;
    _counter = sessionCounter;
  }

  /// Points the repository back at a live session that was under way when the
  /// app closed, so her next flush is attributed to it. Nothing when the
  /// repository does not hold that session.
  void resumeLive(String sessionId) {
    if (_sessions.containsKey(sessionId)) _liveSessionId = sessionId;
  }

  /// Drops every session and every flush, keeping the bundled library.
  ///
  /// Account deletion calls it: `_sessions` and `flushes` are her workouts,
  /// while `workouts` and `alternatives` are content that shipped with the app
  /// and are not hers to delete.
  void reset() {
    _sessions.clear();
    _removed.clear();
    flushes.clear();
    swaps.clear();
    _liveSessionId = null;
    _counter = 0;
  }
}

/// A session she removed: enough to mark its cloud copy removed and to keep
/// the merge from bringing it back.
@immutable
class RemovedSession {
  const RemovedSession({
    required this.id,
    required this.source,
    required this.dateKey,
  });

  final String id;
  final SessionSource source;
  final String dateKey;

  @override
  bool operator ==(Object other) =>
      other is RemovedSession &&
      other.id == id &&
      other.source == source &&
      other.dateKey == dateKey;

  @override
  int get hashCode => Object.hash(id, source, dateKey);
}

/// The video library before any of it has been produced.
class UnreleasedVideoRepository implements WorkoutVideoRepository {
  const UnreleasedVideoRepository();

  @override
  Uri? urlFor(String assetId) => null;

  @override
  bool isDownloaded(String assetId) => false;
}
