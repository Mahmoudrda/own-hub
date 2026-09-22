/// Milestones — twelve in a lifetime, and none of them for filling in a profile.
///
/// P02 states the rule on screen: *"Twelve in all. None are secret, and none are
/// for filling in a profile."* Every one is tied to training, eating or coming
/// back, which is the same constraint `AwardTable` enforces by having no event
/// for opening the app or inviting a friend. [MilestoneMeasure] is the other
/// half of it: there is no member for a profile field, a follower or a login, so
/// a milestone for one of those is not a thing this type can express.
///
/// ## The list of twelve is not authored, and this file does not invent it
///
/// G6 §9.14: *"P02 names eight; I inferred four (first meal logged, 10 personal
/// bests, first rest week banked, 100 sessions). Sign-off needed on the list and
/// on 25 points each."* Inferring four and shipping them as the product's own
/// milestones would be the same defect as shipping an inferred tier ladder.
///
/// So [MilestoneCatalogue.unauthored] is empty, and the catalogue the app builds
/// holds **only the eight P02 actually names**. P02's own heading says "Twelve
/// in all" — a claim about a list that does not exist yet — so that sentence is
/// rendered only if the catalogue really holds twelve, via `statedLine`. Today
/// it holds eight and the heading does not draw. The build report carries the
/// gap; the screen does not carry a fiction.
library;

import 'package:meta/meta.dart';

/// What a milestone counts. Six measures, all of them things she did.
///
/// There is no `profileCompleted`, no `friendsInvited` and no `daysOpened`.
enum MilestoneMeasure {
  /// Sessions logged, lifetime.
  sessions,

  /// Weeks that counted, lifetime.
  countedWeeks,

  /// Personal bests set, lifetime.
  personalBests,

  /// Days with food logged, lifetime.
  foodDays,

  /// Days into the current programme — P02's "day 11 of 18".
  programDays,

  /// Coming back after a break. P02: *"It is the one we most want you to
  /// have."* Earned by returning, which is why it has no progress bar — there
  /// is nothing to be part-way through.
  cameBack,
}

/// One milestone.
@immutable
class Milestone {
  const Milestone({
    required this.id,
    required this.measure,
    required this.target,
  });

  /// A stable identifier, never a sentence. Copy lives in the dictionary and is
  /// resolved at the presentation layer.
  final String id;

  final MilestoneMeasure measure;

  /// How many of [measure] it takes. 1 for a "first ever" milestone.
  final int target;

  /// True when reaching it is a single event rather than a count to climb.
  bool get isFirstOfItsKind => target <= 1;
}

/// A milestone and where she stands against it.
@immutable
class MilestoneStanding {
  const MilestoneStanding({
    required this.milestone,
    required this.progress,
    this.earnedAt,
  });

  final Milestone milestone;

  /// Her figure for [Milestone.measure], clamped at the target for display —
  /// "23 of 50" never reads "60 of 50".
  final int progress;

  /// When it was earned, from `rewards.milestones`. Null while it is ahead.
  final DateTime? earnedAt;

  bool get earned => earnedAt != null;

  /// 0–100. Full once earned, whatever the raw count says.
  double get percent {
    if (earned) return 100;
    if (milestone.target <= 0) return 0;
    return (progress / milestone.target * 100).clamp(0, 100).toDouble();
  }

  /// The progress figure to render, never above the target.
  int get shown => progress > milestone.target ? milestone.target : progress;
}

/// Her counters, as milestones read them.
@immutable
class MilestoneCounts {
  const MilestoneCounts({
    this.sessions = 0,
    this.countedWeeks = 0,
    this.personalBests = 0,
    this.foodDays = 0,
    this.programDays = 0,
  });

  final int sessions;
  final int countedWeeks;
  final int personalBests;
  final int foodDays;

  /// Days into the current programme. Null-safe zero when she has no plan —
  /// G2 publishes no plan for a woman without one, and "day 0 of 18" is a
  /// better answer than an invented day.
  final int programDays;

  int of(MilestoneMeasure measure) => switch (measure) {
    MilestoneMeasure.sessions => sessions,
    MilestoneMeasure.countedWeeks => countedWeeks,
    MilestoneMeasure.personalBests => personalBests,
    MilestoneMeasure.foodDays => foodDays,
    MilestoneMeasure.programDays => programDays,
    // Not a count. Earned or not, and only the ledger knows.
    MilestoneMeasure.cameBack => 0,
  };
}

/// The list of milestones the product ships.
@immutable
class MilestoneCatalogue {
  const MilestoneCatalogue(this.milestones);

  /// No milestones at all. See the library comment.
  static const MilestoneCatalogue unauthored = MilestoneCatalogue(
    <Milestone>[],
  );

  final List<Milestone> milestones;

  /// How many milestones exist. P02's "Twelve in all" is checked against this
  /// rather than stated, so the sentence cannot outlive the list.
  int get count => milestones.length;

  /// Her standing on every milestone, earned first, then nearest by progress.
  ///
  /// [earnedAt] is `rewards.milestones` — the Function-written map of id to the
  /// moment it was reached. A milestone is earned because the ledger says so,
  /// never because the count happens to be high enough right now: the ledger is
  /// append-only, so an earned milestone cannot un-earn itself if a counter is
  /// ever corrected downward.
  List<MilestoneStanding> standings({
    required MilestoneCounts counts,
    Map<String, DateTime> earnedAt = const <String, DateTime>{},
  }) {
    final out = [
      for (final milestone in milestones)
        MilestoneStanding(
          milestone: milestone,
          progress: counts.of(milestone.measure),
          earnedAt: earnedAt[milestone.id],
        ),
    ];

    out.sort((a, b) {
      if (a.earned != b.earned) return a.earned ? -1 : 1;
      if (a.earned && b.earned) return a.earnedAt!.compareTo(b.earnedAt!);
      // Both ahead: the closest one first, so P02 leads with what is in reach.
      return b.percent.compareTo(a.percent);
    });

    return out;
  }
}
