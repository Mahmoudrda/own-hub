// Money: Western digits, no formatter, no zero, no arithmetic.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coaching/domain/money.dart';

void main() {
  group('Western digits, grouped by hand', () {
    test('thousands are comma-grouped', () {
      expect(const Money.pounds(1800).amountText, '1,800');
      expect(const Money.pounds(900).amountText, '900');
      expect(const Money.pounds(21600).amountText, '21,600');
      expect(const Money.pounds(1000000).amountText, '1,000,000');
    });

    test('piastres show only when they are there', () {
      expect(const Money.piastres(180000).amountText, '1,800');
      expect(const Money.piastres(180050).amountText, '1,800.50');
      expect(const Money.piastres(180005).amountText, '1,800.05');
    });

    test('every character is an ASCII digit or a separator', () {
      // The reason `NumberFormat` is never used: under an `ar` locale it
      // renders ١٨٠٠, and the spec forbids Arabic-Indic digits everywhere.
      for (final money in [
        const Money.pounds(1),
        const Money.pounds(1800),
        const Money.piastres(180050),
        const Money.pounds(987654321),
      ]) {
        expect(
          RegExp(r'^[0-9,.]+$').hasMatch(money.amountText),
          isTrue,
          reason: '${money.amountText} must be Western digits only',
        );
      }
    });

    test('small amounts are not padded into a false thousand', () {
      expect(const Money.pounds(0).amountText, '0');
      expect(const Money.pounds(12).amountText, '12');
      expect(const Money.pounds(123).amountText, '123');
      expect(const Money.pounds(1234).amountText, '1,234');
    });
  });

  group('what the type refuses', () {
    test('a negative price is not constructible', () {
      // A negative price is not a refund; a refund has its own type.
      expect(() => Money.piastres(-1), throwsA(isA<AssertionError>()));
    });

    test('there is no zero constant to reach for', () {
      // `Money.zero` would be the obvious thing to render when the seam is
      // silent, and rendering it is the defect. Absence is the truth instead.
      // Asserted at the source level in `coaching_rules_guard_test.dart`.
      expect(const Money.pounds(0).piastres, 0);
    });

    test('equality and ordering are by value', () {
      expect(const Money.pounds(1800), const Money.piastres(180000));
      expect(const Money.pounds(900) <= const Money.pounds(1800), isTrue);
      expect(const Money.pounds(2200) >= const Money.pounds(1800), isTrue);
      final sorted = <Money>[
        const Money.pounds(2200),
        const Money.pounds(900),
        const Money.pounds(1800),
      ]..sort();
      expect(sorted.map((m) => m.amountText), ['900', '1,800', '2,200']);
    });

    test('the currency is not a parameter', () {
      // A second currency needs a settlement account behind it, not a
      // constructor argument somebody passes by accident.
      expect(kCurrencyCode, 'EGP');
    });
  });
}
