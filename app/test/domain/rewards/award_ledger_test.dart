// Implements TEST-CASES.csv P0-RWD-01 — "An award cannot be granted twice by an
// offline replay."
//
// The case's own words are the specification: "An increment is commutative but
// NOT idempotent, so the award must be bound to the creation of a deterministic
// awardId in the same transaction." Spine C4's correction says the same thing
// more briefly — an increment never travels alone.
//
// Cloud Functions are at-least-once, so a replayed trigger is normal rather than
// exceptional. These tests drive the replay directly.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/award_ledger.dart';
import 'package:own_hub/domain/rewards/award_table.dart';
import 'package:own_hub/domain/rewards/daily_cap.dart';
import 'package:own_hub/domain/training/session.dart';
import 'package:own_hub/domain/week/week_key.dart';

const String _today = '2026-09-18';
const AwardTable _table = AwardTable();

void main() {
  group('P0-RWD-01 — a replayed award pays once', () {
    test('the same session, delivered twice, adds its points once', () {
      final ledger = AwardLedger();
      final award = _table.award(
        const SessionLogged(sessionId: 'sess-7c1', source: SessionSource.live),
      );

      final first = ledger.record(award, dayKey: _today);
      expect(first.granted, 30);
      expect(ledger.points, 30);

      final replay = ledger.record(award, dayKey: _today);
      expect(replay.granted, 0);
      expect(replay.refusal, LedgerRefusal.duplicate);
      expect(
        ledger.points,
        30,
        reason: 'the increment never executed, because the id already existed',
      );
      expect(ledger.awardCount, 1);
    });

    test('a week cannot be paid for twice, ever', () {
      final ledger = AwardLedger();
      final week = _table.award(
        WeekCounted(week: WeekKey.tryParse('2026-W38')!),
      );

      ledger.record(week, dayKey: _today);
      ledger.record(week, dayKey: _today);
      ledger.record(week, dayKey: '2026-10-05'); // a much later replay

      expect(ledger.points, 40);
      expect(ledger.awardCount, 1);
    });

    test('a duplicate consumes none of her daily budget', () {
      // The id is checked before the cap, so a replay cannot eat headroom that
      // a genuine new award then could not use.
      final ledger = AwardLedger();
      final first = _table.award(
        const SessionLogged(sessionId: 'a', source: SessionSource.live),
      );

      ledger.record(first, dayKey: _today);
      ledger.record(first, dayKey: _today);
      ledger.record(first, dayKey: _today);

      expect(ledger.capState.pointsToday, 30, reason: 'not 90');

      // A different session still gets its full award.
      final second = ledger.record(
        _table.award(
          const SessionLogged(sessionId: 'b', source: SessionSource.live),
        ),
        dayKey: _today,
      );
      expect(second.granted, 30);
      expect(ledger.points, 60);
    });

    test('an offline drain of a mixed queue settles deterministically', () {
      // Four events, two of them replays, arriving in one reconnect.
      final ledger = AwardLedger();
      final sessionA = _table.award(
        const SessionLogged(sessionId: 'a', source: SessionSource.unplanned),
      );
      final meal = _table.award(const FoodDayLogged(dayId: _today));

      for (final award in [sessionA, meal, sessionA, meal]) {
        ledger.record(award, dayKey: _today);
      }

      expect(ledger.points, 15 + 5);
      expect(ledger.awardCount, 2);
    });
  });

  group('the ledger records that an award happened, not only that it paid', () {
    test('an award capped to zero still cannot be retried tomorrow', () {
      final ledger = AwardLedger(
        today: const DailyCapState(
          dayKey: _today,
          pointsToday: kDailyPointsCap,
        ),
      );
      final award = _table.award(
        const SessionLogged(sessionId: 'late', source: SessionSource.live),
      );

      final capped = ledger.record(award, dayKey: _today);
      expect(capped.granted, 0);
      expect(capped.refusal, LedgerRefusal.capped);
      expect(ledger.contains(award.awardId), isTrue);

      // Tomorrow, with a clean budget — but the same id.
      final retry = ledger.record(award, dayKey: '2026-09-19');
      expect(
        retry.granted,
        0,
        reason:
            'otherwise a capped award becomes a full one by waiting a day, '
            'and the cap is a delay rather than a ceiling',
      );
      expect(ledger.points, 0);
    });
  });

  group('nothing earned is ever taken away', () {
    test('points never fall across a long mixed sequence', () {
      final ledger = AwardLedger();
      var highWater = 0;

      for (var day = 18; day <= 22; day++) {
        final dayKey = '2026-09-$day';
        for (var i = 0; i < 6; i++) {
          ledger.record(
            _table.award(
              SessionLogged(sessionId: 'd$day-s$i', source: SessionSource.live),
            ),
            dayKey: dayKey,
          );
          expect(ledger.points, greaterThanOrEqualTo(highWater));
          highWater = ledger.points;
        }
      }

      expect(ledger.points, greaterThan(0));
    });

    test('a ledger resumed from storage keeps what it already held', () {
      final ledger = AwardLedger(
        points: 415,
        existingAwardIds: const ['session:old-1', 'week:2026-W37'],
      );

      expect(ledger.points, 415);
      expect(ledger.contains('week:2026-W37'), isTrue);

      // And an old id replayed against the resumed ledger still pays nothing.
      final replay = ledger.record(
        _table.award(WeekCounted(week: WeekKey.tryParse('2026-W37')!)),
        dayKey: _today,
      );
      expect(replay.refusal, LedgerRefusal.duplicate);
      expect(ledger.points, 415);
    });
  });
}
