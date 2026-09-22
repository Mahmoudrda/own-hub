/// The pieces the five assistant screens share, and the two that are shared
/// because a rule says they must be.
///
/// [AssistantRefusalBody] is the important one. `X02` is a **state of the `X01`
/// conversation**, not a separate destination — G15 §3.1's table puts `refused`
/// in the same machine as `answered` — so the refusal is one widget rendered in
/// two places rather than two renderings that can drift apart. The same reason
/// `CycleHubView` draws Y11 and Y14 as branches of Y03.
///
/// [AssistantHeldBadge] is the second: `K26` and `K27` both have to say *draft*
/// in the same word, because the one thing neither screen can do is publish.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/hand/hand.dart';
import '../domain/safety_classifier.dart';
import 'assistant_copy.dart';

/// `sectionHead()` — a 17px heading with the prototype's spacing.
class AssistantSectionHead extends StatelessWidget {
  const AssistantSectionHead(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(title, style: AppText.titleM),
  );
}

/// An icon beside a sentence, in a card that explains rather than blocks.
///
/// Every state this feature cannot serve is drawn with one of these. Rule 9's
/// guard bans `showDialog` across the tree, and a notice she can read while
/// still seeing the screen she was on is better than one that covers it.
class AssistantNotice extends StatelessWidget {
  const AssistantNotice({
    super.key,
    required this.icon,
    this.text = '',
    this.variant = AppCardVariant.tonal,
    this.tone = AppColors.primaryDim,
    this.heading = '',
  });

  final IconData icon;

  /// Empty renders no line at all — the shape a missing dictionary string
  /// takes on every screen in this feature.
  final String text;
  final String heading;
  final AppCardVariant variant;
  final Color tone;

  @override
  Widget build(BuildContext context) => AppCard(
    variant: variant,
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    gap: 3,
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (heading.isNotEmpty) Text(heading, style: AppText.titleM),
                if (heading.isNotEmpty && text.isNotEmpty)
                  const SizedBox(height: 3),
                if (text.isNotEmpty) Text(text, style: AppText.bodyM),
              ],
            ),
          ),
        ],
      ),
    ],
  );
}

/// One line of `X03`'s two lists: a tick or a cross, then the sentence.
class AssistantBoundaryLine extends StatelessWidget {
  const AssistantBoundaryLine(this.text, {super.key, required this.allowed});

  final String text;
  final bool allowed;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        allowed ? Icons.check : Icons.close,
        size: 19,
        color: allowed ? AppColors.tertiary : AppColors.error,
      ),
      const SizedBox(width: 9),
      Expanded(child: Text(text, style: AppText.bodyM)),
    ],
  );
}

/// Her words, as she typed them. Held in memory for the lifetime of the route
/// and discarded on pop — G15 §1.1 stores no transcript anywhere.
class AssistantAskBubble extends StatelessWidget {
  const AssistantAskBubble(this.question, {super.key});

  final String question;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      // Blush, like the marker: what she wrote on the page herself.
      child: HandSurface(
        seed: handSeed(['bubble', question]),
        // The tail: the bottom corner on her side of the page.
        looseAt: HandCorner.bottomEnd,
        fill: AppColors.primaryContainer,
        radius: 5,
        looseCorner: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(question, style: AppText.bodyM),
      ),
    ),
  );
}

/// The reply side of the conversation. Takes widgets, not a string, because
/// what sits in it is a dictionary sentence, source chips and nothing else.
class AssistantReplyBubble extends StatelessWidget {
  const AssistantReplyBubble({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      // A white slip framed in pencil: a reply laid on her page, not ink of
      // her own.
      child: HandSurface(
        seed: handSeed(['reply', children.length]),
        looseAt: HandCorner.bottomStart,
        fill: AppColors.surfaceLowest,
        frame: AppColors.outline.withValues(alpha: 0.55),
        frameWidth: 1.05,
        radius: 5,
        looseCorner: 16,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              children[i],
            ],
          ],
        ),
      ),
    ),
  );
}

