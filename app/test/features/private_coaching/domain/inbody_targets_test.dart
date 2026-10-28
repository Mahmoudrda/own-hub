// A coached client's starting point from her InBody numbers: the figures are
// DailyTargets', held to TargetSafety, and nothing is offered where the
// safety module offers nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/nutrition/target_safety.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart'
    show TrainingGoal;
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_targets.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';

const _scan = InBodyScan(weightKg: 64.5, bmrKcal: 1340, heightCm: 164);

InBodySuggestion _suggest(
  InBodyScan scan, {
  String goal = 'stronger',
  int days = 3,
  String? lifeStage,
  bool eatingHistory = false,
}) => InBodyTargets.suggest(
  scan,
  Intake(
    goal: goal,
    daysPerWeek: days,
    lifeStage: lifeStage,
    eatingHistory: eatingHistory,
  ),
);

void main() {
  group('the figures', () {
    test('are hand-computed from her metabolic rate, goal and week', () {
      // 3 days x 45 min = 135 min a week -> 1.375; 1340 x 1.375 = 1842.5.
      // loseSteadily x 0.85 = 1566.1 -> 1566; protein 1.6 x 64.5 = 103.
      final lose = _suggest(_scan, goal: 'loseSteadily');
      expect(lose.state, InBodySuggestionState.ready);
      expect(lose.kcal, 1566);
      expect(lose.proteinG, 103);
      // stronger x 1.05 = 1934.6 -> 1935; protein 1.8 x 64.5 = 116.
      final strong = _suggest(_scan);
      expect(strong.kcal, 1935);
      expect(strong.proteinG, 116);
      // buildMuscle: same energy, 1.9 g a kilo = 123.
      final build = _suggest(_scan, goal: 'buildMuscle');
      expect(build.kcal, 1935);
      expect(build.proteinG, 123);
      // feelBetter and backIntoIt are maintenance: 1842.5 -> 1843, 103 g.
      for (final goal in ['feelBetter', 'backIntoIt']) {
        expect(_suggest(_scan, goal: goal).kcal, 1843);
      }
    });

    test('are exactly what DailyTargets gives with her rate in place', () {
      final direct = DailyTargets.compute(
        body: const BodyData(weightKg: 64.5),
        goal: TrainingGoal.loseSteadily,
        daysPerWeek: 3,
        minutesPerSession: 45,
        bmrKcal: 1340,
      );
      final suggestion = _suggest(_scan, goal: 'loseSteadily');
      expect(suggestion.kcal, direct.kcal);
      expect(suggestion.proteinG, direct.proteinG);
    });

    test('never go under the floor', () {
      // 50 kg, BMR 1000, one day: 1000 x 1.2 x 0.85 = 1020 -> 1200.
      final s = _suggest(
        const InBodyScan(weightKg: 50, bmrKcal: 1000),
        goal: 'loseSteadily',
        days: 1,
      );
      expect(s.kcal, TargetSafety.floorKcal);
    });

    test('hold protein to its share of the day', () {
      // 100 kg at the floor: 1.6 g a kilo is 160 g; 35% of 1200 is 105 g.
      final s = _suggest(
        const InBodyScan(weightKg: 100, bmrKcal: 1100),
        goal: 'loseSteadily',
        days: 1,
      );
      expect(s.kcal, 1200);
      expect(s.proteinG, 105);
      expect(
        TargetSafety.goalProblem(kcal: s.kcal, proteinG: s.proteinG),
        isNull,
        reason: 'the composer would accept it',
      );
    });

    test('read the days she trains, whatever the number is', () {
      expect(_suggest(_scan, days: 0).isReady, isTrue);
      expect(_suggest(_scan, days: 9).isReady, isTrue);
    });

    test('use the contract\'s goal names, not substrings of them', () {
      // The old reader took "lose" or "weight" anywhere in the word.
      final weightGoal = _suggest(_scan, goal: 'weightLoss');
      expect(weightGoal.kcal, 1843, reason: 'an unknown goal is maintenance');
    });
  });

  group('nothing is offered', () {
    test('for an eating-history answer, not even a number', () {
      final s = _suggest(_scan, eatingHistory: true);
      expect(s.state, InBodySuggestionState.withheld);
      expect(s.kcal, 0);
      expect(s.proteinG, 0);
      final viaHealth = InBodyTargets.suggest(
        _scan,
        const Intake(health: {'eatingHistory': true}),
      );
      expect(viaHealth.state, InBodySuggestionState.withheld);
    });

    test('while she is pregnant or after a birth', () {
      for (final stage in ['pregnant', 'postpartum']) {
        final s = _suggest(_scan, goal: 'loseSteadily', lifeStage: stage);
        expect(s.state, InBodySuggestionState.protectedStage, reason: stage);
        expect(s.kcal, 0);
      }
    });

    test('an eating-history answer wins over a life stage', () {
      expect(
        _suggest(_scan, lifeStage: 'pregnant', eatingHistory: true).state,
        InBodySuggestionState.withheld,
      );
    });

    test('without her weight or her metabolic rate', () {
      for (final scan in const [
        InBodyScan(weightKg: 64.5),
        InBodyScan(bmrKcal: 1340),
        InBodyScan(heightCm: 164, bodyFatPercent: 26.6),
        InBodyScan(),
      ]) {
        expect(_suggest(scan).state, InBodySuggestionState.notEnough);
      }
    });

    test('and no age, height or weight is invented to fill a gap', () {
      // The first version assumed 65 kg, 163 cm and 28 years.
      expect(
        _suggest(const InBodyScan(skeletalMuscleMassKg: 24.8)).state,
        InBodySuggestionState.notEnough,
      );
    });
  });
}
