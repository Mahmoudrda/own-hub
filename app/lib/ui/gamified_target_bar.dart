/// A gamified visual progress bar that displays nutritional progress against
/// daily targets (e.g. calories and protein), indicating amount completed,
/// target amount, and amount remaining.
library;

import 'package:flutter/material.dart';

import '../domain/format/number_label.dart';
import '../l10n/app_l10n.dart';
import '../theme/app_tokens.dart';
import 'hand/draw_on.dart' show handMotionOff;

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
    final l10n = AppL10n.of(context);

    final safeTarget = target > 0 ? target : 1;
    final progress = (current / safeTarget).clamp(0.0, 1.0);
    final remaining = (target - current).clamp(0, 9999);
    final isMet = current >= target && target > 0;
    final isOver = current > (target * 1.15).round() && target > 0;

    final remainingText =
        remainingLabel ?? l10n.amountUnitRemaining(countLabel(remaining), unit);
    final metText = targetMetLabel ?? l10n.targetReached;
    final status = isMet ? metText : remainingText;

    // Color accents
    final Color barColor = isOver
        ? AppColors.amber
        : isMet
        ? AppColors.tertiary
        : AppColors.primary;

    return Semantics(
      label: l10n.labelCurrentOfTargetUnitStatus(
        label,
        countLabel(current),
        countLabel(target),
        unit,
        status,
      ),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppText.bodyM.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  status,
                  textAlign: TextAlign.end,
                  style: AppText.label.copyWith(
                    fontSize: 13,
                    color: isMet
                        ? AppColors.tertiary
                        : AppColors.onSurfaceVariant,
                    fontWeight: isMet ? FontWeight.w700 : FontWeight.w500,
                  ),
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
                    duration: handMotionOff(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 300),
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
              Flexible(
                child: Text(
                  '${countLabel(current)} / ${countLabel(target)} $unit',
                  style: AppText.nav.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
