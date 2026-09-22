/// **M09 — Reels.** Deferred at launch, and absent because a flag says so.
///
/// Matches `screens-community.mjs` → `M09`: a full-screen vertical clip, the
/// familiar action rail, and an audio line that credits her own voice rather
/// than a music library. The design note: *"the clip is a woman coach showing
/// three floor moves."*
///
/// ## Nothing video renders while `communityVideo` is off
///
/// The launch scope is photos and text. [ReelsScreenModel.available] is false
/// while the flag is off, and this screen then draws the **ordinary
/// not-available panel and nothing else** — no player, no camera, no "coming
/// soon". The absence is the flag's, not this file's: `ReelsScreenModel.from`
/// is what asks, so switching `communityVideo` on brings the whole surface back
/// with no change here.
///
/// That is also why the camera affordance lives inside the available branch.
/// An entry point to recording on a screen whose capability is switched off is
/// a control that cannot succeed.
///
/// ## Nothing is ranked, and there is no "who liked this"
///
/// The rail carries her real like and comment figures through `countLabel`, and
/// tapping the heart likes rather than opening a roster: `likes` is
/// `allow list: if false` in the rules, so a roster is unreadable rather than
/// merely unbuilt. There is no follower figure anywhere on this screen —
/// [PostCardModel.showsFollowerCount] is false and nothing here would be an
/// appropriate place for one even when it is not.
///
/// ## Offline is an explicit state, never a spinner
///
/// `G10` §4: community media is **not** downloaded for offline — *"it is other
/// women's bodies, and a local cache of it is a privacy liability, not a
/// feature."* So offline there is nothing to draw, and what is drawn instead is
/// `waitingForSignal`: not an error, and not a loading indicator over media
/// that is never coming.
///
/// ## Missing copy, left out rather than invented
///
///   * The empty rendering wants *"No reels yet"* (`G10` §5.1). The dictionary
///     does not carry it, so the panel draws its icon alone.
///   * The audio credit wants *"Her voice · 0:34"*. The only minted form is
///     `herVoice034`, which bakes the mockup's duration into a sentence about a
///     real clip — the defect `baked_in_samples_test.dart` counts. The line is
///     omitted rather than stated wrongly.
///
/// Both are reported with the build.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'community_widgets.dart';
import 'create_view_model.dart';
import 'feed_view_model.dart';

class ReelsView extends StatelessWidget {
  const ReelsView({
    super.key,
    required this.model,
    this.posts = const <PostCardModel>[],
    this.index = 0,
    this.online = true,
    this.onBack,
    this.onRecord,
    this.onOpenProfile,
    this.onOpenComments,
    this.onFollow,
    this.onLike,
    this.onShare,
    this.onSave,
    this.onMore,
    this.onSelectTab,
  });

  final ReelsScreenModel model;

  /// The cards behind [ReelsScreenModel.reels], already resolved.
  ///
  /// Separate from the model for the same reason [GroupView] takes its posts
  /// separately: the model decides *whether* there is a reel surface at all,
  /// and the page decides what is on it.
  final List<PostCardModel> posts;

  /// Which reel is on screen.
  final int index;

  /// False when there is no signal. Community media is never cached, so there
  /// is nothing to fall back to — and an explicit state beats a spinner.
  final bool online;

  final VoidCallback? onBack;

  /// The camera. Offered only where video exists.
  final VoidCallback? onRecord;

  final ValueChanged<String>? onOpenProfile;
  final ValueChanged<String>? onOpenComments;
  final ValueChanged<String>? onFollow;
  final ValueChanged<String>? onLike;
  final ValueChanged<String>? onShare;
  final ValueChanged<String>? onSave;
  final ValueChanged<String>? onMore;
  final ValueChanged<String>? onSelectTab;

  PostCardModel? get _current =>
      index >= 0 && index < posts.length ? posts[index] : null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final reel = _current;

