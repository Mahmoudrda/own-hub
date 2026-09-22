/// `W10` — the inbox, ordered by who has waited longest.
///
/// ## The same documents W01 already holds
///
/// G14 §2: one listener serves W01, W10 and W11. This screen takes the roster
/// it is given and sorts it client-side with `ClientQueue.longestWaitingFirst`,
/// so opening the inbox after the client list costs **0** reads. There is no
/// repository on this widget and no query it could issue.
///
/// ## Waiting time is an order, not a score
///
/// r11. Nothing here ranks women; it orders *work*, by how long somebody has
/// been waiting for a reply her coach promised.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/hand/hand.dart';
import '../domain/clients/coach_client.dart';
import 'coachplan_widgets.dart';

/// W10's three chips. Client-side filters over one list, never three queries.
enum InboxFilter { unread, awaitingReply, all }

class CoachInboxView extends StatelessWidget {
  const CoachInboxView({
    super.key,
    required this.clients,
    this.filter = InboxFilter.all,
    this.onSelectFilter,
    this.onOpenThread,
    this.onOpenSavedReplies,
    this.onTab,
  });

  final List<CoachClient> clients;
  final InboxFilter filter;
  final ValueChanged<InboxFilter>? onSelectFilter;

  /// Given the client whose thread was tapped. The thread itself is K16's.
  final ValueChanged<CoachClient>? onOpenThread;

  final VoidCallback? onOpenSavedReplies;
  final ValueChanged<String>? onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final ordered = ClientQueue.longestWaitingFirst(clients);
    final shown = <CoachClient>[
      for (final client in ordered)
        if (_matches(client)) client,
    ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachPlanNavBar(activeScreenId: 'W10', onTab: onTab),
      body: AppScaffold(
        children: [
          // One short word, so a swipe of marker: W01 takes the underline,
          // and the coach's two hubs are not marked alike.
          AppSplitRow(
            start: MarkerHighlight(
              drawOn: true,
              child: Text(l10n.inbox, style: EditorialType.section),
            ),
            end: const SizedBox.shrink(),
          ),
          AppChipRow(
            grow: false,
            items: [
              for (final value in InboxFilter.values) _label(l10n, value),
            ],
            selected: <int>{InboxFilter.values.indexOf(filter)},
            onTap: onSelectFilter == null
                ? null
                : (i) => onSelectFilter!(InboxFilter.values[i]),
          ),
          for (final client in shown)
            AppListItem(
              key: Key('thread:${client.clientUid}'),
              title: client.displayName,
              variant: client.queue.unreadForCoach > 0
                  ? AppCardVariant.selected
                  : AppCardVariant.outlined,
              trailing: client.queue.unreadForCoach > 0
                  ? AppPill(
                      countLabel(client.queue.unreadForCoach),
                      background: AppColors.primary,
                      foreground: AppColors.onPrimary,
                    )
                  : null,
              onTap: onOpenThread == null ? null : () => onOpenThread!(client),
            ),
          AppCard(
            variant: AppCardVariant.filled,
            gap: 8,
            onTap: onOpenSavedReplies,
            children: [
              SectionHead(l10n.savedReplies),
              // A template sent verbatim as personal feedback is worse than no
              // reply, so they open as drafts she must edit.
              Text(
                l10n.openAsAnEditableDraftNothingIs,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _matches(CoachClient client) => switch (filter) {
    InboxFilter.unread => client.queue.unreadForCoach > 0,
    InboxFilter.awaitingReply => client.queue.hasUnanswered,
    InboxFilter.all => true,
  };

  static String _label(AppL10n l10n, InboxFilter value) => switch (value) {
    InboxFilter.unread => l10n.unread,
    InboxFilter.awaitingReply => l10n.awaitingReply,
    InboxFilter.all => l10n.all,
  };
}
