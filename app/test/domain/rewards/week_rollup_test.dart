// Implements TEST-CASES.csv P0-WEEK-01 ("A week counts") and the half of
// P0-RWD-01 / P0-LOG-09 that lives in the week document.
//
// Every figure here differs from the prototype's. The mockup's woman has a goal
// of 3 with 2 logged; these tests use a goal of 4 and a goal of 2, because a
// test written against the mockup's own numbers passes for a hardcoded constant
// exactly as happily as for a computation. That mistake has shipped five times
// in this repo — PHASE1-FIXES.md §8 and §13 — and it is the reason the numbers
// below look arbitrary.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/week/week_key.dart';

final WeekKey _week = WeekKey.tryParse('2026-W38')!;

WeekDoc _open({int target = 4, List<String> credited = const <String>[]}) =>
    WeekDoc(week: _week, sessionsTarget: target, creditedSessionIds: credited);

void main() {
  const rollup = WeekRollup();

  group('P0-WEEK-01 — the session that crosses the goal counts the week', () {
    test('a goal of four is not met at three', () {
      final week = _open(credited: const ['s1', 's2', 's3']);
      expect(week.sessionsLogged, 3);
      expect(rollup.evaluate(week), WeekState.open);
      expect(week.counted, isFalse);
    });

    test('the fourth session flips it to counted, once', () {
      final third = _open(credited: const ['s1', 's2', 's3']);

      final crossing = rollup.creditSession(week: third, sessionId: 's4');
      expect(crossing.week.counted, isTrue);
      expect(rollup.evaluate(crossing.week), WeekState.met);
      expect(
        crossing.countedNow,
        isTrue,
        reason: 'this is the one moment the 40-point week award may fire',
      );

      // A fifth session is welcome and earns the week nothing further.
      final extra = rollup.creditSession(week: crossing.week, sessionId: 's5');
      expect(extra.week.sessionsLogged, 5);
      expect(extra.week.counted, isTrue);
      expect(
        extra.countedNow,
        isFalse,
        reason: 'Points award once — a fifth session cannot pay for the week',
      );
    });

    test('a two-session goal counts on the second, not the third', () {
      // A different target entirely, so a rollup hardcoded to 3 fails here.
      final week = _open(target: 2, credited: const ['a']);
      final second = rollup.creditSession(week: week, sessionId: 'b');
      expect(second.countedNow, isTrue);
      expect(second.week.sessionsLogged, 2);
    });
  });

  group('an offline replay credits nothing twice', () {
    test('the same session id re-unions and changes nothing', () {
      final week = _open(target: 2, credited: const ['walk-2026-09-18']);

      final replay = rollup.creditSession(
        week: week,
        sessionId: 'walk-2026-09-18',
      );

      expect(replay.alreadyCredited, isTrue);
      expect(replay.countedNow, isFalse);
      expect(replay.week.sessionsLogged, 1, reason: 'not two');
    });

    test('a replay of the crossing session cannot pay for the week twice', () {
      final week = _open(target: 2, credited: const ['a']);
      final crossing = rollup.creditSession(week: week, sessionId: 'b');
      expect(crossing.countedNow, isTrue);

      final replay = rollup.creditSession(week: crossing.week, sessionId: 'b');
      expect(replay.countedNow, isFalse);
      expect(replay.alreadyCredited, isTrue);
      expect(replay.week.sessionsLogged, 2);
    });
  });

  group('sessionsLogged cannot disagree with the id set', () {
    test('it is the size of the set, not a counter beside it', () {
      // PHASE1-FIXES.md §8: "two sources, one of them constant". There is no
      // way to construct a week whose count differs from its evidence.
      final week = _open(credited: const ['a', 'b', 'c', 'd', 'e']);
      expect(week.sessionsLogged, week.creditedSessionIds.length);
      expect(week.sessionsLogged, 5);
    });

    test('the credited set is bounded, and overflow is silent', () {
      final full = _open(
        target: 2,
        credited: [for (var i = 0; i < kCreditedSessionCap; i++) 's$i'],
      );
      final overflow = rollup.creditSession(week: full, sessionId: 'one-more');
      expect(overflow.week.sessionsLogged, kCreditedSessionCap);
      expect(
        overflow.week.counted,
        isFalse,
        reason: 'the week was never closed here, so nothing else changed',
      );
    });
  });

  group('counted is irreversible and closedAt is write-once', () {
    test('copyWith cannot walk counted back to false', () {
      final counted = _open(
        target: 1,
        credited: const ['a'],
      ).copyWith(counted: true);
      expect(counted.copyWith(counted: false).counted, isTrue);
    });

    test('a second close does not move the timestamp', () {
      final first = DateTime(2026, 9, 21, 9);
      final second = DateTime(2026, 10, 5, 9);
      final closed = _open().copyWith(closedAt: first);
      expect(closed.copyWith(closedAt: second).closedAt, first);
    });

    test('a late-syncing session cannot reopen or re-credit a closed week', () {
      final closed = _open(
        target: 2,
        credited: const ['a'],
      ).copyWith(closedAt: DateTime(2026, 9, 21));

      final late = rollup.creditSession(week: closed, sessionId: 'b');
      expect(late.week.sessionsLogged, 1, reason: 'refused outright');
      expect(late.countedNow, isFalse);
      expect(late.week.counted, isFalse);
    });
  });

  group('the goal may fall while the week is open, and never rise', () {
    test('lowering it can itself count the week', () {
      // Two logged against a goal of four; she shrinks the week to two.
      final week = _open(credited: const ['a', 'b']);
      final smaller = rollup.retarget(week, 2);

      expect(smaller.sessionsTarget, 2);
      expect(
        smaller.counted,
        isTrue,
        reason: 'she is measured against the goal she holds now',
      );
    });

    test('raising it is refused, because it could un-count a counted week', () {
      final counted = _open(
        target: 2,
        credited: const ['a', 'b'],
      ).copyWith(counted: true);

      final raised = rollup.retarget(counted, 4);
      expect(raised.sessionsTarget, 2);
      expect(raised.counted, isTrue);
    });

    test('a closed week is frozen', () {
      final closed = _open().copyWith(closedAt: DateTime(2026, 9, 21));
      expect(rollup.retarget(closed, 2).sessionsTarget, 4);
    });
  });

  group('a food-day goal counts in its own unit', () {
    WeekDoc foodWeek() => WeekDoc(
      week: _week,
      sessionsTarget: 4,
      goalKind: WeekGoalKind.foodDays,
    );

    test('four logged food days meet a four-day goal', () {
      final fed = rollup.creditFoodDay(week: foodWeek(), foodDaysLogged: 4);
      expect(fed.progress, 4);
      expect(fed.counted, isTrue);
    });

    test('sessions do not satisfy a food-day goal', () {
      // The unit is a property of the week, not an assumption of the rollup.
      final logged = rollup.creditSession(week: foodWeek(), sessionId: 'a');
      expect(logged.week.sessionsLogged, 1);
      expect(logged.week.progress, 0, reason: 'progress is counted in days');
      expect(logged.countedNow, isFalse);
    });

    test('the day count is absolute, so a replay changes nothing', () {
      final once = rollup.creditFoodDay(week: foodWeek(), foodDaysLogged: 3);
      final twice = rollup.creditFoodDay(week: once, foodDaysLogged: 3);
      expect(twice.foodDaysLogged, 3, reason: 'an absolute write, not +=');
    });
  });

  group('rule 3 — nothing here can express a day', () {
    test('a week bar knows what kind it is and never how many days ran', () {
      final counted = WeekBar(
        week: _week,
        sessionsLogged: 4,
        sessionsTarget: 4,
        counted: true,
      );
      final repaired = WeekBar(
        week: _week,
        sessionsLogged: 1,
        sessionsTarget: 4,
        counted: true,
        repairedByRestWeek: true,
      );
      final missed = WeekBar(
        week: _week,
        sessionsLogged: 0,
        sessionsTarget: 4,
        counted: false,
      );

      expect(counted.kind, WeekBarKind.counted);
      expect(repaired.kind, WeekBarKind.repaired);
      expect(missed.kind, WeekBarKind.missed);
      expect(
        WeekBarKind.values.length,
        3,
        reason:
            'a fourth kind would be somewhere for a failure styling to live',
      );
    });

    test('five states, and none of them counts days', () {
      expect(WeekState.values.length, 5);
    });
  });
}
