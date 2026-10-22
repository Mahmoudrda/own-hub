/// Words the plan screens share, so the coach's preview and the client's view
/// say the same thing.
library;

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../train/domain/workout_library.dart';
import '../../domain/coach_plan.dart';
import 'coach_plan_logic.dart';

final RegExp _numberedDay = RegExp(
  r'^(?:Day|\u064A\u0648\u0645|\u0627\u0644\u064A\u0648\u0645)\s*(\d{1,2})$',
);

/// A meal-plan day in the reader's language: "Day 3" written by an English
/// coach reads "يوم 3" to an Arabic reader. A day she named herself stays.
String mealDayLabel(AppL10n l10n, String label) {
  final m = _numberedDay.firstMatch(label.trim());
  return m == null ? label : l10n.dayNumber(m.group(1)!);
}

String slotLabel(AppL10n l10n, String slot) => switch (slot) {
  'breakfast' => l10n.breakfast,
  'lunch' => l10n.lunch,
  'dinner' => l10n.dinner,
  'snack' => l10n.snack,
  _ => slot,
};

String problemText(AppL10n l10n, PlanProblem problem) => switch (problem) {
  PlanProblem.noName => l10n.giveThePlanANameFirst,
  PlanProblem.noDays => l10n.addAtLeastOneDayFirst,
  PlanProblem.tooManyDays || PlanProblem.tooBig => l10n.thisPlanIsTooBigToSend,
  PlanProblem.unknownMove => l10n.aMoveInThisPlanIsNot,
};

/// "3 x 10" or "3 x 30 seconds".
String moveAmount(AppL10n l10n, AuthoredMove m) => m.holdSeconds == null
    ? l10n.setsReps(countLabel(m.sets), countLabel(m.reps ?? 0))
    : l10n.setsSecondsSeconds(countLabel(m.sets), countLabel(m.holdSeconds!));

/// How much of a meal item: servings, or grams. Empty for a free line.
String itemAmount(AppL10n l10n, MealItem item) => switch (item.kind) {
  MealItemKind.recipe => l10n.servingsN(_servings(item.servings ?? 1)),
  MealItemKind.food => l10n.gramsG_1usqy(countLabel(item.grams ?? 0)),
  MealItemKind.free => '',
};

String _servings(double v) {
  final whole = v == v.roundToDouble();
  return whole ? v.round().toString() : v.toString();
}

String dayNutritionLine(AppL10n l10n, Nutrition n) => l10n
    .aboutKcalKcalProteinGProtein(countLabel(n.kcal), countLabel(n.proteinG));
