/// G17 — Your coaching · your food. Step 2 of 3.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G17`, and its design note is the
/// reason this screen exists at all:
///
/// > Intake announced three steps and delivered two. This is the food step it
/// > skipped — and **the only place in the product where a client states her
/// > allergies**, which the coach screens were already displaying as though
/// > someone had asked.
///
/// So the last line on the screen is not decoration: "This is the only place
/// your allergies come from." It is a claim about the data model, and it is
/// true because the write goes through `DietaryProfileRepository` — G7's port,
/// G2's document — and nothing in this feature keeps a second copy.
///
/// The allergen chips are the four the content team authored. This screen does
/// not offer a fifth, because a plausible-looking allergen list is exactly the
/// fabricated safety guarantee the guard exists to avoid.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';

class CoachingFoodView extends StatelessWidget {
  const CoachingFoodView({
    super.key,
    this.onBack,
    this.onContinue,
    this.selectedAllergens = const {0},
    this.selectedDietary = const {1},
    this.selectedCookMinutes = 1,
    this.familyPot = true,
    this.onAllergen,
    this.onDietary,
    this.onCookMinutes,
    this.onFamilyPot,
  });

  final VoidCallback? onBack;
  final VoidCallback? onContinue;

  /// Indices into the four authored allergens, in order: nuts, dairy, gluten,
  /// shellfish.
  final Set<int> selectedAllergens;

  final Set<int> selectedDietary;
  final int selectedCookMinutes;
  final bool familyPot;

  final ValueChanged<int>? onAllergen;
  final ValueChanged<int>? onDietary;
  final ValueChanged<int>? onCookMinutes;
  final ValueChanged<bool>? onFamilyPot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: l10n.yourCoaching, onBack: onBack),
      footer: [AppButton(l10n.continueLabel, onPressed: onContinue)],
      children: [
        AppSegmented(
          items: [l10n.yourTraining, l10n.yourFood, l10n.yourSupport],
          selectedIndex: 1,
        ),
        // The step's number set by hand beside its title, as on the first
        // step.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HandFigure('2', size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.yourFood, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    l10n.step2Of3,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Question(
          label: l10n.anythingYouCannotEat,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, label) in [
                l10n.noNuts,
                l10n.noDairy,
                l10n.noGluten,
                l10n.noShellfish,
              ].indexed)
                AppChip(
                  label,
                  selected: selectedAllergens.contains(i),
                  onTap: onAllergen == null ? null : () => onAllergen!(i),
                ),
            ],
          ),
        ),
        _Question(
          label: l10n.howYouUsuallyEat,
          child: AppChipRow(
            items: [l10n.everything, l10n.vegetarianOnWeekdays],
            selected: selectedDietary,
            onTap: onDietary,
            grow: false,
          ),
        ),
        _Question(
          label: l10n.timeYouHaveToCook,
          child: AppChipRow(
            items: [l10n.n10Min, l10n.n20Min, l10n.n45Min],
            selected: {selectedCookMinutes},
            onTap: onCookMinutes,
          ),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.someoneElseCooksAtHome, style: AppText.titleM),
                      const SizedBox(height: 2),
                      Text(
                        l10n.saraWillPlanAroundTheFamilyPot,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                AppToggle(
                  value: familyPot,
                  onChanged: onFamilyPot,
                  semanticLabel: l10n.someoneElseCooksAtHome,
                ),
              ],
            ),
          ],
        ),
        // The sentence that describes the data model, not a reassurance.
        Text(
          l10n.thisIsTheOnlyPlaceYourAllergies,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
