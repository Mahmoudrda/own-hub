/// A starting point for a coached client's day, from the InBody numbers she
/// chose to send with her request.
///
/// There is no arithmetic of its own here: the figures come from
/// [DailyTargets.compute], the same code Eat uses, with her sheet's measured
/// metabolic rate in place of the formula, and every floor, ceiling and
/// refusal is [TargetSafety]'s. It offers nothing for a client who is
/// pregnant or after a birth, nothing when her answers withhold targets, and
/// nothing when the sheet lacks her weight or her metabolic rate (the formula
/// would need an age and a height this request does not carry).
library;

import '../../../domain/nutrition/target_safety.dart';
import '../../eat/domain/daily_targets.dart';
import '../../onboarding/domain/body_data.dart';
import '../../onboarding/domain/intake.dart' show TrainingGoal;
import 'inbody_scan.dart';
import 'subscription.dart' show Intake;

enum InBodySuggestionState {
  /// Figures are offered.
  ready,

  /// She is pregnant or after a birth: her coach sets her food with her doctor.
  protectedStage,

  /// An eating-history answer: no calorie or macro target for her.
  withheld,

  /// The sheet does not carry what a safe figure needs.
  notEnough,
}

class InBodySuggestion {
  const InBodySuggestion(this.state, [this.kcal = 0, this.proteinG = 0]);

  final InBodySuggestionState state;
  final int kcal;
  final int proteinG;

  bool get isReady => state == InBodySuggestionState.ready;
}

abstract final class InBodyTargets {
  /// Minutes a coached session takes, for the activity factor.
  static const int sessionMinutes = 45;

  static TrainingGoal _goal(String wire) => switch (wire) {
    'loseSteadily' => TrainingGoal.loseSteadily,
    'buildMuscle' => TrainingGoal.buildMuscle,
    'stronger' => TrainingGoal.stronger,
    _ => TrainingGoal.feelBetter,
  };

  static InBodySuggestion suggest(InBodyScan scan, Intake intake) {
    if (intake.eatingHistoryFlag) {
      return const InBodySuggestion(InBodySuggestionState.withheld);
    }
    final stage = TargetStage.fromWire(intake.lifeStage);
    if (stage.isProtected) {
      return const InBodySuggestion(InBodySuggestionState.protectedStage);
    }
    final weight = scan.weightKg;
    final bmr = scan.bmrKcal;
    if (weight == null || bmr == null) {
      return const InBodySuggestion(InBodySuggestionState.notEnough);
    }
    final targets = DailyTargets.compute(
      body: BodyData(weightKg: weight),
      goal: _goal(intake.goal),
      daysPerWeek: intake.daysPerWeek.clamp(1, 7),
      minutesPerSession: sessionMinutes,
      bmrKcal: bmr.toDouble(),
    );
    if (TargetSafety.goalProblem(
          kcal: targets.kcal,
          proteinG: targets.proteinG,
        ) !=
        null) {
      return const InBodySuggestion(InBodySuggestionState.notEnough);
    }
    return InBodySuggestion(
      InBodySuggestionState.ready,
      targets.kcal,
      targets.proteinG,
    );
  }
}
