/// The pieces every community screen repeats, translated from the local helpers
/// at the top of `6-v2/src/screens-community.mjs`.
///
/// The prototype defines `post()`, `postHead()`, `actionBar()`, `caption()`,
/// `storyRing()` and `photoGrid()` inline because they appear on six screens
/// between them and must stay identical across all six. They are feature-local
/// rather than `lib/ui/` primitives for the same reason they are local in the
/// prototype: a post card and a story ring are Community's vocabulary, not the
/// product's — exactly the argument `train_widgets.dart` makes for a move row.
///
/// ## Every string arrives as a parameter
///
/// Nothing in this file imports `AppL10n`. Copy is resolved by the screen and
/// handed down, which keeps these widgets testable with plain strings and —
/// more importantly — keeps every dictionary decision in one place per screen
/// rather than scattered through the shared furniture.
///
/// ## The queued glyph is not a failure state
///
/// G8's offline contract: full-opacity optimistic render, a trailing
/// `cloud_queue` glyph, no blocking spinner, and **no "failed to save"** for
/// anything that will sync. So [QueuedGlyph] is drawn beside content that is
/// already visible at full opacity — it never dims, greys or replaces it.
library;

import 'package:flutter/material.dart';

import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_media.dart';
import '../../../ui/hand/hand.dart';
import '../domain/follow_state.dart';
import 'feed_view_model.dart';
import 'profile_view_model.dart';

/// The trailing "this has not synced yet" mark.
class QueuedGlyph extends StatelessWidget {
  const QueuedGlyph({super.key, this.label});

