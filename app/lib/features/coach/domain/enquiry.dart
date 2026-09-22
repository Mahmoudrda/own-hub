/// `K09` — a woman has asked to work with her.
///
/// The document is G11's (`relationships/{relId}`). **G12 owns the coach-side
/// transitions only**, and they all pass through here.
///
/// # The guard is the transition, not a counter
///
/// Spine C4, as G12 §3.3 restates it: *an increment never travels alone.*
/// [EnquiryTransition.accept] asserts `status == enquiry` **and** takes the
/// capacity slot in one indivisible step, so `P0-ENQ-03` — two devices accepting
/// the last spot in the same second — fails the second attempt on the status
/// test rather than on a counter read. A design that checked `taken < max` and
/// then incremented would let both through and put a coach at 21 of 20.
///
/// # Accepting is refused offline, never queued
///
/// `P0-ENQ-04`, and G12 §4 gives the reason in one sentence: *"Queuing it would
/// let two coaches accept the last spot, or take money for a spot that no longer
/// exists."* [NetworkStatus] is a required argument of [CoachEnquiryService.accept]
/// rather than something it looks up, so there is no call site that can forget
/// to consider it.
///
/// # Money is captured, never fabricated
///
/// Accepting captures an authorisation placed at `H04`. The capture goes through
/// the seam in `payments.dart`, and **the seam has no working implementation**,
/// so today every accept ends in [EnquiryRefusal.paymentUnavailable] and nothing
/// increments. That is the honest state of the product and it is deliberately
/// not worked around: a service that incremented capacity and skipped the
/// capture would have taken a client without taking her money, and one that
/// reported a capture that did not happen would be lying about money.
///
/// The pure transition is separable from the capture precisely so the capacity
/// and status rules can be proven today, against the part that exists.
///
/// # Declining is neutral
///
/// `P0-ENQ-02`. The copy is "Not a fit for me", the authorisation is voided, and
/// capacity does not move. Nothing here calls it a rejection.
library;

import 'package:meta/meta.dart';

import 'coach_capacity.dart';
import 'coach_verification.dart';
import 'payments.dart';

/// Whether there is signal.
///
/// A value rather than a boolean parameter so a call site reads
/// `NetworkStatus.offline` instead of `false`, and so the argument cannot be
/// confused with the four other booleans around it.
enum NetworkStatus {
  online,
  offline;

  bool get isOnline => this == NetworkStatus.online;
}

/// G12 §3.3's six states.
enum EnquiryStatus {
  /// She asked. `K09` shows it. Money is authorised, **not captured**.
  enquiry,

  /// The coach said yes. The spot is held and the money is taken.
  accepted,

  /// Intake done, plan published. G11's transition, not ours.
  active,

  /// The coach said no. The authorisation is voided; capacity is unchanged.
  declined,

  /// Seventy-two hours with no decision.
  expired,

  /// The client pulled out first.
  withdrawn;

  /// Whether a coach decision is still open on it.
  bool get awaitsCoach => this == EnquiryStatus.enquiry;

  /// Whether this status holds a capacity slot.
  bool get holdsASpot =>
      this == EnquiryStatus.accepted || this == EnquiryStatus.active;
}

/// The seventy-two hours after which an undecided enquiry lapses.
const Duration enquiryTimeToLive = Duration(hours: 72);

/// One enquiry, denormalised the way G12 §7.3 asks G11 to denormalise it.
///
/// Everything `K09` renders is on this object. That is not a convenience: a
/// coach session **may not read `users/{clientUid}`** — the rules deny it — so
/// if her situation and her own words were not carried here, `K09` would be
/// unbuildable rather than merely slower.
@immutable
class Enquiry {
  const Enquiry({
    required this.relId,
    required this.coachUid,
    required this.clientUid,
    required this.status,
    required this.enquiredAt,
    this.displayName = '',
    this.situation = '',
    this.herWords = '',
    this.joinedAt,
    this.authorisationId,
  });

  /// `{coachUid}_{clientUid}` — deterministic, so a replayed create collides
  /// with itself (spine C1). Built by [relationshipId].
  final String relId;

  final String coachUid;
  final String clientUid;
  final EnquiryStatus status;
  final DateTime enquiredAt;

  /// Her name, as G11 projects it. Never read from her user document.
  final String displayName;

  /// "Postpartum, 4 months · trains at home · 20 minutes · 3 days a week".
  final String situation;

  /// Her own words, in quotes on `K09`. The reason the screen exists.
  final String herWords;

