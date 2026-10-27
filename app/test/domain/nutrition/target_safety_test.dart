// The calorie and macro safety rules, and the properties they must keep for
// every body the app accepts.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/nutrition/target_safety.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';

void main() {
  group('the numbers', () {
    test('the floor, the ceiling and the energy for a stage', () {
      expect(TargetSafety.floorKcal, 1200);
      expect(TargetSafety.ceilingKcal, 4000);
      expect(TargetSafety.stageGoalFloorKcal, 1800);
      expect(TargetSafety.maxProteinPerKg, 2.0);
      // FAO/WHO/UNU 2004, Human energy requirements, adequately nourished
      // women: +85, +285, +475 kcal a day by trimester; +505 kcal a day in the
      // first six months of exclusive breastfeeding.
      expect(
        TargetSafety.stageExtraKcal(TargetStage.pregnant, trimester: 1),
        85,
      );
      expect(
        TargetSafety.stageExtraKcal(TargetStage.pregnant, trimester: 2),
        285,
      );
      expect(
        TargetSafety.stageExtraKcal(TargetStage.pregnant, trimester: 3),
        475,
      );
      expect(TargetSafety.stageExtraKcal(TargetStage.breastfeeding), 505);
      // An unknown trimester takes the smallest figure.
      expect(TargetSafety.stageExtraKcal(TargetStage.pregnant), 85);
      expect(TargetSafety.stageExtraKcal(TargetStage.postpartum), 0);
      expect(TargetSafety.stageExtraKcal(TargetStage.none), 0);
      expect(TargetSafety.carbsMinFor(TargetStage.none), 130);
      expect(TargetSafety.carbsMinFor(TargetStage.pregnant), 175);
      expect(TargetSafety.carbsMinFor(TargetStage.breastfeeding), 210);
    });

    test('the stage a wire name means, and the stricter of two', () {
      expect(TargetStage.fromWire('pregnant'), TargetStage.pregnant);
      expect(TargetStage.fromWire('postpartum'), TargetStage.postpartum);
      expect(TargetStage.fromWire('pain_injury'), TargetStage.none);
      expect(TargetStage.fromWire(null), TargetStage.none);
      expect(
        TargetStage.postpartum.orStricter(TargetStage.pregnant),
        TargetStage.pregnant,
      );
      expect(
        TargetStage.pregnant.orStricter(TargetStage.none),
        TargetStage.pregnant,
      );
    });
  });

  group('energy, in the pinned order', () {
    test(
      'maintenance, then the adjustment, then the extra, then the floor',
      () {
        // An adult losing: 2000 x 0.85 = 1700.
        expect(
          TargetSafety.energy(maintenanceKcal: 2000, goalFactor: 0.85).kcal,
          1700,
        );
        // Pregnant in the third trimester, losing: the deficit is dropped, then
        // the extra is added: 2000 + 475, not 1700 + 475.
        final pregnant = TargetSafety.energy(
          maintenanceKcal: 2000,
          goalFactor: 0.85,
          stage: TargetStage.pregnant,
          trimester: 3,
        );
        expect(pregnant.kcal, 2475);
        expect(pregnant.note, TargetNote.noDeficitStage);
        // The floor comes last: 700 + 85 is raised to 1200.
        final tiny = TargetSafety.energy(
          maintenanceKcal: 700,
          goalFactor: 1,
          stage: TargetStage.pregnant,
        );
        expect(tiny.kcal, 1200);
        expect(tiny.note, TargetNote.floor);
      },
    );

    test(
      'under 18 never gets a deficit; the note names her age, not a stage',
      () {
        final teen = TargetSafety.energy(
          maintenanceKcal: 1800,
          goalFactor: 0.85,
          ageYears: 17,
        );
        expect(teen.kcal, 1800);
        expect(teen.note, TargetNote.noDeficitMinor);
        final both = TargetSafety.energy(
          maintenanceKcal: 1800,
          goalFactor: 0.85,
          ageYears: 17,
          stage: TargetStage.pregnant,
        );
        expect(both.note, TargetNote.noDeficitMinor);
        expect(
          TargetSafety.energy(
            maintenanceKcal: 1800,
            goalFactor: 0.85,
            ageYears: 18,
          ).kcal,
          1530,
        );
        // An unknown age is an adult.
        expect(TargetSafety.deficitAllowed(), isTrue);
      },
    );

    test('a blocked deficit under the floor still lands on the floor', () {
      final e = TargetSafety.energy(
        maintenanceKcal: 1100,
        goalFactor: 0.85,
        ageYears: 16,
      );
      expect(e.kcal, 1200);
      expect(e.note, TargetNote.noDeficitMinor);
    });

    test('a surplus or maintenance goal is never blocked', () {
      final e = TargetSafety.energy(
        maintenanceKcal: 2000,
        goalFactor: 1.05,
        ageYears: 15,
        stage: TargetStage.breastfeeding,
      );
      expect(e.kcal, 2100 + 505);
      expect(e.note, TargetNote.none);
    });

    test('the ceiling', () {
      expect(
        TargetSafety.energy(maintenanceKcal: 9000, goalFactor: 1.05).kcal,
        4000,
      );
    });
  });

  group('macros', () {
    test('an ordinary day: protein per kilo, 28% fat, carbs the rest', () {
      // 2000 kcal, 60 kg, 1.6 g/kg: protein 96 (384 kcal), fat 560/9 = 62.2 so
      // 62 g (558 kcal), carbs (2000 - 384 - 558) / 4 = 264.5, so 265.
      final m = TargetSafety.macros(
        kcal: 2000,
        weightKg: 60,
        proteinPerKg: 1.6,
      );
      expect(m, (proteinG: 96, fatG: 62, carbsG: 265));
    });

    test('protein is held to 2.0 g/kg', () {
      // 3000 kcal, 50 kg, asking 3.0 g/kg: 100 g, not 150.
      expect(
        TargetSafety.macros(kcal: 3000, weightKg: 50, proteinPerKg: 3).proteinG,
        100,
      );
    });

    test('protein is held to 35% of the day', () {
      // 1200 kcal, 100 kg: 160 g would be 53%; 35% is 105 g.
      expect(
        TargetSafety.macros(
          kcal: 1200,
          weightKg: 100,
          proteinPerKg: 1.6,
        ).proteinG,
        105,
      );
    });

    test('fat gives way so carbs reach the adult minimum', () {
      // 1200 kcal, 70 kg: protein 105 (420), default fat 336 leaves carbs 111.
      // Fat drops to 260 kcal (28.9 g) and carbs reach 130 g.
      final m = TargetSafety.macros(
        kcal: 1200,
        weightKg: 70,
        proteinPerKg: 1.6,
      );
      expect(m, (proteinG: 105, fatG: 29, carbsG: 130));
    });

    test('protein gives way last, to 0.8 g/kg at the least', () {
      // Pregnant, 1200 kcal, 100 kg: carbs want 175 g (700 kcal). Fat is at its
      // 20% minimum (240 kcal), protein falls to the 0.8 g/kg minimum, 80 g.
      final m = TargetSafety.macros(
        kcal: 1200,
        weightKg: 100,
        proteinPerKg: 1.6,
        stage: TargetStage.pregnant,
      );
      expect(m, (proteinG: 80, fatG: 27, carbsG: 159));
    });
  });

  group('a goal a coach types', () {
    test('the problems, in order', () {
      GoalProblem? p(int k, int g, [TargetStage s = TargetStage.none]) =>
          TargetSafety.goalProblem(kcal: k, proteinG: g, stage: s);
      expect(p(1199, 80), GoalProblem.belowFloor);
      expect(p(1200, 80), isNull);
      expect(p(4001, 80), GoalProblem.aboveCeiling);
      expect(p(4000, 80), isNull);
      expect(p(1799, 100, TargetStage.pregnant), GoalProblem.belowStageFloor);
      expect(p(1800, 100, TargetStage.pregnant), isNull);
      expect(p(1799, 100, TargetStage.postpartum), GoalProblem.belowStageFloor);
      expect(p(1799, 100), isNull);
      // 35% of 1600 is 560 kcal: 140 g is allowed, 141 g is not.
      expect(p(1600, 140), isNull);
      expect(p(1600, 141), GoalProblem.proteinTooHigh);
    });
  });

  group('properties over every body the app accepts', () {
    final weights = <double>[
      30,
      38,
      45,
      52,
      60,
      70,
      85,
      100,
      120,
      160,
      200,
      250,
    ];
    final heights = <int>[120, 135, 150, 160, 170, 185, 200, 230];
    final ages = <int>[14, 16, 17, 18, 19, 25, 40, 55, 70, 90];
    final stages = TargetStage.values;
    // Weekly minutes of 0, 45, 90, 200 and 400 sit in the four activity bands.
    final weeks = <(int, int)>[(1, 10), (3, 15), (2, 45), (4, 50), (7, 60)];

    Iterable<DailyTargets> everyTarget({
      TargetStage? onlyStage,
      TrainingGoal? onlyGoal,
    }) sync* {
      for (final w in weights) {
        for (final h in heights) {
          for (final a in ages) {
            for (final goal
                in onlyGoal == null ? TrainingGoal.values : [onlyGoal]) {
              for (final stage in onlyStage == null ? stages : [onlyStage]) {
                for (final (d, m) in weeks) {
                  yield DailyTargets.compute(
                    body: BodyData(weightKg: w, heightCm: h, ageYears: a),
                    goal: goal,
                    daysPerWeek: d,
                    minutesPerSession: m,
                    stage: stage,
                  );
                }
              }
            }
          }
        }
      }
    }

    test('never below the floor and never above the ceiling', () {
      for (final t in everyTarget()) {
        expect(t.kcal, inInclusiveRange(1200, 4000));
      }
    });

    test('protein stays within 2.0 g/kg and 35% of the day', () {
      for (final w in weights) {
        for (final stage in stages) {
          final t = DailyTargets.compute(
            body: BodyData(weightKg: w, heightCm: 160, ageYears: 30),
            goal: TrainingGoal.buildMuscle,
            stage: stage,
          );
          expect(t.proteinG, lessThanOrEqualTo((2.0 * w).round()));
        }
      }
      for (final t in everyTarget(onlyStage: TargetStage.none)) {
        expect(t.proteinG * 4, lessThanOrEqualTo(0.35 * t.kcal + 2));
      }
    });

    test(
      'protein, fat and carbs add up to the calories, give or take rounding',
      () {
        for (final t in everyTarget()) {
          final sum = t.proteinG * 4 + t.fatG * 9 + t.carbsG * 4;
          expect((sum - t.kcal).abs(), lessThanOrEqualTo(10), reason: '$t');
        }
      },
    );

    test('fat stays between 20% and 35% of the day', () {
      for (final t in everyTarget()) {
        final share = t.fatG * 9 / t.kcal;
        expect(share, inInclusiveRange(0.19, 0.36), reason: '$t');
      }
    });

    test('more training never lowers the calories', () {
      for (final w in weights) {
        for (final a in ages) {
          for (final goal in TrainingGoal.values) {
            for (final stage in stages) {
              var last = 0;
              // Ordered by weekly minutes: 10, 45, 90, 200, 420.
              for (final (d, m) in [
                (1, 10),
                (3, 15),
                (2, 45),
                (4, 50),
                (7, 60),
              ]) {
                final k = DailyTargets.compute(
                  body: BodyData(weightKg: w, heightCm: 165, ageYears: a),
                  goal: goal,
                  daysPerWeek: d,
                  minutesPerSession: m,
                  stage: stage,
                ).kcal;
                expect(k, greaterThanOrEqualTo(last));
                last = k;
              }
            }
          }
        }
      }
    });

    test(
      'a woman who may not lose gets the same calories as one maintaining',
      () {
        for (final w in weights) {
          for (final a in [14, 16, 17]) {
            final body = BodyData(weightKg: w, heightCm: 160, ageYears: a);
            expect(
              DailyTargets.compute(
                body: body,
                goal: TrainingGoal.loseSteadily,
              ).kcal,
              DailyTargets.compute(
                body: body,
                goal: TrainingGoal.feelBetter,
              ).kcal,
            );
          }
          for (final stage in [TargetStage.pregnant, TargetStage.postpartum]) {
            final body = BodyData(weightKg: w, heightCm: 160, ageYears: 30);
            expect(
              DailyTargets.compute(
                body: body,
                goal: TrainingGoal.loseSteadily,
                stage: stage,
              ).kcal,
              DailyTargets.compute(
                body: body,
                goal: TrainingGoal.feelBetter,
                stage: stage,
              ).kcal,
            );
          }
        }
      },
    );

    test('an eating-history answer withholds everything', () {
      for (final goal in TrainingGoal.values) {
        final t = DailyTargets.compute(
          body: const BodyData(weightKg: 60, heightCm: 160, ageYears: 30),
          goal: goal,
          eatingHistory: true,
        );
        expect(t.withheld, isTrue);
        expect([
          t.kcal,
          t.proteinG,
          t.carbsG,
          t.fatG,
          t.fiberG,
        ], everyElement(0));
      }
    });
  });
}
