/// G04 — the coaching tab once a plan exists. **Today, and the next actions.**
///
/// Matches `6-v2/src/screens-coached.mjs` → `G04`. Its design note: *"Today is
/// the coach plan: the session with her note on it, the meals already chosen,
/// the review that is due, and any change she published. The month is one tap
/// away, so this screen only ever shows the next actions."*
///
/// ## The notice at the bottom is not a message
///
/// "Your Thursday workout was updated" is rendered **only when [planChange] is
/// non-null**, and that value comes from `PlanUpdateCard.resolve()` — published
/// versions, never message text. A coach who wrote "I've shortened Thursday"
/// and did not publish produces no row here at all.
///
/// ## One plan, one set of logs
///
/// The session card starts G4's player and the meal row logs through G5's
/// service. This screen creates no second workout history and no second food
/// diary; it is the coach's day rendered over the product she already has.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_log_button.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'coached_widgets.dart';

class CoachingPlanView extends StatelessWidget {
  const CoachingPlanView({
    super.key,
    this.onStartWorkout,
    this.onSeeMonth,
    this.onLogMeal,
    this.onOpenReview,
    this.onOpenPlanChange,
    this.onSelectDay,
    this.onSelectTab,
    this.days,
    this.selectedDay = 3,
    this.dayLabel,
    this.workoutTitle,
    this.workoutLength,
    this.coachNote,
    this.mealTitle,
    this.mealMeta,
    this.reviewDue = true,
    this.planChange,
  });

  final VoidCallback? onStartWorkout;
  final VoidCallback? onSeeMonth;
  final VoidCallback? onLogMeal;
  final VoidCallback? onOpenReview;

  /// Opens the revision the notice names. Null when nothing was published.
  final VoidCallback? onOpenPlanChange;

  final ValueChanged<int>? onSelectDay;
  final ValueChanged<String>? onSelectTab;

  final List<StripDay>? days;
  final int selectedDay;

  /// "Day 9 of 30".
  final String? dayLabel;

  final String? workoutTitle;
  final String? workoutLength;

  /// Her coach's line about today. Rendered only when she wrote one.
  final String? coachNote;

  final String? mealTitle;
  final String? mealMeta;

  final bool reviewDue;

  /// "Sara shortened it to 20 minutes" — **built from a published version**.
  /// Null renders no row.
  final String? planChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final strip =
        days ??
        [
          StripDay(weekday: l10n.sat, dayOfMonth: '12'),
          StripDay(weekday: l10n.sun, dayOfMonth: '13'),
          StripDay(weekday: l10n.mon, dayOfMonth: '14'),
          StripDay(weekday: l10n.tue, dayOfMonth: '16'),
          StripDay(weekday: l10n.wed, dayOfMonth: '17'),
          StripDay(weekday: l10n.thu, dayOfMonth: '18'),
        ];

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachedNavBar(onSelectTab: onSelectTab),
      body: AppScaffold(
        children: [
          // The tab's masthead, with her place in the month circled by hand
          // — the one figure this page is about.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(l10n.coaching, style: EditorialType.section),
              ),
              // "Day 9 of 30" is the mockup's ninth day. A woman on day two
              // sees no day label rather than somebody else's.
              if (dayLabel case final day?)
                Flexible(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 12),
                    child: HandCircled(
                      level: HandLevel.crafted,
                      width: 1.2,
                      color: AppColors.primaryDim,
                      drawOn: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.event_available,
                            size: 16,
                            color: AppColors.primaryDim,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              day,
                              style: AppText.label.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const HandRule(seed: 52, height: 8),
          CoachedDateStrip(
            days: strip,
            selectedIndex: selectedDay,
            onSelect: onSelectDay,
          ),
          AppCard(
            gap: 10,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workoutTitle ?? l10n.fullBodyStrength,
                      style: AppText.titleL,
                    ),
                  ),
                  // Thirty-five minutes is the prototype's session. Hers,
                  // or nothing.
                  if (workoutLength case final length?)
                    AppPill(
                      length,
                      background: AppColors.surfaceContainer,
                      foreground: AppColors.onSurfaceVariant,
                    ),
                ],
              ),
              // Her coach's words, and only her coach's words. "From Sara ·
              // dumbbells 3 kg · 'Keep the squat at 12 kg…'" is a note one
              // woman was written, quoted to everyone else as if it were
              // theirs.
              if (coachNote case final note?)
                Text(
                  note,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              AppButton(
                l10n.startWorkout,
                height: 54,
                icon: Icons.play_arrow,
                onPressed: onStartWorkout,
              ),
            ],
          ),
          AppCard(
            gap: 8,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.todaysMeals, style: AppText.titleM),
                  ),
                  AppButton(
                    l10n.seeAll,
                    variant: AppButtonVariant.text,
                    height: 36,
                    fontSize: 14,
                    onPressed: onSeeMonth,
                  ),
                ],
              ),
              AppListItem(
                title: mealTitle ?? l10n.lunchKoshariBowlMedium,
                // "1 serving · from your plan" states a portion nobody
                // chose. Empty renders no subtitle.
                subtitle: mealMeta ?? '',
                variant: AppCardVariant.filled,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                // One tap, then five seconds to take it back. No confirmation.
                trailing: AppLogButton(
                  l10n.iAteThis,
                  primary: true,
                  onPressed: onLogMeal,
                ),
              ),
            ],
          ),
          if (reviewDue)
            AppListItem(
              title: l10n.weeklyReviewDue,
              subtitle: l10n.oneMinuteMostlyFilledInAlready,
              variant: AppCardVariant.amber,
              onTap: onOpenReview,
              leading: const Icon(
                Icons.event_available,
                size: 22,
                color: AppColors.amber,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          // Present only when a revision was actually published.
          if (planChange != null)
            AppListItem(
              title: l10n.yourThursdayWorkoutWasUpdated,
              subtitle: planChange!,
              onTap: onOpenPlanChange,
              leading: const Icon(
                Icons.info_outline,
                size: 22,
                color: AppColors.primaryDim,
              ),
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
