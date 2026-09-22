/// What earns points, and — far more importantly — what does not.
///
/// ## The absences are the design
///
/// Opening the app earns nothing. Posting earns nothing. Inviting a friend earns
/// nothing. Completing a profile earns nothing. That is not enforced by a check
/// somebody could remove: **[AwardableEvent] has no member for any of them**, so
/// there is no value a caller could construct to ask for those points and no
/// branch in [AwardTable.award] that could pay them. Adding one would mean
/// adding a type, which is a visible decision in a diff.
///
/// P02 says it out loud — *"None are secret, and none are for filling in a
/// profile"* — and this file is what makes that sentence true.
///
/// ## An increment never travels alone
///
/// Spine C4, as corrected after G6 planning: *"commutative is not idempotent."*
/// An increment applied twice adds twice, so an offline write that replays on
/// reconnect would award the points again. Every [Award] therefore carries a
/// **deterministic [Award.awardId]**, and [AwardLedger] binds the increment to
/// the creation of a document with that id. A week cannot pay twice because
/// `week:2026-W38` can be created exactly once, ever.
///
/// The ids are semantic rather than random, which is the whole mechanism:
/// `session:{sessionId}`, `best:{exerciseId}:{sessionId}`, `meal:{yyyy-MM-dd}`,
/// `week:{yyyy-Www}`, `milestone:{id}`.
///
/// ## A session that was not logged live earns less
///
/// The split is [SessionCredit]'s, reused rather than restated. It keys on
/// `source == live` and nothing else, so any source added in future is
/// reduced-credit by default — which is the exact bug `P0-LOG-12` exists for:
/// written as `== recalled`, adding `unplanned` silently promoted a logged walk
/// to full points.
library;

import 'package:meta/meta.dart';

import '../training/session.dart';
import '../week/week_key.dart';

/// Points for a personal best (G6 §1.3).
const int kPersonalBestPoints = 10;

/// Points for a day with food logged. G5's published figure; G6 §9.7 records
/// that 5 versus 10 was an open question and that G5's number was adopted.
const int kFoodDayPoints = 5;

/// Points for a week that counted. Fires at the crossing, never at the close.
const int kWeekCountedPoints = 40;

/// Points for a milestone. G6 §9.14 flags that the figure and the list of twelve
/// both still need sign-off; the list is not in this file, and this constant is
/// the only part of it the engine needs.
const int kMilestonePoints = 25;

/// The kinds of thing that can be awarded. Exactly five.
///
/// A test pins this set. If a sixth appears — `appOpened`, `invited`,
/// `profileCompleted` — the build fails and somebody has to argue for it.
enum AwardKind { session, personalBest, foodDay, weekCounted, milestone }

/// Something that happened and may be worth points.
///
/// Sealed, so [AwardTable.award] switches exhaustively: a new event cannot be
/// added without the compiler demanding that its points be decided.
@immutable
sealed class AwardableEvent {
  const AwardableEvent();
}

/// A session was logged. How it was recorded decides what it earns.
final class SessionLogged extends AwardableEvent {
  const SessionLogged({required this.sessionId, required this.source});

  final String sessionId;
  final SessionSource source;
}

/// A personal best was confirmed.
final class PersonalBestSet extends AwardableEvent {
  const PersonalBestSet({required this.exerciseId, required this.sessionId});

  final String exerciseId;
  final String sessionId;
}

/// Food was logged on a day. Once a day, keyed by the day.
///
/// G6's hook keys off the day document rather than the item count, "so there is
/// no reason for her to split a plate".
final class FoodDayLogged extends AwardableEvent {
  const FoodDayLogged({required this.dayId});

  /// `yyyy-MM-dd`.
  final String dayId;
}

/// A week crossed its goal. Unrepeatable by key.
final class WeekCounted extends AwardableEvent {
  const WeekCounted({required this.week});

  final WeekKey week;
}

/// A milestone was reached. Twelve in a lifetime.
final class MilestoneReached extends AwardableEvent {
  const MilestoneReached({required this.milestoneId});

  final String milestoneId;
}

/// One entry in the ledger.
@immutable
class Award {
  const Award({
    required this.awardId,
    required this.kind,
    required this.points,
    required this.underDailyCap,
  });

  /// Deterministic and semantic. This is the idempotency mechanism.
  final String awardId;

  final AwardKind kind;
  final int points;

  /// Whether the daily cap applies.
  ///
  /// The cap stops grinding, and a thing that happens once cannot be ground — so
  /// a counted week and a milestone sit outside it, bounded instead by the fact
  /// that their ids can only be created once.
  final bool underDailyCap;

  @override
  bool operator ==(Object other) =>
      other is Award &&
      other.awardId == awardId &&
      other.kind == kind &&
      other.points == points &&
      other.underDailyCap == underDailyCap;

  @override
  int get hashCode => Object.hash(awardId, kind, points, underDailyCap);

  @override
  String toString() => 'Award($awardId, ${kind.name}, $points pts)';
}

/// Turns an event into an award. Knows nothing about her body.
///
/// Rule 11, stated as an absence: there is no case keyed to weight, to weight
/// change, or to any social count, and no parameter through which one could be
/// supplied.
class AwardTable {
  const AwardTable({this.credit = const SessionCredit()});

  /// Reused from `domain/training/session.dart` rather than restated, so the
  /// 30/15 split has one definition in the codebase.
  final SessionCredit credit;

  Award award(AwardableEvent event) {
    return switch (event) {
      SessionLogged(:final sessionId, :final source) => Award(
        awardId: 'session:$sessionId',
        kind: AwardKind.session,
        points: credit.pointsFor(source),
        underDailyCap: true,
      ),
      PersonalBestSet(:final exerciseId, :final sessionId) => Award(
        awardId: 'best:$exerciseId:$sessionId',
        kind: AwardKind.personalBest,
        points: kPersonalBestPoints,
        underDailyCap: true,
      ),
      FoodDayLogged(:final dayId) => Award(
        awardId: 'meal:$dayId',
        kind: AwardKind.foodDay,
        points: kFoodDayPoints,
        underDailyCap: true,
      ),
      WeekCounted(:final week) => Award(
        awardId: 'week:${week.id}',
        kind: AwardKind.weekCounted,
        points: kWeekCountedPoints,
        // Unrepeatable by key, so there is nothing to grind.
        underDailyCap: false,
      ),
      MilestoneReached(:final milestoneId) => Award(
        awardId: 'milestone:$milestoneId',
        kind: AwardKind.milestone,
        points: kMilestonePoints,
        underDailyCap: false,
      ),
    };
  }
}
