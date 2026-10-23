// G — motivation and honest rewards (guide §15, DECISIONS D37–D41).
//
// Pure contracts for rows G04, G06, G07, G11, G14 and G15's data. The app's
// own suites hold the widget and journey evidence; this pack states the rules
// in the form a reviewer can read without the app.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/training_streak.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/train/domain/own_best_challenge.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

void main() {
  setUp(() {
    RewardsState.instance.reset();
    TrainingStreakState.instance.reset();
  });

  test('G04 a counted week pays once and only once', () {
    final progress = ProgressStore();
    final today = InMemoryTodayRepository();
    final on = DateTime(2026, 10, 13, 9);
    for (var i = 0; i < 5; i++) {
      RewardsState.instance.creditSession(
        sessionId: 's$i',
        source: SessionSource.live,
        today: today,
        progress: progress,
        now: on.add(Duration(days: i % 3)),
      );
    }
    expect(
      RewardsState.instance.awardIds.where((id) => id.startsWith('week:')),
      ['week:${WeekKey.of(on).id}'],
    );
  });

  test('G06 a first mark pays nothing; an improvement pays', () {
    final progress = ProgressStore();
    final first = RewardsState.instance.creditPersonalBests(
      const [
        PersonalBest(
          exerciseId: 'a',
          metric: BestMetric.reps,
          dateKey: '2026-10-13',
          sessionId: 's',
          reps: 10,
        ),
      ],
      sessionId: 's',
      progress: progress,
      now: DateTime(2026, 10, 13),
    );
    final improved = RewardsState.instance.creditPersonalBests(
      const [
        PersonalBest(
          exerciseId: 'a',
          metric: BestMetric.reps,
          dateKey: '2026-10-13',
          sessionId: 't',
          reps: 12,
          previous: PreviousBest(reps: 10),
        ),
      ],
      sessionId: 't',
      progress: progress,
      now: DateTime(2026, 10, 13),
    );
    expect(first, 0);
    expect(improved, 10);
  });

  test('G07 a food day pays once', () {
    final progress = ProgressStore();
    final on = DateTime(2026, 10, 13);
    expect(
      RewardsState.instance.creditFoodDay(day: '2026-10-13', progress: progress, now: on),
      5,
    );
    expect(
      RewardsState.instance.creditFoodDay(day: '2026-10-13', progress: progress, now: on),
      0,
    );
  });

  test('G11 the streak ends only on the day the week becomes unreachable', () {
    final trace = const TrainingStreak().trace(
      settings: const StreakSettings(since: '2026-10-12'),
      sessionsByDay: const {'2026-10-12': 1},
      targetFor: (_) => 3,
      coveredByRestWeek: (_) => false,
      today: DateTime(2026, 10, 19),
    );
    final ended = trace.where((d) => d.kind == StreakDayKind.ended).toList();
    expect(ended.single.day, '2026-10-17');
  });

  test('G11 a week that reached its target never ends the run', () {
    final status = const TrainingStreak().evaluate(
      settings: const StreakSettings(since: '2026-10-04'),
      sessionsByDay: const {'2026-10-04': 1, '2026-10-10': 2, '2026-10-11': 1},
      targetFor: (_) => 3,
      coveredByRestWeek: (_) => false,
      today: DateTime(2026, 10, 12),
    );
    expect(status.days, 8);
  });

  test('G14 finishing the plan always meets the challenge', () {
    const own = OwnBestChallenge();
    final plan = [
      const PlannedMove(
        exerciseId: 'squat',
        name: 'Squat',
        prescriptionLabel: '',
        sets: [
          PrescribedSet(exerciseId: 'squat', order: 1, reps: 10),
          PrescribedSet(exerciseId: 'squat', order: 2, reps: 10),
        ],
      ),
    ];
    for (final last in [1, 19, 20, 40]) {
      final challenge = own.choose(
        week: WeekKey.of(DateTime(2026, 10, 13)),
        plan: plan,
        sessionsTarget: 2,
        lastWeek: {'squat': (reps: last, seconds: 0, sets: 2)},
      )!;
      expect(challenge.target, lessThanOrEqualTo(challenge.planned));
      expect(
        own.progress(challenge, {'squat': (reps: 40, seconds: 0, sets: 4)}).met,
        isTrue,
      );
    }
  });

  test('G15 a summary separates real bests from first marks', () {
    final summary = summarise(
      sessionId: 's',
      source: SessionSource.live,
      flushes: const <FlushRecord>[],
      durationSec: 600,
      credit: const CreditOutcome(sessionPoints: 30),
      bests: const [
        PersonalBest(
          exerciseId: 'a',
          metric: BestMetric.reps,
          dateKey: 'd',
          sessionId: 's',
          reps: 12,
          previous: PreviousBest(reps: 10),
        ),
        PersonalBest(
          exerciseId: 'b',
          metric: BestMetric.reps,
          dateKey: 'd',
          sessionId: 's',
          reps: 8,
        ),
      ],
    );
    expect(summary.newBests.map((b) => b.exerciseId), ['a']);
    expect(summary.firstMarks, 1);
    expect(summary.minutes, 10);
  });
}
