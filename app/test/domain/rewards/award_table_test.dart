// Implements G6's half of TEST-CASES.csv P0-LOG-04 and P0-LOG-12.
//
// P0-LOG-12 exists because this rule was got wrong once already: written as
// `source == recalled`, adding `unplanned` to the enum silently promoted a
// logged walk to full points and personal-best eligibility. The test below is
// written so that mistake cannot be made again quietly — it asserts that an
// unplanned session earns *the same as a recalled one*, not that it earns 15,
// so a future change to both figures still keeps them equal.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/award_table.dart';
import 'package:own_hub/domain/training/session.dart';
import 'package:own_hub/domain/week/week_key.dart';

void main() {
  const table = AwardTable();

  group('P0-LOG-04 / P0-LOG-12 — only a live session earns full points', () {
    test('a live session earns full credit', () {
      final award = table.award(
        const SessionLogged(sessionId: 'abc', source: SessionSource.live),
      );
      expect(award.points, 30);
      expect(award.kind, AwardKind.session);
      expect(award.underDailyCap, isTrue);
    });

    test('a recalled session earns less', () {
      final award = table.award(
        const SessionLogged(sessionId: 'abc', source: SessionSource.recalled),
      );
      expect(award.points, 15);
    });

    test('an unplanned walk earns exactly what a recalled session earns', () {
      final walk = table.award(
        const SessionLogged(sessionId: 'w', source: SessionSource.unplanned),
      );
      final recalled = table.award(
        const SessionLogged(sessionId: 'r', source: SessionSource.recalled),
      );

      expect(
        walk.points,
        recalled.points,
        reason:
            'the rule is `!= live`. Any source added in future is '
            'reduced-credit by default rather than by amendment.',
      );
      expect(walk.points, lessThan(30));
    });

    test('exactly one source earns full points', () {
      final full = SessionSource.values.where((s) {
        final award = table.award(SessionLogged(sessionId: 'x', source: s));
        return award.points == 30;
      }).toList();

      expect(full, [SessionSource.live]);
    });

    test('the split is SessionCredit\'s, not a second copy of it', () {
      // A different credit scheme must move the answer, which proves the table
      // delegates rather than restating 30 and 15 of its own.
      const generous = AwardTable(
        credit: SessionCredit(livePoints: 50, reducedPoints: 40),
      );
      expect(
        generous
            .award(
              const SessionLogged(sessionId: 'x', source: SessionSource.live),
            )
            .points,
        50,
      );
      expect(
        generous
            .award(
              const SessionLogged(
                sessionId: 'x',
                source: SessionSource.unplanned,
              ),
            )
            .points,
        40,
      );
    });
  });

  group('every award id is deterministic and semantic', () {
    test('the same event always produces the same id', () {
      const event = SessionLogged(
        sessionId: 'sess-9f2',
        source: SessionSource.live,
      );
      expect(table.award(event).awardId, table.award(event).awardId);
      expect(table.award(event).awardId, 'session:sess-9f2');
    });

    test('each kind has its own key shape', () {
      expect(
        table
            .award(
              const PersonalBestSet(
                exerciseId: 'hip_thrust',
                sessionId: 'sess-4',
              ),
            )
            .awardId,
        'best:hip_thrust:sess-4',
      );
      expect(
        table.award(const FoodDayLogged(dayId: '2026-09-18')).awardId,
        'meal:2026-09-18',
      );
      expect(
        table.award(WeekCounted(week: WeekKey.tryParse('2026-W38')!)).awardId,
        'week:2026-W38',
      );
      expect(
        table.award(const MilestoneReached(milestoneId: 'came_back')).awardId,
        'milestone:came_back',
      );
    });

    test('a week can only be paid for once, by construction of its key', () {
      final week = WeekKey.tryParse('2026-W38')!;
      final first = table.award(WeekCounted(week: week));
      final replay = table.award(WeekCounted(week: week));
      expect(first.awardId, replay.awardId);
    });
  });

  group('what sits inside the daily cap and what sits outside it', () {
    test('repeatable kinds are capped', () {
      for (final event in <AwardableEvent>[
        const SessionLogged(sessionId: 'x', source: SessionSource.live),
        const PersonalBestSet(exerciseId: 'x', sessionId: 'y'),
        const FoodDayLogged(dayId: '2026-09-18'),
      ]) {
        expect(table.award(event).underDailyCap, isTrue);
      }
    });

    test('a thing that happens once cannot be ground, so it is not capped', () {
      expect(
        table
            .award(WeekCounted(week: WeekKey.tryParse('2026-W38')!))
            .underDailyCap,
        isFalse,
      );
      expect(
        table.award(const MilestoneReached(milestoneId: 'm')).underDailyCap,
        isFalse,
      );
    });
  });

  group('the absences are the design', () {
    test('there are exactly five kinds of award', () {
      // P02: "None are secret, and none are for filling in a profile." Opening
      // the app, posting, inviting a friend and completing a profile have no
      // AwardableEvent and no AwardKind, so no code path can pay for them.
      // A sixth member here means somebody added one — argue for it in review.
      expect(
        AwardKind.values,
        <AwardKind>{
          AwardKind.session,
          AwardKind.personalBest,
          AwardKind.foodDay,
          AwardKind.weekCounted,
          AwardKind.milestone,
        }.toList(),
      );
    });

    test('the published figures', () {
      expect(kPersonalBestPoints, 10);
      expect(kFoodDayPoints, 5, reason: "G5's published figure, adopted");
      expect(kWeekCountedPoints, 40);
      expect(kMilestonePoints, 25);
    });
  });
}
