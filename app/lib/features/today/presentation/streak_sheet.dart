/// D37 — her training streak, and every control over it, on one sheet.
///
/// Opened from the streak line on Home and from Progress. It says what the
/// streak is in one sentence — rest days count while her week's goal is in
/// reach, an earned rest week covers a week that slips, it lives on this phone
/// — and puts the three things she might want within one tap: pause it, resume
/// it, switch it off. Nothing on it asks her to protect anything, and nothing
/// on it is red.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/rewards/training_streak.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_toggle.dart';
import 'today_cards.dart' show weekdayLabel;

/// "Monday 20/10": the weekday in her language, the date in Western digits.
String pauseEndLabel(AppL10n l10n, DateTime end) =>
    '${weekdayLabel(l10n, end)} ${countLabel(end.day)}/${countLabel(end.month)}';

/// The one line that describes where her streak stands, for Home, Progress
/// and the top of this sheet.
String trainingStreakLine(AppL10n l10n, StreakStatus status) {
  if (status.pausedToday) {
    final end = status.pauseEndsOn;
    return end == null
        ? l10n.pausedUntilYouComeBack
        : l10n.pausedUntilDate(pauseEndLabel(l10n, end));
  }
  if (status.days <= 0) return l10n.dayOneStartsWithYourNextSession;
  return l10n.daysPluralOneTrainingStreak1Day(status.days);
}

Future<void> showTrainingStreakSheet(
  BuildContext context, {
  required StreakStatus status,
  required ValueChanged<StreakPauseLength> onPause,
  required VoidCallback onResume,
  required ValueChanged<bool> onSwitch,
}) {
  final l10n = AppL10n.of(context);
  final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);

  void then(BuildContext sheet, VoidCallback action) {
    Navigator.of(sheet).pop();
    action();
  }

  return showAppSheet<void>(
    context: context,
    children: [
      Text(l10n.trainingStreak, style: AppText.titleL),
      Text(
        trainingStreakLine(l10n, status),
        key: const ValueKey('trainingStreakSheetLine'),
        style: AppText.titleM.copyWith(color: AppColors.tertiary),
      ),
      if (status.best > 0)
        Text(l10n.daysPluralOneYourBest1Day(status.best), style: quiet),
      Text(l10n.restDaysCountWhileYourWeekGoal, style: quiet),
      Builder(
        builder: (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status.pausedToday)
              AppButton(
                l10n.resumeNow,
                variant: AppButtonVariant.tonal,
                onPressed: () => then(sheet, onResume),
              )
            else ...[
              for (final (length, label) in [
                (StreakPauseLength.week, l10n.pauseForAWeek),
                (StreakPauseLength.fortnight, l10n.pauseForTwoWeeks),
                (StreakPauseLength.untilResumed, l10n.pauseUntilIComeBack),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppButton(
                    label,
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    fontSize: 15,
                    onPressed: () => then(sheet, () => onPause(length)),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.showMyTrainingStreak, style: AppText.body),
                ),
                AppToggle(
                  value: status.enabled,
                  semanticLabel: l10n.showMyTrainingStreak,
                  onChanged: (on) => then(sheet, () => onSwitch(on)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.keptOnThisPhoneTurnItOff, style: quiet),
          ],
        ),
      ),
    ],
  );
}
