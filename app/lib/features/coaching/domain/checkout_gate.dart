/// The one place a purchase is allowed, and the six reasons it is not.
///
/// Everything a screen needs to know before offering to take money passes
/// through [CheckoutGate.decide]. It is a pure function of six inputs and it has
/// no `force`, no `allowOffline` and no `skipChecks` parameter for anyone to
/// reach for at the end of a long day.
///
/// ## The owner's decisions, as code
///
///  * **Buy-direct is removed.** The only stage a checkout opens from is
///    [MarketplaceStage.acceptedAwaitingPayment]. Every other stage —
///    including plain browsing — is refused with
///    [CheckoutRefusal.noAcceptedEnquiry]. This is what makes *"she pays only
///    once you accept"* true on every path instead of true on one and false on
///    the other (G11 §3.2's open question 1, closed).
///  * **Browsing is open; purchasing is gated.** An unverified woman may read
///    the directory and every profile. [CheckoutRefusal.notVerified] stops her
///    at the money and nowhere earlier.
///  * **Offline is a hard no.** No optimistic state, no local pending purchase,
///    no queued charge. There is no `CheckoutDecision` variant that means
///    "later", so there is nothing for a sync layer to replay.
///  * **Capacity caps at sixty.** The client re-reads what the directory pack
///    says, and the server re-reads it again at checkout — a stale pack can
///    delay a purchase but can never oversell a coach (`P0-COACH-04`).
///  * **Money is never fabricated.** A null price is
///    [CheckoutRefusal.priceUnknown], not a zero and not an optimistic
///    "continue".
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import 'marketplace_stage.dart';
import 'money.dart';

/// The cap the coach side enforces, restated here so the shopfront can refuse
/// before a round-trip.
///
/// `lib/features/coach/domain/coach_capacity.dart` owns the authority
/// (`CoachCapacity.ceiling`). This constant is a **read-only echo** across a
/// folder boundary this agent may not edit, and
/// `test/features/coaching/coaching_rules_guard_test.dart` reads that file as
/// text and fails if the two ever disagree. Two constants, one authority,
/// stated — rather than an import that couples the shopfront to a file three
/// other agents are changing.
const int kCoachCapacityCeiling = 60;

/// Why a purchase is not allowed right now.
enum CheckoutRefusal {
  /// `Feature.marketplace` is dark, so none of this is reachable.
  marketplaceOff,

  /// `Feature.payments` is dark. Its parent may well be on: browsing a coach
  /// long before a rail is contracted is the point of the two flags.
  paymentsOff,

  /// **Enquiry first, always.** No coach has accepted her, so there is nothing
  /// to pay for. Buy-direct does not exist in this product.
  noAcceptedEnquiry,

  /// A checkout is already open. A second would be a second charge.
  alreadyPaying,

  /// Browsing is open to everyone; paying is not.
  notVerified,

  /// **No signal.** Nothing is queued, nothing is optimistic, nothing is
  /// charged. She retries when she has signal.
  offline,

  /// The coach has stopped taking clients, or every place is taken.
  coachNotAccepting,

  /// The seam could not supply a price. Withheld rather than rendered as zero.
  priceUnknown,
}

/// May she pay?
@immutable
sealed class CheckoutDecision {
  const CheckoutDecision();

  const factory CheckoutDecision.allowed(Money price) = CheckoutAllowed;

  const factory CheckoutDecision.refused(CheckoutRefusal reason) =
      CheckoutRefused;

  /// Whether the caller may open a checkout.
  bool get mayProceed => this is CheckoutAllowed;
}

/// Allowed, and carrying the price the server stated.
///
/// The price travels *with* the permission so a screen cannot render a figure
/// it was not also cleared to charge.
@immutable
final class CheckoutAllowed extends CheckoutDecision {
  const CheckoutAllowed(this.price);
  final Money price;
}

@immutable
final class CheckoutRefused extends CheckoutDecision {
  const CheckoutRefused(this.reason);
  final CheckoutRefusal reason;

  @override
  bool operator ==(Object other) =>
      other is CheckoutRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'CheckoutRefused(${reason.name})';
}

/// The gate.
class CheckoutGate {
  const CheckoutGate();

