/// The eight payment states, the events that move between them, and refunds.
///
/// This file is the **only** place in the application that can put a payment
/// into [PaymentState.paid] or [PaymentState.refunded], and it can only do it
/// from an event that carries a verified provider signature. Everything else —
/// the provider seam, the gate, the view models, the screens — reads.
///
/// ## The four properties this design commits to (G11 §3.2)
///
///  1. **A redirect is not a receipt.** [PaymentLedger.apply] moves a record to
///     `paid` only for [WebhookPaid], which *requires* a non-null
///     `hmacVerifiedAt` and an amount equal to the server-priced amount. There
///     is no event named "she came back from the provider", because an app that
///     trusts its own return URL can be paid with a bookmark.
///  2. **Idempotent by id.** The record's id **is** the provider transaction id.
///     A replayed webhook lands on the same record and
///     [PaymentApplication.changed] is false, so no second engagement, charge or
///     notification follows. `P0-PAY-07`.
///  3. **The client never sends a price.** [PaymentRecord.priced] is set when
///     the record is created by the server-side callable, and [WebhookPaid] is
///     rejected when its amount differs. A tampered request cannot be paid at a
///     lower figure; it cannot be paid at all. `P0-PAY-09`.
///  4. **Expiry is not failure, and a reissue is a new transaction.**
///     [PaymentLedger.reissue] returns a *new* record and leaves the old one
///     `expired` for ever, which is what "the old code is dead server-side"
///     means in a type. `P0-PAY-04`.
///
/// ## Refunds
///
/// The window is **48 hours** and **the platform absorbs the fee** — both owner
/// decisions, both here rather than in a screen. [RefundFeeBearer] has exactly
/// one value, so "the client pays the processing fee out of her refund" is not
/// a sentence this codebase can express.
library;

import 'package:meta/meta.dart';

import 'money.dart';

/// Which Egyptian rail. Card-only checkout excludes most of the market, so all
/// three are first-class rather than card plus two fallbacks.
enum PaymentRail {
  /// Visa, Mastercard, Meeza. The form is the provider's hosted page.
  card,

  /// Vodafone Cash, Orange Money, Etisalat, InstaPay.
  mobileWallet,

  /// A reference code paid at any Fawry point. Has a TTL; the others do not.
  fawry;

  /// Whether a reference code issued on this rail can time out.
  ///
  /// Only Fawry. A card checkout that is abandoned fails; it does not expire,
  /// and showing "that code expired" for a declined card would be a lie in
  /// both directions.
  bool get issuesExpiringReference => this == PaymentRail.fawry;
}

/// Where a payment has got to. Eight states, G11 §3.2, no more and no fewer.
enum PaymentState {
  /// The callable priced the offer from the coach's own offer document.
  created,

  /// The hosted page is open, the wallet push is out, or the Fawry code is
  /// issued. **Nothing is decided.**
  awaitingProvider,

  /// Signed webhook received and verified. The only honest "paid".
  paid,

  /// Declined or provider error. Nothing was charged; all three rails are
  /// offered again. Never a dead end.
  failed,

  /// A Fawry reference outlived its TTL. Distinct from [failed] because the
  /// remedy is different: one tap issues a new code.
  expired,

  /// Money is on its way back. Wallets are days; cards are longer.
  refundPending,

  /// The refund settled.
  refunded,

  /// A card chargeback. Ops-only; the payout to the coach is frozen and the
  /// client is told nothing new, because she already knows.
  disputed;

  /// Whether money has actually left her account and not yet come back.
  bool get holdsHerMoney =>
      this == PaymentState.paid ||
      this == PaymentState.refundPending ||
      this == PaymentState.disputed;

  /// Whether a screen may say the relationship can proceed.
  bool get unlocksCoaching => this == PaymentState.paid;

  /// Whether another attempt is the right offer.
  bool get invitesAnotherAttempt =>
      this == PaymentState.failed || this == PaymentState.expired;
}

