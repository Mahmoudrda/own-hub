// P06 "Your muscles": the map draws front and back, colours a muscle only by
// the sets where it did the work, answers a tap with that muscle's numbers,
// stands still under reduced motion, says what to do before the first log,
// reads right to left in Arabic without mirroring the body, and holds at
// large text.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/progress/domain/muscle_report.dart';
import 'package:own_hub/features/progress/presentation/muscle_figure.dart';
import 'package:own_hub/features/progress/presentation/muscle_map_art.dart';
import 'package:own_hub/features/progress/presentation/muscles_view.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _today = DateTime(2026, 10, 17);

MuscleReport _report(
  List<LoggedMove> log, {
  ExerciseMuscles? Function(String id)? musclesOf,
}) => buildMuscleReport(
  log: log,
  musclesOf: musclesOf ?? (id) => musclesFor(id, ExerciseLibrary.empty),
  today: _today,
);

MuscleReport _week() => _report(const [
  (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 3),
  (dateKey: '2026-10-16', exerciseId: 'goblet_squat', sets: 3),
  (dateKey: '2026-10-14', exerciseId: 'step_back_lunge', sets: 3),
  (dateKey: '2026-10-14', exerciseId: 'dead_bug', sets: 3),
  (dateKey: '2026-10-01', exerciseId: 'bent_over_row', sets: 3),
]);

