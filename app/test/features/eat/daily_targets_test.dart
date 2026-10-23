// Daily targets, worked by hand.
//
// Mifflin-St Jeor for women: 10 w + 6.25 h - 5 a - 161, times an activity
// factor from the weekly minutes, then the goal. Protein is 1.6 g/kg (1.8 for
// stronger, 1.9 for building muscle), fat 28% of kcal, carbs the rest, fibre 25 g.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';

void main() {
  test('no body data: 60 kg, 160 cm, 30 y and the default week', () {
    // BMR 600 + 1000 - 150 - 161 = 1289. 3 x 15 = 45 min a week: 1.2.
    // 1289 x 1.2 x 1.05 (stronger) = 1624.14.
    // Protein 1.8 x 60 = 108. Fat 1624 x 0.28 / 9 = 50.5 -> 51.
    // Carbs (1624 - 432 - 459) / 4 = 183.25 -> 183.
    final t = DailyTargets.compute();
    expect(t.kcal, 1624);
    expect(t.proteinG, 108);
    expect(t.fatG, 51);
    expect(t.carbsG, 183);
    expect(t.fiberG, 25);
    expect(t.usesDefaults, isTrue);
  });

  test('losing steadily: 70 kg, 165 cm, 28 y, 4 days of 45 minutes', () {
    // BMR 700 + 1031.25 - 140 - 161 = 1430.25. 180 min: 1.55.
    // 1430.25 x 1.55 x 0.85 = 1884.35. Protein 1.6 x 70 = 112.
    // Fat 1884 x 0.28 / 9 = 58.6 -> 59. Carbs (1884 - 448 - 531) / 4 = 226.25.
    final t = DailyTargets.compute(
      body: const BodyData(weightKg: 70, heightCm: 165, ageYears: 28),
      goal: TrainingGoal.loseSteadily,
      daysPerWeek: 4,
      minutesPerSession: 45,
    );
    expect(t.kcal, 1884);
    expect(t.proteinG, 112);
    expect(t.fatG, 59);
    expect(t.carbsG, 226);
    expect(t.usesDefaults, isFalse);
  });

  test('feeling better: 65 kg, 170 cm, 35 y, 6 days of 60 minutes', () {
    // BMR 650 + 1062.5 - 175 - 161 = 1376.5. 360 min: 1.725. No adjustment.
    // 1376.5 x 1.725 = 2374.46. Protein 1.6 x 65 = 104.
    // Fat 2374 x 0.28 / 9 = 73.9 -> 74. Carbs (2374 - 416 - 666) / 4 = 323.
    final t = DailyTargets.compute(
      body: const BodyData(weightKg: 65, heightCm: 170, ageYears: 35),
      goal: TrainingGoal.feelBetter,
      daysPerWeek: 6,
      minutesPerSession: 60,
    );
    expect(t.kcal, 2374);
    expect(t.proteinG, 104);
    expect(t.fatG, 74);
    expect(t.carbsG, 323);
  });

  test('part of the body data: the rest falls back and it still says so', () {
    // Weight only: 70 kg, defaults 160 cm and 30 y.
    // BMR 700 + 1000 - 150 - 161 = 1389. x 1.2 = 1666.8.
    final t = DailyTargets.compute(
      body: const BodyData(weightKg: 70),
      goal: TrainingGoal.backIntoIt,
    );
    expect(t.kcal, 1667);
    expect(t.usesDefaults, isTrue);
  });

  test('the activity bands', () {
    double f(int d, int m) =>
        DailyTargets.activityFactor(daysPerWeek: d, minutesPerSession: m);
    expect(f(1, 30), 1.2); // 30
    expect(f(2, 30), 1.375); // 60
    expect(f(3, 49), 1.375); // 147
    expect(f(3, 50), 1.55); // 150
    expect(f(5, 59), 1.55); // 295
    expect(f(5, 60), 1.725); // 300
    expect(f(7, 180), 1.725);
  });

  test('protein: stronger asks for more per kilo', () {
    final base = DailyTargets.compute(goal: TrainingGoal.feelBetter);
    final strong = DailyTargets.compute(goal: TrainingGoal.stronger);
    expect(base.proteinG, 96);
    expect(strong.proteinG, 108);
  });

  test('building muscle: 1.9 g/kg, and the same energy nudge as stronger', () {
    // 60 kg default: 1.9 x 60 = 114, inside the 1.8 to 2.0 g/kg asked for.
    final muscle = DailyTargets.compute(goal: TrainingGoal.buildMuscle);
    final strong = DailyTargets.compute(goal: TrainingGoal.stronger);
    expect(muscle.proteinG, 114);
    expect(muscle.kcal, strong.kcal);
    expect(muscle.proteinG, greaterThan(strong.proteinG));
    // At 72 kg the figure is still within 1.8 to 2.0 g/kg.
    final heavier = DailyTargets.compute(
      body: const BodyData(weightKg: 72, heightCm: 165, ageYears: 30),
      goal: TrainingGoal.buildMuscle,
    );
    expect(heavier.proteinG / 72, inInclusiveRange(1.8, 2.0));
  });
}
