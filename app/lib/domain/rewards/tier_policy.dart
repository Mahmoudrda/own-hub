/// Tiers, on two axes — and the reason this file ships no numbers.
///
/// ## The thresholds are not authored, and this file refuses to invent them
///
/// `DECISIONS.md` D6 delegates the tier thresholds and then says the sentence
/// that governs this entire file:
///
/// > **Until written here, no tier number is authoritative.**
///
/// They have not been written there. G6 §3.2 *infers* a table from P01's and
/// T05's copy and immediately records (§9.2) that those two screens **contradict
/// each other** — P01 says Regular holds on four of the last eight weeks, T05
/// says four and three counted. An inferred table shipped as fact would put a
/// fabricated number in front of a woman on the screen that tells her how she is
/// doing, which is the defect `PHASE1-FIXES.md` records five times over.
///
/// So there is **no authored [TierLadder] anywhere in `lib/`**. [TierPolicy]
/// takes the ladder as a required parameter and has no default; the only ladder
/// this codebase constructs is [TierLadder.unauthored], which is empty. Given an
/// empty ladder the policy returns a standing with a null tier, and P01 renders
/// nothing about tiers at all — no name, no "14 of 20", no "about 6 weeks away".
/// A screen that says less is better than one that says something untrue.
///
/// `test/domain/rewards/rewards_rules_test.dart` scans `lib/` for a constructed
/// [TierRung] and fails if one appears. The day the owner writes the table into
/// `DECISIONS.md`, one constant is added and that guard is updated in the same
/// diff — a visible decision, not a quiet one.
///
/// ## Why two axes
///
/// Promotion is **cumulative**, so it is permanent. Holding is **recent**, so it
/// is losable. That is what reconciles "14 weeks counted" with "holds while four
/// of your last eight weeks count": they are different questions about different
/// windows, and one field could not answer both.
///
/// ## Rule 11 is enforced by a missing parameter
///
/// [TierPolicy.evaluate] takes counted weeks, personal bests and recent weeks.
/// **Weight is not a parameter.** Her weight, her weight lost and any social
/// count are structurally unable to influence a tier, because there is no
/// signature through which they could be passed.
library;

import 'package:meta/meta.dart';

import 'week_rollup.dart';
import 'weekly_goal.dart';

/// The five tiers, in order. The index *is* the rank, which is what makes
/// "one step down" expressible as subtraction and a two-step fall impossible.
enum Tier { firstSteps, showingUp, regular, strong, unshakeable }

/// One rung: what it takes to reach a tier, and what it takes to hold it.
@immutable
class TierRung {
  const TierRung({
    required this.tier,
    required this.countedWeeks,
    required this.bestsCount,
    required this.recencyFloor,
  });

  final Tier tier;

  /// Cumulative counted weeks needed to be promoted here.
  final int countedWeeks;

  /// Cumulative personal bests needed to be promoted here.
  final int bestsCount;

  /// Of the last [kRecentWeekWindow] closed weeks, how many must count for this
  /// tier to keep its label.
  final int recencyFloor;
}

/// The threshold table.
///
/// **Empty in this codebase.** See the library comment: D6 has not authored the
/// numbers, so nothing here does either. Tests construct their own ladders with
/// figures chosen to differ from the prototype's, which is what proves the
/// policy computes rather than recites.
@immutable
class TierLadder {
  const TierLadder(this.rungs);

  /// The ladder the product ships today: none.
  ///
  /// Not a placeholder to be filled in with plausible numbers — the absence is
  /// the feature. An unauthored ladder makes every tier surface render nothing,
  /// which is the honest state of a product whose owner has not yet decided.
  static const TierLadder unauthored = TierLadder(<TierRung>[]);

  /// The ladder the product ships, authored by the owner on 19 September 2026.
  ///
  /// `DECISIONS.md` D14: tiers come from **her gym logs and the weights she has
  /// lifted**. That is these two axes and no third — `countedWeeks` is the
  /// consistency and `bestsCount` is the progression, because a personal best
  /// IS a weight lifted. Body weight appears nowhere, and cannot: rule 11 and
  /// spine C7 forbid ranking women by weight or weight lost, and `loadKg` is
  /// "the dumbbell, and cannot be mistaken for the woman".
  ///
  /// ## Why these numbers
  ///
  /// A year of training to reach the top, which is slow on purpose — a ladder
  /// that tops out in eight weeks tells a woman who has trained for two years
  /// that there is nothing left. Promotion needs **both** axes, so neither
  /// showing up without progressing nor one heroic month gets there alone.
  ///
  /// The holding floors matter more than the thresholds. `recencyFloor` is how
  /// many of her last [kRecentWeekWindow] closed weeks must count for the label
  /// to hold, and none of them exceeds six of eight — so **a bad fortnight
  /// never costs a tier**, and a rest week repairs a missed one before it is
  /// even counted. `First steps` has a floor of zero: the first tier is not
  /// something anyone should be able to fall out of.
  ///
  /// And nothing here can demote what she earned. `TierPolicy.evaluate` takes
  /// the maximum of this and `previouslyEarned`, so a quiet season lowers the
  /// label she is shown and never the tier she reached.
  static const TierLadder shipped = TierLadder(<TierRung>[
    TierRung(
      tier: Tier.firstSteps,
      countedWeeks: 1,
      bestsCount: 0,
      recencyFloor: 0,
    ),
    TierRung(
      tier: Tier.showingUp,
      countedWeeks: 4,
      bestsCount: 0,
      recencyFloor: 2,
    ),
    TierRung(
      tier: Tier.regular,
      countedWeeks: 12,
      bestsCount: 3,
      recencyFloor: 4,
    ),
    TierRung(
      tier: Tier.strong,
      countedWeeks: 26,
      bestsCount: 8,
      recencyFloor: 5,
    ),
    TierRung(
      tier: Tier.unshakeable,
      countedWeeks: 52,
      bestsCount: 15,
      recencyFloor: 6,
    ),
  ]);

