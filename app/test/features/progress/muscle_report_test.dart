// P06's numbers: how a logged set becomes sets per muscle group, over which
// days, and when each group was last trained.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/domain/muscle_map.dart';
import 'package:own_hub/features/progress/domain/muscle_report.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

final DateTime _today = DateTime(2026, 10, 17, 21, 40);

ExerciseMuscles? _bundled(String id) => musclesFor(id, ExerciseLibrary.empty);

MuscleReport _report(List<LoggedMove> log) =>
    buildMuscleReport(log: log, musclesOf: _bundled, today: _today);

LoggedSet _set(String id, {int? reps = 10, bool skipped = false}) => LoggedSet(
  prescribed: PrescribedSet(exerciseId: id, order: 1, reps: 10),
  outcome: skipped ? const SetOutcome.skipped() : SetOutcome(reps: reps),
);

void main() {
  group(
    'a set counts in full where the move works, and half where it helps',
    () {
      test('glute bridge: glutes 1, back of thighs and abs 0.5 a set', () {
        final r = _report(const [
          (dateKey: '2026-10-17', exerciseId: 'glute_bridge', sets: 3),
        ]);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.glutes), 3);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.backOfThighs), 1.5);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.absAndSides), 1.5);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.chest), 0);
      });

      test('two muscles in one group count once, at the higher weight', () {
        // A row works the lats and the upper back, both "upper back"; and its
        // helpers, the rear shoulder and the biceps, are in two other groups.
        final r = _report(const [
          (dateKey: '2026-10-17', exerciseId: 'bent_over_row', sets: 4),
        ]);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.upperBack), 4);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.shoulders), 2);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.arms), 2);

        // A dead bug: core primary and obliques helping, both abs and sides.
        final bug = _report(const [
          (dateKey: '2026-10-17', exerciseId: 'dead_bug', sets: 2),
        ]);
        expect(bug.setsIn(MuscleWindow.week, MuscleSection.absAndSides), 2);
      });

      test('a stretch adds nothing, and an unknown move adds nothing', () {
        final r = _report(const [
          (dateKey: '2026-10-17', exerciseId: 'wall_chest_stretch', sets: 2),
          (dateKey: '2026-10-17', exerciseId: 'no_such_move', sets: 5),
        ]);
        expect(r.hasAnyLog, isFalse);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.chest), 0);
      });

      test('the library row is used when the phone holds one', () {
        final library = ExerciseLibrary(
          version: 1,
          exercises: [
            LibraryExercise(
              id: 'glute_bridge',
              nameEn: 'Glute bridge',
              nameAr: 'جلوت بريدج',
              kind: ExerciseKind.strength,
              primaryMuscles: const [Muscle.glutes, Muscle.hamstrings],
              bodyRegion: 'lower_body',
              pattern: 'hip_thrust_bridge',
              equipment: const [LibraryEquipment.mat],
              place: ExercisePlace.both,
              level: ExerciseLevel.beginner,
              quiet: true,
              floorOnly: true,
              tags: const {},
              clips: const [],
              poster: const ExerciseMedia(path: 'p', bytes: 1),
            ),
          ],
        );
        final r = buildMuscleReport(
          log: const [
            (dateKey: '2026-10-17', exerciseId: 'glute_bridge', sets: 2),
          ],
          musclesOf: (id) => musclesFor(id, library),
          today: _today,
        );
        expect(r.setsIn(MuscleWindow.week, MuscleSection.backOfThighs), 2);
        expect(r.setsIn(MuscleWindow.week, MuscleSection.absAndSides), 0);
      });
    },
  );

  group('the windows', () {
    test('7 days is today and the six before it; 30 days likewise', () {
      final r = _report(const [
        (dateKey: '2026-10-17', exerciseId: 'calf_raise', sets: 1),
        (dateKey: '2026-10-11', exerciseId: 'calf_raise', sets: 2),
        (dateKey: '2026-10-10', exerciseId: 'calf_raise', sets: 4),
        (dateKey: '2026-09-18', exerciseId: 'calf_raise', sets: 8),
        (dateKey: '2026-09-17', exerciseId: 'calf_raise', sets: 16),
      ]);
      expect(r.setsIn(MuscleWindow.week, MuscleSection.calves), 3);
      expect(r.setsIn(MuscleWindow.month, MuscleSection.calves), 15);
    });

    test('a day after today, or a key that is not a date, is left out', () {
      final r = _report(const [
        (dateKey: '2026-10-18', exerciseId: 'calf_raise', sets: 3),
        (dateKey: 'day-2', exerciseId: 'calf_raise', sets: 3),
      ]);
      expect(r.hasAnyLog, isFalse);
    });

    test('the score is relative to her own most trained group', () {
      final r = _report(const [
        (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 4),
        (dateKey: '2026-10-16', exerciseId: 'calf_raise', sets: 1),
      ]);
      expect(r.maxIn(MuscleWindow.week), 4);
      expect(r.score(MuscleWindow.week, MuscleSection.glutes), 1);
      expect(r.score(MuscleWindow.week, MuscleSection.calves), 0.25);
      expect(r.score(MuscleWindow.week, MuscleSection.chest), 0);
      final ranked = r.ranked(MuscleWindow.week);
      expect(ranked.first.section, MuscleSection.glutes);
      expect(ranked.length, MuscleSection.values.length);
    });
  });

  group('last trained', () {
    test('the latest day with a set, over all of her history', () {
      final r = _report(const [
        (dateKey: '2026-08-01', exerciseId: 'push_up', sets: 3),
        (dateKey: '2026-10-14', exerciseId: 'push_up', sets: 3),
        (dateKey: '2026-10-03', exerciseId: 'push_up', sets: 3),
      ]);
      expect(r.lastTrained(MuscleSection.chest), DateTime.utc(2026, 10, 14));
      expect(r.daysSince(MuscleSection.chest), 3);
      expect(r.daysSince(MuscleSection.calves), isNull);
    });

    test('a helping muscle counts as trained that day', () {
      final r = _report(const [
        (dateKey: '2026-10-17', exerciseId: 'push_up', sets: 1),
      ]);
      expect(r.daysSince(MuscleSection.arms), 0);
    });
  });

  group('upper, lower, front and back', () {
    test('per set, at most once per half', () {
      // Squat: quads and glutes, both lower; one set is one lower set.
      final r = _report(const [
        (dateKey: '2026-10-17', exerciseId: 'bodyweight_squat', sets: 10),
      ]);
      expect(r.regionSets(MuscleWindow.week, BodyRegion.lower), 10);
      expect(r.regionSets(MuscleWindow.week, BodyRegion.upper), 0);
      // Quads are the front, glutes the back: both get the set.
      expect(r.regionSets(MuscleWindow.week, BodyRegion.front), 10);
      expect(r.regionSets(MuscleWindow.week, BodyRegion.back), 10);
    });

    test('the trunk is neither upper nor lower body', () {
      for (final m in [Muscle.core, Muscle.obliques, Muscle.lowerBack]) {
        final halves = regionsOf(m);
        expect(halves.contains(BodyRegion.upper), isFalse, reason: m.name);
        expect(halves.contains(BodyRegion.lower), isFalse, reason: m.name);
      }
      final r = _report(const [
        (dateKey: '2026-10-17', exerciseId: 'dead_bug', sets: 3),
      ]);
      expect(r.regionSets(MuscleWindow.week, BodyRegion.upper), 0);
      expect(r.regionSets(MuscleWindow.week, BodyRegion.lower), 0);
      expect(r.regionSets(MuscleWindow.week, BodyRegion.front), 3);
    });

    test('front and back are read from the muscle, not the group', () {
      expect(regionsOf(Muscle.frontDelts), contains(BodyRegion.front));
      expect(regionsOf(Muscle.rearDelts), contains(BodyRegion.back));
      expect(regionsOf(Muscle.biceps), contains(BodyRegion.front));
      expect(regionsOf(Muscle.triceps), contains(BodyRegion.back));
    });
  });

  group('her log, read from the phone', () {
    test('flushed sets on the session day; skipped and live prescriptions '
        'never count; a recalled session counts its own sets', () async {
      final repo = InMemoryTrainRepository();
      final live = await repo.startSession(
        WorkoutDay(
          id: '2026-10-16',
          title: 't',
          summary: 's',
          constraints: 'c',
          moves: [
            PlannedMove(
              exerciseId: 'glute_bridge',
              name: 'Glute bridge',
              prescriptionLabel: '3 × 10',
              sets: [
                for (var i = 1; i <= 3; i++)
                  PrescribedSet(exerciseId: 'glute_bridge', order: i, reps: 10),
              ],
            ),
          ],
        ),
      );
      await repo.flushMove(
        sessionId: live.id,
        exerciseId: 'glute_bridge',
        sets: [
          _set('glute_bridge'),
          _set('glute_bridge'),
          _set('glute_bridge', skipped: true),
        ],
      );
      await repo.finishSession(sessionId: live.id, durationSec: 600);
      // A flush under an id no session was started with: attributed to no
      // day, so it counts nowhere.
      await repo.flushMove(
        sessionId: 'session',
        exerciseId: 'calf_raise',
        sets: [_set('calf_raise')],
      );
      await repo.logRecalled(
        dateKey: '2026-10-12',
        method: RecallMethod.history,
        sets: [_set('push_up'), _set('push_up'), _set('calf_raise')],
      );

      final log = loggedMovesFrom(repo);
      expect(log, hasLength(3));
      expect(
        log,
        contains((dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 2)),
      );
      expect(
        log,
        contains((dateKey: '2026-10-12', exerciseId: 'push_up', sets: 2)),
      );
      final r = _report(log);
      expect(r.setsIn(MuscleWindow.week, MuscleSection.glutes), 2);
      expect(r.setsIn(MuscleWindow.week, MuscleSection.chest), 2);
      expect(r.setsIn(MuscleWindow.week, MuscleSection.calves), 1);
    });
  });

  test('sets are written with Western digits and halves', () {
    expect(setsLabel(0), '0');
    expect(setsLabel(9), '9');
    expect(setsLabel(7.5), '7.5');
    expect(setsLabel(0.5), '0.5');
    expect(setsLabel(1250), '1,250');
  });

  test('an empty report has nothing in any window', () {
    final r = MuscleReport.empty(_today);
    expect(r.hasAnyLog, isFalse);
    for (final w in MuscleWindow.values) {
      expect(r.hasSetsIn(w), isFalse);
      expect(r.maxIn(w), 0);
      expect(r.muscleMaxIn(w), 0);
      expect(r.rankedMuscles(w), isEmpty);
    }
    expect(r.lastWorked(Muscle.glutes), isNull);
  });

  group('per muscle: only where it did the work', () {
    test('a glute bridge works the glutes; the helpers are kept apart', () {
      final r = _report(const [
        (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 3),
      ]);
      const w = MuscleWindow.week;
      expect(r.workedSets(w, Muscle.glutes), 3);
      for (final m in Muscle.values) {
        if (m == Muscle.glutes) continue;
        expect(r.workedSets(w, m), 0, reason: m.name);
        expect(r.muscleScore(w, m), 0, reason: m.name);
      }
      // Whole sets, not halves, where a muscle only helped.
      expect(r.helpedSets(w, Muscle.hamstrings), 3);
      expect(r.helpedSets(w, Muscle.core), 3);
      expect(r.helpedSets(w, Muscle.glutes), 0);
      expect(r.muscleScore(w, Muscle.glutes), 1);
      expect(r.lastWorked(Muscle.glutes), DateTime.utc(2026, 10, 16));
      expect(r.daysSinceWorked(Muscle.glutes), 1);
      expect(r.lastWorked(Muscle.hamstrings), isNull);
      // The groups still count the helpers at half a set.
      expect(r.setsIn(w, MuscleSection.backOfThighs), 1.5);
    });

    test('glutes never light the hips or the inner thighs', () {
      final r = _report(const [
        (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 3),
        (dateKey: '2026-10-16', exerciseId: 'donkey_kick', sets: 3),
      ]);
      const w = MuscleWindow.week;
      expect(r.workedSets(w, Muscle.glutes), 6);
      expect(r.workedSets(w, Muscle.abductors), 0);
      expect(r.workedSets(w, Muscle.adductors), 0);
      expect(r.rankedMuscles(w).map((e) => e.muscle), [Muscle.glutes]);
    });

    test('curls work the biceps, never the triceps or the forearms', () {
      final r = buildMuscleReport(
        log: const [(dateKey: '2026-10-16', exerciseId: 'curl', sets: 4)],
        musclesOf: (_) => const ExerciseMuscles(
          primary: [Muscle.biceps],
          secondary: [Muscle.forearms],
        ),
        today: _today,
      );
      const w = MuscleWindow.week;
      expect(r.workedSets(w, Muscle.biceps), 4);
      expect(r.workedSets(w, Muscle.triceps), 0);
      expect(r.workedSets(w, Muscle.forearms), 0);
      expect(r.helpedSets(w, Muscle.forearms), 4);
      expect(r.helpedSets(w, Muscle.triceps), 0);
      // All three are one group, and the group still has its sets.
      expect(r.setsIn(w, MuscleSection.arms), 4);
    });

    test('each muscle is scored against her most worked muscle', () {
      final r = _report(const [
        (dateKey: '2026-10-16', exerciseId: 'glute_bridge', sets: 4),
        (dateKey: '2026-10-15', exerciseId: 'goblet_squat', sets: 2),
        (dateKey: '2026-09-30', exerciseId: 'push_up', sets: 3),
      ]);
      expect(r.muscleMaxIn(MuscleWindow.week), 6);
      expect(r.muscleScore(MuscleWindow.week, Muscle.glutes), 1);
      expect(
        r.muscleScore(MuscleWindow.week, Muscle.quads),
        closeTo(1 / 3, 1e-9),
      );
      expect(r.workedSets(MuscleWindow.week, Muscle.chest), 0);
      expect(r.workedSets(MuscleWindow.month, Muscle.chest), 3);
      expect(r.helpedSets(MuscleWindow.month, Muscle.triceps), 3);
      expect(r.rankedMuscles(MuscleWindow.month).map((e) => e.muscle), [
        Muscle.glutes,
        Muscle.chest,
        Muscle.quads,
      ]);
    });

    test('a stretch works nothing, and helps nothing', () {
      final r = _report(const [
        (dateKey: '2026-10-16', exerciseId: 'childs_pose', sets: 2),
      ]);
      for (final m in Muscle.values) {
        expect(r.workedSets(MuscleWindow.week, m), 0, reason: m.name);
        expect(r.helpedSets(MuscleWindow.week, m), 0, reason: m.name);
      }
    });
  });
}
