/// Y13 — About cycle phases.
///
/// Matches `screens-cycle.mjs` → `Y13`. The phases explained in plain words,
/// including the fact that menstruation happens during the follicular phase.
///
/// **No day ranges, no "you are here", and no hormone chart** — plan §12: "Y13
/// explains the phases in words precisely because a calendar cannot measure
/// them." This screen takes no date, no cycle document and no estimate, so it
/// has nothing to place her on a timeline with even if a future edit wanted to.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';

class CyclePhasesView extends StatelessWidget {
  const CyclePhasesView({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final phases = <({String title, String body})>[
      (
        title: l10n.menstruation,
        body: l10n.bleedingItHappensDuringTheFollicularPhase,
      ),
      (title: l10n.follicularPhase, body: l10n.fromTheFirstDayOfBleedingUntil),
      (title: l10n.ovulation, body: l10n.anEggIsReleasedACalendarCannot),
      (
        title: l10n.lutealPhase,
        body: l10n.afterOvulationUntilTheNextPeriodStarts,
      ),
    ];

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
        Text(l10n.aboutCyclePhases, style: AppText.titleL),
        // Read like a page, not four identical tiles: each phase is an open
        // paragraph, with a pencil rule where one phase hands over to the next.
        for (var i = 0; i < phases.length; i++) ...[
          if (i > 0) HandRule(seed: 70 + i, height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(phases[i].title, style: AppText.titleM),
              const SizedBox(height: 3),
              Text(
                phases[i].body,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        AppSageNote(l10n.noDayRangesNoYouAreHere),
      ],
    );
  }
}
