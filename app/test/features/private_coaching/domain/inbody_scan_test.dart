import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/private_coaching/domain/inbody_scan.dart';

InBodyReading read(String text) => InBodyReader.read(text);

void main() {
  group('reading a result sheet', () {
    test('an English sheet, every figure on its own labelled line', () {
      final r = read('''
InBody 270 Result Sheet
ID: 10482
Height: 164.0 cm
Age: 27
Gender: Female
Weight: 64.5 kg
SMM (Skeletal Muscle Mass): 24.8 kg
Body Fat Mass: 17.2 kg
Percent Body Fat (PBF): 26.6 %
BMI: 24.0 kg/m2
Basal Metabolic Rate (BMR): 1340 kcal
Target Heart Rate: 135
''');
      expect(r.scan.weightKg, 64.5);
      expect(r.scan.heightCm, 164.0);
      expect(r.scan.skeletalMuscleMassKg, 24.8);
      expect(r.scan.bodyFatPercent, 26.6);
      expect(r.scan.bmrKcal, 1340);
      expect(r.checks, isEmpty, reason: 'a sheet that agrees with itself');
    });

    test('an Arabic sheet with Arabic-Indic digits and decimal marks', () {
      final r = read('''
تقرير فحص تركيب الجسم InBody
الطول: ١٦٨٫٠ سم
الوزن: ٧٢٫٥ كجم
كتلة العضلات الهيكلية: ٢٨٫٢ كجم
نسبة الدهون: ٢٣٫٥ %
معدل الحرق (BMR): ١٤٨٠ سعر
''');
      expect(r.scan.weightKg, 72.5);
      expect(r.scan.heightCm, 168.0);
      expect(r.scan.skeletalMuscleMassKg, 28.2);
      expect(r.scan.bodyFatPercent, 23.5);
      expect(r.scan.bmrKcal, 1480);
    });

    test('Persian digits read the same as Arabic-Indic ones', () {
      final r = read('الوزن: ۷۲٫۵ كجم\nمعدل الحرق ۱۴۸۰');
      expect(r.scan.weightKg, 72.5);
      expect(r.scan.bmrKcal, 1480);
    });

    test('a unit glued to its number does not truncate it', () {
      final r = read('Weight 64.5kg\nHeight 164.5cm\nBMR 1340kcal\nPBF 26.6%');
      expect(r.scan.weightKg, 64.5);
      expect(r.scan.heightCm, 164.5);
      expect(r.scan.bmrKcal, 1340);
      expect(r.scan.bodyFatPercent, 26.6);
    });

    test('thousands separators and comma decimals', () {
      expect(read('BMR: 1,340 kcal\nPBF 26.6').scan.bmrKcal, 1340);
      expect(read('معدل الحرق: ١٬٣٤٠ سعر\nPBF 26.6').scan.bmrKcal, 1340);
      final r = read('Weight 64,5 kg\nPBF 26,6 %');
      expect(r.scan.weightKg, 64.5);
      expect(r.scan.bodyFatPercent, 26.6);
    });

    test('a weight in pounds is converted and flagged', () {
      final r = read('Weight: 142.3 lb\nPBF 26.6 %');
      expect(r.scan.weightKg, 64.5);
      expect(r.checks, contains(InBodyCheck.weightFromPounds));
      expect(
        read('Weight 142.3 lbs\nPBF 26.6').scan.weightKg,
        64.5,
        reason: 'lbs as well as lb',
      );
    });

    test('two labels on one line each take the number after their own', () {
      final r = read('BMI 24.0 kg/m2   PBF 26.6 %');
      expect(r.scan.bodyFatPercent, 26.6, reason: 'not the BMI');
      final both = read('Weight 64.5 kg   Height 164 cm   PBF 26.6 %');
      expect(both.scan.weightKg, 64.5);
      expect(both.scan.heightCm, 164);
    });

    test('a label never borrows the number of another label\'s row', () {
      final r = read('Percent Body Fat\nWeight 64.5 kg\nBMR 1340 kcal');
      expect(r.scan.bodyFatPercent, isNull);
      expect(r.scan.weightKg, 64.5);

      final arabic = read(
        'كتلة العضلات الهيكلية\nالوزن 64.5 كجم\nمعدل الحرق 1480 سعر',
      );
      expect(arabic.scan.skeletalMuscleMassKg, isNull);
      expect(arabic.scan.weightKg, 64.5);
    });

    test('ideal, target and control rows are not her weight', () {
      final r = read('''
Ideal Weight 55.0
Target Weight 58.0
Weight Control -6.5
Weight 64.5 kg
PBF 26.6 %
''');
      expect(r.scan.weightKg, 64.5);
    });

    test('a chart axis on the label line is not a weight', () {
      final r = read('''
Weight 55 70 85 100 115 130 145 160 175 190 205
64.5 kg
PBF 26.6 %
''');
      expect(r.scan.weightKg, 64.5);
    });

    test('a normal range beside a figure does not replace it', () {
      final r = read('Weight 64.5 kg  Normal Range 50.0 - 70.0\nPBF 26.6');
      expect(r.scan.weightKg, 64.5);
    });

    test('the label above its value and the label below it both read', () {
      final above = read('Weight\n68.0\nSMM\n26.5\nPercent Body Fat\n24.5');
      expect(above.scan.weightKg, 68.0);
      expect(above.scan.skeletalMuscleMassKg, 26.5);
      expect(above.scan.bodyFatPercent, 24.5);

      final below = read('68.0 kg\nWeight\n26.5 kg\nSMM\n24.5 %\nPBF');
      expect(below.scan.weightKg, 68.0);
      expect(below.scan.skeletalMuscleMassKg, 26.5);
      expect(below.scan.bodyFatPercent, 24.5);
    });

    test(
      'a row of labels with a row of values reads nothing it cannot pair',
      () {
        final r = read('Weight  SMM  PBF\n64.5  24.8  26.6\nBMR 1340 kcal');
        expect(r.scan.weightKg, isNull);
        expect(r.scan.skeletalMuscleMassKg, isNull);
        expect(r.scan.bodyFatPercent, isNull);
        expect(r.scan.bmrKcal, 1340);
      },
    );

    test('a page with no InBody-only figure is not a sheet', () {
      final r = read('Lab report\nWeight 70 kg\nHeight 165 cm\nBMI 25.7');
      expect(r.scan.isEmpty, isTrue);
    });

    test('numbers outside any plausible range are dropped', () {
      final r = read(
        'Weight 64.5 kg\nSMM 9.0 kg\nPBF 4.9 %\nBMR 799 kcal\nBody Fat Mass 17 kg',
      );
      expect(r.scan.skeletalMuscleMassKg, isNull);
      expect(r.scan.bodyFatPercent, isNull);
      expect(r.scan.bmrKcal, isNull);
      expect(read('Weight 64.5\nPBF 66 %').scan.bodyFatPercent, isNull);
    });

    test('a height in feet and inches is not turned into a number', () {
      final r = read('Height: 5\'4"\nWeight 64.5 kg\nPBF 26.6');
      expect(r.scan.heightCm, isNull);
    });

    test('an id or a date is never read as a figure', () {
      final r = read('ID 10482\n2026.10.24 09:15\nWeight 64.5 kg\nPBF 26.6');
      expect(r.scan.weightKg, 64.5);
      expect(r.scan.heightCm, isNull);
    });

    test('empty and unreadable text give nothing, and do not throw', () {
      expect(read('').scan.isEmpty, isTrue);
      expect(read('   \n \n').scan.isEmpty, isTrue);
      expect(read('Weight kg PBF %').scan.isEmpty, isTrue);
    });
  });

  group('the sheet is checked against itself', () {
    test('weight, height and BMI that disagree are flagged', () {
      final r = read('Weight 64.5 kg\nHeight 174 cm\nBMI 24.0\nPBF 26.6');
      expect(r.checks, contains(InBodyCheck.bmiDisagrees));
      expect(
        r.fieldsToCheck,
        containsAll([InBodyField.weight, InBodyField.height]),
      );
      expect(
        read('Weight 64.5 kg\nHeight 164 cm\nBMI 24.0\nPBF 26.6').checks,
        isEmpty,
      );
    });

    test('fat mass that does not match weight and body fat is flagged', () {
      final r = read('Weight 64.5 kg\nBody Fat Mass 25 kg\nPBF 26.6 %');
      expect(r.checks, contains(InBodyCheck.compositionDisagrees));
      expect(
        r.fieldsToCheck,
        containsAll([InBodyField.weight, InBodyField.bodyFat]),
      );
    });

    test('weight minus fat mass must equal the fat-free mass', () {
      final r = read(
        'Weight 64.5 kg\nBody Fat Mass 17.2 kg\nFat Free Mass 47.3 kg',
      );
      expect(r.checks, isEmpty);
      final off = read(
        'Weight 64.5 kg\nBody Fat Mass 17.2 kg\nFat Free Mass 40.0 kg',
      );
      expect(off.checks, contains(InBodyCheck.compositionDisagrees));
    });
  });

  group('rows from text recognition', () {
    InBodyLine box(String text, double left, double top) =>
        InBodyLine(text, left, top, left + 80, top + 20);

    test('boxes at one height become one row, left to right', () {
      final text = InBodyReader.rows([
        box('64.5 kg', 200, 102),
        box('Weight', 10, 100),
        box('PBF', 10, 140),
        box('26.6 %', 200, 141),
      ]);
      expect(text, 'Weight  64.5 kg\nPBF  26.6 %');
    });

    test('boxes at different heights stay on their own rows', () {
      final text = InBodyReader.rows([
        box('Weight', 10, 100),
        box('64.5 kg', 10, 130),
      ]);
      expect(text, 'Weight\n64.5 kg');
    });

    test('no boxes, no text', () {
      expect(InBodyReader.rows(const []), '');
    });
  });

  group('what is kept', () {
    test(
      'only the five numbers go on the wire, never text read from a photo',
      () {
        const scan = InBodyScan(
          weightKg: 64.5,
          heightCm: 164,
          bodyFatPercent: 26.6,
          skeletalMuscleMassKg: 24.8,
          bmrKcal: 1340,
        );
        expect(scan.toJson(), {
          'weightKg': 64.5,
          'heightCm': 164.0,
          'bodyFatPercent': 26.6,
          'skeletalMuscleMassKg': 24.8,
          'bmrKcal': 1340,
        });
        expect(const InBodyScan(weightKg: 60).toJson(), {'weightKg': 60.0});
      },
    );

    test('a stored scan with a wrong type or range reads as missing', () {
      final scan = InBodyScan.fromJson(<String, Object?>{
        'weightKg': '64.5',
        'heightCm': 500,
        'bodyFatPercent': true,
        'skeletalMuscleMassKg': 24.8,
        'bmrKcal': 1340.4,
        'rawText': 'Weight 64.5 kg',
      });
      expect(scan.weightKg, isNull);
      expect(scan.heightCm, isNull);
      expect(scan.bodyFatPercent, isNull);
      expect(scan.skeletalMuscleMassKg, 24.8);
      expect(scan.bmrKcal, 1340);
    });

    test('a round trip keeps every number', () {
      const scan = InBodyScan(weightKg: 64.5, bmrKcal: 1340);
      expect(InBodyScan.fromJson(Map<String, Object?>.of(scan.toJson())), scan);
    });
  });
}
