/// G12 — the weekly review. **One minute, mostly filled in already.**
///
/// Matches `6-v2/src/screens-coached.mjs` → `G12`. Its design note: *"The review
/// is written from her logs, so the only new input is how manageable it felt
/// and what she would change."*
///
/// ## Why the top card is read-only
///
/// "Workouts completed · 3 of 3" and "Days you logged food · 5" come from
/// `ReviewPrefill`, which counts sets carrying an outcome and days carrying a
/// meal. They are **not editable**, because they are not opinions: a review
/// where she can adjust what she did is a review that records what she wishes
/// she had done. What she can say is how it felt and what to change.
///
/// ## Weight is off, and stays off
///
/// The last row is offered, defaults to off, and is never required. What
/// reaches a coach when it is on is an open question in the plan (OQ-15) and is
/// deliberately not answered here — this screen records the opt-in and sends no
/// figure.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import 'coached_widgets.dart';

class WeeklyReviewView extends StatelessWidget {
  const WeeklyReviewView({
    super.key,
    this.onClose,
    this.onSend,
    this.onManageable,
    this.onChange,
    this.onWeightOptIn,
    this.onWorkedChanged,
    this.selectedManageable = 1,
    this.selectedChanges = const <int>{},
    this.weightOptIn = false,
    this.workoutsCompleted,
    this.foodDaysLogged,
    this.sharedWith,
    this.worked,
  });

  final VoidCallback? onClose;
  final VoidCallback? onSend;
  final ValueChanged<int>? onManageable;
  final ValueChanged<int>? onChange;
  final ValueChanged<bool>? onWeightOptIn;

  /// What she typed in "what worked well". The field was inert — no
  /// controller, no callback — so her sentence never reached her coach.
  final ValueChanged<String>? onWorkedChanged;

  final int selectedManageable;
  final Set<int> selectedChanges;
  final bool weightOptIn;

  /// "3 of 3" — counted from her logs, never from the plan.
  final String? workoutsCompleted;

  /// The number of days she logged food. A value, so it is rendered as digits.
  final String? foodDaysLogged;

  /// What she is currently sharing, stated out loud so the review is honest
  /// about what the coach can see beside it.
  final String? sharedWith;

  final String? worked;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.weeklyReview,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      footer: [AppButton(l10n.sendToSara, icon: Icons.send, onPressed: onSend)],
      children: [
        AppCard(
          gap: 8,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.yourWeekFromYourLogs, style: AppText.titleM),
                // "3 of 3" is the prototype's perfect week, told to a woman
                // who may have done one. The card is headed "your week, from
                // your logs" — so with no logs handed in, it says nothing.
                if (workoutsCompleted case final done?)
                  CoachedKeyValue(label: l10n.workoutsCompleted, value: done),
                CoachedKeyValue(
                  label: l10n.daysYouLoggedFood,
                  value: foodDaysLogged ?? '5',
                ),
                CoachedKeyValue(
                  label: l10n.sharedWithSara,
                  value: sharedWith ?? l10n.energyAndAppetite,
                  last: true,
                ),
              ],
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.howManageableWasYourPlan, style: AppText.titleM),
            const SizedBox(height: 8),
            AppChipRow(
              items: [l10n.easy, l10n.aboutRight, l10n.hardToFitIn],
              selected: {selectedManageable},
              onTap: onManageable,
            ),
          ],
        ),
        AppField(
          key: const Key('G12.worked'),
          label: l10n.whatWorkedWellOptional,
          hint: l10n.morningSessionsBeforeTheKidsWakeUp_1m46g,
          onChanged: onWorkedChanged,
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.whatWouldYouLikeToChange,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final (i, label) in [
                  l10n.workoutTime,
                  l10n.difficulty,
                  l10n.meals,
                  l10n.schedule,
                ].indexed)
                  AppChip(
                    label,
                    selected: selectedChanges.contains(i),
                    onTap: onChange == null ? null : () => onChange!(i),
                  ),
              ],
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.addWeightOrPhotos, style: AppText.titleM),
                      const SizedBox(height: 2),
                      Text(
                        l10n.optionalNeverRequired,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppToggle(
                  value: weightOptIn,
                  onChanged: onWeightOptIn,
                  semanticLabel: l10n.addWeightOrPhotos,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
