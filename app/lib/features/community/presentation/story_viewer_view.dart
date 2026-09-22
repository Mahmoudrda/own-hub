/// **M13 — Stories.** Twenty-four hours, then gone.
///
/// Matches `screens-community.mjs` → `M13`. The design note: *"Stories carry
/// the small things a post is too heavy for — a walk before the school run. The
/// reply bar sends privately, so encouragement does not have to be performed in
/// front of a group."*
///
/// ## One woman per session
///
/// [StoryViewerModel] keeps only the frames belonging to the ring that was
/// tapped, so the strip is one woman's day and never a mixture. Same restraint
/// as M12, on the other surface that shows several pictures in a row.
///
/// ## Expired, hidden, blocked — one rendering
///
/// `P0-COM-15` deletes a story at its TTL, and a story that expired between the
/// rail and the tap resolves to the ordinary not-available panel — identical to
/// a block in either direction. A blocked woman cannot learn she is blocked
/// from this screen, because this screen is not told.
///
/// ## Nothing here plays, and nothing here counts
///
/// No play control is drawn while `communityVideo` is off, and there is no
/// microphone: a voice reply is a content type with no moderation story
/// (`OQ-8`), so the reply bar is text with a heart and a send. There is no
/// viewer list — seen state is local sqflite, so no roster exists to render —
/// and no follower figure.
///
/// ## Missing copy, left out rather than invented
///
///   * *"3 hours ago"* under her name wants a parameterised time-ago form. The
///     dictionary has none, and the figure would otherwise be the mockup's, so
///     the line is omitted.
///   * The overlay card the prototype draws over the picture — *"Walk before
///     the school run · 32 minutes counted by her phone"* — is the mockup's
///     sentence with the mockup's figures. There is no parameterised form, so
///     the card is not drawn.
///
/// Both are reported with the build.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'community_widgets.dart';
import 'feed_view_model.dart';

class StoryViewerView extends StatelessWidget {
  const StoryViewerView({
    super.key,
    required this.model,
    this.onClose,
    this.onMore,
    this.onOpenProfile,
    this.onSendReply,
    this.onLike,
  });

  final StoryViewerModel model;

  final VoidCallback? onClose;
  final VoidCallback? onMore;
  final ValueChanged<String>? onOpenProfile;

  /// Sends privately. Never a comment in front of the group.
  final VoidCallback? onSendReply;

  /// One tap, no confirmation.
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final frame = model.current;

    // Expired, deleted, hidden, or a block in either direction. One rendering,
    // and the title is omitted because the dictionary has no "Not available".
    if (!model.isAvailable || frame == null) {
      return Scaffold(
        backgroundColor: AppColors.surface,
        appBar: AppTopBar(
          title: l10n.story,
          onBack: onClose,
          leadingIcon: Icons.close,
        ),
        body: const AppScaffold(children: [NotAvailablePanel()]),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: model.mediaAvailable
                  ? BlurredShot(
                      height: double.infinity,
                      blurred: frame.blurred,
                      blurredLabel: l10n.facesBlurred,
                      borderRadius: 0,
                    )
                  // Community media is never cached for offline, so there is
                  // nothing to show and no spinner over something that is not
                  // coming.
                  : const _OfflineFill(),
            ),
            PositionedDirectional(
              start: 0,
              end: 0,
              top: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StoryProgressStrip(frames: model.frames, index: model.index),
                  _Head(
                    model: model,
                    yourDayLabel: l10n.yourDay,
                    closeLabel: l10n.close,
                    onOpenProfile: () => onOpenProfile?.call(model.authorUid),
                    onMore: onMore,
                    onClose: onClose,
                  ),
                ],
              ),
            ),
            if (model.offersReply)
              PositionedDirectional(
                start: 0,
                end: 0,
                bottom: 14,
                child: _ReplyBar(
                  hint: l10n.sendHerSomethingKind,
                  sendLabel: l10n.send,
                  onSend: onSendReply,
                  onLike: onLike,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The segments across the top — one per frame, filled up to the current one.
///
/// Laid out with [Row] and [Expanded], so it fills right-to-left in Arabic
/// without a second implementation (`P2-RTL-M13`).
class StoryProgressStrip extends StatelessWidget {
  const StoryProgressStrip({
    super.key,
    required this.frames,
    required this.index,
  });

  final List<StoryFrameModel> frames;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          for (var i = 0; i < frames.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 3,
                decoration: BoxDecoration(
                  // Shape and weight carry the state as well as colour: a
                  // watched segment is dimmer, the current one is full.
                  color: i <= index
                      ? AppColors.inverseOnSurface
                      : AppColors.inverseOnSurface.withValues(alpha: 0.34),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Whose day this is, and the two ways out of it.
class _Head extends StatelessWidget {
  const _Head({
    required this.model,
    required this.yourDayLabel,
    required this.closeLabel,
    this.onOpenProfile,
    this.onMore,
    this.onClose,
  });

  final StoryViewerModel model;
  final String yourDayLabel;
  final String closeLabel;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onMore;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 4, 0),
      child: Row(
        children: [
          AppAvatar(firstName: model.authorName, size: 34, isSelf: false),
          const SizedBox(width: 9),
          Expanded(
            child: GestureDetector(
              onTap: onOpenProfile,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      model.isMine ? yourDayLabel : model.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.titleS.copyWith(
                        color: AppColors.inverseOnSurface,
                      ),
                    ),
                  ),
                  if (model.verified) ...[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.verified,
                      size: 15,
                      color: AppColors.inverseOnSurface,
                    ),
                  ],
                ],
              ),
            ),
          ),
          // "3 hours ago" belongs here. There is no parameterised time-ago
          // form in the dictionary, so nothing is drawn rather than the
          // mockup's figure.
          IconButton(
            onPressed: onMore,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.more_vert),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: closeLabel,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

/// Text, a heart and a send. Privately, and with no microphone.
class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.hint,
    required this.sendLabel,
    this.onSend,
    this.onLike,
  });

  final String hint;
  final String sendLabel;
  final VoidCallback? onSend;
  final VoidCallback? onLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            // Drawn clean over the picture: the viewer is structural, so the
            // field keeps the page's corners without a wavering hand.
            child: HandSurface(
              seed: handSeed(['story-reply']),
              frame: AppColors.inverseOnSurface.withValues(alpha: 0.55),
              frameWidth: 1.5,
              level: HandLevel.structural,
              radius: 6,
              looseCorner: 16,
              child: Container(
                height: 46,
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(
                    color: AppColors.inverseOnSurface,
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onLike,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.favorite_border, size: 26),
          ),
          IconButton(
            onPressed: onSend,
            tooltip: sendLabel,
            color: AppColors.inverseOnSurface,
            icon: const Icon(Icons.send_outlined, size: 24),
          ),
        ],
      ),
    );
  }
}

/// No signal, and nothing cached to fall back on.
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
