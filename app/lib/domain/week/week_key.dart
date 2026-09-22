/// The week is the only unit of time this product counts progress in.
///
/// §2 rule 3: *weeks, not days.* The research behind this product is explicit
/// that visible daily failure erodes the motivation it is built to create, so
/// there is no daily counter anywhere — and the way that is guaranteed is that
/// **nothing in this file can produce one**.
///
/// [WeekKey] can express exactly one thing: which ISO week a moment falls in, in
/// her timezone. It takes no list of days, exposes no run length, and has no
/// comparison that would let a caller count adjacent weeks into a tally. If a
/// future screen wants a daily tally, it will have to add a type to hold it —
/// which is a visible decision, reviewable in a diff, rather than a quiet one.
library;

import 'package:meta/meta.dart';

/// An ISO-8601 week, as `yyyy-Www` — the document id used by `users/{uid}/weeks`.
///
/// Deterministic by construction (spine C1): the same week always produces the
/// same id, so an offline write that replays collides with itself instead of
/// creating a second week.
@immutable
class WeekKey implements Comparable<WeekKey> {
  const WeekKey._(this.year, this.week)
    : assert(week >= 1 && week <= 53, 'ISO weeks run 1–53');

  /// The ISO week containing [moment].
  ///
  /// [moment] must already be in her timezone. The boundary is a property of the
  /// woman, not of the server: `weeklyGoal.tz` travels with her, so a woman who
  /// flies to Cairo does not gain or lose a week in transit.
  factory WeekKey.of(DateTime moment) {
    final date = DateTime.utc(moment.year, moment.month, moment.day);

    // ISO-8601: week 1 is the week containing the first Thursday of the year, and
    // weeks start on Monday. Shifting to the Thursday of this week gives the year
    // the week belongs to, which is not always the calendar year of the date —
    // 1 January 2027 is week 53 of 2026.
    final thursday = date.add(Duration(days: 4 - _isoWeekday(date)));
    final firstOfYear = DateTime.utc(thursday.year, 1, 1);
    final week = ((thursday.difference(firstOfYear).inDays) / 7).floor() + 1;
    return WeekKey._(thursday.year, week);
  }

  /// This week, on the phone she is holding.
  ///
  /// `DECISIONS.md` D17: the app is international and the week follows her
  /// device, because a Cairo-hardcoded boundary misfiles a late-evening session
  /// for the very large Egyptian population in the Gulf at UTC+3/+4.
  ///
  /// `DateTime.now()` is already local and [WeekKey.of] reads its calendar
  /// year, month and day, so this was always the behaviour. It is written down
  /// as a named constructor because "the week follows the device" was an
  /// invariant that nothing stated and no test held: every caller wrote
  /// `WeekKey.of(DateTime.now())`, which is correct and silent about why.
  ///
  /// It deliberately does **not** consult a stored zone. See
  /// [fallbackTimezone] for the half of §3.1 that pulls the other way.
  factory WeekKey.current([DateTime? now]) => WeekKey.of(now ?? DateTime.now());

  /// The zone to assume when hers has never been recorded.
  ///
  /// Lives here rather than in the rewards domain because it is a boundary
  /// concern: Eat needs the same fallback for a meal's day key, and should not
  /// have to import `weekly_goal.dart` to get it.
  ///
  /// It is a **fallback, not a claim**. `kDefaultTimezone` used to read as her
  /// zone, so every goal asserted `Africa/Cairo` whether or not she had ever
  /// been there. A stored zone still travels with her, which is deliberate: a
  /// Cairo→Gulf move must not recompute a boundary that has already passed, or
  /// last month's sessions would quietly change which week they belong to.
  /// New weeks follow her phone; closed weeks keep the boundary they were
  /// closed under.
  static const String fallbackTimezone = 'Africa/Cairo';

  /// Parses `yyyy-Www`. Returns null rather than throwing, so a malformed id read
  /// from storage degrades to "unknown week" instead of crashing her Home screen.
  static WeekKey? tryParse(String id) {
    final m = RegExp(r'^(\d{4})-W(\d{2})$').firstMatch(id);
    if (m == null) return null;
    final year = int.parse(m.group(1)!);
    final week = int.parse(m.group(2)!);
    if (week < 1 || week > 53) return null;
    return WeekKey._(year, week);
  }

  final int year;
  final int week;

  /// The document id. This is the only string form that exists.
  String get id => '$year-W${week.toString().padLeft(2, '0')}';

  /// Ordering, so a range of weeks can be requested from storage.
  ///
  /// Deliberately **not** arithmetic: there is no `+`, no `difference`, and no
  /// `isAdjacentTo`. Ordering lets you ask for the last eight weeks; it does not
  /// let you count how many ran back-to-back.
  @override
  int compareTo(WeekKey other) => year != other.year
      ? year.compareTo(other.year)
      : week.compareTo(other.week);

  @override
  bool operator ==(Object other) =>
      other is WeekKey && other.year == year && other.week == week;

  @override
  int get hashCode => Object.hash(year, week);

  @override
  String toString() => id;

  static int _isoWeekday(DateTime d) =>
      d.weekday; // Dart: Monday = 1 … Sunday = 7
}
