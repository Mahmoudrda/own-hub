/// HANDOFF rule 6 — **four independent switches, all default off, and no way to
/// say "share everything".**
///
/// The rule is usually written as a policy and implemented as a map with a
/// convenience setter that turns everything on. This file makes the convenience
/// setter unrepresentable instead:
///
///  * [SharingSwitches] holds four named booleans. There is no `Map<String,
///    bool>`, so a typo cannot become a silent grant, and no `all`, `enableAll`
///    or `shareEverything` constructor exists for a screen to call.
///  * Every one of the four defaults to **false**. `const SharingSwitches()`
///    is the off state, so a relationship created with no sharing argument
///    shares nothing.
///  * [set] takes exactly one [SharingKey] and one boolean. Flipping one switch
///    cannot move another — asserted by test over every pair.
///
/// ## The grant dies with the relationship
///
/// [SharingSwitches.grantedForRelId] binds the grant to one relationship. It is
/// set by [set] from the relationship it was called for, and there is no
/// constructor parameter that lets a caller name a different one. A grant made
/// for a relationship that has ended is therefore **orphaned** rather than
/// inherited — and [isLiveFor] evaluates that at *read* time, so it holds on a
/// handset that was offline when the coaching ended and has never heard that it
/// did. This is the same read-time evaluation G9's `CycleSharingPolicy` makes,
/// deliberately: two copies of one rule are how one of them rots.
///
/// ## An absent key is never a zero
///
/// Revocation **deletes** the key from the coach's projection rather than
/// filtering it — see `coach_projection.dart`. This file is the switch; that
/// file is the boundary.
library;

import 'package:meta/meta.dart';

import '../../cycle/domain/cycle_sharing_policy.dart' show CycleCategory;

/// The four independent switches. G9's category names are adopted verbatim so
/// the switch and the projection cannot drift apart.
///
/// There is deliberately **no fifth value meaning "all of the above"**. A
/// master switch in this enum is what HANDOFF rule 6 forbids, and an enum is
/// where it would have to be added.
enum SharingKey {
  /// Her workout results and food logs — the coach's rollups.
  logs,

  /// Coarse energy and appetite, from My cycle.
  energyAppetite,

  /// Coarse cramps, bloating and sleep, from My cycle.
  symptoms,

  /// Period day and recent starts.
  datesAndPatterns;

  /// The three that are cycle-derived, and the one that is not.
  ///
  /// Null for [logs]: logs are training and food, and mapping them onto a cycle
  /// category is precisely the drift this getter exists to prevent.
  CycleCategory? get cycleCategory => switch (this) {
    SharingKey.logs => null,
    SharingKey.energyAppetite => CycleCategory.energyAppetite,
    SharingKey.symptoms => CycleCategory.symptoms,
    SharingKey.datesAndPatterns => CycleCategory.datesAndPatterns,
  };
}

/// `relationships/{relId}.sharing` — four booleans and the relationship the
/// grant belongs to.
@immutable
class SharingSwitches {
  /// Every switch off. This is the default state of every new relationship, and
  /// it is the only state this constructor can produce without an argument.
  const SharingSwitches({
    this.logs = false,
    this.energyAppetite = false,
    this.symptoms = false,
    this.datesAndPatterns = false,
    this.grantedForRelId,
  });

  /// The state every relationship begins in.
  static const SharingSwitches off = SharingSwitches();

  final bool logs;
  final bool energyAppetite;
  final bool symptoms;
  final bool datesAndPatterns;

  /// The relationship this grant belongs to. Null while nothing is granted.
  final String? grantedForRelId;

  bool operator [](SharingKey key) => switch (key) {
    SharingKey.logs => logs,
    SharingKey.energyAppetite => energyAppetite,
    SharingKey.symptoms => symptoms,
    SharingKey.datesAndPatterns => datesAndPatterns,
  };

  /// True when nothing at all is shared.
  bool get isAllOff =>
      !logs && !energyAppetite && !symptoms && !datesAndPatterns;

  /// The keys currently on, in declaration order. Used to *render*, never to
  /// grant: reading this for a coach's panel would skip [isLiveFor].
  List<SharingKey> get on =>
      SharingKey.values.where((key) => this[key]).toList();

  /// Moves exactly one switch, binding the grant to [relId].
  ///
  /// The relationship id is **required**. A grant that did not name its
  /// relationship would be a grant the next coach could inherit, which is the
  /// failure this whole file is shaped against.
  SharingSwitches set(SharingKey key, bool value, {required String relId}) {
    final next = SharingSwitches(
      logs: key == SharingKey.logs ? value : logs,
      energyAppetite: key == SharingKey.energyAppetite ? value : energyAppetite,
      symptoms: key == SharingKey.symptoms ? value : symptoms,
      datesAndPatterns: key == SharingKey.datesAndPatterns
          ? value
          : datesAndPatterns,
      grantedForRelId: relId,
    );
    // With nothing granted there is nothing for the id to bind, and leaving a
    // stale id behind would make "she once shared" readable from the document.
    return next.isAllOff ? SharingSwitches.off : next;
  }

  /// Clears every switch. Called when a relationship ends, and by nothing else.
  SharingSwitches cleared() => SharingSwitches.off;

  /// Whether [key] is granted **to this relationship, right now**.
  ///
  /// Three conditions, evaluated at read time: the switch is on, the grant
  /// names this relationship, and the relationship is live. A handset that was
  /// offline when the coaching ended still answers false, because nothing here
  /// consults a cached "yes".
  bool isLiveFor(SharingKey key, {required String relId, required bool live}) {
    if (!this[key]) return false;
    if (grantedForRelId != relId) return false;
    return live;
  }

  @override
  bool operator ==(Object other) =>
      other is SharingSwitches &&
      other.logs == logs &&
      other.energyAppetite == energyAppetite &&
      other.symptoms == symptoms &&
      other.datesAndPatterns == datesAndPatterns &&
      other.grantedForRelId == grantedForRelId;

  @override
  int get hashCode => Object.hash(
    logs,
    energyAppetite,
    symptoms,
    datesAndPatterns,
    grantedForRelId,
  );

  @override
  String toString() =>
      'SharingSwitches(${on.map((k) => k.name).join(', ')}'
      '${grantedForRelId == null ? '' : ' for $grantedForRelId'})';
}

/// What the app may say about a revocation that has not synced.
///
/// G11 §4 and `P0-SHARE-03`: offline, the switch flips on her handset at once
/// and the coach's panel still carries yesterday's projection until the write
/// syncs. **A server cannot deny a read it has not been told about.** So the
/// copy says it applies everywhere as soon as she has signal, and never says
/// "immediately".
enum SharingSyncState {
  /// The server has the new position.
  applied,

  /// Her handset has it; the server has not heard yet.
  savedOnDevice,
}
