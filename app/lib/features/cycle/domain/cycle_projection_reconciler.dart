/// Rebuilds the derived fields on `cycle/current` from the period documents.
///
/// Plan §4: "`lastPeriod` … a **cache** of the newest period document; if two
/// devices disagree, `CycleProjectionReconciler.rebuild()` re-derives it from a
/// bounded `__name__` range (≤12 docs) on reconnect. A derived field that can
/// self-heal is never a conflict."
///
/// And §3.2, on why an edit is a delete plus a create: "Editing a start date
/// rewrites the id, because the id *is* the start date (C1) … `recentStarts` is
/// rebuilt from the collection inside the same transaction." That is what makes
/// Y09's note — "editing a date clears estimates built on the old one" —
/// structurally true rather than a promise the sheet makes.
///
/// **Idempotent.** Running it twice over the same periods produces the same
/// result, which is what lets a failed drain be replayed safely (§4's
/// `arrayUnion` note: "the ≤12 trim is applied by the reconciler,
/// idempotently").
library;

import 'package:meta/meta.dart';

import 'cycle_document.dart';
import 'period_entry.dart';

/// The two derived values, rebuilt together.
///
/// Returned as one object because they are derived from one source and must
/// never be written apart: a `lastPeriod` from one rebuild beside a
/// `recentStarts` from another is exactly the disagreement this class exists to
/// heal.
@immutable
class CycleProjection {
  const CycleProjection({required this.lastPeriod, required this.recentStarts});

  final LastPeriod? lastPeriod;
  final List<String> recentStarts;
}

class CycleProjectionReconciler {
  const CycleProjectionReconciler();

  /// Re-derives [LastPeriod] and `recentStarts` from the period documents.
  ///
  /// [periods] may arrive in any order and may contain more than twelve; both
  /// are normalised here so that callers never have to.
  CycleProjection rebuild(Iterable<PeriodEntry> periods) {
    final sorted = periods.toList()
      // Newest first. The id is the start date, so this is also `__name__`
      // descending — the same order the bounded range returns.
      ..sort((a, b) => b.start.compareTo(a.start));

    if (sorted.isEmpty) {
      return const CycleProjection(lastPeriod: null, recentStarts: <String>[]);
    }

    final newest = sorted.first;

    return CycleProjection(
      lastPeriod: LastPeriod(
        startDate: newest.id,
        endDate: newest.end == null ? null : isoDay(newest.end!),
      ),
      recentStarts: [
        for (final period in sorted.take(CycleDocument.maxRecentStarts))
          period.id,
      ],
    );
  }

  /// Applies a rebuild to a document.
  ///
  /// A convenience so the two derived fields are always written together — see
  /// the note on [CycleProjection].
  CycleDocument apply(CycleDocument cycle, Iterable<PeriodEntry> periods) {
    final projection = rebuild(periods);
    return cycle.copyWith(
      lastPeriod: projection.lastPeriod,
      clearLastPeriod: projection.lastPeriod == null,
      recentStarts: projection.recentStarts,
    );
  }
}
