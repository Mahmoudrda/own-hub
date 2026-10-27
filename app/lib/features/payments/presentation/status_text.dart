library;

import '../../../l10n/app_l10n.dart';
import '../domain/payment_models.dart';
import 'payment_text.dart';

/// The two `dispute.kind` values after which the client may add proof (PAY6).
bool disputeAsksForProof(Payment p) =>
    p.status == PaymentStatus.coachNotReceived ||
    (p.status == PaymentStatus.inReview &&
        (p.disputeKind == 'proof_red' || p.disputeKind == 'not_received'));

String statusWord(AppL10n l, Payment p) => switch (p.status) {
  PaymentStatus.awaitingPayment => l.waitingForYourPayment,
  PaymentStatus.proofSubmitted => l.proofSent,
  PaymentStatus.confirmed => l.paymentConfirmed,
  PaymentStatus.resolvedPaid => l.confirmedAfterReview,
  PaymentStatus.coachNotReceived => l.yourCoachSaysItHasNotArrived,
  PaymentStatus.inReview =>
    p.disputeKind == 'not_received'
        ? l.yourCoachSaysItHasNotArrived
        : l.underReview,
  PaymentStatus.resolvedUnpaid => l.reviewDone,
  PaymentStatus.differentAmount => l.differentAmount,
  PaymentStatus.expired => l.theRequestExpired,
  PaymentStatus.cancelled => l.paymentCancelled,
  PaymentStatus.refundRequested => l.refundAsked,
  PaymentStatus.refunded => l.refundRecorded,
  PaymentStatus.refundDenied => l.refundNotAgreed,
  PaymentStatus.serviceDispute => l.problemReported,
};

String nextLine(AppL10n l, Payment p) => switch (p.status) {
  PaymentStatus.awaitingPayment => l.payWithYourBankAppThenTap,
  PaymentStatus.proofSubmitted => l.yourCoachWillConfirmIfSheDoes,
  PaymentStatus.confirmed ||
  PaymentStatus.resolvedPaid => l.allSetYourCoachingIsActive,
  PaymentStatus.coachNotReceived => l.addYourBanksTransactionScreenshotAndOwn,
  PaymentStatus.inReview =>
    p.disputeKind == 'proof_red'
        ? l.weCouldNotMatchThisPaymentAdd
        : p.disputeKind == 'not_received'
        ? l.addYourBanksTransactionScreenshotAndOwn
        : l.ownHubIsLookingAtBothSides,
  PaymentStatus.resolvedUnpaid => l.weCouldNotFindThePaymentIf,
  PaymentStatus.differentAmount =>
    p.acceptLower
        ? l.yourCoachAcceptedAmountInsteadDoYou(
            egpText(l, p.differentAmountPiasters),
          )
        : l.yourCoachReceivedAmountPayTheRest(
            egpText(l, p.differentAmountPiasters),
          ),
  PaymentStatus.expired => l.ifYouAlreadyPaidYouCanSend,
  PaymentStatus.cancelled => l.nothingWasPaid,
  PaymentStatus.refundRequested => l.yourCoachHas3DaysToAnswer,
  PaymentStatus.refunded => l.yourCoachRecordedTheRefund,
  PaymentStatus.refundDenied => l.ownHubWillLookAtIt,
  PaymentStatus.serviceDispute => l.ownHubIsLookingIntoIt,
};

/// One calm sentence per timeline row, or null for a row the client need not
/// see. A row whose status did not change (`from == to`) is a note, picked
/// by its `code`.
String? timelineSentence(AppL10n l, PaymentEvent e) {
  if (e.from == e.to && e.from.isNotEmpty) {
    return e.code == 'coach_reported'
        ? l.yourCoachSaysYouPaidPleaseCheck
        : null;
  }
  return switch (e.to) {
    'awaiting_payment' => l.paymentRequestCreated,
    'proof_submitted' => l.youSentYourProof,
    'confirmed' =>
      e.role == 'client' ? l.youConfirmedIt : l.yourCoachConfirmedIt,
    'coach_not_received' => l.yourCoachSaysItHasNotArrived,
    'in_review' => l.ownHubStartedAReview,
    'resolved_paid' => l.reviewDoneYourPaymentCounts,
    'resolved_unpaid' => l.reviewDoneWeCouldNotFindThe,
    'different_amount' => l.yourCoachReceivedADifferentAmount,
    'expired' => l.theRequestExpired,
    'cancelled' => l.paymentCancelled,
    'refund_requested' => l.youAskedForARefund,
    'refunded' => l.refundRecorded,
    'refund_denied' => l.refundNotAgreed,
    'service_dispute' => l.youReportedAProblemWithTheService,
    _ => null,
  };
}
