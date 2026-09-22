/// **M02 — Post and comments.**
///
/// Matches `screens-community.mjs` → `M02`. The design note: *"Coaches are
/// labelled inside comments so advice is attributable."*
///
/// ## The composer offers text, not a voice note
///
/// The prototype's composer leads with a microphone — *"it is the gesture she is
/// most fluent in, and it is harder to be cruel out loud."* Voice notes are
/// **deferred**: `OQ-8` records that no group has planned recording, storage,
/// playback or moderation of audio, and a whole content type with no moderation
/// story is a safety gap rather than a missing feature. So the mic is behind
/// `Feature.communityVoiceNotes` and the row simply is not offered while it is
/// off — consulted, not hard-coded, so it returns when the flag does.
///
/// ## There is no "who liked this"
///
/// The like count is a number. Tapping it does nothing, because `likes` is
/// `allow list: if false` in the rules except when constrained to her own posts.
/// A roster is a harassment surface, and the absence is structural rather than a
/// screen that declines to draw one.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_avatar.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/community_models.dart';
import 'community_widgets.dart';
import 'feed_view_model.dart';

class PostView extends StatelessWidget {
  const PostView({
    super.key,
    required this.model,
    this.onBack,
    this.onMore,
    this.onOpenProfile,
    this.onLike,
    this.onSave,
    this.onShare,
    this.onFollow,
    this.onSendComment,
    this.onSubmitComment,
  });

  final PostThreadModel model;
  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final ValueChanged<String>? onOpenProfile;
  final VoidCallback? onLike;
  final VoidCallback? onSave;
  final VoidCallback? onShare;
  final VoidCallback? onFollow;
  final VoidCallback? onSendComment;

  /// Sends what she typed. When set, the composer is a real field and the
  /// send button hands its text here, then clears it. One tap, no dialog.
  final ValueChanged<String>? onSubmitComment;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final post = model.post;

    return PaperPage(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppTopBar(
          title: l10n.post,
          onBack: onBack,
          actions: [
            if (model.isAvailable)
              IconButton(
                onPressed: onMore,
                icon: const Icon(Icons.more_vert),
                color: AppColors.onSurface,
              ),
          ],
        ),
        // The composer is pinned within thumb reach, and only when there is
        // something to comment on.
        bottomNavigationBar: model.isAvailable
            ? _Composer(
                hint: l10n.saySomethingKind,
                sendLabel: l10n.send,
                onSend: onSendComment,
                onSubmit: onSubmitComment,
              )
            : null,
        body: !model.isAvailable || post == null
            // One rendering for every cause: deleted, hidden, or a block in
            // either direction. The title is omitted because the dictionary has
            // no "Not available" — see NotAvailablePanel.
            ? const AppScaffold(children: [NotAvailablePanel()])
            : ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const SizedBox(height: 4),
                  PostHeader(
                    post: post,
                    followLabel: l10n.follow,
                    followingLabel: l10n.following,
                    onOpenProfile: () => onOpenProfile?.call(post.authorUid),
                    onFollow: onFollow,
                    onMore: onMore,
                  ),
                  const SizedBox(height: 9),
                  if (post.hasMedia)
                    BlurredShot(
                      height: 220,
                      blurred: post.blurred,
                      blurredLabel: l10n.facesBlurred,
                      borderRadius: 0,
                    ),
                  const SizedBox(height: 9),
                  PostActionBar(
                    post: post,
                    onLike: onLike,
                    onSave: onSave,
                    onShare: onShare,
                    likeLabel: l10n.like,
                    commentLabel: l10n.comment,
                    shareLabel: l10n.share,
                    saveLabel: l10n.save,
                  ),
                  if (post.caption.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${post.authorName} ',
                              style: AppText.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: post.caption, style: AppText.body),
                          ],
                        ),
                      ),
                    ),
                  if (post.pendingUpload)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: QueuedGlyph(label: l10n.waitingToSync),
                    ),
                  // One pencil line closes the post; the comments below it are
                  // open lines in the same hand, not a second stack of boxes.
                  if (model.comments.isEmpty)
                    const SizedBox(height: 12)
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                      child: HandRule(
                        seed: handSeed(['comments', post.postId]),
                        height: 12,
                      ),
                    ),
                  for (final comment in model.comments)
                    _Comment(comment: comment, coachLabel: l10n.coach),
                ],
              ),
      ),
    );
  }
}

class _Comment extends StatelessWidget {
  const _Comment({required this.comment, required this.coachLabel});

  final CommentModel comment;
  final String coachLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(firstName: comment.authorName, size: 32, isSelf: false),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${comment.authorName} ',
                        style: AppText.bodyM.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextSpan(text: comment.body, style: AppText.bodyM),
                    ],
                  ),
                ),
                // A coach is labelled so advice is attributable.
                if (comment.isCoach)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AppPill(
                      coachLabel,
                      background: AppColors.amberContainer,
                      foreground: AppColors.amber,
                    ),
                  ),
                // Written offline: full opacity, with the glyph.
                if (comment.pendingSync)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: QueuedGlyph(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "Say something kind."
///
/// A real field when [onSubmit] is given: she types, taps send, and the
/// comment is hers at once. Pinned above the keyboard, within thumb reach.
class _Composer extends StatefulWidget {
  const _Composer({
    required this.hint,
    required this.sendLabel,
    this.onSend,
    this.onSubmit,
  });

  final String hint;
  final String sendLabel;
  final VoidCallback? onSend;
  final ValueChanged<String>? onSubmit;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// Something to send, within the rules' cap on a comment.
  bool get _canSend {
    final body = _text.text.trim();
    return body.isNotEmpty && body.length <= kMaxCommentLength;
  }

  void _send() {
    final submit = widget.onSubmit;
    if (submit == null) {
      widget.onSend?.call();
      return;
    }
    if (!_canSend) return;
    submit(_text.text.trim());
    _text.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final typing = widget.onSubmit != null;
    return SafeArea(
      top: false,
      child: Padding(
        // Lifted with the keyboard, so the field is never under it.
        padding: EdgeInsets.fromLTRB(
          16,
          6,
          16,
          12 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: AppCard(
          borderRadius: AppRadius.full,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          children: [
            Row(
              children: [
                Expanded(
                  child: typing
                      ? TextField(
                          controller: _text,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _send(),
                          textInputAction: TextInputAction.send,
                          style: AppText.body.copyWith(
                            color: AppColors.onSurface,
                          ),
                          cursorColor: AppColors.primary,
                          decoration: InputDecoration.collapsed(
                            hintText: widget.hint,
                            hintStyle: AppText.body.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        )
                      : Text(
                          widget.hint,
                          style: AppText.body.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                ),
                IconButton(
                  onPressed: typing
                      ? (_canSend ? _send : null)
                      : widget.onSend,
                  tooltip: widget.sendLabel,
                  iconSize: 22,
                  color: AppColors.primaryDim,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
