/// The coach's window into a client's life, and the boundary that limits it.
///
/// G12's phrase, adopted here: **the projection IS the security boundary.** A
/// withheld field is *absent from the document*, so there is nothing for a rule
/// to hide, nothing for a stale client to render, and nothing for a widget to
/// forget to hide. Revocation therefore **deletes** a key rather than filtering
/// it, and this file is the only writer of all three projections.
///
/// ## The three documents
///
/// | Document | Holds | Rebuilt when |
/// |---|---|---|
/// | `shared/constraints` | allergies, dietary, goal, days, session length, place, equipment, life stage, avoid | her profile or intake changes — rare |
/// | `rollups/{isoWeek}` | sessions planned and logged, meal days, swaps | weekly, and **only while `logs` is on** |
/// | `clientView/current` | last session, adherence, quiet weeks, and the cycle panels **only per switch** | a switch moves, or a projection input changes |
///
/// ## Cycle data cannot be placed in `shared/constraints` at all
///
/// Not "is not placed" — **cannot be**. [SharedConstraints] has nine typed
/// fields and no map, no dynamic, and no member whose type could carry an
/// energy reading, a symptom or a date. [CoachProjectionWriter.buildConstraints]
/// takes no cycle parameter, so there is no argument position for one to arrive
/// in either. `coached_product_rules_test.dart` reads this file's source and
/// fails on the vocabulary, which is what keeps it true after the next edit.
///
/// Cycle-derived values reach the coach through exactly one door:
/// [CyclePanelProjector.build], which **requires** the switches and delegates
/// to G9's `CycleSharingPolicy.projectionFor`. One rule, one implementation —
/// a safety rule with two implementations has one that is weaker.
library;

import 'package:meta/meta.dart';

// `show CycleDocument` is load-bearing rather than tidy: the cycle document
// declares its own `SharingKey` for the three cycle categories, and this
// feature's `SharingKey` has a fourth value — `logs` — that is not a cycle
// category at all. Importing both unqualified makes the name ambiguous, and
// the dangerous resolution of that ambiguity would be to drop this feature's
// enum and use G9's, which would quietly delete the logs switch.
import '../../cycle/domain/cycle_document.dart' show CycleDocument;
import '../../cycle/domain/cycle_sharing_policy.dart';
import 'sharing.dart';

/// `relationships/{relId}/shared/constraints` — the client-authored half of the
/// constraint view.
///
/// Read-only by construction: there is no setter, no `copyWith` and no
/// mutable collection on this type, so a coach screen has no API to type into.
/// HANDOFF 13 says her constraints come from her intake or an assessment and
/// never from a coach screen; this is that sentence as a type.
@immutable
class SharedConstraints {
  const SharedConstraints({
    this.allergies = const <String>[],
    this.dietary = const <String>[],
    this.avoid = const <String>[],
    this.goal,
    this.days,
    this.sessionLength,
    this.place,
    this.equipment = const <String>[],
    this.lifeStage,
    this.sharingV = 1,
  });

  /// From `users/{uid}.profile.allergies`, written by **her** at G17.
  final List<String> allergies;

  /// From `users/{uid}.profile.dietary`, written by **her** at G17.
  final List<String> dietary;

  /// From her intake — "anything we should train around".
  final List<String> avoid;

  final String? goal;
  final int? days;
  final int? sessionLength;
  final String? place;
  final List<String> equipment;
  final String? lifeStage;

  /// Bumped whenever the switches move, so a coach device can tell a fresh
  /// projection from one it fetched before a revocation.
  final int sharingV;

  @override
  String toString() =>
      'SharedConstraints(allergies: $allergies, dietary: $dietary, '
      'avoid: $avoid)';
}

/// `relationships/{relId}/rollups/{yyyy-Www}`.
///
/// Week-keyed, therefore idempotent: rebuilding it twice writes the same
/// document rather than a second one. **Present only while `logs` is on** — an
/// absent rollup is how revocation reads on the coach's side.
@immutable
class WeeklyRollup {
  const WeeklyRollup({
    required this.weekId,
    required this.sessionsPlanned,
    required this.sessionsLogged,
    required this.mealDaysLogged,
    this.swapsUsed = 0,
    this.sharingV = 1,
  });

  final String weekId;
  final int sessionsPlanned;

  /// Sessions with something actually logged. Never a count of prescriptions.
  final int sessionsLogged;

