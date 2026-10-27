// Twenty women, worked by hand, through the safety rules.
//
// Mifflin-St Jeor 10 w + 6.25 h - 5 a - 161, times the activity factor (under
// 60 weekly minutes 1.2, under 150 1.375, under 300 1.55, else 1.725), then the
// goal (losing x0.85, stronger and build muscle x1.05), the stage's extra
// (FAO/WHO/UNU 2004: +85/+285/+475 pregnant by trimester, +505 breastfeeding),
// then the floor of 1,200 and the ceiling of 4,000. Protein is 1.6 g/kg (1.8
// stronger, 1.9 build muscle), held to 2.0 g/kg and 35% of the day; fat 28%;
// carbs the rest, which fat then protein give way to keep above 130 g (175
// pregnant, 210 breastfeeding).

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/nutrition/target_safety.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/onboarding/domain/body_data.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';

typedef _Expect = ({int kcal, int p, int f, int c, TargetNote note});

void _check(
  String name, {
  required double w,
  required int h,
  required int a,
  required TrainingGoal goal,
  required int days,
  required int minutes,
  TargetStage stage = TargetStage.none,
  int? trimester,
  required _Expect expected,
}) {
  test(name, () {
    final t = DailyTargets.compute(
      body: BodyData(weightKg: w, heightCm: h, ageYears: a),
      goal: goal,
      daysPerWeek: days,
      minutesPerSession: minutes,
      stage: stage,
      trimester: trimester,
    );
    expect((
      kcal: t.kcal,
      p: t.proteinG,
      f: t.fatG,
      c: t.carbsG,
      note: t.note,
    ), expected);
  });
}

