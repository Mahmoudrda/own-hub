import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/domain/payments_rules.dart';

void main() {
  test('a handle accepts name@bank and refuses phone numbers', () {
    expect(validInstapayHandle('rahma.m@instapay'), isTrue);
    expect(validInstapayHandle('RAHMA@InstaPay'), isTrue);
    expect(validInstapayHandle(' rahma_m@instapay '), isTrue);
    for (final bad in [
      '01012345678',
      '+201012345678',
      '٠١٠١٢٣٤٥٦٧٨',
      '010 1234 5678',
      'rahma',
      '@instapay',
      'ab@instapay',
      'rahma@x',
    ]) {
      expect(validInstapayHandle(bad), isFalse, reason: bad);
    }
  });

  test('looksLikePhone spots Latin and Arabic-Indic numbers', () {
    expect(looksLikePhone('01012345678'), isTrue);
    expect(looksLikePhone('+20 101 234 5678'), isTrue);
    expect(looksLikePhone('٠١٠١٢٣٤٥٦٧٨'), isTrue);
    expect(looksLikePhone('rahma@instapay'), isFalse);
  });

  test('an account name needs letters', () {
    expect(validAccountName('Rahma M.'), isTrue);
    expect(validAccountName('رحمة محسن'), isTrue);
    for (final bad in ['12', '', ' ', 'a', '1234 5678']) {
      expect(validAccountName(bad), isFalse, reason: bad);
    }
    expect(validAccountName('R' * 81), isFalse);
  });

  test('the two windows the screens state match the server', () {
    final model = File('../functions/payments/model.py').readAsStringSync();
    int limit(String key) =>
        int.parse(RegExp('"$key": (\\d+)').firstMatch(model)!.group(1)!);
    expect(kAddressDelayHours, limit('addressDelayHours'));
    expect(kLateProofDays, limit('lateProofDays'));
    expect(kFeeHoldDays, limit('feeHoldDays'));
  });

  test('the auto-confirm numbers the coach screens state match the server', () {
    final model = File('../functions/payments/model.py').readAsStringSync();
    int limit(String key) =>
        int.parse(RegExp('"$key": (\\d+)').firstMatch(model)!.group(1)!);
    expect(kCleanPaymentsForAutoConfirm, limit('cleanPaymentsForAutoConfirm'));
    expect(kAutoConfirmFlagHours, limit('autoConfirmFlagHours'));
  });

  test('the not-received reasons are the ones the server accepts', () {
    final claims = File('../functions/payments/claims.py').readAsStringSync();
    final listed = RegExp(r'REASONS = \(([^)]*)\)')
        .firstMatch(claims)!
        .group(1)!;
    expect(
      RegExp(r'"([a-z_]+)"').allMatches(listed).map((m) => m.group(1)).toList(),
      kNotReceivedReasons,
    );
  });

  test('the not-received note is 5 to 300 characters once trimmed', () {
    expect(validNotReceivedNote('abcd'), isFalse);
    expect(validNotReceivedNote('  abcd  '), isFalse);
    expect(validNotReceivedNote('abcde'), isTrue);
    expect(validNotReceivedNote('a' * 300), isTrue);
    expect(validNotReceivedNote('a' * 301), isFalse);
  });

  test('a typed amount reads in either alphabet and either separator', () {
    expect(parseAmountPiasters('300'), 30000);
    expect(parseAmountPiasters('300.5'), 30050);
    expect(parseAmountPiasters('300,50'), 30050);
    expect(parseAmountPiasters(' 500.37 '), 50037);
    expect(parseAmountPiasters('٣٠٠'), 30000);
    expect(parseAmountPiasters('٣٠٠٫٥'), 30050);
    for (final bad in [
      '',
      'abc',
      '1.234',
      '0.5',
      '0',
      '-5',
      '1.',
      '12345678',
    ]) {
      expect(parseAmountPiasters(bad), isNull, reason: bad);
    }
  });

  test('the refund numbers the screens state match the server', () {
    final model = File('../functions/payments/model.py').readAsStringSync();
    int limit(String key) =>
        int.parse(RegExp('"$key": (\\d+)').firstMatch(model)!.group(1)!);
    expect(kRefundWindowDays, limit('refundWindowDays'));
    expect(kRefundCoachDays, limit('refundCoachDays'));
    expect(kServiceDisputeGraceDays, limit('serviceDisputeGraceDays'));
    expect(kRefundTxnMinDigits, limit('refundTxnMinDigits'));
    expect(kRefundTxnMaxDigits, limit('refundTxnMaxDigits'));
  });

  test('a refund number is 10 to 20 digits once the server has read it', () {
    expect(validRefundTxn('1234567890'), isTrue);
    expect(validRefundTxn(' 1234 5678 9012 '), isTrue);
    expect(validRefundTxn('1234567890' * 2), isTrue);
    expect(
      validRefundTxn('١٢٣٤٥٦٧٨٩٠١٢'),
      isTrue,
      reason: 'Arabic-Indic digits',
    );
    expect(refundTxnKey('١٢٣-4567 890'), '1234567890');
    for (final bad in [
      '',
      '123456789',
      '1234567890' * 2 + '1',
      '12345678AB',
      'TXN1234567890',
    ]) {
      expect(validRefundTxn(bad), isFalse, reason: bad);
    }
  });

  test('the deny reasons are the ones the server accepts', () {
    final refund = File('../functions/payments/refund.py').readAsStringSync();
    final listed = RegExp(r'data.get\("reasonCode"\), \(([^)]*)\)')
        .firstMatch(refund)!
        .group(1)!;
    expect(
      RegExp(r'"([a-z_]+)"').allMatches(listed).map((m) => m.group(1)).toList(),
      kDenyReasons,
    );
  });
}
