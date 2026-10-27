/// InBody body composition scan data model, deterministic OCR parser, and
/// nutrition target recommendations based on client goals and body metrics.
library;

enum ClientFitnessGoal {
  loseWeight,
  gainMuscle,
  bulk,
  stayInShape,
  generalFitness;

  static ClientFitnessGoal fromString(String? raw) {
    if (raw == null) return stayInShape;
    final r = raw.trim().toLowerCase();
    if (r.contains('lose') ||
        r.contains('fat') ||
        r.contains('weight') ||
        r.contains('cut') ||
        r.contains('تخسيس') ||
        r.contains('وزن')) {
      return loseWeight;
    }
    if (r.contains('bulk') || r.contains('ضخامة') || r.contains('تضخيم')) {
      return bulk;
    }
    if (r.contains('muscle') || r.contains('عضل')) {
      return gainMuscle;
    }
    return stayInShape;
  }
}

/// Structured measurements extracted from an InBody scan sheet.
class InBodyScan {
  const InBodyScan({
    this.weightKg,
    this.skeletalMuscleMassKg,
    this.bodyFatPercent,
    this.bmrKcal,
    this.heightCm,
    this.scanDate,
    this.rawText = '',
  });

  /// Weight in kilograms (e.g. 68.5).
  final double? weightKg;

  /// Skeletal Muscle Mass (SMM) in kilograms (e.g. 26.2).
  final double? skeletalMuscleMassKg;

  /// Percent Body Fat (PBF / %) (e.g. 24.5).
  final double? bodyFatPercent;

  /// Basal Metabolic Rate in calories (e.g. 1420).
  final int? bmrKcal;

  /// Height in centimeters (e.g. 165).
  final double? heightCm;

  /// Date printed on scan or when uploaded.
  final DateTime? scanDate;

  /// Raw OCR text for audit / re-parsing.
  final String rawText;

  bool get isEmpty =>
      weightKg == null &&
      skeletalMuscleMassKg == null &&
      bodyFatPercent == null &&
      bmrKcal == null;

  bool get isNotEmpty => !isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (weightKg != null) 'weightKg': weightKg,
    if (skeletalMuscleMassKg != null)
      'skeletalMuscleMassKg': skeletalMuscleMassKg,
    if (bodyFatPercent != null) 'bodyFatPercent': bodyFatPercent,
    if (bmrKcal != null) 'bmrKcal': bmrKcal,
    if (heightCm != null) 'heightCm': heightCm,
    if (scanDate != null) 'scanDate': scanDate!.toIso8601String(),
    if (rawText.isNotEmpty) 'rawText': rawText,
  };

  factory InBodyScan.fromJson(Map<String, dynamic> map) {
    return InBodyScan(
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      skeletalMuscleMassKg: (map['skeletalMuscleMassKg'] as num?)?.toDouble(),
      bodyFatPercent: (map['bodyFatPercent'] as num?)?.toDouble(),
      bmrKcal: (map['bmrKcal'] as num?)?.toInt(),
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      scanDate: map['scanDate'] is String
          ? DateTime.tryParse(map['scanDate'] as String)
          : null,
      rawText: map['rawText'] as String? ?? '',
    );
  }

  InBodyScan copyWith({
    double? weightKg,
    double? skeletalMuscleMassKg,
    double? bodyFatPercent,
    int? bmrKcal,
    double? heightCm,
    DateTime? scanDate,
    String? rawText,
  }) {
    return InBodyScan(
      weightKg: weightKg ?? this.weightKg,
      skeletalMuscleMassKg: skeletalMuscleMassKg ?? this.skeletalMuscleMassKg,
      bodyFatPercent: bodyFatPercent ?? this.bodyFatPercent,
      bmrKcal: bmrKcal ?? this.bmrKcal,
      heightCm: heightCm ?? this.heightCm,
      scanDate: scanDate ?? this.scanDate,
      rawText: rawText ?? this.rawText,
    );
  }
}

/// Pure deterministic OCR parser for InBody scan printouts.
///
/// Recognizes standard InBody 120/270/370/570/770 layouts across English and Arabic.
class InBodyOcrParser {
  const InBodyOcrParser._();

