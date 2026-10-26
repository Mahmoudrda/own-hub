/// A plan her coach shared, as she reads it: a workout with the app's own clips,
/// or a meal plan by day.
///
/// Her phone screens the plan when it draws it. A day her life stage is not
/// offered is left out, a move her stage holds back is marked and its day
/// cannot be started, and a meal item with something she avoids (or nobody has
/// checked) carries a line saying so. Starting a workout and logging a meal go
/// out through callbacks, so Train and Eat run their own guards.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_list_item.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../eat/domain/allergy_guard.dart';
import '../../../onboarding/domain/intake.dart' show LifeStage;
import '../../../train/data/exercise_media_store.dart';
import '../../../train/domain/exercise_library.dart';
import '../../../train/domain/my_plan.dart';
import '../../../train/domain/workout_library.dart';
import '../../../train/presentation/exercise_clip_player.dart';
import '../../../train/presentation/exercise_demo_view.dart';
import '../../domain/coach_plan.dart';
import '../../domain/coaching_contract.dart';
import '../desk/desk_text.dart' show dateText;
import '../plans/coach_plan_logic.dart';
import 'coach_meal_row.dart';
import 'coach_today.dart';
import '../plans/plan_labels.dart';

/// The days of [plan] a woman at [stage] is offered, as indexes of the plan.
List<int> offeredDays(MyPlan plan, LifeStage? stage) => [
  for (var i = 0; i < plan.days.length; i++)
    if (suits(plan.days[i].session, stage)) i,
];

/// The moves of day [dayIndex] her stage holds back, as indexes of the day.
/// A move the library does not hold counts as held back whenever the stage
/// restricts anything: its tags cannot be read, so it cannot be called safe.
Set<int> heldBackMoves(
  MyPlan plan,
  int dayIndex,
  List<LibraryExercise> library,
  LifeStage? stage,
) {
  final moves = plan.days[dayIndex].session.moves;
  final blocked = blockedMoveIds(
    [for (final m in moves) m.exerciseId],
    library,
    stage,
  );
  return {
    for (var i = 0; i < moves.length; i++)
      if (blocked.contains(moves[i].exerciseId)) i,
  };
}

class CoachPlanView extends StatelessWidget {
  CoachPlanView({
    super.key,
    required this.plan,
    this.lifeStage,
    this.constraints = DietaryConstraints.unknown,
    MealCatalog? catalog,
    this.exercises = const <LibraryExercise>[],
    this.media = const NoExerciseMedia(),
    this.players,
    this.preview = false,
    this.doneThisWeek = 0,
    this.now,
    this.onStartWorkout,
    this.onOpenRecipe,
    this.onLog,
    this.onBack,
    this.onGrocery,
    this.allWeeks = false,
  }) : catalog = catalog ?? MealCatalog();

  final CoachPlan plan;
  final LifeStage? lifeStage;
  final DietaryConstraints constraints;
  final MealCatalog catalog;

  /// The exercise library, for the clips and for the life-stage screen.
  final List<LibraryExercise> exercises;
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory? players;

  /// The coach looking at her own plan: no start and no log.
  final bool preview;

  /// Sessions she has finished this week: with her stage they pick today's
  /// workout day, the one day that carries the filled Start.
  final int doneThisWeek;

  /// The clock, for today's meal day. The phone's by default.
  final DateTime Function()? now;

  /// Starts day [dayIndex] of the workout. Null hides the button.
  final void Function(int dayIndex)? onStartWorkout;

  /// Opens a recipe's own screen.
  final void Function(String recipeId)? onOpenRecipe;

  /// Logs one meal item. The caller runs the allergy guard and the undo.
  final void Function(MealItem item, String slot)? onLog;
  final VoidCallback? onBack;
  final VoidCallback? onGrocery;
  final bool allWeeks;

