/// "Ranked by how often, with the count shown" — E01's suggestions.
///
/// A **plate** is a combination she eats together: koshari and a salad is one
/// row, not two. G5 §1.1 keys it by `sha1(sorted(foodId:size))`, so the same
/// combination logged on a phone and on a tablet lands on one key.
///
/// ## Why this is not a ranking surface
///
/// §2 rule 11 — *nothing is ranked by weight, weight lost, or followers* — is
/// about ranking **women**. This ranks a woman's own plates by her own
/// frequency. There is no cross-user read anywhere in G5, no index that would
/// support one, and [rank] takes her own [EatPrefs] as its only source: there is
/// no parameter through which another woman's data could arrive.
///
/// ## Bounded by construction
///
/// A five-year user's document is the same size as a one-month user's: at most
/// [kPlateCap] plates, each holding at most a [kPlateWindow] of date keys. That
/// is what makes "needs a migration to reach 100k MAU" a no.
///
/// ## Idempotent, because commutative is not
///
/// Spine C4's correction. The counters are **absolute per (plate, date)**, taken
/// from [PlateObservation.timesToday], which is read off the day document. A
/// replayed offline write therefore writes the same number again and changes
/// nothing — whereas an increment would count the same meal twice. The two
/// histograms move by the *delta* in that absolute count, so they inherit the
/// same property rather than quietly losing it.
library;

import 'meal_repository.dart';

/// Folds logs into the rollup, and ranks what comes out.
class PlateRollup {
  const PlateRollup({this.window = kPlateWindow, this.cap = kPlateCap});

  /// The rolling window frequency is answered over. G5 §9 Q6: the count means
  /// "8 times this month", not lifetime, and E01's copy says so.
  final Duration window;

  /// The hard cap on remembered plates.
  final int cap;

  /// Folds one logging event in.
  ///
  /// Prunes date keys outside the window, writes the absolute count for this
  /// date, moves the two histograms by the delta, and evicts the least-used
  /// plate if that pushed the document over [cap].
  EatPrefs record(EatPrefs prefs, PlateObservation observation) {
    final existing = prefs.plates[observation.plateId];

    final pruned = _prune(
      existing?.dayCounts ?? const <String, int>{},
      observation.at,
    );
    final before = pruned[observation.dayId] ?? 0;
    final after = observation.timesToday;

    // A replay carries the same absolute count, so the delta is zero and the
    // histograms below do not move. That is the whole idempotency guarantee.
    final delta = after - before;

    final dayCounts = <String, int>{...pruned};
    if (after <= 0) {
      dayCounts.remove(observation.dayId);
    } else {
      dayCounts[observation.dayId] = after;
    }

    final slotCounts = <MealSlot, int>{...?existing?.slotCounts};
    final dowCounts = <int, int>{...?existing?.dowCounts};
    if (delta != 0) {
      slotCounts[observation.slot] =
          (slotCounts[observation.slot] ?? 0) + delta;
      dowCounts[observation.at.weekday] =
          (dowCounts[observation.at.weekday] ?? 0) + delta;
      slotCounts.removeWhere((_, count) => count <= 0);
      dowCounts.removeWhere((_, count) => count <= 0);
    }

    final plate = Plate(
      plateId: observation.plateId,
      items: observation.items,
      dayCounts: dayCounts,
      slotCounts: slotCounts,
      dowCounts: dowCounts,
      lastAt: existing == null || observation.at.isAfter(existing.lastAt)
          ? observation.at
          : existing.lastAt,
    );

    final plates = <String, Plate>{...prefs.plates, observation.plateId: plate};
    return prefs.copyWith(plates: _evict(plates, observation.at));
  }

  /// The plates E01 and E04 offer, best first.
  ///
  /// **A plate appears only once it has been eaten twice.** That is E09's
  /// promise — "log something twice and it becomes a one-tap plate" — and it is
  /// also what stops a one-off meal being suggested back to her forever.
  ///
  /// Ordering, most significant first:
  ///
  ///   1. how often, inside the window;
  ///   2. how often **in this slot**, when a slot is given — "what she eats at
  ///      this hour";
  ///   3. how often **on this weekday** — E04's "Tuesdays";
  ///   4. most recent, as a stable tie-break.
  ///
  /// [now] is required rather than read from the clock so the window is
  /// testable and so two devices in different timezones rank identically.
  List<Plate> rank(
    EatPrefs prefs, {
    required DateTime now,
    MealSlot? slot,
    int? weekday,
    int limit = 40,
  }) {
    final candidates = prefs.plates.values
        .where((plate) => timesEatenWithin(plate, now) >= 2)
        .toList();

    candidates.sort((a, b) {
      final byCount = timesEatenWithin(
        b,
        now,
      ).compareTo(timesEatenWithin(a, now));
      if (byCount != 0) return byCount;

      if (slot != null) {
        final bySlot = (b.slotCounts[slot] ?? 0).compareTo(
          a.slotCounts[slot] ?? 0,
        );
        if (bySlot != 0) return bySlot;
      }

      if (weekday != null) {
        final byDow = (b.dowCounts[weekday] ?? 0).compareTo(
          a.dowCounts[weekday] ?? 0,
        );
        if (byDow != 0) return byDow;
      }

      final byRecency = b.lastAt.compareTo(a.lastAt);
      if (byRecency != 0) return byRecency;

      // Deterministic last resort, so two devices with identical data produce
      // identical order rather than whatever the map happened to yield.
      return a.plateId.compareTo(b.plateId);
    });

    return candidates.take(limit).toList();
  }

  /// Times eaten inside the window ending at [now].
  int timesEatenWithin(Plate plate, DateTime now) {
    final cutoff = now.subtract(window);
    var total = 0;
    plate.dayCounts.forEach((dayId, count) {
      final day = DateTime.tryParse(dayId);
      if (day == null) return;
      if (!day.isBefore(DateTime(cutoff.year, cutoff.month, cutoff.day))) {
        total += count;
      }
    });
    return total;
  }

  /// Drops date keys that have fallen out of the window.
  Map<String, int> _prune(Map<String, int> dayCounts, DateTime now) {
    final cutoff = now.subtract(window);
    final floor = DateTime(cutoff.year, cutoff.month, cutoff.day);
    return <String, int>{
      for (final entry in dayCounts.entries)
        if (_onOrAfter(entry.key, floor)) entry.key: entry.value,
    };
  }

  static bool _onOrAfter(String dayId, DateTime floor) {
    final day = DateTime.tryParse(dayId);
    if (day == null) return false;
    return !day.isBefore(floor);
  }

  /// Keeps the document under the cap, dropping the least-used plate.
  ///
  /// Eviction key is `(count inside the window, lastAt)` — §1.1. Evicting the
  /// *least* used is what keeps her real staples on the screen; evicting the
  /// oldest would drop the breakfast she has had every day for a year.
  Map<String, Plate> _evict(Map<String, Plate> plates, DateTime now) {
    if (plates.length <= cap) return plates;

    final ordered = plates.values.toList()
      ..sort((a, b) {
        final byCount = timesEatenWithin(
          a,
          now,
        ).compareTo(timesEatenWithin(b, now));
        if (byCount != 0) return byCount;
        final byAge = a.lastAt.compareTo(b.lastAt);
        if (byAge != 0) return byAge;
        return a.plateId.compareTo(b.plateId);
      });

    final doomed = ordered.take(plates.length - cap).map((p) => p.plateId);
    return <String, Plate>{
      for (final entry in plates.entries)
        if (!doomed.contains(entry.key)) entry.key: entry.value,
    };
  }
}
