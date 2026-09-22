/// G09 — session done. **Actual work only.**
///
/// Matches `6-v2/src/screens-coached.mjs` → `G09`. Its design note: *"The
/// summary reports completed and skipped sets honestly, adds optional effort
/// and a note, and sends the real numbers. Nothing here converts a prescription
/// into a result."*
///
/// The last line on the screen says so out loud — "Your actual numbers go to
/// Sara. Prescribed values are never counted as completed work" — and it is
/// true because every figure above it comes from `SessionSummary`, which counts
/// sets carrying an outcome. "12 of 14" is twelve results over fourteen
/// requests, and the denominator is labelled as a request.
///
/// Her numbers reach the coach through the **projection**, not through a copy
/// made here: this screen sends nothing to a second store.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'coached_widgets.dart';

class SessionDoneView extends StatelessWidget {
  const SessionDoneView({
    super.key,
    this.onSend,
    this.onBackToToday,
    this.onEffort,
    this.selectedEffort = 1,
    this.headline,
    this.setsCompleted,
    this.skipped,
    this.personalBest,
    this.note,
  });

  final VoidCallback? onSend;
  final VoidCallback? onBackToToday;
  final ValueChanged<int>? onEffort;

  /// Easy · About right · Hard. Optional — she may send without answering.
  final int selectedEffort;

  /// "Full-body strength · 34 minutes · from Coach Sara".
  final String? headline;

  /// "12 of 14" — outcomes over requests.
  final String? setsCompleted;

  /// "2 · lunges". Null when she skipped nothing, and the row is then absent
  /// rather than reading "0".
  final String? skipped;

  /// Null when there was none. A session with no best is the ordinary case and
  /// must not render as an absence of achievement.
  final String? personalBest;

  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      footer: [
        AppButton(l10n.saveAndSendToSara, icon: Icons.send, onPressed: onSend),
        AppButton(
          l10n.backToToday,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: onBackToToday,
        ),
      ],
      children: [
        const SizedBox(height: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A finished session is the same good moment whether she trains alone or
            // with a coach, so it carries the same picture as R10 rather than a
            // different one for the sake of variety.
            Center(child: AppArt.image(AppArt.strongArms, size: 128)),
            const SizedBox(height: 12),
            // Done, ticked by hand in sage beside the words that say so.
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(child: Text(l10n.sessionDone, style: AppText.display)),
                const SizedBox(width: 12),
                const HandTick(size: 52, drawOn: true),
              ],
            ),
            // "Full-body strength · 34 minutes · from Coach Sara" is the
            // prototype's session, down to the minute. Hers, or nothing.
            if (headline case final line?) ...[
              const SizedBox(height: 6),
              Text(
                line,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        AppCard(
          variant: AppCardVariant.sage,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          gap: 0,
          children: [
            // "12 of 14" is the mockup's tally. A row with no count is not
            // a row, so it is absent rather than wrong.
            if (setsCompleted case final sets?)
              CoachedKeyValue(
                label: l10n.setsCompleted,
                value: sets,
                last: skipped == null && personalBest == null,
              ),
            if (skipped != null)
              CoachedKeyValue(
                label: l10n.skipped,
                value: skipped!,
                last: personalBest == null,
              ),
            if (personalBest != null)
              CoachedKeyValue(
                label: l10n.personalBest,
                value: personalBest!,
                last: true,
              ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.howHardWasIt,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            AppChipRow(
              items: [l10n.easy, l10n.aboutRight, l10n.hard],
              selected: {selectedEffort},
              onTap: onEffort,
            ),
          ],
        ),
        AppField(
          label: l10n.anythingSaraShouldKnowOptional,
          hint: note ?? l10n.kneesFeltFineToday,
        ),
        Text(
          l10n.yourActualNumbersGoToSaraPrescribed,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
