// The coach's three splits: content, safety, selection and migration.
//
// The splits are a JSON asset written by tool/build_coach_splits.py, so nothing
// below trusts the file: every exercise is looked up in the exercise catalogue,
// every move's tags are compared with its row, every day is held to the coach's
// own list and to `workoutProblems`, and every answer she can give is checked
// to land on a split.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/life_stage_safety_policy.dart'
    show LifeStageSafetyPolicy;
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';

const _assetPath = 'assets/content/starting_programmes.json';
const _cataloguePath = '../6-v2/content/exercise_library/catalogue.json';

/// The coach's days, as the exercise ids that stand for each named move, in her
/// order. The closing stretch is not listed.
const _days = <int, List<(String, String, List<String>)>>{
  3: [
    (
      'd1',
      'Upper',
      [
        'machine_chest_press',
        'lat_pulldown_wide',
        'pec_deck_fly',
        'seated_cable_row',
        'dumbbell_lateral_raise',
        'reverse_pec_deck',
        'standing_dumbbell_biceps_curl',
        'cable_rope_triceps_pushdown',
        'plank',
      ],
    ),
    (
      'd2',
      'Lower',
      [
        'pendulum_squat',
        'heel_elevated_goblet_squat',
        'seated_leg_press',
        'dumbbell_calf_raise',
        'dumbbell_sumo_squat',
        'bodyweight_squat_arm_swing',
        'mountain_climbers',
        'russian_twist',
      ],
    ),
    (
      'd3',
      'Lower II',
      [
        'dumbbell_sumo_squat',
        'seated_leg_curl',
        'romanian_deadlift',
        'side_lying_clamshell',
        'seated_dumbbell_calf_raise',
        'dumbbell_reverse_lunge',
        'crunch',
        'reach_crunch',
        'bicycle_crunch',
        'flutter_kicks',
      ],
    ),
  ],
  4: [
    (
      'd1',
      'Upper',
      [
        'machine_chest_press',
        'lat_pulldown_wide',
        'pec_deck_fly',
        'seated_cable_row',
        'dumbbell_lateral_raise',
        'seated_dumbbell_front_raise',
        'reverse_pec_deck',
        'cable_biceps_curl',
        'cable_rope_triceps_pushdown',
        'plank',
      ],
    ),
    (
      'd2',
      'Lower',
      [
        'barbell_back_squat',
        'dumbbell_bulgarian_split_squat',
        'pendulum_squat',
        'straight_leg_glute_kickback',
        'side_lying_clamshell',
        'dumbbell_sumo_squat',
        'dumbbell_calf_raise',
      ],
    ),
    (
      'd3',
      'Lower II',
      [
        'dumbbell_sumo_squat',
        'kettlebell_glute_bridge',
        'seated_leg_curl',
        'dumbbell_reverse_lunge',
        'side_lying_clamshell',
        'seated_dumbbell_calf_raise',
      ],
    ),
    (
      'd4',
      'Core and cardio',
      [
        'flutter_kicks',
        'russian_twist',
        'crunch',
        'plank',
        'mountain_climbers',
      ],
    ),
  ],
  5: [
    (
      'd1',
      'Glutes and legs',
      [
        'seated_leg_press',
        'barbell_hip_thrust',
        'pendulum_squat',
        'dumbbell_reverse_lunge',
        'dumbbell_sumo_squat',
        'dumbbell_calf_raise',
        'flutter_kicks',
      ],
    ),
    (
      'd2',
      'Upper',
      [
        'pec_deck_fly',
        'lat_pulldown_wide',
        'knee_press_up',
        'bent_over_row',
        'shoulder_press',
        'dumbbell_lateral_raise',
        'reverse_pec_deck',
      ],
    ),
    (
      'd3',
      'Cardio and arms',
      [
        'standing_dumbbell_biceps_curl',
        'cable_rope_triceps_pushdown',
        'cable_face_pull',
        'mountain_climbers',
      ],
    ),
    (
      'd4',
      'Glutes and legs II',
      [
        'seated_leg_curl',
        'barbell_deadlift',
        'straight_leg_glute_kickback',
        'donkey_kick',
        'kettlebell_glute_bridge',
        'dumbbell_sumo_squat',
        'seated_dumbbell_calf_raise',
      ],
    ),
    (
      'd5',
      'Core with cardio',
      [
        'bicycle_crunch',
        'reach_crunch',
        'lying_bicycle_legs',
        'crunch',
        'plank',
        'mountain_climbers',
      ],
    ),
  ],
};