  /// Normalises Eastern-Arabic numerals (٠-٩) and decimal separators.
  static String normalizeNumbers(String input) {
    const eastern = '٠١٢٣٤٥٦٧٨٩';
    const western = '0123456789';
    var out = input;
    for (var i = 0; i < eastern.length; i++) {
      out = out.replaceAll(eastern[i], western[i]);
    }
    // Replace Arabic decimal separator (٫) and comma with dot when between digits
    out = out.replaceAllMapped(
      RegExp(r'(\d)[,٫](\d)'),
      (m) => '${m[1]}.${m[2]}',
    );
    return out;
  }

  /// Parses raw OCR text into structured [InBodyScan] metrics.
  static InBodyScan parse(String rawText) {
    if (rawText.trim().isEmpty) {
      return const InBodyScan();
    }

    final normalized = normalizeNumbers(rawText);
    final lines = normalized.split(RegExp(r'[\r\n]+'));

    double? weight;
    double? smm;
    double? bodyFat;
    int? bmr;
    double? height;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      final lower = line.toLowerCase();

      // 1. Weight (الوزن)
      if (weight == null) {
        if (lower.contains('weight') ||
            lower.contains('وزن') ||
            lower.contains('الوزن')) {
          final val = _extractNumberNear(line, lines, i, min: 30.0, max: 250.0);
          if (val != null) weight = val;
        }
      }

      // 2. Skeletal Muscle Mass (SMM / كتلة العضلات الهيكلية / كتلة العضل)
      if (smm == null) {
        if (lower.contains('smm') ||
            lower.contains('skeletal muscle') ||
            lower.contains('muscle mass') ||
            lower.contains('كتلة العضل') ||
            lower.contains('العضلات')) {
          final val = _extractNumberNear(line, lines, i, min: 10.0, max: 80.0);
          if (val != null) smm = val;
        }
      }

      // 3. Percent Body Fat (PBF / % Fat / نسبة الدهون)
      if (bodyFat == null) {
        if (lower.contains('pbf') ||
            lower.contains('percent body fat') ||
            lower.contains('fat %') ||
            lower.contains('fat percent') ||
            lower.contains('نسبة الدهون') ||
            lower.contains('الدهون %') ||
            (lower.contains('body fat') && !lower.contains('mass'))) {
          final val = _extractNumberNear(line, lines, i, min: 5.0, max: 65.0);
          if (val != null) bodyFat = val;
        }
      }

      // 4. BMR (Basal Metabolic Rate / معدل الحرق / الأيض الأساسي)
      if (bmr == null) {
        if (lower.contains('bmr') ||
            lower.contains('basal metabolic') ||
            lower.contains('معدل الحرق') ||
            lower.contains('الأيض الأساسي') ||
            lower.contains('الايض')) {
          final val = _extractNumberNear(
            line,
            lines,
            i,
            min: 800.0,
            max: 3500.0,
          );
          if (val != null) bmr = val.round();
        }
      }

      // 5. Height (الطول)
      if (height == null) {
        if (lower.contains('height') ||
            lower.contains('طول') ||
            lower.contains('الطول')) {
          final val = _extractNumberNear(
            line,
            lines,
            i,
            min: 120.0,
            max: 220.0,
          );
          if (val != null) height = val;
        }
      }
    }

    return InBodyScan(
      weightKg: weight,
      skeletalMuscleMassKg: smm,
      bodyFatPercent: bodyFat,
      bmrKcal: bmr,
      heightCm: height,
      scanDate: DateTime.now(),
      rawText: rawText,
    );
  }

  static double? _extractNumberNear(
    String currentLine,
    List<String> allLines,
    int index, {
    required double min,
    required double max,
  }) {
    // 1. Try numbers on the current line
    final currentMatches = RegExp(r'\b\d{1,4}(?:\.\d{1,2})?\b')
        .allMatches(currentLine);
    for (final m in currentMatches) {
      final val = double.tryParse(m.group(0)!);
      if (val != null && val >= min && val <= max) {
        return val;
      }
    }

    // 2. Try the next line (often OCR outputs label then value on next line)
    if (index + 1 < allLines.length) {
      final nextLine = allLines[index + 1].trim();
      final nextMatches = RegExp(r'\b\d{1,4}(?:\.\d{1,2})?\b')
          .allMatches(nextLine);
      for (final m in nextMatches) {
        final val = double.tryParse(m.group(0)!);
        if (val != null && val >= min && val <= max) {
          return val;
        }
      }
    }

    return null;
  }
}

