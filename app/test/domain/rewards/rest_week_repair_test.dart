// Implements TEST-CASES.csv P0-WEEK-02 ("A missed week is repaired by a banked
// rest week"), P0-WEEK-04 ("A week repaired by a rest week pays no points") and
// G6's half of P0-FR-02.
//
// The figures deliberately avoid the prototype's. The mockup's woman has 14
// counted weeks, a best run of 9 and a goal of 3; these tests use 9 counted
// weeks, a best run of 5 and a goal of 2, so an implementation that recites the
// mockup fails every assertion below.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/rest_week_repair.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';

WeekKey _w(String id) => WeekKey.tryParse(id)!;

final DateTime _monday = DateTime(2026, 9, 21, 6);

WeekDoc _week(String id, {int target = 2, int logged = 0}) => WeekDoc(
  week: _w(id),
  sessionsTarget: target,
  creditedSessionIds: [for (var i = 0; i < logged; i++) '$id-s$i'],
);

/// A woman well into her training: nine counted weeks, one rest week banked.
const WeeklyGoal _established = WeeklyGoal(
  sessionsTarget: 2,
  countedWeeks: 9,
  restWeeksBanked: 1,
  restWeekProgress: 1,
  currentRun: 5,
  bestRun: 5,
);

void main() {
  const repair = RestWeekRepair();

  group('P0-WEEK-02 — a banked rest week repairs a missed week', () {
    test('the week counts, the total does not fall, and no bank is left', () {
      final decision = repair.decide(
        week: _week('2026-W38', logged: 1), // one of two — unmet
        goal: _established,
        closedAt: _monday,
      );

      expect(decision.outcome, RepairOutcome.repaired);
      expect(decision.week.counted, isTrue);
      expect(decision.week.repairedByRestWeek, isTrue);
      expect(decision.week.closedAt, _monday);

      expect(
        decision.goal.countedWeeks,
        10,
        reason: 'D5: a rest week must never reduce a reward',
      );
      expect(decision.goal.restWeeksBanked, 0, reason: 'the bank was spent');
      expect(
        decision.goal.currentRun,
        5,
        reason: 'the run surviving IS the repair',
      );
      expect(decision.goal.lastRepairedWeek, _w('2026-W38'));
    });

    test('it happens without being asked', () {
      // Repair is automatic and unasked — G6 §3.1. The evidence is structural:
      // one call, no prompt, no second call to accept, and no parameter on
      // decide() through which a confirmation could be supplied. A test cannot
      // assert the absence of an argument, so it asserts the consequence: the
      // repair is already done when decide() returns.
      final decision = repair.decide(
        week: _week('2026-W38'),
        goal: _established,
        closedAt: _monday,
      );
      expect(decision.week.repairedByRestWeek, isTrue);
      expect(decision.counts, isTrue);
    });

    test('nothing on the closed week counts what was missed', () {
      final decision = repair.decide(
        week: _week('2026-W38', logged: 1),
        goal: _established,
        closedAt: _monday,
      );
      // The bar shows one of two logged — a total that moves, not a deficit.
      final bar = decision.week.toBar();
      expect(bar.sessionsLogged, 1);
      expect(bar.sessionsTarget, 2);
      expect(bar.kind, WeekBarKind.repaired);
    });
  });

  group('P0-WEEK-04 — a repaired week pays nothing and buys nothing', () {
    test('no points are awarded at the close', () {
      final decision = repair.decide(
        week: _week('2026-W38'),
        goal: _established,
        closedAt: _monday,
      );
      expect(
        decision.pointsAwarded,
        0,
        reason: 'no goal-moving behaviour occurred',
      );
    });

    test('it earns no progress toward the next rest week', () {
      final decision = repair.decide(
        week: _week('2026-W38'),
        goal: _established,
        closedAt: _monday,
      );
      expect(
        decision.goal.restWeekProgress,
        _established.restWeekProgress,
        reason: 'repair must not be able to fund itself',
      );
    });

    test(
      'an earned week does advance the bank, and a repaired one does not',
      () {
        // Three earned counted weeks in, the fourth banks a rest week.
        const almost = WeeklyGoal(
          countedWeeks: 9,
          restWeeksBanked: 0,
          restWeekProgress: 3,
          currentRun: 3,
          bestRun: 5,
        );

        final earned = repair.decide(
          week: _week('2026-W38', logged: 2), // met
          goal: almost,
          closedAt: _monday,
        );
        expect(earned.outcome, RepairOutcome.counted);
        expect(earned.goal.restWeeksBanked, 1);
        expect(earned.goal.restWeekProgress, 0, reason: 'reset after banking');

        // The same starting point, but the week was repaired instead.
        final repaired = repair.decide(
          week: _week('2026-W38'),
          goal: almost.copyWith(restWeeksBanked: 1),
          closedAt: _monday,
        );
        expect(repaired.outcome, RepairOutcome.repaired);
        expect(repaired.goal.restWeekProgress, 3, reason: 'still three');
      },
    );

    test('the bank is capped', () {
      const full = WeeklyGoal(
        countedWeeks: 20,
        restWeeksBanked: kRestWeekBankCap,
        restWeekProgress: 3,
        currentRun: 8,
        bestRun: 8,
      );
      final decision = repair.decide(
        week: _week('2026-W38', logged: 2),
        goal: full,
        closedAt: _monday,
      );
      expect(decision.goal.restWeeksBanked, kRestWeekBankCap);
    });
  });

  group('a week that simply did not count', () {
    test('the run resets and nothing else is taken away', () {
      const noBank = WeeklyGoal(
        countedWeeks: 9,
        restWeeksBanked: 0,
        currentRun: 5,
        bestRun: 5,
      );

      final decision = repair.decide(
        week: _week('2026-W38', logged: 1),
        goal: noBank,
        closedAt: _monday,
      );

      expect(decision.outcome, RepairOutcome.missed);
      expect(decision.week.counted, isFalse);
      expect(decision.goal.currentRun, 0);
      expect(
        decision.goal.countedWeeks,
        9,
        reason: 'nothing earned is ever taken away',
      );
      expect(decision.goal.bestRun, 5, reason: 'her best run is hers');
      expect(decision.pointsAwarded, 0);
    });
  });

  group('P0-FR-02 — a rest week is never spent on an unmet first week', () {
    test('a bank she cannot have earned is not spent', () {
      // countedWeeks is zero, so no rest week could have been earned. Even
      // handed one, the repair refuses: the guard is explicit because decide()
      // takes the bank as a parameter.
      const brandNew = WeeklyGoal(countedWeeks: 0, restWeeksBanked: 1);

      final decision = repair.decide(
        week: _week('2026-W38'),
        goal: brandNew,
        closedAt: _monday,
      );

      expect(decision.outcome, RepairOutcome.missed);
      expect(decision.goal.restWeeksBanked, 1, reason: 'still banked');
      expect(decision.goal.countedWeeks, 0);
    });

    test('idle time changes no number, because no number counts days', () {
      // "Three idle days change no G6 number; nothing expires." There is no
      // parameter on decide() carrying elapsed time, so this is true by
      // construction — closing the same week at two different moments differs
      // only in the timestamp written.
      final early = repair.decide(
        week: _week('2026-W38', logged: 1),
        goal: _established,
        closedAt: DateTime(2026, 9, 21, 6),
      );
      final late = repair.decide(
        week: _week('2026-W38', logged: 1),
        goal: _established,
        closedAt: DateTime(2026, 9, 24, 23),
      );

      expect(early.outcome, late.outcome);
      expect(early.goal.countedWeeks, late.goal.countedWeeks);
      expect(early.goal.restWeeksBanked, late.goal.restWeeksBanked);
      expect(early.goal.currentRun, late.goal.currentRun);
    });
  });

  group('closedAt is write-once', () {
    test('re-closing a closed week changes nothing', () {
      final alreadyClosed = _week(
        '2026-W38',
        logged: 2,
      ).copyWith(counted: true, closedAt: DateTime(2026, 9, 21));

      final decision = repair.decide(
        week: alreadyClosed,
        goal: _established,
        closedAt: DateTime(2026, 10, 12),
      );

      expect(decision.week.closedAt, DateTime(2026, 9, 21));
      expect(
        decision.goal.countedWeeks,
        _established.countedWeeks,
        reason: 'an at-least-once retry must not count the week again',
      );
    });
  });

  group('closing several weeks at once', () {
    test('a limited bank protects the most recent weeks', () {
      // Four weeks away, two rest weeks banked. The two nearest to now are the
      // ones repaired, because both the run and the tier floor weight recency.
      const twoBanked = WeeklyGoal(
        countedWeeks: 9,
        restWeeksBanked: 2,
        currentRun: 5,
        bestRun: 5,
      );

      final run = repair.closeStaleWeeks(
        unclosed: [
          _week('2026-W35'),
          _week('2026-W36'),
          _week('2026-W37'),
          _week('2026-W38'),
        ],
        goal: twoBanked,
        closedAt: _monday,
      );

      final byWeek = {for (final d in run.decisions) d.week.week.id: d.outcome};

      expect(byWeek['2026-W35'], RepairOutcome.missed);
      expect(byWeek['2026-W36'], RepairOutcome.missed);
      expect(byWeek['2026-W37'], RepairOutcome.repaired);
      expect(byWeek['2026-W38'], RepairOutcome.repaired);

      expect(run.repairedCount, 2);
      expect(run.goal.restWeeksBanked, 0);
      expect(run.goal.countedWeeks, 11, reason: '9 + the two repaired');
      expect(run.pointsAwarded, 0);
    });

    test('the weeks are applied oldest first, so the chart reads forward', () {
      final run = repair.closeStaleWeeks(
        unclosed: [
          _week('2026-W38', logged: 2),
          _week('2026-W36', logged: 2),
          _week('2026-W37', logged: 2),
        ],
        goal: _established,
        closedAt: _monday,
      );

      expect(run.decisions.map((d) => d.week.week.id).toList(), [
        '2026-W36',
        '2026-W37',
        '2026-W38',
      ]);
      expect(run.goal.recent8.map((b) => b.week.id).toList(), [
        '2026-W36',
        '2026-W37',
        '2026-W38',
      ]);
      expect(run.goal.currentRun, 8, reason: '5 + three earned weeks');
      expect(run.goal.bestRun, 8);
    });

    test('a long absence is skipped rather than fanned out', () {
      // Twelve unclosed weeks. Only the most recent eight are reconciled; the
      // older four are skipped entirely — no document, not counted, not
      // repaired — so a two-year absence cannot write a hundred documents.
      final weeks = [for (var i = 27; i <= 38; i++) _week('2026-W$i')];

      final run = repair.closeStaleWeeks(
        unclosed: weeks,
        goal: const WeeklyGoal(countedWeeks: 9, restWeeksBanked: 0),
        closedAt: _monday,
      );

      expect(run.decisions.length, kRecentWeekWindow);
      expect(run.skippedWeeks.length, 4);
      expect(run.skippedWeeks.map((w) => w.id).toList(), [
        '2026-W27',
        '2026-W28',
        '2026-W29',
        '2026-W30',
      ]);
      expect(run.goal.recent8.length, kRecentWeekWindow);
    });
  });
}
