library;

import '../../../l10n/app_l10n.dart';
import '../data/payments_repository.dart';
import '../domain/payment_models.dart';

/// "500.37 EGP" / "500.37 جنيه"; whole pounds drop the decimals. Western digits.
String egpText(AppL10n l10n, int piasters) =>
    l10n.amountEgp(egpPlain(piasters));

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
    _ => l10n.weCouldNotDoThatTryAgain,
  };
}
