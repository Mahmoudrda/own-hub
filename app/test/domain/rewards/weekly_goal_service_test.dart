// `WeeklyGoalService` — the goal she chooses, and the rest the product pays for.
//
// Covers `DECISIONS.md` D16 ("Planned rest is capped at two per week"), the D5a
// ruling it settles, and `weekly_goal.dart`'s statement that `sessionsTarget` is
// "the only counter on this object she may write".
//
// The figures deliberately avoid both the prototype's (target 3, 14 counted
// weeks, best run 9) and `rest_week_repair_test.dart`'s (target 2, 9 counted
// weeks, best run 5). This file's woman trains four times a week, has 23 counted
// weeks and a best run of 11, so an implementation reciting either fixture fails
// here.
//
// The dates are a real ISO week: Monday 2 November 2026 opens `2026-W45`, and
// Monday 9 November opens `2026-W46`. The first group asserts that outright, so
// a mistake in the fixture surfaces as its own failure rather than as a confusing
// one in the cap.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/rewards/weekly_goal_service.dart';
import 'package:own_hub/domain/week/week_key.dart';

WeekKey _w(String id) => WeekKey.tryParse(id)!;

// One ISO week, Monday to Sunday.
final DateTime _mon = DateTime(2026, 11, 2, 7, 30);
final DateTime _wed = DateTime(2026, 11, 4, 19);
final DateTime _fri = DateTime(2026, 11, 6, 8);
final DateTime _sun = DateTime(2026, 11, 8, 22, 15);

// The week after, and the week before.
final DateTime _nextMon = DateTime(2026, 11, 9, 6);
final DateTime _prevFri = DateTime(2026, 10, 30, 12);

/// A woman well into her training, on a four-session goal.
///
/// Not `const`: [WeekKey] has no public const constructor, which is deliberate
/// — every week id is parsed or derived, never hand-built.
final WeeklyGoal _established = WeeklyGoal(
  sessionsTarget: 4,
  countedWeeks: 23,
  restWeeksBanked: 2,
  restWeekProgress: 3,
  currentRun: 7,
  bestRun: 11,
  recent8: <WeekBar>[
    WeekBar(
      week: _w('2026-W44'),
      sessionsLogged: 4,
      sessionsTarget: 4,
      counted: true,
    ),
  ],
  tz: 'Asia/Dubai',
);

bool _isComment(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('///') || t.startsWith('*');
}

/// Non-comment lines of the implementation, for the structural guards.
List<String> _serviceCode() {
  final file = File('lib/domain/rewards/weekly_goal_service.dart');
  expect(file.existsSync(), isTrue, reason: 'the service must exist');
  return file.readAsLinesSync().where((l) => !_isComment(l)).toList();
}

