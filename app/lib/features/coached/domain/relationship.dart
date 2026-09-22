/// The coaching relationship, and the transitions it is allowed to make.
///
/// G11 §3.1. Twelve states, and the two properties that matter most are both
/// about what is **missing** from the event list:
///
///  1. **There is no `messageSent` event.** Not "it is ignored" — it does not
///     exist, so a message cannot reach a transition in this table at all. That
///     is §2.2's first half made structural: a coach who types "I've shortened
///     Thursday" moves nothing.
///  2. **The only way into [RelationshipState.active] is
///     [RelationshipEvent.coachPublishedPlan].** Every other event that tries
///     returns null, and [RelationshipStateMachine.next] returning null means
///     "that cannot happen from here" rather than "nothing changed".
///
/// ## Ending
///
/// [EndCoaching] is the one place a relationship ends, and it does three things
/// in one call: moves the state, clears the switches, and deletes the three
/// derived projections. Splitting them across call sites is how a relationship
/// ends on one screen and a coach keeps a panel.
///
/// **Ending may confirm.** G11 §5 names paying and ending coaching as the two
/// deliberate exceptions to rule 9 — destructive, non-logging, irreversible
/// acts, the same carve-out block and account deletion already have. Everything
/// else in this feature is undo, not confirmation.
library;

import 'package:meta/meta.dart';

import 'coach_projection.dart';
import 'message_repository.dart';
import 'sharing.dart';

/// Where a relationship is.
///
/// The plan's diagram names ten boxes; this enum has twelve values because
/// `refunded` and `declined` are drawn as terminal leaves rather than boxes.
/// Stated rather than quietly reconciled: a state that exists in the product
/// and not in the type is a state nothing can test.
enum RelationshipState {
  /// She asked a question before deciding. No money has moved.
  enquiry,

  /// The coach declined the enquiry. The thread stays readable.
  declined,

  /// Checkout has been created. **Not live**: nothing is shared, nothing is
  /// assigned, and the app must not behave as though she has a coach.
  awaitingPayment,

  /// Paid, waiting for the coach to accept within her window.
  awaitingAcceptance,

  /// The coach declined or the clock ran out; the money is on its way back.
  refunding,

  /// Settled. Terminal.
  refunded,

  /// She is filling in G01 → G17 → G02.
  intake,

  /// Intake submitted; the coach is writing the plan. **Nothing is faked.**
  preparing,

  /// A plan has been published. G04 is the tab root.
  active,

  /// Five days out. One notification, renewal offered, never auto-charged.
  endingSoon,

  /// Over. History is readable; new assignments and messages are closed.
  ended,

  /// A report was upheld or someone blocked someone. Messages closed both ways.
  suspended;

  /// The states in which the two parties may write to each other.
  ///
  /// Matches the rules' `live()` list exactly. `awaitingPayment` is absent on
  /// purpose: money has not landed, so there is nothing to be live about.
  bool get isLive => switch (this) {
    RelationshipState.enquiry ||
    RelationshipState.awaitingAcceptance ||
    RelationshipState.intake ||
    RelationshipState.preparing ||
    RelationshipState.active ||
    RelationshipState.endingSoon => true,
    _ => false,
  };

  /// Nothing follows these.
  bool get isTerminal => switch (this) {
    RelationshipState.declined ||
    RelationshipState.refunded ||
    RelationshipState.ended => true,
    _ => false,
  };

  /// Whether an assignment may be running.
  bool get hasPlan =>
      this == RelationshipState.active || this == RelationshipState.endingSoon;
}

/// Everything that can move a relationship.
///
/// Read this list for what is not on it. There is no message event, no "coach
/// said the plan changed", and no event a client's device can raise that
/// touches money or capacity — those are server acts, and the client learns
/// about them by reading.
enum RelationshipEvent {
  coachAcceptedEnquiry,
  coachDeclinedEnquiry,
  checkoutCreated,
  paymentPaid,
  paymentFailed,
  coachAccepted,
  coachDeclined,
  acceptanceWindowElapsed,
  refundSettled,
  intakeSubmitted,

  /// **The only door into `active`.** Named for the callable that raises it.
  coachPublishedPlan,

