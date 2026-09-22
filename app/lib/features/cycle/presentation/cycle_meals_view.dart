/// Y07 — Meals for today.
///
/// Matches `screens-cycle.mjs` → `Y07`. Three choices, never a list.
///
/// ## Adding is not eating
///
/// `P0-CYC-18`: "Adding updates today's plan and does not log the meal as eaten
/// — the count of logged meals is unchanged." So [onAddToPlan] is a *plan*
/// callback and this screen has **no** logging path at all: no `LogCommandBus`,
/// no `MealRepository`, no undo snackbar. The existing food-logging flow stays
/// the only way something counts as eaten, which is enforced here by the absence
/// of any other way rather than by a comment asking people not to.
///
/// ## The ranking this screen does not do
///
/// The case also requires "at most three options, none containing sesame, each
/// with its reason written on the card" — allergies applied **before** ranking,
/// not after.
///
/// G5 publishes `MealDayReader` and `usualPlates` but **not the ranker**, and
/// G9 OQ-6 asks for `EatSuggestionRanker.rank({SymptomContext})` which does not
/// exist. So this screen renders the options it is handed and does not invent an
/// ordering: [options] arrives already screened and ranked, and when nothing is
/// supplied the screen says so instead of showing plausible-looking suggestions
/// that no allergy guard has seen.
///
/// That is the safety-critical half. G5 §5.1 is explicit that the guard "fails
/// closed for the allergy class — an unknown constraint is not an absent one",
/// and a screen that guessed at three meals here could put sesame in front of a
/// woman who told us about it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import 'cycle_widgets.dart';

/// One option, already screened by G5's allergy guard and ranked by G5.
///
/// [reason] is required and is the "reason written on the card" the case asks
/// for. There is no way to construct an option without one, so a suggestion
/// that cannot say why it is being offered cannot be displayed.
@immutable
class CycleMealOption {
  const CycleMealOption({
    required this.title,
    required this.meta,
    required this.reason,
  });

  final String title;
  final String meta;

  /// Why this is being offered — written on the card.
  final String reason;
}

class CycleMealsView extends StatelessWidget {
  const CycleMealsView({
    super.key,
    this.options = const <CycleMealOption>[],
    this.onAddToPlan,
    this.onSwap,
    this.onBack,
    this.onSelectTab,
  });

  /// Already screened and ranked by G5. See the library note.
  final List<CycleMealOption> options;

  /// Updates today's plan. **Not** a log.
  final ValueChanged<CycleMealOption>? onAddToPlan;

  final ValueChanged<CycleMealOption>? onSwap;
  final VoidCallback? onBack;
  final ValueChanged<String>? onSelectTab;

  /// "Three options, never a list."
  static const int maxOptions = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final shown = options.take(maxOptions).toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CycleNavBar(onSelectTab: onSelectTab),
      appBar: AppTopBar(title: l10n.mealsForToday, onBack: onBack),
      body: AppScaffold(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(l10n.mealsForToday, style: AppText.titleL)),
              const SizedBox(width: 8),
              // The pill names a count, and the dictionary has it only as the
              // fixed "3 options" — so it renders only when that is true.
              if (shown.length == maxOptions)
                AppPill(
                  l10n.n3Options,
                  background: AppColors.surfaceContainer,
                  foreground: AppColors.onSurfaceVariant,
                ),
            ],
          ),
          if (shown.isEmpty)
            // No ranker, no options. Said plainly rather than filled in.
            Text(
              l10n.nothingChangesUntilYouTellUsHow,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            )
          else
            for (final option in shown)
              AppCard(
                children: [
                  Text(option.title, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    option.meta,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  // The reason, on the card, always.
                  Text(option.reason, style: AppText.bodyM),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          l10n.addToTodaysPlan,
                          height: 44,
                          fontSize: 15,
                          onPressed: onAddToPlan == null
                              ? null
                              : () => onAddToPlan!(option),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppButton(
                        l10n.swap,
                        variant: AppButtonVariant.outlined,
                        height: 44,
                        fontSize: 15,
                        onPressed: onSwap == null
                            ? null
                            : () => onSwap!(option),
                      ),
                    ],
                  ),
                ],
              ),
          AppSageNote(l10n.addingUpdatesYourPlanItDoesNot),
        ],
      ),
    );
  }
}
