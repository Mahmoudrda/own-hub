// Which day of a coach's plan is today's: the start date decides, in Cairo
// days, and the night Egypt moves its clocks is still one day.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart' show LifeStage;
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_today.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';

CoachPlan _meal({DateTime? startsOn, DateTime? publishedAt}) => CoachPlan(
  id: 'm1',
  kind: PlanKind.meal,
  meal: MealPlanBody(
    days: [
      for (final n in [1, 2, 3]) MealDay(label: 'Day $n'),
    ],
  ),
  startsOn: startsOn,
  publishedAt: publishedAt,
);

MyPlan _twoWeeks() => MyPlan(
  days: [
    for (var i = 0; i < 6; i++)
      MyPlanDay(
        week: i < 3 ? 1 : 2,
        session: AuthoredSession(
          sessionId: 'mine_${i + 1}',
          titleEn: 'Day ${i + 1}',
          titleAr: 'يوم ${i + 1}',
          minutes: 30,
          lifeStages: const {LifeStage.none},
          moves: [
            AuthoredMove(
              exerciseId: 'squat',
              nameEn: 'Squat',
              nameAr: 'سكوات',
              sets: 3,
              reps: 10,
            ),
          ],
        ),
      ),
  ],
);

void main() {
  group('the meal plan starts on its start date', () {
    // Saturday 7 November 2026, noon, as CoachPlan reads a start date.
    final starts = DateTime(2026, 11, 7, 12);

    test('nothing before it, day one on it, and the days repeat', () {
      final plan = _meal(startsOn: starts);
      // Cairo is UTC+2 in November: 10:00 UTC is noon there.
      expect(todaysMealDay(plan, DateTime.utc(2026, 11, 6, 10)), isNull);
      expect(todaysMealDay(plan, DateTime.utc(2026, 11, 7, 10)), 0);
      expect(todaysMealDay(plan, DateTime.utc(2026, 11, 9, 10)), 2);
      expect(todaysMealDay(plan, DateTime.utc(2026, 11, 10, 10)), 0);
    });

    test('with no start date it is the day it was published, as before', () {
      final plan = _meal(publishedAt: DateTime.utc(2026, 11, 1, 10));
      expect(todaysMealDay(plan, DateTime.utc(2026, 11, 1, 18)), 0);
      expect(todaysMealDay(plan, DateTime.utc(2026, 11, 3, 10)), 2);
      // A phone clock behind the publish time is day one, not nothing.
      expect(todaysMealDay(plan, DateTime.utc(2026, 10, 30, 10)), 0);
    });
  });

  group('week two starts on day seven, whatever the clocks do', () {
    final plan = _twoWeeks();

    void weekFlips(DateTime startsOn, DateTime lastMomentOfDaySix) {
      // The last minute of day six is week one; the next minute is week two.
      final before = lastMomentOfDaySix;
      final after = lastMomentOfDaySix.add(const Duration(minutes: 1));
      expect(currentWeekOf(plan, startsOn, before), 1);
      expect(currentWeekOf(plan, startsOn, after), 2);
      expect(
        todaysWorkoutDay(plan, 0, null, startsOn: startsOn, now: before),
        0,
      );
      expect(
        todaysWorkoutDay(plan, 0, null, startsOn: startsOn, now: after),
        3,
      );
    }

    test('over the spring change (Friday 30 April 2027)', () {
      // Monday 26 April, noon. Cairo is UTC+2 until the night of the 30th and
      // UTC+3 after it, so day six ends at 21:00 UTC on 2 May.
      weekFlips(DateTime(2027, 4, 26, 12), DateTime.utc(2027, 5, 2, 20, 59));
    });

    test('over the autumn change (Thursday 28 October 2027)', () {
      // Monday 25 October. UTC+3 until the night of the 28th, UTC+2 after, so
      // day six ends at 22:00 UTC on 31 October.
      weekFlips(DateTime(2027, 10, 25, 12), DateTime.utc(2027, 10, 31, 21, 59));
    });

    test('no change at all is the same', () {
      weekFlips(DateTime(2026, 11, 2, 12), DateTime.utc(2026, 11, 8, 21, 59));
    });
  });
}