/// Why a refund is being made.
///
/// The reason decides whether the 48-hour window applies. A refund the platform
/// initiates — because a coach declined, went silent or was suspended — is
/// never time-barred: the woman did nothing wrong and the clock is not hers.
enum RefundReason {
  /// She asked, inside the window.
  clientChangedMind,

  /// The coach declined after payment.
  coachDeclined,

  /// The coach neither accepted nor declined within her stated window.
  /// `P0-PAY-06` — the promise `H03` makes *before* payment.
  coachSilent,

  /// A report was upheld or someone blocked someone.
  suspended,
}

/// Who pays the processing fee on a refund.
///
/// **One value, deliberately.** The owner decided the platform absorbs it, and
/// an enum with a single member makes the other answer unrepresentable rather
/// than merely undesirable. A second value here would be a product decision,
/// and it would show up in review as one.
enum RefundFeeBearer { platform }

/// The 48-hour refund window.
abstract final class RefundWindow {
  /// The owner's figure. Changing it is a one-line change with a test behind it,
  /// which is the point of it being a constant and not a literal in a branch.
  static const Duration length = Duration(hours: 48);

  /// Whether a client-requested refund is still inside the window.
  ///
  /// Inclusive of the boundary: at exactly 48 hours she is inside it. A woman
  /// who taps at the instant the clock turns should not lose her money to a
  /// strict inequality.
  static bool isOpen({required DateTime paidAt, required DateTime now}) {
    final elapsed = now.difference(paidAt);
    if (elapsed.isNegative) return true; // clock skew is not her problem
    return elapsed <= length;
  }
}

/// What a refund will actually return.
@immutable
class RefundQuote {
  const RefundQuote._({
    required this.amountBack,
    required this.reason,
    required this.feeBearer,
  });

  /// The quote for a refund that is going ahead.
  ///
  /// [amountBack] is **always** the gross. There is no branch in this
  /// constructor that returns less, which is the owner's "the platform absorbs
  /// the refund fee" expressed as code that cannot do otherwise.
  factory RefundQuote.full({
    required Money gross,
    required RefundReason reason,
  }) => RefundQuote._(
    amountBack: gross,
    reason: reason,
    feeBearer: RefundFeeBearer.platform,
  );

  final Money amountBack;
  final RefundReason reason;
  final RefundFeeBearer feeBearer;

  @override
  String toString() => 'RefundQuote(${amountBack.amountText}, ${reason.name})';
}

/// Whether a refund may be requested at all.
abstract final class RefundEligibility {
  /// Null when the refund may go ahead; otherwise why it may not.
  ///
  /// Only [RefundReason.clientChangedMind] is bounded by [RefundWindow]. The
  /// three platform-initiated reasons are always allowed, because the promise
  /// made before payment does not have a deadline attached to it.
  static RefundRefusal? refuse({
    required RefundReason reason,
    required PaymentState state,
    required DateTime? paidAt,
    required DateTime now,
  }) {
    if (state != PaymentState.paid) return RefundRefusal.nothingToRefund;
    if (paidAt == null) return RefundRefusal.nothingToRefund;
    if (reason != RefundReason.clientChangedMind) return null;
    return RefundWindow.isOpen(paidAt: paidAt, now: now)
        ? null
        : RefundRefusal.windowClosed;
  }
}

/// Why a refund cannot be made.
enum RefundRefusal {
  /// Nothing has been captured, so there is nothing to send back. Refunding an
  /// unpaid payment would create money.
  nothingToRefund,

  /// Past 48 hours, and she asked rather than the platform.
  windowClosed,
}

/// A refund in flight, recorded on the payment.
@immutable
class RefundLeg {
  const RefundLeg({
    required this.quote,
    required this.requestedAt,
    this.settledAt,
  });

  final RefundQuote quote;
  final DateTime requestedAt;
  final DateTime? settledAt;

  bool get isSettled => settledAt != null;

