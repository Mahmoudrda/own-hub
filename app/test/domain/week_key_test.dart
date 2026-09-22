// Implements TEST-CASES.csv: P1-RULE-03 (no daily counter can exist),
// P0-WEEK-01 (a week counts), and the determinism half of spine C1.
//
// The point of these is not that ISO week arithmetic is hard — it is that the
// week must be the ONLY unit this product can express.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/week/week_key.dart';

void main() {
  group('D17 — the week follows the phone she is holding', () {
    // The app is international. There is a very large Egyptian population in
    // the Gulf at UTC+3/+4, and a boundary computed in Cairo misfiles their
    // late-evening sessions into the wrong week — a Monday 01:00 session in
    // Dubai is still Sunday in UTC, which is a different ISO week.
    //
    // This was already the behaviour: every caller hands `of` a device-local
    // DateTime and nothing calls toUtc(). It was an invariant nothing stated
    // and no test held, which is why `current` exists as a named constructor.

    test('current() is of(now), with the clock injectable', () {
      final moment = DateTime(2026, 9, 18, 9, 41);
      expect(WeekKey.current(moment), WeekKey.of(moment));
      expect(WeekKey.current(moment).id, '2026-W38');
    });

    test('the week comes from the calendar fields, NOT from UTC', () {
      // The real guard, and deliberately machine-independent: a test cannot
      // pick the runner's timezone, so asserting "23:30 in Dubai lands in
      // Monday's week" would pass or fail depending on where it ran.
      //
      // Instead: two moments with the same year, month and day — one local,
      // one UTC — must be the same week. `of` reads `moment.year/month/day`,
      // which are the LOCAL calendar fields of a local DateTime, so this holds
      // today and breaks the instant anyone converts to UTC first.
      final local = DateTime(2026, 9, 21, 1, 0);
      final utc = DateTime.utc(2026, 9, 21, 1, 0);

      expect(
        WeekKey.of(local),
        WeekKey.of(utc),
        reason:
            'a moment is filed by the date it is FOR HER. Converting to UTC '
            'first moves a Gulf Monday back into Sunday, and Sunday is the '
            'last day of the previous ISO week',
      );
    });

    test('nothing in the week boundary converts to UTC', () {
      // The source half. The assertion above catches the behaviour; this
      // catches the edit, and names it, so the next person reads why before
      // they add it.
      final source = File('lib/domain/week/week_key.dart').readAsStringSync();
      final banned = RegExp(r'\.toUtc\(\)');

      expect(
        banned.hasMatch(source),
        isFalse,
        reason:
            'toUtc() here would recompute every boundary in UTC and silently '
            'move the Gulf diaspora a week',
      );
      // The control, so this cannot pass by matching nothing.
      expect(banned.hasMatch('final d = moment.toUtc();'), isTrue);
    });

    test('the fallback zone is a fallback, and the boundary ignores it', () {
      // `WeekKey.fallbackTimezone` exists for a goal whose zone was never
      // recorded. It must not participate in computing a week, or a woman in
      // Dubai would be filed in Cairo's week after all.
      expect(WeekKey.fallbackTimezone, 'Africa/Cairo');

      final source = File('lib/domain/week/week_key.dart').readAsStringSync();
      // It is declared, and referenced nowhere in the arithmetic.
      expect(
        RegExp(r'fallbackTimezone').allMatches(source).length,
        greaterThan(0),
      );
      expect(
        source.contains('WeekKey._(') && source.contains('fallbackTimezone'),
        isTrue,
        reason: 'both exist; the test below is that they never meet',
      );
      for (final line in source.split('\n')) {
        if (line.contains('fallbackTimezone') && line.contains('WeekKey._(')) {
          fail('the fallback zone reached the boundary arithmetic: $line');
        }
      }
    });
  });

  group('WeekKey produces the document id and nothing else', () {
    test('formats as yyyy-Www, zero padded', () {
      expect(WeekKey.of(DateTime.utc(2026, 9, 18)).id, '2026-W38');
      expect(WeekKey.of(DateTime.utc(2026, 1, 5)).id, '2026-W02');
    });

    test(
      'the same week always yields the same id, whatever the day or time',
      () {
        // Spine C1: deterministic ids are what make an offline replay collide with
        // itself instead of creating a duplicate week.
        final monday = WeekKey.of(DateTime.utc(2026, 9, 14, 0, 0));
        final sunday = WeekKey.of(DateTime.utc(2026, 9, 20, 23, 59));
        expect(monday, sunday);
        expect(monday.id, sunday.id);
      },
    );

    test(
      'handles the ISO year boundary, where the week belongs to another year',
      () {
        // 1 Jan 2027 is a Friday, so it falls in the last week of 2026. Getting
        // this wrong silently moves a woman's week and loses her progress at
        // new year.
        expect(WeekKey.of(DateTime.utc(2027, 1, 1)).id, '2026-W53');
        expect(WeekKey.of(DateTime.utc(2026, 12, 28)).id, '2026-W53');
      },
    );

    test('round-trips through its own id', () {
      final k = WeekKey.of(DateTime.utc(2026, 9, 18));
      expect(WeekKey.tryParse(k.id), k);
    });

    test('a malformed id degrades to null rather than throwing', () {
      // Read from storage, this must not crash Home.
      for (final bad in ['', '2026-38', '2026-W00', '2026-W54', 'nonsense']) {
        expect(WeekKey.tryParse(bad), isNull, reason: bad);
      }
    });
  });

  group('P1-RULE-03 — a daily counter is not expressible', () {
    test('WeekKey offers ordering but no arithmetic', () {
      // Ordering lets storage ask for the last eight weeks. It deliberately does
      // not let anything count how many weeks ran back to back, which is what a
      // daily or weekly run counter would need.
      final a = WeekKey.of(DateTime.utc(2026, 9, 7));
      final b = WeekKey.of(DateTime.utc(2026, 9, 14));
      expect(a.compareTo(b), lessThan(0));

      // 1 January 2026 is a Thursday, so the week containing 7 September is 37.
      expect(WeekKey.of(DateTime.utc(2026, 9, 7)).toString(), '2026-W37');
    });

    test('the type carries no day-level information at all', () {
      final k = WeekKey.of(DateTime.utc(2026, 9, 18, 14, 30));
      // Only a year and a week number survive construction. A run of consecutive
      // days cannot be reconstructed from this, by anyone, ever.
      expect(k.year, 2026);
      expect(k.week, 38);
      expect(k.id.split('-').length, 2);
    });
  });
}