  final DateTime? joinedAt;

  /// The hold placed at `H04`. Null when no rail was involved — which is every
  /// enquiry today, because no rail exists.
  final String? authorisationId;

  /// The initial `K07` and `K09` draw in her avatar.
  String get initial => displayName.trim().isEmpty
      ? ''
      : displayName.trim().substring(0, 1).toUpperCase();

  /// How long she has been waiting, at [now].
  Duration waitedBy(DateTime now) => now.difference(enquiredAt);

  /// Whether the seventy-two hours have run out.
  bool hasLapsedBy(DateTime now) =>
      status.awaitsCoach && waitedBy(now) >= enquiryTimeToLive;

  Enquiry copyWith({EnquiryStatus? status}) => Enquiry(
    relId: relId,
    coachUid: coachUid,
    clientUid: clientUid,
    status: status ?? this.status,
    enquiredAt: enquiredAt,
    displayName: displayName,
    situation: situation,
    herWords: herWords,
    joinedAt: joinedAt,
    authorisationId: authorisationId,
  );
}

/// The deterministic relationship id. Spine C1.
String relationshipId({required String coachUid, required String clientUid}) =>
    '${coachUid}_$clientUid';

/// Why a decision could not be applied.
enum EnquiryRefusal {
  /// She does not hold `coachV`. `P0-CVER-01` and `P0-CVER-04`.
  notVerified,

  /// Every spot is taken. `P0-ENQ-03`'s loser.
  rosterFull,

  /// Somebody already decided it — the other device, the client, or the clock.
  /// `P0-ENQ-03`'s **first** line of defence.
  alreadyDecided,

  /// No signal. Refused with a reason, never queued (`P0-ENQ-04`).
  offline,

  /// The money rail could not take the hold. Nothing moves — not the status,
  /// not the count.
  paymentUnavailable,

  /// Her capacity has never been set, so there is no roster to join.
  capacityNotSet,
}

/// What a transition did, or refused to do.
@immutable
sealed class EnquiryOutcome {
  const EnquiryOutcome();

  const factory EnquiryOutcome.applied({
    required Enquiry enquiry,
    required CoachCapacity capacity,
  }) = EnquiryApplied;

  const factory EnquiryOutcome.refused(EnquiryRefusal reason) = EnquiryRefused;

  bool get didApply => this is EnquiryApplied;
}

class EnquiryApplied extends EnquiryOutcome {
  const EnquiryApplied({required this.enquiry, required this.capacity});

  final Enquiry enquiry;

  /// The capacity **after** the transition. Returned together with the status
  /// so a caller cannot persist one without the other.
  final CoachCapacity capacity;
}

class EnquiryRefused extends EnquiryOutcome {
  const EnquiryRefused(this.reason);
  final EnquiryRefusal reason;
}

/// The coach-side transitions, as pure functions.
///
/// No clock, no network, no money. Everything `P0-ENQ-01` through `P0-ENQ-05`
/// asserts about **status and capacity** is decided here and is testable without
/// a provider — which matters, because there is no provider.
class EnquiryTransition {
  const EnquiryTransition();

  /// `COACH_ACCEPT`. Status and capacity move together or not at all.
  EnquiryOutcome accept({
    required Enquiry enquiry,
    required CoachCapacity capacity,
    required CoachVerificationState verification,
  }) {
    // The status assertion comes FIRST, and that ordering is the test case.
    // P0-ENQ-03 requires the losing device to fail "on the status assertion
    // inside the transaction, not on a counter read" — so a full roster must
    // never be the reason a replayed accept is rejected, because that would
    // report "the spot is gone" for an enquiry that was already accepted by the
    // same coach a moment earlier.
    if (!enquiry.status.awaitsCoach) {
      return const EnquiryOutcome.refused(EnquiryRefusal.alreadyDecided);
    }
    if (!verification.mayAcceptClients) {
      return const EnquiryOutcome.refused(EnquiryRefusal.notVerified);
    }
    if (!capacity.isSet) {
      return const EnquiryOutcome.refused(EnquiryRefusal.capacityNotSet);
    }

    final next = capacity.withOneMoreTaken();
    if (next == null) {
      return const EnquiryOutcome.refused(EnquiryRefusal.rosterFull);
    }

    return EnquiryOutcome.applied(
      enquiry: enquiry.copyWith(status: EnquiryStatus.accepted),
      capacity: next,
    );
  }

