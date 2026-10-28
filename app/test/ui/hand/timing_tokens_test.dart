// E1: the guide's motion vocabulary, by name, on HandTiming. Each token sits
// in the range the guide gives it, the three D46 timings are unchanged, and the
// tokens run from the quickest to the longest.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/hand/motion.dart';

void main() {
  int ms(Duration d) => d.inMilliseconds;

  test('each token is in the range the guide gives it', () {
    expect(ms(HandTiming.press), inInclusiveRange(80, 120));
    expect(ms(HandTiming.quick), inInclusiveRange(150, 200));
    expect(ms(HandTiming.base), inInclusiveRange(250, 300));
    expect(ms(HandTiming.emphasis), inInclusiveRange(400, 500));
    expect(ms(HandTiming.moment), inInclusiveRange(700, 1200));
    expect(ms(HandTiming.staggerStep), inInclusiveRange(40, 60));
  });

  test('they run from the quickest to the longest', () {
    final ladder = [
      HandTiming.press,
      HandTiming.quick,
      HandTiming.base,
      HandTiming.emphasis,
      HandTiming.moment,
    ];
    for (var i = 1; i < ladder.length; i++) {
      expect(ladder[i], greaterThan(ladder[i - 1]));
    }
  });

  test('the three timings D46 chose are as they were', () {
    expect(ms(HandTiming.short), 150);
    expect(ms(HandTiming.medium), 220);
    expect(ms(HandTiming.long), 400);
    expect(HandTiming.quick, HandTiming.short);
  });
}