  RefundLeg settled(DateTime at) =>
      RefundLeg(quote: quote, requestedAt: requestedAt, settledAt: at);
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

/// Everything that can move a payment.
///
/// Read this list for what is **not** on it. There is no `ReturnedFromProvider`,
/// no `UserSaysItWorked` and no `MarkPaid`. The only event that reaches
/// [PaymentState.paid] carries a signature timestamp and an amount, and both are
/// required and non-nullable — so a caller who has neither cannot construct it.
@immutable
sealed class PaymentEvent {
  const PaymentEvent();

  /// When it happened, for the record's own timestamps.
  DateTime get at;
}

/// The hosted page opened, the wallet push went out, or a code was issued.
@immutable
final class ProviderOpened extends PaymentEvent {
  const ProviderOpened({required this.at, this.reference, this.expiresAt});

  @override
  final DateTime at;

  /// The Fawry code shown on screen, when the rail issues one.
  final String? reference;

  /// The reference TTL, when the rail has one.
  final DateTime? expiresAt;
}

/// A signed, verified `payment.paid` webhook.
///
/// [hmacVerifiedAt] is required and non-nullable on purpose: the signature is
/// verified before this object exists, so there is no path that constructs one
/// "and checks later".
@immutable
final class WebhookPaid extends PaymentEvent {
  const WebhookPaid({
    required this.at,
    required this.hmacVerifiedAt,
    required this.amount,
  });

  @override
  final DateTime at;
  final DateTime hmacVerifiedAt;

  /// What the provider says was captured. Compared with the server price;
  /// a mismatch is refused rather than trusted.
  final Money amount;
}

/// A decline or a provider error.
@immutable
final class WebhookFailed extends PaymentEvent {
  const WebhookFailed({required this.at, required this.code});

  @override
  final DateTime at;

  /// The provider's own code, for ops. Never rendered raw to her.
  final String code;
}

/// A Fawry reference outlived its TTL.
@immutable
final class ReferenceExpired extends PaymentEvent {
  const ReferenceExpired({required this.at});

  @override
  final DateTime at;
}

/// A refund has been asked for.
@immutable
final class RefundRequested extends PaymentEvent {
  const RefundRequested({required this.at, required this.reason});

  @override
  final DateTime at;
  final RefundReason reason;
}

/// The provider confirmed the refund settled.
@immutable
final class WebhookRefundSettled extends PaymentEvent {
  const WebhookRefundSettled({required this.at});

  @override
  final DateTime at;
}

/// A card chargeback was opened.
@immutable
final class ChargebackOpened extends PaymentEvent {
  const ChargebackOpened({required this.at});

  @override
  final DateTime at;
}

// ---------------------------------------------------------------------------
// The record
// ---------------------------------------------------------------------------

/// One payment, keyed by the provider's transaction id.
///
/// The private constructor is the enforcement: outside this library the only
/// way to obtain a record is [PaymentRecord.created] — which is always
/// [PaymentState.created] — or a [PaymentLedger] transition. There is no
/// constructor that takes a state, so no file can build a paid payment.
@immutable
class PaymentRecord {
  const PaymentRecord._({
    required this.providerTxnId,
    required this.relId,
    required this.engagementId,
    required this.rail,
    required this.priced,
    required this.state,
    required this.createdAt,
    this.reference,
    this.expiresAt,
    this.paidAt,
    this.hmacVerifiedAt,
    this.failedAt,
    this.failureCode,
    this.refund,
  });

  /// A payment as the server-side checkout callable creates it.
  ///
  /// [priced] comes from the coach's offer document, server-side. There is no
  /// parameter here a client could supply an amount through — see the seam's
  /// `CheckoutRequest`, which carries an offer id and no money at all.
  const PaymentRecord.created({
    required String providerTxnId,
    required String relId,
    required String engagementId,
    required PaymentRail rail,
    required Money priced,
    required DateTime createdAt,
  }) : this._(
         providerTxnId: providerTxnId,
         relId: relId,
         engagementId: engagementId,
         rail: rail,
         priced: priced,
         state: PaymentState.created,
         createdAt: createdAt,
       );

