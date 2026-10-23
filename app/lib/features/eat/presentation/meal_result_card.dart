/// The card that answers a typed or spoken meal: what it added up to, and
/// whether it looks right.
///
/// While the words are still being turned into foods it is a placeholder that
/// shimmers once, saying so. When they arrive it fills with the dish's picture,
/// the three macros as coloured dots, and Yes / Edit. Where the answer is
/// already there (typing is parsed in the same frame) the filled card is
/// drawn directly, with no pretend wait.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/hand/draw_on.dart';
import '../../../ui/hand/food_marks.dart';
import '../../../ui/hand/motion.dart';
import '../../../ui/meal_image.dart';
import '../domain/meal_sentence_parser.dart';

/// The colours of the three macro dots, the same ones E01's bars use.
const Color kProteinDot = AppColors.tertiarySoft;
const Color kCarbsDot = AppColors.primary;
const Color kFatDot = AppColors.outline;

class MealResultCard extends StatelessWidget {
  const MealResultCard({
    super.key,
    this.items = const <ParsedItem>[],
    this.adding = false,
    this.onYes,
    this.onEdit,
  });

  /// What the words became. Ignored while [adding].
  final List<ParsedItem> items;

  /// The words are still being turned into foods.
  final bool adding;

  /// "Yes": it looks right, so log it. Null leaves the button off.
  final VoidCallback? onYes;

  /// "Edit": go and change the words. Null leaves the button off.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: handMotionOff(context) ? Duration.zero : HandTiming.medium,
      switchInCurve: HandTiming.standard,
      child: adding
          ? const _AddingCard(key: ValueKey('meal-result-adding'))
          : _FilledCard(
              key: const ValueKey('meal-result-filled'),
              items: items,
              onYes: onYes,
              onEdit: onEdit,
            ),
    );
  }
}

class _AddingCard extends StatefulWidget {
  const _AddingCard({super.key});

  @override
  State<_AddingCard> createState() => _AddingCardState();
}

class _AddingCardState extends State<_AddingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: HandTiming.shimmer,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final still =
        handMotionOff(context) || !TickerMode.valuesOf(context).enabled;
    if (still) {
      _c.value = 0.5;
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _block(double x, {double? width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        gradient: LinearGradient(
          begin: Alignment(x - 1, 0),
          end: Alignment(x + 1, 0),
          colors: const [
            AppColors.surfaceContainer,
            AppColors.surfaceHigh,
            AppColors.surfaceContainer,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Semantics(
      liveRegion: true,
      label: l10n.addingUpYourMeal,
      excludeSemantics: true,
      child: AppCard(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final x = -1.0 + 3.0 * _c.value;
              return Row(
                children: [
                  _block(x, width: 56, height: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.addingUpYourMeal,
                          style: AppText.titleM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _block(x, height: 12),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FilledCard extends StatelessWidget {
  const _FilledCard({super.key, required this.items, this.onYes, this.onEdit});

  final List<ParsedItem> items;
  final VoidCallback? onYes;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final kcal = items.fold<int>(0, (sum, i) => sum + i.kcal);
    final protein = items.fold<int>(0, (sum, i) => sum + i.proteinG);
    final carbs = _sum(items.map((i) => i.carbsG));
    final fat = _sum(items.map((i) => i.fatG));
    final asset = items
        .map((i) => i.food.imageAsset)
        .firstWhere((a) => a != null, orElse: () => null);

    return AppCard(
      key: const ValueKey('meal-result-card'),
      gap: 12,
      children: [
        Row(
          children: [
            MealImage(
              asset: asset,
              size: 56,
              semanticLabel: null,
              fallback: const FoodMark(
                markKey: FoodMarks.bowl,
                size: 56,
                ink: AppColors.primaryDim,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${countLabel(kcal)} ${l10n.kcal}',
                    style: AppText.titleM,
                  ),
                ],
              ),
            ),
          ],
        ),
        Wrap(
          key: const ValueKey('meal-result-dots'),
          spacing: 14,
          runSpacing: 6,
          children: [
            _Dot(kProteinDot, l10n.nGProtein(countLabel(protein))),
            if (carbs != null)
              _Dot(kCarbsDot, l10n.carbsGramsG(countLabel(carbs))),
            if (fat != null) _Dot(kFatDot, l10n.fatGramsG(countLabel(fat))),
          ],
        ),
        Text(l10n.doesThisLookRight, style: AppText.titleS),
        if (onYes != null || onEdit != null)
          Row(
            children: [
              if (onYes != null)
                Expanded(
                  child: AppButton(
                    l10n.yes_6deo,
                    key: const ValueKey('meal-result-yes'),
                    variant: AppButtonVariant.tonal,
                    height: 48,
                    fontSize: 16,
                    onPressed: onYes,
                  ),
                ),
              if (onYes != null && onEdit != null) const SizedBox(width: 10),
              if (onEdit != null)
                Expanded(
                  child: AppButton(
                    l10n.edit,
                    key: const ValueKey('meal-result-edit'),
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    fontSize: 16,
                    onPressed: onEdit,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  /// The total, or null when any item does not carry the figure: a sum with a
  /// hole in it would be a smaller number than she ate.
  static int? _sum(Iterable<int?> values) {
    var total = 0;
    for (final v in values) {
      if (v == null) return null;
      total += v;
    }
    return total;
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.colour, this.label);

  final Color colour;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
