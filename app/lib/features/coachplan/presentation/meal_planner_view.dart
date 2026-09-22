/// `W06` — the month's meals, with her constraints on screen the whole time.
///
/// ## The strip is read-only, and it is the same widget W02 uses
///
/// r13 again: no coach screen has an input for `avoid` or allergies. This
/// screen renders [ConstraintPanel] and has no field of any kind — the pickers
/// are buttons, and every quantity that reaches a slot comes from G5's verified
/// pack rather than from something typed here.
///
/// ## A conflicting food is never offered, and one that arrives anyway is named
///
/// The picker is built from `MealSlotPlanner.offerable`, which screens at the
/// source. A slot filled before the allergy was recorded cannot be screened
/// that way — the slot arrived before the constraint did — so the write path
/// catches it and `blockedSlots` names the allergen here. There is no "assign
/// it anyway": the override G5 gives *her* exists because she is the authority
/// on her own body, and a coach is not.
///
/// ## An empty slot is a gap, and "she chooses" is an answer
///
/// `null` is counted; free choice is not. Publishing turns every remaining gap
/// into an explicit free choice, and what she sees here tomorrow is still the
/// gap she left.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/safety/client_constraints.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/meal/meal_slot_planner.dart';
import '../domain/plan/plan_draft.dart';
import 'coachplan_labels.dart';
import 'coachplan_widgets.dart';
import 'workout_planner_view.dart' show monthDayKeys;

class MealPlannerView extends StatelessWidget {
  const MealPlannerView({
    super.key,
    required this.draft,
    required this.constraints,
    required this.dayKey,
    this.clientName = '',
    this.coachMealNames = const <String, String>{},
    this.blockedSlots = const <BlockedMealSlot>[],
    this.onSelectDay,
    this.onOpenSlot,
    this.onSelectAppMeal,
    this.onCreateMeal,
    this.onDraftAWeek,
    this.onPublish,
    this.onBack,
  });

  final PlanDraft draft;

  /// Hers, resolved from the assessment. Rendered, never edited.
  final ClientConstraints constraints;

  /// The day being filled, `yyyy-MM-dd`.
  final String dayKey;

  final String clientName;

  /// Her coach's own dishes by id, so a slot can name the meal rather than the
  /// document. The id is never published — the publisher embeds by value.
  final Map<String, String> coachMealNames;

  /// Everything the write path refuses, with the allergen named.
  final List<BlockedMealSlot> blockedSlots;

  final ValueChanged<String>? onSelectDay;
  final ValueChanged<PlanMealSlot>? onOpenSlot;
  final VoidCallback? onSelectAppMeal;
  final VoidCallback? onCreateMeal;
  final VoidCallback? onDraftAWeek;
  final VoidCallback? onPublish;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final days = monthDayKeys(draft.month);
    final index = days.indexOf(dayKey);
    final weekStart = index < 0 ? 0 : (index ~/ 7) * 7;
    final week = days.skip(weekStart).take(7).toList(growable: false);
    final meal = draft.dayAt(dayKey)?.meal;
    final blockedHere = <PlanMealSlot, BlockedMealSlot>{
      for (final blocked in blockedSlots)
        if (blocked.dayKey == dayKey) blocked.slot: blocked,
    };

    final totalSlots = days.length * PlanMealSlot.values.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: clientName, onBack: onBack),
      body: AppScaffold(
        footer: [
          AppButton(l10n.previewAndPublish, height: 54, onPressed: onPublish),
        ],
        children: [
          // Above the slots, and it stays there while she edits.
          ConstraintPanel(constraints: constraints),
          AppChipRow(
            items: [
              for (final key in week) countLabel(dateFromDayKey(key)?.day ?? 0),
            ],
            selected: <int>{
              for (var i = 0; i < week.length; i++)
                if (week[i] == dayKey) i,
            },
            onTap: onSelectDay == null ? null : (i) => onSelectDay!(week[i]),
          ),
          for (final slot in PlanMealSlot.values)
            PlannerRow(
              key: CoachPlanKeys.slotRow(slot.wireName),
              leading: RowLabel(mealSlotLabel(l10n, slot)),
              value: _slotValue(l10n, meal?.slots[slot]),
              isGap: meal?.slots[slot] == null,
              onTap: onOpenSlot == null ? null : () => onOpenSlot!(slot),
            ),
          // Refused, with the allergen named. Never auto-assigned, never
          // silently dropped.
          for (final entry in blockedHere.entries)
            AppCard(
              key: Key('blocked:${entry.key.wireName}'),
              variant: AppCardVariant.error,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gap: 4,
              children: [
                Text(mealSlotLabel(l10n, entry.key), style: AppText.titleM),
                Text(
                  entry.value.allergens.isEmpty
                      ? entry.value.foodId ?? ''
                      : entry.value.allergens.join(' · '),
                  style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.selectAppMeal,
                  variant: AppButtonVariant.tonal,
                  height: 44,
                  fontSize: 14,
                  onPressed: onSelectAppMeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  l10n.createMeal,
                  variant: AppButtonVariant.outlined,
                  height: 44,
                  fontSize: 14,
                  icon: Icons.add,
                  onPressed: onCreateMeal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  l10n.draftAWeek,
                  variant: AppButtonVariant.text,
                  height: 44,
                  fontSize: 14,
                  onPressed: onDraftAWeek,
                ),
              ),
            ],
          ),
          // Her month against her month. A gap is counted; a stated free
          // choice is not a gap.
          LabelledValue(
            label: l10n.meals,
            value: l10n.countOfTotal('${draft.filledMealSlots}', '$totalSlots'),
          ),
        ],
      ),
    );
  }

  /// What one slot says.
  ///
  /// Free choice is an answer somebody gave, so it reads as one. An empty slot
  /// is a hole and reads as a hole. They are never the same string.
  String _slotValue(AppL10n l10n, MealSlotAssignment? assignment) {
    if (assignment == null) return l10n.nothingAssigned;
    return switch (assignment.source) {
      MealSlotSource.freeChoice => l10n.herChoice,
      MealSlotSource.library => assignment.foodIds.join(' · '),
      MealSlotSource.coach =>
        coachMealNames[assignment.coachMealId] ??
            assignment.coachMealId ??
            l10n.nothingAssigned,
    };
  }
}
