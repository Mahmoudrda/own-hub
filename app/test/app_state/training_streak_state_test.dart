// What the phone keeps for her streak: her choices and her sessions per day,
// never a running count (D37).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/rewards_state.dart';
import 'package:own_hub/app_state/training_streak_state.dart';
import 'package:own_hub/domain/rewards/training_streak.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';

void main() {
  final state = TrainingStreakState.instance;
  late ProgressStore progress;

  setUp(() {
    state.reset();
    RewardsState.instance.reset();
    progress = ProgressStore();
  });

  test('a credit counts its day once per credit, and best follows', () {
    state.noteCredit(DateTime(2026, 10, 12, 9), progress: progress);
    state.noteCredit(DateTime(2026, 10, 12, 18), progress: progress);
    expect(state.sessionsByDay['2026-10-12'], 2);
    final status = state.status(
      progress: progress,
      now: DateTime(2026, 10, 13),
    );
    expect(status.days, 1);
    expect(status.best, 1);
  });

  test('off draws nothing; on again starts fresh and keeps the best', () {
    state.noteCredit(DateTime(2026, 10, 12, 9), progress: progress);
    state.setEnabled(false, progress: progress, now: DateTime(2026, 10, 13));
    expect(
      state.status(progress: progress, now: DateTime(2026, 10, 13)).enabled,
      isFalse,
    );
    state.setEnabled(true, progress: progress, now: DateTime(2026, 10, 20));
    final again = state.status(progress: progress, now: DateTime(2026, 10, 20));
    expect(again.days, 0);
    expect(again.best, 1);
  });

  test('pause and resume', () {
    state.noteCredit(DateTime(2026, 10, 12, 9), progress: progress);
    state.pause(StreakPauseLength.untilResumed, now: DateTime(2026, 10, 13));
    expect(
      state.status(progress: progress, now: DateTime(2026, 10, 13)).pausedToday,
      isTrue,
    );
    state.resume(now: DateTime(2026, 10, 15));
    expect(
      state.status(progress: progress, now: DateTime(2026, 10, 15)).pausedToday,
      isFalse,
    );
  });

  test('the snapshot carries her choices and her days, and nothing else', () {
    state.noteCredit(DateTime(2026, 10, 12, 9), progress: progress);
    state.pause(StreakPauseLength.week, now: DateTime(2026, 10, 13));
    final document =
        jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>;
    final section = document['trainingStreak']! as Map<String, Object?>;
    expect(
      section.keys,
      unorderedEquals(['on', 'since', 'best', 'pauses', 'days']),
    );
    state.reset();
    AppSnapshot.restore(jsonEncode(document));
    expect(state.sessionsByDay['2026-10-12'], 1);
    expect(state.settings().pauses.single.end, '2026-10-19');
  });

  test('awards and the cap make the round trip', () {
    RewardsState.instance.creditFoodDay(
      day: '2026-10-13',
      progress: progress,
      now: DateTime(2026, 10, 13),
    );
    final document = jsonEncode(AppSnapshot.capture());
    RewardsState.instance.reset();
    AppSnapshot.restore(document);
    expect(RewardsState.instance.awardIds, contains('meal:2026-10-13'));
    expect(RewardsState.instance.capState.pointsToday, 5);
  });

  test('an old snapshot without these sections restores the rest', () {
    final document =
        jsonDecode(jsonEncode(AppSnapshot.capture())) as Map<String, Object?>
          ..remove('awards')
          ..remove('trainingStreak');
    expect(AppSnapshot.restore(jsonEncode(document)), greaterThan(0));
  });
}
