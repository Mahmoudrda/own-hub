// The ID and selfie screens turn the secure flag on while they are up, and
// off when they close; on iOS a linen cover goes over them while inactive.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/secure_screen.dart';

void main() {
  late List<bool> calls;
  setUp(() {
    calls = [];
    secureApply = (on) async => calls.add(on);
  });

  testWidgets('on at open, off at close, off on dispose', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SecureScreen(child: Text('card'))),
    );
    expect(calls, [true]);
    await tester.pumpWidget(const MaterialApp(home: Text('gone')));
    expect(calls, [true, false]);
  });

  testWidgets('two overlapping screens: off only after the last closes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            SecureScreen(child: Text('a')),
            SecureScreen(child: Text('b')),
          ],
        ),
      ),
    );
    expect(calls, [true]);
    await tester.pumpWidget(
      const MaterialApp(home: SecureScreen(child: Text('a'))),
    );
    expect(calls, [true]);
    await tester.pumpWidget(const MaterialApp(home: Text('gone')));
    expect(calls, [true, false]);
  });

  testWidgets('a failing platform never throws', (tester) async {
    secureApply = (on) async => throw PlatformException(code: 'x');
    await tester.pumpWidget(
      const MaterialApp(home: SecureScreen(child: Text('card'))),
    );
    await tester.pumpWidget(const MaterialApp(home: Text('gone')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS: linen cover while inactive, removed on resume', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(
      const MaterialApp(home: SecureScreen(child: Text('card'))),
    );
    expect(find.byType(ColoredBox), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0xFFFCF8F2),
      ),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0xFFFCF8F2),
      ),
      findsNothing,
    );
    debugDefaultTargetPlatformOverride = null;
  });
}
