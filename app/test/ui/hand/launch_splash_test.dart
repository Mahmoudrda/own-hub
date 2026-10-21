import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:own_hub/ui/hand/launch_splash.dart';

Widget _app({required bool show, bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: LaunchSplash(
      show: show,
      child: const Scaffold(body: Text('first screen')),
    ),
  ),
);

Finder get _mark => find.byWidgetPredicate(
  (w) => w is CustomPaint && w.painter is OwnHubMarkPainter,
);

void main() {
  test('the whole splash fits in 700 ms', () {
    expect(HandTiming.splash.inMilliseconds, lessThanOrEqualTo(700));
  });

  testWidgets(
    'cold start: the mark draws and is gone within 700 ms plus a frame',
    (tester) async {
      await tester.pumpWidget(_app(show: true));
      expect(_mark, findsOneWidget);
      expect(find.text('first screen'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(_mark, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 420));
      expect(_mark, findsNothing);
      expect(find.text('first screen'), findsOneWidget);
    },
  );

  testWidgets(
    'the splash absorbs a tap while it is up, then lets taps through',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: LaunchSplash(
            show: true,
            child: Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => taps++,
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('go'), warnIfMissed: false);
      expect(taps, 0);
      await tester.pump(HandTiming.splash);
      await tester.tap(find.text('go'));
      expect(taps, 1);
    },
  );

  testWidgets('warm start: no splash at all', (tester) async {
    await tester.pumpWidget(_app(show: false));
    expect(_mark, findsNothing);
    expect(find.text('first screen'), findsOneWidget);
  });

  testWidgets('Reduce Motion: no wait, the screen is there at once', (
    tester,
  ) async {
    await tester.pumpWidget(_app(show: true, still: true));
    expect(_mark, findsNothing);
    expect(find.text('first screen'), findsOneWidget);
  });

  test('cold start is taken once', () {
    LaunchSplash.enabled = true;
    expect(LaunchSplash.takeColdStart(), isTrue);
    expect(LaunchSplash.takeColdStart(), isFalse);
  });
}
