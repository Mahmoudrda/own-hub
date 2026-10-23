// D41: rewards are paid honestly, on the phone.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/domain/rewards/award_table.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

final DateTime tue = DateTime(2026, 10, 13, 10);

PersonalBest best(String id, {bool improved = true}) => PersonalBest(
  exerciseId: id,
  metric: BestMetric.reps,
  dateKey: '2026-10-13',
  sessionId: 's',
  reps: 12,
  previous: improved ? const PreviousBest(reps: 10) : null,
);

void main() {
  late ProgressStore progress;
  late InMemoryTodayRepository today;
  final rewards = RewardsState.instance;

  setUp(() {
    rewards.reset();
    TrainingStreakState.instance.reset();
    progress = ProgressStore();
    today = InMemoryTodayRepository();
  });

  CreditOutcome credit(String id, {DateTime? at}) => rewards.creditSession(
    sessionId: id,
    source: SessionSource.live,
    today: today,
    progress: progress,
    now: at ?? tue,
  );

  test('the daily cap holds across sessions, not only inside one', () {
    final a = credit('live-1');
    final b = credit('live-2');
    final c = credit('live-3', at: tue.add(const Duration(hours: 2)));
    // 30 + 30 reaches the 60-point day. The week (target 3) counts on the
    // third, which pays its 40 outside the cap; the session itself gets 0.
    expect(a.sessionPoints, 30);
    expect(b.sessionPoints, 30);
    expect(c.sessionPoints, 0);
    expect(c.weekCountedNow, isTrue);
    expect(c.weekPoints, 40);
  });

  test(
    'a session that ends after Sunday midnight puts Home on Monday, once',
    () {
      // Home reads its week the way production wires it: from the week
      // documents. It is still on Sunday, with Sunday's week full.
      final sunday = DateTime(2026, 10, 18, 23, 50);
      final home = InMemoryTodayRepository(
        day: TodayDay(
          date: sunday,
          state: DayState.done,
          arc: const FirstWeekArc(hasAnyLog: true),
          week: const WeekProgress(sessionsLogged: 3, sessionsTarget: 3),
        ),
        weekSource: (now) {
          final doc = progress.weeks[WeekKey.of(now).id];
          return doc == null
              ? null
              : WeekProgress(
                  sessionsLogged: doc.sessionsLogged,
                  sessionsTarget: doc.sessionsTarget,
                );
        },
      );
      final outcome = rewards.creditSession(
        sessionId: 'live-midnight',
        source: SessionSource.live,
        today: home,
        progress: progress,
        now: DateTime(2026, 10, 19, 0, 10),
      );
      expect(home.day.date.day, 19);
      expect(outcome.loggedAfter, 1);
      expect(home.day.week.sessionsLogged, outcome.loggedAfter);
      expect(home.day.week.sessionsTarget, outcome.target);
    },
  );

  test('a replayed session pays nothing and moves nothing', () {
    credit('live-1');
    final points = progress.rewards.points;
    final again = credit('live-1');
    expect(again.alreadyCredited, isTrue);
    expect(progress.rewards.points, points);
    expect(progress.rewards.sessionsLogged, 1);
  });

  test('a counted week pays 40 exactly once', () {
    credit('live-1');
    credit('live-2');
    credit('live-3', at: tue.add(const Duration(days: 1)));
    credit('live-4', at: tue.add(const Duration(days: 2)));
    final weekIds = rewards.awardIds.where((id) => id.startsWith('week:'));
    expect(weekIds, ['week:${WeekKey.of(tue).id}']);
  });

  test('the cap and the paid ids survive a restore', () {
    credit('live-1');
    credit('live-2');
    final ids = rewards.awardIds;
    final cap = rewards.capState;
    rewards.reset();
    rewards.restore(awardIds: ids, cap: cap);
    final third = credit('live-3');
    expect(third.sessionPoints, 0, reason: 'the day was already at 60');
  });

  test('closing weeks fills empty ones, ends the run and banks rest weeks', () {
    // Four counted weeks in a row bank one rest week.
    for (var w = 0; w < 4; w++) {
      final monday = DateTime(2026, 9, 7 + 7 * w, 10);
      for (var s = 0; s < 3; s++) {
        credit('w$w-$s', at: monday.add(Duration(days: s)));
      }
    }
    rewards.closeStaleWeeks(progress: progress, now: DateTime(2026, 10, 5, 9));
    expect(progress.goal.countedWeeks, 4);
    expect(progress.goal.currentRun, 4);
    expect(progress.goal.restWeeksBanked, 1);

    // Two empty weeks later: the first is repaired by the bank, the second is
    // missed and the run ends. Neither pays.
    final before = progress.rewards.points;
    rewards.closeStaleWeeks(progress: progress, now: DateTime(2026, 10, 19, 9));
    expect(progress.weeks['2026-W41']!.isClosed, isTrue);
    expect(progress.weeks['2026-W42']!.isClosed, isTrue);
    expect(progress.goal.restWeeksBanked, 0);
    expect(progress.goal.currentRun, 0);
    expect(progress.rewards.points, before);
  });

  test('closing twice changes nothing the second time', () {
    credit('live-1', at: DateTime(2026, 9, 7, 10));
    rewards.closeStaleWeeks(progress: progress, now: tue);
    final goal = progress.goal;
    expect(rewards.closeStaleWeeks(progress: progress, now: tue), isNull);
    expect(progress.goal.lastClosedWeek, goal.lastClosedWeek);
  });

  test('a real personal best pays; a first mark does not; three a day', () {
    final granted = rewards.creditPersonalBests(
      [best('a'), best('b', improved: false), best('c'), best('d'), best('e')],
      sessionId: 's',
      progress: progress,
      now: tue,
    );
    expect(granted, 30, reason: '3 × 10, the fourth refused, b was a first');
  });

  test('food pays once a day, and the preview says so', () {
    expect(rewards.foodDayPointsAvailable('2026-10-13'), kFoodDayPoints);
    expect(
      rewards.foodDayPointsAvailable('2026-10-13', anotherPendingToday: true),
      0,
    );
    expect(
      rewards.creditFoodDay(day: '2026-10-13', progress: progress, now: tue),
      kFoodDayPoints,
    );
    expect(
      rewards.creditFoodDay(day: '2026-10-13', progress: progress, now: tue),
      0,
    );
    expect(rewards.foodDayPointsAvailable('2026-10-13'), 0);
  });

  test('milestones pay once, when their count is reached', () {
    final first = credit('live-1');
    expect(first.milestonesEarned, contains('first_session'));
    expect(progress.rewards.milestones.keys, contains('first_session'));
    final second = credit('live-2');
    expect(second.milestonesEarned, isNot(contains('first_session')));
  });

  test('a lowered target can count the week, and pays it once', () {
    credit('live-1');
    rewards.retargetCurrentWeek(1, progress: progress, now: tue);
    expect(progress.weeks[WeekKey.of(tue).id]!.counted, isTrue);
    expect(rewards.awardIds, contains('week:${WeekKey.of(tue).id}'));
    rewards.retargetCurrentWeek(1, progress: progress, now: tue);
    expect(
      rewards.awardIds.where((id) => id.startsWith('week:')),
      hasLength(1),
    );
  });

  test('a session credit is noted for the training streak, once', () {
    credit('live-1');
    credit('live-1');
    expect(TrainingStreakState.instance.sessionsByDay['2026-10-13'], 1);
  });

  test('a week with no document stays closed-safe: weeks are WeekDocs', () {
    credit('live-1', at: DateTime(2026, 9, 7, 10));
    rewards.closeStaleWeeks(progress: progress, now: tue);
    expect(
      progress.weeks.values.where((w) => w.week.compareTo(WeekKey.of(tue)) < 0),
      everyElement(isA<WeekDoc>().having((w) => w.isClosed, 'closed', isTrue)),
    );
  });
}
