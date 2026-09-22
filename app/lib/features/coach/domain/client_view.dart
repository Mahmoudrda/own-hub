/// What a coach may know about a client — and the shape that makes the sharing
/// switches true rather than promised.
///
/// # A coach never reads a client's documents
///
/// G12 §1.4 states it as a denial, not an intention: *"I never read
/// `users/{clientUid}/**` from a coach session. Not 'should not' — the rules deny
/// it."* Everything she sees is a **Cloud-Function-materialised projection**
/// at `relationships/{relId}/clientView/current`, filtered by the client's own
/// switches before it is written.
///
/// [ClientViewReader] therefore takes a `relId` and returns a [ClientView], and
/// there is **no method anywhere in this feature that takes a client uid**. A
/// rules mistake cannot leak what the switch denies, because the field is not in
/// the document to leak (G12 §6, `P1-RULE-15`).
///
/// # Withheld means absent, not hidden
///
/// The switches are enforced by **absence**. When a client revokes one, the
/// Cloud Function deletes the field, so [ClientView] carries null and the screen
/// has nothing to draw. A projection that carried the value and a flag saying
/// "do not show it" would put the data on the coach's device and trust the UI —
/// which is what `P1-RULE-15` exists to fail.
///
/// [ClientView.cycle] is the sharpest case. Cycle data is unreachable unless
/// that switch is on, and "not shared" never means "no symptoms" — so a screen
/// given null says nothing at all rather than "none".
///
/// # Constraints are read-only, by type
///
/// HANDOFF 13: the assessment and her intake are the only two sources of a
/// client's constraints. [ClientConstraints] is immutable, has no `copyWith`, no
/// setters and **no repository write method**, so no coach screen can bind a
/// text field to an avoid list. `P1-RULE-12` searches for exactly that control
/// and there is nothing for it to bind to.
///
/// # The honest limit, recorded
///
/// G12 §4: a client who revokes a switch while the coach is **offline** does not
/// revoke the coach's *cached* panel until she reconnects. The server-side
/// projection is emptied immediately and the next read returns nothing, but a
/// screen already rendered on her device is beyond reach. Copy must not promise
/// otherwise, and [ClientView.asOf] exists so a screen can say when it was last
/// true.
library;

import 'package:meta/meta.dart';

/// A client's constraints, as the assessment recorded them.
///
/// Immutable, with no way back. See the file note.
@immutable
class ClientConstraints {
  const ClientConstraints({
    this.avoid = const <String>[],
    this.allergies = const <String>[],
    this.equipment = const <String>[],
    this.sessionMinutes,
    this.daysPerWeek,
  });

  /// Nothing is known. Distinct from "nothing to avoid": a coach must be able to
  /// tell the difference between an answered assessment and a missing one.
  static const ClientConstraints unknown = ClientConstraints();

  /// Movements or positions to stay away from.
  final List<String> avoid;

  /// From her dietary profile. The one place allergies come from.
  final List<String> allergies;

  final List<String> equipment;
  final int? sessionMinutes;
  final int? daysPerWeek;

  /// Whether an assessment has been answered at all.
  bool get isKnown =>
      avoid.isNotEmpty ||
      allergies.isNotEmpty ||
      equipment.isNotEmpty ||
      sessionMinutes != null ||
      daysPerWeek != null;
}

/// How her week is going, as the projection states it.
///
/// Every field is nullable and null means the switch is off. There is no
/// "shared: false" boolean, because a boolean beside a value is a value on the
/// coach's device.
@immutable
class ClientWeekSignal {
  const ClientWeekSignal({
    this.sessionsLogged,
    this.sessionsTarget,
    this.quietWeeksInARow,
    this.restWeekAlreadyUsed,
  });

  final int? sessionsLogged;
  final int? sessionsTarget;

  /// How many weeks in a row have come up short.
  ///
  /// **Not a streak.** §2 rule 3 forbids a consecutive-*day* counter; this
  /// counts weeks, which is the only unit this product has, and it counts
  /// *quiet* weeks so that `K16`'s banner can say "second quiet week" — a reason
  /// to be kind, never a score.
  final int? quietWeeksInARow;

