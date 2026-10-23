import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_chrome.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/app_state/kitten_setting.dart';
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
  f.dip,
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
  test('the kitten always moves; only Reduce Motion holds it still', () {
    expect(KittenSetting.instance.moves, isTrue);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Kitten.resetPlayed();
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

  test('the think puts a paw at the chin, face tipped, eyes up and away', () {
    final f = KittenFrame.end(KittenPose.think);
    final paw = KittenPainter.pawOf(f, lead: true);
    // Below the mouth (0.578), on the leading side of the chin, inside the
    // head's width, and nearer the face than the shoulder is.
    expect(paw.dy, inInclusiveRange(0.6, 0.7));
    expect(paw.dx, inInclusiveRange(0.56, 0.7));
    expect(paw.dx, lessThan(KittenPainter.shoulderOf(lead: true).dx));
    expect(f.headTilt, greaterThan(0.06));
    expect(f.look.dy, lessThan(-0.5));
    expect(f.look.dx, lessThan(-0.3));
    // The other paw stays down.
    expect(KittenPainter.pawOf(f, lead: false).dy, greaterThan(0.85));
    // It stays there through the breaths: one move, then still.
    for (var ms = 900.0; ms <= 3500; ms += 50) {
      final held = KittenPainter.pawOf(
        KittenFrame.at(KittenPose.think, ms),
        lead: true,
      );
      expect((held - paw).distance, lessThan(1e-9), reason: 'ms=$ms');
    }
  });

  test('the wait sits lower with both paws folded in front, eyes soft', () {
    final f = KittenFrame.end(KittenPose.wait);
    final lead = KittenPainter.pawOf(f, lead: true);
    final trail = KittenPainter.pawOf(f, lead: false);
    expect(lead.dx, inInclusiveRange(0.5, 0.58));
    expect(trail.dx, inInclusiveRange(0.42, 0.5));
    expect(lead.dy, inInclusiveRange(0.78, 0.9));
    expect(trail.dy, inInclusiveRange(0.78, 0.9));
    expect(f.squash, lessThan(0.97));
    // Soft, never shut or smiling: waiting is not sleep and not cheer.
    expect(f.eyeOpen, inInclusiveRange(0.7, 0.9));
    expect(f.happy, 0);
    expect(f.smile, 0);
    // Never sad: it does not droop below where it sits.
    expect(f.squash, greaterThan(0.9));
  });

  test('the nod dips the head twice and comes back, nothing else moves', () {
    const nod = KittenPose.nod;
    var peaks = 0;
    var previous = 0.0;
    var rising = true;
    var maxDip = 0.0;
    for (var ms = 0.0; ms <= nod.moveMs; ms += 2) {
      final f = KittenFrame.at(nod, ms);
      maxDip = math.max(maxDip, f.dip);
      if (rising && f.dip < previous - 1e-9) {
        peaks++;
        rising = false;
      } else if (!rising && f.dip > previous + 1e-9) {
        rising = true;
      }
      previous = f.dip;
      // Paws stay at rest and the face does not turn.
      expect(f.lead, f.trail);
      expect(f.look, Offset.zero);
      expect(f.happy, 0);
    }
    expect(peaks, 2);
    expect(maxDip, inInclusiveRange(0.03, 0.06));
    expect(KittenFrame.end(nod).dip, closeTo(0, 1e-9));
    expect(nod.moveMs, lessThanOrEqualTo(600));
  });

  test('the stretch takes one paw over the head and the other out wide', () {
    final f = KittenFrame.end(KittenPose.stretch);
    final lead = KittenPainter.pawOf(f, lead: true);
    final trail = KittenPainter.pawOf(f, lead: false);
    expect(lead.dy, lessThan(0.45));
    expect(trail.dx, lessThan(0.3));
    expect(f.happy, 1);
  });

  test('the lift curls both paws up to the chest, together', () {
    final f = KittenFrame.end(KittenPose.lift);
    final lead = KittenPainter.pawOf(f, lead: true);
    final trail = KittenPainter.pawOf(f, lead: false);
    expect(lead.dy, inInclusiveRange(0.62, 0.75));
    expect(trail.dy, closeTo(lead.dy, 1e-9));
    expect(lead.dx - trail.dx, inInclusiveRange(0.12, 0.3));
  });

  test('the peek ends low in its box with both paws on the edge', () {
    final start = KittenFrame.at(KittenPose.peek, 0);
    final end = KittenFrame.end(KittenPose.peek);
    expect(start.lift, lessThan(-0.9));
    expect(end.lift, closeTo(-0.4, 1e-9));
    for (final lead in [true, false]) {
      final paw = KittenPainter.placed(
        end,
        KittenPainter.pawOf(end, lead: lead),
      );
      expect(paw.dy, inInclusiveRange(0.8, 0.94));
    }
  });

  testWidgets('every prop draws, in both directions, without throwing', (
    tester,
  ) async {
    for (final dir in TextDirection.values) {
      for (final prop in KittenProp.values) {
        await tester.pumpWidget(
          Directionality(
            textDirection: dir,
            child: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Center(
                child: Kitten(
                  pose: prop == KittenProp.dumbbell
                      ? KittenPose.lift
                      : KittenPose.rest,
                  prop: prop,
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '${dir.name} $prop');
      }
    }
  });

  test('no pose is sad, sleepy, pleading or angry', () {
    for (final pose in KittenPose.values) {
      final run = kittenRunFor(pose).inMilliseconds;
      for (var ms = 0; ms <= run; ms += 10) {
        final f = KittenFrame.at(pose, ms.toDouble());
        final why = '${pose.name} $ms';
        // Not drooping or slumped.
        expect(f.squash, greaterThan(0.88), reason: why);
        // Eyes are only fully shut for a blink, never held shut.
        if (f.eyeOpen < 0.5) {
          expect(f.eyeOpen, greaterThan(0.0), reason: why);
        }
        // The head never hangs.
        expect(f.dip, lessThan(0.06), reason: why);
        expect(f.headTilt.abs(), lessThan(0.15), reason: why);
      }
      // And it ends awake.
      expect(
        KittenFrame.end(pose).eyeOpen,
        greaterThan(0.7),
        reason: pose.name,
      );
    }
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
          // The peek comes up from below the edge, which clips it, so its
          // paws are below the box on the way in and inside it at the end.
          if (pose == KittenPose.peek && ms < pose.moveMs) continue;
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

  testWidgets('three budgeted appearances move per sitting, then it holds', (
    tester,
  ) async {
    // D48: the first three budgeted kittens to arrive move, whichever screen
    // they are on; the fourth is simply there.
    final poses = [
      (KittenPose.point, 'T06'),
      (KittenPose.cheer, 'R10'),
      (KittenPose.wave, 'T04'),
      (KittenPose.cheer, 'T08'),
    ];
    for (final (i, (pose, moment)) in poses.indexed) {
      await tester.pumpWidget(
        _host(Kitten(pose: pose, moment: moment, sessionBudget: true)),
      );
      if (i < Kitten.sessionBudgetLimit) {
        expect(_controllerOf(tester).isAnimating, isTrue, reason: moment);
        await tester.pumpAndSettle();
      } else {
        expect(_controllerOf(tester).value, 1, reason: moment);
        expect(tester.binding.hasScheduledFrame, isFalse);
      }
      await tester.pumpWidget(const SizedBox());
    }
    expect(Kitten.sessionBudgetLimit, 3);
    expect(Kitten.budgetUsed, 3);
  });

  testWidgets('one kitten changing pose on a screen takes one place', (
    tester,
  ) async {
    // C12 goes from think to point to cheer: three moves, one appearance.
    for (final pose in [KittenPose.think, KittenPose.point, KittenPose.cheer]) {
      await tester.pumpWidget(_host(Kitten(pose: pose, sessionBudget: true)));
      expect(_controllerOf(tester).isAnimating, isTrue, reason: pose.name);
      await tester.pumpAndSettle();
    }
    expect(Kitten.budgetUsed, 1);
  });

  testWidgets('a kitten held still takes nothing from the budget', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const Kitten(
          pose: KittenPose.think,
          holdStill: true,
          sessionBudget: true,
        ),
      ),
    );
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(Kitten.budgetUsed, 0);
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

  test('a loop is allowed only in the idle controller, gated by the check', () {
    // D50: the kitten breathes, so one repeat is allowed, and only for the
    // idle loop behind kittenStill. No timers, no free tickers.
    final banned = RegExp(r'\bTimer\(|\bTimer\.periodic|\bTicker\(');
    final repeats = <String>[];
    for (final f in Directory(
      'lib/ui/hand/mascot',
    ).listSync().whereType<File>()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//')) continue;
        expect(banned.hasMatch(line), isFalse, reason: '${f.path}:${i + 1}');
        if (line.contains('.repeat(')) repeats.add('${f.path}:${i + 1}');
      }
    }
    expect(repeats, hasLength(1));
    expect(repeats.single, startsWith('lib/ui/hand/mascot/kitten.dart'));
    final source = File('lib/ui/hand/mascot/kitten.dart').readAsStringSync();
    final sync = RegExp(r'void _syncIdle\(\) \{[\s\S]*?\n  \}\n')
        .firstMatch(source)!
        .group(0)!;
    expect(sync, contains('!kittenStill(context)'));
    expect(sync, contains('_idle.repeat()'));
  });

  test('one kitten per screen: a file places at most one', () {
    // Three files place more than one, each as exclusive arms of one choice:
    // C11's strip shows the one guidance step she is on, the tour shows the
    // card for a stop or the closing card, never both, and C14 shows the
    // cheer once she is approved or the wait before that.
    const exclusive = {
      'lib/features/signup/presentation/being_checked_view.dart',
      'lib/features/signup/presentation/selfie_capture_view.dart',
      'lib/features/signup/presentation/demo/demo_chrome.dart',
    };
    final call = RegExp(r'\bKitten\(');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.startsWith('lib/ui/hand/mascot') ||
          f.path.startsWith('lib/l10n')) {
        continue;
      }
      var count = 0;
      for (final line in f.readAsLinesSync()) {
        if (line.trimLeft().startsWith('//')) continue;
        count += call.allMatches(line).length;
      }
      if (exclusive.contains(f.path)) continue;
      expect(count, lessThanOrEqualTo(1), reason: f.path);
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
      // The ID card and the camera screens' frames, the consent, and the
      // training screens where the phone is on the floor.
      'lib/features/signup/presentation/why_we_check_view.dart',
      'lib/features/signup/presentation/consent_view.dart',
      'lib/features/signup/presentation/id_capture_view.dart',
      'lib/features/train/presentation/mid_set_view.dart',
      'lib/features/train/presentation/resting_view.dart',
      'lib/features/train/presentation/follow_along_view.dart',
      'lib/features/signup/presentation/pledge_view.dart',
      'lib/features/signup/presentation/woman_reviewer_view.dart',
      // The new variations stay off the clips, the logging screens and the
      // coaching screens.
      'lib/features/train/presentation/exercise_video_view.dart',
      'lib/features/train/presentation/exercise_demo_view.dart',
      'lib/features/train/presentation/move_logged_view.dart',
      'lib/features/train/presentation/logged_from_memory_view.dart',
      'lib/features/coach',
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

  test('the new variations sit only where they were placed', () {
    String src(String path) => File('lib/features/$path').readAsStringSync();
    // Still, at 40, on Train and on the day's page.
    final train = src('train/presentation/train_view.dart');
    expect(train, contains('KittenPose.lift'));
    expect(train, contains('KittenProp.dumbbell'));
    final day = src('train/presentation/workout_day_view.dart');
    expect(day, contains('KittenPose.stretch'));
    for (final file in [train, day]) {
      expect(file, contains('holdStill: true'));
      expect(file, contains('size: 40'));
    }
    // The heart on the two cheers.
    expect(
      src('today/presentation/first_week_view.dart'),
      contains('KittenProp.heart'),
    );
    expect(
      src('train/presentation/finished_view.dart'),
      contains('cheer ? KittenProp.heart : null'),
    );
    // The peek comes in from a screen edge and clips itself to its box, so it
    // has no mid-page home. First-view empty states wave instead.
    const peeks = <String, String>{};
    const waves = {
      'eat/presentation/week_plan_view.dart': 'E07',
      'train/presentation/program_view.dart': 'R02',
    };
    for (final e in peeks.entries) {
      final text = src(e.key);
      expect(text, contains('KittenPose.peek'), reason: e.key);
      expect(text, contains("moment: '${e.value}'"), reason: e.key);
    }
    for (final e in waves.entries) {
      final text = src(e.key);
      expect(text, contains('KittenPose.wave'), reason: e.key);
      expect(text, contains("moment: '${e.value}'"), reason: e.key);
    }
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.startsWith('lib/ui/hand/mascot')) continue;
      final text = f.readAsStringSync();
      final onlyPeek = peeks.keys.any((k) => f.path.endsWith(k));
      if (!onlyPeek) {
        expect(text.contains('KittenPose.peek'), isFalse, reason: f.path);
      }
    }
  });

  testWidgets('a still kitten blinks once the second time it is opened', (
    tester,
  ) async {
    Widget kitten() => _host(
      const Kitten(
        pose: KittenPose.stretch,
        moment: 'R03',
        holdStill: true,
        blinkOnRevisit: true,
      ),
    );
    await tester.pumpWidget(kitten());
    expect(_controllerOf(tester).isAnimating, isFalse);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(kitten());
    // The second time: one blink, 700 ms, and then nothing is scheduled.
    expect(_controllerOf(tester).isAnimating, isTrue);
    await tester.pumpAndSettle();
    expect(_controllerOf(tester).value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
    // Never a third.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(kitten());
    expect(_controllerOf(tester).isAnimating, isFalse);
  });

  testWidgets('the revisit blink holds still under reduced motion', (
    tester,
  ) async {
    Widget kitten() => _host(
      const Kitten(
        pose: KittenPose.lift,
        moment: 'R01',
        holdStill: true,
        blinkOnRevisit: true,
      ),
      disableAnimations: true,
    );
    for (var i = 0; i < 2; i++) {
      await tester.pumpWidget(kitten());
      expect(_controllerOf(tester).isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox());
    }
  });

  group('idle loop', () {
    setUp(() => Kitten.idleInTests = true);
    tearDown(() => Kitten.idleInTests = false);

    AnimationController idleOf(WidgetTester tester) {
      final paint = tester.widget<CustomPaint>(
        find.descendant(
          of: find.byType(Kitten),
          matching: find.byType(CustomPaint),
        ),
      );
      return (paint.painter! as KittenPainter).idle! as AnimationController;
    }

    testWidgets('runs when motion is allowed, and keeps running', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const Kitten(pose: KittenPose.rest)));
      expect(idleOf(tester).isAnimating, isTrue);
      await tester.pump(const Duration(seconds: 30));
      expect(idleOf(tester).isAnimating, isTrue);
      // Unmount: nothing is left running.
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(find.byType(Kitten), findsNothing);
    });

    testWidgets('a held-still kitten still breathes', (tester) async {
      await tester.pumpWidget(
        _host(const Kitten(pose: KittenPose.rest, holdStill: true)),
      );
      expect(idleOf(tester).isAnimating, isTrue);
    });

    testWidgets('Android Remove animations: no idle ticker', (tester) async {
      await tester.pumpWidget(
        _host(const Kitten(pose: KittenPose.rest), disableAnimations: true),
      );
      expect(idleOf(tester).isAnimating, isFalse);
      expect(idleOf(tester).value, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('iOS Reduce Motion: no idle ticker', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(reduceMotion: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(_host(const Kitten(pose: KittenPose.rest)));
      expect(idleOf(tester).isAnimating, isFalse);
    });

    testWidgets('pauses while its route is covered', (tester) async {
      await tester.pumpWidget(
        _host(
          TickerMode(
            enabled: false,
            child: const Kitten(pose: KittenPose.rest),
          ),
        ),
      );
      expect(idleOf(tester).isAnimating, isFalse);
    });

    test(
      'breath is 1.00 to 1.025 over 2.4 s, the float 3 dp, the blink short',
      () {
        expect(KittenIdle.breath(0), closeTo(0, 1e-9));
        expect(KittenIdle.breath(1200 / KittenIdle.loopMs), closeTo(1, 1e-9));
        expect(KittenIdle.breath(2400 / KittenIdle.loopMs), closeTo(0, 1e-9));
        expect(KittenIdle.breath(1), closeTo(0, 1e-9));
        expect(KittenIdle.scale, 0.025);
        expect(KittenIdle.floatDp, 3);
        var blinks = 0;
        var wasShut = false;
        final gaps = <int>[];
        var last = 0;
        for (var ms = 0; ms < KittenIdle.loopMs; ms++) {
          final shut = KittenIdle.blink(ms / KittenIdle.loopMs) > 0;
          if (shut && !wasShut) {
            blinks++;
            gaps.add(ms - last);
            last = ms;
          }
          wasShut = shut;
        }
        expect(blinks, 2);
        // Between four and seven seconds apart, round the wrap too.
        gaps.add(KittenIdle.loopMs - last + gaps.first);
        for (final g in gaps.skip(1)) {
          expect(g, inInclusiveRange(4000, 7000));
        }
      },
    );

    testWidgets('nothing paints outside the box at the top of a breath, '
        'at text scale 2.0', (tester) async {
      const edge = 24.0;
      for (final pose in KittenPose.values) {
        for (final size in const [32.0, 48.0, 72.0]) {
          Kitten.resetPlayed();
          // Large text changes nothing about the box a kitten is given.
          await tester.pumpWidget(
            MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Center(
                  child: Kitten(pose: pose, size: size),
                ),
              ),
            ),
          );
          final box = tester.getRect(find.byType(Kitten));
          expect(box.width, size);
          expect(
            box.height,
            closeTo(size + KittenIdle.headroomFor(size), 1e-6),
          );
          final p = KittenPainter(
            progress: const AlwaysStoppedAnimation<double>(1),
            pose: pose,
            rtl: false,
          );
          final peak = AlwaysStoppedAnimation<double>(1200 / KittenIdle.loopMs);
          final peaked = KittenPainter(
            progress: p.progress,
            pose: pose,
            rtl: false,
            idle: peak,
            headroom: KittenIdle.headroomFor(size),
          );
          final recorder = ui.PictureRecorder();
          peaked.paint(
            Canvas(recorder),
            Size(size, size + KittenIdle.headroomFor(size)),
          );
          final image = await tester.runAsync(() async {
            final pic = recorder.endRecording();
            final side = (size + 2 * edge).ceil();
            final rec = ui.PictureRecorder();
            final c = Canvas(rec)..translate(edge, edge);
            c.drawPicture(pic);
            return rec.endRecording().toImage(side, side);
          });
          final bytes = (await tester.runAsync(
            () => image!.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          final w = image!.width;
          final h = image.height;
          final boxH = size + KittenIdle.headroomFor(size);
          var outside = 0;
          for (var y = 0; y < h; y++) {
            for (var x = 0; x < w; x++) {
              final inside =
                  x >= edge && x < edge + size && y >= edge && y < edge + boxH;
              if (inside) continue;
              if (bytes.getUint8((y * w + x) * 4 + 3) != 0) outside++;
            }
          }
          expect(outside, 0, reason: '${pose.name} at $size');
        }
      }
    });
  });
}
