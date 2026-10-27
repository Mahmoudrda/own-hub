/// The one place that decides whether a calorie or macro target may exist, and
/// how low or high it may go. Every screen that shows or suggests a target
/// reads it through here (`DailyTargets.compute` on the phone, the coach's meal
/// goal on the composer), and `functions/coaching/plans.py` repeats the same
/// numbers for the server.
///
/// Pure arithmetic on primitives. It imports nothing from `features/`.
///
/// ## The rules (owner decisions 1 and 2, 27 Oct 2026)
///
///  * No target below [floorKcal] for anyone, and none above [ceilingKcal].
///  * No calorie deficit under 18, while pregnant, or after a birth (she may be
///    breastfeeding, and the app cannot rule it out). The goal is worked out as
///    maintenance and the screen says to ask her doctor.
///  * Extra energy while pregnant and while breastfeeding, so a protected
///    target is never a maintenance figure alone. FAO/WHO/UNU 2004, *Human
///    energy requirements*, adequately nourished women: +85, +285 and +475 kcal
///    a day in the first, second and third trimester; +505 kcal a day in the
///    first six months of exclusive breastfeeding.
///  * Protein at most [maxProteinPerKg] a kilo and [maxProteinShare] of the
///    day's energy. Fat stays between [minFatShare] and [maxFatShare]. Carbs
///    never drop below the adult RDA ([carbsMinG]; 175 g pregnant, 210 g
///    breastfeeding, Institute of Medicine 2005).
///  * An eating-history answer withholds every calorie and macro target: she is
///    pointed to her coach instead.
///
/// The order is pinned by test: maintenance, then the goal's adjustment unless
/// she is protected, then the stage's extra, then the floor and the ceiling.
///
/// The figures are an estimate to aim at. Whether they are the right ones for
/// a given body is a dietitian's call (decision 6), not this file's.
library;

import 'dart:math' as math;

/// What the targets must allow for. Wire names are the ones `Intake.lifeStage`
/// already stores.
enum TargetStage {
  none,

  /// Any time after a birth. Breastfeeding is not asked, so this is treated as
  /// a possible one: no deficit, and no extra energy it cannot be sure of.
  postpartum,
  pregnant,

  /// Breastfeeding, when something actually says so.
  breastfeeding;

  static TargetStage fromWire(String? wire) => switch (wire) {
    'pregnant' => pregnant,
    'postpartum' => postpartum,
    'breastfeeding' => breastfeeding,
    _ => none,
  };

  bool get isProtected => this != none;

  /// The stricter of two stages, for a woman who answered in two places.
  TargetStage orStricter(TargetStage other) =>
      other.index > index ? other : this;
}

/// Why a figure is not the one her body data alone would give.
enum TargetNote {
  none,

  /// Raised to [TargetSafety.floorKcal].
  floor,

  /// A weight-loss goal under 18: worked out as maintenance.
  noDeficitMinor,

  /// A weight-loss goal while pregnant or after a birth: worked out as
  /// maintenance, with her doctor named.
  noDeficitStage,

  /// An eating-history answer: no target at all.
  withheld,
}

class SafeEnergy {
  const SafeEnergy(this.kcal, this.note);

  final int kcal;
  final TargetNote note;
}

typedef SafeMacros = ({int proteinG, int fatG, int carbsG});

/// What is wrong with a goal a coach typed, if anything.
enum GoalProblem {
  belowFloor,
  aboveCeiling,

  /// Pregnant or after a birth: a goal under [TargetSafety.stageGoalFloorKcal]
  /// is a deficit the app does not set.
  belowStageFloor,

  /// More protein than [TargetSafety.maxProteinShare] of the day's energy.
  proteinTooHigh,
}

abstract final class TargetSafety {
  static const int adultAgeYears = 18;

  static const int floorKcal = 1200;
  static const int ceilingKcal = 4000;

  /// The lowest goal a coach may set for a pregnant or postpartum client. The
  /// server has no body data (D31), so it cannot compute her maintenance; this
  /// keeps a deficit-sized figure from going out. To be confirmed by the
  /// dietitian.
  static const int stageGoalFloorKcal = 1800;

  static const double maxProteinPerKg = 2.0;
  static const double minProteinPerKg = 0.8;
  static const double maxProteinShare = 0.35;

  static const double minFatShare = 0.20;
  static const double defaultFatShare = 0.28;
  static const double maxFatShare = 0.35;

