// Implements TEST-CASES.csv P0-RWD-02 — "The daily points cap holds even when
// several sessions sync at once."
//
// The case's precondition is "more sessions logged in one day than the cap
// allows", so these tests drive the boundary rather than the happy path: the
// award that straddles the ceiling, the one after it, and the kinds that are
// deliberately outside it.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/award_table.dart';
import 'package:own_hub/domain/rewards/daily_cap.dart';
import 'package:own_hub/domain/training/session.dart';
import 'package:own_hub/domain/week/week_key.dart';

const String _today = '2026-09-18';
const String _tomorrow = '2026-09-19';

const AwardTable _table = AwardTable();

Award _session({String id = 's', SessionSource source = SessionSource.live}) =>
    _table.award(SessionLogged(sessionId: id, source: source));

Award get _best =>
    _table.award(const PersonalBestSet(exerciseId: 'e', sessionId: 's'));

void main() {
  const cap = DailyCap();

  group('under the ceiling, everything lands in full', () {
    test('a first session pays the whole award', () {
      final decision = cap.apply(
        state: const DailyCapState.fresh(_today),
        dayKey: _today,
        award: _session(),
      );

      expect(decision.granted, 30);
      expect(decision.inFull, isTrue);
      expect(decision.state.pointsToday, 30);
      expect(decision.reason, CapReason.none);
    });
  });

  group('P0-RWD-02 — points stop at the cap', () {
    test('the award that straddles the ceiling is trimmed to reach it', () {
      // 45 already earned today; a 30-point session would take her to 75.
      final decision = cap.apply(
        state: const DailyCapState(dayKey: _today, pointsToday: 45),
        dayKey: _today,
        award: _session(),
      );

      expect(decision.granted, 15, reason: 'the remaining headroom, not 30');
      expect(decision.state.pointsToday, kDailyPointsCap);
      expect(decision.reason, CapReason.dailyPoints);
      expect(decision.inFull, isFalse);
    });

    test('once the ceiling is reached, further awards pay nothing', () {
      final decision = cap.apply(
        state: const DailyCapState(
          dayKey: _today,
          pointsToday: kDailyPointsCap,
        ),
        dayKey: _today,
        award: _session(id: 'another'),
      );

      expect(decision.granted, 0);
      expect(decision.state.pointsToday, kDailyPointsCap);
      expect(decision.reason, CapReason.dailyPoints);
    });

    test('syncing several at once cannot bypass it', () {
      // Five sessions logged offline and drained on reconnect. Whatever order
      // they arrive in, the day totals the cap and no more.
      var state = const DailyCapState.fresh(_today);
      var paid = 0;
      for (var i = 0; i < 5; i++) {
        final decision = cap.apply(
          state: state,
          dayKey: _today,
          award: _session(id: 'offline-$i'),
        );
        paid += decision.granted;
        state = decision.state;
      }

      expect(paid, kDailyPointsCap, reason: '5 × 30 = 150, capped at 60');
      expect(state.pointsToday, kDailyPointsCap);
    });
  });

  group('personal bests carry their own, tighter ceiling', () {
    test('three a day land, the fourth does not', () {
      var state = const DailyCapState.fresh(_today);
      final granted = <int>[];

      for (var i = 0; i < 4; i++) {
        final decision = cap.apply(state: state, dayKey: _today, award: _best);
        granted.add(decision.granted);
        state = decision.state;
      }

      expect(granted, [10, 10, 10, 0]);
      expect(state.bestsToday, kBestAwardsPerDay);
    });

    test('the fourth is refused for being a fourth, not for the points', () {
      final decision = cap.apply(
        state: const DailyCapState(
          dayKey: _today,
          pointsToday: 30, // plenty of headroom left
          bestsToday: kBestAwardsPerDay,
        ),
        dayKey: _today,
        award: _best,
      );

      expect(decision.granted, 0);
      expect(decision.reason, CapReason.bestsPerDay);
      expect(
        decision.state.pointsToday,
        30,
        reason: 'a refused award consumes no budget',
      );
    });
  });

  group('what sits outside the cap', () {
    test('a counted week pays in full even at the ceiling', () {
      final week = _table.award(
        WeekCounted(week: WeekKey.tryParse('2026-W38')!),
      );
      final decision = cap.apply(
        state: const DailyCapState(
          dayKey: _today,
          pointsToday: kDailyPointsCap,
        ),
        dayKey: _today,
        award: week,
      );

      expect(decision.granted, 40);
      expect(decision.reason, CapReason.none);
    });

    test('an uncapped award does not eat the budget either', () {
      final milestone = _table.award(
        const MilestoneReached(milestoneId: 'first_counted_week'),
      );
      final decision = cap.apply(
        state: const DailyCapState(dayKey: _today, pointsToday: 10),
        dayKey: _today,
        award: milestone,
      );

      expect(decision.granted, 25);
      expect(
        decision.state.pointsToday,
        10,
        reason: 'a milestone must not use up headroom a session could have had',
      );
    });
  });

  group('a new day starts clean', () {
    test('yesterday\'s total does not follow her into today', () {
      final decision = cap.apply(
        state: const DailyCapState(
          dayKey: _today,
          pointsToday: kDailyPointsCap,
          bestsToday: kBestAwardsPerDay,
        ),
        dayKey: _tomorrow,
        award: _session(),
      );

      expect(decision.granted, 30);
      expect(decision.state.dayKey, _tomorrow);
      expect(decision.state.pointsToday, 30);
      expect(decision.state.bestsToday, 0);
    });

    test('the rollover is a comparison of day keys, never elapsed time', () {
      // Nothing here measures a duration, so nothing accumulates across days —
      // which is how a daily cap coexists with rule 3.
      final sameDay = cap.apply(
        state: const DailyCapState(dayKey: _today, pointsToday: 50),
        dayKey: _today,
        award: _session(),
      );
      expect(sameDay.granted, 10);

      final differentDay = cap.apply(
        state: const DailyCapState(dayKey: '2026-01-04', pointsToday: 50),
        dayKey: _today,
        award: _session(),
      );
      expect(differentDay.granted, 30);
    });
  });

  group('the ceiling is a parameter, not a number nobody can find', () {
    test('a different cap moves the answer', () {
      const tight = DailyCap(dailyPoints: 35, bestsPerDay: 1);
      final decision = tight.apply(
        state: const DailyCapState(dayKey: _today, pointsToday: 20),
        dayKey: _today,
        award: _session(),
      );
      expect(decision.granted, 15);
    });
  });
}