/// The families of every programme the app shipped before the splits.
const _oldFamilies = [
  'stronger_home',
  'stronger_weights',
  'stronger_gym',
  'feel_better_home',
  'feel_better_weights',
  'feel_better_gym',
  'lose_steadily_home',
  'lose_steadily_weights',
  'lose_steadily_gym',
  'build_muscle_weights',
  'build_muscle_gym',
  'beginner_foundations',
];

String _id(int days, TrainingLevel tier) => tier == TrainingLevel.beginner
    ? 'split_${days}day'
    : 'split_${days}day_${tier.wireName}';

Map<String, Map<String, Object?>> _catalogueRows() {
  final catalogue = jsonDecode(File(_cataloguePath).readAsStringSync()) as Map;
  return {
    for (final raw in catalogue['exercises'] as List)
      (raw as Map)['exerciseId'] as String: raw.cast<String, Object?>(),
  };
}

const _kit = <Set<Equipment>>[
  {Equipment.none},
  {Equipment.mat},
  {Equipment.dumbbells},
  {Equipment.bands},
  {Equipment.mat, Equipment.dumbbells},
  {Equipment.dumbbells, Equipment.bands},
];

Iterable<Intake> _everyAnswer() sync* {
  for (final goal in TrainingGoal.values) {
    for (final place in TrainingPlace.values) {
      for (final equipment in _kit) {
        for (final days in [1, 2, 3, 4, 5, 6, 7]) {
          for (final minutes in Intake.allowedMinutes) {
            for (final level in TrainingLevel.values) {
              yield Intake(
                goal: goal,
                place: place,
                equipment: equipment,
                days: days,
                minutes: minutes,
                level: level,
              );
            }
          }
        }
      }
    }
  }
}

