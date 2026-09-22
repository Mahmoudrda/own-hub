/// What Progress reads, and the one thing it writes.
///
/// G6 owns five collections and the client's relationship with them is lopsided
/// on purpose:
///
///   * `users/{uid}/weeks/{yyyy-Www}` — **read only**
///   * `users/{uid}/bests/{exerciseId}` — **read only**
///   * `users/{uid}/awards/{awardId}` — **read only**
///   * `users/{uid}.rewards`, `.weeklyGoal` counters — **read only**
///   * `users/{uid}/measurements/{yyyy-MM-dd}` — hers to write
///
/// *"What a woman writes is evidence; what the server writes is the score. A
/// reward a client can write is a reward that is not earned."* (G6, opening.)
/// `firestore.rules` publishes `allow write: if false` on the first three, and
/// these interfaces match: [WeeksRepository] and [BestsRepository] **have no
/// write method at all**. A screen cannot mint a counted week, because there is
/// no function to call.
///
/// ## Rule 11, enforced by three absences
///
/// [MeasurementsRepository] exposes [MeasurementsRepository.latest] and
/// [MeasurementsRepository.historyForOwner] and **nothing else** (G6 §5). There
/// is no `query`, no `where`, no `orderBy` parameter and no comparator anywhere
/// in this file. `historyForOwner` is scoped to the owner by its name and by its
/// signature, which takes no uid: there is no way to ask for another woman's
/// measurements, so there is nothing to sort across.
///
/// That is the domain half. The storage half is
/// `firestore.indexes.json`, which disables the automatic single-field index on
/// `measurements.weightKg` — because Firestore indexes every field by default,
/// and without the exemption `orderBy('weightKg')` is a query that simply works
/// no matter what this file says. Both halves are required; neither is
/// sufficient. `test/domain/rewards/rewards_rules_test.dart` scans this file,
/// and `test/firestore_indexes_test.dart` scans the deployment artifact.
///
/// ## Why the fakes are strict
///
/// `InMemoryTrainRepository` and `InMemoryMealRepository` set the standard here,
/// and `PHASE1-QA-VERDICT` singles it out: pinning *the fake's* strictness is
/// what stops a case passing in memory and failing on a phone. So
/// [InMemoryMeasurementsRepository] refuses the document ids the rules refuse,
/// and merges by field the way `set(merge: true)` does — two devices adding
/// weight and a waist measurement on the same day both survive (G8 K6).
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../domain/rewards/personal_best_detector.dart';
import '../../../domain/rewards/rewards.dart';
import '../../../domain/rewards/week_rollup.dart';
import '../../../domain/rewards/weekly_goal.dart';
import '../../../domain/week/week_key.dart';

/// Re-exported so a screen reading progress needs one import, not two.
export '../../../domain/rewards/rewards.dart' show Rewards;

/// `users/{uid}/measurements/{yyyy-MM-dd}` — the most private document she owns.
///
/// Every figure is nullable, because she may record a weight without a waist or
/// a waist without a weight, and an absent measurement is an absence rather than
/// a zero.
///
/// Note what this type does **not** do: it does not implement `Comparable`, it
/// has no `compareTo`, and it carries no `rank`, `sharedWith` or `public` field.
/// Rule 11 is not a check applied to measurements; it is a set of methods this
/// type does not have.
@immutable
class Measurement {
  const Measurement({
    required this.dayId,
    required this.takenAt,
    this.weightKg,
    this.waistCm,
    this.hipsCm,
    this.armCm,
    this.thighCm,
    this.note,
  });

  /// `yyyy-MM-dd` in her timezone — the document id. Deterministic (spine C1),
  /// so an offline retry collides with itself instead of logging twice.
  final String dayId;

  final DateTime takenAt;

  final num? weightKg;
  final num? waistCm;
  final num? hipsCm;
  final num? armCm;
  final num? thighCm;
  final String? note;

  /// True when nothing at all was recorded. Not an error — just nothing to save.
  bool get isEmpty =>
      weightKg == null &&
      waistCm == null &&
      hipsCm == null &&
      armCm == null &&
      thighCm == null;

