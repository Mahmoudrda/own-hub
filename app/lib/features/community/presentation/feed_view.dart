/// **M01 — Community**, and the three other things this tab can be.
///
/// Matches `6-v2/src/screens-community.mjs` → `M01`: a stories rail, full-bleed
/// pictures, likes, comments, share and save. The design note says what is
/// different underneath — *"every ring belongs to an ID-verified woman, and
/// faces arrive blurred unless she turned that off herself."*
///
/// ## M17 is a branch of this widget, not a route
///
/// `HANDOFF` rule 16. `app_router.dart` lists `M17` in `firstRunStates`, so it
/// is excluded from `appDestinations` and nothing can navigate to it. The
/// day-one rendering is a `case` below, which is what makes `P0-COM-03` true:
/// pressing back from it exits the tab, because nothing ever pushed a screen to
/// go back to.
///
/// ## Missing copy, left out rather than invented
///
/// Two states want sentences the dictionary does not carry, and the build
/// reports them rather than fabricating English in a widget:
///
///   * **joined-but-silent** wants *"Nobody has posted here yet today"*. The
///     closest minted string is `nobodyYet`, which is used for the heading; the
///     body sentence is omitted.
///   * **offline-cold** wants a body under `waitingForSignal`. There is none.
///
/// Inventing either would bypass the dictionary, so the Arabic build would show
/// English and no test of the English UI would notice.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/community_tab_state.dart';
import 'community_widgets.dart';
import 'feed_view_model.dart';

class FeedView extends StatelessWidget {
  const FeedView({
    super.key,
    required this.model,
    this.onRefresh,
    this.onOpenPost,
    this.onOpenProfile,
    this.onOpenGroups,
    this.onOpenActivity,
    this.onOpenSearch,
    this.onOpenCreate,
    this.onOpenStory,
    this.onJoinGroup,
    this.onLike,
    this.onSave,
    this.onFollow,
    this.onMore,
    this.onSelectTab,
  });

  final FeedScreenModel model;

  /// Pull to refresh. **The only way this screen re-reads** — there is no
  /// listener anywhere in community, by design (G10 §2.4).
  final Future<void> Function()? onRefresh;

  final ValueChanged<String>? onOpenPost;
  final ValueChanged<String>? onOpenProfile;
  final VoidCallback? onOpenGroups;
  final VoidCallback? onOpenActivity;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenCreate;
  final ValueChanged<String>? onOpenStory;
  final ValueChanged<String>? onJoinGroup;
  final ValueChanged<String>? onLike;
  final ValueChanged<String>? onSave;
  final ValueChanged<String>? onFollow;
  final ValueChanged<String>? onMore;
  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // The same paper AppScaffold lays down, under the masthead and the feed
    // alike, so the ready feed is not the one plain page in the tab.
    return PaperPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        bottomNavigationBar: AppNavBar(
          activeScreenId: 'M01',
          onSelect: onSelectTab,
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(
                title: l10n.community,
                groupsLabel: l10n.groups,
                activityLabel: l10n.activity,
                searchLabel: l10n.search,
                createLabel: l10n.create,
                onOpenGroups: onOpenGroups,
                onOpenActivity: onOpenActivity,
                onOpenSearch: onOpenSearch,
                onOpenCreate: onOpenCreate,
              ),
              Expanded(child: _body(context, l10n)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AppL10n l10n) {
    // HANDOFF 16, as a switch. Each state has its own rendering and its own
    // single smallest action.
    switch (model.state) {
      case CommunityTabState.dayOne:
        return _DayOne(
          model: model,
          onJoinGroup: onJoinGroup,
          onOpenGroups: onOpenGroups,
        );
      case CommunityTabState.joinedOnly:
        return _JoinedButSilent(onOpenCreate: onOpenCreate);
      case CommunityTabState.offlineCold:
        return const _OfflineCold();
      case CommunityTabState.ready:
        return _ready(context, l10n);
    }
  }

  Widget _ready(BuildContext context, AppL10n l10n) {
    final list = ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        if (model.rail.isNotEmpty)
          StoriesRail(
            rings: model.rail,
            // Her own ring reads "Your day"; everyone else's reads her name.
            labelFor: (ring) => ring.isMine ? l10n.yourDay : ring.authorName,
            onOpen: (ring) => onOpenStory?.call(ring.postId),
          ),
        for (final (i, post) in model.posts.indexed) ...[
          // Open posts on a ruled page: a pencil line under the rail and
          // between entries, never a box round each one.
          if (i > 0 || model.rail.isNotEmpty)
            PostRule(postId: post.postId)
          else
            const SizedBox(height: 14),
          CommunityPostCard(
            post: post,
            followLabel: l10n.follow,
            followingLabel: l10n.following,
            blurredLabel: l10n.facesBlurred,
            queuedLabel: l10n.waitingToSync,
            onOpen: () => onOpenPost?.call(post.postId),
            onOpenProfile: () => onOpenProfile?.call(post.authorUid),
            onFollow: () => onFollow?.call(post.authorUid),
            onMore: () => onMore?.call(post.postId),
            onLike: () => onLike?.call(post.postId),
            onComment: () => onOpenPost?.call(post.postId),
            onSave: () => onSave?.call(post.postId),
            likeLabel: l10n.like,
            commentLabel: l10n.comment,
            shareLabel: l10n.share,
            saveLabel: l10n.save,
          ),
        ],
      ],
    );

