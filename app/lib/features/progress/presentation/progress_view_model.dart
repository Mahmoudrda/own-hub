/// What P01–P04 render, computed without a widget in sight.
///
/// `ARCHITECTURE.md` §1: *"A view model may not restate a rule, and a widget may
/// never contain one."* So nothing here decides anything. Every week state comes
/// from [WeekRollup], every tier from [TierPolicy], every level from
/// [LevelCurve], every milestone standing from [MilestoneCatalogue]. This file
/// only *arranges* those answers, which is why the whole of P01's behaviour is
/// testable without pumping a frame — step 3 of the Phase 2 build order.
///
/// ## The numbers this file refuses to produce
///
/// [ProgressSummary.standing] is computed from the ladder it is given, and the
/// ladder the app gives it is [TierLadder.unauthored] — empty, because
/// `DECISIONS.md` D6 has not authored the thresholds. So `standing.isKnown` is
/// false, [ProgressSummary.nextRungs] is empty, and P01 draws no tier name, no
/// "14 of 20" and no "about 6 weeks away".
///
/// That is not a gap left by accident; it is the requirement. A tier bar drawn
/// against an invented threshold would tell a woman she is 70% of the way to
/// something nobody has defined.
library;

import 'package:meta/meta.dart';

import '../../../domain/rewards/level_curve.dart';
import '../../../domain/rewards/tier_policy.dart';
import '../../../domain/rewards/week_rollup.dart';
import '../../../domain/rewards/weekly_goal.dart';
import '../domain/milestone.dart';
import '../domain/progress_repository.dart';

/// Everything P01 draws.
@immutable
class ProgressSummary {
  const ProgressSummary({
    required this.goal,
    required this.rewards,
    required this.standing,
    required this.ladder,
    required this.level,
    required this.pointsToNextLevel,
    this.currentWeek,
    this.milestoneCount = 0,
  });

  /// Builds the screen from her documents.
  ///
  /// Pure: the same inputs always produce the same view, and there is no clock,
  /// no date list and no day count among the parameters — so a consecutive-day
  /// tally is not computable at the one place P01's content is decided.
  factory ProgressSummary.from({
    required WeeklyGoal goal,
    required Rewards rewards,
    WeekDoc? currentWeek,
    // D14: the owner authored the ladder, so the default is the shipped one.
    // It was `unauthored` for as long as no table existed, which is why P01
    // rendered no tier to anyone.
    TierLadder ladder = TierLadder.shipped,
    Tier? previouslyEarned,
    int milestoneCount = 0,
    TierPolicy policy = const TierPolicy(),
    LevelCurve curve = const LevelCurve(),
  }) {
    return ProgressSummary(
      goal: goal,
      rewards: rewards,
      currentWeek: currentWeek,
      ladder: ladder,
      standing: policy.evaluate(
        ladder: ladder,
        countedWeeks: goal.countedWeeks,
        bestsCount: rewards.bestsCount,
        recentClosedWeeks: goal.recent8,
        previouslyEarned: previouslyEarned,
      ),
      level: curve.levelFor(rewards.points),
      pointsToNextLevel: curve.pointsToNextLevel(rewards.points),
      milestoneCount: milestoneCount,
    );
  }

  final WeeklyGoal goal;
  final Rewards rewards;

  /// This week, read live and separately because "This week, 2 of 3" must be
  /// instant. [WeeklyGoal.recent8] holds only **closed** weeks, so the current
  /// one is never in it.
  final WeekDoc? currentWeek;

  final TierStanding standing;
  final TierLadder ladder;
  final int level;
  final int pointsToNextLevel;

  /// How many milestones the catalogue holds — P02's "4 of 12" denominator, and
  /// the figure P01's tile checks itself against.
  final int milestoneCount;

  int get countedWeeks => goal.countedWeeks;
  int get bestRun => goal.bestRun;
  int get currentRun => goal.currentRun;
  int get restWeeksBanked => goal.restWeeksBanked;
  int get bestsCount => rewards.bestsCount;
  int get milestonesEarned => rewards.milestones.length;

  /// The last eight closed weeks, oldest first. Empty for a new woman, and an
  /// empty chart draws nothing rather than eight grey stubs.
  List<WeekBar> get recentWeeks => goal.recent8;

  /// Sessions logged this week. Zero before she has logged anything — the week
  /// document does not exist until the first credit.
  int get sessionsThisWeek => currentWeek?.sessionsLogged ?? 0;

  /// This week's goal. Falls back to her standing goal when no week document
  /// exists yet, which is the number the week would be created with.
  int get sessionsTarget => currentWeek?.sessionsTarget ?? goal.sessionsTarget;

  /// True when a rest week covered one of the weeks on the chart — the only
  /// condition under which "the pale one was a rest week" is a true sentence
  /// about what she is looking at.
  bool get hasRepairedWeekInWindow =>
      recentWeeks.any((b) => b.kind == WeekBarKind.repaired);

  /// The rungs above her, lowest first. **Empty while the ladder is
  /// unauthored**, which is why P01's "Next: Strong" card does not draw.
  List<TierRung> get nextRungs {
    final earned = standing.earned;
    if (earned == null) return const <TierRung>[];
    return ladder.above(earned);
  }

  /// The next rung, or null when there is none — or when none is authored.
  TierRung? get nextRung => nextRungs.isEmpty ? null : nextRungs.first;

  /// True when there is a tier to say anything at all about.
  bool get tierIsKnown => standing.isKnown;

  /// Her progress toward [rung]'s counted-week threshold, 0–100.
  ///
  /// A rung that asks for none has no bar to fill, so this is 0 and the view
  /// draws no row for it. It was 100 — a finished bar beside "0 of 0" — which
  /// told every new woman she had completed a target that does not exist.
  double percentToCountedWeeks(TierRung rung) => rung.countedWeeks <= 0
      ? 0
      : (countedWeeks / rung.countedWeeks * 100).clamp(0, 100).toDouble();

  /// Her progress toward [rung]'s personal-best threshold, 0–100. Same rule as
  /// [percentToCountedWeeks] for a rung that asks for none.
  double percentToBests(TierRung rung) => rung.bestsCount <= 0
      ? 0
      : (bestsCount / rung.bestsCount * 100).clamp(0, 100).toDouble();
}

/// Everything P02 draws.
@immutable
class MilestonesSummary {
  const MilestonesSummary({
    required this.standings,
    required this.catalogueCount,
  });

  factory MilestonesSummary.from({
    required MilestoneCatalogue catalogue,
    required MilestoneCounts counts,
    Map<String, DateTime> earnedAt = const <String, DateTime>{},
  }) {
    return MilestonesSummary(
      standings: catalogue.standings(counts: counts, earnedAt: earnedAt),
      catalogueCount: catalogue.count,
    );
  }

  final List<MilestoneStanding> standings;

  /// How many milestones exist. P02's heading claims twelve; the heading is
  /// checked against this number rather than trusted.
  final int catalogueCount;

  List<MilestoneStanding> get earned =>
      standings.where((s) => s.earned).toList();

  List<MilestoneStanding> get ahead =>
      standings.where((s) => !s.earned).toList();

  int get earnedCount => earned.length;
}