  static const int carbsMinG = 130;
  static const int carbsMinPregnantG = 175;
  static const int carbsMinBreastfeedingG = 210;

  static const int lactationExtraKcal = 505;
  static const Map<int, int> pregnancyExtraKcal = {1: 85, 2: 285, 3: 475};

  static bool isMinor(int? ageYears) =>
      ageYears != null && ageYears < adultAgeYears;

  static bool deficitAllowed({
    int? ageYears,
    TargetStage stage = TargetStage.none,
  }) => !isMinor(ageYears) && !stage.isProtected;

  /// Extra kcal a day for [stage]. An unknown trimester takes the first, the
  /// smallest, so the target never overshoots.
  static int stageExtraKcal(TargetStage stage, {int? trimester}) =>
      switch (stage) {
        TargetStage.pregnant =>
          pregnancyExtraKcal[(trimester ?? 1).clamp(1, 3)]!,
        TargetStage.breastfeeding => lactationExtraKcal,
        TargetStage.postpartum || TargetStage.none => 0,
      };

  static int carbsMinFor(TargetStage stage) => switch (stage) {
    TargetStage.pregnant => carbsMinPregnantG,
    TargetStage.breastfeeding => carbsMinBreastfeedingG,
    TargetStage.postpartum || TargetStage.none => carbsMinG,
  };

  /// The day's energy from [maintenanceKcal] and the goal's factor (below 1 is
  /// a deficit).
  static SafeEnergy energy({
    required double maintenanceKcal,
    required double goalFactor,
    int? ageYears,
    TargetStage stage = TargetStage.none,
    int? trimester,
  }) {
    final blocked =
        goalFactor < 1 && !deficitAllowed(ageYears: ageYears, stage: stage);
    final raw =
        maintenanceKcal * (blocked ? 1.0 : goalFactor) +
        stageExtraKcal(stage, trimester: trimester);
    final kcal = raw.round();
    final blockedNote = isMinor(ageYears)
        ? TargetNote.noDeficitMinor
        : TargetNote.noDeficitStage;
    if (kcal < floorKcal) {
      return SafeEnergy(floorKcal, blocked ? blockedNote : TargetNote.floor);
    }
    return SafeEnergy(
      kcal > ceilingKcal ? ceilingKcal : kcal,
      blocked ? blockedNote : TargetNote.none,
    );
  }

  /// Protein, fat and carbs for [kcal], wanting [proteinPerKg] a kilo. Protein
  /// is held to [maxProteinPerKg] and [maxProteinShare]; fat starts at
  /// [defaultFatShare] and gives way, down to [minFatShare], and then protein
  /// does, so carbs reach their minimum. Carbs are what is left.
  static SafeMacros macros({
    required int kcal,
    required double weightKg,
    required double proteinPerKg,
    TargetStage stage = TargetStage.none,
  }) {
    final carbsMin = carbsMinFor(stage);
    var protein = math.min(
      math.min(proteinPerKg, maxProteinPerKg) * weightKg,
      maxProteinShare * kcal / 4,
    );
    var fatKcal = defaultFatShare * kcal;
    if ((kcal - 4 * protein - fatKcal) / 4 < carbsMin) {
      fatKcal = math.max(minFatShare * kcal, kcal - 4 * protein - 4 * carbsMin);
      if ((kcal - 4 * protein - fatKcal) / 4 < carbsMin) {
        protein = math.max(
          minProteinPerKg * weightKg,
          (kcal - fatKcal - 4 * carbsMin) / 4,
        );
      }
    }
    final p = protein.round();
    final f = (fatKcal / 9).round();
    final c = ((kcal - p * 4 - f * 9) / 4).round();
    return (proteinG: p, fatG: f, carbsG: c < 0 ? 0 : c);
  }

  /// What is wrong with a goal of [kcal] and [proteinG], or null. The coach
  /// composer and `plans.py` apply the same tests.
  static GoalProblem? goalProblem({
    required int kcal,
    required int proteinG,
    TargetStage stage = TargetStage.none,
  }) {
    if (kcal < floorKcal) return GoalProblem.belowFloor;
    if (kcal > ceilingKcal) return GoalProblem.aboveCeiling;
    if (stage.isProtected && kcal < stageGoalFloorKcal) {
      return GoalProblem.belowStageFloor;
    }
    if (proteinG * 4 > maxProteinShare * kcal) {
      return GoalProblem.proteinTooHigh;
    }
    return null;
  }
}
