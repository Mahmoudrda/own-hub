/// The sentence before the phone's own question.
///
/// Shown at value moments only: the offer on `R10` after a finished session,
/// and the reminders row on `A01` when she asks for them. Never at launch.
/// What she gets, one primary "Turn on reminders", a quiet "Not now". Saying
/// yes only opens the days sheet, whose Save is what asks the phone, so
/// nothing here prompts and a "Not now" asks nothing of anyone.
///
/// The [tips] wording is the one offer on `C13` "You're in", or the first
/// Home after it: the getting started tips and the reminders she can choose.
/// It promises no days, because saying yes there sets none.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/hand/mascot/kitten.dart';

/// True when she chose to go on, false or null when she did not.
Future<bool?> showNotificationExplainer(
  BuildContext context, {
  bool tips = false,
}) => showAppSheet<bool>(
  context: context,
  children: [
    NotificationExplainerBody(
      tips: tips,
      onChoose: (go) {
        Navigator.of(context).pop(go);
      },
    ),
  ],
);

class NotificationExplainerBody extends StatelessWidget {
  const NotificationExplainerBody({
    super.key,
    required this.onChoose,
    this.tips = false,
  });

  final ValueChanged<bool> onChoose;

  /// The getting started wording, from `C13`.
  final bool tips;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    Widget line(String text) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check, size: 18, color: AppColors.primaryDim),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: quiet)),
      ],
    );
    return Column(
      key: const ValueKey('notification-explainer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(
          child: ExcludeSemantics(
            child: Kitten(pose: KittenPose.point, size: 56, holdStill: true),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tips ? l10n.wantAFewTipsAndYourWorkout : l10n.remindersThatFitYourDay,
          style: AppText.titleL,
        ),
        const SizedBox(height: 10),
        if (tips) ...[
          line(l10n.aFewTipsInYourFirstWeeks),
          const SizedBox(height: 8),
          line(l10n.workoutRemindersOnTheDaysYouPick),
          const SizedBox(height: 8),
          line(l10n.turnAnyOfThemOffInNotifications),
        ] else ...[
          line(l10n.aQuietNoteOnTheDaysYou),
          const SizedBox(height: 8),
          line(l10n.aQuickWayToAddASession),
          const SizedBox(height: 8),
          line(l10n.aPingWhenYourRestBetweenSets),
        ],
        const SizedBox(height: 8),
        line(l10n.remindersNeverComeBetween10PmAnd_z63uh),
        const SizedBox(height: 14),
        AppButton(
          tips ? l10n.turnOnNotifications : l10n.turnOnReminders,
          key: const ValueKey('explainer-yes'),
          onPressed: () => onChoose(true),
        ),
        AppButton(
          l10n.notNow,
          key: const ValueKey('explainer-not-now'),
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: () => onChoose(false),
        ),
      ],
    );
  }
}
