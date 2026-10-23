// D40: the one celebration — deterministic, once, gone afterwards, and absent
// under Reduce Motion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/hand/paper_confetti.dart';

void main() {
  test('the same seed places the same scraps', () {
    final a = confettiScraps(42, 12);
    final b = confettiScraps(42, 12);
    expect([for (final s in a) s.x], [for (final s in b) s.x]);
    expect(confettiScraps(43, 12).first.x, isNot(a.first.x));
  });

  test('scraps stay on the page and use the three inks', () {
    for (final scrap in confettiScraps(7, 30)) {
      expect(scrap.x, inInclusiveRange(0.0, 1.0));
    }
    expect(
      {for (final s in confettiScraps(7, 30)) s.color}.length,
      3,
      reason: 'rose, sage and pencil — never gold',
    );
  });

  testWidgets('plays once and leaves nothing behind', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PaperConfetti(seed: 1))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      find.descendant(
        of: find.byType(PaperConfetti),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PaperConfetti),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('draws nothing under Reduce Motion', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(body: PaperConfetti(seed: 1)),
        ),
      ),
    );
    await tester.pump();
    expect(
      find.descendant(
        of: find.byType(PaperConfetti),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });
}
