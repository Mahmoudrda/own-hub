// The plates on each side of a bar for a total weight.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/domain/plate_math.dart';

void main() {
  test('40 kg on a 20 kg bar is a 10 each side', () {
    final load = platesFor(40)!;
    expect(load.perSideKg, [10]);
    expect(load.exact, isTrue);
    expect(load.eachSideKg, 10);
    expect(load.loadableKg, 40);
  });

  test('the bare bar is no plates', () {
    final load = platesFor(20)!;
    expect(load.perSideKg, isEmpty);
    expect(load.exact, isTrue);
  });

  test('a 15 kg bar changes the sum', () {
    final load = platesFor(40, barKg: 15)!;
    expect(load.eachSideKg, 12.5);
    expect(load.perSideKg, [10, 2.5]);
    expect(load.exact, isTrue);
  });

  test('a 10 kg bar', () {
    expect(platesFor(60, barKg: 10)!.perSideKg, [25]);
  });

  test('plates are taken heaviest first', () {
    expect(platesFor(142.5)!.perSideKg, [25, 25, 10, 1.25]);
    expect(platesFor(100)!.perSideKg, [25, 15]);
  });

  test('a total the plates cannot make says so and gives the nearest', () {
    final load = platesFor(41)!;
    expect(load.exact, isFalse);
    expect(load.requestedKg, 41);
    expect(load.loadableKg, 40);
    final up = platesFor(41.5)!;
    expect(up.exact, isFalse);
    expect(up.loadableKg, 42.5);
    expect(up.perSideKg, [10, 1.25]);
  });

  test('below the bar, or not a number, there is nothing to load', () {
    expect(platesFor(15), isNull);
    expect(platesFor(0), isNull);
    expect(platesFor(double.nan), isNull);
    expect(platesFor(40, barKg: 0), isNull);
  });

  test('the bar choices are 20, 15 and 10', () {
    expect(kBarChoicesKg, [20, 15, 10]);
  });
}
