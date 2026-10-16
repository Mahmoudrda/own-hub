import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/week/week_calendar.dart';
import 'package:own_hub/domain/week/week_key.dart';

void main() {
  test('mondayOf is the Monday of the ISO week', () {
    expect(
      mondayOf(WeekKey.of(DateTime(2026, 10, 15))),
      DateTime(2026, 10, 12),
    );
    // 1 January 2027 is in week 53 of 2026, whose Monday is 28 December.
    final w53 = WeekKey.of(DateTime(2027, 1, 1));
    expect(w53.id, '2026-W53');
    expect(mondayOf(w53), DateTime(2026, 12, 28));
    expect(mondayOf(WeekKey.of(DateTime(2027, 1, 4))), DateTime(2027, 1, 4));
  });

  test('daysOf lists Monday to Sunday', () {
    final days = daysOf(WeekKey.of(DateTime(2026, 10, 13)));
    expect(days.first, DateTime(2026, 10, 12));
    expect(days.last, DateTime(2026, 10, 18));
    expect(days, hasLength(7));
  });

  test('weeksBetween is exclusive at both ends and keeps the newest', () {
    final from = WeekKey.of(DateTime(2026, 12, 1)); // 2026-W49
    final to = WeekKey.of(DateTime(2027, 1, 12)); // 2027-W02
    final between = weeksBetween(from, to);
    expect(between.map((w) => w.id), [
      '2026-W50',
      '2026-W51',
      '2026-W52',
      '2026-W53',
      '2027-W01',
    ]);
    expect(weeksBetween(from, to, max: 2).map((w) => w.id), [
      '2026-W53',
      '2027-W01',
    ]);
    expect(weeksBetween(to, from), isEmpty);
    expect(weeksBetween(from, from), isEmpty);
  });
}
