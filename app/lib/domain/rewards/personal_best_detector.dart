/// A personal best, measured against her own history and nobody else's.
///
/// P03's note is the specification: *"Measured against your own history only.
/// More reps, more weight, a longer hold, or a harder version — a 3 kg dumbbell
/// counts like a 30 kg barbell."* That is what makes the ladder identical for a
/// first-timer and a fifteen-year lifter, and it is also why rule 11 is safe
/// here: a best is a comparison with her past self, never with another woman.
///
/// ## Detection without scanning her history
///
/// The maximum is **materialised**: `users/{uid}/bests/{exerciseId}` *is* the
/// running best, so detecting one is a point lookup rather than an aggregation.
/// A session touches at most six exercises, so a detection run reads at most six
/// documents by deterministic id — no query, no index, and nothing that grows
/// with how long she has been training (G6 §3.3).
///
/// ## A recalled session can never set one
///
/// The first line of [detect] refuses any source but `live`, via [SessionCredit]
/// rather than a condition written out again here. R12 says so on screen —
/// *"No personal best from this one — the numbers were copied, not measured"* —
/// rather than quietly awarding nothing.
///
/// It is doubly impossible in production: G4's `SessionFinished` carries an
/// **empty `measuredSets`** for a recalled or unplanned session, so there is
/// nothing to compare even if the guard were removed. `P0-LOG-04` and
/// `P0-LOG-12` cover both halves.
///
/// ## Rule 1 is enforced by the shape of the input
///
/// [MeasuredSet] has `actualWeight`, `actualReps` and `actualHoldSec` and **no
/// `prescribed*` field of any kind**. A prescribed value cannot become a best
/// because the detector has no parameter through which one could arrive. This is
/// deliberately a different type from `LoggedSet`, which pairs a prescription
/// with an outcome: G6 §3.3 reads G4's server-derived `measuredSets` payload and
/// never the raw `sets` array, and using a type that cannot hold a prescription
/// is how that stays true.
///
/// ## One kind of best cannot be detected today
///
/// `actualHoldSec` is **absent from G4's schema** (`SetOutcome` has
/// `holdSeconds` on the outcome, but `sets[].actualHoldSec` is not surfaced in
/// `measuredSets`). G6 §7.3 calls this "the one request that blocks shipped
/// behaviour", and the consequence is precise: P03's *"Plank hold · 45
/// seconds"* cannot be detected from a real session until G4 supplies it. The
/// branch is implemented and tested here so that the day the field lands, no
/// detection logic has to be written — but nothing populates it yet, and the
/// build report says so rather than letting it look finished.
library;

import 'package:meta/meta.dart';

import '../training/session.dart';

/// What a best is measured in, per exercise.
enum BestMetric {
  /// Heaviest load, then volume at that load.
  load,

  /// Most reps, at no less than the load she managed before.
  reps,

  /// Longest hold.
  hold,

  /// Moved to a harder version of the same movement.
  variation,
}

/// One set, as G4's server-derived `measuredSets` payload carries it.
///
/// Every field is nullable and only non-null values are ever compared, so an
/// unlogged set is an absence rather than a zero.
@immutable
class MeasuredSet {
  const MeasuredSet({
    required this.exerciseId,
    this.actualWeight,
    this.actualReps,
    this.actualHoldSec,
  });

  final String exerciseId;

  final num? actualWeight;
  final int? actualReps;

  /// **Not populated today.** See the library comment — G6 §7.3 request 1.
  final int? actualHoldSec;
}

/// What the bundled content pack knows about an exercise.
///
/// Read from the local pack, never from Firestore (G8 §3), so detection costs no
/// reads at all beyond the bests themselves.
@immutable
class ExerciseMeta {
  const ExerciseMeta({
    required this.exerciseId,
    required this.metric,
    this.progressionFamily,
    this.progressionRank,
    this.siblings = const <String>[],
  });

  final String exerciseId;
  final BestMetric metric;

  /// The movement this is a version of — "squat", "hinge".
  final String? progressionFamily;

  /// How hard this version is within the family. Higher is harder.
  final int? progressionRank;

  /// The other exercise ids in the family, so the detector can point-get their
  /// bests without a query.
  final List<String> siblings;
}

/// The best she held before this one.
@immutable
class PreviousBest {
  const PreviousBest({
    this.loadKg,
    this.reps,
    this.holdSec,
    this.rank,
    this.dateKey,
  });

  final num? loadKg;
  final int? reps;
  final int? holdSec;
  final int? rank;
  final String? dateKey;
}

