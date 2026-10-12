/// G16 — the thirty days are over. **Nothing is deleted, nothing pretends to be
/// active.**
///
/// Matches `6-v2/src/screens-coached.mjs` → `G16`. Its design note: *"When the
/// 30 days end, nothing is deleted and nothing pretends to be active. New
/// assignments and messages close, the self-guided app and My cycle continue,
/// and optional cycle sharing switches itself off with the relationship."*
///
/// That last clause is the one that matters, and it is **a Function, not a
/// sentence**: `EndCoaching.end()` clears the switches and deletes
/// `shared/constraints`, `rollups/*` and `clientView/current`. The line on this
/// screen describes something that already happened.
///
/// ## Rule 9's second named exemption
///
/// G11 §5: paying and ending coaching **may** confirm — destructive,
/// non-logging, irreversible acts, the same carve-out block and account
/// deletion have. This screen is the ended *state*, so it asks nothing; the
/// carve-out is named here so a reader of `coached_product_rules_test.dart`
/// knows why this file is on its exemption list rather than wondering.
///
/// ## Renewal needs a connection
///
/// "Work with Sara again" is a purchase, and buying offline is a hard no: no
/// optimistic state, no local pending purchase, no queued charge
/// (`CoachingPurchaseGate`). When [online] is false the button is disabled
/// rather than queueing something that cannot happen.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'coached_widgets.dart';

class CoachingEndedView extends StatelessWidget {
  const CoachingEndedView({
    super.key,
    this.onOpenPlan,
    this.onOpenConversation,
    this.onOpenReviews,
    this.onWorkAgain,
    this.onSelectTab,
    this.endedLabel,
    this.headline,
    this.reviewsSummary,
    this.online = true,
  });

  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenConversation;
  final VoidCallback? onOpenReviews;

  /// Starts a **new engagement**. Never resurrects the old one: `ENDED` is
  /// terminal in the state machine, and renewal creates a new engagement on the
  /// same thread.
  final VoidCallback? onWorkAgain;

  final ValueChanged<String>? onSelectTab;

  final String? endedLabel;
  final String? headline;
  final String? reviewsSummary;

  /// False disables renewal. See the library comment.
  final bool online;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachedNavBar(onSelectTab: onSelectTab),
      body: AppScaffold(
        children: [
          // The same masthead as the rest of the tab — nothing here pretends
          // to be active, and nothing pretends the tab has gone either.
          Row(
            children: [
              Expanded(
                child: Text(l10n.coaching, style: EditorialType.section),
              ),
              // "Ended 7 Oct" is the mockup's last day. Without hers, the
              // pill is absent — the screen is already unambiguous about
              // being over, and a wrong date is worse than no date.
              if (endedLabel case final ended?)
                AppPill(
                  ended,
                  background: AppColors.surfaceContainer,
                  foreground: AppColors.onSurfaceVariant,
                ),
            ],
          ),
          const HandRule(seed: 53, height: 8),
          AppCard(
            variant: AppCardVariant.filled,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 24,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // "Your 30 days with Sara have ended" names a coach
                        // and a length that may not be hers. The sentence
                        // below it is true of everyone and carries the card.
                        if (headline case final line?) ...[
                          Text(line, style: AppText.titleM),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          l10n.everythingYouDidIsStillHereTo,
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
          AppListItem(
            title: l10n.your30DayPlan,
            subtitle: l10n.readableNoNewAssignments,
            onTap: onOpenPlan,
            leading: const Icon(
              Icons.history,
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
            title: l10n.yourConversation,
            subtitle: l10n.readableNewMessagesAreClosed,
            onTap: onOpenConversation,
            leading: const Icon(
              Icons.forum_outlined,
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
            title: l10n.yourReviews,
            // "4 reviews and the day-30 wrap-up" counts reviews she may
            // never have answered. Empty renders no subtitle at all.
            subtitle: reviewsSummary ?? '',
            onTap: onOpenReviews,
            leading: const Icon(
              Icons.checklist,
              size: 22,
              color: AppColors.primaryDim,
            ),
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          // The line that describes what the Function already did.
          AppSageNote(l10n.yourOwnWorkoutsRecipesMealsAndMy),
          AppButton(
            l10n.workWithSaraAgain,
            height: 52,
            onPressed: online ? onWorkAgain : null,
          ),
        ],
      ),
    );
  }
}