/// Target nutritional recommendation based on InBody metrics and client goal.
class NutritionTargets {
  const NutritionTargets({
    required this.dailyCaloriesKcal,
    required this.dailyProteinGrams,
    required this.dailyCarbsGrams,
    required this.dailyFatGrams,
    required this.rationale,
  });

  final int dailyCaloriesKcal;
  final int dailyProteinGrams;
  final int dailyCarbsGrams;
  final int dailyFatGrams;
  final String rationale;
}

class InBodyTargetEstimator {
  const InBodyTargetEstimator._();

  /// Estimates recommended daily nutrition targets from body composition.
  static NutritionTargets estimate({
    required InBodyScan scan,
    required ClientFitnessGoal goal,
    int daysPerWeek = 4,
  }) {
    // Fallback baseline weight if not detected
    final weight = scan.weightKg ?? 65.0;

    // Estimate BMR if missing (Mifflin-St Jeor estimate for women)
    final bmr =
        scan.bmrKcal ??
        (10 * weight + 6.25 * (scan.heightCm ?? 163.0) - 5 * 28 - 161).round();

    // Activity multiplier based on training frequency
    final activityMultiplier = switch (daysPerWeek) {
      <= 2 => 1.25,
      <= 4 => 1.4,
      _ => 1.55,
    };

    final maintenanceKcal = (bmr * activityMultiplier).round();

    int targetKcal;
    double proteinMultiplier;
    String rationale;

    switch (goal) {
      case ClientFitnessGoal.loseWeight:
        // 350-500 kcal deficit, high protein (2.0-2.2g/kg) to preserve lean mass
        targetKcal = (maintenanceKcal - 400).clamp(1200, 3500);
        proteinMultiplier = 2.0;
        rationale =
            'Deficit for fat loss with high protein to protect lean muscle.';
        break;

      case ClientFitnessGoal.bulk:
        // 250-350 kcal surplus, 1.8-2.0g/kg protein
        targetKcal = (maintenanceKcal + 300).clamp(1500, 4000);
        proteinMultiplier = 1.9;
        rationale =
            'Caloric surplus for muscle hypertrophy and strength gains.';
        break;

      case ClientFitnessGoal.gainMuscle:
        // Slight surplus or maintenance with 2.0g/kg protein
        targetKcal = (maintenanceKcal + 150).clamp(1400, 3800);
        proteinMultiplier = 2.0;
        rationale = 'Lean muscle building with optimized protein synthesis.';
        break;

      case ClientFitnessGoal.stayInShape:
      case ClientFitnessGoal.generalFitness:
        // Maintenance calories, 1.6-1.8g/kg protein
        targetKcal = maintenanceKcal.clamp(1300, 3500);
        proteinMultiplier = 1.7;
        rationale =
            'Maintenance nutrition for balanced energy and body composition.';
        break;
    }

    final targetProteinG = (weight * proteinMultiplier).round().clamp(50, 250);

    // Fat: ~25-30% of total calories (9 kcal/g)
    final fatKcal = (targetKcal * 0.28).round();
    final targetFatG = (fatKcal / 9).round().clamp(35, 120);

    // Carbs: remainder of calories (4 kcal/g)
    final proteinKcal = targetProteinG * 4;
    final remainingKcal = targetKcal - proteinKcal - (targetFatG * 9);
    final targetCarbsG = (remainingKcal > 0 ? remainingKcal / 4 : 80)
        .round()
        .clamp(50, 500);

    return NutritionTargets(
      dailyCaloriesKcal: targetKcal,
      dailyProteinGrams: targetProteinG,
      dailyCarbsGrams: targetCarbsG,
      dailyFatGrams: targetFatG,
      rationale: rationale,
    );
  }
}
