// TierPolicy: earnedTier is monotonic, displayTier slips at most one step, and
// no ladder is authored.
//
// The ladder used below is a TEST ladder with figures chosen to be nothing like
// G6 §3.2's inferred table (6/20/40 counted weeks, 3/10/20 bests). It promotes
// at 3, 7 and 12 counted weeks. That is on purpose twice over: it proves the
// policy computes from the ladder it is given rather than from numbers baked
// into it, and it keeps an unauthored table out of the test suite where somebody
// might later mistake it for a decision.
//
// DECISIONS.md D6: "Until written here, no tier number is authoritative."

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/week/week_key.dart';

/// A ladder invented for this test and for nowhere else.
const TierLadder _testLadder = TierLadder(<TierRung>[
  TierRung(
    tier: Tier.firstSteps,
    countedWeeks: 0,
    bestsCount: 0,
    recencyFloor: 0,
  ),
  TierRung(
    tier: Tier.showingUp,
    countedWeeks: 1,
    bestsCount: 0,
    recencyFloor: 1,
  ),
  TierRung(tier: Tier.regular, countedWeeks: 3, bestsCount: 2, recencyFloor: 3),
  TierRung(tier: Tier.strong, countedWeeks: 7, bestsCount: 5, recencyFloor: 3),
  TierRung(
    tier: Tier.unshakeable,
    countedWeeks: 12,
    bestsCount: 9,
    recencyFloor: 5,
  ),
]);

List<WeekBar> _weeks({required int counted, int total = 8}) => [
  for (var i = 0; i < total; i++)
    WeekBar(
      week: WeekKey.tryParse('2026-W${(30 + i).toString().padLeft(2, '0')}')!,
      sessionsLogged: i < counted ? 2 : 0,
      sessionsTarget: 2,
      counted: i < counted,
    ),
];

