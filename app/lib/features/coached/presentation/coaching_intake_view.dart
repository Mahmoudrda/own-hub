/// G01 — Your coaching · your training. Step 1 of 3.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G01`.
///
/// Two things this screen does before it asks her for anything:
///
///  1. **It states what she bought.** The coach, the dates, the review cadence
///     and the working hours sit above the first question. A woman who has just
///     paid 1,800 EGP should not have to remember what she agreed to.
///  2. **It reuses what the product already knows.** Her goal, days, session
///     length, place and equipment come from `users/{uid}.profile`, which G2
///     wrote at setup. The chips open with her existing answers selected rather
///     than blank — asking a woman twice is how she learns the app is not
///     listening.
///
/// "Saved as you go" is literally true: each step merges only its own fields,
/// so closing here leaves a real answer rather than a half-written record.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_segmented.dart';
import '../../../ui/hand/hand.dart';
import 'coached_widgets.dart';

class CoachingIntakeView extends StatelessWidget {
  const CoachingIntakeView({
    super.key,
    this.onClose,
    this.onContinue,
    this.onMessageCoach,
    this.coachName,
    this.coachDetail,
    this.packageLabel,
    this.selectedGoal = 0,
    this.selectedDays = const {1},
    this.selectedSessionLength = 1,
    this.selectedPlace = const <int>{},
    this.onGoal,
    this.onDay,
    this.onSessionLength,
    this.onPlace,
  });

  final VoidCallback? onClose;
  final VoidCallback? onContinue;
  final VoidCallback? onMessageCoach;

  /// Null falls back to the dictionary's coach, which is what the standalone
  /// preview of this screen renders.
  final String? coachName;
  final String? coachDetail;

  /// What she bought, as one line — "30 days · 12 Sep – 11 Oct". **Null when
  /// we have not been given her dates**, and then the row is absent: the
  /// dictionary's "30 days · 8 Sep to 7 Oct" is the prototype's month, and a
  /// woman reading it would be told her coaching ends on a day it does not.
  final String? packageLabel;

  /// Her existing answers, echoed from her profile.
  final int selectedGoal;
  final Set<int> selectedDays;
  final int selectedSessionLength;
  final Set<int> selectedPlace;

  final ValueChanged<int>? onGoal;
  final ValueChanged<int>? onDay;
  final ValueChanged<int>? onSessionLength;
  final ValueChanged<int>? onPlace;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.yourCoaching,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      footer: [AppButton(l10n.continueLabel, onPressed: onContinue)],
      children: [
        AppCard(
          variant: AppCardVariant.tonal,
          children: [
            CoachRow(
              name: coachName ?? l10n.coachSaraHany,
              detail:
                  coachDetail ??
                  l10n.registeredDietitianAndCoachPostpartumStrength,
              onMessage: onMessageCoach,
              messageTooltip: l10n.messageSara,
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          gap: 0,
          children: [
            if (packageLabel case final package?)
              CoachedKeyValue(label: l10n.package, value: package),
            // The cadence is the product's, not the mockup's: reviews are
            // weekly and there is a wrap-up on day thirty for everyone.
            CoachedKeyValue(
              label: l10n.reviews,
              value: l10n.every7DaysAndOnDay30,
              last: true,
            ),
          ],
        ),
        AppSegmented(
          items: [l10n.yourTraining, l10n.yourFood, l10n.yourSupport],
          selectedIndex: 0,
        ),
        // The step's number set by hand beside its title — the line under
        // it already says which step this is; the figure is only the page
        // numbering itself.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HandFigure('1', size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.yourTraining, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    l10n.step1Of3SavedAsYou,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        _Question(
          label: l10n.goal,
          child: AppChipRow(
            items: [l10n.getStronger, l10n.feelBetter, l10n.loseWeight],
            selected: {selectedGoal},
            onTap: onGoal,
            grow: false,
          ),
        ),
        _Question(
          label: l10n.daysYouCanTrain,
          child: AppChipRow(
            items: [l10n.sat, l10n.sun, l10n.mon, l10n.tue, l10n.thu],
            selected: selectedDays,
            onTap: onDay,
          ),
        ),
        _Question(
          label: l10n.timePerSession,
          child: AppChipRow(
            items: [l10n.n15Min, l10n.n20Min, l10n.n30Min],
            selected: {selectedSessionLength},
            onTap: onSessionLength,
          ),
        ),
        _Question(
          label: l10n.whereAndWithWhat,
          child: AppChipRow(
            items: [l10n.atHome, l10n.dumbbells3Kg],
            selected: selectedPlace,
            onTap: onPlace,
            grow: false,
          ),
        ),
      ],
    );
  }
}

/// A label above a row of chips. Three lines, repeated four times, so it is a
/// widget rather than four copies that drift.
class _Question extends StatelessWidget {
  const _Question({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