  final List<TierRung> rungs;

  /// True once someone has written the numbers down.
  bool get isAuthored => rungs.isNotEmpty;

  /// The rung for [tier], or null when the ladder does not describe it.
  TierRung? rungFor(Tier tier) {
    for (final rung in rungs) {
      if (rung.tier == tier) return rung;
    }
    return null;
  }

  /// The rungs above [tier], lowest first — P01's "Next: …" card.
  List<TierRung> above(Tier tier) =>
      (rungs.where((r) => r.tier.index > tier.index).toList()
            ..sort((a, b) => a.tier.index.compareTo(b.tier.index)))
          .toList();
}

/// Where she stands.
///
/// [earned] is monotonic and is what every unlock reads. [display] is what the
/// label says, and it is the only thing that can move downward.
@immutable
class TierStanding {
  const TierStanding({this.earned, this.display, this.slipped = false});

  /// Nothing is known, because no ladder is authored. Both tiers are null and
  /// every screen renders nothing rather than a plausible guess.
  static const TierStanding unknown = TierStanding();

  /// The highest tier she has ever reached. **Never falls.**
  final Tier? earned;

  /// The tier her label shows. At most one step below [earned].
  final Tier? display;

  /// True when [display] is below [earned] right now.
  final bool slipped;

  /// True when a ladder was authored and a tier could be computed.
  bool get isKnown => earned != null;

  @override
  bool operator ==(Object other) =>
      other is TierStanding &&
      other.earned == earned &&
      other.display == display &&
      other.slipped == slipped;

  @override
  int get hashCode => Object.hash(earned, display, slipped);

  @override
  String toString() =>
      'TierStanding(earned: ${earned?.name}, display: ${display?.name}, '
      'slipped: $slipped)';
}

/// Computes a standing. Cannot compute anything about her body.
class TierPolicy {
  const TierPolicy();

  /// Her tier, on both axes.
  ///
  /// [previouslyEarned] is the monotonic floor read back from
  /// `rewards.earnedTier`. Passing it is what makes "nothing earned is ever
  /// taken away" a property of the arithmetic: the result is the **maximum** of
  /// what she has already earned and what she qualifies for now, so a quiet
  /// period can never demote the stored tier.
  TierStanding evaluate({
    required TierLadder ladder,
    required int countedWeeks,
    required int bestsCount,
    required List<WeekBar> recentClosedWeeks,
    Tier? previouslyEarned,
  }) {
    if (!ladder.isAuthored) return TierStanding.unknown;

    // Promotion: the highest rung whose cumulative thresholds she meets.
    Tier qualified = Tier.firstSteps;
    for (final rung in ladder.rungs) {
      final meets =
          countedWeeks >= rung.countedWeeks && bestsCount >= rung.bestsCount;
      if (meets && rung.tier.index > qualified.index) qualified = rung.tier;
    }

    // Monotonic floor. max(), never assignment.
    final earned =
        (previouslyEarned != null && previouslyEarned.index > qualified.index)
        ? previouslyEarned
        : qualified;

    final display = _holds(ladder, earned, recentClosedWeeks)
        ? earned
        : _oneStepDown(earned);

    return TierStanding(
      earned: earned,
      display: display,
      slipped: display.index < earned.index,
    );
  }

  /// Whether the recency floor for [tier] is met over her recent closed weeks.
  ///
  /// Only the most recent [kRecentWeekWindow] are consulted, however many are
  /// handed in — a caller passing a longer history cannot accidentally widen the
  /// window and make a tier easier to hold than the ladder says.
  bool _holds(TierLadder ladder, Tier tier, List<WeekBar> recent) {
    final rung = ladder.rungFor(tier);
    if (rung == null) return true;
    final window = recent.length > kRecentWeekWindow
        ? recent.sublist(recent.length - kRecentWeekWindow)
        : recent;
    return window.where((b) => b.counted).length >= rung.recencyFloor;
  }

  /// One step, and there is no code path that takes two.
  ///
  /// Written as a subtraction of exactly one from the enum index, floored at
  /// [Tier.firstSteps]. A slip of two is not a case that has to be prevented; it
  /// is a value this function cannot return.
  Tier _oneStepDown(Tier tier) =>
      tier.index == 0 ? Tier.firstSteps : Tier.values[tier.index - 1];
}
