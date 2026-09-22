/// A training session, and what it earns her.
///
/// The credit rule here has already been got wrong once, which is why it lives
/// in a type rather than in a condition somebody has to remember.
///
/// The schema originally had two sources, `live` and `recalled`, and the rule
/// "a recalled session earns less and never sets a personal best" was written as
/// `source == recalled`. When `unplanned` was added — so that a walk or a studio
/// class had somewhere to live — that condition silently became wrong: a logged
/// walk earned *full* points and became eligible for a personal best.
///
/// So the test is **[SessionSource.live], and nothing else**. Any source added
/// in future is reduced-credit by default, and [allSourcesAreClassified] fails
/// the build if someone adds one without deciding what it earns.
library;

import 'package:meta/meta.dart';

import 'prescribed_set.dart';

/// How the session came to be recorded.
enum SessionSource {
  /// Logged as it happened, set by set. The only source that earns full credit.
  live,

  /// Trained away from the phone and entered afterwards — "I already did it".
  /// She did the work; we simply cannot vouch for the numbers.
  recalled,

  /// A walk, a class, something the plan never prescribed. Counts toward her
  /// week; carries no measured sets to set a best from.
  unplanned,
}

@immutable
class TrainingSession {
  const TrainingSession({
    required this.id,
    required this.source,
    required this.startedAt,
    this.planVersion,
    this.assignmentId,
    this.activity,
    this.completedAt,
    this.duration = Duration.zero,
    this.sets = const [],
  });

  /// Client-generated once at session start and reused on every retry, so an
  /// offline replay collides with itself instead of creating a second session
  /// (spine C1).
  final String id;

  final SessionSource source;
  final DateTime startedAt;

  /// Null for an unplanned session — there was no plan to reference.
  final String? planVersion;
  final String? assignmentId;

  /// What she did, when it was not a prescribed session: "walk", "class".
  final String? activity;

  final DateTime? completedAt;
  final Duration duration;
  final List<LoggedSet> sets;

  bool get isFinished => completedAt != null;

  /// Sets she actually logged. An unlogged set is not a zero.
  int get loggedSetCount => sets.where((s) => s.isLogged).length;

  /// Spine C8: a live session must be born with nothing logged. A recalled or
  /// unplanned session is recorded after the fact and is exempt.
  bool get satisfiesNoPrefillOnCreate =>
      source != SessionSource.live ||
      const AdherenceCalculator().hasNoPrefill(sets);
}

/// What a session earns.
///
/// Every method here keys off `source == live` rather than listing the sources
/// that earn less. That asymmetry is deliberate: the safe default for an unknown
/// source is *less*, never more.
class SessionCredit {
  const SessionCredit({this.livePoints = 30, this.reducedPoints = 15});

  final int livePoints;
  final int reducedPoints;

  /// Only a session logged as it happened earns full credit.
  bool earnsFullCredit(SessionSource source) => source == SessionSource.live;

  /// A personal best needs measured sets, logged at the time. A recalled session
  /// may be perfectly honest and still cannot establish one — and R12 says so on
  /// screen rather than quietly awarding nothing.
  bool eligibleForPersonalBest(SessionSource source) =>
      source == SessionSource.live;

  int pointsFor(SessionSource source) =>
      earnsFullCredit(source) ? livePoints : reducedPoints;

  /// Every source counts toward the week. This is the point of the rule: she did
  /// the work either way, and rule 3 counts weeks rather than judging days.
  bool countsTowardWeek(SessionSource source) => true;
}

/// Guard against a future source being added without deciding what it earns.
///
/// Called by a test rather than at runtime. If someone adds `SessionSource.trial`
/// and does not classify it here, the test fails and they have to make the
/// decision deliberately instead of inheriting whichever branch happens to run.
const Set<SessionSource> fullCreditSources = {SessionSource.live};
const Set<SessionSource> reducedCreditSources = {
  SessionSource.recalled,
  SessionSource.unplanned,
};

bool get allSourcesAreClassified => SessionSource.values
    .toSet()
    .difference(fullCreditSources.union(reducedCreditSources))
    .isEmpty;
