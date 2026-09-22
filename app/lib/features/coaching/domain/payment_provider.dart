/// The money seam for the client side — `H03`'s checkout, and nothing else.
///
/// **There is no working implementation of this interface, and that is the
/// honest state of the product.** No provider is contracted, Paymob is not
/// integrated, and `pubspec.yaml` carries no SDK. So the only implementation
/// here is [UnavailablePaymentProvider], which refuses and says why.
///
/// The screens are built against this interface so that adding Paymob is a
/// dependency change rather than a rewrite — and so that a fake can never be
/// mistaken for a working rail, **because no fake that succeeds exists to be
/// mistaken**. This is the shape `features/signup/domain/id_capture.dart` takes
/// for the camera, and it is taken here for a stronger reason: a fake camera
/// wastes a screenshot, a fake payment reaches a woman's bank.
///
/// ## What this interface cannot express
///
/// Each of these is enforced by a missing member rather than by a check:
///
///  * **A checkout cannot return "paid".** [CheckoutOutcome] has two variants,
///    `unavailable` and `started`. There is no `paid` variant, so the code path
///    that opens the provider's page has nowhere to put a success. Paid arrives
///    later, from a signed webhook, through
///    `payment_state_machine.dart` — the only file that can build that state.
///  * **The client never sends a price.** [CheckoutRequest] carries a relation
///    id, an offer id, a rail and an idempotency key. There is **no amount
///    parameter and no `Money` field**, so `P0-PAY-09`'s tampered request has
///    nothing to tamper with. The server prices the offer from the coach's own
///    document.
///  * **Nothing is queued.** Every method returns a refusal for
///    [PaymentUnavailableReason.offline]. There is no `enqueue`, no `retryLater`
///    and no pending-purchase type, so an offline buy has nowhere to be stored
///    and nothing to replay on reconnect. `P0-PAY-08`.
///  * **A zero is not an answer.** [priceOf] returns `Money?`, and null means
///    "the seam could not tell me". A screen given null renders **nothing about
///    money** — never "0 EGP", which is a claim about her coach's price.
///
/// Everything reachable from here is additionally behind `Feature.payments`,
/// which is a child of `Feature.marketplace` and ships **off**. The directory
/// and the profiles can be browsed long before a payment rail is contracted,
/// and the parent chain is what keeps those two facts separable.
///
/// ## Naming, stated once
///
/// `features/coach/domain/payments.dart` defines a `PaymentProvider` too. That
/// one is the **coach's** side — payout methods, monthly earnings, capturing an
/// authorisation she accepted. This one is the **client's** — checkout, rails,
/// refunds. They are different interfaces with the same obvious name, in
/// different libraries, and neither is imported by the other. When Paymob is
/// contracted they should be merged behind one adapter; that is recorded in
/// this feature's handover rather than pre-empted by an edit to a folder this
/// agent does not own.
library;

import 'package:meta/meta.dart';

import 'money.dart';
import 'payment_state_machine.dart';

/// Why the rail cannot answer, in terms a screen can act on.
///
/// [notImplemented] is first because it is today's real answer, and naming it
/// keeps the gap visible in the UI instead of behind a spinner that never
/// resolves.
enum PaymentUnavailableReason {
  /// No provider is contracted and no SDK is wired up. Today's answer.
  notImplemented,

  /// `Feature.payments` is dark — or its parent `Feature.marketplace` is.
  /// Distinct from [notImplemented]: the rail may exist and simply not be
  /// switched on for her yet.
  featureOff,

  /// No signal. **A refusal, never a queued write.** Opening a checkout is a
  /// network round-trip by definition, and a queued charge is the one thing
  /// this seam exists to make impossible.
  offline,

  /// The provider is reachable and could not answer. **Never a rejection of
  /// her** — the screen offers another attempt, not an explanation.
  providerUnavailable,
}

/// What the app asks for when it wants a checkout.
///
/// Note what is absent: any amount at all. The server prices the offer.
@immutable
class CheckoutRequest {
  const CheckoutRequest({
    required this.relId,
    required this.offerId,
    required this.rail,
    required this.idempotencyKey,
  });

  /// `{coachUid}__{clientUid}`, computed not queried.
  final String relId;

  /// Which of her packages. The price lives on the coach's offer document and
  /// is read server-side.
  final String offerId;

  final PaymentRail rail;

  /// Minted once per attempt and reused across retries, so a checkout created
  /// twice by a flaky connection collapses onto one order.
  final String idempotencyKey;

  @override
  String toString() =>
      'CheckoutRequest($relId, $offerId, ${rail.name}, $idempotencyKey)';
}

/// A checkout the provider has opened.
///
/// It carries **no state**. Holding one of these means the hosted page is open
/// or the code is issued; it does not mean anything was paid, and there is no
/// field on it that could be read as though it did.
@immutable
class HostedCheckout {
  const HostedCheckout({
    required this.providerTxnId,
    required this.rail,
    this.hostedPage,
    this.reference,
    this.expiresAt,
  });

  /// The provider's transaction id, which becomes the payment document id.
  final String providerTxnId;

  final PaymentRail rail;

  /// The provider's page, opened in a platform browser tab — Chrome Custom
  /// Tabs or `ASWebAuthenticationSession`. **Never an in-app WebView**, where
  /// in-process JavaScript can observe the form and which drags this app into
  /// PCI scope.
  final Uri? hostedPage;

  /// The Fawry code she reads out at the counter.
  final String? reference;

  /// When that code dies.
  final DateTime? expiresAt;
}

/// The answer to "open a checkout".
///
/// Two variants. **There is no third meaning "paid".**
@immutable
sealed class CheckoutOutcome {
  const CheckoutOutcome();

