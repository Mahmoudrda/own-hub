// Implements the day-id half of spine C1: a date-keyed document id is
// deterministic, sortable, and the same on both of her devices.
//
// The point of these is not that date formatting is hard. It is that four
// places in `lib/` had each written their own `padLeft(2, '0')`, and a fifth
// was about to, while the one field that mattered held `day-2`.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/format/day_key.dart';

void main() {
  group('dayKey produces a yyyy-MM-dd document id', () {
    test('pads every component', () {
      expect(dayKey(DateTime(2026, 9, 1)), '2026-09-01');
      expect(dayKey(DateTime(2026, 12, 25)), '2026-12-25');
    });

    test('is always exactly ten characters', () {
      // Fixed width is what makes the lexicographic sort below hold.
      for (final moment in [
        DateTime(2026, 1, 1),
        DateTime(2026, 9, 19, 23, 59, 59),
        DateTime(2027, 11, 30),
      ]) {
        expect(dayKey(moment).length, 10, reason: '$moment');
      }
    });

    test('satisfies the id shape the stores assert', () {
      // `ProgressStore._assertDayId` throws on anything else, so a formatter
      // that drifted from this pattern would take down measurement writes.
      final shape = RegExp(r'^\d{4}-\d{2}-\d{2}$');
      expect(shape.hasMatch(dayKey(DateTime(2026, 9, 19))), isTrue);
      expect(shape.hasMatch(dayKey(DateTime(2026, 1, 5, 6, 30))), isTrue);
    });

    test('Western digits only, whatever the ambient locale', () {
      // P0-A11Y-01. `intl`'s DateFormat would emit Eastern digits under `ar`,
      // which is why this is plain Dart.
      final eastern = RegExp(r'[٠-٩۰-۹]');
      expect(eastern.hasMatch(dayKey(DateTime(2026, 9, 19))), isFalse);
      // The control, so this cannot pass by matching nothing.
      expect(eastern.hasMatch('٢٠٢٦'), isTrue);
    });
  });

  group('the ids sort chronologically as plain strings', () {
    test('lexicographic order is date order', () {
      // `progress_repository.dart` sorts bests "newest first by dateKey" with
      // a bare String.compareTo. If this ever stopped holding, P03 would show
      // her history in an arbitrary order and nothing would throw.
      final ordered = [
        dayKey(DateTime(2025, 12, 31)),
        dayKey(DateTime(2026, 1, 1)),
        dayKey(DateTime(2026, 9, 2)),
        dayKey(DateTime(2026, 9, 19)),
        dayKey(DateTime(2026, 10, 1)),
      ];
      final shuffled = [...ordered]..shuffle();
      shuffled.sort();
      expect(shuffled, ordered);
    });

    test('a slug sorts ABOVE every real date, which is the bug this fixes', () {
      // R03's sample day carried `day-2`. Because 'd' > '2', a best minted in
      // the running app pinned itself to the top of P03 forever, above dated
      // ones. Pinning the comparison here so nobody reintroduces a slug.
      expect('day-2'.compareTo(dayKey(DateTime(2026, 9, 19))), greaterThan(0));
      expect('day-2'.compareTo('2099-12-31'), greaterThan(0));
    });
  });

  group('D17 — the day is the day it was for her', () {
    test('reads the local calendar fields, not UTC', () {
      // Machine-independent for the reason week_key_test gives: a test cannot
      // choose the runner's timezone. Two moments carrying the same calendar
      // date, one local and one UTC, must produce the same id — true today,
      // and false the instant anyone converts to UTC first.
      expect(
        dayKey(DateTime(2026, 9, 21, 1, 0)),
        dayKey(DateTime.utc(2026, 9, 21, 1, 0)),
        reason:
            'converting to UTC first moves a Gulf woman 01:00 Monday session '
            'back into Sunday, filing it under the wrong day',
      );
    });

    test('the time of day never reaches the id', () {
      final midnight = dayKey(DateTime(2026, 9, 19, 0, 0));
      final nearlyMidnight = dayKey(DateTime(2026, 9, 19, 23, 59, 59, 999));
      expect(midnight, nearlyMidnight);
    });
  });
}
