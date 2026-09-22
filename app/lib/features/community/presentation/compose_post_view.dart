/// The composer behind **M03's "Write a post"** — the text half of the launch
/// scope.
///
/// `G10-community.md`: the launch scope is *photos and text*, and a text post is
/// [PostKind.photo] with an empty `media[]` — the same document, not a second
/// kind of post. There is no camera plugin in this build, so text is the half
/// that can actually be made, and this is where it is made.
///
/// ## A sheet, not a screen
///
/// M03 is the chooser the design draws, and nothing in `screens-community.mjs`
/// is a text composer — so adding one as a route would invent a screen the
/// design does not have. It is laid over M03 instead, which is what
/// `app_sheet.dart` exists for: *"a decision that belongs to the screen
/// underneath rather than replacing it."*
///
/// ## It raises no confirmation
///
/// Rule 9. The sheet closes and the post is made, with five seconds to undo it
/// on the bar underneath — the same undo every other log in this product
/// offers. There is no "are you sure", here or in the publish pipeline.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_sheet.dart';
import '../domain/community_models.dart';
import 'explore_view.dart' show topicLabel;
import 'groups_view_model.dart';

/// What she wrote, and where it goes. A plain value, handed back to the caller
/// — the sheet writes nothing itself.
@immutable
class ComposedPost {
  const ComposedPost({
    required this.caption,
    this.groupId,
    this.isStory = false,
    this.topics = const <CommunityTopic>[],
  });

  final String caption;

  /// The group she chose, or null for her own page.
  final String? groupId;

  /// "Your day" — the same document with a 24-hour TTL.
  final bool isStory;

  final List<CommunityTopic> topics;
}

/// Opens the composer over the current screen.
///
/// Returns what she wrote, or null if she closed it. [groups] are the groups she
/// has joined — a woman cannot post into a room she is not in, so nothing else
/// is offered.
Future<ComposedPost?> showPostComposer(
  BuildContext context, {
  List<GroupRowModel> groups = const <GroupRowModel>[],
  String? initialGroupId,
}) => showAppSheet<ComposedPost>(
  context: context,
  children: [ComposePostBody(groups: groups, initialGroupId: initialGroupId)],
);

/// The body of the composer. Public so a test can pump it on its own.
class ComposePostBody extends StatefulWidget {
  const ComposePostBody({
    super.key,
    this.groups = const <GroupRowModel>[],
    this.initialGroupId,
    this.onPost,
  });

  final List<GroupRowModel> groups;
  final String? initialGroupId;

  /// Called with what she wrote. When absent the sheet pops with the value,
  /// which is how [showPostComposer] receives it.
  final ValueChanged<ComposedPost>? onPost;

  @override
  State<ComposePostBody> createState() => _ComposePostBodyState();
}

class _ComposePostBodyState extends State<ComposePostBody> {
  final TextEditingController _text = TextEditingController();
  final Set<CommunityTopic> _topics = <CommunityTopic>{};

  /// 0 is her page, 1 is her day, and the rest are her groups in order.
  late int _audience = _initialAudience();

  int _initialAudience() {
    final id = widget.initialGroupId;
    if (id == null) return 0;
    final at = widget.groups.indexWhere((g) => g.groupId == id);
    return at < 0 ? 0 : at + 2;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _canPost {
    final body = _text.text.trim();
    return body.isNotEmpty && body.length <= kMaxCaptionLength;
  }

  ComposedPost get _composed => ComposedPost(
    caption: _text.text.trim(),
    isStory: _audience == 1,
    groupId: _audience >= 2 ? widget.groups[_audience - 2].groupId : null,
    topics: _topics.toList(),
  );

  void _post() {
    if (!_canPost) return;
    final composed = _composed;
    final onPost = widget.onPost;
    if (onPost != null) {
      onPost(composed);
      return;
    }
    Navigator.of(context).pop(composed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // Her page, her day, then each room she is in. A group she has not joined
    // is not offered, because posting into one is not something she can do.
    final audiences = <String>[
      l10n.yourPage,
      l10n.yourDay,
      for (final group in widget.groups) group.name,
    ];

    final topics = <CommunityTopic>[
      for (final topic in CommunityTopic.values)
        if (topicLabel(topic, l10n) != null) topic,
    ];

    // Lifted with the keyboard. The sheet scrolls, so the Post button stays
    // reachable while she is typing rather than sitting under the keys.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.writeAPost, style: AppText.titleL),
          const SizedBox(height: 12),
          AppField(
            controller: _text,
            label: l10n.writeAPost,
            autofocus: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),
          Text(l10n.postTo, style: AppText.titleM),
          const SizedBox(height: 8),
          AppChipRow(
            items: audiences,
            selected: <int>{_audience},
            grow: false,
            onTap: (i) => setState(() => _audience = i),
          ),
          const SizedBox(height: 14),
          Text(l10n.addTopics, style: AppText.titleM),
          const SizedBox(height: 8),
          AppChipRow(
            items: <String>[for (final t in topics) topicLabel(t, l10n)!],
            selected: <int>{
              for (var i = 0; i < topics.length; i++)
                if (_topics.contains(topics[i])) i,
            },
            grow: false,
            onTap: (i) => setState(() {
              final topic = topics[i];
              if (!_topics.remove(topic) && _topics.length < kMaxPostTopics) {
                _topics.add(topic);
              }
            }),
          ),
          const SizedBox(height: 16),
          // One tap, and five seconds to take it back. No confirmation.
          AppButton(l10n.post, onPressed: _canPost ? _post : null),
        ],
      ),
    );
  }
}
