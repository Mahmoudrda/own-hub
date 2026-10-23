// D37's rule table, as tests. Each case is one sentence of the decision.
//
// Weeks below are ISO weeks. 12 October 2026 is a Monday.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/rewards/training_streak.dart';
import 'package:own_hub/domain/week/week_key.dart';

DateTime d(int month, int day) => DateTime(2026, month, day);

StreakStatus run(
  Map<String, int> byDay, {
  required DateTime today,
  String since = '2026-10-01',
  int target = 3,
  bool covered = false,
  List<StreakPause> pauses = const <StreakPause>[],
  int Function(WeekKey)? targetFor,
}) => const TrainingStreak().evaluate(
  settings: StreakSettings(since: since, pauses: pauses),
  sessionsByDay: byDay,
  targetFor: targetFor ?? (_) => target,
  coveredByRestWeek: (_) => covered,
  today: today,
);

void main() {
  test('nothing logged is no run, and never a failure', () {
    final status = run(const {}, today: d(10, 14));
    expect(status.enabled, isTrue);
    expect(status.days, 0);
    expect(status.best, 0);
  });

  test('a day she trains starts it; today pending neither adds nor ends', () {
    final status = run({'2026-10-12': 1}, today: d(10, 13));
    // Monday trained (1); Tuesday is today and not trained, so pending.
    expect(status.days, 1);
    expect(status.trainedToday, isFalse);
  });

  test('rest days count while the week target is still reachable', () {
    // Target 3, trained Monday only. Tue–Fri are rest while 1 + days left
    // still reaches 3; Saturday is the day it no longer can.
    final trace = const TrainingStreak().trace(
      settings: const StreakSettings(since: '2026-10-12'),
      sessionsByDay: const {'2026-10-12': 1},
      targetFor: (_) => 3,
      coveredByRestWeek: (_) => false,
      today: d(10, 19),
    );
    final kinds = {for (final day in trace) day.day: day.kind};
    expect(kinds['2026-10-12'], StreakDayKind.trained);
    expect(kinds['2026-10-13'], StreakDayKind.rest);
    expect(kinds['2026-10-16'], StreakDayKind.rest); // Friday: 1 + 2 = 3
    expect(kinds['2026-10-17'], StreakDayKind.ended); // Saturday: 1 + 1 < 3
    expect(kinds['2026-10-18'], StreakDayKind.waiting); // Sunday, same week
    expect(kinds['2026-10-19'], StreakDayKind.pending); // today
  });

  test('ending is silent: the next session is day 1, and best is kept', () {
    final status = run(
      {'2026-10-12': 1, '2026-10-20': 1},
      since: '2026-10-12',
      today: d(10, 20),
    );
    expect(status.days, 1);
    // Mon trained + Tue–Fri rest = 5 before Saturday ended it.
    expect(status.best, 5);
  });

  test('a week that meets its target keeps every day of it', () {
    final status = run(
      {'2026-10-12': 1, '2026-10-14': 1, '2026-10-16': 1},
      since: '2026-10-12',
      today: d(10, 19),
    );
    // Mon–Sun all kept (7), Monday 19 is today and pending.
    expect(status.days, 7);
  });

  test('a rest week she earned covers a slipped week', () {
    final status = run(
      {'2026-10-12': 1, '2026-10-19': 1},
      since: '2026-10-12',
      today: d(10, 19),
      covered: true,
    );
    // Mon + Tue–Fri rest (5), Sat/Sun covered (neutral), Mon 19 trained (6).
    expect(status.days, 6);
  });

  test('a pause is neutral, and a paused week cannot end the run', () {
    final status = run(
      {'2026-10-12': 1, '2026-10-20': 1},
      since: '2026-10-12',
      today: d(10, 20),
      pauses: const [StreakPause(start: '2026-10-15', end: '2026-10-16')],
    );
    // Mon trained, Tue/Wed rest, Thu/Fri paused, Sat/Sun slipped in a paused
    // week so neutral, Mon 19 rest (week 2: 0 + 6 >= 3), Tue 20 trained.
    expect(status.days, 5);
  });

  test(
    'a week that catches up keeps the days it looked like it slipped on',
    () {
      // Target 3: nothing Mon–Fri after a Sunday start, then two sessions on
      // Saturday and one on Sunday. The week counted, so Friday was a rest day.
      final status = run(
        {'2026-10-04': 1, '2026-10-10': 2, '2026-10-11': 1},
        since: '2026-10-04',
        today: d(10, 12),
      );
      // Sun 4 trained, Mon 5–Fri 9 rest, Sat 10 and Sun 11 trained; Mon 12 is
      // today and pending.
      expect(status.days, 8);
      final trace = const TrainingStreak().trace(
        settings: const StreakSettings(since: '2026-10-04'),
        sessionsByDay: const {
          '2026-10-04': 1,
          '2026-10-10': 2,
          '2026-10-11': 1,
        },
        targetFor: (_) => 3,
        coveredByRestWeek: (_) => false,
        today: d(10, 12),
      );
      expect(trace.where((day) => day.kind == StreakDayKind.ended), isEmpty);
    },
  );

  test('several sessions on one day count once toward the run', () {
    final status = run(
      {'2026-10-12': 3},
      since: '2026-10-12',
      today: d(10, 13),
    );
    expect(status.days, 1);
  });

  test('a lowered target mid-week is the target that week is judged by', () {
    final status = run(
      {'2026-10-12': 1},
      since: '2026-10-12',
      today: d(10, 19),
      targetFor: (_) => 1,
    );
    // Target 1 is met on Monday, so every day of the week is kept.
    expect(status.days, 7);
  });

  test('days before "since" are never judged', () {
    final status = run(
      {'2026-10-01': 1},
      since: '2026-10-12',
      today: d(10, 14),
    );
    expect(status.days, 0);
  });

  test('switched off reads as off, with nothing judged', () {
    final status = const TrainingStreak().evaluate(
      settings: const StreakSettings(since: '2026-10-12', enabled: false),
      sessionsByDay: const {'2026-10-12': 1},
      targetFor: (_) => 3,
      coveredByRestWeek: (_) => false,
      today: d(10, 13),
    );
    expect(status, same(StreakStatus.off));
  });

  group('settings', () {
    test('pausing for a week ends six days later, inclusive', () {
      final paused = StreakSettings.startingOn(d(10, 12))
          .pausedFrom(d(10, 13), StreakPauseLength.week);
      expect(paused.pauses.single.start, '2026-10-13');
      expect(paused.pauses.single.end, '2026-10-19');
      expect(paused.activeOn(d(10, 19)), isNotNull);
      expect(paused.activeOn(d(10, 20)), isNull);
    });

    test('until she comes back has no end, and resuming ends it yesterday', () {
      final paused = StreakSettings.startingOn(d(10, 1))
          .pausedFrom(d(10, 5), StreakPauseLength.untilResumed);
      expect(paused.pauses.single.end, isNull);
      final resumed = paused.resumedOn(d(10, 9));
      expect(resumed.pauses.single.end, '2026-10-08');
      expect(resumed.activeOn(d(10, 9)), isNull);
    });

    test('a pause started today and resumed today leaves nothing behind', () {
      final settings = StreakSettings.startingOn(d(10, 1))
          .pausedFrom(d(10, 5), StreakPauseLength.fortnight)
          .resumedOn(d(10, 5));
      expect(settings.pauses, isEmpty);
    });

    test('best only rises, and switching off and on keeps it', () {
      final settings = StreakSettings.startingOn(d(10, 1)).withBest(9);
      expect(settings.withBest(4).best, 9);
      final again = settings.switchedOff().switchedOn(d(10, 20));
      expect(again.best, 9);
      expect(again.enabled, isTrue);
      expect(again.since, '2026-10-20');
    });
  });

  test('a run longer than the lookback is capped, not broken', () {
    final byDay = <String, int>{};
    for (var i = 0; i < 30; i++) {
      final day = DateTime(2026, 9, 1 + i);
      byDay['${day.year}-${day.month.toString().padLeft(2, '0')}-'
              '${day.day.toString().padLeft(2, '0')}'] =
          1;
    }
    final status = const TrainingStreak(lookback: 10).evaluate(
      settings: const StreakSettings(since: '2026-09-01'),
      sessionsByDay: byDay,
      targetFor: (_) => 3,
      coveredByRestWeek: (_) => false,
      today: d(9, 30),
    );
    expect(status.days, 11);
  });
}
