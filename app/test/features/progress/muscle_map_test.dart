// Every move a session can hold has muscles, even before the phone has the
// exercise library: otherwise a set she logged would light up nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/exercise_metrics.dart';

Set<String> _programmeIds() {
  final json = jsonDecode(
    File('assets/content/starting_programmes.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final p in (json['programmes']! as List).cast<Map<String, Object?>>())
      for (final s in (p['sessions']! as List).cast<Map<String, Object?>>())
        for (final m in (s['moves']! as List).cast<Map<String, Object?>>())
          m['exerciseId']! as String,
  };
}

List<Map<String, Object?>> _catalogue() {
  final json = jsonDecode(
    File('../6-v2/content/exercise_library/catalogue.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return (json['exercises']! as List).cast<Map<String, Object?>>();
}

void main() {
  test('every programme and seed move resolves with no library at all', () {
    final ids = {
      ..._programmeIds(),
      // The seed day, the demo and the moves bests are measured on.
      ...bundledExerciseMetrics.keys,
      'box_squat',
    };
    expect(ids.length, greaterThan(40));
    final missing = [
      for (final id in ids)
        if ((musclesFor(id, ExerciseLibrary.empty)?.primary ?? const [])
            .isEmpty)
          id,
    ];
    expect(missing, isEmpty, reason: 'no muscles for: ${missing.join(', ')}');
  });

  test('every catalogue move has muscles, and the table agrees with it', () {
    final rows = _catalogue();
    expect(rows, isNotEmpty);
    for (final row in rows) {
      final id = row['exerciseId']! as String;
      final primary = [
        for (final w in (row['primaryMuscles']! as List)) Muscle.fromWire(w)!,
      ];
      final secondary = [
        for (final w in (row['secondaryMuscles'] as List? ?? const []))
          Muscle.fromWire(w)!,
      ];
      expect(primary, isNotEmpty, reason: id);
      final bundled = bundledExerciseMuscles[id];
      if (bundled == null) continue;
      expect(bundled.primary, primary, reason: '$id primary');
      expect(bundled.secondary, secondary, reason: '$id secondary');
      expect(bundled.stretch, row['kind'] == 'stretch', reason: '$id kind');
    }
  });

  test('a glute bridge works the glutes first and the hamstrings second', () {
    final bridge = bundledExerciseMuscles['glute_bridge']!;
    expect(bridge.primary, [Muscle.glutes]);
    expect(bridge.secondary, contains(Muscle.hamstrings));
    expect(bridge.sectionWeights[MuscleSection.glutes], 1);
    expect(bridge.sectionWeights[MuscleSection.backOfThighs], 0.5);
  });

  test('no move lists one muscle as both primary and secondary', () {
    for (final MapEntry(key: id, value: m) in bundledExerciseMuscles.entries) {
      expect(m.primary.where(m.secondary.contains), isEmpty, reason: id);
    }
  });
}