  /// The document id. Being the provider's own transaction id is what makes a
  /// replayed webhook idempotent instead of a second charge.
  final String providerTxnId;

  final String relId;
  final String engagementId;
  final PaymentRail rail;

  /// The server's price for the offer. Immutable.
  final Money priced;

  final PaymentState state;
  final DateTime createdAt;

  /// The Fawry code, when there is one.
  final String? reference;
  final DateTime? expiresAt;

  final DateTime? paidAt;
  final DateTime? hmacVerifiedAt;
  final DateTime? failedAt;
  final String? failureCode;

  final RefundLeg? refund;

  /// The figure a receipt may state, or null when there is nothing to state.
  ///
  /// Null until the webhook lands. A screen that renders this before then shows
  /// nothing, which is correct: she has not paid yet.
  Money? get capturedAmount =>
      state.holdsHerMoney || state == PaymentState.refunded ? priced : null;

  PaymentRecord _with({
    PaymentState? state,
    String? reference,
    DateTime? expiresAt,
    DateTime? paidAt,
    DateTime? hmacVerifiedAt,
    DateTime? failedAt,
    String? failureCode,
    RefundLeg? refund,
  }) => PaymentRecord._(
    providerTxnId: providerTxnId,
    relId: relId,
    engagementId: engagementId,
    rail: rail,
    priced: priced,
    state: state ?? this.state,
    createdAt: createdAt,
    reference: reference ?? this.reference,
    expiresAt: expiresAt ?? this.expiresAt,
    paidAt: paidAt ?? this.paidAt,
    hmacVerifiedAt: hmacVerifiedAt ?? this.hmacVerifiedAt,
    failedAt: failedAt ?? this.failedAt,
    failureCode: failureCode ?? this.failureCode,
    refund: refund ?? this.refund,
  );

  @override
  String toString() => 'PaymentRecord($providerTxnId ${state.name})';
}

/// Why an event did not apply.
enum PaymentRefusal {
  /// The transition is not in the table. `expired → paid`, for instance.
  illegalTransition,

  /// The provider reported an amount that is not the server price. This is the
  /// tamper case, and it is refused rather than trusted or split.
  amountMismatch,

  /// Already applied. Not an error — the provider retries by design.
  alreadyApplied,

  /// A refund was asked for that may not be made.
  refundRefused,

  /// A reference cannot expire on a rail that does not issue one.
  railHasNoReference,
}

/// The result of offering one event to one record.
@immutable
class PaymentApplication {
  const PaymentApplication._({
    required this.record,
    required this.changed,
    this.refused,
    this.refundRefusal,
  });

  /// The record afterwards. On refusal it is the record you passed in,
  /// unchanged and identical.
  final PaymentRecord record;

  /// Whether anything moved. False for a replay, which is how `P0-PAY-07` is
  /// asserted without inspecting a store.
  final bool changed;

  final PaymentRefusal? refused;
  final RefundRefusal? refundRefusal;

  bool get didApply => changed;
}

/// The transition table, as a function.
class PaymentLedger {
  const PaymentLedger();