    // Video is switched off, or there is nothing to play. Either way this is
    // an ordinary screen with an ordinary panel — no player, and no camera.
    if (!model.available || reel == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(title: l10n.reels, onBack: onBack),
        bottomNavigationBar: AppNavBar(
          activeScreenId: 'M01',
          onSelect: onSelectTab,
        ),
        body: AppScaffold(
          children: [
            // Unavailable and empty are different facts. Empty has its
            // sentence now — "No reels yet" — and unavailable still draws the
            // ordinary panel, because the sentence for THAT is not minted.
            model.available
                ? AppCard(
                    variant: AppCardVariant.filled,
                    children: [
                      const Center(
                        child: Icon(
                          Icons.videocam_off_outlined,
                          size: 28,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(l10n.noReelsYet, style: AppText.titleM),
                      ),
                    ],
                  )
                : const NotAvailablePanel(),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'M01',
        onSelect: onSelectTab,
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: online
                  ? BlurredShot(
                      height: double.infinity,
                      blurred: reel.blurred,
                      blurredLabel: l10n.facesBlurred,
                      borderRadius: 0,
                    )
                  // Never cached, so never drawn from a cache. Not an error.
                  : const _OfflineFill(),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              top: 0,
              child: _Header(
                title: l10n.reels,
                createLabel: l10n.create,
                backLabel: l10n.back,
                onBack: onBack,
                onRecord: onRecord,
              ),
            ),
            PositionedDirectional(
              end: 6,
              bottom: 22,
              child: _Rail(
                post: reel,
                shareLabel: l10n.share,
                saveLabel: l10n.save,
                onLike: () => onLike?.call(reel.postId),
                onComment: () => onOpenComments?.call(reel.postId),
                onShare: () => onShare?.call(reel.postId),
                onSave: () => onSave?.call(reel.postId),
                onMore: () => onMore?.call(reel.postId),
              ),
            ),
            PositionedDirectional(
              start: 0,
              end: 74,
              bottom: 22,
              child: _Caption(
                post: reel,
                followLabel: l10n.follow,
                followingLabel: l10n.following,
                onOpenProfile: () => onOpenProfile?.call(reel.authorUid),
                onFollow: () => onFollow?.call(reel.authorUid),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title and the camera, over the clip.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.createLabel,
    required this.backLabel,
    this.onBack,
    this.onRecord,
  });

  final String title;
  final String createLabel;
  final String backLabel;
  final VoidCallback? onBack;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 2, 4, 0),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              tooltip: backLabel,
              color: AppColors.inverseOnSurface,
              // Directional, so it mirrors in Arabic.
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppText.titleL.copyWith(color: AppColors.inverseOnSurface),
            ),
          ),
          // The one smallest action for this screen, and a video affordance —
          // so it exists only inside the branch where video does.
          IconButton(
            onPressed: onRecord,
            tooltip: createLabel,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.photo_camera_outlined),
          ),
        ],
      ),
    );
  }
}

/// Like, comment, share, save and the overflow — the familiar rail.
class _Rail extends StatelessWidget {
  const _Rail({
    required this.post,
    required this.shareLabel,
    required this.saveLabel,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onMore,
  });

  final PostCardModel post;
  final String shareLabel;
  final String saveLabel;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // One tap, no confirmation. Rule 9.
        _RailAction(
          icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
          // Her figure, in Western digits in both languages. Tapping likes;
          // there is nothing here that could list who else did.
          label: post.likeLabel,
          onTap: onLike,
        ),
        _RailAction(
          icon: Icons.chat_bubble_outline,
          label: post.commentLabel,
          onTap: onComment,
        ),
        _RailAction(
          icon: Icons.send_outlined,
          label: shareLabel,
          onTap: onShare,
        ),
        _RailAction(
          icon: post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
          label: saveLabel,
          onTap: onSave,
        ),
        IconButton(
          onPressed: onMore,
          color: AppColors.inverseOnSurface,
          icon: const Icon(Icons.more_vert),
        ),
      ],
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Gives under the finger instead of rippling, like every control on the
    // page; nothing is drawn over the clip.
    return HandPressable(
      onTap: onTap,
      builder: (_, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 27, color: AppColors.inverseOnSurface),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppText.label.copyWith(
                color: AppColors.inverseOnSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Who made it, and what she said.
class _Caption extends StatelessWidget {
  const _Caption({
    required this.post,
    required this.followLabel,
    required this.followingLabel,
    this.onOpenProfile,
    this.onFollow,
  });

  final PostCardModel post;
  final String followLabel;
  final String followingLabel;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AppAvatar(firstName: post.authorName, size: 34, isSelf: false),
              const SizedBox(width: 9),
              Flexible(
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: Text(
                    post.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.titleS.copyWith(
                      color: AppColors.inverseOnSurface,
                    ),
                  ),
                ),
              ),
              if (post.verified) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.verified,
                  size: 15,
                  color: AppColors.inverseOnSurface,
                ),
              ],
              // Nothing beside her name counts anybody. Follower counts are
              // off, and `showsFollowerCount` is false whether they are or not.
              if (post.showsFollowButton) ...[
                const SizedBox(width: 9),
                FollowPill(
                  state: post.followState,
                  followLabel: followLabel,
                  followingLabel: followingLabel,
                  height: 30,
                  onTap: onFollow,
                ),
              ],
            ],
          ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              post.caption,
              style: AppText.bodyM.copyWith(color: AppColors.inverseOnSurface),
            ),
          ],
          // The audio credit belongs here. Its only minted form states the
          // mockup's duration as a fact about this clip, so it is omitted.
        ],
      ),
    );
  }
}

/// No signal, and no cache to fall back on — by design.
class _OfflineFill extends StatelessWidget {
  const _OfflineFill();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return ColoredBox(
      color: AppColors.inverseSurface,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_queue,
              size: 30,
              color: AppColors.inverseOnSurface,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.waitingForSignal,
              style: AppText.titleM.copyWith(color: AppColors.inverseOnSurface),
            ),
          ],
        ),
      ),
    );
  }
}
