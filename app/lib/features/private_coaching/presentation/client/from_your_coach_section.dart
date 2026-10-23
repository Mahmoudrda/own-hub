/// Eat: today's meals from her coach, each with a one-tap log.
///
/// The log goes out through [onLog], so the app's allergy guard and undo run
/// as they do for any meal. A marked item says what it holds.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_card.dart';
import '../../../eat/domain/allergy_guard.dart';
import '../../domain/coach_plan.dart';
import '../../domain/coaching_contract.dart';
import '../plans/coach_plan_logic.dart';
import '../plans/plan_labels.dart';
import 'coach_meal_row.dart';
import 'coach_today.dart';

class FromYourCoachSection extends StatelessWidget {
  FromYourCoachSection({
    super.key,
    required this.plan,
    required this.now,
    this.constraints = DietaryConstraints.unknown,
    MealCatalog? catalog,
    this.onLog,
    this.onOpenRecipe,
    this.onOpenPlan,
  }) : catalog = catalog ?? MealCatalog();

  /// A meal plan her coach shared.
  final CoachPlan plan;
  final DateTime now;
  final DietaryConstraints constraints;
  final MealCatalog catalog;

  /// Logs one item into [slot] of today.
  final void Function(MealItem item, String slot)? onLog;
  final void Function(String recipeId)? onOpenRecipe;
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final meal = plan.meal;
    final d = todaysMealDay(plan, now);
    if (meal == null || d == null) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    final day = meal.days[d];
    final flags = flagMealPlan(MealPlanBody(days: [day]), constraints, catalog);
    MealFlag? flagOf(String slot, int i) {
      for (final f in flags) {
        if (f.slot == slot && f.index == i) return f;
      }
      return null;
    }

    return AppCard(
      key: const ValueKey('from-your-coach'),
      variant: AppCardVariant.outlined,
      borderRadius: AppRadius.md,
      onTap: onOpenPlan,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.todaysMealsFromYourCoach, style: AppText.titleM),
        ),
        for (final slot in CoachingEnums.mealSlots)
          if (day.itemsIn(slot).isNotEmpty) ...[
            Text(
              slotLabel(l10n, slot),
              style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
            ),
            for (var i = 0; i < day.itemsIn(slot).length; i++)
              CoachMealRow(
                item: day.itemsIn(slot)[i],
                slot: slot,
                catalog: catalog,
                keyPrefix: 'coach-meal-$slot-$i',
                flag: flagOf(slot, i),
                onOpenRecipe: onOpenRecipe,
                onLog: onLog,
              ),
          ],
      ],
    );
  }
}
