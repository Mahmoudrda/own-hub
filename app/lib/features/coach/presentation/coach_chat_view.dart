/// `K16` — a conversation with a client.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K16`.
///
/// # §2 rule 2, visible on the screen
///
/// There is no control here that touches a plan. The composer produces a
/// [CoachMessageDraft], which has three fields and none of them is a plan field,
/// and [CoachChatService] holds no plan repository to reach for. The screen
/// cannot change a plan because the objects it holds cannot express one.
///
/// # The banner is context, and only what the switches allow
///
/// "Second quiet week. Her rest week is already used." is drawn from the
/// client-view projection. When she has not shared her logs the field is
/// **absent from the document**, so there is nothing to draw and no banner
/// appears — not a banner saying "not shared" (`P1-RULE-15`).
///
/// # A queued message is never a failed one
///
/// `P0-CCHAT-01`. An unsent message renders with "Waiting for signal" and the
/// same weight as any other; it is hers the moment she taps send.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/client_view.dart';
import '../domain/coach_chat.dart';
import 'coach_setup_scaffold.dart';

class CoachChatView extends StatelessWidget {
  const CoachChatView({
    super.key,
    required this.messages,
    this.clientName = '',
    this.week,
    this.onBack,
    this.onOpenClient,
    this.onSend,
    this.onSendText,
  });

  final List<CoachMessage> messages;
  final String clientName;

  /// What the projection carries about her week. Null when the switch is off,
  /// and null draws nothing at all.
  final ClientWeekSignal? week;

  final VoidCallback? onBack;
  final VoidCallback? onOpenClient;

  /// Wired by the host to [CoachChatService.send]. Null leaves the composer
  /// inert rather than drawing a send button that discards her message.
  final VoidCallback? onSend;

  /// The same send, with the words she typed.
  ///
  /// When it is supplied the composer becomes a real field: the mic and the
  /// hint stay, and the send arrow carries her sentence instead of a tap. It
  /// is a second callback rather than a change to [onSend] because tests and
  /// the screen catalogue construct this view with the old one.
  final ValueChanged<String>? onSendText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final signal = week;

    return AppScaffold(
      scrollable: false,
      appBar: AppTopBar(
        title: clientName,
        // `W10` is the coach's chat list, G14's screen.
        onBack: () => goToScreen(context, 'W10', onBack),
        actions: [
          IconButton(
            tooltip: l10n.clients,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.person_outline),
            onPressed: () => goToScreen(context, 'W02', onOpenClient),
          ),
        ],
      ),
      footer: [_Composer(onSend: onSend, onSendText: onSendText)],
      children: [
        // Context above the thread, so her reply can be about the person
        // rather than about the data.
        if (signal != null && signal.warrantsBanner)
          AppCard(
            variant: AppCardVariant.amber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber,
                    size: 22,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.secondQuietWeekHerRestWeekIs,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
        for (final message in messages) _Bubble(message: message),
      ],
    );
  }
}

/// One message. Hers on the right, the client's on the left.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final CoachMessage message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final mine = message.isFromCoach;

    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // Hers on blush, the client's on white paper framed in pencil,
            // each with its one loose corner on the side it was sent from.
            HandSurface(
              seed: handSeed(['bubble', message.body]),
              looseAt: mine ? HandCorner.bottomEnd : HandCorner.bottomStart,
              fill: mine ? AppColors.primaryContainer : AppColors.surfaceLowest,
              frame: mine ? null : AppColors.outline.withValues(alpha: 0.55),
              frameWidth: 1.05,
              radius: 6,
              looseCorner: 16,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                message.body,
                style: AppText.bodyM.copyWith(color: AppColors.onSurface),
              ),
            ),
            // Queued, quietly. Never "failed", and never a retry button that
            // would mint a second id.
            if (message.delivery.isPending) ...[
              const SizedBox(height: 3),
              Text(
                l10n.waitingForSignal,
                style: AppText.nav.copyWith(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The composer. Three affordances and no fourth.
class _Composer extends StatefulWidget {
  const _Composer({this.onSend, this.onSendText});

  final VoidCallback? onSend;
  final ValueChanged<String>? onSendText;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final words = _controller.text.trim();
    if (words.isEmpty) return;
    widget.onSendText!(words);
    // Cleared here rather than by the host: the thread below already holds
    // her sentence, and a composer that keeps it invites a second send.
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final typed = widget.onSendText;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      borderRadius: AppRadius.full,
      // The whole card is the control only while there is nothing to type in.
      onTap: typed == null ? widget.onSend : null,
      children: [
        Row(
          children: [
            const Icon(Icons.mic, size: 22, color: AppColors.primaryDim),
            const SizedBox(width: 10),
            Expanded(
              child: typed == null
                  ? Text(
                      l10n.messageOrHoldToTalk,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : TextField(
                      controller: _controller,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration.collapsed(
                        hintText: l10n.messageOrHoldToTalk,
                        hintStyle: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            if (typed == null)
              const Icon(Icons.send, size: 22, color: AppColors.primaryDim)
            else
              IconButton(
                tooltip: l10n.send,
                iconSize: 22,
                color: AppColors.primaryDim,
                icon: const Icon(Icons.send),
                onPressed: _controller.text.trim().isEmpty ? null : _send,
              ),
          ],
        ),
      ],
    );
  }
}