/// `Draft`. The badge both draft screens wear, because neither can publish.
class AssistantHeldBadge extends StatelessWidget {
  const AssistantHeldBadge({super.key});

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: AppPill(
      AppL10n.of(context).draft,
      background: AppColors.amberContainer,
      foreground: AppColors.amber,
      icon: Icons.edit_note,
    ),
  );
}

/// The row on `X01` that says some questions will not be answered.
///
/// The design points it at `X02`. It leads to **`X03`** instead, because `X02`
/// is a state of the conversation and not a destination: navigating to a
/// refusal she has not triggered would render a refusal of nothing. The screen
/// that actually explains the sentence in this row is the boundaries one, and
/// it is the screen that works when the feature does not.
class AssistantBoundaryRow extends StatelessWidget {
  const AssistantBoundaryRow({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppListItem(
      leading: const Icon(
        Icons.support_agent,
        size: 21,
        color: AppColors.error,
      ),
      title: l10n.sharpOrNewPain,
      subtitle: l10n.someQuestionsItWillNotAnswerAnd,
      trailing: const Icon(
        Icons.chevron_right,
        size: 21,
        color: AppColors.onSurfaceVariant,
      ),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    );
  }
}

/// `X02`, drawn wherever the conversation is refused.
///
/// The ordering is the whole content of `P0-ASK-05`: on an emergency the route
/// to care **leads**, and everywhere else it follows the refusal. That is read
/// from [AskScreen.promotesCare] rather than decided here, so the screen and
/// the view model cannot disagree.
///
/// An unsafe request gets neither the medical sentence nor the route to care:
/// see [assistantRefusalLine] for why the nearest line is not borrowed.
class AssistantRefusalBody extends StatelessWidget {
  const AssistantRefusalBody({
    super.key,
    required this.category,
    required this.promotesCare,
    this.onFindCare,
    this.onMessageSara,
    this.onBoundaries,
  });

  final RefusalCategory category;
  final bool promotesCare;
  final VoidCallback? onFindCare;
  final VoidCallback? onMessageSara;

  /// Where an unsafe request is sent instead of to a clinic: the screen that
  /// says what it will and will not do.
  final VoidCallback? onBoundaries;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final refusal = assistantRefusalLine(l10n, category);
    final guidance = assistantCareGuidance(l10n, category);
    final routesToCare = refusalRoutesToCare(category);

    final refusalBlock = <Widget>[
      // Null for an unsafe request: the screen refuses by offering nothing and
      // naming its boundaries, rather than by borrowing the medical sentence.
      if (refusal != null) AssistantReplyBubble(children: [Text(refusal)]),
    ];

    final careBlock = <Widget>[
      if (routesToCare) ...[
        AssistantNotice(
          icon: Icons.support_agent,
          heading: l10n.thisNeedsADoctorNotAnApp,
          // Empty on a plain diagnostic question: the general pain line would
          // be about something she may not have mentioned.
          text: guidance ?? '',
          variant: AppCardVariant.error,
          tone: AppColors.error,
        ),
        AppButton(
          l10n.findCareNearYou,
          height: 48,
          fontSize: 15,
          onPressed: onFindCare,
        ),
      ],
    ];

    final blocks = <Widget>[
      if (promotesCare) ...[
        ...careBlock,
        ...refusalBlock,
      ] else ...[
        ...refusalBlock,
        ...careBlock,
      ],
      AppButton(
        l10n.messageSara,
        variant: AppButtonVariant.outlined,
        height: 44,
        fontSize: 14,
        onPressed: onMessageSara,
      ),
      if (!routesToCare)
        AppButton(
          l10n.whatItCanAndCannotDo,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 14,
          onPressed: onBoundaries,
        ),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        gap: 3,
        children: [
          Text(l10n.whatIDidWithThatMessage, style: AppText.titleM),
          Text(
            l10n.nothingWasLoggedAndNothingWasShared,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          blocks[i],
        ],
      ],
    );
  }
}
