// A one-off package used to render no price and therefore no way to buy it,
// because the dictionary had no bare-currency form -- every EGP string baked a
// sample figure into the sentence. `amountEgp` is parameterised, so the number
// is hers.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/coaching/domain/coaching_repository.dart';
import 'package:own_hub/features/coaching/domain/money.dart';
import 'package:own_hub/features/coaching/presentation/coaching_money.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  late AppL10n l10n;

  setUp(() async {
    l10n = await AppL10n.delegate.load(const Locale('en'));
  });

  test('a one-off package states its price', () {
    final line = priceLine(
      l10n,
      price: const Money.pounds(2743),
      period: OfferPeriod.oneOff,
    );
    expect(line, isNotNull, reason: 'it used to render nothing at all');
    expect(line, contains('2,743'), reason: 'her figure, grouped, Western');
    expect(line, contains('EGP'));
  });

  test('a monthly package is unchanged', () {
    final line = priceLine(
      l10n,
      price: const Money.pounds(2743),
      period: OfferPeriod.monthly,
    );
    expect(line, contains('2,743'));
  });

  test('an unknown price is still withheld, for both periods', () {
    // The point was never to always show a figure -- it was to stop hiding a
    // real one. A price nobody supplied is still rendered as nothing.
    for (final period in OfferPeriod.values) {
      expect(priceLine(l10n, price: null, period: period), isNull);
    }
  });
}
