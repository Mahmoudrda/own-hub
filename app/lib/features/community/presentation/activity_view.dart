/// **M14 — Activity.** People, not counters.
///
/// Matches `screens-community.mjs` → `M14`. The design note: *"Activity is
/// people who did something, plus one prompt: your first post is eight weeks
/// old, add a follow-up. That prompt is the engine of the whole follow-up
/// feature, and it is the only nudge on the screen."*
///
/// ## Zero notification documents
///
/// `G10` §2.2: *"M14 has no notification documents by design."* The obvious
/// build writes one `notifications` doc per like — a write on the hottest path
/// in the product, and the fan-out mistake wearing a different hat. This screen
/// is assembled from three constrained reads at open, so it costs **no writes**.
///
/// The one exception is the follow-up prompt, which must survive the app being
/// closed, and is a single G7 notification written by a Cloud Task.
///
/// ## Missing copy, and what is drawn instead
///
/// Every row sentence the prototype uses bakes the mockup's figures into the
/// string — *"Habiba and 12 others liked your best"*, *"Beginners group reached
/// 146 sessions"*. Rendering one of those would state the prototype's numbers as
/// facts about her, which is the defect `test/baked_in_samples_test.dart`
/// exists to count. No parameterised form exists, so each row draws **the
/// woman's name and an icon for what she did**, and the sentences are reported
/// as dictionary work outstanding.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/community_models.dart';
import 'profile_view_model.dart';

class ActivityView extends StatelessWidget {
  const ActivityView({
    super.key,
    required this.model,
    this.onBack,
    this.onOpenPost,
    this.onAddFollowUp,
    this.onFollowBack,
    this.onSelectTab,
  });

  final ActivityScreenModel model;
  final VoidCallback? onBack;
  final ValueChanged<String>? onOpenPost;
  final ValueChanged<String>? onAddFollowUp;
  final ValueChanged<String>? onFollowBack;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final prompt = model.followUpPrompt;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.activity, onBack: onBack),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        children: [
          // The one nudge on the screen.
          if (prompt != null)
            AppCard(
              variant: AppCardVariant.tonal,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.history,
                      size: 23,
                      color: AppColors.primaryDim,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.eightWeeksSinceYourFirstPost,
                            style: AppText.titleM,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            l10n.addAFollowUpPictureToIt,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      l10n.add,
                      variant: AppButtonVariant.tonal,
                      height: 36,
                      fontSize: 14,
                      onPressed: () => onAddFollowUp?.call(prompt),
                    ),
                  ],
                ),
              ],
            ),

          if (model.rows.isNotEmpty) Text(l10n.thisWeek, style: AppText.titleM),

          for (final row in model.rows)
            AppListItem(
              leading: AppAvatar(
                firstName: row.actorName,
                size: 40,
                isSelf: false,
              ),
              // Her name, and an icon for what she did. The sentence that
              // belongs here has no parameterised form in the dictionary.
              title: row.actorName,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              trailing: row.offersFollowBack
                  ? AppButton(
                      l10n.followBack,
                      variant: AppButtonVariant.tonal,
                      height: 32,
                      fontSize: 14,
                      onPressed: () => onFollowBack?.call(row.id),
                    )
                  : Icon(
                      _icon(row.kind),
                      size: 20,
                      semanticLabel: _semantic(row.kind, l10n),
                      color: AppColors.onSurfaceVariant,
                    ),
              onTap: row.postId == null
                  ? null
                  : () => onOpenPost?.call(row.postId!),
            ),

          // "Nothing here is a number going up. Every line is a woman who did
          // something, or a thing you can act on."
          AppSageNote(l10n.nothingHereIsANumberGoingUp),
        ],
      ),
    );
  }

  IconData _icon(ActivityKind kind) => switch (kind) {
    ActivityKind.liked => Icons.favorite,
    ActivityKind.commented => Icons.chat_bubble_outline,
    ActivityKind.followed => Icons.person_add_outlined,
    ActivityKind.groupMilestone => Icons.groups_outlined,
    ActivityKind.followUpPrompt => Icons.history,
  };

  String _semantic(ActivityKind kind, AppL10n l10n) => switch (kind) {
    ActivityKind.liked => l10n.activity,
    ActivityKind.commented => l10n.activity,
    ActivityKind.followed => l10n.follow,
    ActivityKind.groupMilestone => l10n.groups,
    ActivityKind.followUpPrompt => l10n.followUp,
  };
}
