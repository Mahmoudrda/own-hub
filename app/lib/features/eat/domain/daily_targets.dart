/// What a day of eating is measured against: kcal, protein, carbs, fat, fibre.
///
/// Mifflin-St Jeor for women, scaled by how much she trains, nudged by her
/// goal. The figures are an estimate to aim at, never a limit: E01 shows what
/// she has eaten against them and nothing counts down.
///
/// Body data is optional (D31, local only). Whatever is missing falls back to
/// [defaultWeightKg], [defaultHeightCm] and [defaultAgeYears], and
/// [usesDefaults] says so, so the screen can offer to personalise.
///
/// Whether a figure may exist at all, and how low it may go, is
/// [TargetSafety]'s: a floor, no weight-loss goal under 18, while pregnant or
/// after a birth, and no target whatever for an eating-history answer.
library;

import 'package:meta/meta.dart';

import '../../../domain/nutrition/target_safety.dart';
import '../../onboarding/domain/body_data.dart';
import '../../onboarding/domain/intake.dart' show TrainingGoal;

@immutable
class DailyTargets {
  const DailyTargets({
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.usesDefaults,
    this.note = TargetNote.none,
  });

  /// No target at all: an eating-history answer. Every figure is zero and
  /// [withheld] is true, so a screen that forgets to ask draws a dash, not a
  /// number she could aim at.
  const DailyTargets.withheld()
    : kcal = 0,
      proteinG = 0,
      carbsG = 0,
      fatG = 0,
      fiberG = 0,
      usesDefaults = false,
      note = TargetNote.withheld;

  static const double defaultWeightKg = 60;
  static const int defaultHeightCm = 160;
  static const int defaultAgeYears = 30;

  /// Protein per kilo of body weight. Stronger asks for more, and building
  /// muscle a little more again.
  static const double proteinPerKg = 1.6;
  static const double proteinPerKgStronger = 1.8;
  static const double proteinPerKgMuscle = 1.9;

  static const int fiberTargetG = 25;

  /// Goal adjustments on top of maintenance.
  static const double loseAdjust = 0.85;
  static const double strongerAdjust = 1.05;

  /// What the day's energy is worked out for, from the weekly minutes she
  /// trains: under an hour a week is the sedentary 1.2, and 5 hours or more
  /// is 1.725. The bands in between are the standard 1.375 and 1.55.
  static double activityFactor({
    required int daysPerWeek,
    required int minutesPerSession,
  }) {
    final weekly = daysPerWeek.clamp(0, 7) * minutesPerSession.clamp(0, 600);
    if (weekly < 60) return 1.2;
    if (weekly < 150) return 1.375;
    if (weekly < 300) return 1.55;
    return 1.725;
  }

  factory DailyTargets.compute({
    BodyData body = BodyData.empty,
    TrainingGoal goal = TrainingGoal.stronger,
    int daysPerWeek = 3,
    int minutesPerSession = 15,
    TargetStage stage = TargetStage.none,
    int? trimester,
    bool eatingHistory = false,
    double? bmrKcal,
  }) {
    if (eatingHistory) return const DailyTargets.withheld();
    final weight = body.weightKg ?? defaultWeightKg;
    final height = (body.heightCm ?? defaultHeightCm).toDouble();
    final age = (body.ageYears ?? defaultAgeYears).toDouble();

    // A measured rate (an InBody sheet's) stands in for the formula.
    final bmr = bmrKcal ?? 10 * weight + 6.25 * height - 5 * age - 161;
    final factor = activityFactor(
      daysPerWeek: daysPerWeek,
      minutesPerSession: minutesPerSession,
    );
    final adjust = switch (goal) {
      TrainingGoal.loseSteadily => loseAdjust,
      TrainingGoal.stronger || TrainingGoal.buildMuscle => strongerAdjust,
      TrainingGoal.feelBetter || TrainingGoal.backIntoIt => 1.0,
    };
    final energy = TargetSafety.energy(
      maintenanceKcal: bmr * factor,
      goalFactor: adjust,
      ageYears: body.ageYears,
      stage: stage,
      trimester: trimester,
    );
    final kcal = energy.kcal;

    final perKg = switch (goal) {
      TrainingGoal.buildMuscle => proteinPerKgMuscle,
      TrainingGoal.stronger => proteinPerKgStronger,
      TrainingGoal.loseSteadily ||
      TrainingGoal.feelBetter ||
      TrainingGoal.backIntoIt => proteinPerKg,
    };
    final macros = TargetSafety.macros(
      kcal: kcal,
      weightKg: weight,
      proteinPerKg: perKg,
      stage: stage,
    );

    return DailyTargets(
      kcal: kcal,
      proteinG: macros.proteinG,
      carbsG: macros.carbsG,
      fatG: macros.fatG,
      fiberG: fiberTargetG,
      usesDefaults: !body.isComplete,
      note: energy.note,
    );
  }

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;

  /// True when any of weight, height and age was missing, so the figures rest
  /// on the stated defaults.
  final bool usesDefaults;

  /// Why these figures are not the ones her body data alone would give.
  final TargetNote note;

  /// True when she has no calorie or macro target. Her coach sets her food.
  bool get withheld => note == TargetNote.withheld;

  @override
  bool operator ==(Object other) =>
      other is DailyTargets &&
      other.kcal == kcal &&
      other.proteinG == proteinG &&
      other.carbsG == carbsG &&
      other.fatG == fatG &&
      other.fiberG == fiberG &&
      other.usesDefaults == usesDefaults &&
      other.note == note;

  @override
  int get hashCode =>
      Object.hash(kcal, proteinG, carbsG, fatG, fiberG, usesDefaults, note);
}
