import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';

void main() {
  group('InBodyOcrParser', () {
    test('parses standard English InBody 270 scan printout', () {
      const sample = '''
      InBody 270 Result Sheet
      ID: 10482
      Height: 164.0 cm
      Age: 27
      Gender: Female
      
      Body Composition Analysis
      Weight: 64.5 kg
      SMM (Skeletal Muscle Mass): 24.8 kg
      Body Fat Mass: 17.2 kg
      Percent Body Fat (PBF): 26.6 %
      
      Obesity Analysis
      BMI: 24.0 kg/m2
      
      Research Parameters
      Basal Metabolic Rate (BMR): 1340 kcal
      Target Heart Rate: 135
      ''';

      final scan = InBodyOcrParser.parse(sample);
      expect(scan.weightKg, 64.5);
      expect(scan.skeletalMuscleMassKg, 24.8);
      expect(scan.bodyFatPercent, 26.6);
      expect(scan.bmrKcal, 1340);
      expect(scan.heightCm, 164.0);
    });

    test('parses Arabic InBody printout with Eastern Arabic numerals', () {
      const arabicSample = '''
      تقرير فحص تركيب الجسم InBody
      الطول: ١٦٨٫٠ سم
      الوزن: ٧٢٫٥ كجم
      كتلة العضلات الهيكلية: ٢٨٫٢ كجم
      نسبة الدهون: ٢٣٫٥ %
      معدل الحرق (BMR): ١٤٨٠ سعر
      ''';

      final scan = InBodyOcrParser.parse(arabicSample);
      expect(scan.weightKg, 72.5);
      expect(scan.skeletalMuscleMassKg, 28.2);
      expect(scan.bodyFatPercent, 23.5);
      expect(scan.bmrKcal, 1480);
      expect(scan.heightCm, 168.0);
    });

    test('handles two-line label and value pairs', () {
      const twoLineSample = '''
      Weight
      68.0
      SMM
      26.5
      Percent Body Fat
      22.0
      BMR
      1420
      ''';

      final scan = InBodyOcrParser.parse(twoLineSample);
      expect(scan.weightKg, 68.0);
      expect(scan.skeletalMuscleMassKg, 26.5);
      expect(scan.bodyFatPercent, 22.0);
      expect(scan.bmrKcal, 1420);
    });

    test('handles empty or garbage text safely without throwing', () {
      final empty = InBodyOcrParser.parse('');
      expect(empty.isEmpty, isTrue);

      final garbage = InBodyOcrParser.parse('random words 123 nothing here');
      expect(garbage.weightKg, isNull);
      expect(garbage.skeletalMuscleMassKg, isNull);
    });
  });

  group('InBodyTargetEstimator', () {
    test('calculates weight loss / deficit targets with high protein', () {
      const scan = InBodyScan(weightKg: 70.0, heightCm: 165.0, bmrKcal: 1400);

      final targets = InBodyTargetEstimator.estimate(
        scan: scan,
        goal: ClientFitnessGoal.loseWeight,
        daysPerWeek: 4,
      );

      // 1400 * 1.4 = 1960 maintenance - 400 = ~1560 kcal
      expect(targets.dailyCaloriesKcal, closeTo(1560, 50));
      // 70kg * 2.0 = 140g protein
      expect(targets.dailyProteinGrams, 140);
      expect(targets.dailyCarbsGrams, greaterThan(50));
      expect(targets.dailyFatGrams, greaterThan(30));
    });

    test('calculates muscle gain / bulk targets with surplus', () {
      const scan = InBodyScan(weightKg: 60.0, heightCm: 160.0, bmrKcal: 1300);

      final targets = InBodyTargetEstimator.estimate(
        scan: scan,
        goal: ClientFitnessGoal.bulk,
        daysPerWeek: 4,
      );

      // 1300 * 1.4 = 1820 + 300 = ~2120 kcal
      expect(targets.dailyCaloriesKcal, closeTo(2120, 50));
      expect(targets.dailyProteinGrams, closeTo(114, 10));
    });
  });
}