  final int mealDaysLogged;
  final int swapsUsed;
  final int sharingV;

  @override
  String toString() => 'WeeklyRollup($weekId $sessionsLogged/$sessionsPlanned)';
}

/// The keys `clientView/current` may carry.
///
/// The first four are training and food facts; the last three are cycle
/// categories and arrive only through [CyclePanelProjector].
enum ClientViewKey {
  lastSessionAt,
  adherencePct,
  quietWeeks,
  restWeekUsed,
  energyAppetite,
  symptoms,
  datesAndPatterns,
}

/// What a coach's screen gets when it asks for one key.
///
/// Sealed, with a [NotSharedEntry] variant, so "not shared" has to be handled
/// rather than rendering as an empty panel. A nullable return would let a
/// careless widget draw a zero, and **a zero is a clinical claim**: "no
/// symptoms" is not "not shared".
@immutable
sealed class ClientViewEntry {
  const ClientViewEntry();
}

@immutable
final class SharedEntry extends ClientViewEntry {
  const SharedEntry(this.value);

  final Object value;

  @override
  String toString() => 'SharedEntry($value)';
}

@immutable
final class NotSharedEntry extends ClientViewEntry {
  const NotSharedEntry();

  @override
  bool operator ==(Object other) => other is NotSharedEntry;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NotShared';
}

/// `relationships/{relId}/clientView/current`.
///
/// Backed by a map that **holds only the keys that are shared**. [read] returns
/// [NotSharedEntry] for anything absent, and there is no `getOrElse`, no
/// `valueOr` and no default: a caller cannot ask this type to invent a figure.
@immutable
class ClientView {
  const ClientView(this._values, {this.sharingV = 1});

  static const ClientView empty = ClientView(<ClientViewKey, Object>{});

  final Map<ClientViewKey, Object> _values;
  final int sharingV;

  /// The answer for one key. Absent ⇒ [NotSharedEntry].
  ClientViewEntry read(ClientViewKey key) {
    final value = _values[key];
    return value == null ? const NotSharedEntry() : SharedEntry(value);
  }

  /// The keys actually present. A test asserts a revoked key is not in here —
  /// not that it is present and false.
  Set<ClientViewKey> get keys => _values.keys.toSet();

  bool has(ClientViewKey key) => _values.containsKey(key);

  @override
  String toString() => 'ClientView(${keys.map((k) => k.name).join(', ')})';
}

/// The one door cycle-derived values pass through on their way to a coach.
///
/// [build] **requires** [switches]. A projector that could be called without
/// them is a projector that can leak, so there is no default and no overload
/// that omits it. Everything it can return comes from G9's policy, which
/// re-evaluates the grant at read time.
class CyclePanelProjector {
  const CyclePanelProjector({this.policy = const CycleSharingPolicy()});

  final CycleSharingPolicy policy;

  /// The projection for one category, or `NotShared`.
  ///
  /// [live] is whether the relationship is live *right now*. Passed in rather
  /// than inferred, because the caller is the only thing that knows, and a
  /// projector that guessed would be guessing about a consent boundary.
  CycleCategoryProjection build({
    required SharingKey key,
    required SharingSwitches switches,
    required String relId,
    required bool live,
    CycleDocument? cycle,
    List<CoarseDay> days = const <CoarseDay>[],
    int? currentPeriodDay,
  }) {
    final category = key.cycleCategory;
    if (category == null) {
      throw ArgumentError.value(
        key,
        'key',
        'Only the three cycle categories have a projection. Logs are training '
            'and food, and mapping them onto a category is the drift this '
            'refusal exists to prevent.',
      );
    }

    // My switches decide entitlement; G9's policy decides shape. Both must
    // agree, and the second is authoritative about cycle content.
    if (!switches.isLiveFor(key, relId: relId, live: live)) {
      return NotShared(category);
    }

    return policy.projectionFor(
      cycle: cycle,
      relationship: CoachRelationship(
        relId: relId,
        coachUid: relId.split('__').first,
        clientUid: relId.split('__').last,
        status: live ? RelationshipStatus.active : RelationshipStatus.ended,
      ),
      relId: relId,
      category: category,
      days: days,
      currentPeriodDay: currentPeriodDay,
    );
  }
}

