/// One meal item from a coach's plan: its name and amount, a line when it holds
/// something she avoids or nobody has checked, and a one-tap log.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../member/coach_labels.dart' show allergenNames;
import '../../domain/coach_plan.dart';
import '../plans/coach_plan_logic.dart';
import '../plans/plan_labels.dart';

class CoachMealRow extends StatelessWidget {
  const CoachMealRow({
    super.key,
    required this.item,
    required this.slot,
    required this.catalog,
    required this.keyPrefix,
    this.flag,
    this.onOpenRecipe,
    this.onLog,
  });

  final MealItem item;
  final String slot;
  final MealCatalog catalog;
  final String keyPrefix;
  final MealFlag? flag;
  final void Function(String recipeId)? onOpenRecipe;

  /// Null hides the Log button.
  final void Function(MealItem item, String slot)? onLog;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final amount = itemAmount(l10n, item);
    final canOpen = item.kind == MealItemKind.recipe && onOpenRecipe != null;
    final canLog = onLog != null && item.kind != MealItemKind.free;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(catalog.title(item, lang), style: AppText.titleS),
        if (amount.isNotEmpty)
          Text(
            amount,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if ((item.note ?? '').isNotEmpty)
          Text(
            item.note!,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (flag != null)
          Text(
            flag!.kind == MealFlagKind.contains
                ? l10n.containsAllergensWhichYouAvoid(
                    allergenNames(l10n, flag!.allergens),
                  )
                : l10n.notCheckedAgainstYourAllergies,
            key: ValueKey('$keyPrefix-flag'),
            style: AppText.bodyM.copyWith(color: AppColors.error),
          ),
      ],
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: canOpen
                ? InkWell(
                    key: ValueKey(keyPrefix),
                    onTap: () => onOpenRecipe!(item.recipeId!),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: text,
                    ),
                  )
                : Padding(
                    key: ValueKey(keyPrefix),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: text,
                  ),
          ),
          if (canLog)
            TextButton(
              key: ValueKey('$keyPrefix-log'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () => onLog!(item, slot),
              child: Text(l10n.logThis),
            ),
        ],
      ),
    );
  }
}