void main() {
  group('twenty profiles', () {
    _check(
      '1. a small woman losing steadily lands on the floor, not 913',
      // BMR 400 + 906.25 - 250 - 161 = 895.25 x 1.2 x 0.85 = 913.2 -> 1200.
      // Protein 64, fat 336 kcal = 37 g, carbs (1200 - 256 - 333) / 4 = 152.75.
      w: 40,
      h: 145,
      a: 50,
      goal: TrainingGoal.loseSteadily,
      days: 3,
      minutes: 15,
      expected: (kcal: 1200, p: 64, f: 37, c: 153, note: TargetNote.floor),
    );
    _check(
      '2. a large woman, stronger',
      // BMR 1100 + 1062.5 - 175 - 161 = 1826.5 x 1.55 = 2831.1 x 1.05 = 2972.6.
      // Protein 1.8 x 110 = 198, fat 2973 x 0.28 / 9 = 92, carbs 338.25.
      w: 110,
      h: 170,
      a: 35,
      goal: TrainingGoal.stronger,
      days: 4,
      minutes: 45,
      expected: (kcal: 2973, p: 198, f: 92, c: 338, note: TargetNote.none),
    );
    _check(
      '3. very active, building muscle',
      // BMR 620 + 1050 - 135 - 161 = 1374 x 1.725 = 2370.2 x 1.05 = 2488.7.
      // Protein 1.9 x 62 = 117.8, fat 77, carbs (2489 - 472 - 693) / 4 = 331.
      w: 62,
      h: 168,
      a: 27,
      goal: TrainingGoal.buildMuscle,
      days: 6,
      minutes: 60,
      expected: (kcal: 2489, p: 118, f: 77, c: 331, note: TargetNote.none),
    );
    _check(
      '4. sixteen, losing: maintenance, no deficit',
      // BMR 550 + 1000 - 80 - 161 = 1309 x 1.375 = 1799.9, not x 0.85.
      w: 55,
      h: 160,
      a: 16,
      goal: TrainingGoal.loseSteadily,
      days: 3,
      minutes: 30,
      expected: (
        kcal: 1800,
        p: 88,
        f: 56,
        c: 236,
        note: TargetNote.noDeficitMinor,
      ),
    );
    _check(
      '5. pregnant, trimester unknown, losing: maintenance plus 85',
      // BMR 650 + 1031.25 - 150 - 161 = 1370.25 x 1.375 = 1884.1 + 85 = 1969.1.
      w: 65,
      h: 165,
      a: 30,
      goal: TrainingGoal.loseSteadily,
      days: 3,
      minutes: 30,
      stage: TargetStage.pregnant,
      expected: (
        kcal: 1969,
        p: 104,
        f: 61,
        c: 251,
        note: TargetNote.noDeficitStage,
      ),
    );
    _check(
      '6. pregnant in the third trimester: plus 475',
      // 1884.1 + 475 = 2359.1. Carbs (2359 - 416 - 657) / 4 = 321.5 -> 322.
      w: 65,
      h: 165,
      a: 30,
      goal: TrainingGoal.feelBetter,
      days: 3,
      minutes: 30,
      stage: TargetStage.pregnant,
      trimester: 3,
      expected: (kcal: 2359, p: 104, f: 73, c: 322, note: TargetNote.none),
    );
    _check(
      '7. breastfeeding, losing: maintenance plus 505',
      // 1884.1 + 505 = 2389.1.
      w: 65,
      h: 165,
      a: 30,
      goal: TrainingGoal.loseSteadily,
      days: 3,
      minutes: 30,
      stage: TargetStage.breastfeeding,
      expected: (
        kcal: 2389,
        p: 104,
        f: 74,
        c: 327,
        note: TargetNote.noDeficitStage,
      ),
    );
    _check(
      '8. after a birth, losing: maintenance, nothing added',
      // BMR 700 + 1012.5 - 160 - 161 = 1391.5 x 1.375 = 1913.3.
      w: 70,
      h: 162,
      a: 32,
      goal: TrainingGoal.loseSteadily,
      days: 2,
      minutes: 30,
      stage: TargetStage.postpartum,
      expected: (
        kcal: 1913,
        p: 112,
        f: 60,
        c: 231,
        note: TargetNote.noDeficitStage,
      ),
    );
    _check(
      '9. eighteen, losing: an adult, the deficit applies',
      // BMR 580 + 1031.25 - 90 - 161 = 1360.25 x 1.2 = 1632.3 x 0.85 = 1387.5.
      w: 58,
      h: 165,
      a: 18,
      goal: TrainingGoal.loseSteadily,
      days: 3,
      minutes: 15,
      expected: (kcal: 1387, p: 93, f: 43, c: 157, note: TargetNote.none),
    );
    _check(
      '10. seventeen, the same body: maintenance',
      // BMR 580 + 1031.25 - 85 - 161 = 1365.25 x 1.2 = 1638.3.
      w: 58,
      h: 165,
      a: 17,
      goal: TrainingGoal.loseSteadily,
      days: 3,
      minutes: 15,
      expected: (
        kcal: 1638,
        p: 93,
        f: 51,
        c: 202,
        note: TargetNote.noDeficitMinor,
      ),
    );
    _check(
      '11. fourteen, 30 kg, 120 cm: the lightest body the app takes',
      // BMR 300 + 750 - 70 - 161 = 819 x 1.2 x 1.05 = 1031.9 -> 1200.
      w: 30,
      h: 120,
      a: 14,
      goal: TrainingGoal.stronger,
      days: 3,
      minutes: 15,
      expected: (kcal: 1200, p: 54, f: 37, c: 163, note: TargetNote.floor),
    );
    _check(
      '12. ninety, 45 kg: maintenance is under the floor',
      // BMR 450 + 937.5 - 450 - 161 = 776.5 x 1.375 = 1067.7 -> 1200.
      w: 45,
      h: 150,
      a: 90,
      goal: TrainingGoal.backIntoIt,
      days: 2,
      minutes: 30,
      expected: (kcal: 1200, p: 72, f: 37, c: 145, note: TargetNote.floor),
    );
    _check(
      '13. 250 kg, 230 cm, training hard: the ceiling',
      // BMR 2500 + 1437.5 - 150 - 161 = 3626.5 x 1.725 x 1.05 = 6568.5 -> 4000.
      // Protein 1.8 x 250 = 450 held to 35% of 4000 / 4 = 350.
      w: 250,
      h: 230,
      a: 30,
      goal: TrainingGoal.stronger,
      days: 7,
      minutes: 180,
      expected: (kcal: 4000, p: 350, f: 124, c: 371, note: TargetNote.none),
    );
    _check(
      '14. 30 kg at ninety, losing: the floor, not 448',
      // BMR 300 + 750 - 450 - 161 = 439 x 1.2 x 0.85 = 447.8 -> 1200.
      w: 30,
      h: 120,
      a: 90,
      goal: TrainingGoal.loseSteadily,
      days: 1,
      minutes: 15,
      expected: (kcal: 1200, p: 48, f: 37, c: 169, note: TargetNote.floor),
    );
    _check(
      '15. 120 kg, 150 cm, seventy: protein held to 35% of the day',
      // BMR 1200 + 937.5 - 350 - 161 = 1626.5 x 1.2 x 0.85 = 1659.0.
      // Protein 192 would be 46%; 35% of 1659 / 4 = 145.2.
      w: 120,
      h: 150,
      a: 70,
      goal: TrainingGoal.loseSteadily,
      days: 1,
      minutes: 30,
      expected: (kcal: 1659, p: 145, f: 52, c: 153, note: TargetNote.none),
    );
    _check(
      '16. 70 kg at 1200 kcal: fat gives way so carbs reach 130 g',
      // BMR 700 + 937.5 - 300 - 161 = 1176.5 x 1.2 x 0.85 = 1200.0.
      // Protein 112 held to 105 (420 kcal); fat 260 kcal = 29 g; carbs 129.75.
      w: 70,
      h: 150,
      a: 60,
      goal: TrainingGoal.loseSteadily,
      days: 1,
      minutes: 30,
      expected: (kcal: 1200, p: 105, f: 29, c: 130, note: TargetNote.none),
    );
    _check(
      '17. pregnant in the second trimester, stronger: x1.05 then plus 285',
      // BMR 520 + 987.5 - 120 - 161 = 1226.5 x 1.55 = 1901.1 x 1.05 = 1996.1.
      w: 52,
      h: 158,
      a: 24,
      goal: TrainingGoal.stronger,
      days: 5,
      minutes: 30,
      stage: TargetStage.pregnant,
      trimester: 2,
      expected: (kcal: 2281, p: 94, f: 71, c: 317, note: TargetNote.none),
    );
    _check(
      '18. breastfeeding, feeling better',
      // BMR 480 + 968.75 - 140 - 161 = 1147.75 x 1.2 = 1377.3 + 505 = 1882.3.
      w: 48,
      h: 155,
      a: 28,
      goal: TrainingGoal.feelBetter,
      days: 3,
      minutes: 15,
      stage: TargetStage.breastfeeding,
      expected: (kcal: 1882, p: 77, f: 59, c: 261, note: TargetNote.none),
    );

    test('19. weight only: age falls back to 30 and she is an adult', () {
      // BMR 700 + 1000 - 150 - 161 = 1389 x 1.2 x 0.85 = 1416.8.
      final t = DailyTargets.compute(
        body: const BodyData(weightKg: 70),
        goal: TrainingGoal.loseSteadily,
      );
      expect((t.kcal, t.proteinG, t.fatG, t.carbsG), (1417, 112, 44, 143));
      expect(t.note, TargetNote.none);
      expect(t.usesDefaults, isTrue);
    });

    test('20. an eating-history answer: no target at all', () {
      final t = DailyTargets.compute(
        body: const BodyData(weightKg: 70, heightCm: 165, ageYears: 30),
        goal: TrainingGoal.loseSteadily,
        eatingHistory: true,
      );
      expect(t, const DailyTargets.withheld());
      expect(t.withheld, isTrue);
      expect(t.usesDefaults, isFalse);
    });
  });
}
