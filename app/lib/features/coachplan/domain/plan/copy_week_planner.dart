/// W05 — "10 days written, 2 replaced", said **before** it happens.
///
/// `P0-PLAN-02`: the sheet states the count and names the days it would
/// replace, by date, before the action; cancelling writes nothing; confirming
/// replaces exactly those. Coaches lose trust the first time a copy silently
/// erases work, and that trust does not come back.
///
/// ## This is not the rule-9 violation it looks like
///
/// §2.9 is "undo, not confirmation" — for **logging**. `P1-RULE-09` explicitly
/// exempts destructive bulk actions, and copying a week over existing work is
/// the definition of one. No logging action exists on any screen in this
/// feature, so there is nothing here for the undo rule to govern. Stated so QA
/// does not read the sheet as a violation.
///
/// ## The summary is computed in memory
///
/// Zero reads, and therefore exact offline (`P2-OFF-W05`). Both W05 and a split
/// application name their overwrites through this one type, so the two cannot
/// describe the same act differently.
library;

import 'package:meta/meta.dart';

import 'plan_draft.dart';

/// What a bulk write would do, before it does it.
@immutable
class OverwriteSummary {
  OverwriteSummary({
    required List<String> written,
    required List<String> replaced,
  }) : written = List<String>.unmodifiable(written),
       replaced = List<String>.unmodifiable(replaced);

  /// Every day the action would write, in date order.
  final List<String> written;

  /// The days that already hold something and would be replaced, named so the
  /// sheet can list them rather than counting them.
  final List<String> replaced;

  int get daysWritten => written.length;
  int get daysReplaced => replaced.length;

  /// True when nothing would be lost — the sheet still appears, because the
  /// coach asked for a bulk action either way, but it has nothing to warn
  /// about.
  bool get isNonDestructive => replaced.isEmpty;

  /// What a bulk write of [incoming] would do to [draft].
  static OverwriteSummary forIncoming(
    PlanDraft draft,
    Map<String, PlanDay> incoming,
  ) {
    final written = incoming.keys.toList()..sort();
    return OverwriteSummary(
      written: written,
      replaced: <String>[
        for (final key in written)
          if (draft.days.containsKey(key)) key,
      ],
    );
  }

  @override
  String toString() =>
      'OverwriteSummary($daysWritten written, $daysReplaced replaced)';
}

/// Copies one week onto others.
class CopyWeekPlanner {
  const CopyWeekPlanner();

  /// The days [sourceDays] would produce at [targetStarts].
  ///
  /// Each target start is the first day of a destination week; the source week
  /// is laid down from there in order. Days are **copied by value**, so
  /// editing Tuesday of week 2 afterwards does not reach into week 3.
  Map<String, PlanDay> project({
    required PlanDraft draft,
    required List<String> sourceDayKeys,
    required List<DateTime> targetStarts,
  }) {
    final source = <String, PlanDay>{
      for (final key in sourceDayKeys)
        if (draft.days.containsKey(key)) key: draft.days[key]!,
    };
    final ordered = source.keys.toList()..sort();

    final out = <String, PlanDay>{};
    for (final start in targetStarts) {
      for (var i = 0; i < ordered.length; i++) {
        final target = start.add(Duration(days: i));
        out[_dayKey(target)] = source[ordered[i]]!.copy();
      }
    }
    return out;
  }

  /// What that projection would overwrite. Call this before [apply], always.
  OverwriteSummary summarise({
    required PlanDraft draft,
    required Map<String, PlanDay> projection,
  }) => OverwriteSummary.forIncoming(draft, projection);

  /// The draft with the projection merged in.
  ///
  /// Only the named days change: `days` is a map, so every other date is
  /// carried through untouched. Cancelling is simply not calling this.
  PlanDraft apply({
    required PlanDraft draft,
    required Map<String, PlanDay> projection,
  }) => draft.withDays(projection, origin: DraftOrigin.copy);

  /// Days that fall outside [draft]'s month.
  ///
  /// `P2-ERR-W05`: copying week 4 onto the following month must load or create
  /// the second month's draft first, and the summary must cover both. Naming
  /// the strays is how a caller knows a second document is involved before it
  /// half-applies a week.
  List<String> daysOutsideMonth({
    required PlanDraft draft,
    required Map<String, PlanDay> projection,
  }) => <String>[
    for (final key in projection.keys)
      if (!key.startsWith('${draft.month}-')) key,
  ]..sort();

  static String _dayKey(DateTime moment) =>
      '${moment.year.toString().padLeft(4, '0')}-'
      '${moment.month.toString().padLeft(2, '0')}-'
      '${moment.day.toString().padLeft(2, '0')}';
}
