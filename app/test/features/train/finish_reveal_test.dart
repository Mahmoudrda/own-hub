// The finish screen's one figure counts up, and stays still when she has asked
// her phone for less motion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/train/presentation/finish_reveal.dart';

Widget _host({required bool motionOff}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: motionOff),
    child: Scaffold(
      body: FinishReveal(
        stages: 3,
        child: RevealCount(
          index: 1,
          from: 0,
          value: 4,
          format: (shown) => '$shown of 4',
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('with motion off the count is its final figure from the first '
      'frame', (tester) async {
    await tester.pumpWidget(_host(motionOff: true));
    expect(find.text('4 of 4'), findsOneWidget);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('4 of 4'), findsOneWidget);
      for (final n in [0, 1, 2, 3]) {
        expect(find.text('$n of 4'), findsNothing);
      }
    }
  });

  testWidgets('with motion on the count passes through figures on the way', (
    tester,
  ) async {
    await tester.pumpWidget(_host(motionOff: false));
    final seen = <String>{};
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      for (final n in [0, 1, 2, 3]) {
        if (find.text('$n of 4').evaluate().isNotEmpty) seen.add('$n');
      }
    }
    expect(seen, isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.text('4 of 4'), findsOneWidget);
  });
}