  /// Field-level merge, exactly as `set(merge: true)` behaves (G8 K6).
  ///
  /// [other] is the newer write. A null on the newer document does not erase a
  /// value the older one holds, which is what lets two handsets each add a
  /// different figure on the same day without either losing the other's.
  Measurement mergedWith(Measurement other) => Measurement(
    dayId: dayId,
    takenAt: other.takenAt.isAfter(takenAt) ? other.takenAt : takenAt,
    weightKg: other.weightKg ?? weightKg,
    waistCm: other.waistCm ?? waistCm,
    hipsCm: other.hipsCm ?? hipsCm,
    armCm: other.armCm ?? armCm,
    thighCm: other.thighCm ?? thighCm,
    note: other.note ?? note,
  );

  @override
  String toString() => 'Measurement($dayId weight:$weightKg waist:$waistCm)';
}

// ------------------------------------------------------------- repositories --

/// Her weeks and her counters. **Read only** — every field is Function-written.
abstract class WeeksRepository {
  /// One week by deterministic id. Null before anything was logged in it.
  Future<WeekDoc?> week(WeekKey key);

  /// Her goal and its counters, including the eight-bar `recent8` cache.
  Future<WeeklyGoal> goal();

  /// Her currency.
  Future<Rewards> rewards();

  /// A live view, for the screen that is open.
  Stream<WeeklyGoal> watchGoal();

  Future<void> dispose();

  // There is deliberately no write method of any kind. See the library comment.
}

/// Her personal bests. **Read only**, and never across women.
abstract class BestsRepository {
  /// Her bests, newest first by `dateKey`.
  ///
  /// Bounded: the exercise library is 124 moves, so this can never return more
  /// than 124 documents however long she has trained. The limit is a cost
  /// control, not a paging mechanism.
  Future<List<PersonalBest>> recent({int limit = 50});

  /// One best by deterministic id — the point lookup detection uses.
  Future<PersonalBest?> forExercise(String exerciseId);

  Future<void> dispose();
}

/// Her body measurements. Hers to write, and nobody else's to read.
///
/// Two read methods, and no third. See the library comment for why the missing
/// one matters more than the two that are here.
abstract class MeasurementsRepository {
  /// The most recent measurement, or null if she has never recorded one.
  Future<Measurement?> latest();

  /// Her own history, newest first by document id.
  ///
  /// Ordered by `__name__`, which is the date key — the only ordering this
  /// collection has an index for. There is no parameter naming a field to sort
  /// by, so "order by weight" is not a request that can be made.
  Future<List<Measurement>> historyForOwner({int limit = 24});

  /// Records one. Merges by field into the day's document.
  ///
  /// Reachable only once a log's undo window has closed: the five seconds live
  /// ahead of this call in `LogCommandBus`, so an undone measurement never
  /// reaches storage and there is nothing queued to resurface on reconnect.
  Future<void> save(Measurement measurement);

  /// Wipes the on-device copy. G7's A02 manifest row 33 — the client-side half
  /// of deletion, without which her data is still readable from the offline
  /// cache on that handset after the account is gone.
  Future<void> purgeLocal();

  Future<void> dispose();
}

// ------------------------------------------------------------------ fakes ----

/// The documents, shared between the repositories that point at them.
///
/// This is "the server" in a test. Seeding [weeks], [goal], [bests] and
/// [rewards] here rather than through a repository method is the strictness that
/// matters: it models the Cloud Function, which is the only writer those four
/// have. A test that wants a counted week writes one *as the server*, because a
/// client cannot.
class ProgressStore {
  ProgressStore({
    Map<String, WeekDoc>? weeks,
    WeeklyGoal? goal,
    Map<String, PersonalBest>? bests,
    Rewards? rewards,
    Map<String, Measurement>? measurements,
  }) : weeks = weeks ?? <String, WeekDoc>{},
       goal = goal ?? const WeeklyGoal(),
       bests = bests ?? <String, PersonalBest>{},
       rewards = rewards ?? const Rewards(),
       measurements = measurements ?? <String, Measurement>{};

  /// Keyed by `yyyy-Www`.
  final Map<String, WeekDoc> weeks;

  WeeklyGoal goal;

  /// Keyed by `exerciseId`.
  final Map<String, PersonalBest> bests;

  Rewards rewards;

  /// Keyed by `yyyy-MM-dd`.
  final Map<String, Measurement> measurements;

  /// Applies a measurement the way Firestore's `set(merge: true)` would.
  void applyMeasurement(Measurement measurement) {
    _assertDayId(measurement.dayId);
    _assertPlausible(measurement);
    final existing = measurements[measurement.dayId];
    measurements[measurement.dayId] = existing == null
        ? measurement
        : existing.mergedWith(measurement);
  }

