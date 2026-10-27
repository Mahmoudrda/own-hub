library;

import 'dart:typed_data';

import '../domain/payment_models.dart';

/// Screen names for tests and the budget list.
class PayScreens {
  static const pay1 = 'PAY1';
  static const pay2 = 'PAY2';
  static const pay3 = 'PAY3';
  static const pay4 = 'PAY4';
  static const pay5 = 'PAY5';
  static const pay6 = 'PAY6';
  static const pay7 = 'PAY7';
  static const pay8 = 'PAY8';
  static const pay9 = 'PAY9';
  static const pay10 = 'PAY10';
}

/// Callable names, as `functions/main.py` registers them. The only place
/// they are written.
class PaymentCallables {
  static const createPayment = 'create_payment';
  static const cancelPayment = 'cancel_payment';
  static const submitProof = 'submit_instapay_proof';
  static const addEvidence = 'add_payment_evidence';
  static const coachConfirm = 'coach_confirm_payment';
  static const coachNotReceived = 'coach_mark_not_received';
  static const coachDifferentAmount = 'coach_mark_different_amount';
  static const clientDifferentAmount = 'client_respond_different_amount';
  static const coachReport = 'coach_report_payment';
  static const clientAnswerReport = 'client_confirm_coach_report';
  static const setAddress = 'set_coach_instapay_address';
  static const setAutoConfirm = 'set_auto_confirm_green';
  static const requestRefund = 'request_refund';
  static const denyRefund = 'deny_refund';
  static const recordRefund = 'record_instapay_refund';
  static const openServiceDispute = 'open_service_dispute';
  static const recordFeePayment = 'record_fee_payment';
  static const partyImage = 'get_payment_image';
}

/// A refusal. [reason] is the server's reason code (the HttpsError message),
/// empty when unknown. [unreachable] means no signal: the screen may queue.
class PaymentFailure implements Exception {
  const PaymentFailure(this.reason, {this.unreachable = false});
  final String reason;
  final bool unreachable;
  @override
  String toString() => 'PaymentFailure($reason, unreachable: $unreachable)';
}

/// The server's answer to a proof. [retry] is true for an AMBER answer that
/// left the payment where it was: she may fix the [reasons] and send again
/// with a new key.
class ProofResult {
  const ProofResult({
    required this.status,
    this.outcome,
    this.reasons = const <String>[],
    this.retry = false,
  });
  final PaymentStatus status;
  final RiskOutcome? outcome;
  final List<String> reasons;
  final bool retry;
}

/// What a saved address change did: `pending` waits 24 hours, a first
/// address is active at once.
class AddressChange {
  const AddressChange({required this.pending, this.effectiveAt});
  final bool pending;
  final DateTime? effectiveAt;
}

abstract class PaymentsRepository {
  String? get uid;

  Stream<Payment?> watchPayment(String paymentId);
  Stream<List<Payment>> watchMyPaymentsAsClient();
  Stream<List<Payment>> watchMyPaymentsAsCoach();
  Stream<List<PaymentEvent>> watchEvents(String paymentId);
  Stream<CoachAddress?> watchMyAddress();
  Stream<List<FeeStatement>> watchMyStatements();

  /// The kill switch `config/payments.enabled`: true or false, and null when
  /// it could not be read (the caller keeps what it had). A missing document
  /// is false.
  Future<bool?> paymentsEnabled();

  Future<Payment> createPayment({
    required String subId,
    required String idempotencyKey,
    String? topUpOf,
  });

  Future<void> cancelPayment(String paymentId);

  /// Sends the pictures in the call (the server stores them; a phone never
  /// writes to Storage). [amountPiasters] must equal the payment's amount.
  Future<ProofResult> submitProof({
    required String paymentId,
    required String idempotencyKey,
    required int amountPiasters,
    required List<Uint8List> images,
    String? txnNumber,
    String? senderHandle,
    DateTime? paidAtClaimed,
    Map<String, Object?> phoneReading = const <String, Object?>{},
    bool otherPayerOk = false,
  });

  /// PAY6: either party adds pictures to a payment under review.
  Future<int> addEvidence({
    required String paymentId,
    required List<Uint8List> images,
    String? note,
  });

  Future<PaymentStatus> clientAnswerReport(
    String paymentId, {
    required bool yes,
  });
  Future<PaymentStatus> clientRespondDifferentAmount(
    String paymentId, {
    required bool agree,
  });

  /// PAY7. Needs a phone sign-in less than five minutes old.
  Future<AddressChange> setAddress({
    required String address,
    required String accountName,
  });

  // ------------------------------------------------ coach side (PAY4, PAY5, PAY8, PAY9)
  Future<PaymentStatus> coachConfirm(String paymentId, {int? receivedPiasters});
  Future<PaymentStatus> coachNotReceived({
    required String paymentId,
    required String reasonCode,
    required String note,
    required List<Uint8List> images,
  });
  Future<PaymentStatus> coachDifferentAmount({
    required String paymentId,
    required int receivedPiasters,
    required bool acceptLower,
  });

  /// "A client paid me": by [subId] or by [reference], never both.
  Future<void> coachReport({
    String? subId,
    String? reference,
    required String txnNumber,
  });
  Future<void> setAutoConfirm(bool enabled);
  Future<PaymentStatus> requestRefund(String paymentId);
  Future<PaymentStatus> denyRefund(
    String paymentId, {
    required String reasonCode,
  });
  Future<PaymentStatus> recordRefund({
    required String paymentId,
    required String txnNumber,
    required int amountPiasters,
    required String kind,
    DateTime? paidAt,
  });
  Future<PaymentStatus> openServiceDispute(String paymentId, {String? note});
  Future<void> recordFeePayment({
    required String statementId,
    required String txnNumber,
  });
  Future<Uint8List> partyImage({
    required String paymentId,
    required String path,
  });
}

/// Asks her phone for a fresh SMS code (spec 4.4). The server accepts an
/// address change only from a token made by a phone sign-in in the last five
/// minutes, so the "one-time code" is Firebase phone re-authentication.
abstract class PhoneReauth {
  /// Sends the code to the number she signed in with.
  Future<void> sendCode();

  /// Checks the code and refreshes the token. Throws [PaymentFailure].
  Future<void> confirm(String code);
}
