/// `users/{uid}/periods/{yyyy-MM-dd}` — the id **is** the start date (spine C1).
///
/// Plan §1.2. Two invariants are load-bearing and both are enforced here by
/// construction rather than by validation-at-the-edge:
///
///  1. **`start` equals the document id.** So an offline retry targets the same
///     document and collapses into the same state; a duplicate is impossible.
///     [PeriodEntry.id] is derived from [start], so they cannot disagree.
///  2. **`stillBleeding == (end == null)`.** A derived getter, not a stored
///     field. G9 §6 asks Firestore to enforce the same equality; a getter is the
///     client-side form, and there is simply no second field to fall out of
///     step.
///
/// ## Why an invalid entry cannot be constructed
///
/// §3.2's `invalid` state: "never persisted — future date, `end < start`, or
/// `stillBleeding` disagreeing with `end` … the sheet refuses with the reason on
/// screen; **no write is attempted**, so nothing to undo".
///
/// The generative constructor is private. The only way to get a [PeriodEntry] is
/// [PeriodEntry.validate], which returns a sealed result. So "no write is
/// attempted" is not a rule the sheet has to remember — an invalid entry is not
/// a value that exists, and there is nothing to hand a repository.
library;

import 'package:meta/meta.dart';

/// A document id: `yyyy-MM-dd`, Western digits, zero-padded.
///
/// G8 publishes `DocIds.day()` in the plan, but no such helper exists in this
/// tree yet, so this is defined locally and flagged rather than assumed. When
/// G8's lands, this becomes a call to it.
String isoDay(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Midnight on the day [date] falls in, so comparisons are by day and never by
/// the hour she happened to open the sheet.
DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Why a draft was refused. Y09 renders the reason on screen.
enum PeriodProblem {
  /// "Future dates are not accepted."
  startInFuture,

  /// The end date is in the future.
  endInFuture,

  /// "…and an end date cannot come before a start date."
  endBeforeStart,
}

/// The outcome of validating a draft. Sealed, so a caller must handle both.
@immutable
sealed class PeriodDraftResult {
  const PeriodDraftResult();
}

/// The draft is valid and here is the entry to save.
@immutable
final class PeriodValid extends PeriodDraftResult {
  const PeriodValid(this.entry);
  final PeriodEntry entry;
}

/// The draft is refused, with every reason it was refused for.
///
/// All problems at once rather than the first one: a woman who has picked two
/// wrong dates should be told both, not told one, corrected, and then told the
/// other.
@immutable
final class PeriodInvalid extends PeriodDraftResult {
  const PeriodInvalid(this.problems);
  final Set<PeriodProblem> problems;
}

/// One period she logged.
@immutable
class PeriodEntry {
  const PeriodEntry._({required this.start, this.end});

  /// Validates a draft. The only way to construct a [PeriodEntry].
  ///
  /// [today] is passed in rather than read from a clock so that "a future date"
  /// is testable and so that this stays a pure function. Note this is the
  /// *period* path, not the suggestion path — rule 4's ban on a clock applies to
  /// `SymptomSuggestionResolver.resolve`, and a period sheet that could not tell
  /// what day it is could not reject a future date at all.
  static PeriodDraftResult validate({
    required DateTime start,
    DateTime? end,
    required DateTime today,
  }) {
    final startDay = dayOnly(start);
    final endDay = end == null ? null : dayOnly(end);
    final todayDay = dayOnly(today);

    final problems = <PeriodProblem>{
      if (startDay.isAfter(todayDay)) PeriodProblem.startInFuture,
      if (endDay != null && endDay.isAfter(todayDay)) PeriodProblem.endInFuture,
      if (endDay != null && endDay.isBefore(startDay))
        PeriodProblem.endBeforeStart,
    };

    if (problems.isNotEmpty) return PeriodInvalid(problems);
    return PeriodValid(PeriodEntry._(start: startDay, end: endDay));
  }

  final DateTime start;

  /// Null means she is still bleeding.
  final DateTime? end;

  /// The document id, which **is** the start date (spine C1).
  String get id => isoDay(start);

  /// Derived. See the library comment — there is no field to disagree with.
  bool get stillBleeding => end == null;

  /// How many days this period covers, or null while it is open.
  int? get lengthDays => end == null ? null : end!.difference(start).inDays + 1;

  /// Whether [date] falls inside this period, inclusive.
  bool covers(DateTime date) {
    final day = dayOnly(date);
    if (day.isBefore(start)) return false;
    if (end == null) return true;
    return !day.isAfter(end!);
  }

  /// Which day of this period [date] is — 1 for the start day.
  ///
  /// Returns null when [date] is not inside the period, so "period day 2" is
  /// never rendered for a day that is not a period day.
  int? dayNumberOn(DateTime date) {
    if (!covers(date)) return null;
    return dayOnly(date).difference(start).inDays + 1;
  }

  @override
  bool operator ==(Object other) =>
      other is PeriodEntry && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() =>
      'PeriodEntry($id → ${end == null ? 'open' : isoDay(end!)})';
}