  /// Optional wording beside the icon, already resolved.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.cloud_queue,
          size: 15,
          color: AppColors.onSurfaceVariant,
        ),
        if (text != null) ...[
          const SizedBox(width: 5),
          Text(
            text,
            style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// The follow control, in the renderings [FollowState] allows.
///
/// There is no rendering for "blocked": [FollowState.unavailable] draws
/// **nothing at all**, because a disabled button that says something different
/// is exactly the side channel that tells a woman she was blocked.
class FollowPill extends StatelessWidget {
  const FollowPill({
    super.key,
    required this.state,
    required this.followLabel,
    required this.followingLabel,
    this.onTap,
    this.height = 32,
  });

  final FollowState state;

  /// "Follow", resolved by the screen.
  final String followLabel;

  /// "Following".
  final String followingLabel;

  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Her own profile, and the not-available case, both draw nothing. The
    // second is deliberate: see the class comment.
    if (state == FollowState.self || state == FollowState.unavailable) {
      return const SizedBox.shrink();
    }

    final following = state == FollowState.following;
    final pending = state == FollowState.pendingLocal;

    return Semantics(
      button: true,
      selected: following,
      // A small printed block with one loose corner, not a pill: rose ink for
      // the action, a flat tint once she follows.
      child: HandSurface(
        seed: handSeed(['follow', following, height]),
        fill: following ? AppColors.surfaceContainer : AppColors.primary,
        radius: 4,
        looseCorner: 12,
        onTap: onTap,
        pressable: true,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                following ? followingLabel : followLabel,
                style: AppText.label.copyWith(
                  color: following ? AppColors.onSurface : AppColors.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              // Tapped offline: optimistic, at full opacity, with the glyph.
              if (pending) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.cloud_queue,
                  size: 14,
                  color: AppColors.onPrimary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The ordinary not-available panel.
///
/// One rendering for every cause — a deleted post, a woman who turned her
/// profile off, a block in either direction. The caller cannot tell them apart
/// and neither can this widget: it is given a title and draws it.
/// **[title] is nullable on purpose.** The sentence this panel wants — the
/// ordinary "Not available" — is **absent from the dictionary**. Inventing it in
/// the widget would bypass the dictionary and show English to an Arabic reader,
/// so when there is no string the panel draws its icon alone: unavailability is
/// conveyed, and no English is fabricated. The missing key is reported with the
/// build rather than worked around.
class NotAvailablePanel extends StatelessWidget {
  const NotAvailablePanel({super.key, this.title, this.body});

  final String? title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final detail = body;
    final heading = title;
    return AppCard(
      variant: AppCardVariant.filled,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.visibility_off_outlined,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (heading != null) Text(heading, style: AppText.titleM),
                  if (detail != null) ...[
                    if (heading != null) const SizedBox(height: 4),
                    Text(
                      detail,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A woman's name, her group and the overflow, as `postHead()` draws it.
class PostHeader extends StatelessWidget {
  const PostHeader({
    super.key,
    required this.post,
    required this.followLabel,
    required this.followingLabel,
    this.onOpenProfile,
    this.onFollow,
    this.onMore,
  });

  final PostCardModel post;
  final String followLabel;
  final String followingLabel;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final group = post.groupName;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 6, 0),
      child: Row(
        children: [
          AppAvatar(firstName: post.authorName, size: 38, isSelf: false),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.titleS,
                        ),
                      ),
                      if (post.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          size: 15,
                          color: AppColors.primaryDim,
                        ),
                      ],
                    ],
                  ),
                  if (group != null)
                    Text(
                      group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (post.showsFollowButton)
            FollowPill(
              state: post.followState,
              followLabel: followLabel,
              followingLabel: followingLabel,
              onTap: onFollow,
            ),
          IconButton(
            onPressed: onMore,
            iconSize: 22,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }
}

/// Like, comment, share and save — `actionBar()`.
///
/// Every one of these is a single tap with **no confirmation**. Rule 9.
class PostActionBar extends StatelessWidget {
  const PostActionBar({
    super.key,
    required this.post,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.likeLabel,
    this.commentLabel,
    this.shareLabel,
    this.saveLabel,
  });

  final PostCardModel post;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  /// What each control is called for a screen reader, already resolved. Like
  /// and save also say whether they are on, so the state is not only a colour.
  final String? likeLabel;
  final String? commentLabel;
  final String? shareLabel;
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          _Count(
            icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
            colour: post.likedByMe ? AppColors.primary : AppColors.onSurface,
            label: post.likeLabel,
            semanticLabel: likeLabel,
            selected: post.likedByMe,
            onTap: onLike,
          ),
          const SizedBox(width: 15),
          _Count(
            icon: Icons.chat_bubble_outline,
            colour: AppColors.onSurface,
            label: post.commentLabel,
            semanticLabel: commentLabel,
            onTap: onComment,
          ),
          const SizedBox(width: 15),
          IconButton(
            onPressed: onShare,
            tooltip: shareLabel,
            iconSize: 24,
            color: AppColors.onSurface,
            icon: const Icon(Icons.send_outlined),
          ),
          const Spacer(),
          Semantics(
            selected: post.savedByMe,
            child: IconButton(
              onPressed: onSave,
              tooltip: saveLabel,
              iconSize: 24,
              color: post.savedByMe ? AppColors.primary : AppColors.onSurface,
              icon: Icon(
                post.savedByMe ? Icons.bookmark : Icons.bookmark_border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.colour,
    required this.label,
    this.semanticLabel,
    this.selected,
    this.onTap,
  });

  final IconData icon;
  final Color colour;
  final String label;
  final String? semanticLabel;
  final bool? selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = semanticLabel;
    return Semantics(
      label: name,
      selected: selected,
      button: onTap != null,
      child: HandPressable(
        onTap: onTap,
        builder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 25, color: colour),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppText.label.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A whole post — `post()` in the prototype.
class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.followLabel,
    required this.followingLabel,
    this.blurredLabel,
    this.queuedLabel,
    this.mediaHeight = 268,
    this.onOpen,
    this.onOpenProfile,
    this.onFollow,
    this.onMore,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.likeLabel,
    this.commentLabel,
    this.shareLabel,
    this.saveLabel,
  });

  final PostCardModel post;
  final String followLabel;
  final String followingLabel;

  /// The action bar's names for a screen reader. See [PostActionBar].
  final String? likeLabel;
  final String? commentLabel;
  final String? shareLabel;
  final String? saveLabel;

  /// "Faces blurred", shown over an image that is.
  final String? blurredLabel;

  /// Beside the queued glyph on a post that has not uploaded yet.
  final String? queuedLabel;

  final double mediaHeight;
  final VoidCallback? onOpen;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onFollow;
  final VoidCallback? onMore;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PostHeader(
          post: post,
          followLabel: followLabel,
          followingLabel: followingLabel,
          onOpenProfile: onOpenProfile,
          onFollow: onFollow,
          onMore: onMore,
        ),
        const SizedBox(height: 9),
        if (post.hasMedia)
          GestureDetector(
            onTap: onOpen,
            child: BlurredShot(
              height: mediaHeight,
              blurred: post.blurred,
              blurredLabel: blurredLabel,
              borderRadius: 0,
            ),
          ),
        const SizedBox(height: 9),
        PostActionBar(
          post: post,
          onLike: onLike,
          onComment: onComment,
          onShare: onShare,
          onSave: onSave,
          likeLabel: likeLabel,
          commentLabel: commentLabel,
          shareLabel: shareLabel,
          saveLabel: saveLabel,
        ),
        if (post.caption.isNotEmpty)
          // The words open the post too: a text post has no picture to tap,
          // and "comment" should not be the only way into it.
          GestureDetector(
            onTap: onOpen,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${post.authorName} ',
                      style: AppText.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: post.caption, style: AppText.body),
                  ],
                ),
              ),
            ),
          ),
        // Full opacity, with the glyph. Never dimmed and never an error.
        if (post.pendingUpload)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: QueuedGlyph(label: queuedLabel),
          ),
      ],
    );
  }
}

/// The pencil line between two posts.
///
/// Posts are set open on the page rather than boxed one by one, so a feed
/// reads as a kept page of entries, not a stack of identical cards. The rule
/// is what holds one woman's post apart from the next.
class PostRule extends StatelessWidget {
  const PostRule({super.key, required this.postId, this.inset = 14});

