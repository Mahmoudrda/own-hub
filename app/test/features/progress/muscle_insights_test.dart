// What P06 says about her map: the most trained, a group she has rested, and
// how the halves of her body compare. Facts with numbers, never a judgement.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart'
    show Equipment, LifeStage, TrainingPlace;
import 'package:own_hub/features/progress/domain/muscle_insights.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/progress/domain/muscle_report.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';

import '../../helpers/exercise_library_fixture.dart';

final DateTime _today = DateTime(2026, 10, 17);

MuscleReport _report(List<LoggedMove> log) => buildMuscleReport(
  log: log,
  musclesOf: (id) => musclesFor(id, ExerciseLibrary.empty),
  today: _today,
);

String _daysAgo(int days) {
  final d = _today.subtract(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

void main() {
  group('most trained', () {
    test('her top three in the window, most first, with their sets', () {
      final r = _report([
        (dateKey: _daysAgo(1), exerciseId: 'glute_bridge', sets: 6),
        (dateKey: _daysAgo(1), exerciseId: 'calf_raise', sets: 2),
        (dateKey: _daysAgo(2), exerciseId: 'push_up', sets: 4),
        (dateKey: _daysAgo(20), exerciseId: 'bent_over_row', sets: 30),
      ]);
      final week = mostTrained(r, MuscleWindow.week)!;
      // Glutes 6; abs 3 from the bridges and 2 from the push-ups; chest 4.
      expect(week.top.map((v) => v.section), [
        MuscleSection.glutes,
        MuscleSection.absAndSides,
        MuscleSection.chest,
      ]);
      expect(week.top.map((v) => v.sets), [6, 5, 4]);
      expect(week.top.first.sets, 6);
      // The month includes the rows from twenty days ago.
      expect(
        mostTrained(r, MuscleWindow.month)!.top.first.section,
        MuscleSection.upperBack,
      );
    });

    test('fewer than three when she trained fewer', () {
      final r = _report([
        (dateKey: _daysAgo(0), exerciseId: 'calf_raise', sets: 2),
      ]);
      expect(mostTrained(r, MuscleWindow.week)!.top, hasLength(1));
    });

    test('nothing when the window is empty', () {
      final r = _report([
        (dateKey: _daysAgo(12), exerciseId: 'calf_raise', sets: 2),
      ]);
      expect(mostTrained(r, MuscleWindow.week), isNull);
      expect(mostTrained(r, MuscleWindow.month), isNotNull);
      expect(
        mostTrained(MuscleReport.empty(_today), MuscleWindow.month),
        isNull,
      );
    });
  });

  group('not trained in a while', () {
    test('nine days is not yet a while; ten days is', () {
      final nine = _report([
        (dateKey: _daysAgo(9), exerciseId: 'calf_raise', sets: 3),
      ]);
      expect(restingSection(nine), isNull);

      final ten = _report([
        (dateKey: _daysAgo(10), exerciseId: 'calf_raise', sets: 3),
      ]);
      final resting = restingSection(ten)!;
      expect(resting.section, MuscleSection.calves);
      expect(resting.days, 10);
      expect(kRestingDays, 10);
    });

    test('read over all of her history, not the window', () {
      final r = _report([
        (dateKey: _daysAgo(45), exerciseId: 'push_up', sets: 3),
        (dateKey: _daysAgo(1), exerciseId: 'calf_raise', sets: 3),
      ]);
      // Chest is outside the 30 days, and still named: she has trained it.
      final resting = restingSection(r)!;
      expect(resting.section, MuscleSection.chest);
      expect(resting.days, 45);
    });

    test('a group she has never trained is not named', () {
      final r = _report([
        (dateKey: _daysAgo(1), exerciseId: 'calf_raise', sets: 3),
      ]);
      expect(restingSection(r), isNull);
    });

    test('the longest rested is the one named', () {
      final r = _report([
        (dateKey: _daysAgo(12), exerciseId: 'calf_raise', sets: 3),
        (dateKey: _daysAgo(20), exerciseId: 'lat_pulldown_wide', sets: 3),
      ]);
      expect(restingSection(r)!.section, MuscleSection.upperBack);
    });

    group('the moves it suggests', () {
      final library = ExerciseLibrary.parse({
        'version': 1,
        'exercises': [
          exerciseRow(
            'calf_a',
            primary: ['calves'],
            equipment: ['none'],
            tags: ['none'],
          ),
          exerciseRow(
            'calf_supine',
            primary: ['calves'],
            equipment: ['mat'],
            tags: ['supine_load'],
          ),
          exerciseRow(
            'calf_machine',
            primary: ['calves'],
            equipment: ['machine'],
            place: 'gym',
            tags: ['none'],
          ),
          exerciseRow(
            'calf_stretch',
            kind: 'stretch',
            primary: ['calves'],
            equipment: ['none'],
            tags: ['none'],
          ),
          exerciseRow(
            'calf_b',
            primary: ['calves'],
            equipment: ['dumbbells'],
            tags: ['none'],
          ),
          exerciseRow(
            'chest_a',
            primary: ['chest'],
            equipment: ['none'],
            tags: ['none'],
          ),
        ],
      })!;
      final rested = _report([
        (dateKey: _daysAgo(14), exerciseId: 'calf_raise', sets: 3),
      ]);

      test('strength moves for the group, at home with what she has', () {
        final r = restingSection(
          rested,
          library: library.exercises,
          place: TrainingPlace.home,
          equipment: {Equipment.mat},
        )!;
        expect(r.moves.map((e) => e.id), ['calf_a', 'calf_supine']);
      });

      test('at a gym, the machine too, and never more than three', () {
        final r = restingSection(
          rested,
          library: library.exercises,
          place: TrainingPlace.ladiesGym,
          equipment: {Equipment.none},
        )!;
        expect(r.moves, hasLength(3));
        expect(r.moves.map((e) => e.id), contains('calf_machine'));
        expect(r.moves.map((e) => e.id), isNot(contains('calf_stretch')));
      });

      test('pregnant: a move her life stage holds back is never suggested', () {
        final r = restingSection(
          rested,
          library: library.exercises,
          lifeStage: LifeStage.pregnant,
          place: TrainingPlace.home,
          equipment: {Equipment.mat, Equipment.dumbbells},
        )!;
        expect(r.moves.map((e) => e.id), ['calf_a', 'calf_b']);
      });

      test('no library on the phone yet: named, with no moves', () {
        final r = restingSection(rested)!;
        expect(r.section, MuscleSection.calves);
        expect(r.moves, isEmpty);
      });
    });
  });

  group('balance', () {
    test('lower body about twice the upper body', () {
      final r = _report([
        (dateKey: _daysAgo(1), exerciseId: 'bodyweight_squat', sets: 12),
        (dateKey: _daysAgo(1), exerciseId: 'wall_press_up', sets: 6),
      ]);
      final b = balance(r, MuscleWindow.week)!;
      expect(b.axis, BalanceAxis.upperLower);
      expect(b.first, 6);
      expect(b.second, 12);
      expect(b.more, BodyRegion.lower);
      expect(b.times, 2);
      expect(b.even, isFalse);
    });

    test('about the same is said as even, with both numbers', () {
      final r = _report([
        (dateKey: _daysAgo(1), exerciseId: 'bodyweight_squat', sets: 10),
        (dateKey: _daysAgo(1), exerciseId: 'bent_over_row', sets: 4),
        (dateKey: _daysAgo(1), exerciseId: 'machine_chest_press', sets: 5),
      ]);
      final b = balance(r, MuscleWindow.week)!;
      expect(b.axis, BalanceAxis.upperLower);
      expect(b.even, isTrue);
      expect(b.first, 9);
      expect(b.second, 10);
    });

    test('a little more, then rounded times', () {
      final little = _report([
        (dateKey: _daysAgo(1), exerciseId: 'bodyweight_squat', sets: 15),
        (dateKey: _daysAgo(1), exerciseId: 'push_up', sets: 10),
      ]);
      final b = balance(little, MuscleWindow.week)!;
      expect(b.axis, BalanceAxis.upperLower);
      expect(b.more, BodyRegion.lower);
      expect(b.times, 1);

      final three = _report([
        (dateKey: _daysAgo(1), exerciseId: 'bodyweight_squat', sets: 15),
        (dateKey: _daysAgo(1), exerciseId: 'wall_press_up', sets: 5),
      ]);
      expect(balance(three, MuscleWindow.week)!.times, 3);
    });

    test('everything to one half is 0 times, said as all of it', () {
      final r = _report([
        (dateKey: _daysAgo(1), exerciseId: 'calf_raise', sets: 6),
      ]);
      final b = balance(r, MuscleWindow.week)!;
      expect(b.times, 0);
      expect(b.even, isFalse);
    });

    test('the more uneven axis is the one said', () {
      // Upper and lower even; the back far ahead of the front.
      final r = _report([
        (dateKey: _daysAgo(1), exerciseId: 'seated_leg_curl', sets: 6),
        (dateKey: _daysAgo(1), exerciseId: 'lat_pulldown_wide', sets: 6),
      ]);
      final b = balance(r, MuscleWindow.week)!;
      expect(b.axis, BalanceAxis.frontBack);
      expect(b.more, BodyRegion.back);
    });

    test('nothing to compare without a whole set', () {
      expect(balance(MuscleReport.empty(_today), MuscleWindow.week), isNull);
    });
  });
}
