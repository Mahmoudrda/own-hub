// The moments library, M1 to M12: the table that names each moment's piece,
// timing, touch and sound, and a widget test for each one that proves it plays
// once and is simply there under Reduce Motion.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/app_state/sound.dart';
import 'package:own_hub/ui/app_ring_stat.dart';
import 'package:own_hub/ui/app_step_bar.dart';
import 'package:own_hub/ui/app_week_segments.dart';
import 'package:own_hub/ui/hand/hand.dart';

import '../../helpers/fake_sound.dart';

Widget _host(Widget child, {bool still = false}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  late FakeSoundBackend backend;
  final savedHaptics = AppHaptics.enabled;

  setUp(() {
    backend = setUpFakeSound();
    AppHaptics.enabled = () => false;
  });
  tearDown(() {
    AppHaptics.enabled = savedHaptics;
    tearDownFakeSound();
  });

  group('the table', () {
    test('names twelve moments, M1 to M12, once each', () {
      expect(MomentId.values, hasLength(12));
      expect(kMoments.keys.toSet(), MomentId.values.toSet());
      expect([for (final id in MomentId.values) kMoments[id]!.code], [
        for (var i = 1; i <= 12; i++) 'M$i',
      ]);
    });

    test('every moment says what she gets under Reduce Motion', () {
      for (final spec in kMoments.values) {
        expect(spec.reduced, isNotEmpty, reason: spec.code);
        expect(spec.piece, isNotEmpty, reason: spec.code);
      }
    });

    test('every sound named is a cue in the sound table', () {
      for (final spec in kMoments.values) {
        final cue = spec.cue;
        if (cue != null) expect(kSoundCues, contains(cue), reason: spec.code);
      }
    });

    test('the five wired moments carry the sounds they play', () {
      expect(kMoments[MomentId.setDone]!.cue, SoundCue.setDone);
      expect(kMoments[MomentId.restRing]!.cue, SoundCue.restEnd);
      expect(kMoments[MomentId.sessionPeak]!.cue, SoundCue.sessionDone);
      expect(kMoments[MomentId.foodLogged]!.cue, SoundCue.foodLogged);
      expect(kMoments[MomentId.verified]!.cue, SoundCue.verified);
    });

    test('motion lasts on the tokens, and never past two seconds', () {
      for (final entry in kMoments.entries) {
        expect(
          entry.value.motion,
          lessThanOrEqualTo(const Duration(seconds: 2)),
          reason: entry.value.code,
        );
      }
      expect(kMoments[MomentId.tilt]!.motion, Duration.zero);
      expect(kMoments[MomentId.tick]!.motion, HandTiming.moment);
    });

    test('M12 has no sound and no touch, and neither do M2, M7 and M11', () {
      for (final id in [
        MomentId.tilt,
        MomentId.welcome,
        MomentId.welcomeBack,
        MomentId.arrival,
      ]) {
        expect(kMoments[id]!.cue, isNull, reason: kMoments[id]!.code);
        expect(kMoments[id]!.haptic, isNull, reason: kMoments[id]!.code);
      }
    });

    test('feelMoment gives the sound of the moment it is asked for', () async {
      feelMoment(MomentId.verified);
      await Future<void>.delayed(Duration.zero);
      expect(backend.names, ['verified']);
    });
  });

  group('M1 the tick', () {
    testWidgets('draws on once and settles', (tester) async {
      await tester.pumpWidget(_host(const Moment()));
      await tester.pumpAndSettle();
      expect(find.byType(HandTick), findsOneWidget);
      expect(backend.played, isEmpty, reason: 'without an id it is quiet');
    });

    testWidgets('is simply there with motion off', (tester) async {
      await tester.pumpWidget(_host(const Moment(), still: true));
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.byType(HandTick), findsOneWidget);
    });

    testWidgets('can say what it means to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const Moment(label: 'Saved')));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Saved'), findsOneWidget);
      handle.dispose();
    });
  });

  group('M2 and M7 a line', () {
    testWidgets('fades up once, and a rebuild does not replay it', (
      tester,
    ) async {
      Widget line() => _host(const MomentLine('You are welcome back'));
      await tester.pumpWidget(line());
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 0);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      await tester.pumpWidget(line());
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is simply there with motion off', (tester) async {
      await tester.pumpWidget(_host(const MomentLine('Hello'), still: true));
      expect(tester.widget<Opacity>(find.byType(Opacity).first).opacity, 1);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('the words are real text for a screen reader', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const MomentLine('Hello')));
      expect(find.bySemanticsLabel('Hello'), findsOneWidget);
      handle.dispose();
    });
  });

  group('M3 a set done', () {
    Widget bar(int step) => _host(
      SizedBox(width: 240, child: AppStepBar(step: step, total: 3)),
    );

    testWidgets('the segment fills over time', (tester) async {
      await tester.pumpWidget(bar(0));
      await tester.pumpWidget(bar(1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('and at once with motion off', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(), still: true));
      await tester.pumpWidget(
        _host(
          const SizedBox(width: 240, child: AppStepBar(step: 1, total: 3)),
          still: true,
        ),
      );
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('M4 the rest ring', () {
    Widget ring(double f, {bool still = false}) => _host(
      AppRingStat(fraction: f, big: '0:20', small: 'Rest'),
      still: still,
    );

    testWidgets('drains as it is given a smaller fraction', (tester) async {
      await tester.pumpWidget(ring(1));
      await tester.pumpAndSettle();
      await tester.pumpWidget(ring(0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets('the countdown figure is there with motion off', (
      tester,
    ) async {
      await tester.pumpWidget(ring(1, still: true));
      await tester.pumpWidget(ring(0.5, still: true));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('0:20'), findsOneWidget);
    });
  });

  group('M6 the week closes', () {
    Widget week(int filled, {bool still = false}) => _host(
      AppWeekSegments(
        total: 3,
        filled: filled,
        style: WeekStyle.marks,
        stagger: HandTiming.staggerStep,
      ),
      still: still,
    );

    testWidgets('the marks arrive and settle', (tester) async {
      await tester.pumpWidget(week(3));
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('they are simply there with motion off', (tester) async {
      await tester.pumpWidget(week(3, still: true));
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('M9 a milestone', () {
    testWidgets('her number is drawn once and readable as one thing', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const MomentNumber(number: '12', label: 'Sessions')),
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.bySemanticsLabel('Sessions 12'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('it is simply there with motion off', (tester) async {
      await tester.pumpWidget(
        _host(
          const MomentNumber(number: '12', label: 'Sessions'),
          still: true,
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('12'), findsOneWidget);
    });
  });

  group('M10 verified', () {
    testWidgets('the tick gives its sound once, however it is redrawn', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Moment(id: MomentId.verified)),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(_host(const Moment(id: MomentId.verified)));
      await tester.pumpAndSettle();
      expect(backend.names, ['verified']);
    });

    testWidgets('it plays with motion off, and the tick is there', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const Moment(id: MomentId.verified), still: true),
      );
      expect(backend.names, ['verified']);
      expect(find.byType(HandTick), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });
  });

  group('M11 arrival', () {
    testWidgets('rows arrive once, and a rebuild does not replay them', (
      tester,
    ) async {
      Widget list() => _host(
        Column(
          children: StaggerIn.all([
            for (var i = 0; i < 3; i++) Text('row $i'),
          ], group: 'moments-test'),
        ),
      );
      await tester.pumpWidget(list());
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
      await tester.pumpWidget(list());
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('no stagger with motion off', (tester) async {
      await tester.pumpWidget(
        _host(
          Column(
            children: StaggerIn.all([
              for (var i = 0; i < 3; i++) Text('row $i'),
            ], group: 'moments-still'),
          ),
          still: true,
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      expect(find.text('row 2'), findsOneWidget);
    });
  });

  group('M12 tilt', () {
    testWidgets('is off with motion off', (tester) async {
      await tester.pumpWidget(
        _host(
          const TiltParallax(child: SizedBox(width: 20, height: 20)),
          still: true,
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
    });
  });
}
