/// The chat list for a coach or a client: one row per relationship, built from
/// the relationship documents alone, so opening it reads no messages.
library;

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../domain/subscription.dart';
import '../desk/desk_model.dart' show tagOf;
import '../member/coach_card.dart';
import 'chat_logic.dart';

class ChatListView extends StatefulWidget {
  const ChatListView({
    super.key,
    required this.relationships,
    required this.myUid,
    required this.personOf,
    required this.onOpen,
    this.onBack,
    this.now,
  });

  final List<Relationship> relationships;
  final String myUid;

  /// Name and photo of the other person, by uid.
  final ChatPerson Function(String uid) personOf;
  final void Function(Relationship relationship) onOpen;
  final VoidCallback? onBack;
  final DateTime Function()? now;

  @override
  State<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  final TextEditingController _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The coach's list names a client, never "My coach": without a name for
  /// her it shows her tag. The client's list names the coach.
  ChatPerson _person(AppL10n l10n, Relationship r) {
    final person = widget.personOf(r.otherParty(widget.myUid));
    if (r.coachUid == widget.myUid && person.name == l10n.myCoach) {
      return ChatPerson(
        uid: person.uid,
        name: l10n.clientTag(tagOf(r.id)),
        photoUrl: person.photoUrl,
      );
    }
    return person;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final now = (widget.now ?? DateTime.now)();
    final q = _query.text.trim().toLowerCase();
    final rows = <(Relationship, ChatThread, ChatPerson)>[
      for (final r in widget.relationships)
        (r, ChatThread.of(r, widget.myUid), _person(l10n, r)),
    ]..sort((a, b) => ChatThread.newestFirst(a.$2, b.$2));
    final shown = [
      for (final row in rows)
        if (q.isEmpty || row.$3.name.toLowerCase().contains(q)) row,
    ];
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      tooltip: l10n.back,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      icon: const Icon(Icons.arrow_back),
                      color: AppColors.ink,
                      onPressed: widget.onBack,
                    )
                  else
                    const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        l10n.messages,
                        style: AppText.headline.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.search,
                  style: AppText.body.copyWith(color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText: l10n.searchChats,
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: AppColors.surfaceLowest,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: rows.isEmpty
                  ? _Empty(
                      title: l10n.noChatsYet,
                      body: l10n.yourChatsWithYourCoachOrYour,
                    )
                  : shown.isEmpty
                  ? _Empty(title: l10n.noChatsMatchYourSearch)
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const Divider(
                        height: 1,
                        indent: 72,
                        color: AppColors.borderWarm,
                      ),
                      itemBuilder: (context, i) {
                        final (relationship, thread, person) = shown[i];
                        return ChatRowTile(
                          person: person,
                          thread: thread,
                          myUid: widget.myUid,
                          now: now,
                          onTap: () => widget.onOpen(relationship),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row: photo, name, last line, time and the unread badge.
class ChatRowTile extends StatelessWidget {
  const ChatRowTile({
    super.key,
    required this.person,
    required this.thread,
    required this.myUid,
    required this.now,
    required this.onTap,
  });

  final ChatPerson person;
  final ChatThread thread;
  final String myUid;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final last = thread.last;
    final at = thread.at;
    final preview = last == null ? '' : previewOf(l10n, last, myUid);
    final time = at == null ? '' : listTimeLabel(l10n, at, now);
    final unread = thread.unread;
    final spoken = <String>[
      person.name,
      if (preview.isNotEmpty) preview,
      if (time.isNotEmpty) time,
      if (unread > 0) l10n.countUnread('$unread'),
    ].join(', ');
    return Semantics(
      button: true,
      label: spoken,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                CoachPhoto(
                  name: person.name,
                  photoUrl: person.photoUrl,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.titleM.copyWith(color: AppColors.ink),
                      ),
                      if (preview.isNotEmpty)
                        Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyM.copyWith(
                            color: unread > 0
                                ? AppColors.ink
                                : AppColors.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: AppText.nav.copyWith(
                          color: unread > 0
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    if (unread > 0)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AppRadius.full),
                          ),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: AppText.nav.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.titleL.copyWith(color: AppColors.ink),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
