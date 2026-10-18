// Every move Train can show has a filmed clip in the exercise catalogue, and
// every clip file is named for the move it plays.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';

Map<String, Map<String, dynamic>> _catalogue() {
  final file = File('../6-v2/content/exercise_library/catalogue.json');
  final rows =
      (jsonDecode(file.readAsStringSync()) as Map)['exercises'] as List;
  return {
    for (final row in rows.cast<Map<String, dynamic>>())
      row['exerciseId'] as String: row,
  };
}

List<dynamic> _clips(Map<String, dynamic>? row) =>
    (row?['clips'] as List?) ?? const [];

void main() {
  final catalogue = _catalogue();

  test('every clip file starts with its own exercise id', () {
    for (final entry in catalogue.entries) {
      for (final clip in _clips(entry.value).cast<Map<String, dynamic>>()) {
        final name = clip['file'] as String;
        expect(
          name.startsWith('${entry.key}_'),
          isTrue,
          reason: '${entry.key} names $name',
        );
      }
    }
  });

  test('every programme move has a filmed clip', () {
    final file = File('assets/content/starting_programmes.json');
    final programmes =
        (jsonDecode(file.readAsStringSync()) as Map)['programmes'] as List;
    var checked = 0;
    for (final programme in programmes.cast<Map<String, dynamic>>()) {
      for (final session
          in (programme['sessions'] as List).cast<Map<String, dynamic>>()) {
        for (final move
            in (session['moves'] as List).cast<Map<String, dynamic>>()) {
          final id = move['exerciseId'] as String;
          checked++;
          expect(
            _clips(catalogue[id]),
            isNotEmpty,
            reason: '${programme['programId']} ${session['sessionId']}: $id',
          );
        }
      }
    }
    expect(checked, greaterThan(0));
  });

  test('day one and the bundled library only use filmed moves', () {
    final l10n = AppL10nEn();
    final day = sampleWorkoutDay(l10n);
    final ids = {
      for (final move in day.moves) move.exerciseId,
      for (final move in day.moves)
        for (final set in move.sets) set.exerciseId,
    };
    expect(ids, isNotEmpty);
    for (final id in ids) {
      expect(_clips(catalogue[id]), isNotEmpty, reason: 'day one: $id');
    }
    for (final workout in sampleWorkoutLibrary(l10n)) {
      expect(workout.id, day.id);
      expect(workout.exerciseIds, isNotEmpty);
      for (final id in workout.exerciseIds) {
        expect(_clips(catalogue[id]), isNotEmpty, reason: 'library row: $id');
      }
    }
  });
}
