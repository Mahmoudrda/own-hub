/// Format rules for InstaPay addresses. The server is the authority
/// (`functions/payments/address.py`, `proof.py`); these only give instant
/// feedback and keep a phone number out of both fields.
library;

import 'receipt_reader.dart' show normalizeDigits;

/// How long a coach's new InstaPay address waits before it works. The server's
/// `LIMITS["addressDelayHours"]` (`functions/payments/model.py`) is the
/// authority; a test keeps the two equal.
const int kAddressDelayHours = 24;

/// How many days after a request a late proof is still accepted
/// (`LIMITS["lateProofDays"]`).
const int kLateProofDays = 7;

/// Clean payments a coach needs before she may turn on automatic confirming
/// (`LIMITS["cleanPaymentsForAutoConfirm"]`).
const int kCleanPaymentsForAutoConfirm = 3;

/// How long she may still flag a payment that confirmed itself
/// (`LIMITS["autoConfirmFlagHours"]`).
const int kAutoConfirmFlagHours = 48;

/// A fee statement left unpaid this long stops new clients for that coach
/// (`LIMITS["feeOverdueDays"]`).
const int kFeeOverdueDays = 30;

/// The refund numbers the screens state (`LIMITS` in
/// `functions/payments/model.py`): how long after access began she may ask,
/// how long the coach has to answer, how long after a refund is recorded or a
/// package ends she may still report a problem, and the digits the bank's
/// transaction number must have.
const int kRefundWindowDays = 14;
const int kRefundCoachDays = 3;
const int kServiceDisputeGraceDays = 14;
const int kRefundTxnMinDigits = 10;
const int kRefundTxnMaxDigits = 20;

/// The transaction number as the server reads it: Latin digits, letters and
/// digits only. A refund number is valid when that leaves only digits.
String refundTxnKey(String raw) =>
    normalizeDigits(raw).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

bool validRefundTxn(String raw) {
  final key = refundTxnKey(raw);
  return key.length >= kRefundTxnMinDigits &&
      key.length <= kRefundTxnMaxDigits &&
      RegExp(r'^[0-9]+$').hasMatch(key);
}

/// The note she writes with a problem or a dispute: 5 to 300 characters.
bool validProblemNote(String raw) => validNotReceivedNote(raw);

/// The reasons a coach gives for not agreeing to a refund, in the order shown
/// (`deny` in `functions/payments/refund.py`).
const List<String> kDenyReasons = <String>[
  'sessions_delivered',
  'outside_terms',
  'other',
];

/// The reason codes of "Not received", in the order shown
/// (`REASONS` in `functions/payments/claims.py`).
const List<String> kNotReceivedReasons = <String>[
  'not_seen',
  'wrong_amount',
  'wrong_name',
  'paid_by_someone_else',
  'other',
];

/// The note she writes with "Not received": 5 to 300 characters.
bool validNotReceivedNote(String raw) {
  final n = raw.trim().length;
  return n >= 5 && n <= 300;
}

/// "300", "300.5", "300,50" or "٣٠٠٫٥" in piasters. Null for anything that
/// is not a sum of at least one pound with at most two decimals.
int? parseAmountPiasters(String raw) {
  final m = RegExp(r'^(\d{1,7})(?:[.,](\d{1,2}))?$')
      .firstMatch(normalizeDigits(raw).trim());
  if (m == null) return null;
  final cents = m.group(2) == null
      ? 0
      : int.parse(m.group(2)!.padRight(2, '0'));
  final piasters = int.parse(m.group(1)!) * 100 + cents;
  return piasters >= 100 ? piasters : null;
}

final RegExp _handle = RegExp(r'^[a-z0-9._-]{3,40}@[a-z]{3,20}$');
final RegExp _phoneLike = RegExp(r'^[+0-9\u0660-\u0669\s-]{8,}$');

/// True for `name@bank`. A phone number is never a valid handle here.
bool validInstapayHandle(String raw) {
  final s = raw.trim();
  return !_phoneLike.hasMatch(s) && _handle.hasMatch(s.toLowerCase());
}

bool looksLikePhone(String raw) => _phoneLike.hasMatch(raw.trim());

/// 2 to 80 characters with at least one letter (Latin or Arabic).
bool validAccountName(String raw) {
  final s = raw.trim();
  return s.length >= 2 &&
      s.length <= 80 &&
      RegExp(r'[A-Za-z\u0621-\u064A]').hasMatch(s);
}
