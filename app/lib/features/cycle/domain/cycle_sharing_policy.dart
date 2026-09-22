/// HANDOFF rule 6 / spine C12 — the **only** function that can turn cycle data
/// into something a coach sees.
///
/// Plan §5: "Returns `notShared` unless `sharing.<category> == true` **and**
/// `grantedForRelId == relId` **and** the relationship is `active`. Evaluated at
/// read time (C10's pattern), so revocation and a finished relationship both
/// take effect without a revocation write."
///
/// ## Why read time is the whole design
///
/// §3.4: "`orphaned` is the state that makes the product's own promise true:
/// *'Cycle sharing switched itself off when the coaching ended.'* It is
/// evaluated **at read time**, exactly as C10 evaluates result consent, so it
/// holds even when her handset is offline and no revocation write has synced."
///
/// A grant copied into the coach's view at publish time would survive the
/// relationship that produced it. Nothing here is copied anywhere: every read
/// re-evaluates all three conditions, so there is no cached "yes" to go stale.
///
/// ## `notShared` is a value, never an absence
///
/// §5: "An explicit value, not an empty list — W02's panel must be able to say
/// 'not shared', because 'not shared' is not 'no symptoms' and a coach reading
/// absence as wellness is a clinical error the UI would have caused."
///
/// That is why [CycleCategoryProjection] is sealed with a [NotShared] variant
/// rather than the projection being nullable. A null would let a careless
/// renderer draw an empty panel; a [NotShared] has to be handled.
library;

import 'package:meta/meta.dart';

import 'cycle_document.dart';
import 'today_check_in.dart';

/// The three independent sharing categories (plan §7.2's contract table).
enum CycleCategory { energyAppetite, symptoms, datesAndPatterns }

/// G11's relationship status. Only `active` can carry a grant.
enum RelationshipStatus { pending, active, ended, expired }

/// The slice of G11's `relationships/{relId}` this policy reads.
///
/// A forward interface: G11 has no Stage 2 plan yet, so this is the shape the
/// cycle group needs rather than the whole document.
@immutable
class CoachRelationship {
  const CoachRelationship({
    required this.relId,
    required this.coachUid,
    required this.clientUid,
    required this.status,
  });

  /// Exactly `{coachUid}__{clientUid}` — double underscore (spine §8). The
  /// spelling is load-bearing: the Storage rules parse it.
  final String relId;

  final String coachUid;
  final String clientUid;
  final RelationshipStatus status;

  bool get isActive => status == RelationshipStatus.active;
}

/// One day of coarse values, with **no date on it**.
///
/// The contract table's "never contains" column for `energyAppetite` and
/// `symptoms` begins with "a date". So the projection carries an ordered list
/// and no day keys: a coach sees the shape of her week without being handed the
/// calendar it came from, and there is no field for a date to be added to
/// later without a visible change.
@immutable
class CoarseDay {
  const CoarseDay({
    this.energy,
    this.appetite,
    this.cramps,
    this.bloating,
    this.sleep,
  });

  final Energy? energy;
  final Appetite? appetite;
  final Cramps? cramps;
  final Bloating? bloating;
  final Sleep? sleep;
}

/// What a coach may render for one category.
@immutable
sealed class CycleCategoryProjection {
  const CycleCategoryProjection();

  /// Which category this answers for.
  CycleCategory get category;
}

/// Not shared — an explicit marker, never an empty panel or a zero.
@immutable
final class NotShared extends CycleCategoryProjection {
  const NotShared(this.category);

  @override
  final CycleCategory category;

  /// Why it is not shared. For the coach's UI this is irrelevant — all three
  /// render identically — but it is what makes `P0-CYC-15` testable without
  /// reaching into the policy's internals.
  @override
  bool operator ==(Object other) =>
      other is NotShared && other.category == category;

  @override
  int get hashCode => category.hashCode;
}

/// Last 7 days of energy and appetite, coarse. Never a date, phase or period
/// day — there is no field for one.
@immutable
final class EnergyAppetiteProjection extends CycleCategoryProjection {
  const EnergyAppetiteProjection(this.days);

  final List<CoarseDay> days;

  @override
  CycleCategory get category => CycleCategory.energyAppetite;
}