void main() {
  late List<AuthoredProgramme> plans;

  setUpAll(() {
    final text = File(_assetPath).readAsStringSync();
    StartingProgrammes.adopt(text);
    plans = WorkoutLibrary.parse(
      (jsonDecode(text) as Map).cast<String, Object?>(),
    ).programmes;
  });
  tearDownAll(StartingProgrammes.reset);

  AuthoredProgramme plan(int days, TrainingLevel tier) =>
      plans.firstWhere((p) => p.programId == _id(days, tier));

  List<AuthoredSession> ordinary(AuthoredProgramme p) => [
    for (final s in p.sessions)
      if (suits(s, LifeStage.none)) s,
  ];

  List<AuthoredMove> work(AuthoredSession s) =>
      s.moves.sublist(0, s.moves.length - 1);

  test('the file says its content is drafted and not yet signed off', () {
    expect(StartingProgrammes.review, contains('pending Rahma'));
  });

  test(
    'the catalogue is exactly nine programmes: three splits, three tiers',
    () {
      expect(plans, hasLength(9));
      expect(StartingProgrammes.catalogue, hasLength(9));
      expect(StartingProgrammes.catalogue.map((p) => p.programId).toSet(), {
        for (final days in [3, 4, 5])
          for (final tier in TrainingLevel.values) _id(days, tier),
      });
      expect(StartingProgrammes.catalogue.map((p) => p.family).toSet(), {
        'split_3day',
        'split_4day',
        'split_5day',
      });
      for (final p in StartingProgrammes.catalogue) {
        expect(p.daysPerWeek, int.parse(p.family.substring(6, 7)));
        expect(p.sessionLength, inInclusiveRange(45, 60), reason: p.programId);
        expect(p.goals, isEmpty, reason: 'the goal does not choose a plan');
        expect(p.places, isEmpty, reason: 'every place is offered the splits');
        expect(p.equipment, isEmpty, reason: 'every kit is offered the splits');
      }
      for (final p in plans) {
        expect(workoutProblems(p), isEmpty, reason: p.programId);
        expect(p.status, ProgrammeStatus.published);
      }
    },
  );

  test('every day is the coach\'s list, in her order, at every tier', () {
    for (final entry in _days.entries) {
      for (final tier in TrainingLevel.values) {
        final p = plan(entry.key, tier);
        final days = ordinary(p);
        expect(days, hasLength(entry.key), reason: p.programId);
        for (final (i, (id, title, ids)) in entry.value.indexed) {
          final s = days[i];
          expect(s.sessionId, id, reason: p.programId);
          expect(s.titleEn, title, reason: p.programId);
          expect(
            work(s).map((m) => m.exerciseId).toList(),
            ids,
            reason: '${p.programId} $id',
          );
          // The closing stretch: one held set, no rest.
          final stretch = s.moves.last;
          expect(stretch.sets, 1);
          expect(stretch.holdSeconds, isNotNull);
          expect(stretch.restSeconds, 0);
          // No move repeats in a day.
          expect(
            s.moves.map((m) => m.exerciseId).toSet(),
            hasLength(s.moves.length),
          );
        }
      }
    }
  });

  test(
    'every exercise is a catalogue exercise with a clip and its own tags',
    () {
      final rows = _catalogueRows();
      for (final p in plans) {
        for (final s in p.sessions) {
          for (final m in s.moves) {
            final row = rows[m.exerciseId];
            expect(row, isNotNull, reason: '${p.programId} ${m.exerciseId}');
            expect(
              (row!['clips'] as List?) ?? const [],
              isNotEmpty,
              reason: '${p.programId} ${m.exerciseId} has no clip',
            );
            expect(
              m.contraindications.toSet(),
              (row['contraindicationTags'] as List).cast<String>().toSet(),
              reason: '${p.programId} ${s.sessionId} ${m.exerciseId}',
            );
          }
        }
      }
    },
  );

  test('cardio is timed blocks of at most ten minutes, 20 to 30 in all', () {
    for (final entry in _days.entries) {
      for (final tier in TrainingLevel.values) {
        for (final s in ordinary(plan(entry.key, tier))) {
          final cardio = [
            for (final m in work(s))
              if (m.holdSeconds != null && m.holdSeconds! >= 300) m,
          ];
          if (s.titleEn.contains('cardio') || s.titleEn.contains('Cardio')) {
            expect(cardio, hasLength(1), reason: '${entry.key} ${s.sessionId}');
            final m = cardio.single;
            expect(
              m.holdSeconds,
              lessThanOrEqualTo(WorkoutLimits.maxHoldSeconds),
            );
            expect(m.sets * m.holdSeconds! / 60, inInclusiveRange(20, 30));
          }
        }
      }
    }
  });

  test('every ordinary day takes 45 to 60 minutes, at every tier', () {
    for (final p in plans) {
      for (final s in ordinary(p)) {
        final raw = estimatedMinutes(s);
        expect(
          raw,
          inInclusiveRange(45, 60),
          reason: '${p.programId} ${s.sessionId}',
        );
        expect(s.minutes, inInclusiveRange(45, 60));
        // The app leaves a day of 30 minutes or more whole.
        final shown = estimatedMinutes(scaleSession(s, 60));
        expect(shown, raw, reason: '${p.programId} ${s.sessionId} at 60');
      }
    }
  });

  test('the tiers hold the same moves and differ in sets, reps or rest', () {
    for (final days in [3, 4, 5]) {
      final b = ordinary(plan(days, TrainingLevel.beginner));
      final i = ordinary(plan(days, TrainingLevel.intermediate));
      final a = ordinary(plan(days, TrainingLevel.advanced));
      for (var d = 0; d < b.length; d++) {
        String shape(AuthoredSession s) => work(s)
            .map(
              (m) =>
                  '${m.sets}x${m.reps ?? 'h${m.holdSeconds}'}@${m.restSeconds}',
            )
            .join(',');
        final ids = work(b[d]).map((m) => m.exerciseId).toList();
        expect(work(i[d]).map((m) => m.exerciseId).toList(), ids);
        expect(work(a[d]).map((m) => m.exerciseId).toList(), ids);
        expect(
          {shape(b[d]), shape(i[d]), shape(a[d])},
          hasLength(3),
          reason: '$days days, ${b[d].sessionId}',
        );
        // Every tier's first move carries a load note, and they differ.
        expect({
          b[d].moves.first.notesEn,
          i[d].moves.first.notesEn,
          a[d].moves.first.notesEn,
        }, hasLength(3));
        for (final s in [b[d], i[d], a[d]]) {
          expect(s.moves.first.notesEn, isNotEmpty);
          expect(s.moves.first.notesAr, isNotEmpty);
        }
      }
    }
  });

  test('the tiers are pitched as the coach asks', () {
    for (final days in [3, 4, 5]) {
      for (final (tier, repsOf, setsRange) in [
        (TrainingLevel.beginner, [12], [3, 4]),
        (TrainingLevel.intermediate, [10, 15], [3, 5]),
        (TrainingLevel.advanced, [8, 12, 20], [3, 5]),
      ]) {
        for (final s in ordinary(plan(days, tier))) {
          for (final m in work(s)) {
            // Timed cardio blocks are not sets of a lift.
            if ((m.holdSeconds ?? 0) >= 300) continue;
            expect(
              m.sets,
              inInclusiveRange(setsRange[0], setsRange[1]),
              reason: '$tier ${s.sessionId} ${m.exerciseId}',
            );
            if (m.reps != null) {
              expect(
                repsOf,
                contains(m.reps),
                reason: '$tier ${s.sessionId} ${m.exerciseId}',
              );
            }
          }
        }
      }
    }
    // Advanced rests long on the big lifts and short on the small ones.
    final upper = ordinary(plan(4, TrainingLevel.advanced)).first;
    expect(work(upper)[0].restSeconds, greaterThanOrEqualTo(90));
    expect(work(upper)[4].restSeconds, inInclusiveRange(45, 60));
    // Beginner rests 75 to 90 on its arm work.
    final beginner = ordinary(plan(3, TrainingLevel.beginner)).first;
    expect(work(beginner)[6].restSeconds, inInclusiveRange(75, 90));
  });

  test('pregnancy and after a birth are offered only floor-safe sessions', () {
    final floor = {
      for (final t in LifeStageSafetyPolicy.pregnancyAndEarlyPostpartumFloor)
        t.wireName,
    };
    for (final p in plans) {
      for (final s in p.sessions) {
        final protected = s.lifeStages.any(kProtectedStages.contains);
        final flagged = s.moves.any(
          (m) => m.contraindications.any(floor.contains),
        );
        if (protected) {
          expect(flagged, isFalse, reason: '${p.programId} ${s.sessionId}');
          expect(s.lifeStages, {LifeStage.pregnant, LifeStage.postpartum});
        } else {
          // An ordinary session still reaches a woman with a pain or injury
          // answer, who is otherwise offered nothing.
          expect(s.lifeStages, {LifeStage.none, LifeStage.painInjury});
        }
      }
      expect(
        programmeSessionsFor(p, LifeStage.pregnant).map((s) => s.sessionId),
        ['a-gentle', 'b-gentle'],
        reason: p.programId,
      );
      expect(
        programmeSessionsFor(p, LifeStage.postpartum).map((s) => s.sessionId),
        ['a-gentle', 'b-gentle'],
      );
      expect(
        programmeSessionsFor(p, LifeStage.painInjury),
        hasLength(p.sessions.length - 2),
      );
      // The gentle sessions are the same prescription in every tier.
      expect(
        programmeSessionsFor(p, LifeStage.pregnant),
        programmeSessionsFor(
          plan(int.parse(p.programId.substring(6, 7)), TrainingLevel.beginner),
          LifeStage.pregnant,
        ),
      );
    }
  });

  test('a short day is cut, and every day is still valid', () {
    for (final p in plans) {
      for (final s in p.sessions) {
        for (final minutes in [10, 15, 20, 30, 45, 60, 75]) {
          final cut = scaleSession(s, minutes);
          // A short day carries its own length; from 30 minutes the day is whole.
          expect(cut.minutes, minutes < 30 ? minutes : s.minutes);
          expect(
            workoutProblems(
              AuthoredProgramme(
                programId: p.programId,
                titleEn: p.titleEn,
                titleAr: p.titleAr,
                status: ProgrammeStatus.published,
                sessions: [cut],
              ),
            ),
            isEmpty,
            reason: '${p.programId} ${s.sessionId} $minutes min',
          );
        }
      }
    }
  });

  group('selection', () {
    test(
      'days a week choose the split; any other number maps to the nearest',
      () {
        for (final (days, want) in [
          (1, 3),
          (2, 3),
          (3, 3),
          (4, 4),
          (5, 5),
          (6, 5),
          (7, 5),
        ]) {
          final chosen = selectStartingProgram(Intake(days: days))!;
          expect(chosen.daysPerWeek, want, reason: '$days days');
          expect(splitDaysFor(days), want);
        }
      },
    );

    test('then her level chooses the tier, and any tier can be asked for', () {
      const intake = Intake(days: 4, level: TrainingLevel.intermediate);
      expect(
        selectStartingProgram(intake)!.programId,
        'split_4day_intermediate',
      );
      expect(
        selectStartingProgram(intake, tier: TrainingLevel.advanced)!.programId,
        'split_4day_advanced',
      );
      expect(
        selectStartingProgram(intake, tier: TrainingLevel.beginner)!.programId,
        'split_4day',
      );
    });

    test('every goal, place, kit, days, minutes and level selects a split', () {
      var checked = 0;
      for (final intake in _everyAnswer()) {
        final chosen = selectStartingProgram(intake);
        expect(chosen, isNotNull, reason: '$intake');
        expect(
          chosen!.programId,
          _id(splitDaysFor(intake.days), intake.level),
          reason: '$intake',
        );
        // The week she is given has her days, taken from the split's days.
        final programme = StartingProgrammes.programme(chosen.programId)!;
        final sessions = programmeSessionsFor(programme, intake.lifeStage);
        expect(sessions, isNotEmpty);
        checked++;
      }
      expect(checked, greaterThan(5000));
    });

    test('her goal never changes the plan, only her food', () {
      for (final days in [3, 4, 5]) {
        final ids = {
          for (final goal in TrainingGoal.values)
            selectStartingProgram(Intake(goal: goal, days: days))!.programId,
        };
        expect(ids, hasLength(1), reason: '$days days');
      }
    });

    test('three cards: the best fit of each split, best first', () {
      for (final days in [2, 3, 4, 5, 6]) {
        final top = topStartingPrograms(Intake(days: days));
        expect(top.map((p) => p.family).toSet(), hasLength(3));
        expect(top.first.daysPerWeek, splitDaysFor(days));
      }
    });

    test('the kit and place are not a reason to refuse a split', () {
      final everyone = [
        for (final place in TrainingPlace.values)
          for (final kit in _kit)
            topStartingPrograms(Intake(place: place, equipment: kit)).length,
      ];
      expect(everyone.toSet(), {3});
    });

    test('a catalogue with a kit she does not have returns nothing', () {
      final dumbbellsOnly = [
        StartingProgram(
          programId: 'x',
          weeks: 8,
          daysPerWeek: 3,
          sessionLength: 45,
          quiet: true,
          equipment: const {Equipment.dumbbells},
        ),
      ];
      expect(
        selectStartingProgram(const Intake(), catalogue: dumbbellsOnly),
        isNull,
      );
    });
  });

  group('migration', () {
    test('a split id is kept as it is', () {
      for (final days in [3, 4, 5]) {
        for (final tier in TrainingLevel.values) {
          for (final nowDays in [1, 3, 4, 5, 7]) {
            expect(
              migratedProgrammeId(_id(days, tier), days: nowDays),
              _id(days, tier),
            );
          }
        }
        expect(
          migratedProgrammeFamily('split_${days}day', days: 7),
          'split_${days}day',
        );
        expect(isCoachSplit(_id(days, TrainingLevel.advanced)), isTrue);
      }
    });

    test(
      'every old family lands on the split with her days, at the same tier',
      () {
        for (final family in _oldFamilies) {
          for (final tier in TrainingLevel.values) {
            final old = tier == TrainingLevel.beginner
                ? family
                : '${family}_${tier.wireName}';
            for (final (days, want) in [
              (1, 3),
              (2, 3),
              (3, 3),
              (4, 4),
              (5, 5),
              (6, 5),
              (7, 5),
            ]) {
              expect(
                migratedProgrammeId(old, days: days),
                _id(want, tier),
                reason: '$old at $days days',
              );
            }
            expect(programmeTier(old), tier, reason: old);
          }
          expect(isCoachSplit(family), isFalse, reason: family);
          expect(migratedProgrammeFamily(family, days: 4), 'split_4day');
          expect(
            migratedProgrammeFamily('${family}_advanced', days: 5),
            'split_5day',
          );
        }
      },
    );

    test('an unknown id maps the same way', () {
      expect(
        migratedProgrammeId('something_else_advanced', days: 5),
        'split_5day_advanced',
      );
      expect(migratedProgrammeId('', days: 4), 'split_4day');
    });

    test('a migrated id always exists in the catalogue', () {
      final ids = {for (final p in StartingProgrammes.catalogue) p.programId};
      for (final family in _oldFamilies) {
        for (final days in [1, 2, 3, 4, 5, 6, 7]) {
          expect(ids, contains(migratedProgrammeId(family, days: days)));
        }
      }
    });
  });

  test('every summary states the sets and rests its days really have', () {
    for (final p in plans) {
      final moves = [
        for (final s in ordinary(p))
          for (final m in work(s))
            if (m.reps != null) m,
      ];
      final sets = moves.map((m) => m.sets);
      final rests = moves.map((m) => m.restSeconds);
      final loSets = sets.reduce((a, b) => a < b ? a : b);
      final hiSets = sets.reduce((a, b) => a > b ? a : b);
      final loRest = rests.reduce((a, b) => a < b ? a : b);
      final hiRest = rests.reduce((a, b) => a > b ? a : b);
      final en = StartingProgrammes.summary(p.programId, 'en');
      final ar = StartingProgrammes.summary(p.programId, 'ar');
      expect(
        en,
        contains(
          loSets == hiSets ? '$loSets sets, ' : '$loSets to $hiSets sets, ',
        ),
        reason: p.programId,
      );
      expect(en, endsWith('rests of $loRest to $hiRest seconds.'));
      expect(ar, contains('$loSets'));
      expect(ar, endsWith('وراحة من $loRest لـ $hiRest ثانية.'));
      // No other counts of sets or seconds are claimed.
      expect(
        RegExp(r'\d+ (to \d+ )?sets|\d+ to \d+ seconds').allMatches(en),
        hasLength(2),
      );
    }
  });

  test(
    'the day names the card shows come from the file, in both languages',
    () {
      expect(
        StartingProgrammes.dayNames('split_3day', 'en'),
        'Upper · Lower · Lower II',
      );
      expect(
        StartingProgrammes.dayNames('split_4day_advanced', 'en'),
        'Upper · Lower · Lower II · Core and cardio',
      );
      expect(
        StartingProgrammes.dayNames('split_5day', 'ar'),
        contains('كارديو'),
      );
      expect(StartingProgrammes.dayNames('nope', 'en'), '');
    },
  );
}
