/// The Home card for a woman with a coach: today's coach workout, the next live
/// session, and whether her coach has written.
library;

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../coaching_when.dart';
import '../desk/desk_text.dart' show dateText;
import '../../../onboarding/domain/intake.dart' show LifeStage;
import '../../domain/coach_plan.dart';
import '../../domain/subscription.dart';
import 'coach_today.dart';

class CoachHomeCard extends StatelessWidget {
  const CoachHomeCard({
    super.key,
    this.workout,
    this.nextSession,
    this.hasUnread = false,
    this.doneThisWeek = 0,
    this.lifeStage,
    this.onStartWorkout,
  });

  /// The latest workout plan her coach shared, if any.
  final CoachPlan? workout;

  /// The soonest session that is proposed or confirmed.
  final LiveSession? nextSession;
  final bool hasUnread;

  /// Sessions she has finished this week, to pick the day.
  final int doneThisWeek;
  final LifeStage? lifeStage;

  /// Starts the coach workout day shown. Null hides the button.
  final void Function(CoachPlan plan, int dayIndex)? onStartWorkout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final plan = workout?.workout;
    final day = plan == null
        ? null
        : todaysWorkoutDay(
            plan,
            doneThisWeek,
            lifeStage,
            startsOn: workout?.startsOn,
          );
    final at = nextSession?.startsAt;
    return AppCard(
      key: const ValueKey('coach-home-card'),
      variant: AppCardVariant.tonal,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.fromYourCoach, style: AppText.titleM),
        ),
        Text(
          day == null
              ? (workout?.startsOn != null && plan != null && plan.weekCount > 1
                    ? l10n.yourPlanStartsDate(dateText(l10n, workout!.startsOn))
                    : l10n.yourCoachHasNotSetAPlan)
              : l10n.todaysWorkoutName(plan!.days[day].session.title(lang)),
          key: const ValueKey('coach-home-workout'),
          style: AppText.bodyM,
        ),
        if (plan != null && plan.weekCount > 1 && day != null)
          Text(
            l10n.weekNOfTotal(
              countLabel(plan.days[day].week),
              countLabel(plan.weekCount),
            ),
            key: const ValueKey('coach-home-week'),
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (at != null)
          Text(
            l10n.nextSessionWhen(
              '${coachWhen(l10n, at, cairo: true)} · ${l10n.cairoTime}',
            ),
            key: const ValueKey('coach-home-session'),
            style: AppText.bodyM,
            textDirection: Directionality.of(context),
          ),
        if (hasUnread)
          Text(
            l10n.newMessagesFromYourCoach,
            key: const ValueKey('coach-home-unread'),
            style: AppText.titleS.copyWith(color: AppColors.primaryDim),
          ),
        if (day != null && onStartWorkout != null)
          AppButton(
            l10n.startThisWorkout,
            key: const ValueKey('coach-home-start'),
            height: 48,
            onPressed: () => onStartWorkout!(workout!, day),
          ),
      ],
    );
  }
}