void main() {
  const policy = TierPolicy();

  group('D6 — no ladder is authored, so no tier is claimed', () {
    test('the shipped ladder is empty', () {
      expect(TierLadder.unauthored.isAuthored, isFalse);
      expect(TierLadder.unauthored.rungs, isEmpty);
    });

    test(
      'an unauthored ladder yields no tier at all, however good her year is',
      () {
        final standing = policy.evaluate(
          ladder: TierLadder.unauthored,
          countedWeeks: 40,
          bestsCount: 25,
          recentClosedWeeks: _weeks(counted: 8),
        );

        expect(standing.isKnown, isFalse);
        expect(standing.earned, isNull);
        expect(standing.display, isNull);
        expect(standing.slipped, isFalse);
        expect(standing, TierStanding.unknown);
      },
    );
  });

  group('promotion is cumulative', () {
    test('she is promoted only when BOTH thresholds are met', () {
      // Seven counted weeks is Strong's week threshold, but she has four bests
      // against a requirement of five.
      final shortOnBests = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 7,
        bestsCount: 4,
        recentClosedWeeks: _weeks(counted: 6),
      );
      expect(shortOnBests.earned, Tier.regular);

      final bothMet = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 7,
        bestsCount: 5,
        recentClosedWeeks: _weeks(counted: 6),
      );
      expect(bothMet.earned, Tier.strong);
    });

    test('the thresholds come from the ladder, not from the policy', () {
      // A second ladder with different numbers must move the answer. If the
      // policy had G6's inferred table baked in, this would fail.
      const steeper = TierLadder(<TierRung>[
        TierRung(
          tier: Tier.showingUp,
          countedWeeks: 1,
          bestsCount: 0,
          recencyFloor: 0,
        ),
        TierRung(
          tier: Tier.regular,
          countedWeeks: 30,
          bestsCount: 30,
          recencyFloor: 0,
        ),
      ]);

      final onTest = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 7,
        bestsCount: 5,
        recentClosedWeeks: _weeks(counted: 6),
      );
      final onSteeper = policy.evaluate(
        ladder: steeper,
        countedWeeks: 7,
        bestsCount: 5,
        recentClosedWeeks: _weeks(counted: 6),
      );

      expect(onTest.earned, Tier.strong);
      expect(onSteeper.earned, Tier.showingUp);
    });
  });

  group('earnedTier is monotonic — nothing earned is ever taken away', () {
    test('a quiet stretch cannot demote what she has already earned', () {
      final standing = policy.evaluate(
        ladder: _testLadder,
        // Her cumulative totals would only qualify her for Showing up now…
        countedWeeks: 1,
        bestsCount: 0,
        recentClosedWeeks: _weeks(counted: 0),
        // …but she reached Strong once.
        previouslyEarned: Tier.strong,
      );

      expect(standing.earned, Tier.strong, reason: 'max(), never assignment');
    });

    test('it still rises when she qualifies for more', () {
      final standing = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 12,
        bestsCount: 9,
        recentClosedWeeks: _weeks(counted: 7),
        previouslyEarned: Tier.regular,
      );
      expect(standing.earned, Tier.unshakeable);
    });
  });

  group('displayTier slips at most one step', () {
    test('failing the recency floor drops the label by exactly one', () {
      // Unshakeable needs five of the last eight; she has one.
      final standing = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 12,
        bestsCount: 9,
        recentClosedWeeks: _weeks(counted: 1),
      );

      expect(standing.earned, Tier.unshakeable);
      expect(standing.display, Tier.strong);
      expect(standing.slipped, isTrue);
      expect(
        standing.display!.index,
        standing.earned!.index - 1,
        reason: 'the formula subtracts one; no code path subtracts two',
      );
    });

    test('a total collapse still drops only one step', () {
      // Nothing counted at all in the whole window — the worst possible recent
      // record — and the label is still exactly one rung down.
      final standing = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 12,
        bestsCount: 9,
        recentClosedWeeks: _weeks(counted: 0),
      );
      expect(standing.earned, Tier.unshakeable);
      expect(standing.display, Tier.strong);
    });

    test('the floor tier cannot slip below itself', () {
      final standing = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 0,
        bestsCount: 0,
        recentClosedWeeks: _weeks(counted: 0),
      );
      expect(standing.earned, Tier.firstSteps);
      expect(standing.display, Tier.firstSteps);
      expect(standing.slipped, isFalse);
    });

    test('one counted week brings the label back, silently', () {
      final slipped = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 7,
        bestsCount: 5,
        recentClosedWeeks: _weeks(counted: 2),
      );
      expect(slipped.slipped, isTrue);
      expect(slipped.display, Tier.regular);

      final returned = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 7,
        bestsCount: 5,
        recentClosedWeeks: _weeks(counted: 3), // Strong's floor is three
      );
      expect(returned.slipped, isFalse);
      expect(returned.display, Tier.strong);
    });

    test('no combination of inputs produces a two-step fall', () {
      // Exhaustive over the ladder and the whole range of recent records.
      for (final earned in Tier.values) {
        for (var counted = 0; counted <= 8; counted++) {
          final standing = policy.evaluate(
            ladder: _testLadder,
            countedWeeks: 0,
            bestsCount: 0,
            recentClosedWeeks: _weeks(counted: counted),
            previouslyEarned: earned,
          );
          final drop = standing.earned!.index - standing.display!.index;
          expect(
            drop,
            lessThanOrEqualTo(1),
            reason: '$earned with $counted counted weeks fell $drop steps',
          );
          expect(drop, greaterThanOrEqualTo(0));
        }
      }
    });
  });

  group('the recency window cannot be widened by the caller', () {
    test('only the most recent eight closed weeks are consulted', () {
      // Twenty weeks handed in, the first twelve all counted and the last eight
      // none. A policy that looked at everything would see twelve counted and
      // hold the tier; the window means it sees zero.
      final longHistory = [
        ..._weeks(counted: 12, total: 12),
        ..._weeks(counted: 0, total: 8),
      ];

      final standing = policy.evaluate(
        ladder: _testLadder,
        countedWeeks: 12,
        bestsCount: 9,
        recentClosedWeeks: longHistory,
      );

      expect(standing.earned, Tier.unshakeable);
      expect(standing.display, Tier.strong, reason: 'the window is the last 8');
    });
  });
}
