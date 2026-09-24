// The tap target floor.
//
// A first-time-user review measured text buttons at 40 points and read that as
// a miss on a 68 year old's phone. Forty is the number in the *call site* —
// `height: 40` — and `AppButton` already wraps every variant in a
// `ConstrainedBox(minHeight: 44)`, so the painted block can be 40 while the
// thing she can hit is 44. That is a distinction worth holding to rather than
// re-deriving from the widget tree every time somebody measures it, because
// the two numbers are meant to differ: the underline treatment does not need
// to grow with the target.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

Widget _host(Widget child) => MaterialApp(
  theme: buildTheme(const Locale('en')),
  home: Scaffold(
    body: Center(child: IntrinsicWidth(child: child)),
  ),
);

void main() {
  for (final variant in AppButtonVariant.values) {
    testWidgets('${variant.name} meets 44 points even when asked for less', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(AppButton('Tap', variant: variant, height: 30, onPressed: () {})),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(AppButton));
      expect(
        size.height,
        greaterThanOrEqualTo(44),
        reason:
            'this product is tapped mid-set with one hand; 44 is the iOS '
            'minimum and the floor is enforced rather than assumed',
      );
    });
  }

  testWidgets('a taller button is not shrunk to the floor', (tester) async {
    await tester.pumpWidget(_host(const AppButton('Tap', height: 56)));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byType(AppButton)).height,
      greaterThanOrEqualTo(56),
    );
  });
}
