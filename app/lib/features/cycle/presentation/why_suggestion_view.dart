/// Y05 — Why this suggestion?
///
/// Matches `screens-cycle.mjs` → `Y05`. Every health claim shows what she
/// logged, what the option is, and one source.
///
/// This screen is the visible proof of rule 4: the reason it gives is the list
/// of **symptoms she logged**, taken straight from `DaySuggestion.reason`. There
/// is no date on this screen and nothing here can reach one, so "because you are
/// on day 2" is not a sentence it can produce.
///
/// The standing note — "for general wellbeing, not diagnosis or contraception" —
/// is a required string, not decoration (plan §12).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/symptom_context.dart';
import 'symptom_labels.dart';

class WhySuggestionView extends StatelessWidget {
  const WhySuggestionView({
    super.key,
    required this.reason,
    this.onClose,
    this.onReadSource,
  });

  /// What she logged. Never empty for a real suggestion — `GentlerOption` and
  /// `Suppressed` both assert it in their constructors.
  final List<LoggedSymptom> reason;

  final VoidCallback? onClose;
  final VoidCallback? onReadSource;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final logged = loggedSymptomsSentence(l10n, reason);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      footer: [
        AppButton(
          l10n.close,
          variant: AppButtonVariant.outlined,
          height: 48,
          fontSize: 15,
          onPressed: onClose,
        ),
      ],
      children: [
        Text(l10n.whyThisSuggestion, style: AppText.titleL),
        AppCard(
          variant: AppCardVariant.filled,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          children: [
            Text(
              l10n.howAreYouFeeling,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            // Her logged symptoms, computed. Not the mockup's sentence unless
            // hers happens to be the pair it describes.
            if (logged.isNotEmpty) Text(logged, style: AppText.bodyM),
          ],
        ),
        Text(l10n.gentleMovementMayHelpSomePeopleWith, style: AppText.bodyM),
        // The one source. It cites NHS guidance, which is British — G9 OQ-11
        // flags this as needing an Egyptian source and a named clinical
        // reviewer. Rendered because it is approved copy already in the
        // dictionary; reported because it should not stay British.
        //
        // Pen-underlined like every other link in the product, and at least
        // 44 high so the source is as easy to reach as the claim is to read.
        HandPressable(
          onTap: onReadSource,
          builder: (_, _) => ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: AppColors.primaryDim,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: HandUnderline(
                    level: HandLevel.crafted,
                    width: 1.2,
                    color: AppColors.primaryDim.withValues(alpha: 0.8),
                    gap: 1,
                    child: Text(
                      l10n.nhsPeriodPain,
                      style: AppText.label.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AppSageNote(l10n.cycleDatesAreEstimatesThisFeatureIs),
      ],
    );
  }
}