  endDateApproaching,
  endDateReached,
  endedEarly,
  suspended,
}

/// `relationships/{relId}` as this feature reads it.
@immutable
class Relationship {
  const Relationship({
    required this.ref,
    required this.state,
    this.sharing = SharingSwitches.off,
    this.startedAt,
    this.endsAt,
    this.engagementId,
    this.planVersion,
    this.priceEGP,
    this.replyWindowMins,
  });

  final RelationshipRef ref;
  final RelationshipState state;

  /// Four booleans, all off until she moves one.
  final SharingSwitches sharing;

  final DateTime? startedAt;
  final DateTime? endsAt;
  final String? engagementId;

  /// The version currently published, if any.
  final String? planVersion;

  /// The **agreed** price, copied at acceptance, so a later price rise cannot
  /// reach an existing client.
  final int? priceEGP;

  final int? replyWindowMins;

  String get relId => ref.relId;
  bool get isLive => state.isLive;

  Relationship copyWith({
    RelationshipState? state,
    SharingSwitches? sharing,
    DateTime? startedAt,
    DateTime? endsAt,
    String? engagementId,
    String? planVersion,
  }) => Relationship(
    ref: ref,
    state: state ?? this.state,
    sharing: sharing ?? this.sharing,
    startedAt: startedAt ?? this.startedAt,
    endsAt: endsAt ?? this.endsAt,
    engagementId: engagementId ?? this.engagementId,
    planVersion: planVersion ?? this.planVersion,
    priceEGP: priceEGP,
    replyWindowMins: replyWindowMins,
  );

  @override
  String toString() => 'Relationship($relId ${state.name})';
}

/// The transition table, as a function.
class RelationshipStateMachine {
  const RelationshipStateMachine();

  /// The state [event] leads to from [from], or **null when it cannot happen**.
  ///
  /// Null rather than `from`, deliberately. Returning the current state would
  /// make an illegal transition indistinguishable from a no-op, and "the
  /// publish did nothing" is exactly the bug this table exists to surface.
  RelationshipState? next(RelationshipState from, RelationshipEvent event) {
    // Two events are legal from almost anywhere, so they are handled before the
    // table rather than repeated in every row.
    if (event == RelationshipEvent.suspended && !from.isTerminal) {
      return RelationshipState.suspended;
    }
    if (event == RelationshipEvent.endedEarly && from.isLive) {
      return RelationshipState.ended;
    }

    return switch ((from, event)) {
      (RelationshipState.enquiry, RelationshipEvent.coachDeclinedEnquiry) =>
        RelationshipState.declined,
      (RelationshipState.enquiry, RelationshipEvent.coachAcceptedEnquiry) =>
        RelationshipState.awaitingPayment,
      // D21. There is deliberately NO (enquiry, checkoutCreated) transition.
      //
      // It used to be here, and it was buy-direct surviving in the model after
      // the product removed it: a checkout could be created straight from an
      // enquiry, so a woman could pay before her coach had accepted her. The
      // marketplace's own gate refused it, but a rule enforced in one caller
      // and not in the state machine is a rule that holds until the second
      // caller arrives.
      //
      // The only door into awaitingPayment is `coachAcceptedEnquiry`, above,
      // which is what makes "she pays only once you accept" true on every
      // path rather than on the paths somebody remembered.

      (RelationshipState.awaitingPayment, RelationshipEvent.paymentPaid) =>
        RelationshipState.awaitingAcceptance,
      // Nothing was charged, so she goes back to where she was.
      (RelationshipState.awaitingPayment, RelationshipEvent.paymentFailed) =>
        RelationshipState.enquiry,

      (RelationshipState.awaitingAcceptance, RelationshipEvent.coachAccepted) =>
        RelationshipState.intake,
      (RelationshipState.awaitingAcceptance, RelationshipEvent.coachDeclined) =>
        RelationshipState.refunding,
      (
        RelationshipState.awaitingAcceptance,
        RelationshipEvent.acceptanceWindowElapsed,
      ) =>
        RelationshipState.refunding,

      (RelationshipState.refunding, RelationshipEvent.refundSettled) =>
        RelationshipState.refunded,

      (RelationshipState.intake, RelationshipEvent.intakeSubmitted) =>
        RelationshipState.preparing,

      // The one door into active, from either side of the wait.
      (RelationshipState.preparing, RelationshipEvent.coachPublishedPlan) =>
        RelationshipState.active,

      (RelationshipState.active, RelationshipEvent.endDateApproaching) =>
        RelationshipState.endingSoon,
      (RelationshipState.active, RelationshipEvent.endDateReached) =>
        RelationshipState.ended,
      (RelationshipState.endingSoon, RelationshipEvent.endDateReached) =>
        RelationshipState.ended,

      _ => null,
    };
  }

