import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/hand/hand.dart';

void main() {
  testWidgets('draws a tick on and settles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: Moment())));
    await tester.pumpAndSettle();
    expect(find.byType(HandTick), findsOneWidget);
  });

  testWidgets('is simply there with motion off', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(home: Center(child: Moment())),
      ),
    );
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.byType(HandTick), findsOneWidget);
  });
}
