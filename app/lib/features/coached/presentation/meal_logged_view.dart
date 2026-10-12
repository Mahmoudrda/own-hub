/// G11 — the meal is logged, and correcting it is not logging it twice.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G11`. Its design note: *"A logged
/// meal can be edited to the portion she actually ate, and a deliberate second
/// helping is a separate action so repeated taps never double-count."*
///
/// The sentence on the screen — "Changing the plan never changes a log you
/// already saved. Tapping twice does not create a second log." — is a claim
/// about `MealLogService`, which gives a planned item a **deterministic id**
/// derived from the assignment, the slot and the index. Re-logging replaces;
/// [onAddHelping] is a different method that removes nothing.
///
/// ## The protein bar
///
/// The target is the coach's `assignments.nutrition.proteinTargetG` when she
/// set one. When she did not, this screen shows whatever G5's totals already
/// use and **invents nothing**.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/app_undo_bar.dart';
import 'coached_widgets.dart';

/// One slot on the strip across the top.
@immutable
class SlotChip {
  const SlotChip({
    required this.name,
    required this.state,
    this.logged = false,
  });

  /// "Lunch".
  final String name;

  /// "logged" or "planned" — the dictionary's words, passed in.
  final String state;

  final bool logged;
}

class MealLoggedView extends StatelessWidget {
  const MealLoggedView({
    super.key,
    this.onEdit,
    this.onPortion,
    this.onAddHelping,
    this.onUndo,
    this.onSelectTab,
    this.slots,
    this.proteinLabel,
    this.proteinPercent = 56,
    this.itemName,
    this.itemMeta,
    this.selectedPortion = 1,
    this.undoMessage,
  });

  final VoidCallback? onEdit;
  final ValueChanged<int>? onPortion;

  /// A **second helping** — a separate action, so repeated taps cannot
  /// double-count.
  final VoidCallback? onAddHelping;

  final VoidCallback? onUndo;
  final ValueChanged<String>? onSelectTab;

  final List<SlotChip>? slots;

  /// "53 of 95 g".
  final String? proteinLabel;

  final double proteinPercent;

  final String? itemName;
  final String? itemMeta;
  final int selectedPortion;

  /// The undo bar's text, which must name the same numbers the button named.
  final String? undoMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final strip =
        slots ??
        [
          SlotChip(name: l10n.breakfast, state: l10n.eaten, logged: true),
          SlotChip(name: l10n.lunch, state: l10n.eaten, logged: true),
          SlotChip(name: l10n.dinner, state: l10n.planned),
        ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachedNavBar(onSelectTab: onSelectTab),
      body: AppScaffold(
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.eat, style: AppText.titleL)),
              Flexible(child: AppPill(l10n.fromYourPlan, icon: Icons.sports)),
            ],
          ),
          AppCard(
            gap: 10,
            children: [
              Row(
                children: [
                  for (final (i, slot) in strip.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    // A logged meal is a plain slip of sage; one still to
                    // come waits on a tint framed in pencil.
                    Expanded(
                      child: HandSurface(
                        seed: handSeed(['slot', i, slot.name]),
                        fill: slot.logged
                            ? AppColors.tertiaryContainer
                            : AppColors.surfaceLow,
                        frame: slot.logged
                            ? null
                            : AppColors.outline.withValues(alpha: 0.5),
                        frameWidth: 1,
                        radius: 5,
                        looseCorner: 13,
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              slot.name,
                              style: AppText.bodyM.copyWith(
                                fontWeight: FontWeight.w600,
                                color: slot.logged
                                    ? AppColors.tertiary
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                            Text(slot.state, style: AppText.bodyM),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(l10n.protein, style: AppText.titleS),
                      ),
                      // "53 of 95 g" is the mockup's protein day. Hers or
                      // nothing — the bar beside it already shows how far
                      // along she is without naming a gram she never ate.
                      if (proteinLabel case final protein?)
                        Text(
                          protein,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  AppProgressBar(percent: proteinPercent, height: 10),
                ],
              ),
            ],
          ),
          AppCard(
            gap: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemName ?? l10n.koshariBowlMedium,
                          style: AppText.titleM,
                        ),
                        // "Logged 1:13 · 1 serving" is a time and a portion
                        // from the prototype, not from her log.
                        if (itemMeta case final meta?) ...[
                          const SizedBox(height: 3),
                          Text(
                            meta,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  AppButton(
                    l10n.edit,
                    variant: AppButtonVariant.tonal,
                    height: 40,
                    fontSize: 14,
                    onPressed: onEdit,
                  ),
                ],
              ),
              // Correcting the portion. The same item id, so the slot holds one
              // item before and one after.
              AppChipRow(
                items: [l10n.serving, l10n.n1Serving, l10n.n1],
                selected: {selectedPortion},
                onTap: onPortion,
              ),
              // A different act entirely: this one adds.
              AppButton(
                l10n.addAnotherServing,
                variant: AppButtonVariant.text,
                height: 40,
                fontSize: 14,
                onPressed: onAddHelping,
              ),
            ],
          ),
          Text(
            l10n.changingThePlanNeverChangesAMeal,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          AppUndoBar(
            // "Lunch logged · 1 serving" names a meal and a portion the
            // screen was not told about. The bar still offers the undo; it
            // just does not invent what it is undoing.
            message: undoMessage ?? l10n.mealAdded,
            undoLabel: l10n.undo,
            onUndo: onUndo,
          ),
        ],
      ),
    );
  }
}
