// P01's view model — the whole of the screen's behaviour, tested without
// pumping a frame. Step 3 of the Phase 2 build order.
//
// Figures throughout are deliberately not the prototype's.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/rewards.dart';
import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/progress/domain/milestone.dart';
import 'package:own_hub/features/progress/presentation/milestones_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view_model.dart';

WeekBar _bar(int i, {required bool counted, bool repaired = false}) => WeekBar(
  week: WeekKey.tryParse('2026-W${(30 + i).toString().padLeft(2, '0')}')!,
  sessionsLogged: counted ? 2 : 0,
  sessionsTarget: 2,
  counted: counted,
  repairedByRestWeek: repaired,
);

void main() {
  group('the week, which is the only unit', () {
    test('this week comes from the live week document, not the cache', () {
      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(sessionsTarget: 4, countedWeeks: 9),
        rewards: const Rewards(),
        currentWeek: WeekDoc(
          week: WeekKey.tryParse('2026-W38')!,
          sessionsTarget: 2,
          creditedSessionIds: const ['a'],
        ),
      );

      expect(summary.sessionsThisWeek, 1);
      expect(
        summary.sessionsTarget,
        2,
        reason: "the week's own target, which she may have shrunk",
      );
    });

    test('before her first log this week there is no week document', () {
      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(sessionsTarget: 4),
        rewards: const Rewards(),
      );

      expect(summary.sessionsThisWeek, 0);
      expect(
        summary.sessionsTarget,
        4,
        reason: 'falls back to the goal the week would be created with',
      );
    });

    test('the chart holds only closed weeks', () {
      final summary = ProgressSummary.from(
        goal: WeeklyGoal(
          countedWeeks: 9,
          recent8: [
            _bar(0, counted: true),
            _bar(1, counted: false),
            _bar(2, counted: true, repaired: true),
          ],
        ),
        rewards: const Rewards(),
        currentWeek: WeekDoc(
          week: WeekKey.tryParse('2026-W38')!,
          sessionsTarget: 2,
        ),
      );

      expect(summary.recentWeeks, hasLength(3));
      expect(summary.recentWeeks.map((b) => b.kind).toList(), [
        WeekBarKind.counted,
        WeekBarKind.missed,
        WeekBarKind.repaired,
      ]);
    });

    test('the rest-week legend is true only when there is a pale bar', () {
      final withRepair = ProgressSummary.from(
        goal: WeeklyGoal(
          recent8: [
            _bar(0, counted: true),
            _bar(1, counted: true, repaired: true),
          ],
        ),
        rewards: const Rewards(),
      );
      final without = ProgressSummary.from(
        goal: WeeklyGoal(
          recent8: [_bar(0, counted: true), _bar(1, counted: false)],
        ),
        rewards: const Rewards(),
      );

      expect(withRepair.hasRepairedWeekInWindow, isTrue);
      expect(without.hasRepairedWeekInWindow, isFalse);
    });
  });

  group('the level is computed, not stored twice', () {
    test('it follows her points', () {
      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(),
        rewards: const Rewards(points: 235),
      );
      expect(summary.level, 3);
      expect(summary.pointsToNextLevel, 5);
    });

    test('a woman with nothing is level 1', () {
      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(),
        rewards: const Rewards(),
      );
      expect(summary.level, 1);
    });
  });

  group('D14 — the ladder is authored, so a tier is claimed', () {
    // This group asserted the opposite until 19 September 2026: with no ladder
    // authored, `ProgressSummary.from` defaulted to `TierLadder.unauthored` and
    // P01 showed no tier to anyone. The owner wrote the thresholds down, so the
    // default is `TierLadder.shipped` and these assertions invert.

    test('forty counted weeks and thirty bests earn Strong', () {
      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(countedWeeks: 40),
        rewards: const Rewards(points: 4000, bestsCount: 30),
      );

      expect(summary.tierIsKnown, isTrue);
      expect(
        summary.standing.earned,
        Tier.strong,
        reason:
            'Strong asks for 26 weeks and 8 bests; Unshakeable asks for 52, '
            'which 40 does not reach',
      );
    });

    test(
      'with no recent closed weeks the LABEL slips, and the tier does not',
      () {
        // A bare WeeklyGoal has an empty `recent8`, so nothing meets Strong's
        // floor of five of eight. This is the whole promise of T05 in one
        // assertion: what she earned is untouched, and only what she is shown
        // steps down — by exactly one, never two.
        final summary = ProgressSummary.from(
          goal: const WeeklyGoal(countedWeeks: 40),
          rewards: const Rewards(points: 4000, bestsCount: 30),
        );

        expect(summary.standing.earned, Tier.strong);
        expect(summary.standing.display, Tier.regular);
        expect(summary.standing.slipped, isTrue);
      },
    );

    test('a woman with nothing logged is on the first rung, not nowhere', () {
      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(),
        rewards: const Rewards(),
      );

      // First steps asks for one counted week, so she has not reached it — but
      // the ladder is known, which is what P01 needed in order to draw at all.
      expect(summary.tierIsKnown, isTrue);
      expect(summary.standing.earned, Tier.firstSteps);
    });

    test('given a ladder, the bars are her real ratios', () {
      const ladder = TierLadder(<TierRung>[
        TierRung(
          tier: Tier.showingUp,
          countedWeeks: 1,
          bestsCount: 0,
          recencyFloor: 0,
        ),
        TierRung(
          tier: Tier.regular,
          countedWeeks: 5,
          bestsCount: 2,
          recencyFloor: 0,
        ),
        TierRung(
          tier: Tier.strong,
          countedWeeks: 15,
          bestsCount: 8,
          recencyFloor: 0,
        ),
      ]);

      final summary = ProgressSummary.from(
        goal: const WeeklyGoal(countedWeeks: 9),
        rewards: const Rewards(bestsCount: 4),
        ladder: ladder,
      );

      expect(summary.standing.earned, Tier.regular);
      final next = summary.nextRung!;
      expect(next.tier, Tier.strong);
      expect(summary.percentToCountedWeeks(next), closeTo(60, 0.01));
      expect(summary.percentToBests(next), closeTo(50, 0.01));
    });
  });

  group('P02 — milestones', () {
    test(
      'the shipped catalogue is the authored eight, not an invented twelve',
      () {
        // G6 §9.14: P02 names eight and four more were inferred. The inferred
        // four are not here. "Came back" was the eighth P02 names and the only
        // one the dictionary could not label; `cameBack` exists now, so eight
        // is what can honestly ship. The heading's claim of twelve is checked
        // against this number at the widget, not asserted.
        expect(authoredMilestones.count, 8);
        expect(authoredMilestones.milestones.map((m) => m.id).toSet(), {
          'first_session',
          'first_counted_week',
          'first_personal_best',
          'ten_sessions',
          'twenty_counted_weeks',
          'first_program_finished',
          'fifty_sessions',
          'came_back',
        });
      },
    );

    test('coming back is earned from the ledger, never from a counter', () {
      // MilestoneCounts has no member for it and `of` returns 0, so no amount
      // of training can earn it and no corrected counter can take it away.
      final counts = const MilestoneCounts(
        sessions: 500,
        countedWeeks: 80,
        personalBests: 40,
        foodDays: 300,
        programDays: 200,
      );
      expect(counts.of(MilestoneMeasure.cameBack), 0);

      final untouched = MilestonesSummary.from(
        catalogue: authoredMilestones,
        counts: counts,
      );
      expect(untouched.ahead.map((s) => s.milestone.id), contains('came_back'));

      final earned = MilestonesSummary.from(
        catalogue: authoredMilestones,
        counts: const MilestoneCounts(),
        earnedAt: {'came_back': DateTime(2026, 8, 22)},
      );
      expect(earned.earned.single.milestone.id, 'came_back');
    });

    test('nothing in the catalogue is for filling in a profile', () {
      // The measures are things she did. There is no member for a profile
      // field, a follower or a login, so such a milestone is not expressible.
      for (final milestone in authoredMilestones.milestones) {
        expect(
          milestone.measure,
          isIn(const [
            MilestoneMeasure.sessions,
            MilestoneMeasure.countedWeeks,
            MilestoneMeasure.personalBests,
            MilestoneMeasure.foodDays,
            MilestoneMeasure.programDays,
            MilestoneMeasure.cameBack,
          ]),
        );
      }
    });

    test('earned comes from the ledger, not from the count being high', () {
      final summary = MilestonesSummary.from(
        catalogue: authoredMilestones,
        counts: const MilestoneCounts(sessions: 60, countedWeeks: 9),
        earnedAt: {'first_session': DateTime(2026, 6, 3)},
      );

      // Sixty sessions is well past "10 sessions" and "50 sessions", but only
      // the one the ledger records is earned — so a counter corrected downward
      // cannot un-earn anything.
      expect(summary.earnedCount, 1);
      expect(summary.earned.single.milestone.id, 'first_session');
      expect(
        summary.ahead.map((s) => s.milestone.id),
        contains('fifty_sessions'),
      );
    });

    test('progress is her figure, clamped at the target for display', () {
      final summary = MilestonesSummary.from(
        catalogue: authoredMilestones,
        counts: const MilestoneCounts(sessions: 60),
      );

      final fifty = summary.standings.firstWhere(
        (s) => s.milestone.id == 'fifty_sessions',
      );
      expect(fifty.progress, 60);
      expect(fifty.shown, 50, reason: 'never "60 of 50"');
      expect(fifty.percent, 100);
    });

    test('the unearned are ordered by what is closest', () {
      final summary = MilestonesSummary.from(
        catalogue: authoredMilestones,
        counts: const MilestoneCounts(
          sessions: 23,
          countedWeeks: 14,
          personalBests: 0,
          programDays: 11,
        ),
      );

      // 23/50 = 46%, 14/20 = 70%, 11/18 = 61%. Nearest first.
      final ahead = summary.ahead
          .where(
            (s) => const [
              'twenty_counted_weeks',
              'first_program_finished',
              'fifty_sessions',
            ].contains(s.milestone.id),
          )
          .map((s) => s.milestone.id)
          .toList();

      expect(ahead, [
        'twenty_counted_weeks',
        'first_program_finished',
        'fifty_sessions',
      ]);
    });
  });
}
