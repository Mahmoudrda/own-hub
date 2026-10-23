/// "Your lunch picks": the foods she has eaten before at the meal she is on,
/// each one tap away at the portion she usually has.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../domain/allergy_guard.dart';
import '../domain/food_library.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import 'eat_sample_library.dart';
import 'eat_widgets.dart';

/// Her own foods for [slot], most-eaten there first and most recent as the
/// tie-break, each at the size and servings she last had.
///
/// Read from the plates her phone already remembers, so it needs no query. A
/// plate counts for a slot as soon as she has had it there once: a pick is a
/// shortcut back to something she chose, not a claim about a habit. Foods that
/// have left the pack, or that her avoid list rules out, are skipped, and the
/// list is empty when she has no history for the slot.
List<ParsedItem> slotPicks({
  required EatPrefs prefs,
  required FoodLibrary library,
  required AllergyGuard guard,
  required MealSlot slot,
  int limit = 8,
}) {
  final plates = [
    for (final plate in prefs.plates.values)
      if ((plate.slotCounts[slot] ?? 0) > 0) plate,
  ];
  plates.sort((a, b) {
    final bySlot = b.slotCounts[slot]!.compareTo(a.slotCounts[slot]!);
    return bySlot != 0 ? bySlot : b.lastAt.compareTo(a.lastAt);
  });

  final seen = <String>{};
  final entries = <ParsedItem>[];
  for (final plate in plates) {
    for (final item in plate.items) {
      if (seen.contains(item.foodId)) continue;
      final entry = entryFor(library, item.foodId, sizeId: item.size);
      if (entry == null) continue;
      seen.add(item.foodId);
      entries.add(
        ParsedItem(
          food: entry.food,
          size: entry.size,
          servings: item.servings.toInt().clamp(1, 9),
          sourceText: entry.sourceText,
        ),
      );
    }
  }
  final allowed = guard
      .screenSuggestions([for (final e in entries) e.food])
      .map((f) => f.foodId)
      .toSet();
  return [
    for (final e in entries)
      if (allowed.contains(e.food.foodId)) e,
  ].take(limit).toList();
}

String slotPicksTitle(AppL10n l10n, MealSlot slot) => switch (slot) {
  MealSlot.breakfast => l10n.yourBreakfastPicks,
  MealSlot.lunch => l10n.yourLunchPicks,
  MealSlot.dinner => l10n.yourDinnerPicks,
  MealSlot.snack => l10n.yourSnackPicks,
};

/// The row of picks, or nothing when there are none.
class SlotPicksRow extends StatelessWidget {
  const SlotPicksRow({
    super.key,
    required this.slot,
    required this.picks,
    required this.onAdd,
  });

  final MealSlot slot;
  final List<ParsedItem> picks;
  final ValueChanged<ParsedItem> onAdd;

  @override
  Widget build(BuildContext context) {
    if (picks.isEmpty) return const SizedBox.shrink();
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          slotPicksTitle(l10n, slot),
          key: const ValueKey('slot-picks-title'),
          style: AppText.titleM,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          key: const ValueKey('slot-picks'),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final pick in picks) ...[
                  QuickAddCard(
                    key: ValueKey('pick-${pick.food.foodId}'),
                    title: pick.food.names.first,
                    meta: l10n.kcalKcalProteinGProtein(
                      countLabel(pick.kcal),
                      countLabel(pick.proteinG),
                    ),
                    addLabel: l10n.addName(pick.food.names.first),
                    onAdd: () => onAdd(pick),
                  ),
                  const SizedBox(width: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
