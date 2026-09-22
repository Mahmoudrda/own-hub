/// C14 — Being checked.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C14`.
///
/// **This screen is not a rejection and must never read as one.** A check that
/// needs a person — and a check that failed the automatic pass, and a provider
/// outage, which all arrive here — means a woman reviewer is looking at it.
/// `DECISIONS.md` D8 fixes the substance: we are reviewing your application to
/// make sure this community stays safe and private. Nothing here accuses her and
/// nothing dead-ends.
///
/// The card is **amber, not error**. Amber is the product's "a caution that is
/// not a failure"; red is reserved for genuine problems and medical guidance.
/// Using the error variant here would turn waiting into an accusation with one
/// word of code.
///
/// What makes the promise real is the three rows underneath: workouts, recipes
/// and coach profiles all open right now. G1's capability matrix says the only
/// thing a pending check closes is the community — and G1's route contract
/// requires `R01`, `E05` and `H01` to render for an unverified account, because
/// this screen's promise depends on it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';

class BeingCheckedView extends StatelessWidget {
  const BeingCheckedView({
    super.key,
    this.onOpenWorkouts,
    this.onOpenRecipes,
    this.onOpenCoaches,
    this.onSelectTab,
  });

  /// `R01`. Open while she waits.
  final VoidCallback? onOpenWorkouts;

  /// `E05`. Open while she waits.
  final VoidCallback? onOpenRecipes;

  /// `H01`. Browsable while she waits; messaging waits for the check.
  final VoidCallback? onOpenCoaches;

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'T01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        // No lead: there is nowhere to step back to, and nothing to undo.
        appBar: AppTopBar(title: l10n.beingChecked),
        children: [
          AppCard(
            variant: AppCardVariant.amber,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.hourglass_top,
                    size: 26,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.aWomanReviewerIsLooking,
                          style: AppText.titleM,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.usuallyUnderTwoHoursWeWillText,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Text(l10n.whileYouWaitEverythingHereIsOpen, style: AppText.titleM),
          AppListItem(
            leading: const Icon(
              Icons.fitness_center,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.workoutsAndVideos,
            subtitle: l10n.all124IncludingTheQuietOnes,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: onOpenWorkouts,
          ),
          AppListItem(
            leading: const Icon(
              Icons.restaurant,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.recipes,
            subtitle: l10n.withPortionsAndCostPerServing,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: onOpenRecipes,
          ),
          AppListItem(
            leading: const Icon(
              Icons.sports_gymnastics,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.coachProfiles,
            subtitle: l10n.browseMessageWhenYouAreVerified,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: onOpenCoaches,
          ),
          // The closed door, named as the point rather than as a punishment.
          Text(
            l10n.theCommunityStaysClosedUntilTheCheck,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