  /// Offer [event] to [record].
  ///
  /// Never throws. An impossible transition comes back refused with the record
  /// untouched, because a payment screen that crashes on an unexpected webhook
  /// is worse than one that says nothing new.
  PaymentApplication apply(PaymentRecord record, PaymentEvent event) {
    switch (event) {
      case ProviderOpened(:final reference, :final expiresAt):
        if (record.state != PaymentState.created) {
          return _refuse(record, PaymentRefusal.illegalTransition);
        }
        return _moved(
          record._with(
            state: PaymentState.awaitingProvider,
            reference: reference,
            expiresAt: expiresAt,
          ),
        );

      case WebhookPaid(:final at, :final hmacVerifiedAt, :final amount):
        // A retry of a webhook that already landed. The provider does this by
        // design; it must not create a second engagement or a second charge.
        if (record.state == PaymentState.paid) {
          return _refuse(record, PaymentRefusal.alreadyApplied);
        }
        if (record.state != PaymentState.created &&
            record.state != PaymentState.awaitingProvider) {
          return _refuse(record, PaymentRefusal.illegalTransition);
        }
        // The one comparison that stops a halved request being honoured.
        if (amount != record.priced) {
          return _refuse(record, PaymentRefusal.amountMismatch);
        }
        return _moved(
          record._with(
            state: PaymentState.paid,
            paidAt: at,
            hmacVerifiedAt: hmacVerifiedAt,
          ),
        );

      case WebhookFailed(:final at, :final code):
        if (record.state != PaymentState.created &&
            record.state != PaymentState.awaitingProvider) {
          return _refuse(record, PaymentRefusal.illegalTransition);
        }
        return _moved(
          record._with(
            state: PaymentState.failed,
            failedAt: at,
            failureCode: code,
          ),
        );

      case ReferenceExpired():
        if (!record.rail.issuesExpiringReference) {
          return _refuse(record, PaymentRefusal.railHasNoReference);
        }
        if (record.state != PaymentState.awaitingProvider) {
          return _refuse(record, PaymentRefusal.illegalTransition);
        }
        return _moved(record._with(state: PaymentState.expired));

      case RefundRequested(:final at, :final reason):
        final refusal = RefundEligibility.refuse(
          reason: reason,
          state: record.state,
          paidAt: record.paidAt,
          now: at,
        );
        if (refusal != null) {
          return PaymentApplication._(
            record: record,
            changed: false,
            refused: PaymentRefusal.refundRefused,
            refundRefusal: refusal,
          );
        }
        return _moved(
          record._with(
            state: PaymentState.refundPending,
            refund: RefundLeg(
              quote: RefundQuote.full(gross: record.priced, reason: reason),
              requestedAt: at,
            ),
          ),
        );

      case WebhookRefundSettled(:final at):
        final leg = record.refund;
        if (record.state != PaymentState.refundPending || leg == null) {
          return _refuse(record, PaymentRefusal.illegalTransition);
        }
        return _moved(
          record._with(state: PaymentState.refunded, refund: leg.settled(at)),
        );

      case ChargebackOpened():
        if (record.state == PaymentState.disputed) {
          return _refuse(record, PaymentRefusal.alreadyApplied);
        }
        if (record.state != PaymentState.paid &&
            record.state != PaymentState.refundPending &&
            record.state != PaymentState.refunded) {
          return _refuse(record, PaymentRefusal.illegalTransition);
        }
        return _moved(record._with(state: PaymentState.disputed));
    }
  }

  /// A new payment for an expired reference.
  ///
  /// Returns a **new record under a new transaction id**, and does not touch
  /// the old one: the expired code stays expired for ever, which is what stops
  /// a woman paying an old Fawry code and a new one for the same month.
  ///
  /// Refuses (returns null) for anything that is not expired, so "reissue" can
  /// never become a way to re-open a payment that failed or already settled.
  PaymentRecord? reissue(
    PaymentRecord expiredRecord, {
    required String newProviderTxnId,
    required DateTime now,
  }) {
    if (expiredRecord.state != PaymentState.expired) return null;
    if (newProviderTxnId == expiredRecord.providerTxnId) return null;
    return PaymentRecord.created(
      providerTxnId: newProviderTxnId,
      relId: expiredRecord.relId,
      engagementId: expiredRecord.engagementId,
      rail: expiredRecord.rail,
      priced: expiredRecord.priced,
      createdAt: now,
    );
  }

  PaymentApplication _moved(PaymentRecord next) =>
      PaymentApplication._(record: next, changed: true);

  PaymentApplication _refuse(PaymentRecord record, PaymentRefusal why) =>
      PaymentApplication._(record: record, changed: false, refused: why);
}
