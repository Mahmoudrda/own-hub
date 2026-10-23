// P06's body map art: every muscle she can train is drawn, every shape is
// coloured by its own muscle or by nothing, a tap lands on the shape under
// it, and the shapes nothing trains stay grey whatever she logs.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/progress/presentation/muscle_map_art.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/theme/body_map_tokens.dart';

List<MuscleArea> get _all => [
  for (final list in MuscleMapArt.areas.values) ...list,
];

const Size _phone = Size(328, 360.8);

void main() {
  test('every muscle she can train is drawn, and shows', () {
    const layout = MuscleMapLayout(_phone);
    for (final muscle in Muscle.values) {
      final areas = _all.where((a) => a.muscle == muscle).toList();
      expect(areas, isNotEmpty, reason: '${muscle.name} is not drawn');
      expect(
        layout.pointOn(muscle),
        isNotNull,
        reason: '${muscle.name} is drawn but hidden',
      );
    }
  });

  test('every shape is a muscle, or one of the few nothing trains', () {
    for (final area in _all) {
      final name = area.id.split('.').first;
      if (MuscleMapArt.untrainable.contains(name)) {
        expect(area.muscle, isNull, reason: area.id);
      } else {
        expect(Muscle.values, contains(area.muscle), reason: area.id);
      }
    }
    // The hip flexors and the shins are drawn, never filed under another
    // muscle.
    for (final name in ['hipFlexors', 'shin', 'neck', 'serratus']) {
      final drawn = _all.where((a) => a.id.startsWith('$name.')).toList();
      expect(drawn, hasLength(2), reason: name);
      expect(drawn.every((a) => a.muscle == null), isTrue, reason: name);
    }
  });

  test('every shape shows, in mirrored pairs, both sides of the body', () {
    const layout = MuscleMapLayout(_phone);
    for (final area in _all) {
      final point = layout.pointIn(area);
      expect(point, isNotNull, reason: '${area.id} is hidden');
      expect(layout.areaAt(point!), area, reason: area.id);
      final side = layout.toArt(area.view, point).dx;
      expect(side < 50, !area.mirrored, reason: area.id);
    }
  });

  test('a tap on the glutes lands on the glutes, on the back view', () {
    const layout = MuscleMapLayout(_phone);
    final point = layout.pointOn(Muscle.glutes)!;
    final area = layout.areaAt(point)!;
    expect(area.muscle, Muscle.glutes);
    expect(area.view, BodyView.back);
    expect(point.dx, greaterThan(_phone.width / 2));
    // Beside her, and on her hair, there is nothing to choose.
    expect(layout.areaAt(const Offset(1, 1)), isNull);
    final bun = layout.fromArt(BodyView.front, const Offset(50, 4.8));
    expect(layout.areaAt(bun), isNull);
  });

  test('front on the left, back on the right, at any width', () {
    for (final size in const [Size(328, 360.8), Size(600, 500)]) {
      final layout = MuscleMapLayout(size);
      expect(
        layout.originOf(BodyView.front).dx,
        lessThan(layout.originOf(BodyView.back).dx),
      );
      final chest = layout.pointOn(Muscle.chest)!;
      final glutes = layout.pointOn(Muscle.glutes)!;
      expect(chest.dx, lessThan(size.width / 2));
      expect(glutes.dx, greaterThan(size.width / 2));
    }
  });

  test('untrained is the grey of the body', () {
    expect(MuscleHeat.untrained, BodyMapInk.body);
    for (final area in _all) {
      expect(MuscleHeat.fillFor(area, const {}), BodyMapInk.body);
    }
    expect(MuscleHeat.of(0), MuscleHeat.untrained);
  });

  test('pinks up the scale, petrol only for her most trained', () {
    expect(MuscleHeat.steps, [
      AppColors.pinkSoft,
      AppColors.brandPink,
      AppColors.pinkDeep,
      AppColors.primary,
    ]);
    expect(MuscleHeat.stepOf(0.1), 0);
    expect(MuscleHeat.stepOf(0.5), 1);
    expect(MuscleHeat.stepOf(0.8), 2);
    expect(MuscleHeat.stepOf(0.95), 3);
    expect(MuscleHeat.of(1), AppColors.primary);
    expect(MuscleHeat.of(0.85), isNot(AppColors.primary));
  });

  test('a shape is coloured by its own muscle and no other', () {
    const scores = {Muscle.biceps: 1.0, Muscle.glutes: 0.5};
    for (final area in _all) {
      final fill = MuscleHeat.fillFor(area, scores);
      switch (area.muscle) {
        case Muscle.biceps:
          expect(fill, AppColors.primary, reason: area.id);
        case Muscle.glutes:
          expect(fill, AppColors.brandPink, reason: area.id);
        default:
          expect(fill, MuscleHeat.untrained, reason: area.id);
      }
    }
  });

  test('the shapes nothing trains stay grey even when all else is top', () {
    final everything = {for (final m in Muscle.values) m: 1.0};
    final grey = _all.where((a) => a.muscle == null).toList();
    expect(grey, isNotEmpty);
    for (final area in grey) {
      expect(MuscleHeat.fillFor(area, everything), MuscleHeat.untrained);
    }
  });

  test('paints at a phone and a tablet width, with and without a choice', () {
    for (final size in const [Size(328, 360.8), Size(700, 418)]) {
      for (final selected in const [
        <Muscle>{},
        {Muscle.glutes},
      ]) {
        final recorder = ui.PictureRecorder();
        MuscleMapPainter(
          scores: const {Muscle.glutes: 1, Muscle.chest: 0.3},
          selected: selected,
        ).paint(Canvas(recorder), size);
        recorder.endRecording().dispose();
      }
    }
    final a = MuscleMapPainter(scores: const {Muscle.glutes: 1});
    expect(
      a.shouldRepaint(MuscleMapPainter(scores: const {Muscle.glutes: 1})),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        MuscleMapPainter(
          scores: const {Muscle.glutes: 1},
          selected: const {Muscle.glutes},
        ),
      ),
      isTrue,
    );
  });
}