/// Last 7 days of cramps, bloating and sleep, coarse. Never free text, a
/// severity trend line, or any inference.
@immutable
final class SymptomsProjection extends CycleCategoryProjection {
  const SymptomsProjection(this.days);

  final List<CoarseDay> days;

  @override
  CycleCategory get category => CycleCategory.symptoms;
}

/// Current period day and recent starts.
///
/// **No ovulation date and no fertile window**, and note there is no field
/// either could be written to — the contract's "never contains" column is
/// enforced by the type, not by a reviewer checking a map.
@immutable
final class DatesAndPatternsProjection extends CycleCategoryProjection {
  const DatesAndPatternsProjection({
    required this.currentPeriodDay,
    required this.recentStarts,
  });

  /// Which day of her current period it is, or null if she is not on one.
  final int? currentPeriodDay;

  /// At most twelve `yyyy-MM-dd` start dates.
  final List<String> recentStarts;

  @override
  CycleCategory get category => CycleCategory.datesAndPatterns;
}

/// The read-time state of one switch (plan §3.4).
enum SharingGrantState {
  /// The switch is false.
  ///
  /// §3.4 lists `revoked` as a separate state, and at *read* time it is
  /// indistinguishable from `off` — which is correct rather than a gap: both
  /// mean "she has not granted this", and a coach must not be able to tell
  /// whether she once did. The distinction is a transition, not an observation.
  off,

  /// True, bound to this relationship, and the relationship is live.
  granted,

  /// True, but the grant belongs to a relationship that has ended or to a
  /// different relationship entirely. **A grant never survives into a new
  /// coaching relationship.**
  orphaned,
}

/// The one function that can turn cycle data into something a coach sees.
class CycleSharingPolicy {
  const CycleSharingPolicy();

  /// The read-time state of [category] for [relId].
  SharingGrantState stateFor({
    required CycleDocument? cycle,
    required CoachRelationship? relationship,
    required String relId,
    required CycleCategory category,
  }) {
    if (cycle == null) return SharingGrantState.off;

    final on = switch (category) {
      CycleCategory.energyAppetite => cycle.sharing.energyAppetite,
      CycleCategory.symptoms => cycle.sharing.symptoms,
      CycleCategory.datesAndPatterns => cycle.sharing.datesAndPatterns,
    };
    if (!on) return SharingGrantState.off;

    // The grant is bound to one relationship and is not inherited by the next.
    if (cycle.sharing.grantedForRelId != relId) {
      return SharingGrantState.orphaned;
    }

    // …and it is live only while that relationship is.
    if (relationship == null ||
        relationship.relId != relId ||
        !relationship.isActive) {
      return SharingGrantState.orphaned;
    }

    return SharingGrantState.granted;
  }

  /// The projection a coach may render, or [NotShared].
  ///
  /// [days] and [currentPeriodDay] are the already-computed coarse inputs; this
  /// function decides only whether she is entitled to see them. Passing the data
  /// in rather than reading it here is what lets the same policy run inside the
  /// `getCycleProjection` Cloud Function (§6 R4) against the Admin SDK's view of
  /// the same documents.
  CycleCategoryProjection projectionFor({
    required CycleDocument? cycle,
    required CoachRelationship? relationship,
    required String relId,
    required CycleCategory category,
    List<CoarseDay> days = const <CoarseDay>[],
    int? currentPeriodDay,
  }) {
    final state = stateFor(
      cycle: cycle,
      relationship: relationship,
      relId: relId,
      category: category,
    );

    if (state != SharingGrantState.granted) return NotShared(category);

    return switch (category) {
      CycleCategory.energyAppetite => EnergyAppetiteProjection(
        days.take(projectionWindowDays).toList(),
      ),
      CycleCategory.symptoms => SymptomsProjection(
        days.take(projectionWindowDays).toList(),
      ),
      CycleCategory.datesAndPatterns => DatesAndPatternsProjection(
        currentPeriodDay: currentPeriodDay,
        recentStarts: cycle!.recentStarts
            .take(CycleDocument.maxRecentStarts)
            .toList(),
      ),
    };
  }

  /// "last 7 days" from the contract table, in one place.
  static const int projectionWindowDays = 7;
}