/// What a rebuild is made of.
///
/// A plain value object rather than a repository read, so the writer is a pure
/// function of its inputs and the same code can run inside a Cloud Function
/// against the Admin SDK's view of the same documents.
@immutable
class ProjectionInputs {
  const ProjectionInputs({
    this.allergies = const <String>[],
    this.dietary = const <String>[],
    this.avoid = const <String>[],
    this.goal,
    this.days,
    this.sessionLength,
    this.place,
    this.equipment = const <String>[],
    this.lifeStage,
    this.weekId,
    this.sessionsPlanned = 0,
    this.sessionsLogged = 0,
    this.mealDaysLogged = 0,
    this.swapsUsed = 0,
    this.lastSessionAt,
    this.adherencePct,
    this.quietWeeks,
    this.restWeekUsed,
    this.cycle,
    this.coarseDays = const <CoarseDay>[],
    this.currentPeriodDay,
  });

  final List<String> allergies;
  final List<String> dietary;
  final List<String> avoid;
  final String? goal;
  final int? days;
  final int? sessionLength;
  final String? place;
  final List<String> equipment;
  final String? lifeStage;

  final String? weekId;
  final int sessionsPlanned;
  final int sessionsLogged;
  final int mealDaysLogged;
  final int swapsUsed;

  final DateTime? lastSessionAt;
  final int? adherencePct;
  final int? quietWeeks;
  final bool? restWeekUsed;

  final CycleDocument? cycle;
  final List<CoarseDay> coarseDays;
  final int? currentPeriodDay;
}

/// Holds the three projections for one relationship.
///
/// Its mutators are library-private, so [CoachProjectionWriter] — in this same
/// library — is the only thing that can write them. A screen holding a store
/// can read it and cannot change it.
class CoachProjectionStore {
  final Map<String, SharedConstraints> _constraints =
      <String, SharedConstraints>{};
  final Map<String, Map<String, WeeklyRollup>> _rollups =
      <String, Map<String, WeeklyRollup>>{};
  final Map<String, ClientView> _clientViews = <String, ClientView>{};

  /// Every deletion this store performed, for the test that proves revocation
  /// deletes rather than filters.
  final List<String> deletions = <String>[];

  SharedConstraints? constraints(String relId) => _constraints[relId];

  WeeklyRollup? rollup(String relId, String weekId) => _rollups[relId]?[weekId];

  Map<String, WeeklyRollup> rollups(String relId) =>
      Map.unmodifiable(_rollups[relId] ?? const <String, WeeklyRollup>{});

  /// `clientView/current`, or null when there is none at all.
  ClientView? clientView(String relId) => _clientViews[relId];

  void _putConstraints(String relId, SharedConstraints value) {
    _constraints[relId] = value;
  }

  void _putRollup(String relId, WeeklyRollup value) {
    _rollups.putIfAbsent(relId, () => <String, WeeklyRollup>{})[value.weekId] =
        value;
  }

  void _putClientView(String relId, ClientView value) {
    _clientViews[relId] = value;
  }

  void _deleteRollups(String relId) {
    if (_rollups.remove(relId) != null) {
      deletions.add('relationships/$relId/rollups');
    }
  }

  void _deleteConstraints(String relId) {
    if (_constraints.remove(relId) != null) {
      deletions.add('relationships/$relId/shared/constraints');
    }
  }

  void _deleteClientView(String relId) {
    if (_clientViews.remove(relId) != null) {
      deletions.add('relationships/$relId/clientView/current');
    }
  }
}

/// The **only** writer of `shared/`, `rollups/` and `clientView/`.
///
/// It reads the switches at projection time and never a cached copy, and it
/// deletes withheld keys rather than filtering them. Both properties are what
/// make a revocation real on the coach's device rather than cosmetic.
class CoachProjectionWriter {
  const CoachProjectionWriter({
    this.store,
    this.projector = const CyclePanelProjector(),
  });

  /// Where the three documents live. Injectable so the same writer runs in a
  /// test and in a Function.
  final CoachProjectionStore? store;

  final CyclePanelProjector projector;

