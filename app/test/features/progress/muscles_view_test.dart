// P06 "Your muscles": the figure draws, turns, answers a tap with the part's
// numbers, stands still under reduced motion, says what to do before the
// first log, and reads right to left in Arabic.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/progress/domain/muscle_report.dart';
import 'package:own_hub/features/progress/presentation/muscle_figure.dart';
import 'package:own_hub/features/progress/presentation/muscles_view.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';

final DateTime _today = DateTime(2026, 10, 17);

MuscleReport _week() => buildMuscleReport(
  log: const [
    (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 3),
    (dateKey: '2026-10-16', exerciseId: 'goblet_squat', sets: 3),
    (dateKey: '2026-10-14', exerciseId: 'step_back_lunge', sets: 3),
    (dateKey: '2026-10-14', exerciseId: 'dead_bug', sets: 3),
    (dateKey: '2026-10-01', exerciseId: 'bent_over_row', sets: 3),
  ],
  musclesOf: (id) => musclesFor(id, ExerciseLibrary.empty),
  today: _today,
);

Future<void> _pump(
  WidgetTester tester,
  MuscleReport report, {
  String lang = 'en',
  bool reducedMotion = false,
  FigureHits? hits,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(lang),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(disableAnimations: reducedMotion),
          child: MusclesView(report: report, hits: hits),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

MuscleFigureState _figure(WidgetTester tester) =>
    tester.state<MuscleFigureState>(find.byType(MuscleFigure));

Future<void> _tapSection(
  WidgetTester tester,
  FigureHits hits,
  MuscleSection section,
) async {
  final point = hits.pointOn(section);
  expect(point, isNotNull, reason: '${section.name} is not in view');
  final box = tester.renderObject<RenderBox>(
    find.byKey(const ValueKey('p06-figure')),
  );
  await tester.tapAt(box.localToGlobal(point!));
  await tester.pumpAndSettle();
}

void main() {
  group('the figure', () {
    test('one mesh, with every muscle group on it', () {
      final mesh = FigureMesh.instance;
      expect(identical(mesh, FigureMesh.instance), isTrue);
      expect(mesh.triangleCount, greaterThan(1000));
      expect(mesh.bias.length, mesh.triangleCount);
      expect(mesh.grooves.length, mesh.vertexCount);
      final parts = mesh.parts.toSet();
      for (final s in MuscleSection.values) {
        expect(parts, contains(s.index), reason: s.name);
      }
    });

    test('paints at any turn, and a frame says what is where', () {
      final hits = FigureHits();
      final yaw = ValueNotifier<double>(0);
      addTearDown(yaw.dispose);
      final painter = MuscleFigurePainter(
        yaw: yaw,
        scores: const {MuscleSection.glutes: 1, MuscleSection.chest: 0.4},
        hits: hits,
      );
      void paint() {
        final recorder = ui.PictureRecorder();
        painter.paint(Canvas(recorder), const Size(360, 400));
        recorder.endRecording().dispose();
      }

      paint();
      // Facing her: the front of the body is there to tap.
      for (final s in [
        MuscleSection.chest,
        MuscleSection.absAndSides,
        MuscleSection.frontOfThighs,
        MuscleSection.shoulders,
        MuscleSection.arms,
      ]) {
        expect(hits.pointOn(s), isNotNull, reason: 'front: ${s.name}');
      }
      expect(hits.pointOn(MuscleSection.glutes), isNull);
      expect(hits.sectionAt(Offset.zero), isNull);

      // Turned round: the back of it.
      yaw.value = 3.14159;
      paint();
      for (final s in [
        MuscleSection.glutes,
        MuscleSection.upperBack,
        MuscleSection.lowerBack,
        MuscleSection.backOfThighs,
        MuscleSection.calves,
      ]) {
        expect(hits.pointOn(s), isNotNull, reason: 'back: ${s.name}');
      }
      expect(hits.pointOn(MuscleSection.chest), isNull);

      // From the side, the inner and outer thighs.
      yaw.value = 1.5708;
      paint();
      expect(hits.pointOn(MuscleSection.innerAndOuterThighs), isNotNull);
    });

    test('untrained is linen; petrol only for the most trained', () {
      expect(MuscleHeat.of(0), MuscleHeat.untrained);
      expect(MuscleHeat.stepOf(0.1), 0);
      expect(MuscleHeat.stepOf(0.5), 1);
      expect(MuscleHeat.stepOf(0.8), 2);
      expect(MuscleHeat.stepOf(0.95), 3);
      expect(MuscleHeat.steps.last, isNot(MuscleHeat.of(0.85)));
    });
  });

  group('P06', () {
    testWidgets('renders her week: legend, most trained, balance, the list', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _week());
      expect(find.byType(MuscleFigure), findsOneWidget);
      expect(find.byKey(const ValueKey('p06-legend')), findsOneWidget);
      expect(find.text('More training · 9'), findsOneWidget);
      expect(
        find.textContaining('In sets: Glutes 9 · Front of thighs 6'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('p06-balance')), findsOneWidget);
      // Upper back, from the rows sixteen days ago.
      expect(find.byKey(const ValueKey('p06-resting')), findsOneWidget);
      expect(find.text('Last trained: 16 days ago'), findsWidgets);
      expect(find.byKey(const ValueKey('p06-empty')), findsNothing);
      for (final s in MuscleSection.values) {
        expect(find.byKey(ValueKey('p06-row-${s.name}')), findsOneWidget);
      }
      expect(
        find.bySemanticsLabel(RegExp(r'^Body map\. In sets: Glutes 9, ')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('a drag turns her, and keeps turning a little after', (
      tester,
    ) async {
      await _pump(tester, _week());
      expect(_figure(tester).yaw, closeTo(0, 1e-6));
      await tester.fling(
        find.byKey(const ValueKey('p06-figure')),
        const Offset(160, 0),
        900,
      );
      await tester.pump();
      final released = _figure(tester).yaw;
      expect(released, greaterThan(1.5));
      await tester.pumpAndSettle();
      expect(_figure(tester).yaw, greaterThan(released));
      // It comes to rest: nothing keeps ticking.
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('the toggle shows her back, then her front', (tester) async {
      await _pump(tester, _week());
      await tester.tap(find.text('See the back'));
      await tester.pumpAndSettle();
      expect(_figure(tester).yaw.abs(), closeTo(3.14159, 1e-3));
      expect(find.text('See the front'), findsOneWidget);
      await tester.tap(find.text('See the front'));
      await tester.pumpAndSettle();
      expect(_figure(tester).yaw.abs() % 6.28318, closeTo(0, 1e-3));
    });

    testWidgets('a tap on a part opens its card with its numbers', (
      tester,
    ) async {
      final hits = FigureHits();
      await _pump(tester, _week(), hits: hits);
      await _tapSection(tester, hits, MuscleSection.frontOfThighs);
      expect(find.byKey(const ValueKey('p06-part-card')), findsOneWidget);
      expect(find.text('Sets in 7 days: 6'), findsOneWidget);
      expect(find.text('Last trained: Yesterday'), findsOneWidget);

      // Turned round, the glutes.
      _figure(tester).turn(toBack: true);
      await tester.pumpAndSettle();
      await _tapSection(tester, hits, MuscleSection.glutes);
      expect(find.text('Sets in 7 days: 9'), findsOneWidget);

      // A row in the list opens the same card.
      await tester.ensureVisible(find.byKey(const ValueKey('p06-row-calves')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('p06-row-calves')));
      await tester.pumpAndSettle();
      expect(find.text('Sets in 7 days: 0'), findsOneWidget);
      expect(find.text('Not trained yet'), findsOneWidget);
    });

    testWidgets('30 days counts the month', (tester) async {
      await _pump(tester, _week());
      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle();
      Finder upperBack(String sets) => find.descendant(
        of: find.byKey(const ValueKey('p06-row-upperBack')),
        matching: find.text(sets),
      );
      expect(upperBack('3'), findsOneWidget);
      expect(find.byKey(const ValueKey('p06-resting')), findsOneWidget);
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(upperBack('0'), findsOneWidget);
    });

    testWidgets('reduced motion: a still front view, and no glide', (
      tester,
    ) async {
      await _pump(tester, _week(), reducedMotion: true);
      expect(_figure(tester).yaw, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.fling(
        find.byKey(const ValueKey('p06-figure')),
        const Offset(100, 0),
        1200,
      );
      await tester.pump();
      final released = _figure(tester).yaw;
      await tester.pump(const Duration(milliseconds: 500));
      expect(_figure(tester).yaw, released);
      // The toggle jumps rather than turns.
      await tester.tap(find.byKey(const ValueKey('p06-turn')));
      await tester.pump();
      expect(math.cos(_figure(tester).yaw), lessThan(0));
    });

    testWidgets('before her first log: what to do, and no noughts', (
      tester,
    ) async {
      await _pump(tester, MuscleReport.empty(_today));
      expect(
        find.text('Log your first workout and your muscles light up here.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('p06-legend')), findsNothing);
      expect(find.byKey(const ValueKey('p06-row-glutes')), findsNothing);
      expect(find.byType(MuscleFigure), findsOneWidget);
    });

    testWidgets('a week with nothing, a month with something', (tester) async {
      await _pump(
        tester,
        buildMuscleReport(
          log: const [
            (dateKey: '2026-10-05', exerciseId: 'calf_raise', sets: 3),
          ],
          musclesOf: (id) => musclesFor(id, ExerciseLibrary.empty),
          today: _today,
        ),
      );
      expect(find.text('No sets logged in the last 7 days.'), findsOneWidget);
      expect(find.byKey(const ValueKey('p06-resting')), findsOneWidget);
    });

    testWidgets('Arabic, right to left, the figure unmirrored', (tester) async {
      final english = FigureHits();
      await _pump(tester, _week(), hits: english);
      final chestInEnglish = english.pointOn(MuscleSection.chest);
      final hits = FigureHits();
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _week(), lang: 'ar', hits: hits);
      expect(
        Directionality.of(tester.element(find.byType(MusclesView))),
        TextDirection.rtl,
      );
      expect(find.text('عضلاتك'), findsWidgets);
      // The legend reads from the right: "Not yet" on the right-hand side.
      final notYet = tester.getCenter(find.textContaining('لسه ·'));
      final more = tester.getCenter(find.textContaining('تمرين أكتر ·'));
      expect(notYet.dx, greaterThan(more.dx));
      // The body is not mirrored: every part lands where it does in English.
      expect(hits.pointOn(MuscleSection.chest), chestInEnglish);
      // A drag to the right turns her the same way as in English.
      await tester.drag(
        find.byKey(const ValueKey('p06-figure')),
        const Offset(80, 0),
      );
      await tester.pump();
      expect(_figure(tester).yaw, greaterThan(0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
