import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/kitten_setting.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_chrome.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/ui/hand/mascot/kitten.dart';
import 'package:own_hub/ui/hand/mascot/kitten_painter.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MediaQuery(
  data: MediaQueryData(disableAnimations: disableAnimations),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: Center(child: child),
  ),
);

AnimationController _controllerOf(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.descendant(of: find.byType(Kitten), matching: find.byType(CustomPaint)),
  );
  return (paint.painter! as KittenPainter).progress as AnimationController;
}

void main() {
  setUp(() {
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
    for (final f in Directory('lib/ui/hand/mascot').listSync().whereType<File>()) {
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
