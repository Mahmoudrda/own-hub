// Every log that offers an undo also shows that it was saved: a hand-drawn tick
// beside the words (D48).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/app_undo_bar.dart';
import 'package:own_hub/ui/hand/hand.dart';

Widget _host({bool disableAnimations = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: const Scaffold(
      body: AppUndoBar(message: 'Set saved', undoLabel: 'Undo'),
    ),
  ),
);

void main() {
  testWidgets('a tick is drawn on as the bar arrives', (tester) async {
    await tester.pumpWidget(_host());
    expect(find.byType(HandTick), findsOneWidget);
    expect(tester.widget<HandTick>(find.byType(HandTick)).drawOn, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('under reduced motion the tick is simply there', (tester) async {
    await tester.pumpWidget(_host(disableAnimations: true));
    expect(find.byType(HandTick), findsOneWidget);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
