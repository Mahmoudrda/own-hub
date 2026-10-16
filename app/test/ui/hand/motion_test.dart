import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/kitten_setting.dart';
import 'package:own_hub/theme/hand_theme.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

AccelerometerEvent _tilt(double x, double y) =>
    AccelerometerEvent(x, y, 0, DateTime(2026));

Widget _host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  group('TiltParallax', () {
    late StreamController<AccelerometerEvent> readings;
    var listeners = 0;
    var cancels = 0;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      listeners = 0;
      cancels = 0;
      readings = StreamController<AccelerometerEvent>.broadcast(
        onListen: () => listeners++,
        onCancel: () => cancels++,
      );
      TiltParallax.source = () => readings.stream;
    });

    tearDown(() async {
      await readings.close();
    });

    Offset shiftOf(WidgetTester tester) {
      final t = tester
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(TiltParallax),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .getTranslation();
      return Offset(t.x, t.y);
    }

    testWidgets('moves with the phone and never past 8 px', (tester) async {
      await tester.pumpWidget(
        _host(const TiltParallax(child: SizedBox(width: 50, height: 50))),
      );
      expect(listeners, 1);
      // The first reading is where she is holding it.
      readings.add(_tilt(0, 6));
      await tester.pump();
      for (var i = 0; i < 200; i++) {
        readings.add(_tilt(9.8, 6));
        await tester.pump();
      }
      final shift = shiftOf(tester);
      expect(shift.dx.abs(), closeTo(8, 1e-6));
      expect(shift.dy.abs(), lessThanOrEqualTo(8));
    });

    testWidgets('is filtered: one jolt barely moves it', (tester) async {
      await tester.pumpWidget(
        _host(const TiltParallax(child: SizedBox(width: 50, height: 50))),
      );
      readings.add(_tilt(0, 6));
      await tester.pump();
      readings.add(_tilt(9.8, 6));
      await tester.pump();
      expect(shiftOf(tester).dx.abs(), lessThan(2.5));
    });

    testWidgets('does not listen at all under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(
          const TiltParallax(child: SizedBox(width: 50, height: 50)),
          still: true,
        ),
      );
      expect(listeners, 0);
      readings.add(_tilt(9.8, 0));
      await tester.pump();
      expect(shiftOf(tester), Offset.zero);
    });

    testWidgets('lets go when the kitten switch is off, and when disposed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const TiltParallax(child: SizedBox(width: 50, height: 50))),
      );
      expect(listeners, 1);
      await KittenSetting.instance.set(false);
      await tester.pump();
      expect(cancels, 1);
      await KittenSetting.instance.set(true);
      await tester.pump();
      expect(listeners, 2);
      await tester.pumpWidget(_host(const SizedBox()));
      expect(cancels, 2);
    });

    testWidgets('listens only while its route is the current one', (
      tester,
    ) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: const Scaffold(
            body: TiltParallax(child: SizedBox(width: 50, height: 50)),
          ),
        ),
      );
      expect(listeners, 1);
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(builder: (_) => const Scaffold()),
        ),
      );
      await tester.pumpAndSettle();
      expect(cancels, 1);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(listeners, 2);
    });
  });

  group('press spring', () {
    double scaleOf(WidgetTester tester) => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(AppButton),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .entry(0, 0);

    testWidgets('a button shrinks to 0.97 on a spring and settles back', (
      tester,
    ) async {
      await tester.pumpWidget(_host(AppButton('Go', onPressed: () {})));
      expect(scaleOf(tester), 1);
      final g = await tester.startGesture(tester.getCenter(find.text('Go')));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(scaleOf(tester), lessThan(1));
      await tester.pump(const Duration(seconds: 1));
      expect(scaleOf(tester), closeTo(0.97, 0.002));
      await g.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1, 1e-4));
    });

    testWidgets('is instant under reduced motion, and still tappable', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(AppButton('Go', onPressed: () => taps++), still: true),
      );
      final g = await tester.startGesture(tester.getCenter(find.text('Go')));
      await tester.pump();
      expect(scaleOf(tester), 1);
      await g.up();
      await tester.pump();
      expect(taps, 1);
    });
  });

  testWidgets('FingerTilt leans at most 6 degrees and springs back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const FingerTilt(child: SizedBox(width: 200, height: 100))),
    );
    Matrix4 m() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(FingerTilt),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform;
    final box = tester.getRect(find.byType(FingerTilt));
    final g = await tester.startGesture(box.bottomRight - const Offset(1, 1));
    await tester.pump();
    // sin(6 degrees) is about 0.1045 on the rotation entries.
    expect(m().entry(0, 2).abs(), lessThanOrEqualTo(0.1046));
    expect(m().entry(0, 2).abs(), greaterThan(0.09));
    await g.up();
    await tester.pumpAndSettle();
    expect(m().entry(0, 2).abs(), lessThan(1e-4));
  });

  testWidgets('FingerTilt draws nothing extra under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const FingerTilt(child: SizedBox(width: 200, height: 100)),
        still: true,
      ),
    );
    expect(
      find.descendant(
        of: find.byType(FingerTilt),
        matching: find.byType(Listener),
      ),
      findsNothing,
    );
  });

  group('route transition', () {
    Future<void> openSecond(WidgetTester tester, {required bool still}) async {
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: handTheme(ThemeData()),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: still),
            child: child!,
          ),
          home: const Scaffold(body: Text('first')),
        ),
      );
      unawaited(
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('second')),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
    }

    testWidgets('fades through, so the next page is not yet opaque', (
      tester,
    ) async {
      expect(
        handTheme(ThemeData())
            .pageTransitionsTheme
            .builders[TargetPlatform.android],
        isA<HandPageTransitionsBuilder>(),
      );
      await openSecond(tester, still: false);
      final opacities = find
          .ancestor(
            of: find.text('second'),
            matching: find.byType(FadeTransition),
          )
          .evaluate()
          .map((e) => (e.widget as FadeTransition).opacity.value);
      expect(opacities.reduce((a, b) => a < b ? a : b), lessThan(1));
      await tester.pumpAndSettle();
    });

    testWidgets('has no transition under reduced motion', (tester) async {
      await openSecond(tester, still: true);
      final fades = find.ancestor(
        of: find.text('second'),
        matching: find.byType(FadeTransition),
      );
      for (final e in fades.evaluate()) {
        expect((e.widget as FadeTransition).opacity.value, 1);
      }
    });
  });

  group('entrances and waits', () {
    testWidgets('a row eases in once, and not again on a revisit', (
      tester,
    ) async {
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      await tester.pumpWidget(
        _host(
          ValueListenableBuilder<bool>(
            valueListenable: shown,
            builder: (_, on, _) => on
                ? const Column(
                    children: [
                      StaggerIn(index: 0, child: Text('a')),
                      StaggerIn(index: 3, child: Text('b')),
                    ],
                  )
                : const SizedBox(),
          ),
        ),
      );
      double ink(String t) => tester
          .widget<FadeTransition>(
            find
                .ancestor(
                  of: find.text(t),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity
          .value;
      await tester.pump(const Duration(milliseconds: 20));
      expect(ink('b'), 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(ink('a'), greaterThan(0));
      await tester.pumpAndSettle();
      expect(ink('b'), 1);
      // The same visit, rows built again: already there.
      shown.value = false;
      await tester.pump();
      shown.value = true;
      await tester.pump();
      expect(ink('b'), 1);
    });

    testWidgets('rows are there at once under reduced motion', (tester) async {
      await tester.pumpWidget(
        _host(const StaggerIn(index: 2, child: Text('a')), still: true),
      );
      expect(
        tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text('a'),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value,
        1,
      );
    });

    testWidgets('the shimmer runs while it is on screen and stops with it', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const Skeleton(width: 56, height: 72)));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpWidget(_host(const SizedBox()));
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the shimmer is a still block under reduced motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Skeleton(width: 56, height: 72), still: true),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets(
      'a swapped card eases between states, and is instant when still',
      (tester) async {
        Widget card(String t, {bool still = false}) => _host(
          HandSwap(child: Text(t, key: ValueKey(t))),
          still: still,
        );
        await tester.pumpWidget(card('one'));
        await tester.pumpWidget(card('two'));
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.text('one'), findsOneWidget);
        expect(find.text('two'), findsOneWidget);
        await tester.pumpAndSettle();
        expect(find.text('one'), findsNothing);

        await tester.pumpWidget(card('one', still: true));
        await tester.pumpWidget(card('two', still: true));
        await tester.pump();
        expect(find.text('one'), findsNothing);
      },
    );
  });
}
