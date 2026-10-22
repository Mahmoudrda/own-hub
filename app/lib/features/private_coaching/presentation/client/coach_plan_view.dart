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
import '../plans/coach_plan_logic.dart';
import 'coach_meal_row.dart';
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
    this.onStartWorkout,
    this.onOpenRecipe,
    this.onLog,
    this.onBack,
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

  /// Starts day [dayIndex] of the workout. Null hides the button.
  final void Function(int dayIndex)? onStartWorkout;

  /// Opens a recipe's own screen.
  final void Function(String recipeId)? onOpenRecipe;

  /// Logs one meal item. The caller runs the allergy guard and the undo.
  final void Function(MealItem item, String slot)? onLog;
  final VoidCallback? onBack;

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
    return [
      for (final d in shown)
        _dayCard(context, l10n, lang, workout, d, shown.indexOf(d)),
    ];
  }

  Widget _dayCard(
    BuildContext context,
    AppL10n l10n,
    String lang,
    MyPlan workout,
    int d,
    int position,
  ) {
    final session = workout.days[d].session;
    final held = heldBackMoves(workout, d, exercises, lifeStage);
    final canStart = !preview && onStartWorkout != null && held.isEmpty;
    return AppCard(
      key: ValueKey('plan-workout-day-$d'),
      variant: AppCardVariant.outlined,
      borderRadius: AppRadius.md,
      children: [
        Semantics(
          header: true,
          child: Text(
            '${countLabel(position + 1)}. ${session.title(lang)}',
            style: AppText.titleM,
          ),
        ),
        Text(
          <String>[
            l10n.minutesMin(countLabel(session.minutes)),
            l10n.countPluralOne1MoveOtherCount(session.moves.length),
          ].join(' · '),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
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
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppText.titleS.copyWith(
                    color: heldBack ? AppColors.onSurfaceVariant : null,
                    decoration: heldBack ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  moveAmount(l10n, move),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                if (safety.isNotEmpty) Text(safety, style: AppText.bodyM),
                if (note.isNotEmpty)
                  Text(
                    note,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (canWatch) const Icon(Icons.play_circle_outline, size: 24),
        ],
      ),
    );
    if (!canWatch) return KeyedSubtree(key: ValueKey(key), child: content);
    return Semantics(
      button: true,
      label: '${l10n.watchTheClip}: $name',
      child: InkWell(
        key: ValueKey(key),
        onTap: () => _watch(context, move.exerciseId),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: ExcludeSemantics(child: content),
        ),
      ),
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
    final cards = <Widget>[];
    for (var d = 0; d < meal.days.length; d++) {
      final day = meal.days[d];
      final total = dayNutrition(day, catalog);
      anyFigure = anyFigure || !total.isEmpty;
      cards.add(
        AppCard(
          key: ValueKey('plan-meal-day-$d'),
          variant: AppCardVariant.outlined,
          borderRadius: AppRadius.md,
          children: [
            Semantics(
              header: true,
              child: Text(mealDayLabel(l10n, day.label), style: AppText.titleM),
            ),
            for (final slot in CoachingEnums.mealSlots)
              if (day.itemsIn(slot).isNotEmpty) ...[
                Text(
                  slotLabel(l10n, slot),
                  style: AppText.titleS.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                for (var i = 0; i < day.itemsIn(slot).length; i++)
                  CoachMealRow(
                    item: day.itemsIn(slot)[i],
                    slot: slot,
                    catalog: catalog,
                    keyPrefix: 'plan-item-$d-$slot-$i',
                    flag: flagOf(d, slot, i),
                    onOpenRecipe: onOpenRecipe,
                    onLog: preview ? null : onLog,
                  ),
              ],
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
      ...cards,
      if (anyFigure)
        Text(
          l10n.figuresComeFromOwnHubsFoodTables,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
    ];
  }
}
