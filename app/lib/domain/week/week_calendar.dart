/// Calendar arithmetic over ISO weeks, kept out of [WeekKey] itself.
///
/// [WeekKey] is an id: it parses, compares and prints. Walking from one week to
/// the next, or listing a week's days, is arithmetic on the calendar, and it
/// lives here so the id stays the small value the rules and the snapshot key
/// documents by.
///
/// Every date is built from calendar fields (`DateTime(y, m, d + n)`) rather
/// than by adding a `Duration`, so a daylight-saving change never lands two
/// dates on the same day or skips one.
library;

import 'week_key.dart';

/// The Monday that starts [week], at local midnight.
///
/// ISO-8601: 4 January is always in week 1, so week 1's Monday is the Monday
/// on or before it, and every later week is seven days on.
DateTime mondayOf(WeekKey week) {
  final jan4 = DateTime(week.year, 1, 4);
  return DateTime(
    week.year,
    1,
    4 -
        (jan4.weekday - DateTime.monday) +
        (week.week - 1) * DateTime.daysPerWeek,
  );
}

/// The seven days of [week], Monday first.
List<DateTime> daysOf(WeekKey week) {
  final monday = mondayOf(week);
  return [
    for (var i = 0; i < DateTime.daysPerWeek; i++)
      DateTime(monday.year, monday.month, monday.day + i),
  ];
}

/// The weeks strictly after [after] and strictly before [before], oldest
/// first, keeping only the newest [max] of them.
///
/// Empty when there is no week between the two, including when [before] is
/// not later than [after].
List<WeekKey> weeksBetween(WeekKey after, WeekKey before, {int max = 8}) {
  final out = <WeekKey>[];
  if (max <= 0 || before.compareTo(after) <= 0) return out;
  var monday = mondayOf(after);
  while (true) {
    monday = DateTime(
      monday.year,
      monday.month,
      monday.day + DateTime.daysPerWeek,
    );
    final week = WeekKey.of(monday);
    if (week.compareTo(before) >= 0) break;
    out.add(week);
  }
  return out.length <= max ? out : out.sublist(out.length - max);
}
