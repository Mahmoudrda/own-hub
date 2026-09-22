/// `K27` — the meal draft, where every number on screen came from a food row.
///
/// The screen's stated rule is that *"a dish without verified values is offered
/// without totals, never with invented ones"*, and this widget cannot break it
/// even by accident: [MealDishRow.totals] is **null** whenever the pack row is
/// unverified, so there is no figure here to render. The `if` below is not the
/// guard — the null is. `draft_view_model.dart` explains why that distinction
/// is the whole design.
///
/// Nothing on this screen adds anything up. There is no day total and no week
/// total, because `P0-ASK-10` says no total is ever computed by the model, and
/// a total computed here on its behalf would be the same figure arriving by a
/// politer route.
///
/// ## What the design has that this does not
///
///  * **"No nuts. Vegetarian on weekdays. Applied before anything was chosen."**
///    True of the mockup's client. `AllergyGuard` is what makes the claim true,
///    and it runs before selection — but this screen is handed a resolved
///    draft, not the constraints, so it cannot name them. A safety sentence
///    nobody checked against the actual constraint set is decoration.
///  * **The `Protein 92 g` / `Cost 46 EGP` / `7 days` chips.** Each is a total
///    across dishes. Nothing sums here.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'assistant_copy.dart';
import 'assistant_widgets.dart';
import 'draft_view_model.dart';

class MealDraftView extends StatelessWidget {
  const MealDraftView({
    super.key,
    required this.screen,
    this.onClose,
    this.onBoundaries,
    this.onOpenInPlanner,
    this.onDiscard,
  });

  /// Built by [DraftViewModel.meal]. Nothing is computed here.
  final MealDraftScreen screen;

  final VoidCallback? onClose;

  /// `X03`.
  final VoidCallback? onBoundaries;

  /// `W06`. G14's meal planner performs the write, after this tap.
  final VoidCallback? onOpenInPlanner;

  /// Also `W06`. No dialog — rule 9.
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final day = screen.firstDay;

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.meals,
        leadingIcon: Icons.close,
        onBack: onClose,
        actions: [
          IconButton(
            tooltip: l10n.whatItCanAndCannotDo,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.info_outline),
            onPressed: onBoundaries,
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.openInTheMealPlanner,
          height: 54,
          onPressed: onOpenInPlanner,
        ),
        AppButton(
          l10n.discardTheDraft,
          variant: AppButtonVariant.text,
          height: 42,
          fontSize: 15,
          onPressed: onDiscard,
        ),
      ],
      children: [
        const AssistantHeldBadge(),
        // A slot whose dishes all failed to resolve is not in this list at all:
        // a "Dinner" heading with nothing under it tells a coach something was
        // chosen and gives her no way to know what.
        if (day != null)
          for (final slot in day.slots) _Slot(slot: slot),
        AppCard(
          variant: AppCardVariant.sage,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          gap: 3,
          children: [
            Text(l10n.everyNumberCameFromTheFoodLibrary, style: AppText.titleM),
            Text(
              l10n.nothingWasCalculatedADishWithoutVerified,
              style: AppText.bodyM,
            ),
          ],
        ),
        AssistantNotice(
          icon: Icons.warning_amber,
          text: l10n.nothingIsPublishedThisOpensAsA,
          variant: AppCardVariant.amber,
          tone: AppColors.amber,
        ),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.slot});

  final MealSlotRow slot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // A ruled line per meal, the way a day is kept in a diary, rather than a
    // box per meal: the slots are one list, not separate things.
    final line = Padding(
      padding: const EdgeInsets.fromLTRB(2, 9, 2, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(
              mealSlotLabel(l10n, slot.slot),
              style: AppText.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final dish in slot.dishes) ...[
                  Text(dish.name, style: AppText.bodyM),
                  // Null on an unverified row, and therefore absent. Not a
                  // zero, not a dash, not "about".
                  if (dish.totals case final totals?)
                    Text(
                      totals,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        HandRule(seed: handSeed(['meal-slot', slot.slot.name]), height: 3),
      ],
    );
  }
}
