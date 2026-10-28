library;

import '../../../l10n/app_l10n.dart';
import '../../events/domain/cairo_time.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';
import '../domain/payments_rules.dart';

/// "500.37 EGP" / "500.37 جنيه"; whole pounds drop the decimals. Western digits.
String egpText(AppL10n l10n, int piasters) =>
    l10n.amountEgp(egpPlain(piasters));

/// "27/10 14:32" in Cairo time, Western digits.
String cairoStamp(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final c = toCairo(t);
  return '${two(c.day)}/${two(c.month)} ${two(c.hour)}:${two(c.minute)}';
}

/// "27/10/2026" in Cairo time, Western digits.
String cairoDate(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final c = toCairo(t);
  return '${two(c.day)}/${two(c.month)}/${c.year}';
}

/// "27/10/2026 14:32" in Cairo time, Western digits.
String cairoDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  final c = toCairo(t);
  return '${cairoDate(t)} ${two(c.hour)}:${two(c.minute)}';
}

/// A calm sentence for a refusal. Never the raw code. Codes are the ones in
/// `functions/payments/errors.py` and `functions/coaching/errors.py`.
String paymentFailureText(AppL10n l10n, PaymentFailure f) {
  if (f.unreachable) return l10n.weCouldNotReachOwnHubCheck;
  return switch (f.reason) {
    'recent_sign_in_required' => l10n.pleaseSignInAgainThenTryOnce,
    'otp_wrong' => l10n.theCodeIsNotRightTryAgain,
    'otp_expired' => l10n.theCodeHasExpiredAskForA,
    'address_not_handle' => l10n.thatLooksLikeAPhoneNumberUse,
    'address_format' => l10n.thatDoesNotLookLikeAnInstapay,
    'too_many_requests' || 'otp_rate' => l10n.tooManyTriesPleaseWaitAWhile,
    'wrong_status' ||
    'illegal_transition' ||
    'payment_not_found' => l10n.thisPaymentChangedRefreshAndTryAgain,
    'txn_reused' => l10n.thisTransactionNumberWasAlreadyUsed,
    'too_many_screenshots' => l10n.youHaveSentTooManyPicturesFor,
    'image_invalid' ||
    'image_too_large' ||
    'image_undecodable' => l10n.weCouldNotUseThatPicturePick,
    'proof_window_closed' => l10n.theTimeToSendAProofFor,
    'coach_not_ready' => l10n.yourCoachHasNotSetUpPayments,
    'coach_payments_suspended' => l10n.yourCoachCannotTakePaymentsHereRight,
    'client_payments_suspended' => l10n.paymentsByInstapayAreNotAvailableOn,
    'amount_over_limit' => l10n.thisAmountIsAboveWhatInstapayAllows,
    'first_payment_shortest_only' => l10n.forYourFirstPaymentPleaseChooseYour,
    'open_payment_exists' => l10n.youAlreadyHaveAPaymentOpenOpen,
    'payments_off' => l10n.paymentsArePausedForAMomentPlease,
    'appears_in_statement' => l10n.thisPaymentAppearsInYourStatementPlease,
    'evidence_required' => l10n.pleaseTickThatYouSearchedYourBank,
    'reason_required' => l10n.pleaseTellUsWhatYouSawIn,
    'accept_lower_too_low' => l10n.thatIsTooFarBelowThePrice,
    'refund_window_closed' => l10n.theFirstNDaysAreOverSo(
      kRefundWindowDays.toString(),
    ),
    'refund_already_requested' => l10n.youAlreadyAskedForARefundOn,
    'dispute_window_closed' => l10n.theTimeToReportAProblemOn,
    'dispute_already_used' => l10n.youAlreadyReportedThisOwnHubHas,
    'dispute_limit' => l10n.youHaveReachedTheNumberOfReports,
    'refund_txn_invalid' => l10n.pleaseCheckTheTransactionNumberFromYour,
    'refund_paid_at_invalid' => l10n.theDateOrTimeOnYourPhone,
    _ => l10n.weCouldNotDoThatTryAgain,
  };
}

/// The same for a call a coach makes: `coach_not_ready` there is not about her
/// coach.
String coachPaymentFailureText(AppL10n l10n, PaymentFailure f) =>
    f.reason == 'coach_not_ready' && !f.unreachable
    ? l10n.weCouldNotDoThatTryAgain
    : paymentFailureText(l10n, f);

/// Recording a refund. A bad request there is an amount the server will not
/// take (more than the payment).
String refundFailureText(AppL10n l10n, PaymentFailure f) =>
    f.reason == 'bad_request' && !f.unreachable
    ? l10n.pleaseCheckTheAmountItCannotBe
    : coachPaymentFailureText(l10n, f);

/// Recording that she paid Own Hub's fee. A bad request there is a
/// transaction number too short to be one (letters and digits both count);
/// `wrong_status` and `payment_not_found` mean the statement is no longer open.
String feeFailureText(AppL10n l10n, PaymentFailure f) {
  if (f.unreachable) return paymentFailureText(l10n, f);
  return switch (f.reason) {
    'bad_request' => l10n.pleaseCheckTheTransactionNumberFromYour_653l2,
    'wrong_status' ||
    'payment_not_found' => l10n.thisStatementChangedGoBackAndOpen,
    _ => coachPaymentFailureText(l10n, f),
  };
}

/// Turning automatic confirming on. Here `wrong_status` means she has not yet
/// confirmed enough clean payments, not that a payment changed.
String autoConfirmFailureText(AppL10n l10n, PaymentFailure f) {
  if (f.unreachable) return paymentFailureText(l10n, f);
  return switch (f.reason) {
    'auto_confirm_off' => l10n.automaticConfirmingIsNotAvailableToYou,
    'wrong_status' => l10n.automaticConfirmingOpensAfterNPaymentsThat(
      kCleanPaymentsForAutoConfirm.toString(),
    ),
    _ => coachPaymentFailureText(l10n, f),
  };
}
