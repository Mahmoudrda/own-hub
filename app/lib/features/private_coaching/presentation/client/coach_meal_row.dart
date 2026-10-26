/// One meal item from a coach's plan: its name and amount, a line when it holds
/// something she avoids or nobody has checked, and a one-tap log.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_sheet.dart';
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
    this.onSwap,
    this.compact = false,
  });

  final MealItem item;
  final String slot;
  final MealCatalog catalog;
  final String keyPrefix;
  final MealFlag? flag;
  final void Function(String recipeId)? onOpenRecipe;

  /// Null hides the Log button.
  final void Function(MealItem item, String slot)? onLog;

  /// Null hides Swap.
  final VoidCallback? onSwap;

  /// One tap-through row instead of a row with its own Log button: the tap
  /// opens a sheet with Log this, and Open recipe when there is one. A day of
  /// these reads as one list.
  final bool compact;

  void _openSheet(
    BuildContext context,
    AppL10n l10n,
    String title,
    String detail,
    bool canOpen,
    bool canLog,
  ) {
    unawaited(
      showAppSheet<void>(
        context: context,
        children: [
          Text(title, style: AppText.titleL),
          if (detail.isNotEmpty)
            Text(
              detail,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          if (canLog)
            Builder(
              builder: (sheet) => AppButton(
                l10n.logThis,
                key: ValueKey('$keyPrefix-log'),
                onPressed: () {
                  Navigator.of(sheet).pop();
                  onLog!(item, slot);
                },
              ),
            ),
          if (canOpen)
            Builder(
              builder: (sheet) => AppButton(
                l10n.viewRecipe,
                key: ValueKey('$keyPrefix-recipe'),
                variant: canLog
                    ? AppButtonVariant.text
                    : AppButtonVariant.outlined,
                onPressed: () {
                  Navigator.of(sheet).pop();
                  onOpenRecipe!(item.recipeId!);
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final amount = itemAmount(l10n, item);
    final canOpen = item.kind == MealItemKind.recipe && onOpenRecipe != null;
    final canLog = onLog != null && item.kind != MealItemKind.free;
    if (compact) {
      final title = catalog.title(item, lang);
      final flagText = flag == null
          ? ''
          : flag!.kind == MealFlagKind.contains
          ? l10n.containsAllergensWhichYouAvoid(
              allergenNames(l10n, flag!.allergens),
            )
          : l10n.notCheckedAgainstYourAllergies;
      final detail = [
        slotLabel(l10n, slot),
        if (amount.isNotEmpty) amount,
        if ((item.note ?? '').isNotEmpty) item.note!,
      ].join('\n');
      final tappable = canOpen || canLog;
      return AppListItem(
        key: ValueKey(keyPrefix),
        title: title,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.titleM),
            if (flagText.isNotEmpty)
              Text(
                flagText,
                key: ValueKey('$keyPrefix-flag'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
          ],
        ),
        subtitle: detail,
        trailing: tappable ? const Icon(Icons.chevron_right, size: 24) : null,
        onTap: tappable
            ? () => _openSheet(
                context,
                l10n,
                title,
                [detail, flagText].where((t) => t.isNotEmpty).join('\n'),
                canOpen,
                canLog,
              )
            : null,
      );
    }
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
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onSwap != null)
                TextButton(
                  key: ValueKey('$keyPrefix-swap'),
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: onSwap,
                  child: Text(l10n.swap),
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
        ],
      ),
    );
  }
}
