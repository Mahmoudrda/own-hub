/// The two test rails — one for her checkout (`H03`), one for a coach's payout
/// method (`K05`) — and the only place in the app where money *appears* to move.
///
/// **They exist only while no account is required.** Paymob is not contracted,
/// so the product's own seams (`features/coaching/domain/payment_provider.dart`
/// and `features/coach/domain/payments.dart`) ship one implementation each, and
/// both refuse. The owner still has to be able to walk "pay a coach" and "set
/// where I am paid" by hand, so these implement the same two interfaces and
/// succeed — and every screen that uses them says, in words, that it is a test
/// and that no money moves. `CoachingLinkState` and `CoachProfileState` only
/// hand them out while `Feature.accountRequired` is off; with it on, the
/// refusing providers are what the screens get.
///
/// They live here, outside `lib/features/`, on purpose: the feature folders'
/// guard tests assert that the refusing provider is the only implementation
/// *in the feature*, and that stays true. A real adapter belongs in `data/`.
///
/// What they still refuse to fake:
///
///  * **Earnings.** A month's statement is never invented — `earnings` stays
///    unavailable, so `K17` still says nothing about money.
///  * **A price.** The checkout is priced from the coach's own offer document,
///    exactly as the server would; the request carries no amount.
///  * **A refund or a reissued code.** Refused; there is nothing to refund.
library;

import 'dart:async';

import '../features/coach/domain/payments.dart' as payout;
import '../features/coaching/domain/money.dart';
import '../features/coaching/domain/payment_provider.dart';
import '../features/coaching/domain/payment_state_machine.dart';

/// Looks up the server's price for one of a coach's offers, or null.
typedef OfferPriceLookup = Money? Function(String coachUid, String offerId);

/// `H03`'s test rail. Opens a "checkout" and settles it at once.
///
/// It plays both halves of a real provider — the hosted page and the signed
/// webhook — because there is no server here to receive one. The ledger still
/// decides every state: the record is created through
/// [PaymentRecord.created] and moved by [PaymentLedger], so a mismatched
/// amount or a replay is refused here exactly as it would be for real.
class TestPaymentProvider implements PaymentProvider {
  TestPaymentProvider({required this.priceFor, DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final OfferPriceLookup priceFor;
  final DateTime Function() _clock;

  static const PaymentLedger _ledger = PaymentLedger();

  /// Every payment this rail has settled, by provider transaction id.
  final Map<String, PaymentRecord> records = <String, PaymentRecord>{};

  @override
  Future<Money?> priceOf({
    required String coachUid,
    required String offerId,
  }) async => priceFor(coachUid, offerId);

  @override
  Future<CheckoutOutcome> startCheckout(CheckoutRequest request) async {
    final coachUid = request.relId.split('__').first;
    final price = priceFor(coachUid, request.offerId);
    if (price == null) {
      return const CheckoutOutcome.unavailable(
        PaymentUnavailableReason.providerUnavailable,
      );
    }
    // The idempotency key names the attempt, so a retried tap lands on the
    // same record instead of a second charge.
    final txnId = 'test_${request.idempotencyKey}';
    final now = _clock();
    var record =
        records[txnId] ??
        PaymentRecord.created(
          providerTxnId: txnId,
          relId: request.relId,
          engagementId: 'eng_${request.relId}',
          rail: request.rail,
          priced: price,
          createdAt: now,
        );
    record = _ledger.apply(record, ProviderOpened(at: now)).record;
    // The test "webhook": the amount is the server's own price, so the
    // ledger's tamper check passes for the honest request and nothing else.
    record = _ledger
        .apply(record, WebhookPaid(at: now, hmacVerifiedAt: now, amount: price))
        .record;
    records[txnId] = record;
    return CheckoutOutcome.started(
      HostedCheckout(providerTxnId: txnId, rail: request.rail),
    );
  }

  @override
  Stream<PaymentView> watch(String providerTxnId) {
    final record = records[providerTxnId];
    return Stream<PaymentView>.value(
      record == null
          ? const PaymentView.unavailable(
              PaymentUnavailableReason.providerUnavailable,
            )
          : PaymentView.record(record),
    );
  }

  /// The settled record for [providerTxnId], synchronously.
  PaymentRecord? recordFor(String providerTxnId) => records[providerTxnId];

  @override
  Future<CheckoutOutcome> reissue({
    required String expiredProviderTxnId,
    required String idempotencyKey,
  }) async => const CheckoutOutcome.unavailable(
    PaymentUnavailableReason.notImplemented,
  );

  @override
  Future<RefundOutcome> requestRefund({
    required String providerTxnId,
    required RefundReason reason,
  }) async =>
      const RefundOutcome.unavailable(PaymentUnavailableReason.notImplemented);
}

/// `K05`'s test rail. Records where she would be paid; pays nobody.
///
/// Keeps what the real tokeniser would keep and nothing more: her name, the
/// kind of account and the last four characters. The full number is dropped
/// the moment this call returns, as it would be by a real provider.
class TestPayoutProvider implements payout.PaymentProvider {
  TestPayoutProvider({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  payout.PayoutMethodState _method = const payout.PayoutMethodState.none();

  @override
  Future<payout.PayoutMethodState> payoutMethod() async => _method;

  @override
  Future<payout.PayoutMethodState> setPayoutMethod(
    payout.PayoutMethodDraft draft,
  ) async {
    if (!draft.isComplete) return _method;
    final digits = draft.accountRef.trim();
    final tail = digits.length <= 2
        ? digits
        : digits.substring(digits.length - 2);
    _method = payout.PayoutMethodState.set(
      payout.PayoutDestination(
        kind: draft.kind,
        holderName: draft.holderName.trim(),
        maskedTail: 'xx$tail',
        updatedAt: _clock(),
      ),
    );
    return _method;
  }

  /// Never a statement. `K17` stays silent about money even in test mode.
  @override
  Future<payout.EarningsState> earnings(String monthKey) async =>
      const payout.EarningsState.unavailable(
        payout.PaymentUnavailableReason.notImplemented,
      );

  @override
  Future<payout.CaptureOutcome> capture({
    required String authorisationId,
  }) async => const payout.CaptureOutcome.unavailable(
    payout.PaymentUnavailableReason.notImplemented,
  );

  @override
  Future<payout.VoidOutcome> voidAuthorisation({
    required String authorisationId,
  }) async => const payout.VoidOutcome.unavailable(
    payout.PaymentUnavailableReason.notImplemented,
  );
}
