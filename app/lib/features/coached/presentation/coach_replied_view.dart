/// G13 — the coach's reply, and a plan update that **actually exists**.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G13`. Its design note is the whole
/// rule in one sentence:
///
/// > A message that says something changed, with nothing changed behind it, is
/// > how coaching over chat fails.
///
/// So the card at the bottom of this screen is not built from what the coach
/// wrote. [planChange] comes from `PlanUpdateCard.resolve()`, which reads
/// published versions and nothing else. When the coach replies without
/// publishing, [planChange] is null and **the card is absent** — not greyed
/// out, not "pending", absent. There is no text on this screen that could
/// produce one.
///
/// Her voice note plays here and is never transcribed.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import 'coached_widgets.dart';

class CoachRepliedView extends StatelessWidget {
  const CoachRepliedView({
    super.key,
    this.onBack,
    this.onReplyInChat,
    this.onOpenPlanChange,
    this.agreed,
    this.planChange,
    this.coachName,
    this.repliedAt,
    this.answeredAfter,
    this.voiceDuration,
  });

  final VoidCallback? onBack;
  final VoidCallback? onReplyInChat;

  /// Opens the revision the card names. It exists, so this always lands
  /// somewhere.
  final VoidCallback? onOpenPlanChange;

  /// "What we agreed" — the two or three points, in her coach's words.
  final List<String>? agreed;

  /// The label for the published revision, or **null when nothing was
  /// published**. Null renders no card at all.
  final String? planChange;

  final String? coachName;
  final String? repliedAt;
  final String? answeredAfter;

  /// "0:34". A value, not copy.
  final String? voiceDuration;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // The prototype agreed "Keep 12 kg on squats" and "Thursday drops to 20
    // minutes" with every woman who opened this screen. Points nobody made
    // are no points at all, and the card below is absent rather than filled
    // with another client's week.
    final points = agreed ?? const <String>[];

    return AppScaffold(
      appBar: AppTopBar(title: l10n.weeklyReview, onBack: onBack),
      footer: [
        AppButton(
          l10n.replyInChat,
          height: 52,
          icon: Icons.chat_bubble_outline,
          onPressed: onReplyInChat,
        ),
      ],
      children: [
        Row(
          children: [
            Flexible(
              child: AppPill(
                l10n.coachReplied,
                background: AppColors.tertiaryContainer,
                foreground: AppColors.tertiary,
                icon: Icons.check,
              ),
            ),
            // "2 hours after you sent it" is the mockup's turnaround. Unless
            // we were handed hers, the pill stands on its own.
            if (answeredAfter case final after?) ...[
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  after,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        AppCard(
          gap: 10,
          children: [
            CoachRow(
              name: coachName ?? l10n.saraHany,
              // A date we were not given is no date. "Sunday 20 September"
              // belonged to the mockup, not to her reply.
              detail: repliedAt ?? '',
            ),
            ChatBubble(
              voiceDuration: voiceDuration ?? '0:34',
              voicePlayTooltip: l10n.voiceNote,
            ),
          ],
        ),
        if (points.isNotEmpty)
          AppCard(
            variant: AppCardVariant.sage,
            gap: 10,
            children: [
              Text(l10n.whatWeAgreed, style: AppText.titleM),
              for (final point in points)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: 20,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(point, style: AppText.body)),
                    ],
                  ),
                ),
            ],
          ),
        // Absent when nothing was published. See the library comment.
        if (planChange != null)
          AppCard(
            variant: AppCardVariant.tonal,
            onTap: onOpenPlanChange,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.autorenew,
                    size: 22,
                    color: AppColors.primaryDim,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.planUpdated, style: AppText.titleM),
                        const SizedBox(height: 2),
                        Text(
                          planChange!,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: AppColors.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        Text(
          // What a revision does not touch.
          l10n.yesterdaysLogsAndAnySessionYouAlready,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