void main() {
  const service = WeeklyGoalService();

  group('the fixture is a real ISO week', () {
    test('Monday 2 November 2026 opens 2026-W45', () {
      expect(WeekKey.of(_mon).id, '2026-W45');
    });

    test('Monday to Sunday is one week; the next Monday is the next', () {
      expect(WeekKey.of(_wed), WeekKey.of(_mon));
      expect(WeekKey.of(_fri), WeekKey.of(_mon));
      expect(WeekKey.of(_sun), WeekKey.of(_mon), reason: 'Sunday still W45');
      expect(WeekKey.of(_nextMon), _w('2026-W46'));
      expect(WeekKey.of(_prevFri), _w('2026-W44'));
    });
  });

  group('D16 — planned rest is capped at two per week', () {
    test('the cap is two', () {
      // The number itself is the decision. D5a required a cap and recorded
      // none; the owner settled it on 19 September 2026.
      expect(kPlannedRestPerWeek, 2, reason: 'DECISIONS.md D16');
      // Negative controls: the two numbers it is NOT. D5a's own proposal was
      // one, and a three would make "two per week" false while every
      // single-mark test still passed.
      expect(kPlannedRestPerWeek, isNot(1));
      expect(kPlannedRestPerWeek, isNot(3));
    });

    test('the first rest day of a week is granted', () {
      final decision = service.markPlannedRest(
        _mon,
        planned: PlannedRest.fresh(WeekKey.of(_mon)),
      );

      expect(decision.outcome, PlannedRestOutcome.planned);
      expect(decision.isPlannedRest, isTrue);
      expect(decision.planned.dayKeys, {'2026-11-02'});
      expect(decision.planned.used, 1);
      expect(decision.remaining, 1);
      expect(decision.planned.isFull, isFalse);
    });

    test('the second is granted, and the week is then full', () {
      final first = service.markPlannedRest(
        _mon,
        planned: PlannedRest.fresh(WeekKey.of(_mon)),
      );
      final second = service.markPlannedRest(_wed, planned: first.planned);

      expect(second.outcome, PlannedRestOutcome.planned);
      expect(second.planned.dayKeys, {'2026-11-02', '2026-11-04'});
      expect(second.planned.used, 2);
      expect(second.remaining, 0);
      expect(second.planned.isFull, isTrue);
    });

    test('the THIRD day of the same week is refused', () {
      // D5a: the cap exists "so it cannot be used to excuse every day". This is
      // the assertion that sentence rests on.
      final full = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02', '2026-11-04'},
      );

      final third = service.markPlannedRest(_fri, planned: full);

      expect(third.outcome, PlannedRestOutcome.capReached);
      expect(third.isPlannedRest, isFalse);
      expect(third.planned.dayKeys, {
        '2026-11-02',
        '2026-11-04',
      }, reason: 'a refused day must not be recorded');
      expect(
        third.planned.dayKeys.contains('2026-11-06'),
        isFalse,
        reason: 'the refused day is absent, not merely uncounted',
      );
      expect(third.planned.used, 2);
      expect(third.remaining, 0);
    });

    test('a fourth attempt changes nothing either', () {
      final full = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02', '2026-11-04'},
      );

      final third = service.markPlannedRest(_fri, planned: full);
      final fourth = service.markPlannedRest(_sun, planned: third.planned);

      expect(fourth.outcome, PlannedRestOutcome.capReached);
      expect(fourth.planned.used, 2, reason: 'still exactly two, never three');
      expect(fourth.planned, full);
    });

    test('marking the same day twice consumes one rest, not two', () {
      // Spine C1: a replayed write collides with itself. A double tap on Y11's
      // rest row must not spend half her week's allowance twice.
      final first = service.markPlannedRest(
        _mon,
        planned: PlannedRest.fresh(WeekKey.of(_mon)),
      );
      final again = service.markPlannedRest(_mon, planned: first.planned);

      expect(again.outcome, PlannedRestOutcome.alreadyPlanned);
      expect(again.isPlannedRest, isTrue, reason: 'she may still rest');
      expect(again.planned.used, 1, reason: 'nothing was consumed');
      expect(again.remaining, 1);
      expect(again.planned, first.planned);
    });

    test('a repeat of an already-rested day is not reported as a refusal, even '
        'when the week is full', () {
      // The ordering assertion: dedupe runs BEFORE the cap. With the two
      // checks the other way round, re-opening a day she already marked would
      // tell her she had run out — a refusal she did not earn, on the
      // severe-symptom screen.
      final full = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02', '2026-11-04'},
      );

      final repeat = service.markPlannedRest(_wed, planned: full);

      expect(repeat.outcome, PlannedRestOutcome.alreadyPlanned);
      expect(repeat.outcome, isNot(PlannedRestOutcome.capReached));
      expect(repeat.isPlannedRest, isTrue);
      expect(repeat.planned, full);
    });

    test('a different day in the same week is not mistaken for a repeat', () {
      // The negative control for the test above: dedupe must key on the DAY,
      // not on the week. If it keyed on the week, every second rest day would
      // come back `alreadyPlanned` and the cap would never be reached.
      final one = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02'},
      );

      final other = service.markPlannedRest(_wed, planned: one);

      expect(other.outcome, PlannedRestOutcome.planned);
      expect(other.planned.used, 2);
    });

    test('a new week restores the allowance', () {
      final full = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02', '2026-11-04'},
      );

      final next = service.markPlannedRest(_nextMon, planned: full);

      expect(next.outcome, PlannedRestOutcome.planned);
      expect(next.planned.week, _w('2026-W46'));
      expect(next.planned.dayKeys, {
        '2026-11-09',
      }, reason: 'last week\'s days do not travel into this one');
      expect(next.remaining, 1);
    });

    test(
      'a state from a LATER week is discarded just as an earlier one is',
      () {
        // The week rolls over on inequality, not on "is this older?". A
        // comparison would accept a later week's state and spend the wrong
        // week's allowance against this date.
        final nextWeekFull = PlannedRest(
          week: _w('2026-W46'),
          dayKeys: const {'2026-11-09', '2026-11-11'},
        );

        final earlier = service.markPlannedRest(
          _prevFri,
          planned: nextWeekFull,
        );

        expect(
          earlier.outcome,
          PlannedRestOutcome.planned,
          reason:
              'W44 has its own allowance and W46 has nothing to say about it',
        );
        expect(earlier.planned.week, _w('2026-W44'));
        expect(earlier.planned.dayKeys, {'2026-10-30'});
      },
    );

    test('the week comes from the date, never from the state handed in', () {
      final mislabelled = PlannedRest(
        week: _w('2026-W01'),
        dayKeys: const {'2026-01-01'},
      );

      final decision = service.markPlannedRest(_fri, planned: mislabelled);

      expect(decision.planned.week, _w('2026-W45'));
      expect(decision.planned.dayKeys, {'2026-11-06'});
    });

    test('rest days are unordered — there is no run to count', () {
      // Rule 3 at the type level. Marking Wednesday then Monday gives the same
      // state as Monday then Wednesday, so nothing here can express "two in a
      // row", a first, or a last.
      final forwards = service.markPlannedRest(
        _wed,
        planned: service
            .markPlannedRest(_mon, planned: PlannedRest.fresh(WeekKey.of(_mon)))
            .planned,
      );
      final backwards = service.markPlannedRest(
        _mon,
        planned: service
            .markPlannedRest(_wed, planned: PlannedRest.fresh(WeekKey.of(_wed)))
            .planned,
      );

      expect(forwards.planned, backwards.planned);
    });

    test('remaining never goes negative, even from an over-full state', () {
      final overFull = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02', '2026-11-04', '2026-11-06'},
      );
      expect(overFull.remaining, 0);
      expect(overFull.isFull, isTrue);
      expect(
        service.markPlannedRest(_sun, planned: overFull).outcome,
        PlannedRestOutcome.capReached,
      );
    });

    test('covers() answers for a day, and only for that day', () {
      final one = PlannedRest(
        week: WeekKey.of(_mon),
        dayKeys: const {'2026-11-02'},
      );
      expect(one.covers(_mon), isTrue);
      expect(one.covers(DateTime(2026, 11, 2, 23, 59)), isTrue);
      expect(one.covers(_wed), isFalse);
    });
  });

  group('setTarget — the only counter she may write', () {
    test('2, 3 and 4 are all accepted', () {
      for (final target in [2, 3, 4]) {
        final decision = service.setTarget(_established, target);
        expect(
          decision.goal.sessionsTarget,
          target,
          reason: 'she may choose $target',
        );
        expect(decision.accepted, isTrue);
      }
    });

    test('shrinking the week is what T05 offers, and it takes', () {
      // "A goal she can meet beats a goal she abandons."
      final decision = service.setTarget(_established, 2);
      expect(decision.outcome, TargetOutcome.set);
      expect(decision.goal.sessionsTarget, 2);
    });

    test('nothing else on the goal moves', () {
      // `weekly_goal.dart`: every other field is written by a Cloud Function.
      // This is the assertion that the client half stays the client half.
      final after = service.setTarget(_established, 2).goal;

      expect(after.countedWeeks, 23, reason: 'server-owned');
      expect(after.restWeeksBanked, 2, reason: 'server-owned');
      expect(after.restWeekProgress, 3, reason: 'server-owned');
      expect(after.currentRun, 7, reason: 'server-owned');
      expect(after.bestRun, 11, reason: 'server-owned');
      expect(after.recent8, _established.recent8, reason: 'server-owned');
      expect(after.lastClosedWeek, _established.lastClosedWeek);
      expect(after.lastRepairedWeek, _established.lastRepairedWeek);
      expect(after.tierSlippedWeek, _established.tierSlippedWeek);
      expect(after.goalKind, _established.goalKind);
      expect(after.tz, 'Asia/Dubai', reason: 'hers, never the handset\'s');
    });

    test('a target below one is refused', () {
      final decision = service.setTarget(_established, 0);
      expect(decision.outcome, TargetOutcome.belowMinimum);
      expect(decision.accepted, isFalse);
      expect(decision.goal.sessionsTarget, 4, reason: 'the goal she had');
    });

    test('a target above seven is refused', () {
      final decision = service.setTarget(_established, 8);
      expect(decision.outcome, TargetOutcome.aboveMaximum);
      expect(decision.accepted, isFalse);
      expect(decision.goal.sessionsTarget, 4);
    });

    test('refusal is a refusal, never a clamp', () {
      // The defect this is written against: clamping 7 to 4 and 0 to 2 would
      // give her a goal she did not choose, report success, and leave nothing
      // to find it by.
      for (final absurd in [0, 8, 12, -3]) {
        final decision = service.setTarget(_established, absurd);
        expect(
          decision.goal.sessionsTarget,
          4,
          reason:
              '$absurd must leave the goal alone, not be clamped into range',
        );
        expect(decision.goal.sessionsTarget, isNot(absurd));
        expect(decision.accepted, isFalse);
        expect(
          identical(decision.goal, _established),
          isTrue,
          reason: 'a refused write returns the goal untouched, not a copy',
        );
      }
    });

    test('choosing the target she already has is not an error', () {
      final decision = service.setTarget(_established, 4);
      expect(decision.outcome, TargetOutcome.unchanged);
      expect(decision.accepted, isTrue);
      expect(decision.goal.sessionsTarget, 4);
    });

    test('the bounds are 1 and 7', () {
      // The owner widened the goal from 2..4 to 1..7 on 18 Oct 2026, and
      // O03's chips and `Intake.days` run over the same range.
      expect(kMinSessionsTarget, 1);
      expect(kMaxSessionsTarget, 7);
      // Negative control: a 0 or an 8 must not be inside them.
      expect(kMinSessionsTarget, isNot(0));
      expect(kMaxSessionsTarget, isNot(8));
    });
  });

  group('the client half is honest about what it cannot write', () {
    test('markPlannedRest returns no WeeklyGoal, because it cannot', () {
      // D5a's promise is about ADHERENCE, which lives on
      // `users/{uid}/weeks/{yyyy-Www}` — `allow write: if false`. A decision
      // carrying a nudged counter would look finished and change nothing.
      //
      // Asserting the absence of a field is not something a value test can do,
      // so this asserts the consequence: nothing the service returns for a rest
      // day is a goal, and no goal-shaped counter appears in its source.
      final decision = service.markPlannedRest(
        _mon,
        planned: PlannedRest.fresh(WeekKey.of(_mon)),
      );
      expect(decision, isA<PlannedRestDecision>());
      expect(decision, isNot(isA<TargetDecision>()));

      final banned = RegExp(
        r'\b(countedWeeks|restWeeksBanked|restWeekProgress|currentRun'
        r'|bestRun|recent8|points|earnedTier)\b',
      );
      final offenders = [
        for (final line in _serviceCode())
          if (banned.hasMatch(line)) line.trim(),
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'every one of these is written by a Cloud Function. The service '
            'must not name one in code, let alone return one.',
      );

      // The control — the guard must bite on the write it forbids.
      expect(
        banned.hasMatch('goal.copyWith(countedWeeks: goal.countedWeeks + 1)'),
        isTrue,
      );
      expect(banned.hasMatch('restWeeksBanked: 0,'), isTrue);
      // And must not fire on the one field that IS hers.
      expect(banned.hasMatch('sessionsTarget: target,'), isFalse);
    });

    test('RULE 3 — no run counter, in any spelling', () {
      final banned = RegExp(
        r'\b(streak|dayStreak|daysStreak|dailyStreak|daysInARow|consecutiveDays'
        r'|currentStreak|longestStreak|missedDays|daysMissed|restsInARow)\b',
        caseSensitive: false,
      );
      final offenders = [
        for (final line in _serviceCode())
          if (banned.hasMatch(line)) line.trim(),
      ];
      expect(offenders, isEmpty, reason: 'Rule 3: weeks, not days');

      // The control.
      expect(banned.hasMatch('final int restsInARow;'), isTrue);
      expect(banned.hasMatch('int dailyStreak = 0;'), isTrue);
      // And must not fire on the vocabulary this file legitimately uses.
      expect(banned.hasMatch('final Set<String> dayKeys;'), isFalse);
      expect(banned.hasMatch('const int kPlannedRestPerWeek = 2;'), isFalse);
    });

    test('RULE 9 — nothing here can ask her to confirm a rest', () {
      final banned = RegExp(
        r'(showDialog|AlertDialog|\bconfirm\w*\s*[:(]|bool\s+confirmed)',
        caseSensitive: false,
      );
      final offenders = [
        for (final line in _serviceCode())
          if (banned.hasMatch(line)) line.trim(),
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'rule 9: no confirmation parameter, so no screen can be asked to '
            'raise one on her behalf',
      );

      // The control.
      expect(banned.hasMatch('required bool confirmed,'), isTrue);
      expect(
        banned.hasMatch('await showDialog<bool>(context: context,'),
        isTrue,
      );
    });

    test('Western digits only — the day id is built by hand, never by intl', () {
      // P0-A11Y-01. `NumberFormat`/`DateFormat` emit Eastern digits under `ar`,
      // and a document id that changes with the reader's language is not an id.
      final source = File('lib/domain/rewards/weekly_goal_service.dart')
          .readAsStringSync();
      expect(source, isNot(contains('NumberFormat')));
      expect(source, isNot(contains('DateFormat')));
      expect(source, isNot(contains("import 'package:intl")));

      // And the ids it produces are Western digits, in an Arabic-safe shape.
      final decision = service.markPlannedRest(
        _sun,
        planned: PlannedRest.fresh(WeekKey.of(_sun)),
      );
      expect(decision.planned.dayKeys.single, matches(r'^\d{4}-\d{2}-\d{2}$'));
      expect(decision.planned.dayKeys.single, '2026-11-08');
    });
  });
}
