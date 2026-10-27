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
  });
}