  const factory CheckoutOutcome.unavailable(PaymentUnavailableReason reason) =
      CheckoutUnavailable;

  const factory CheckoutOutcome.started(HostedCheckout checkout) =
      CheckoutStarted;
}

/// The rail refused, and said why.
@immutable
final class CheckoutUnavailable extends CheckoutOutcome {
  const CheckoutUnavailable(this.reason);
  final PaymentUnavailableReason reason;
}

/// The provider's page is open. Nothing has been paid.
@immutable
final class CheckoutStarted extends CheckoutOutcome {
  const CheckoutStarted(this.checkout);
  final HostedCheckout checkout;
}

/// What a screen may know about one payment.
///
/// [PaymentUnknown] is not "loading" and not "zero". It is the seam saying it
/// cannot tell you, and a screen given it says nothing about money.
@immutable
sealed class PaymentView {
  const PaymentView();

  const factory PaymentView.unavailable(PaymentUnavailableReason reason) =
      PaymentUnknown;

  const factory PaymentView.record(PaymentRecord record) = PaymentKnown;
}

@immutable
final class PaymentUnknown extends PaymentView {
  const PaymentUnknown(this.reason);
  final PaymentUnavailableReason reason;
}

@immutable
final class PaymentKnown extends PaymentView {
  const PaymentKnown(this.record);
  final PaymentRecord record;
}

/// The answer to "start a refund".
///
/// There is no `refunded` variant: settling is a webhook, not a return value.
/// A method that could return "refunded" is a method a screen could use to tell
/// a woman her money is back before it is.
@immutable
sealed class RefundOutcome {
  const RefundOutcome();

  const factory RefundOutcome.unavailable(PaymentUnavailableReason reason) =
      RefundUnavailable;

  const factory RefundOutcome.refused(RefundRefusal refusal) = RefundNotAllowed;

  const factory RefundOutcome.requested(RefundQuote quote) = RefundRequestedOk;
}

@immutable
final class RefundUnavailable extends RefundOutcome {
  const RefundUnavailable(this.reason);
  final PaymentUnavailableReason reason;
}

@immutable
final class RefundNotAllowed extends RefundOutcome {
  const RefundNotAllowed(this.refusal);
  final RefundRefusal refusal;
}

@immutable
final class RefundRequestedOk extends RefundOutcome {
  const RefundRequestedOk(this.quote);
  final RefundQuote quote;
}

/// The client-side money rail.
abstract class PaymentProvider {
  /// The server's price for an offer, or null when it cannot be supplied.
  ///
  /// Null is not an error and not a zero. A screen that gets null shows the
  /// package without a figure and does not offer to buy it, because a purchase
  /// button beside no price is a button that asks her to trust a number nobody
  /// stated.
  Future<Money?> priceOf({required String coachUid, required String offerId});

  /// Opens the provider's hosted page, wallet push or Fawry code.
  ///
  /// Never returns "paid". See [CheckoutOutcome].
  Future<CheckoutOutcome> startCheckout(CheckoutRequest request);

  /// Watches one payment document.
  ///
  /// This is what the deep-link return triggers — a **read**, not a write. The
  /// app never marks anything paid; the webhook does.
  Stream<PaymentView> watch(String providerTxnId);

  /// Issues a new code for an expired Fawry reference.
  ///
  /// A new transaction, never a revival of the old one.
  Future<CheckoutOutcome> reissue({
    required String expiredProviderTxnId,
    required String idempotencyKey,
  });

  /// Asks for a refund. The platform absorbs the fee; she gets the gross back.
  Future<RefundOutcome> requestRefund({
    required String providerTxnId,
    required RefundReason reason,
  });
}

/// The only implementation that exists today: one that refuses, and says why.
///
/// It is **not** a stand-in rail. It never reports a started checkout, never
/// emits a [PaymentKnown], and constructs no [PaymentRecord] of any kind — so
/// no screen built against it can appear to have taken money, and no test can
/// pass by pretending. When Paymob lands, the replacement goes in `data/` and
/// this class stays for tests of the refusal paths.
///
/// `test/features/coaching/coaching_rules_guard_test.dart` asserts that this is
/// the *only* `implements PaymentProvider` in `lib/`. A second one is either a
/// real adapter — which belongs in `data/` with a contract behind it — or a fake
/// that succeeds, which is the single defect this seam exists to prevent.
class UnavailablePaymentProvider implements PaymentProvider {
  const UnavailablePaymentProvider({
    this.reason = PaymentUnavailableReason.notImplemented,
  });

  final PaymentUnavailableReason reason;

  /// The rail as it is when the feature flag is dark rather than absent.
  static const UnavailablePaymentProvider featureOff =
      UnavailablePaymentProvider(reason: PaymentUnavailableReason.featureOff);

  /// The rail as it is with no signal. Refusal, not a queue.
  static const UnavailablePaymentProvider offline = UnavailablePaymentProvider(
    reason: PaymentUnavailableReason.offline,
  );

  @override
  Future<Money?> priceOf({
    required String coachUid,
    required String offerId,
  }) async => null;

  @override
  Future<CheckoutOutcome> startCheckout(CheckoutRequest request) async =>
      CheckoutOutcome.unavailable(reason);

  @override
  Stream<PaymentView> watch(String providerTxnId) =>
      Stream<PaymentView>.value(PaymentView.unavailable(reason));

  @override
  Future<CheckoutOutcome> reissue({
    required String expiredProviderTxnId,
    required String idempotencyKey,
  }) async => CheckoutOutcome.unavailable(reason);

  @override
  Future<RefundOutcome> requestRefund({
    required String providerTxnId,
    required RefundReason reason,
  }) async => RefundOutcome.unavailable(this.reason);
}