    final refresh = onRefresh;
    if (refresh == null) return list;
    return RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// The feed header — what is new for her, search, and the camera.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.groupsLabel,
    required this.activityLabel,
    required this.searchLabel,
    required this.createLabel,
    this.onOpenGroups,
    this.onOpenActivity,
    this.onOpenSearch,
    this.onOpenCreate,
  });

  final String title;
  final String groupsLabel;
  final String activityLabel;
  final String searchLabel;
  final String createLabel;
  final VoidCallback? onOpenGroups;
  final VoidCallback? onOpenActivity;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenCreate;

  @override
  Widget build(BuildContext context) {
    // The tab's masthead: the name set at section size with one marker swipe
    // behind it — this hub's single signature mark — and a pencil rule
    // under the whole row, where the page starts.
    final row = Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 4, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Row(
          children: [
            Expanded(
              // Scales down rather than wrapping when four tools and a long
              // name or a large text size compete for one line.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                // Underlined once, a single pass: each section's home is
                // marked its own way, so the hand never repeats a gesture
                // from tab to tab.
                child: HandUnderline(
                  drawOn: true,
                  level: HandLevel.expressive,
                  width: HandStroke.pen,
                  child: Text(title, style: EditorialType.section),
                ),
              ),
            ),
            IconButton(
              onPressed: onOpenGroups,
              tooltip: groupsLabel,
              icon: const Icon(Icons.groups_outlined),
            ),
            IconButton(
              onPressed: onOpenActivity,
              tooltip: activityLabel,
              icon: const Icon(Icons.favorite_border),
            ),
            IconButton(
              onPressed: onOpenSearch,
              tooltip: searchLabel,
              icon: const Icon(Icons.search),
            ),
            IconButton(
              onPressed: onOpenCreate,
              tooltip: createLabel,
              icon: const Icon(Icons.photo_camera_outlined),
            ),
          ],
        ),
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: HandRule(seed: 17, height: 8),
        ),
      ],
    );
  }
}

/// **M17 — Community, day one.** A state of this tab.
class _DayOne extends StatelessWidget {
  const _DayOne({required this.model, this.onJoinGroup, this.onOpenGroups});

  final FeedScreenModel model;
  final ValueChanged<String>? onJoinGroup;
  final VoidCallback? onOpenGroups;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      children: [
        // Verified is done, so it is ticked in sage and set on the open page
        // — not one more box above the two that follow.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: HandTick(size: 24, seed: 5, drawOn: true),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.youAreVerifiedTheRoomIsOpen, style: AppText.titleM),
                  const SizedBox(height: 4),
                  Text(
                    l10n.facesArriveBlurredAndNothingHereLeaves,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const HandRule(seed: 71, height: 8),
        AppEmptyState(
          icon: Icons.groups_outlined,
          art: AppArt.dance,
          title: l10n.yourFeedIsEmptyOnPurpose,
          // "It fills with the groups you join, never a public timeline."
          body: l10n.itFillsWithTheGroupsYouJoin,
          onTap: onOpenGroups,
        ),
        _SectionHead(
          title: l10n.groupsForSomeoneStartingOut,
          subtitle: l10n.beginnersPostpartumOrYourCity,
        ),
        // The one smallest action: join one group.
        for (final group in model.suggestedGroups)
          AppListItem(
            title: group.name,
            leading: const Icon(
              Icons.groups_outlined,
              size: 23,
              color: AppColors.primaryDim,
            ),
            trailing: AppButton(
              l10n.join,
              variant: AppButtonVariant.tonal,
              height: 38,
              fontSize: 14,
              onPressed: () => onJoinGroup?.call(group.groupId),
            ),
          ),
        AppSageNote(l10n.onlyVerifiedWomenCanSeeAnythingYou),
      ],
    );
  }
}

/// She has joined, and nobody has posted yet.
class _JoinedButSilent extends StatelessWidget {
  const _JoinedButSilent({this.onOpenCreate});

  final VoidCallback? onOpenCreate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      footer: [
        // The one smallest action for this state: post the first thing.
        AppButton(l10n.post, onPressed: onOpenCreate),
      ],
      children: [
        // The heading is `nobodyYet`. G10's sentence for this state — "Nobody
        // has posted here yet today" — is not in the dictionary, and the body
        // is therefore omitted rather than invented.
        //
        // Dashed, because it is a space waiting for the first post rather
        // than a notice about one.
        HandSurface(
          seed: handSeed(['nobody-yet', 'feed']),
          frame: AppColors.outline.withValues(alpha: 0.7),
          dashed: true,
          radius: 5,
          looseCorner: 16,
          padding: const EdgeInsets.all(16),
          child: Text(l10n.nobodyYet, style: AppText.titleM),
        ),
      ],
    );
  }
}

/// No cache and no signal. Not an error — physics.
class _OfflineCold extends StatelessWidget {
  const _OfflineCold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      children: [
        AppCard(
          variant: AppCardVariant.filled,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_queue,
                  size: 22,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                // No "failed to load" anywhere: nothing has gone wrong.
                Expanded(
                  child: Text(l10n.waitingForSignal, style: AppText.titleM),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final sub = subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.titleM),
        if (sub != null)
          Text(
            sub,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }
}
