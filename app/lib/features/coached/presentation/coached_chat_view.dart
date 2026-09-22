/// G14 — the conversation.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G14`. Its design note: *"Plan
/// updates appear as system cards, separate from what the coach wrote."*
///
/// ## Three things this screen is careful about
///
///  1. **A plan update is not a message.** [PlanUpdatedChip] is centred, green
///     and pill-shaped — it cannot be mistaken for either party's bubble. It is
///     rendered from published versions, so a coach describing a change in a
///     bubble produces a bubble and no chip.
///  2. **The hours are real.** The banner states her actual working hours and
///     that the thread is not monitored at night, so nobody waits up for a 2am
///     reply that was never promised.
///  3. **An ended relationship is readable.** With [composerEnabled] false the
///     composer is replaced by a plain explanation rather than a control that
///     fails when she taps it. The security rules reject a forced write either
///     way; this is the honest surface for it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import 'coached_widgets.dart';

/// One row in the thread: a bubble, or the system chip.
@immutable
class ThreadEntry {
  const ThreadEntry.message({
    required this.mine,
    this.text,
    this.state,
    this.attachmentLabel,
    this.voiceDuration,
    this.queued = false,
  }) : planUpdate = null;

  /// A published revision, rendered as a system chip.
  const ThreadEntry.planUpdate(String label)
    : planUpdate = label,
      mine = false,
      text = null,
      state = null,
      attachmentLabel = null,
      voiceDuration = null,
      queued = false;

  final bool mine;
  final String? text;
  final String? state;
  final String? attachmentLabel;
  final String? voiceDuration;
  final bool queued;

  /// Non-null for the system chip.
  final String? planUpdate;
}

class CoachedChatView extends StatelessWidget {
  const CoachedChatView({
    super.key,
    this.onBack,
    this.onMore,
    this.onAttach,
    this.onVoice,
    this.onSendText,
    this.onOpenAttachment,
    this.onOpenPlanUpdate,
    this.coachName,
    this.serviceHours,
    this.entries,
    this.composerEnabled = true,
  });

  final VoidCallback? onBack;
  final VoidCallback? onMore;
  final VoidCallback? onAttach;
  final VoidCallback? onVoice;

  /// Supplied by a host that can store a message. Without it the composer is
  /// the prototype's inert row; with it she can write and send, and the same
  /// thread is what `K16` shows the coach.
  final ValueChanged<String>? onSendText;

  final VoidCallback? onOpenAttachment;
  final VoidCallback? onOpenPlanUpdate;

  final String? coachName;
  final String? serviceHours;

  final List<ThreadEntry>? entries;

  /// False once the relationship has ended.
  final bool composerEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // An empty thread is an empty thread. The prototype's four messages —
    // "Can we make Thursday shorter? I have 20 minutes.", a plan updated on
    // Thursday 18 September — are one woman's conversation, and showing them
    // to everyone else puts words in her mouth and a date on a change that
    // never happened.
    final thread = entries ?? const <ThreadEntry>[];

    return AppScaffold(
      appBar: AppTopBar(
        title: coachName ?? l10n.saraHany,
        onBack: onBack,
        actions: [
          IconButton(
            onPressed: onMore,
            iconSize: 22,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      footer: [
        CoachedComposer(
          hint: l10n.messageSara,
          enabled: composerEnabled,
          closedNotice: l10n.readableNewMessagesAreClosed,
          onAttach: onAttach,
          onVoice: onVoice,
          onSendText: onSendText,
          attachTooltip: l10n.photo,
          voiceTooltip: l10n.voiceNote,
          sendTooltip: l10n.send,
        ),
      ],
      children: [
        // Her coach's hours, or nothing. "Sun–Thu, 9:00–17:00 Cairo" is one
        // coach's working week, and a woman whose coach answers on Friday
        // would have been told to expect silence.
        if (serviceHours case final hours?)
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Text(
                hours,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        for (final entry in thread)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: entry.planUpdate != null
                ? PlanUpdatedChip(
                    label: entry.planUpdate!,
                    onTap: onOpenPlanUpdate,
                  )
                : ChatBubble(
                    text: entry.text,
                    mine: entry.mine,
                    state: entry.state,
                    attachmentLabel: entry.attachmentLabel,
                    onOpenAttachment: onOpenAttachment,
                    voiceDuration: entry.voiceDuration,
                    voicePlayTooltip: l10n.voiceNote,
                    queued: entry.queued,
                  ),
          ),
      ],
    );
  }
}
