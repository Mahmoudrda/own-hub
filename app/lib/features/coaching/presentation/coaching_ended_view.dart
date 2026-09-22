/// `H06` — coaching ended.
///
/// The prototype's `H06` was the chat thread; the thread belongs to
/// `features/coached` (`G14`), which already owns messages, and drawing a
/// second one here would be two composers writing to one collection. What the
/// marketplace owns at the end of a relationship is this: what stays readable,
/// what has closed, and how to work with her again.
///
/// ## Everything she did is still here to read
///
/// The plan, the conversation and the reviews stay readable. New assignments
/// and new messages are closed — by the security rules, not by a disabled
/// button — and this screen states that rather than hiding the history behind
/// it. Her own workouts, recipes, logs and My cycle carry on exactly as before.
///
/// ## Cycle sharing switched itself off
///
/// That sentence renders only when [EndedCoachingSnapshot.sharingCleared] is
/// true. It is a Cloud Function's work, not a screen's claim: `onRelationshipEnded`
/// clears the switches and deletes the three derived projections, and the grant
/// is bound to a relationship id that no longer exists. The screen may say it
/// because it is true; the model is what makes it possible to test that before
/// the screen says it.
///
/// ## Working with her again starts an enquiry
///
/// Not a checkout. Buy-direct is removed and a renewal is not an exception:
/// a new engagement still needs her to accept before a pound moves. So the
/// button opens `H04`, and the old conversation and reviews are still there
/// because the relationship id is deterministic and has not changed.
///
/// ## Ending may confirm
///
/// The second of rule 9's two carve-outs. Where this screen offers to end a
/// relationship early, the confirmation is an inline step — never a dialog.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import 'coaching_view_models.dart';
import 'coaching_widgets.dart';

class CoachingEndedView extends StatelessWidget {
  const CoachingEndedView({
    super.key,
    required this.model,
    this.onBack,
    this.onOpenPlan,
    this.onOpenConversation,
    this.onOpenReviews,
    this.onWorkTogetherAgain,
  });

  final CoachingEndedViewModel model;
  final VoidCallback? onBack;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenConversation;
  final VoidCallback? onOpenReviews;
  final VoidCallback? onWorkTogetherAgain;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final snapshot = model.snapshot;

    // "Work with Sara again" names the mockup's coach. It renders only for a
    // woman whose coach really is called Sara; everyone else gets the button
    // with the neutral label rather than a stranger's name.
    final againForHer = statedLine(
      l10n.workWithSaraAgain,
      states: 'Sara',
      hers: snapshot.coachName.trim().split(' ').first,
    );

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.coaching,
        onBack: () => goToScreen(context, 'H05', onBack),
      ),
      footer: [
        if (model.mayWorkTogetherAgain)
          AppButton(
            // Neutral fallback: the dictionary's only "again" line names a
            // coach, so a woman with a different coach gets the plain word.
            againForHer ?? l10n.coaches,
            height: 54,
            // An enquiry, not a checkout. The destination is the proof.
            onPressed: () => goToScreen(context, 'H04', onWorkTogetherAgain),
          ),
      ],
      children: [
        AppCard(
          variant: AppCardVariant.tonal,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoachAvatar(snapshot.coachName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(snapshot.coachName, style: AppText.titleM),
                      const SizedBox(height: 3),
                      CoachingNote(l10n.everythingYouDidIsStillHereTo),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // The three history rows. Readable, and saying so.
        if (snapshot.planReadable)
          AppListItem(
            leading: const Icon(
              Icons.calendar_month,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.yourCoaching,
            subtitle: l10n.readableNoNewAssignments,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => goToScreen(context, 'G05', onOpenPlan),
          ),
        if (snapshot.messagesReadable)
          AppListItem(
            leading: const Icon(
              Icons.chat_bubble_outline,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.yourConversation,
            subtitle: l10n.readableNewMessagesAreClosed,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => goToScreen(context, 'G14', onOpenConversation),
          ),
        if (snapshot.reviewCount > 0)
          AppListItem(
            leading: const Icon(
              Icons.history,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.reviews,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => goToScreen(context, 'G13', onOpenReviews),
          ),

        // Only when a Function really did it.
        if (model.maySaySharingCleared)
          CoachingNote(l10n.yourOwnWorkoutsRecipesLogsAndMy),
      ],
    );
  }
}
