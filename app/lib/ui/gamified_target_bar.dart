/// A gamified visual progress bar that displays nutritional progress against
/// daily targets (e.g. calories and protein), indicating amount completed,
/// target amount, and amount remaining.
library;

import 'package:flutter/material.dart';

import '../domain/format/number_label.dart';
import '../theme/app_tokens.dart';

class GamifiedTargetBar extends StatelessWidget {
  const GamifiedTargetBar({
    super.key,
    required this.label,
    required this.current,
    required this.target,
    required this.unit,
    this.remainingLabel,
    this.targetMetLabel,
  });

  /// The name of the nutrient (e.g. Protein, Calories, Carbs).
  final String label;

  /// The amount currently allocated or consumed.
  final int current;

  /// The target amount set by the coach.
  final int target;

  /// The unit of measurement (e.g. "g" or "kcal").
  final String unit;

  /// Custom label for remaining amount, if needed.
  final String? remainingLabel;

  /// Custom label when target is reached or exceeded.
  final String? targetMetLabel;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final safeTarget = target > 0 ? target : 1;
    final progress = (current / safeTarget).clamp(0.0, 1.0);
    final remaining = (target - current).clamp(0, 9999);
    final isMet = current >= target && target > 0;
    final isOver = current > (target * 1.15).round() && target > 0;

    // Remaining text: e.g. "80g remaining" or "باقي ٨٠ جم"
    final remainingText = remainingLabel ??
        (isArabic ? 'باقي ${countLabel(remaining)} $unit' : '${countLabel(remaining)}$unit remaining');

    // Met text: e.g. "Target reached!" or "تم الوصول للهدف"
    final metText = targetMetLabel ??
        (isArabic ? 'تم الوصول للهدف' : 'Target reached');

    // Color accents
    final Color barColor = isOver
        ? AppColors.amber
        : isMet
            ? AppColors.tertiary
            : AppColors.primary;

    return Semantics(
      label: '$label: ${countLabel(current)} of ${countLabel(target)} $unit. '
          '${isMet ? metText : remainingText}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppText.bodyM.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              Text(
                isMet ? metText : remainingText,
                style: AppText.label.copyWith(
                  fontSize: 13,
                  color: isMet ? AppColors.tertiary : AppColors.onSurfaceVariant,
                  fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 10,
              color: AppColors.surfaceContainer,
              alignment: AlignmentDirectional.centerStart,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${countLabel(current)} / ${countLabel(target)} $unit',
                style: AppText.nav.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                '${countLabel((progress * 100).round())}%',
                style: AppText.nav.copyWith(
                  color: AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
