/// `X03` — what it can and cannot do.
///
/// The screen the rest of the feature is measured against, and the only one
/// that is **guaranteed to render**: it takes an [AssistantBoundaries] and
/// nothing else — no service, no provider, no connectivity, no pack. G15 §4
/// says it "fully works" offline, and §2.4 says it stays readable at the `off`
/// rung of the degrade ladder. Both are true here for the same reason: there is
/// nothing on this widget to fail.
///
/// ## The one thing the kill switch changes
///
/// [switchedOff] does not hide a word of the content. It swaps the action in
/// the footer, because *Ask something* would otherwise lead to a screen that
/// cannot answer — G15 §2.4: "X01's entry point is replaced by *Ask Sara*;
/// **X03 stays readable**". The honest description of the feature survives the
/// feature being off, which is the whole point of the screen.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'assistant_boundaries.dart';
import 'assistant_widgets.dart';

class BoundariesView extends StatelessWidget {
  const BoundariesView({
    super.key,
    required this.boundaries,
    this.switchedOff = false,
    this.onBack,
    this.onAsk,
    this.onAskSara,
  });

  /// Built by [assistantBoundaries] from the dictionary. Every string on this
  /// screen is one of its fields; not one is composed here.
  final AssistantBoundaries boundaries;

  /// `kill_switches.assistant`. See the file note — it changes the footer and
  /// nothing else.
  final bool switchedOff;

  final VoidCallback? onBack;

  /// `X01`.
  final VoidCallback? onAsk;

  /// `H06`. What the footer offers instead when the feature is off.
  final VoidCallback? onAskSara;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(title: boundaries.title, onBack: onBack),
      footer: [
        if (switchedOff)
          AppButton(l10n.askSaraInstead, height: 54, onPressed: onAskSara)
        else
          AppButton(boundaries.askCta, height: 54, onPressed: onAsk),
      ],
      children: [
        AssistantSectionHead(boundaries.canHeading),
        // Open lines on the page. Only the cannot list below is laid on its
        // own sheet, so the two lists are not one template drawn twice.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final ability in AssistantAbility.values)
                if (boundaries.can[ability] case final line?)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.5),
                    child: AssistantBoundaryLine(line, allowed: true),
                  ),
            ],
          ),
        ),
        const HandRule(seed: 61, height: 12),
        AssistantSectionHead(boundaries.cannotHeading),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          gap: 7,
          children: [
            // The longer and more specific of the two lists, which is the
            // opposite of how a feature like this is usually sold.
            for (final limit in AssistantLimit.values)
              if (boundaries.cannot[limit] case final line?)
                AssistantBoundaryLine(line, allowed: false),
          ],
        ),
        AppCard(
          variant: AppCardVariant.sage,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          gap: 3,
          children: [
            Text(boundaries.whatLeavesYourPhoneHeading, style: AppText.titleM),
            Text(boundaries.whatLeavesYourPhoneBody, style: AppText.bodyM),
          ],
        ),
      ],
    );
  }
}