  /// `COACH_DECLINE`. Neutral, and capacity does not move.
  ///
  /// Note what is **not** checked: her credential state. A coach whose
  /// certificates lapsed can still say no to someone who is waiting on her, and
  /// refusing to let her would leave the client hanging for seventy-two hours
  /// over the coach's paperwork.
  EnquiryOutcome decline({
    required Enquiry enquiry,
    required CoachCapacity capacity,
  }) {
    if (!enquiry.status.awaitsCoach) {
      return const EnquiryOutcome.refused(EnquiryRefusal.alreadyDecided);
    }
    return EnquiryOutcome.applied(
      enquiry: enquiry.copyWith(status: EnquiryStatus.declined),
      capacity: capacity,
    );
  }

  /// `TTL_72H`. Applied lazily on read, like certificate expiry — no sweeper.
  ///
  /// `P0-ENQ-05`: capacity is unchanged, and **her measured reply time is not
  /// penalised** for an enquiry she never saw. Nothing here touches
  /// `replyTimeP50Mins`, which is the mechanism: an expiry produces no reply
  /// event, so the rolling p50 has nothing to count.
  EnquiryOutcome expireIfStale({
    required Enquiry enquiry,
    required CoachCapacity capacity,
    required DateTime now,
  }) {
    if (!enquiry.hasLapsedBy(now)) {
      return const EnquiryOutcome.refused(EnquiryRefusal.alreadyDecided);
    }
    return EnquiryOutcome.applied(
      enquiry: enquiry.copyWith(status: EnquiryStatus.expired),
      capacity: capacity,
    );
  }
}

/// Accepting and declining, with the network and the money rail attached.
///
/// This is what `K09` calls. The split from [EnquiryTransition] is deliberate:
/// the rules that can be honestly implemented today are in the pure function
/// above, and everything that depends on a provider nobody has contracted is
/// here, where its absence is visible.
class CoachEnquiryService {
  const CoachEnquiryService({
    required this.payments,
    this.transition = const EnquiryTransition(),
  });

  final PaymentProvider payments;
  final EnquiryTransition transition;

  /// `K09`'s primary action.
  ///
  /// Order matters and is the whole of G12 §3.3: assert, then capture, then
  /// commit. The capture is **inside** the accept, so a failure to take her
  /// money leaves the enquiry open and the spot free rather than half-accepted.
  Future<EnquiryOutcome> accept({
    required Enquiry enquiry,
    required CoachCapacity capacity,
    required CoachVerificationState verification,
    required NetworkStatus network,
  }) async {
    if (!network.isOnline) {
      return const EnquiryOutcome.refused(EnquiryRefusal.offline);
    }

    final proposed = transition.accept(
      enquiry: enquiry,
      capacity: capacity,
      verification: verification,
    );
    if (proposed is! EnquiryApplied) return proposed;

    final authorisation = enquiry.authorisationId;
    if (authorisation == null) {
      return const EnquiryOutcome.refused(EnquiryRefusal.paymentUnavailable);
    }

    final capture = await payments.capture(authorisationId: authorisation);
    if (!capture.didCapture) {
      // Nothing is committed. The spot is still free, the enquiry is still
      // open, and no screen may report otherwise.
      return const EnquiryOutcome.refused(EnquiryRefusal.paymentUnavailable);
    }

    return proposed;
  }

  /// `K09`'s neutral second action.
  ///
  /// The void is attempted and its failure does **not** block the decline: a
  /// coach must be able to say no to a woman who is waiting, and an unreleased
  /// hold is a reconciliation problem rather than a reason to trap them both.
  /// The outcome reports what happened either way.
  Future<({EnquiryOutcome outcome, bool authorisationVoided})> decline({
    required Enquiry enquiry,
    required CoachCapacity capacity,
    required NetworkStatus network,
  }) async {
    if (!network.isOnline) {
      return (
        outcome: const EnquiryOutcome.refused(EnquiryRefusal.offline),
        authorisationVoided: false,
      );
    }

    final proposed = transition.decline(enquiry: enquiry, capacity: capacity);
    if (proposed is! EnquiryApplied) {
      return (outcome: proposed, authorisationVoided: false);
    }

    var voided = false;
    final authorisation = enquiry.authorisationId;
    if (authorisation != null) {
      final result = await payments.voidAuthorisation(
        authorisationId: authorisation,
      );
      voided = result.didVoid;
    }

    return (outcome: proposed, authorisationVoided: voided);
  }
}
