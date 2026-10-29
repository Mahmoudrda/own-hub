/// What a tap on a payments push opens. The server (`functions/payments/
/// notices.py`) sends the kind, plus `paymentId` or, for a fee statement,
/// `statementMonth`; the texts come with the push, so the phone holds none.
///
/// Every kind the server can send is listed here, and a test reads the server's
/// list so a new kind cannot ship without a place to go.
library;

/// The screen a payments push leads to.
enum PaymentPushScreen {
  /// PAY3, for the payment the push names.
  status,

  /// PAY4, the coach's payments inbox. Refund requests are a section of it.
  coachInbox,

  /// The coach's own payment details.
  coachAddress,

  /// PAY9, at the month the push names.
  statements,
}

/// Where each kind goes, by who gets it. A coach's "suspended" has no screen of
/// its own, so it opens the inbox, which she can always read.
const Map<String, PaymentPushScreen> kPaymentPushScreens = {
  // To the client.
  'instapayReminder': PaymentPushScreen.status,
  'instapayConfirmed': PaymentPushScreen.status,
  'instapayNotReceived': PaymentPushScreen.status,
  'instapayDifferentAmount': PaymentPushScreen.status,
  'instapayCoachReported': PaymentPushScreen.status,
  'instapayReviewStarted': PaymentPushScreen.status,
  'instapayReviewDecided': PaymentPushScreen.status,
  'instapayRefundRecorded': PaymentPushScreen.status,
  'instapayAddressChanged': PaymentPushScreen.status,
  'instapayAccessEndsSoon': PaymentPushScreen.status,
  'instapayPaused': PaymentPushScreen.status,
  // To the coach.
  'instapayProofSent': PaymentPushScreen.coachInbox,
  'instapayCoachReminder': PaymentPushScreen.coachInbox,
  'instapayConfirmedByClient': PaymentPushScreen.coachInbox,
  'instapayDisputeOpened': PaymentPushScreen.coachInbox,
  'instapayCoachReviewDecided': PaymentPushScreen.coachInbox,
  'instapayRefundRequested': PaymentPushScreen.coachInbox,
  'instapaySuspended': PaymentPushScreen.coachInbox,
  'instapayAddressChangedCoach': PaymentPushScreen.coachAddress,
  'instapayStatementReady': PaymentPushScreen.statements,
  'instapayFeeDueSoon': PaymentPushScreen.statements,
  'instapayFeeDueToday': PaymentPushScreen.statements,
  'instapayFeeOverdue': PaymentPushScreen.statements,
  'instapayFeeClaimRejected': PaymentPushScreen.statements,
  'instapayAccountActive': PaymentPushScreen.coachInbox,
};

/// A payments push read from its data.
class PaymentPush {
  const PaymentPush(
    this.screen, {
    this.paymentId,
    this.statementMonth,
    this.billId,
  });

  final PaymentPushScreen screen;

  /// Set for [PaymentPushScreen.status] when the push carried a usable one.
  /// Without it her coach screen opens instead, where the payment card is.
  final String? paymentId;

  /// "2026-10", for [PaymentPushScreen.statements] when the push carried one.
  final String? statementMonth;

  /// For [PaymentPushScreen.statements]: the payment whose commission bill to
  /// open (an auto id, no uid).
  final String? billId;

  /// Whether this is a screen of her coach's side.
  bool get forCoach => screen != PaymentPushScreen.status;
}

final RegExp _idShape = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
final RegExp _monthShape = RegExp(r'^\d{4}-(0[1-9]|1[0-2])$');

/// The push [data] describes, or null for anything that is not a payments
/// kind. A missing or odd id is dropped, not trusted: the screen still opens at
/// its most useful place.
PaymentPush? paymentPushFor(Map<String, Object?> data) {
  final kind = data['kind'];
  final screen = kind is String ? kPaymentPushScreens[kind] : null;
  if (screen == null) return null;
  final id = data['paymentId'];
  final month = data['statementMonth'];
  final bill = data['billId'];
  return PaymentPush(
    screen,
    paymentId: id is String && _idShape.hasMatch(id) ? id : null,
    statementMonth: month is String && _monthShape.hasMatch(month)
        ? month
        : null,
    billId: bill is String && _idShape.hasMatch(bill) ? bill : null,
  );
}
