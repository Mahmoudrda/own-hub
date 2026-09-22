/// Reading a day back, including the case where two devices wrote to it.
///
/// G5 §4.5 is honest about a limitation and this file is where it is handled:
///
/// > **`arrayUnion` cannot enforce uniqueness by `itemId`** — it dedupes by
/// > whole-element equality. Two *different* corrections of the same planned
/// > item therefore produce two entries sharing an `itemId`.
///
/// So the array is reconciled **at read time**, deterministically, so that every
/// device renders the same day and the next write rewrites the canonical array.
/// A map keyed by `itemId` would make this exact rather than convergent — that
/// is plan §9 Q11, raised rather than worked around, because the spine declares
/// `slots.<slot>` as an array and this group does not get to change it.
///
/// ## `totals` is a cache; the items are truth
///
/// §4.5 again: if read-time dedupe drops an entry, the stored `totals` disagrees
/// with the items. The reader renders [DayTotals.recompute] over the deduped
/// items and lets the next write repair the cache. Self-healing, with no
/// migration and no background job — and it means a screen can never show a
/// total that no list of food adds up to.
library;

import 'day_totals.dart';
import 'meal_repository.dart';

/// Turns the stored document into what the screens render.
class MealDayReader {
  const MealDayReader();

  /// Resolves duplicate `itemId`s and returns a stable, deterministic order.
  ///
  /// The rule, from §4.5: **keep the entry with the greatest `loggedAt`**, ties
  /// broken by the lexicographically greater hash. Within a tie the `itemId`s
  /// are equal by construction — that is what put them in the same group — so
  /// the tie is broken on [MealItem.contentSignature], which is the same
  /// comparison applied to the part that actually differs.
  ///
  /// The output is sorted by `(loggedAt, itemId)` rather than left in array
  /// order. Two devices can hold the same items in different positions, and
  /// sorting is what makes "every device renders the same day" true of the
  /// order as well as the contents.
  List<MealItem> dedupe(Iterable<MealItem> items) {
    final winners = <String, MealItem>{};

    for (final item in items) {
      final held = winners[item.itemId];
      if (held == null || _beats(item, held)) {
        winners[item.itemId] = item;
      }
    }

    final out = winners.values.toList()
      ..sort((a, b) {
        final byTime = a.loggedAt.compareTo(b.loggedAt);
        if (byTime != 0) return byTime;
        return a.itemId.compareTo(b.itemId);
      });
    return out;
  }

  /// True when [candidate] should replace [held].
  static bool _beats(MealItem candidate, MealItem held) {
    final byTime = candidate.loggedAt.compareTo(held.loggedAt);
    if (byTime != 0) return byTime > 0;
    return candidate.contentSignature.compareTo(held.contentSignature) > 0;
  }

  /// One slot, deduplicated and ordered.
  List<MealItem> itemsIn(MealDay day, MealSlot slot) =>
      dedupe(day.itemsIn(slot));

  /// Every slot, deduplicated.
  Map<MealSlot, List<MealItem>> slotsOf(MealDay day) {
    return <MealSlot, List<MealItem>>{
      for (final slot in MealSlot.values)
        if (day.itemsIn(slot).isNotEmpty) slot: itemsIn(day, slot),
    };
  }

  /// The running total, recomputed from the items.
  ///
  /// Never reads a stored `totals` field — see the file note. There is no
  /// parameter here for a target other than protein, and no return value that
  /// could hold one.
  DayTotals totals(
    MealDay day, {
    int proteinTargetG = kProvisionalProteinTargetG,
  }) {
    return DayTotals.recompute(
      dedupe(day.allItems),
      proteinTargetG: proteinTargetG,
    );
  }

  /// True when nothing has ever been logged on this day.
  ///
  /// E01 branches on this to render E09 — HANDOFF rule 16: the first run is a
  /// **state** of the Eat route, not a destination of its own.
  bool isFirstDay(MealDay day) => day.hasNothingLogged;

  /// G5 → G3: the "Breakfast: ful and baladi / Lunch: now" strip on T01.
  ///
  /// An in-process call on the document G3 has already read for Today, so it
  /// costs nothing. G3 owns T01's layout; G5 owns the numbers.
  MealDaySummary todaySummary(MealDay day) {
    final slots = slotsOf(day);
    return MealDaySummary(
      loggedSlots: slots.keys.toSet(),
      itemCount: slots.values.fold(0, (sum, items) => sum + items.length),
      firstLogAt: day.firstLogAt,
    );
  }
}

/// The small, read-only view of a day that Today renders.
class MealDaySummary {
  const MealDaySummary({
    required this.loggedSlots,
    required this.itemCount,
    this.firstLogAt,
  });

  final Set<MealSlot> loggedSlots;
  final int itemCount;
  final DateTime? firstLogAt;

  bool get hasAnythingToday => itemCount > 0;
}