/// `users/{uid}/bests/{exerciseId}` — the running maximum, materialised.
///
/// The load field is `loadKg`, **not `weight`**. G7 projects bests publicly
/// behind `privacy.showBests` and warns "numbers only; never scale weight". A
/// field called `weight` inside a record that may be published is one careless
/// line from publishing body weight; `loadKg` is the dumbbell and cannot be
/// mistaken for the woman (G6 §1.2).
@immutable
class PersonalBest {
  const PersonalBest({
    required this.exerciseId,
    required this.metric,
    required this.dateKey,
    required this.sessionId,
    this.loadKg,
    this.reps,
    this.holdSec,
    this.rank,
    this.previous,
  });

  final String exerciseId;
  final BestMetric metric;

  /// `yyyy-MM-dd`. Sorts lexicographically, so P03 needs no timestamp field and
  /// no extra index.
  final String dateKey;

  final String sessionId;

  /// The load lifted. Never her body weight.
  final num? loadKg;

  final int? reps;
  final int? holdSec;

  /// Her rank within the progression family, for a [BestMetric.variation] best.
  final int? rank;

  final PreviousBest? previous;

  /// Volume at this best, when both numbers are known. The load tie-breaker.
  num? get volume {
    final load = loadKg;
    final count = reps;
    if (load == null || count == null) return null;
    return load * count;
  }

  @override
  String toString() =>
      'PersonalBest($exerciseId ${metric.name} '
      'load:$loadKg reps:$reps hold:$holdSec rank:$rank on $dateKey)';
}

/// Finds the bests in a finished session.
class PersonalBestDetector {
  const PersonalBestDetector({this.credit = const SessionCredit()});

  final SessionCredit credit;

  /// The bests this session set, one at most per exercise.
  ///
  /// Returns an empty list — never a partial one — for any source but `live`.
  List<PersonalBest> detect({
    required SessionSource source,
    required String sessionId,
    required String dateKey,
    required List<MeasuredSet> measuredSets,
    required Map<String, ExerciseMeta> exercises,
    Map<String, PersonalBest> current = const <String, PersonalBest>{},
  }) {
    if (!credit.eligibleForPersonalBest(source)) return const <PersonalBest>[];

    final byExercise = <String, List<MeasuredSet>>{};
    for (final set in measuredSets) {
      byExercise.putIfAbsent(set.exerciseId, () => <MeasuredSet>[]).add(set);
    }

    final found = <PersonalBest>[];
    for (final entry in byExercise.entries) {
      final meta = exercises[entry.key];
      // An exercise the pack does not describe has no metric to be compared on.
      // Failing closed here means a missing content tag costs her a best she
      // might have earned, which is the safe direction: the alternative is
      // guessing a metric and recording a best that is not one.
      if (meta == null) continue;

      final best =
          _variation(
            meta: meta,
            sessionId: sessionId,
            dateKey: dateKey,
            current: current,
          ) ??
          _onMetric(
            meta: meta,
            sets: entry.value,
            sessionId: sessionId,
            dateKey: dateKey,
            held: current[entry.key],
          );

      if (best != null) found.add(best);
    }

    return found;
  }

  /// "Moved to the harder version" — a best that is not a bigger number.
  ///
  /// Fires when she has a best somewhere lower in the progression family and
  /// none at this rank or above. Reading the siblings is a point-get of at most
  /// four documents by deterministic id (G6 §3.3 step 4).
  PersonalBest? _variation({
    required ExerciseMeta meta,
    required String sessionId,
    required String dateKey,
    required Map<String, PersonalBest> current,
  }) {
    final rank = meta.progressionRank;
    final family = meta.progressionFamily;
    if (rank == null || family == null) return null;

    // Already has a best here, so moving up is not what just happened.
    if (current.containsKey(meta.exerciseId)) return null;

    var foundLower = false;
    for (final siblingId in meta.siblings) {
      final siblingBest = current[siblingId];
      if (siblingBest == null) continue;
      final siblingRank = siblingBest.rank;
      if (siblingRank == null) continue;
      if (siblingRank >= rank) return null; // already at or above this version
      foundLower = true;
    }
    if (!foundLower) return null;

    return PersonalBest(
      exerciseId: meta.exerciseId,
      metric: BestMetric.variation,
      dateKey: dateKey,
      sessionId: sessionId,
      rank: rank,
      previous: PreviousBest(rank: _highestSiblingRank(meta, current)),
    );
  }

  int? _highestSiblingRank(
    ExerciseMeta meta,
    Map<String, PersonalBest> current,
  ) {
    int? highest;
    for (final siblingId in meta.siblings) {
      final rank = current[siblingId]?.rank;
      if (rank == null) continue;
      if (highest == null || rank > highest) highest = rank;
    }
    return highest;
  }