  /// Whether [event] can move [from] at all.
  bool can(RelationshipState from, RelationshipEvent event) =>
      next(from, event) != null;
}

/// What ending produced, so a caller can assert on it rather than inspect a
/// store.
@immutable
class EndedCoaching {
  const EndedCoaching({required this.relationship, required this.deletedPaths});

  /// The relationship as it is now: `ended`, with every switch off.
  final Relationship relationship;

  /// The projection documents that were deleted.
  final List<String> deletedPaths;

  @override
  String toString() =>
      'EndedCoaching(${relationship.relId}, deleted ${deletedPaths.length})';
}

/// Ends a relationship: state, switches and projections, in one call.
///
/// This is one of the two acts in the feature that **may** ask first (the other
/// is paying, which lives in `purchase_gate.dart`). It is destructive, it logs
/// nothing, and it cannot be undone — the same three properties that earned
/// block and account deletion their carve-out from rule 9.
class EndCoaching {
  EndCoaching({
    required this.projections,
    this.machine = const RelationshipStateMachine(),
  });

  final CoachProjectionWriter projections;
  final RelationshipStateMachine machine;

  /// Ends [relationship] because its date arrived, or because either party
  /// ended it early.
  ///
  /// Throws when the relationship cannot end from where it is, rather than
  /// silently clearing a grant on something that was never live.
  EndedCoaching end(
    Relationship relationship, {
    RelationshipEvent event = RelationshipEvent.endDateReached,
  }) {
    final next = machine.next(relationship.state, event);
    if (next != RelationshipState.ended) {
      throw StateError(
        'A relationship in ${relationship.state.name} cannot end by '
        '${event.name}.',
      );
    }

    final store = projections.store;
    final before = store?.deletions.length ?? 0;

    // Order matters only in one direction: the switches must be cleared even if
    // a projection delete fails, because the switch is what the next
    // relationship would otherwise inherit.
    final cleared = projections.onRelationshipEnded(relationship.relId);
    final deleted = store == null
        ? const <String>[]
        : store.deletions.sublist(before);

    return EndedCoaching(
      relationship: relationship.copyWith(
        state: RelationshipState.ended,
        sharing: cleared,
      ),
      deletedPaths: List.unmodifiable(deleted),
    );
  }
}

/// Flips one switch, and rebuilds what the coach can see.
///
/// The service exists so that "turn the switch off" and "remove the derived
/// panel" are one act. Two call sites is how a switch moves on her phone and a
/// panel survives on the coach's.
class RelationshipSharingService {
  const RelationshipSharingService({required this.projections});

  final CoachProjectionWriter projections;

  /// Moves [key] to [value] for [relationship], returning the relationship as
  /// it now stands.
  ///
  /// [online] decides only what the UI may *say* — [SharingSyncState]. The
  /// switch flips on her handset either way, because refusing to let a woman
  /// revoke consent until she has signal is the wrong failure.
  ({Relationship relationship, SharingSyncState sync}) setSwitch({
    required Relationship relationship,
    required SharingKey key,
    required bool value,
    required ProjectionInputs inputs,
    bool online = true,
  }) {
    final switches = relationship.sharing.set(
      key,
      value,
      relId: relationship.relId,
    );
    final updated = relationship.copyWith(sharing: switches);

    if (online) {
      projections.rebuild(
        relId: updated.relId,
        switches: switches,
        live: updated.isLive,
        inputs: inputs,
        sharingV: DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
      );
    }

    return (
      relationship: updated,
      sync: online ? SharingSyncState.applied : SharingSyncState.savedOnDevice,
    );
  }
}
