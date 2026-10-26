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
import '../../../ui/hand/spring_pop.dart';

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
        Center(
          child: SampleNotification(body: l10n.morningHadBreakfastYetLogItIn),
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

/// A sample Own Hub notification in a large pale pink circle: what the phone
/// will show, before the phone asks. It pops in once and sits still with
/// motion off. Decorative, so a screen reader skips it.
class SampleNotification extends StatelessWidget {
  const SampleNotification({super.key, required this.body});

  /// One of the nudge texts, the way it will read on the lock screen.
  final String body;

  @override
  Widget build(BuildContext context) {
    // The sample is a picture of a notification: at the largest text sizes it
    // is scaled down inside its circle rather than overflowing it.
    return ExcludeSemantics(
      child: Container(
        key: const ValueKey('notification-sample'),
        width: 184,
        height: 184,
        padding: const EdgeInsets.all(14),
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SpringPop(
            from: 0.7,
            child: Container(
              width: 152,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppShadow.raised,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Own Hub',
                          style: AppText.titleS.copyWith(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          body,
                          style: AppText.bodyM.copyWith(
                            fontSize: 10.5,
                            height: 1.25,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