  /// `shared/constraints`, built from her profile and her intake.
  ///
  /// **There is no cycle parameter, and no field to put one in.** See the
  /// library comment.
  SharedConstraints buildConstraints(
    ProjectionInputs inputs, {
    int sharingV = 1,
  }) => SharedConstraints(
    allergies: List.unmodifiable(inputs.allergies),
    dietary: List.unmodifiable(inputs.dietary),
    avoid: List.unmodifiable(inputs.avoid),
    goal: inputs.goal,
    days: inputs.days,
    sessionLength: inputs.sessionLength,
    place: inputs.place,
    equipment: List.unmodifiable(inputs.equipment),
    lifeStage: inputs.lifeStage,
    sharingV: sharingV,
  );

  /// Rebuilds all three projections for [relId].
  ///
  /// Returns the client view it wrote so a caller can assert on it without
  /// reaching into the store.
  ///
  ///  * `shared/constraints` is written whatever the switches say — it is her
  ///    allergy list, and a coach planning her meals must have it. It carries
  ///    no cycle data under any switch, which is why that is safe.
  ///  * `rollups/{week}` exists **only while `logs` is on**, and is deleted
  ///    outright when it is not.
  ///  * `clientView/current` carries a cycle key **only** when that switch is
  ///    live for this relationship, and the key is absent otherwise.
  ClientView rebuild({
    required String relId,
    required SharingSwitches switches,
    required bool live,
    required ProjectionInputs inputs,
    int sharingV = 1,
  }) {
    final target = store;

    target?._putConstraints(
      relId,
      buildConstraints(inputs, sharingV: sharingV),
    );

    if (switches.isLiveFor(SharingKey.logs, relId: relId, live: live)) {
      final weekId = inputs.weekId;
      if (weekId != null) {
        target?._putRollup(
          relId,
          WeeklyRollup(
            weekId: weekId,
            sessionsPlanned: inputs.sessionsPlanned,
            sessionsLogged: inputs.sessionsLogged,
            mealDaysLogged: inputs.mealDaysLogged,
            swapsUsed: inputs.swapsUsed,
            sharingV: sharingV,
          ),
        );
      }
    } else {
      // Deleted, not filtered. There is nothing left on the coach's side to
      // hide, which is the whole of HANDOFF rule 6's teeth.
      target?._deleteRollups(relId);
    }

    final values = <ClientViewKey, Object>{};

    if (switches.isLiveFor(SharingKey.logs, relId: relId, live: live)) {
      final lastSessionAt = inputs.lastSessionAt;
      final adherence = inputs.adherencePct;
      final quiet = inputs.quietWeeks;
      final restWeek = inputs.restWeekUsed;
      if (lastSessionAt != null) {
        values[ClientViewKey.lastSessionAt] = lastSessionAt;
      }
      if (adherence != null) values[ClientViewKey.adherencePct] = adherence;
      if (quiet != null) values[ClientViewKey.quietWeeks] = quiet;
      if (restWeek != null) values[ClientViewKey.restWeekUsed] = restWeek;
    }

    for (final key in const [
      SharingKey.energyAppetite,
      SharingKey.symptoms,
      SharingKey.datesAndPatterns,
    ]) {
      final projection = projector.build(
        key: key,
        switches: switches,
        relId: relId,
        live: live,
        cycle: inputs.cycle,
        days: inputs.coarseDays,
        currentPeriodDay: inputs.currentPeriodDay,
      );
      // NotShared is never written. An absent key is the representation of
      // "not shared", and writing a marker would be a field for a stale client
      // to render as a value.
      if (projection is NotShared) continue;
      values[_viewKeyFor(key)] = projection;
    }

    final view = ClientView(Map.unmodifiable(values), sharingV: sharingV);
    target?._putClientView(relId, view);
    return view;
  }

  /// The relationship has ended: clear everything derived from it.
  ///
  /// Returns the switches as they must now be stored — all off. G16's line
  /// "Cycle sharing switched itself off when the coaching ended" is this
  /// method, not a sentence on a screen.
  SharingSwitches onRelationshipEnded(String relId) {
    final target = store;
    target?._deleteConstraints(relId);
    target?._deleteRollups(relId);
    target?._deleteClientView(relId);
    return SharingSwitches.off;
  }

  static ClientViewKey _viewKeyFor(SharingKey key) => switch (key) {
    SharingKey.energyAppetite => ClientViewKey.energyAppetite,
    SharingKey.symptoms => ClientViewKey.symptoms,
    SharingKey.datesAndPatterns => ClientViewKey.datesAndPatterns,
    SharingKey.logs => throw ArgumentError('logs is not a cycle panel'),
  };
}