  static void _assertDayId(String dayId) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dayId)) {
      throw StateError(
        '"$dayId" is not a yyyy-MM-dd document id. Spine C1: a date-keyed id '
        'is what makes an offline retry idempotent, and the security rules '
        'refuse anything else.',
      );
    }
  }

  /// The bounds the rules would apply.
  ///
  /// Not a validation of her body — a guard against a corrupt write. A negative
  /// measurement is a bug in whatever produced it, and storing it would put a
  /// nonsense number on the one screen she is most sensitive about.
  static void _assertPlausible(Measurement m) {
    for (final entry in <String, num?>{
      'weightKg': m.weightKg,
      'waistCm': m.waistCm,
      'hipsCm': m.hipsCm,
      'armCm': m.armCm,
      'thighCm': m.thighCm,
    }.entries) {
      final value = entry.value;
      if (value != null && value <= 0) {
        throw StateError(
          '${entry.key} was $value. A measurement is a positive number; the '
          'rules refuse anything else.',
        );
      }
    }
  }
}

/// An in-memory [WeeksRepository]. Read-only, exactly like the real one.
class InMemoryWeeksRepository implements WeeksRepository {
  InMemoryWeeksRepository({ProgressStore? store})
    : store = store ?? ProgressStore();

  final ProgressStore store;

  final StreamController<WeeklyGoal> _goals =
      StreamController<WeeklyGoal>.broadcast();

  @override
  Future<WeekDoc?> week(WeekKey key) async => store.weeks[key.id];

  @override
  Future<WeeklyGoal> goal() async => store.goal;

  @override
  Future<Rewards> rewards() async => store.rewards;

  @override
  Stream<WeeklyGoal> watchGoal() => _goals.stream;

  /// Publishes a change the way a Cloud Function's write would arrive.
  ///
  /// Named for what it models, so nobody mistakes it for a client write path.
  void serverWrote(WeeklyGoal goal) {
    store.goal = goal;
    if (!_goals.isClosed) _goals.add(goal);
  }

  @override
  Future<void> dispose() => _goals.close();
}

/// An in-memory [BestsRepository].
class InMemoryBestsRepository implements BestsRepository {
  InMemoryBestsRepository({ProgressStore? store})
    : store = store ?? ProgressStore();

  final ProgressStore store;

  @override
  Future<List<PersonalBest>> recent({int limit = 50}) async {
    // Newest first by dateKey, which sorts lexicographically because it is
    // yyyy-MM-dd. No other ordering is offered, and there is no parameter
    // through which one could be asked for.
    final all = store.bests.values.toList()
      ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return all.length <= limit ? all : all.sublist(0, limit);
  }

  @override
  Future<PersonalBest?> forExercise(String exerciseId) async =>
      store.bests[exerciseId];

  @override
  Future<void> dispose() async {}
}

/// An in-memory [MeasurementsRepository], strict where the real one is strict.
class InMemoryMeasurementsRepository implements MeasurementsRepository {
  InMemoryMeasurementsRepository({ProgressStore? store})
    : store = store ?? ProgressStore();

  final ProgressStore store;

  /// Every save that reached "the server", in order. A test asserts against
  /// this to prove an undone measurement never arrived.
  final List<Measurement> saves = <Measurement>[];

  bool _purged = false;

  /// True once [purgeLocal] has run — G7's A02 row 33.
  bool get purged => _purged;

  @override
  Future<Measurement?> latest() async {
    final history = await historyForOwner(limit: 1);
    return history.isEmpty ? null : history.first;
  }

  @override
  Future<List<Measurement>> historyForOwner({int limit = 24}) async {
    final all = store.measurements.values.toList()
      // By document id, descending. This is `orderBy(__name__, 'desc')`, the
      // only ordering the collection is indexed for.
      ..sort((a, b) => b.dayId.compareTo(a.dayId));
    return all.length <= limit ? all : all.sublist(0, limit);
  }

  @override
  Future<void> save(Measurement measurement) async {
    saves.add(measurement);
    store.applyMeasurement(measurement);
  }

  @override
  Future<void> purgeLocal() async {
    store.measurements.clear();
    saves.clear();
    _purged = true;
  }

  @override
  Future<void> dispose() async {}
}
