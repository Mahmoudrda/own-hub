/// G03 — she has paid, the coach has her intake, and **nothing is faked**.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G03`. Its design note: *"While the
/// plan is being written, nothing is faked. Chat works, the library works, My
/// cycle works, and the state says plainly that nothing is scheduled yet."*
///
/// This is the screen most products get wrong by being helpful. The obvious
/// move is to show a placeholder week, or a "starter plan", so the tab does not
/// look empty — and then her coach publishes something different and the app
/// has told her a lie she already started following. So:
///
///  * no assignment is invented;
///  * the sentence says nothing is scheduled **yet**;
///  * and three things that genuinely do work are offered instead.
///
/// `CoachingTabState.resolve()`'s branch: this is a **state** of the coaching
/// tab rather than a destination, which is why it carries the tab's own bar and
/// its own title rather than a back arrow.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'coached_widgets.dart';

class PreparingView extends StatelessWidget {
  const PreparingView({
    super.key,
    this.onMessageCoach,
    this.onTrainOnYourOwn,
    this.onMyCycle,
    this.onExampleDay,
    this.onSelectTab,
    this.coachName,
    this.coachDetail,
  });

  final VoidCallback? onMessageCoach;
  final VoidCallback? onTrainOnYourOwn;
  final VoidCallback? onMyCycle;

  /// "See an example day" — labelled as an example, and it opens the real
  /// screen with the real empty state rather than a mock-up of a full one.
  final VoidCallback? onExampleDay;

  final ValueChanged<String>? onSelectTab;

  final String? coachName;
  final String? coachDetail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachedNavBar(onSelectTab: onSelectTab),
      body: AppScaffold(
        children: [
          // The tab's masthead: its name at section size, the state in
          // marker beside it, and a pencil rule under both.
          Row(
            children: [
              Expanded(
                child: Text(l10n.coaching, style: EditorialType.section),
              ),
              AppPill(
                l10n.preparing,
                background: AppColors.amberContainer,
                foreground: AppColors.amber,
              ),
            ],
          ),
          const HandRule(seed: 51, height: 8),
          AppCard(
            variant: AppCardVariant.tonal,
            children: [
              CoachRow(
                name: coachName ?? l10n.coachSaraHany,
                // "Sunday to Thursday, 9:00–17:00" are one coach's hours.
                // Empty renders no detail line rather than another coach's
                // working week.
                detail: coachDetail ?? '',
                onMessage: onMessageCoach,
                messageTooltip: l10n.messageSara,
              ),
            ],
          ),
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
                          l10n.saraIsPreparingYourPlan,
                          style: AppText.titleM,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          l10n.sheHasYourIntakeMostPlansArrive,
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
          AppButton(
            l10n.messageSara,
            height: 52,
            icon: Icons.chat_bubble_outline,
            onPressed: onMessageCoach,
          ),
          // The sentence that stops this screen from lying.
          Text(
            l10n.nothingIsScheduledYetSoNothingIs,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          AppListItem(
            title: l10n.trainOnYourOwnMeanwhile,
            subtitle: l10n.theLibraryIsOpenAsUsual,
            onTap: onTrainOnYourOwn,
            leading: const Icon(
              Icons.fitness_center,
              size: 22,
              color: AppColors.primaryDim,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          AppListItem(
            title: l10n.myCycle,
            subtitle: l10n.worksWithOrWithoutACoach,
            onTap: onMyCycle,
            leading: const Icon(
              Icons.self_improvement,
              size: 22,
              color: AppColors.primaryDim,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          AppListItem(
            title: l10n.seeAnExampleDay,
            subtitle: l10n.whatTodayLooksLikeOnceShePublishes,
            onTap: onExampleDay,
            leading: const Icon(
              Icons.visibility_outlined,
              size: 22,
              color: AppColors.primaryDim,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