  LibraryExercise? _exercise(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _watch(BuildContext context, String id) {
    final e = _exercise(id);
    if (e == null) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (route) => ExerciseDemoView(
            exercise: e,
            media: media,
            players: players,
            onClose: () => Navigator.of(route).maybePop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return AppScaffold(
      appBar: AppTopBar(
        title: plan.name.isEmpty ? l10n.fromYourCoach : plan.name,
        onBack: onBack,
      ),
      children: [
        Text(
          [
            if (plan.coachName.isNotEmpty) plan.coachName,
            l10n.versionN(countLabel(plan.revision)),
          ].join(' · '),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        if (plan.workout != null) ..._workout(context, l10n, lang),
        if (plan.meal != null) ..._meals(context, l10n, lang),
        Text(
          l10n.ifYouHaveAHealthConditionCheck,
          key: const ValueKey('plan-doctor-line'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- workout

  List<Widget> _workout(BuildContext context, AppL10n l10n, String lang) {
    final workout = plan.workout!;
    final shown = offeredDays(workout, lifeStage);
    if (shown.isEmpty) {
      return [
        AppCard(
          variant: AppCardVariant.amber,
          children: [
            Text(
              l10n.heldBackForHowYouAreTraining,
              key: const ValueKey('plan-all-held-back'),
              style: AppText.bodyM,
            ),
          ],
        ),
      ];
    }
    final nowDay = (now ?? DateTime.now)();
    final weekNow = currentWeekOf(workout, plan.startsOn, nowDay);
    final started =
        workout.weekCount <= 1 || plan.startsOn == null || weekNow != null;
    final visible = workout.weekCount > 1 && !allWeeks && weekNow != null
        ? [
            for (final d in shown)
              if (workout.days[d].week == weekNow) d,
          ]
        : shown;
    final today = todaysWorkoutDay(
      workout,
      doneThisWeek,
      lifeStage,
      startsOn: plan.startsOn,
      now: nowDay,
    );
    return [
      if (workout.weekCount > 1)
        Text(
          !started
              ? l10n.yourPlanStartsDate(dateText(l10n, plan.startsOn))
              : l10n.weekNOfTotal(
                  countLabel(weekNow ?? 1),
                  countLabel(workout.weekCount),
                ),
          key: const ValueKey('plan-week-line'),
          style: AppText.titleS,
        ),
      for (var i = 0; i < visible.length; i++) ...[
        if (allWeeks &&
            workout.weekCount > 1 &&
            (i == 0 ||
                workout.days[visible[i]].week !=
                    workout.days[visible[i - 1]].week))
          Text(
            l10n.weekN(countLabel(workout.days[visible[i]].week)),
            style: AppText.titleS,
          ),
        _dayCard(
          context,
          l10n,
          lang,
          workout,
          visible[i],
          allWeeks
              ? [
                  for (final d in visible)
                    if (workout.days[d].week == workout.days[visible[i]].week) d,
                ].indexOf(visible[i])
              : i,
          isToday: visible[i] == today,
        ),
      ],
      if (workout.weekCount > 1 && !allWeeks)
        AppButton(
          l10n.seeAllWeeks,
          key: const ValueKey('plan-all-weeks'),
          variant: AppButtonVariant.text,
          height: 48,
          onPressed: () => unawaited(
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (route) => CoachPlanView(
                  plan: plan,
                  lifeStage: lifeStage,
                  constraints: constraints,
                  catalog: catalog,
                  exercises: exercises,
                  media: media,
                  players: players,
                  preview: preview,
                  doneThisWeek: doneThisWeek,
                  now: now,
                  onStartWorkout: onStartWorkout,
                  onOpenRecipe: onOpenRecipe,
                  onLog: onLog,
                  allWeeks: true,
                  onBack: () => Navigator.of(route).maybePop(),
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _dayCard(
    BuildContext context,
    AppL10n l10n,
    String lang,
    MyPlan workout,
    int d,
    int position, {
    required bool isToday,
  }) {
    final session = workout.days[d].session;
    final held = heldBackMoves(workout, d, exercises, lifeStage);
    final canStart = !preview && onStartWorkout != null && held.isEmpty;
    return _DayCard(
      key: ValueKey('plan-workout-day-$d'),
      title: '${countLabel(position + 1)}. ${session.title(lang)}',
      meta: <String>[
        l10n.minutesMin(countLabel(session.minutes)),
        l10n.countPluralOne1MoveOtherCount(session.moves.length),
      ].join(' · '),
      initiallyOpen: isToday,
      body: [
        for (var m = 0; m < session.moves.length; m++)
          _moveRow(
            context,
            l10n,
            lang,
            session.moves[m],
            key: 'plan-move-$d-$m',
            heldBack: held.contains(m),
          ),
        if (held.isNotEmpty)
          Text(
            l10n.heldBackForHowYouAreTraining,
            key: ValueKey('plan-held-note-$d'),
            style: AppText.bodyM.copyWith(color: AppColors.error),
          ),
        if (onStartWorkout != null && !preview)
          AppButton(
            l10n.startThisWorkout,
            key: ValueKey('plan-start-$d'),
            variant: isToday ? AppButtonVariant.filled : AppButtonVariant.text,
            height: isToday ? 56 : 48,
            onPressed: canStart ? () => onStartWorkout!(d) : null,
          ),
      ],
    );
  }

  Widget _moveRow(
    BuildContext context,
    AppL10n l10n,
    String lang,
    AuthoredMove move, {
    required String key,
    required bool heldBack,
  }) {
    final name = lang == 'ar' && move.nameAr.isNotEmpty
        ? move.nameAr
        : move.nameEn;
    final canWatch = !heldBack && _exercise(move.exerciseId) != null;
    final note = lang == 'ar' && move.notesAr.isNotEmpty
        ? move.notesAr
        : move.notesEn;
    final safety = lang == 'ar' && move.safetyAr.isNotEmpty
        ? move.safetyAr
        : move.safetyEn;
    final nameStyle = AppText.titleM.copyWith(
      color: heldBack ? AppColors.onSurfaceVariant : null,
      decoration: heldBack ? TextDecoration.lineThrough : null,
    );
    final row = AppListItem(
      key: ValueKey(key),
      title: name,
      titleWidget: Text(name, style: nameStyle),
      subtitle: [
        moveAmount(l10n, move),
        if (safety.isNotEmpty) safety,
        if (note.isNotEmpty) note,
      ].join('\n'),
      trailing: canWatch
          ? const Icon(Icons.play_circle_outline, size: 24)
          : null,
      onTap: canWatch ? () => _watch(context, move.exerciseId) : null,
    );
    if (!canWatch) return row;
    return Semantics(
      button: true,
      label: '${l10n.watchTheClip}: $name',
      excludeSemantics: true,
      child: row,
    );
  }

  // ------------------------------------------------------------------ meals

  List<Widget> _meals(BuildContext context, AppL10n l10n, String lang) {
    final meal = plan.meal!;
    final flags = flagMealPlan(meal, constraints, catalog);
    MealFlag? flagOf(int day, String slot, int index) {
      for (final f in flags) {
        if (f.day == day && f.slot == slot && f.index == index) return f;
      }
      return null;
    }

    var anyFigure = false;
    final today = todaysMealDay(plan, (now ?? DateTime.now)());
    final cards = <Widget>[];
    for (var d = 0; d < meal.days.length; d++) {
      final day = meal.days[d];
      final total = dayNutrition(day, catalog);
      anyFigure = anyFigure || !total.isEmpty;
      cards.add(
        _DayCard(
          key: ValueKey('plan-meal-day-$d'),
          title: mealDayLabel(l10n, day.label),
          initiallyOpen: d == today,
          body: [
            for (final slot in CoachingEnums.mealSlots)
              for (var i = 0; i < day.itemsIn(slot).length; i++)
                CoachMealRow(
                  item: day.itemsIn(slot)[i],
                  slot: slot,
                  catalog: catalog,
                  keyPrefix: 'plan-item-$d-$slot-$i',
                  flag: flagOf(d, slot, i),
                  onOpenRecipe: onOpenRecipe,
                  onLog: preview ? null : onLog,
                  compact: true,
                ),
            if (!total.isEmpty)
              Text(
                [
                  dayNutritionLine(l10n, total),
                  if (total.partial) l10n.someItemsHaveNoFigures,
                ].join(' · '),
                key: ValueKey('plan-day-figures-$d'),
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
          ],
        ),
      );
    }
    return [
      if (meal.goal != null)
        Text(
          l10n.yourCoachsTargetKcalCaloriesAndProtein(
            '${meal.goal!.kcalPerDay}',
            '${meal.goal!.proteinGPerDay}',
          ),
          key: const ValueKey('plan-goal-line'),
          style: AppText.bodyM,
        ),
      ...cards,
      if (anyFigure)
        Text(
          l10n.figuresComeFromOwnHubsFoodTables,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      if (!preview && onGrocery != null)
        AppButton(
          l10n.groceryList,
          key: const ValueKey('plan-grocery'),
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onGrocery,
        ),
    ];
  }
}

/// One day of a plan. Today's day starts open; the others show their name and
/// open on a tap, so the screen leads with the day she is on.
class _DayCard extends StatefulWidget {
  const _DayCard({
    super.key,
    required this.title,
    required this.body,
    required this.initiallyOpen,
    this.meta = '',
  });

  final String title;
  final String meta;
  final List<Widget> body;
  final bool initiallyOpen;

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return AppListItem(
        title: widget.title,
        subtitle: widget.meta,
        trailing: const Icon(Icons.expand_more, size: 24),
        onTap: () => setState(() => _open = true),
      );
    }
    return AppCard(
      variant: AppCardVariant.outlined,
      borderRadius: AppRadius.md,
      children: [
        Semantics(
          header: true,
          child: Text(widget.title, style: AppText.titleM),
        ),
        if (widget.meta.isNotEmpty)
          Text(
            widget.meta,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ...widget.body,
      ],
    );
  }
}
