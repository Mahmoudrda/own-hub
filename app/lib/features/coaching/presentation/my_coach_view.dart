/// `H05` — my coach.
///
/// Matches `6-v2/src/screens-coaching.mjs` → `H05`.
///
/// ## One thing waiting at a time
///
/// With a coach, the Coaching tab stops being a directory and becomes a
/// relationship: her, the check-in that is due, and the last reply. The
/// check-in is the product — it is what she paid for and what keeps her — so it
/// is the one card that may be amber, and [MyCoachWaiting] makes "one thing"
/// structural rather than a layout convention three cards could quietly break.
///
/// ## The empty state is the onboarding
///
/// A woman with no coach sees the invitation to find one, and a tap opens
/// `H01`. There is no tour and no overlay: HANDOFF rules 16 and 17 make
/// first-run a *state*, not a route.
///
/// ## Two figures this screen refuses to invent
///
///  * Her reply time renders only for the coach it is true of.
///  * Nothing on this screen states a price. A receipt needs a parameterised
///    money string the dictionary does not have, and the mockup's `1,800 EGP`
///    would be told to every woman. Listed in the handover.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'coaching_view_models.dart';
import 'coaching_widgets.dart';

class MyCoachView extends StatelessWidget {
  const MyCoachView({
    super.key,
    required this.model,
    this.onFindACoach,
    this.onOpenChat,
    this.onOpenPlan,
    this.onOpenReview,
    this.onOpenLastReview,
  });

  final MyCoachViewModel model;
  final VoidCallback? onFindACoach;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenReview;
  final VoidCallback? onOpenLastReview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final snapshot = model.snapshot;

    if (snapshot == null) {
      // The empty state *is* the onboarding: one line about what a coach adds,
      // and the way to find one.
      return AppScaffold(
        appBar: AppTopBar(title: l10n.coaching),
        children: [
          AppEmptyState(
            icon: Icons.person_search,
            art: AppArt.lungeKneeling,
            title: l10n.coaches,
            body: l10n.everyCoachHereIsAVerifiedWoman,
            onTap: () => goToScreen(context, 'H01', onFindACoach),
          ),
          AppButton(
            l10n.coaches,
            height: 54,
            onPressed: () => goToScreen(context, 'H01', onFindACoach),
          ),
        ],
      );
    }

    final reply = statedLine(
      l10n.about2HoursMeasuredNotTyped,
      states: 120,
      hers: snapshot.replyMinsP50,
    );

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.coaching,
        actions: [
          IconButton(
            tooltip: l10n.chat,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.chat_bubble_outline),
            // G14 is the coached feature's thread; this tab hands off to it.
            onPressed: () => goToScreen(context, 'G14', onOpenChat),
          ),
        ],
      ),
      children: [
        // The tab's masthead is her coach: set on the page rather than in a
        // card, her name at section size in the same marker it wore on her
        // profile, and a pencil rule between her and the day's business.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachAvatar(snapshot.coachName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkerHighlight(
                    drawOn: true,
                    child: Text(
                      snapshot.coachName,
                      style: EditorialType.section,
                    ),
                  ),
                  // Null renders no claim about how fast she answers.
                  if (reply != null) ...[
                    const SizedBox(height: 3),
                    CoachingNote(reply),
                  ],
                ],
              ),
            ),
          ],
        ),
        const HandRule(seed: 23, height: 10),

        // She has paid and the relationship has not started yet. Saying so
        // beats a plan card for a plan that does not exist.
        if (model.awaitingPayment)
          CoachingNotice(
            icon: Icons.hourglass_empty,
            text: l10n.shePaysOnlyOnceYouAccept,
          ),

        if (model.isLive)
          AppCard(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(l10n.yourCoaching, style: AppText.titleM),
                  ),
                  const SizedBox(width: 12),
                  AppButton(
                    l10n.open,
                    variant: AppButtonVariant.tonal,
                    height: 40,
                    fontSize: 15,
                    onPressed: () => goToScreen(context, 'G04', onOpenPlan),
                  ),
                ],
              ),
            ],
          ),

        // One thing waiting, decided in the model.
        switch (model.waiting) {
          MyCoachWaiting.reviewDue => AppCard(
            variant: AppCardVariant.amber,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_available,
                    size: 24,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.weeklyReviewDue, style: AppText.titleM),
                        const SizedBox(height: 3),
                        CoachingNote(l10n.oneMinuteItIsFilledInFrom),
                      ],
                    ),
                  ),
                ],
              ),
              AppButton(
                l10n.doItNow,
                height: 48,
                fontSize: 15,
                onPressed: () => goToScreen(context, 'G12', onOpenReview),
              ),
            ],
          ),
          MyCoachWaiting.unreadMessages => AppListItem(
            leading: const Icon(
              Icons.chat_bubble_outline,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.chat,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => goToScreen(context, 'G14', onOpenChat),
          ),
          MyCoachWaiting.lastReviewAnswered => AppListItem(
            leading: const Icon(
              Icons.history,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.lastReview,
            // "Sara replied with a voice note" is the mockup's coach, not
            // hers. It renders only for a woman whose coach really is called
            // Sara; everyone else gets the row with no subtitle rather than
            // somebody else's coach's name.
            subtitle:
                statedLine(
                  l10n.saraRepliedWithAVoiceNote,
                  states: 'Sara',
                  hers: snapshot.coachName.trim().split(' ').first,
                ) ??
                '',
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => goToScreen(context, 'G13', onOpenLastReview),
          ),
          MyCoachWaiting.nothing => const SizedBox.shrink(),
        },
      ],
    );
  }
}
