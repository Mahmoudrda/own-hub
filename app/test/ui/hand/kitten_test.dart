import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/kitten_setting.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_chrome.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';
import 'package:own_hub/ui/hand/mascot/kitten_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

/// Every moving value of a frame, so motion can be checked as numbers.
List<double> _values(KittenFrame f) => [
  f.lift,
  f.squash,
  f.headTilt,
  f.lead,
  f.trail,
  f.leadPaw,
  f.trailPaw,
  f.look.dx,
  f.look.dy,
  f.eyeOpen,
  f.happy,
  f.smile,
  f.tail,
  f.ear,
];

AnimationController _controllerOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(
      of: find.byType(Kitten),
      matching: find.byType(CustomPaint),
    ),
  );
  return (paint.painter! as KittenPainter).progress as AnimationController;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Kitten.resetPlayed();
    KittenSetting.instance.resetForTest();
  });

  testWidgets('moves once, then settles with nothing left scheduled', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Kitten(pose: KittenPose.wave)));
    expect(_controllerOf(tester).isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('every pose finishes inside its run, the move within 1.2 s', (
    tester,
  ) async {
    for (final pose in KittenPose.values) {
      expect(pose.moveMs, lessThanOrEqualTo(1200), reason: pose.name);
      // The breaths end exactly where the move left it.
      final end = KittenFrame.end(pose);
      final moved = KittenFrame.at(pose, pose.moveMs.toDouble());
      expect(end.squash, closeTo(moved.squash, 1e-9), reason: pose.name);
      expect(end.tail, closeTo(0, 1e-9), reason: pose.name);
    }
  });

  testWidgets('Android Remove animations: the last frame at once', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const Kitten(pose: KittenPose.cheer), disableAnimations: true),
    );
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('iOS Reduce Motion: the last frame at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(reduceMotion: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(_host(const Kitten(pose: KittenPose.cheer)));
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('her Profile switch off: still', (tester) async {
    KittenSetting.instance.resetForTest(moves: false);
    await tester.pumpWidget(_host(const Kitten(pose: KittenPose.wave)));
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('turning it off in Profile holds it still at once', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const Kitten(pose: KittenPose.wave)));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_controllerOf(tester).isAnimating, isTrue);
    unawaited(KittenSetting.instance.set(false));
    expect(_controllerOf(tester).isAnimating, isFalse);
    expect(_controllerOf(tester).value, 1);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('the wave raises the leading paw beside the face and lowers it', () {
    final shoulder = KittenPainter.shoulderOf(lead: true);
    const wave = KittenPose.wave;
    // Through the whole wave, from just after the rise to just before the
    // paw comes down, it is well above the shoulder at cheek or ear height,
    // out at the side of the head rather than across the face.
    for (var u = 0.32; u <= 0.78; u += 0.01) {
      final f = KittenFrame.at(wave, u * wave.moveMs);
      final paw = KittenPainter.pawOf(f, lead: true);
      expect(paw.dy, lessThan(shoulder.dy - 0.15), reason: 'u=$u');
      expect(paw.dy, lessThan(0.56), reason: 'u=$u');
      expect(paw.dx, greaterThan(0.76), reason: 'u=$u');
      final trail = KittenPainter.pawOf(f, lead: false);
      expect(trail.dy, greaterThan(0.85), reason: 'u=$u');
    }
    // And it really goes side to side, not just up.
    final xs = [
      for (var u = 0.32; u <= 0.78; u += 0.01)
        KittenPainter.pawOf(
          KittenFrame.at(wave, u * wave.moveMs),
          lead: true,
        ).dx,
    ];
    expect(xs.reduce(math.max) - xs.reduce(math.min), greaterThan(0.06));
    // Lowered again at the end.
    final end = KittenPainter.pawOf(KittenFrame.end(wave), lead: true);
    expect(end.dy, greaterThan(0.85));
  });

  test('the cheer puts both paws up above the shoulders, and keeps them', () {
    const cheer = KittenPose.cheer;
    for (var u = 0.3; u <= 1.0; u += 0.02) {
      final f = KittenFrame.at(cheer, u * cheer.moveMs);
      for (final lead in [true, false]) {
        final paw = KittenPainter.pawOf(f, lead: lead);
        final shoulder = KittenPainter.shoulderOf(lead: lead);
        expect(paw.dy, lessThan(shoulder.dy - 0.1), reason: 'u=$u');
        expect((paw.dx - 0.5).abs(), greaterThan(0.3), reason: 'u=$u');
      }
    }
    final end = KittenFrame.end(cheer);
    expect(end.happy, 1);
    for (final lead in [true, false]) {
      expect(
        KittenPainter.pawOf(end, lead: lead).dy,
        lessThan(KittenPainter.shoulderOf(lead: lead).dy - 0.1),
      );
    }
  });

  test('the point reaches forward at chest height, eyes following', () {
    final f = KittenFrame.end(KittenPose.point);
    final paw = KittenPainter.pawOf(f, lead: true);
    expect(paw.dx, greaterThan(0.85));
    expect(paw.dy, inInclusiveRange(0.62, 0.8));
    expect(f.look.dx, greaterThan(0.9));
  });

  test('no part leaves the box at any instant', () {
    for (final pose in KittenPose.values) {
      final run = kittenRunFor(pose).inMilliseconds;
      for (var ms = 0; ms <= run; ms += 5) {
        final f = KittenFrame.at(pose, ms.toDouble());
        for (final lead in [true, false]) {
          final paw = KittenPainter.placed(
            f,
            KittenPainter.pawOf(f, lead: lead),
          );
          // The paw's radius and its soft edge.
          const r = 0.056;
          final why = '${pose.name} $ms';
          expect(paw.dx - r, greaterThan(0), reason: why);
          expect(paw.dx + r, lessThan(1), reason: why);
          expect(paw.dy - r, greaterThan(0), reason: why);
          expect(paw.dy + r, lessThan(1), reason: why);
        }
      }
    }
  });

  test('motion is smooth: no jumps in place or in speed, 1 ms apart', () {
    for (final pose in KittenPose.values) {
      final run = kittenRunFor(pose).inMilliseconds;
      var a = _values(KittenFrame.at(pose, 0));
      var b = _values(KittenFrame.at(pose, 1));
      for (var ms = 2; ms <= run + 2; ms++) {
        final c = _values(KittenFrame.at(pose, ms.toDouble()));
        for (var i = 0; i < c.length; i++) {
          final why = '${pose.name} value $i at $ms ms';
          // Where it is barely changes in a millisecond...
          expect((c[i] - b[i]).abs(), lessThan(0.04), reason: why);
          // ...and neither does how fast it moves: a move that starts or
          // stops dead would show here as a sudden change in speed.
          expect((c[i] - 2 * b[i] + a[i]).abs(), lessThan(1.5e-3), reason: why);
        }
        a = b;
        b = c;
      }
    }
  });

  testWidgets('a named moment moves only the first time in a run', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const Kitten(pose: KittenPose.wave, moment: 'C01')),
    );
    expect(_controllerOf(tester).isAnimating, isTrue);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _host(const Kitten(pose: KittenPose.wave, moment: 'C01')),
    );
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('a new replay key moves it again', (tester) async {
    await tester.pumpWidget(
      _host(const Kitten(pose: KittenPose.point, replayKey: 1)),
    );
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _host(const Kitten(pose: KittenPose.point, replayKey: 2)),
    );
    expect(_controllerOf(tester).isAnimating, isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('is never read out', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const Kitten(pose: KittenPose.rest)));
    await tester.pumpAndSettle();
    final node = tester.getSemantics(find.byType(Kitten));
    expect(node.label, isEmpty);
    expect(node.childrenCount, 0);
    handle.dispose();
  });

  testWidgets('draws in Arabic too, mirrored', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: const Center(child: Kitten(pose: KittenPose.point)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(Kitten),
        matching: find.byType(CustomPaint),
      ),
    );
    expect((paint.painter! as KittenPainter).rtl, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tour card shows it only when asked, never on Cycle', (
    tester,
  ) async {
    Widget card({required bool guide}) => MaterialApp(
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Scaffold(
        body: DemoCoachCard(
          number: 1,
          total: 7,
          title: 'Title',
          line: 'Line',
          onNext: () {},
          guide: guide,
        ),
      ),
    );
    await tester.pumpWidget(card(guide: true));
    await tester.pumpAndSettle();
    expect(find.byType(Kitten), findsOneWidget);
    await tester.pumpWidget(card(guide: false));
    await tester.pumpAndSettle();
    expect(find.byType(Kitten), findsNothing);
    final source = File(
      'lib/features/signup/presentation/look_around_view.dart',
    ).readAsStringSync();
    expect(source, contains('guide: stop != DemoStop.cycle'));
  });

  test('no loops and no timers in the kitten', () {
    final banned = RegExp(r'\.repeat\(|\bTimer\(|\bTimer\.periodic|\bTicker\(');
    for (final f in Directory(
      'lib/ui/hand/mascot',
    ).listSync().whereType<File>()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        expect(banned.hasMatch(line), isFalse, reason: '${f.path}:${i + 1}');
      }
    }
  });

  test('never on the screens it must stay off', () {
    // Cycle, body data, deletion, Rahma's content, the assistant, errors.
    const offLimits = [
      'lib/features/cycle',
      'lib/features/progress',
      'lib/features/assistant',
      'lib/features/eat/presentation/rahma_letter_view.dart',
      'lib/features/eat/presentation/rahma_recipe_view.dart',
      'lib/features/account/presentation/your_data_sheet.dart',
    ];
    for (final path in offLimits) {
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.notFound) continue;
      final files = entity == FileSystemEntityType.directory
          ? Directory(path)
                .listSync(recursive: true)
                .whereType<File>()
                .where((f) => f.path.endsWith('.dart'))
          : [File(path)];
      for (final f in files) {
        expect(
          f.readAsStringSync().contains('Kitten('),
          isFalse,
          reason: f.path,
        );
      }
    }
  });
}