Future<void> _pump(
  WidgetTester tester,
  MuscleReport report, {
  String lang = 'en',
  bool reducedMotion = false,
  double textScale = 1,
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
          data: MediaQuery.of(context).copyWith(
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MusclesView(report: report),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final Finder _figure = find.byKey(const ValueKey('p06-figure'));

MuscleMapPainter _painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(MuscleFigure),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as MuscleMapPainter;

/// The fill each drawn shape gets on the screen as it stands.
Map<MuscleArea, Color> _fills(WidgetTester tester) {
  final scores = _painter(tester).scores;
  return {
    for (final list in MuscleMapArt.areas.values)
      for (final area in list) area: MuscleHeat.fillFor(area, scores),
  };
}

Future<void> _tapMuscle(
  WidgetTester tester,
  Muscle muscle, {
  BodyView? view,
}) async {
  await tester.ensureVisible(_figure);
  await tester.pumpAndSettle();
  final box = tester.renderObject<RenderBox>(_figure);
  final point = MuscleMapLayout(box.size).pointOn(muscle, view: view);
  expect(point, isNotNull, reason: '${muscle.name} is not drawn');
  await tester.tapAt(box.localToGlobal(point!));
  await tester.pumpAndSettle();
}

void main() {
  group('P06', () {
    testWidgets('renders her week: legend, most trained, balance, the list', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _week());
      expect(find.byType(MuscleFigure), findsOneWidget);
      expect(find.text('Front view'), findsOneWidget);
      expect(find.text('Back view'), findsOneWidget);
      expect(find.text('Tap a muscle for its sets.'), findsOneWidget);
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
      // The figure is read out muscle by muscle, the sets beside each.
      expect(
        find.bySemanticsLabel(
          'Body map. In sets: Glutes 9, Front of thighs 6, Core 3',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('her most trained muscle is petrol, the untrained grey', (
      tester,
    ) async {
      await _pump(tester, _week());
      final fills = _fills(tester);
      for (final MapEntry(key: area, value: fill) in fills.entries) {
        switch (area.muscle) {
          case Muscle.glutes:
            expect(fill, AppColors.primary, reason: area.id);
          case Muscle.quads:
          case Muscle.core:
            expect(fill, isNot(MuscleHeat.untrained), reason: area.id);
          default:
            expect(fill, MuscleHeat.untrained, reason: area.id);
        }
      }
    });

    testWidgets('a tap on a muscle opens its card with its numbers', (
      tester,
    ) async {
      await _pump(tester, _week());
      await _tapMuscle(tester, Muscle.quads, view: BodyView.front);
      expect(find.byKey(const ValueKey('p06-part-card')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('p06-part-card')),
          matching: find.text('Front of thighs'),
        ),
        findsOneWidget,
      );
      expect(find.text('Sets in 7 days: 6'), findsOneWidget);
      expect(find.text('Last trained: Yesterday'), findsOneWidget);
      expect(_painter(tester).selected, {Muscle.quads});

      // The glutes, on her back.
      await _tapMuscle(tester, Muscle.glutes, view: BodyView.back);
      expect(_painter(tester).selected, {Muscle.glutes});
      expect(find.text('Sets in 7 days: 9'), findsOneWidget);

      // The same muscle again lets it go.
      await _tapMuscle(tester, Muscle.glutes, view: BodyView.back);
      expect(find.byKey(const ValueKey('p06-part-card')), findsNothing);
      expect(_painter(tester).selected, isEmpty);

      // A row in the list opens its group, and rings every muscle in it.
      await tester.ensureVisible(find.byKey(const ValueKey('p06-row-calves')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('p06-row-calves')));
      await tester.pumpAndSettle();
      expect(find.text('Sets in 7 days: 0'), findsOneWidget);
      expect(find.text('Not trained yet'), findsOneWidget);
      expect(_painter(tester).selected, {Muscle.calves});
    });

    testWidgets('a muscle that only helped stays grey, and its card says so', (
      tester,
    ) async {
      await _pump(tester, _week());
      // The bridges and lunges list the hamstrings as helping, six sets.
      for (final MapEntry(key: area, value: fill) in _fills(tester).entries) {
        if (area.muscle == Muscle.hamstrings) {
          expect(fill, MuscleHeat.untrained, reason: area.id);
        }
      }
      await _tapMuscle(tester, Muscle.hamstrings);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('p06-part-card')),
          matching: find.text('Back of thighs'),
        ),
        findsOneWidget,
      );
      expect(find.text('Sets in 7 days: 0'), findsOneWidget);
      expect(find.text('Also worked: 6 sets'), findsOneWidget);
      expect(find.text('Not trained yet'), findsOneWidget);
    });

    testWidgets('glutes alone: only the glutes light up', (tester) async {
      await _pump(
        tester,
        _report(const [
          (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 4),
          (dateKey: '2026-10-15', exerciseId: 'donkey_kick', sets: 3),
        ], musclesOf: (id) => bundledExerciseMuscles[id]),
      );
      expect(_painter(tester).scores, {Muscle.glutes: 1.0});
      for (final MapEntry(key: area, value: fill) in _fills(tester).entries) {
        expect(
          fill,
          area.muscle == Muscle.glutes
              ? AppColors.primary
              : MuscleHeat.untrained,
          reason: area.id,
        );
      }
    });

    testWidgets('curls light the biceps, never the triceps or forearms', (
      tester,
    ) async {
      await _pump(
        tester,
        _report(
          const [(dateKey: '2026-10-16', exerciseId: 'curl', sets: 4)],
          musclesOf: (id) => const ExerciseMuscles(
            primary: [Muscle.biceps],
            secondary: [Muscle.forearms],
          ),
        ),
      );
      for (final MapEntry(key: area, value: fill) in _fills(tester).entries) {
        if (area.muscle == Muscle.biceps) {
          expect(fill, AppColors.primary, reason: area.id);
        } else {
          expect(fill, MuscleHeat.untrained, reason: area.id);
        }
      }
      await _tapMuscle(tester, Muscle.forearms, view: BodyView.front);
      expect(find.text('Also worked: 4 sets'), findsOneWidget);
      await _tapMuscle(tester, Muscle.triceps, view: BodyView.back);
      expect(find.text('Sets in 7 days: 0'), findsOneWidget);
      expect(find.byKey(const ValueKey('p06-also-worked')), findsNothing);
    });

    testWidgets('a tap off every muscle chooses nothing', (tester) async {
      await _pump(tester, _week());
      await _tapMuscle(tester, Muscle.glutes, view: BodyView.back);
      expect(find.byKey(const ValueKey('p06-part-card')), findsOneWidget);
      final box = tester.renderObject<RenderBox>(_figure);
      // The page beside her, then the shin, which nothing she logs trains.
      await tester.tapAt(box.localToGlobal(const Offset(2, 2)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p06-part-card')), findsNothing);
      final layout = MuscleMapLayout(box.size);
      final shin = MuscleMapArt.areas[BodyView.front]!.firstWhere(
        (a) => a.id == 'shin.r',
      );
      await tester.tapAt(box.localToGlobal(layout.pointIn(shin)!));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('p06-part-card')), findsNothing);
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
      expect(_painter(tester).scores.keys, contains(Muscle.lats));
      await tester.tap(find.text('7 days'));
      await tester.pumpAndSettle();
      expect(upperBack('0'), findsOneWidget);
      expect(_painter(tester).scores.keys, isNot(contains(Muscle.lats)));
    });

    testWidgets('reduced motion: the same still map, nothing ticking', (
      tester,
    ) async {
      await _pump(tester, _week(), reducedMotion: true);
      expect(find.byType(MuscleFigure), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
      await _tapMuscle(tester, Muscle.glutes);
      expect(find.text('Sets in 7 days: 9'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('before her first log: what to do, and no noughts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, MuscleReport.empty(_today));
      expect(
        find.text('Log your first workout and your muscles light up here.'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('p06-legend')), findsNothing);
      expect(find.byKey(const ValueKey('p06-row-glutes')), findsNothing);
      expect(find.byType(MuscleFigure), findsOneWidget);
      expect(_painter(tester).scores, isEmpty);
      expect(
        find.bySemanticsLabel('Body map. In sets: Not trained yet'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a week with nothing, a month with something', (tester) async {
      await _pump(
        tester,
        _report(const [
          (dateKey: '2026-10-05', exerciseId: 'calf_raise', sets: 3),
        ]),
      );
      expect(find.text('No sets logged in the last 7 days.'), findsOneWidget);
      expect(find.byKey(const ValueKey('p06-resting')), findsOneWidget);
    });

    testWidgets('Arabic, right to left, the body unmirrored', (tester) async {
      await _pump(tester, _week());
      final englishSize = tester.renderObject<RenderBox>(_figure).size;
      final englishFront = tester.getCenter(
        find.byKey(const ValueKey('p06-front-label')),
      );
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, _week(), lang: 'ar');
      expect(
        Directionality.of(tester.element(find.byType(MusclesView))),
        TextDirection.rtl,
      );
      expect(find.text('عضلاتك'), findsWidgets);
      // The legend reads from the right: "Not yet" on the right-hand side.
      final notYet = tester.getCenter(find.textContaining('لسه ·'));
      final more = tester.getCenter(find.textContaining('تمرين أكتر ·'));
      expect(notYet.dx, greaterThan(more.dx));
      // The front stays on the left, under the front of the body.
      final front = tester.getCenter(
        find.byKey(const ValueKey('p06-front-label')),
      );
      final back = tester.getCenter(
        find.byKey(const ValueKey('p06-back-label')),
      );
      expect(front.dx, lessThan(back.dx));
      expect(front.dx, closeTo(englishFront.dx, 0.01));
      expect(find.text('من قدّام'), findsOneWidget);
      expect(find.text('من ورا'), findsOneWidget);
      // Every muscle sits where it does in English: a tap on the chest's
      // place opens the chest.
      final box = tester.renderObject<RenderBox>(_figure);
      expect(box.size, englishSize);
      await _tapMuscle(tester, Muscle.chest, view: BodyView.front);
      expect(_painter(tester).selected, {Muscle.chest});
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('p06-part-card')),
          matching: find.text('الصدر'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('large text: the labels and the card grow, nothing breaks', (
      tester,
    ) async {
      await _pump(tester, _week(), textScale: 2);
      expect(tester.takeException(), isNull);
      expect(find.text('Front view'), findsOneWidget);
      // The figure keeps its width; the words under it wrap if they must.
      final box = tester.renderObject<RenderBox>(_figure);
      expect(box.size.width, greaterThan(300));
      await _tapMuscle(tester, Muscle.hamstrings);
      expect(find.text('Also worked: 6 sets'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