  /// The post below the rule, so each rule is drawn differently.
  final String postId;

  /// Matches the text margin of the post it separates.
  final double inset;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(inset, 8, inset, 6),
    child: HandRule(seed: handSeed(['post-rule', postId]), height: 12),
  );
}

/// An image placeholder that says whether faces in it are blurred.
///
/// There is no real photograph in this build — community media lives on a CDN
/// that does not exist yet, and it is **never cached for offline** because it is
/// other women's bodies. So this draws the same deliberate placeholder
/// `AppMedia` draws everywhere else, plus the one fact that matters about a
/// community image.
class BlurredShot extends StatelessWidget {
  const BlurredShot({
    super.key,
    this.height = 268,
    this.width,
    this.blurred = true,
    this.blurredLabel,
    this.borderRadius = AppRadius.md,
  });

  final double height;
  final double? width;
  final bool blurred;
  final String? blurredLabel;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final label = blurredLabel;
    return Stack(
      children: [
        AppMedia(
          height: height,
          width: width,
          kind: AppMediaKind.photo,
          showPlayButton: false,
          borderRadius: borderRadius,
        ),
        if (blurred && label != null)
          PositionedDirectional(
            start: 10,
            bottom: 10,
            child: HandSurface(
              seed: handSeed(['blurred-label', label]),
              fill: AppColors.inverseSurface.withValues(alpha: 0.72),
              radius: 4,
              looseCorner: 12,
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.blur_on,
                    size: 14,
                    color: AppColors.inverseOnSurface,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: AppText.label.copyWith(
                      color: AppColors.inverseOnSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// One ring on the stories rail.
class StoryRing extends StatelessWidget {
  const StoryRing({
    super.key,
    required this.ring,
    required this.label,
    this.onTap,
  });

  final StoryRingModel ring;

  /// Her name, or "Your day" for her own.
  final String label;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  // Seen and expiring-soon both dim the ring. Shape and colour
                  // together, never colour alone.
                  color: ring.seen || ring.expiringSoon
                      ? AppColors.outlineVariant
                      : AppColors.primary,
                  width: ring.seen ? 1.5 : 2.5,
                ),
              ),
              child: AppAvatar(
                firstName: ring.authorName,
                size: 54,
                isSelf: false,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// The horizontal rail M01 opens with.
class StoriesRail extends StatelessWidget {
  const StoriesRail({
    super.key,
    required this.rings,
    required this.labelFor,
    this.onOpen,
  });

  final List<StoryRingModel> rings;

  /// Resolves each ring's caption — "Your day" for hers, her name otherwise.
  final String Function(StoryRingModel) labelFor;

  final void Function(StoryRingModel)? onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: rings.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, i) => StoryRing(
          ring: rings[i],
          label: labelFor(rings[i]),
          onTap: onOpen == null ? null : () => onOpen!(rings[i]),
        ),
      ),
    );
  }
}

/// The three-across grid M07, M10 and M15 all draw.
class CommunityGrid extends StatelessWidget {
  const CommunityGrid({
    super.key,
    required this.tiles,
    this.blurredLabel,
    this.unavailableLabel,
    this.columns = 3,
    this.onOpen,
  });

  final List<ProfileTileModel> tiles;
  final String? blurredLabel;

  /// Drawn on a tile whose post is gone.
  final String? unavailableLabel;

  final int columns;
  final void Function(ProfileTileModel)? onOpen;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) {
        final tile = tiles[i];
        if (!tile.available) {
          final label = unavailableLabel;
          // A flat tint and no hatching: the live tiles are the hatched ones,
          // so a gone post must not read as one more picture.
          return HandSurface(
            seed: handSeed(['gone-tile', tile.postId]),
            fill: AppColors.surfaceContainer,
            radius: 3,
            looseCorner: 10,
            padding: const EdgeInsets.all(8),
            child: Center(
              child: label == null
                  ? const Icon(
                      Icons.visibility_off_outlined,
                      size: 20,
                      color: AppColors.onSurfaceVariant,
                    )
                  : Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppText.label.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
            ),
          );
        }
        if (!tile.hasMedia) {
          // A text post. Its words, set on the page, rather than a photo
          // placeholder that would say there is a picture when there is none.
          return HandSurface(
            seed: handSeed(['text-tile', tile.postId]),
            fill: AppColors.surfaceLow,
            frame: AppColors.outline.withValues(alpha: 0.6),
            radius: 3,
            looseCorner: 10,
            padding: const EdgeInsets.all(8),
            onTap: onOpen == null ? null : () => onOpen!(tile),
            semanticsButton: onOpen != null,
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(
                tile.caption,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: AppText.label.copyWith(color: AppColors.onSurface),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: onOpen == null ? null : () => onOpen!(tile),
          child: BlurredShot(
            height: 116,
            blurred: tile.blurred,
            blurredLabel: null,
            borderRadius: AppRadius.xs,
          ),
        );
      },
    );
  }
}