  PersonalBest? _onMetric({
    required ExerciseMeta meta,
    required List<MeasuredSet> sets,
    required String sessionId,
    required String dateKey,
    required PersonalBest? held,
  }) {
    return switch (meta.metric) {
      BestMetric.load => _load(meta, sets, sessionId, dateKey, held),
      BestMetric.reps => _reps(meta, sets, sessionId, dateKey, held),
      BestMetric.hold => _hold(meta, sets, sessionId, dateKey, held),
      // A family-only metric; handled entirely by _variation above.
      BestMetric.variation => null,
    };
  }

  /// Heavier than before — or the same load for more total work.
  PersonalBest? _load(
    ExerciseMeta meta,
    List<MeasuredSet> sets,
    String sessionId,
    String dateKey,
    PersonalBest? held,
  ) {
    MeasuredSet? top;
    for (final set in sets) {
      final load = set.actualWeight;
      if (load == null) continue;
      final best = top?.actualWeight;
      if (best == null || load > best) {
        top = set;
      } else if (load == best) {
        // Same load: prefer the set that did more reps, so volume is measured
        // at her heaviest weight rather than at whichever set came first.
        final reps = set.actualReps ?? 0;
        if (reps > (top?.actualReps ?? 0)) top = set;
      }
    }
    if (top == null) return null;

    final load = top.actualWeight!;
    final reps = top.actualReps;

    if (held == null) {
      return _best(
        meta,
        BestMetric.load,
        sessionId,
        dateKey,
        loadKg: load,
        reps: reps,
        held: held,
      );
    }

    final heldLoad = held.loadKg;
    if (heldLoad == null || load > heldLoad) {
      return _best(
        meta,
        BestMetric.load,
        sessionId,
        dateKey,
        loadKg: load,
        reps: reps,
        held: held,
      );
    }

    if (load == heldLoad && reps != null) {
      final heldVolume = held.volume;
      if (heldVolume != null && load * reps > heldVolume) {
        return _best(
          meta,
          BestMetric.load,
          sessionId,
          dateKey,
          loadKg: load,
          reps: reps,
          held: held,
        );
      }
    }

    return null;
  }

  /// More reps — but only at no less than the load she managed before.
  ///
  /// Without the load condition, dropping to a lighter dumbbell and doing more
  /// reps would read as progress. It is a different set, not a better one.
  PersonalBest? _reps(
    ExerciseMeta meta,
    List<MeasuredSet> sets,
    String sessionId,
    String dateKey,
    PersonalBest? held,
  ) {
    final floor = held?.loadKg;
    MeasuredSet? top;
    for (final set in sets) {
      final reps = set.actualReps;
      if (reps == null) continue;
      if (floor != null) {
        final load = set.actualWeight;
        // A bodyweight move records no load; it is comparable to itself.
        if (load != null && load < floor) continue;
      }
      if (top == null || reps > top.actualReps!) top = set;
    }
    if (top == null) return null;

    final reps = top.actualReps!;
    if (held != null && held.reps != null && reps <= held.reps!) return null;

    return _best(
      meta,
      BestMetric.reps,
      sessionId,
      dateKey,
      loadKg: top.actualWeight ?? held?.loadKg,
      reps: reps,
      held: held,
    );
  }

  /// A longer hold. Nothing populates the input yet — see the library comment.
  PersonalBest? _hold(
    ExerciseMeta meta,
    List<MeasuredSet> sets,
    String sessionId,
    String dateKey,
    PersonalBest? held,
  ) {
    int? longest;
    for (final set in sets) {
      final hold = set.actualHoldSec;
      if (hold == null) continue;
      if (longest == null || hold > longest) longest = hold;
    }
    if (longest == null) return null;
    if (held != null && held.holdSec != null && longest <= held.holdSec!) {
      return null;
    }

    return _best(
      meta,
      BestMetric.hold,
      sessionId,
      dateKey,
      holdSec: longest,
      held: held,
    );
  }

  PersonalBest _best(
    ExerciseMeta meta,
    BestMetric metric,
    String sessionId,
    String dateKey, {
    num? loadKg,
    int? reps,
    int? holdSec,
    PersonalBest? held,
  }) {
    return PersonalBest(
      exerciseId: meta.exerciseId,
      metric: metric,
      dateKey: dateKey,
      sessionId: sessionId,
      loadKg: loadKg,
      reps: reps,
      holdSec: holdSec,
      rank: meta.progressionRank,
      previous: held == null
          ? null
          : PreviousBest(
              loadKg: held.loadKg,
              reps: held.reps,
              holdSec: held.holdSec,
              rank: held.rank,
              dateKey: held.dateKey,
            ),
    );
  }
}