  /// Whether a checkout may be created, and at what price.
  ///
  /// The order of the checks is deliberate and is asserted by test. The flags
  /// come first because a dark feature should not produce a verification
  /// prompt; the stage comes before verification because "no coach has accepted
  /// you" is the honest answer to a woman who has not enquired, whether or not
  /// she has verified; offline comes before the price because with no signal
  /// the price is unknown *for that reason* and saying so twice helps nobody.
  CheckoutDecision decide({
    required FeatureFlags flags,
    required MarketplaceStage stage,
    required bool verified,
    required bool online,
    required bool coachAcceptingClients,
    required int? spotsLeft,
    required Money? price,
  }) {
    if (!flags.isOn(Feature.marketplace)) {
      return const CheckoutDecision.refused(CheckoutRefusal.marketplaceOff);
    }
    // `payments` is a child of `marketplace`; `isOn` walks the chain, so this
    // is false whenever the parent is off too. Checked separately anyway,
    // because the two refusals need two different sentences.
    if (!flags.isOn(Feature.payments)) {
      return const CheckoutDecision.refused(CheckoutRefusal.paymentsOff);
    }
    if (stage == MarketplaceStage.paying) {
      return const CheckoutDecision.refused(CheckoutRefusal.alreadyPaying);
    }
    if (stage != MarketplaceStage.acceptedAwaitingPayment) {
      return const CheckoutDecision.refused(CheckoutRefusal.noAcceptedEnquiry);
    }
    if (!verified) {
      return const CheckoutDecision.refused(CheckoutRefusal.notVerified);
    }
    if (!online) {
      return const CheckoutDecision.refused(CheckoutRefusal.offline);
    }
    if (!coachAcceptingClients || (spotsLeft != null && spotsLeft <= 0)) {
      return const CheckoutDecision.refused(CheckoutRefusal.coachNotAccepting);
    }
    if (price == null) {
      return const CheckoutDecision.refused(CheckoutRefusal.priceUnknown);
    }
    return CheckoutDecision.allowed(price);
  }
}

/// Whether an enquiry may be sent.
///
/// A much lighter gate than [CheckoutGate], and deliberately so: an enquiry
/// moves no money, takes no place and can be declined, so the only things that
/// stop it are the feature flag, a stage that already has one open, and — unlike
/// a purchase — **nothing about connectivity**. An enquiry is a message, and
/// messages queue.
enum EnquiryRefusal {
  /// `Feature.marketplace` is dark.
  marketplaceOff,

  /// Browsing is open to the unverified; starting a relationship is not.
  notVerified,

  /// She already has an open enquiry, or is already working with this coach.
  alreadyInTouch,

  /// The coach has closed her books. Sending anyway would be a message she has
  /// told us she cannot answer.
  coachNotAccepting,

  /// Nothing typed. Refused here rather than sent as an empty thread.
  empty,
}

@immutable
sealed class EnquiryDecision {
  const EnquiryDecision();

  const factory EnquiryDecision.allowed() = EnquiryAllowed;

  const factory EnquiryDecision.refused(EnquiryRefusal reason) =
      EnquiryRefusedBy;

  bool get mayProceed => this is EnquiryAllowed;
}

@immutable
final class EnquiryAllowed extends EnquiryDecision {
  const EnquiryAllowed();

  @override
  bool operator ==(Object other) => other is EnquiryAllowed;

  @override
  int get hashCode => 11;
}

@immutable
final class EnquiryRefusedBy extends EnquiryDecision {
  const EnquiryRefusedBy(this.reason);
  final EnquiryRefusal reason;

  @override
  bool operator ==(Object other) =>
      other is EnquiryRefusedBy && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'EnquiryRefusedBy(${reason.name})';
}

/// The enquiry gate.
class EnquiryGate {
  const EnquiryGate();

  /// Whether `H04` may send.
  ///
  /// Note the absence of an `online` parameter. This is not an oversight: a
  /// queued enquiry is a message with a deterministic id that collapses onto
  /// itself on reconnect, which is the opposite of a queued charge.
  EnquiryDecision decide({
    required FeatureFlags flags,
    required MarketplaceStage stage,
    required bool verified,
    required bool coachAcceptingClients,
    required String message,
  }) {
    if (!flags.isOn(Feature.marketplace)) {
      return const EnquiryDecision.refused(EnquiryRefusal.marketplaceOff);
    }
    if (!verified) {
      return const EnquiryDecision.refused(EnquiryRefusal.notVerified);
    }
    if (!stage.mayEnquire) {
      return const EnquiryDecision.refused(EnquiryRefusal.alreadyInTouch);
    }
    if (!coachAcceptingClients) {
      return const EnquiryDecision.refused(EnquiryRefusal.coachNotAccepting);
    }
    if (message.trim().isEmpty) {
      return const EnquiryDecision.refused(EnquiryRefusal.empty);
    }
    return const EnquiryDecision.allowed();
  }
}