  final bool? restWeekAlreadyUsed;

  /// Whether `K16`'s amber banner has anything true to say.
  bool get warrantsBanner => (quietWeeksInARow ?? 0) >= 2;
}

/// The projection, as one object.
@immutable
class ClientView {
  const ClientView({
    required this.relId,
    required this.displayName,
    this.constraints,
    this.week,
    this.cycle,
    this.asOf,
  });

  /// Nothing has been shared, or there is no projection yet.
  factory ClientView.empty(String relId) =>
      ClientView(relId: relId, displayName: '');

  final String relId;

  /// Her name, as G11 projects it.
  final String displayName;

  /// Null when the assessment switch is off or no assessment exists.
  final ClientConstraints? constraints;

  /// Null when she has not shared her logs.
  final ClientWeekSignal? week;

  /// **Null unless she turned cycle sharing on**, which is off by default and
  /// independent of every other switch (HANDOFF 6, spine C12).
  ///
  /// A `String?` carrying the one phase word the projection includes, and
  /// nothing else. There is no cycle date, no symptom list and no history here,
  /// because a coach has no reason for any of it.
  final String? cycle;

  /// When the projection was materialised.
  ///
  /// Rendered by `K16` when the document came from cache, because of the honest
  /// limit in the file note: a cached panel outlives a revocation until she
  /// reconnects, and the screen must not imply otherwise.
  final DateTime? asOf;

  /// Whether anything at all has been shared.
  bool get isEmpty => constraints == null && week == null && cycle == null;
}

/// Reads the projection. **The only door from a coach session to anything about
/// a client.**
///
/// There is no `forClient(uid)` overload, and adding one would be the defect:
/// every method here keys on a relationship, so a coach can only ask about
/// someone she actually coaches.
abstract class ClientViewReader {
  /// The projection for one relationship, or an empty view.
  Future<ClientView> forRelationship(String relId);
}

/// Her constraints, read through the projection and never written.
///
/// A separate interface from [ClientViewReader] so that a screen needing only
/// constraints is handed only constraints — and so `P1-RULE-12`'s "the value
/// object is immutable and has no write method" is a statement about a type
/// somebody actually holds.
class ClientConstraintsReader {
  const ClientConstraintsReader(this._view);

  final ClientViewReader _view;

  /// What she may know, or [ClientConstraints.unknown].
  ///
  /// Never null: a missing projection and an unanswered assessment are both
  /// "we do not know", and a nullable return would tempt a caller into
  /// `?? const ClientConstraints()` which says the same thing less clearly.
  Future<ClientConstraints> forRelationship(String relId) async {
    final view = await _view.forRelationship(relId);
    return view.constraints ?? ClientConstraints.unknown;
  }
}

/// An in-memory projection, strict in the way the Cloud Function is strict.
///
/// [revoke] **deletes** the field rather than blanking it, which is the whole
/// mechanism: a test that revoked by setting a flag would prove nothing, because
/// the security property is that the value is not in the document.
class InMemoryClientViewProjection implements ClientViewReader {
  InMemoryClientViewProjection([Map<String, ClientView>? seed])
    : _views = {...?seed};

  final Map<String, ClientView> _views;

  /// How many documents have been read. `P0-CSCALE-01` counts reads, so the fake
  /// has to be able to report them.
  int reads = 0;

  void put(ClientView view) => _views[view.relId] = view;

  /// A client turned a switch off. The field leaves the document.
  void revoke(
    String relId, {
    bool constraints = false,
    bool week = false,
    bool cycle = false,
  }) {
    final current = _views[relId];
    if (current == null) return;
    _views[relId] = ClientView(
      relId: current.relId,
      displayName: current.displayName,
      constraints: constraints ? null : current.constraints,
      week: week ? null : current.week,
      cycle: cycle ? null : current.cycle,
      asOf: current.asOf,
    );
  }

  @override
  Future<ClientView> forRelationship(String relId) async {
    reads++;
    return _views[relId] ?? ClientView.empty(relId);
  }
}
