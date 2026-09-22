/// **M05 — one group.**
///
/// Matches `screens-community.mjs` → `M05`. The design note: *"A group is a feed
/// plus one shared goal. The challenge card is first because a shared total is
/// what makes a group feel like a room rather than a noticeboard."*
///
/// ## What is not here
///
/// There is no member list and no way to reach one. `groups/{gid}/members` is
/// `allow list: if false` in the rules — thousands of women are not a roster to
/// scrape — so the count comes from the group document and nothing on this
/// screen can enumerate who they are.
///
/// ## Missing copy
///
/// The empty rendering wants *"This group is new"*. The dictionary does not
/// carry it, so the heading falls back to `nobodyYet` and the sentence is
/// omitted rather than invented. Reported with the build.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_progress.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'community_widgets.dart';
import 'feed_view_model.dart';
import 'groups_view_model.dart';

class GroupView extends StatelessWidget {
  const GroupView({
    super.key,
    required this.model,
    required this.posts,
    this.onBack,
    this.onMore,
    this.onOpenGoal,
    this.onJoin,
    this.onOpenPost,
    this.onOpenCreate,
    this.onLike,
    this.onSave,
    this.onSelectTab,
    this.onLeave,
    this.onMorePost,
    this.onOpenProfile,
  });

  final GroupScreenModel model;

  /// The group's feed. Passed in rather than fetched: the screen does no I/O.
  final List<PostCardModel> posts;

  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onOpenGoal;
  final VoidCallback? onJoin;
  final ValueChanged<String>? onOpenPost;
  final VoidCallback? onOpenCreate;
  final ValueChanged<String>? onLike;
  final ValueChanged<String>? onSave;
  final ValueChanged<String>? onSelectTab;

  /// Leaves the group. One tap, and Join brings her straight back, so it is
  /// undone the same way it was done rather than confirmed.
  final VoidCallback? onLeave;

  /// The overflow on one post in the group, which is about that post and its
  /// author rather than about the group. Falls back to [onMore] when absent.
  final ValueChanged<String>? onMorePost;

  final ValueChanged<String>? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final goal = model.goal;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: model.group.name,
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: onMore,
            color: AppColors.onSurface,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: AppScaffold(
        footer: [
          // Posting into a group is for its members: the rules address a group
          // post only to a group she is in.
          if (model.group.joined) AppButton(l10n.post, onPressed: onOpenCreate),
        ],
        children: [
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (model.group.showsMemberCount)
                          Text(model.group.memberLabel, style: AppText.titleM)
                        else if (model.group.blurb.isNotEmpty)
                          Text(model.group.blurb, style: AppText.titleM),
                        // Muted for a week: still a member, just quiet.
                        if (model.group.muted)
                          Text(
                            l10n.stillAMemberJustQuiet,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (model.group.offersJoin)
                    AppButton(
                      l10n.join,
                      variant: AppButtonVariant.tonal,
                      height: 38,
                      fontSize: 14,
                      onPressed: onJoin,
                    )
                  else ...[
                    Text(
                      l10n.joined,
                      style: AppText.label.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (onLeave != null)
                      AppButton(
                        l10n.leaveGroup,
                        variant: AppButtonVariant.text,
                        height: 38,
                        fontSize: 14,
                        onPressed: onLeave,
                      ),
                  ],
                ],
              ),
            ],
          ),

          // The shared goal sits on top. Everyone who does her part finishes.
          if (goal != null)
            AppListItem(
              variant: AppCardVariant.amber,
              leading: const Icon(
                Icons.celebration_outlined,
                size: 23,
                color: AppColors.amber,
              ),
              title: '${goal.totalLabel} / ${goal.targetLabel}',
              subtitle: l10n.togetherSoFar,
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: onOpenGoal,
            ),

          if (model.isEmpty)
            // "This group is new" is not in the dictionary; the heading is the
            // nearest minted string and the sentence is left out. Dashed: a
            // space waiting for the group's first post.
            HandSurface(
              seed: handSeed(['nobody-yet', model.group.groupId]),
              frame: AppColors.outline.withValues(alpha: 0.7),
              dashed: true,
              radius: 5,
              looseCorner: 16,
              padding: const EdgeInsets.all(16),
              child: Text(l10n.nobodyYet, style: AppText.titleM),
            )
          else
            for (final (i, post) in posts.indexed) ...[
              // The group's posts are open entries ruled apart, as on M01.
              if (i > 0) PostRule(postId: post.postId, inset: 0),
              CommunityPostCard(
                post: post,
                followLabel: l10n.follow,
                followingLabel: l10n.following,
                blurredLabel: l10n.facesBlurred,
                queuedLabel: l10n.waitingToSync,
                mediaHeight: 212,
                onOpen: () => onOpenPost?.call(post.postId),
                onOpenProfile: () => onOpenProfile?.call(post.authorUid),
                onComment: () => onOpenPost?.call(post.postId),
                onLike: () => onLike?.call(post.postId),
                onSave: () => onSave?.call(post.postId),
                onMore: onMorePost == null
                    ? onMore
                    : () => onMorePost!(post.postId),
                likeLabel: l10n.like,
                commentLabel: l10n.comment,
                shareLabel: l10n.share,
                saveLabel: l10n.save,
              ),
            ],
        ],
      ),
    );
  }
}

/// The shared-total bar, used by M05's card and M06's page.
class SharedTotalBar extends StatelessWidget {
  const SharedTotalBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return AppProgressBar(percent: fraction * 100, height: 12);
  }
}
