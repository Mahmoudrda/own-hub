// Home's day moves on, and its week agrees with the week document (G08).

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';

void main() {
  TodayDay loggedDay(DateTime on) => TodayDay(
    date: on,
    state: DayState.done,
    arc: const FirstWeekArc(hasAnyLog: true, completed: {FirstWeekStep.logSet}),
    week: const WeekProgress(sessionsLogged: 3, sessionsTarget: 3),
    walkToCount: true,
    walkMinutes: 20,
    mealLoggedAt: on,
    showCycleCard: true,
  );

  test('a new day resets the day and keeps what is about her', () {
    final repo = InMemoryTodayRepository(
      day: loggedDay(DateTime(2026, 10, 13, 9)),
    );
    expect(
      repo.rollTo(DateTime(2026, 10, 13, 22)),
      isFalse,
      reason: 'same day',
    );
    expect(repo.rollTo(DateTime(2026, 10, 14, 7)), isTrue);
    final day = repo.day;
    expect(day.date.day, 14);
    expect(day.state, DayState.nothingDone);
    expect(day.mealLoggedAt, isNull);
    expect(day.walkToCount, isFalse);
    expect(day.showCycleCard, isTrue);
    expect(day.arc.completed, contains(FirstWeekStep.logSet));
    // Same ISO week: the week carries over.
    expect(day.week.sessionsLogged, 3);
  });

  test('a new week starts the week again against the same target', () {
    final repo = InMemoryTodayRepository(
      day: loggedDay(DateTime(2026, 10, 18, 9)),
    );
    repo.rollTo(DateTime(2026, 10, 19, 8)); // Monday
    expect(repo.day.week.sessionsLogged, 0);
    expect(repo.day.week.sessionsTarget, 3);
  });

  test('the week document wins when there is one', () {
    final repo = InMemoryTodayRepository(
      day: loggedDay(DateTime(2026, 10, 18, 9)),
      weekSource: (_) =>
          const WeekProgress(sessionsLogged: 1, sessionsTarget: 4),
    );
    repo.rollTo(DateTime(2026, 10, 19, 8));
    expect(repo.day.week.sessionsTarget, 4);
    expect(repo.day.week.sessionsLogged, 1);
  });

  test('finishing a session ticks the first week step', () {
    final repo = InMemoryTodayRepository();
    repo.recordSession('live-1');
    expect(repo.day.arc.completed, contains(FirstWeekStep.finishSession));
  });

  test('a recalled session ticks it too', () async {
    final repo = InMemoryTodayRepository();
    await repo.logRecalledSession(
      const RecalledSession(id: 'recalled-x', title: 't'),
    );
    expect(repo.day.arc.completed, contains(FirstWeekStep.finishSession));
  });

  test('never moves backwards', () {
    final repo = InMemoryTodayRepository(
      day: loggedDay(DateTime(2026, 10, 14, 9)),
    );
    expect(repo.rollTo(DateTime(2026, 10, 13, 23, 50)), isFalse);
    expect(repo.day.date.day, 14);
  });

  test(
    'a session that crosses Sunday midnight is credited to the week it ends in',
    () {
      // Started Sunday 23:40, finished Monday 00:20: the credit, and so Home's
      // week and the streak's day, use the finish time (WorkoutSessionState and
      // RewardsState credit at AppClock.now()), which is Monday.
      final repo = InMemoryTodayRepository(
        day: loggedDay(DateTime(2026, 10, 18, 23, 40)),
      );
      expect(repo.rollTo(DateTime(2026, 10, 19, 0, 20)), isTrue);
      expect(repo.day.week.sessionsLogged, 0, reason: 'a new ISO week');
      repo.recordSession('live-midnight');
      expect(repo.day.week.sessionsLogged, 1);
    },
  );
}
