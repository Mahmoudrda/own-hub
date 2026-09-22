// Counts, rendered as text.
//
// Small, but it sits under the one sentence on E04 that states how much she has
// eaten today — so "looks about right" is not good enough for it.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/format/number_label.dart';

void main() {
  test('groups thousands, and only from the right', () {
    expect(countLabel(0), '0');
    expect(countLabel(7), '7');
    expect(countLabel(99), '99');
    expect(countLabel(100), '100');
    expect(countLabel(999), '999');
    expect(countLabel(1000), '1,000');
    expect(countLabel(1106), '1,106');
    expect(countLabel(12400), '12,400');
    expect(countLabel(999999), '999,999');
    expect(countLabel(1000000), '1,000,000');
  });

  test('never writes a leading separator', () {
    // The off-by-one that produces ",100". Worth pinning: it only shows at
    // exact multiples of three digits, so it survives casual testing.
    for (final n in [100, 1000, 100000, 1000000]) {
      expect(countLabel(n).startsWith(','), isFalse, reason: '$n');
    }
  });

  test('a negative keeps its sign outside the grouping', () {
    // Not expected on a calorie total, but a formatter that mangles a negative
    // is a formatter waiting to be reused somewhere it matters.
    expect(countLabel(-1), '-1');
    expect(countLabel(-1106), '-1,106');
  });

  test('digits stay Western — the whole reason this is not NumberFormat', () {
    // P0-A11Y-01. NumberFormat under an `ar` locale emits ١١٠٦; this must not,
    // in any locale, because it does not consult one.
    final out = countLabel(1106);
    expect(out, '1,106');
    expect(
      RegExp(r'^[0-9,]+$').hasMatch(out),
      isTrue,
      reason:
          'Eastern-Arabic digits would break P0-A11Y-01 and the dictionary, '
          'whose Arabic values all use Western digits',
    );
  });
}
