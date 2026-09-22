/// The weekly review — **a record, never a revision.**
///
/// Two rules meet in this file and both are enforced by shape rather than by
/// care:
///
///  1. **HANDOFF 15 — saving a review never edits a published plan.** The only
///     write path is [ReviewRepository.save], which builds one document under
///     `relationships/{relId}/reviews/{yyyy-Www}`. It takes no version to
///     write, no assignment, no effective date. `planVersion` is *stamped* from
///     the version that was live at submit and is immutable afterwards.
///  2. **§2.1 — a prescribed value is never a result.** [ReviewPrefill] counts
///     sets that carry an outcome. A prescription contributes nothing, so
///     "3 of 3" cannot be inflated by a plan that asked for three.
///
/// ## Why answers freeze at submit
///
/// G11 §3.4: "a review that can be rewritten after the coach replies is not a
/// record." So [WeeklyReview] has no `copyWith` that can reach `answers`,
/// `fromLogs`, `planVersion` or `submittedAt`, and the repository refuses a
/// second save for a week that already has one. The coach's response is a
/// separate method writing a separate field.
///
/// ## The id is the week
///
/// `yyyy-Www`, from `WeekKey`. Deterministic, so submitting twice offline
/// collapses onto one document instead of creating two reviews for one week.
library;

import 'package:meta/meta.dart';

import '../../../domain/training/prescribed_set.dart';
import '../../../domain/week/week_key.dart';
import 'sharing.dart';

/// How manageable the week felt. Her answer, in her words' three shapes.
enum Manageable { easy, aboutRight, hardToFitIn }

/// What she would like changed. A closed set, because a free-text field here
/// would be a second inbox nobody reads.
enum ReviewChange { workoutTime, difficulty, meals, schedule }

/// The answers she gives. Three fields and an opt-in, and nothing that could
/// address the plan.
@immutable
class ReviewAnswers {
  const ReviewAnswers({
    required this.manageable,
    this.worked,
    this.change = const <ReviewChange>[],
    this.weightOptIn = false,
  });

  final Manageable manageable;

  /// "Morning sessions before the kids wake up." Optional, and optional means
  /// null rather than an empty string that renders as a blank quote.
  final String? worked;

  final List<ReviewChange> change;

  /// Weight and photos are **off by default and never required**. What reaches
  /// a coach when this is on is G11's open question OQ-15 and is deliberately
  /// not decided here — this flag records the opt-in and carries no figure.
  final bool weightOptIn;

  @override
  String toString() =>
      'ReviewAnswers(${manageable.name}, change: ${change.map((c) => c.name)})';
}

/// The half of the review that comes from her own logs.
///
/// Every number here is counted from something she did. `sessionsTarget` is the
/// only prescribed figure and it is labelled as the denominator, never as work.
@immutable
class ReviewFromLogs {
  const ReviewFromLogs({
    required this.sessionsDone,
    required this.sessionsTarget,
    required this.foodDaysLogged,
    this.daysUnlogged = 0,
    this.sharedKeys = const <SharingKey>[],
  });

  final int sessionsDone;
  final int sessionsTarget;
  final int foodDaysLogged;

  /// Days with no food log. Shown as **not logged**, never as meals skipped and
  /// never as a failure.
  final int daysUnlogged;

  /// What she is sharing this week, so the review can say so out loud.
  final List<SharingKey> sharedKeys;

  @override
  String toString() =>
      'ReviewFromLogs($sessionsDone/$sessionsTarget, food $foodDaysLogged)';
}

/// The coach's answer to a review.
@immutable
class CoachResponse {
  const CoachResponse({
    required this.respondedAt,
    this.body,
    this.voicePath,
    this.agreed = const <String>[],
  });

  final DateTime respondedAt;
  final String? body;

  /// A voice note's object path. **Never a transcript** — there is no field for
  /// one here and none anywhere in this feature.
  final String? voicePath;

  /// "What we agreed", as she reads it on G13.
  final List<String> agreed;

  @override
  String toString() => 'CoachResponse(${agreed.length} agreed)';
}

/// Where a review is. G11 §3.4.
enum ReviewState { due, drafted, submitted, answered }

/// `relationships/{relId}/reviews/{yyyy-Www}`.
@immutable
class WeeklyReview {
  const WeeklyReview({
    required this.weekId,
    required this.state,
    required this.dueAt,
    this.answers,
    this.fromLogs,
    this.planVersion,
    this.submittedAt,
    this.coachResponse,
  });

  /// `yyyy-Www`. The document id, and the reason a double submit is one review.
  final String weekId;

  final ReviewState state;
  final DateTime dueAt;

  /// Null until she submits.
  final ReviewAnswers? answers;
  final ReviewFromLogs? fromLogs;

  /// **Stamped at submit, immutable afterwards.** The version that was live
  /// when she answered, so the record says what she was answering about.
  final String? planVersion;

  final DateTime? submittedAt;

  final CoachResponse? coachResponse;

  bool get isSubmitted =>
      state == ReviewState.submitted || state == ReviewState.answered;

  /// The coach's reply, and only the coach's reply, may be added later.
  ///
  /// Deliberately not a general `copyWith`: this method cannot reach `answers`,
  /// `fromLogs`, `planVersion` or `submittedAt`, so there is no call that could
  /// rewrite what she said after reading what the coach said.
  WeeklyReview withCoachResponse(CoachResponse response) => WeeklyReview(
    weekId: weekId,
    state: ReviewState.answered,
    dueAt: dueAt,
    answers: answers,
    fromLogs: fromLogs,
    planVersion: planVersion,
    submittedAt: submittedAt,
    coachResponse: response,
  );

  @override
  String toString() => 'WeeklyReview($weekId ${state.name})';
}

/// Builds the prefilled half of G12 from what is already on the device.
///
/// **Reads the local cache only**, which is why the screen costs zero extra
/// reads: every number here was already fetched by Today, Train or Eat.
class ReviewPrefill {
  const ReviewPrefill();

  /// Counts logged sets, food days and nothing else.
  ///
  /// [sessions] is a list of each session's sets. A session contributes to
  /// `sessionsDone` when **any** of its sets carries an outcome — a session she
  /// started and logged one set of is a session she did, and a session where
  /// every set is still a prescription is not.
  ReviewFromLogs build({
    required List<List<LoggedSet>> sessions,
    required int sessionsTarget,
    required int daysInWindow,
    required Set<String> foodLoggedDayKeys,
    SharingSwitches sharing = SharingSwitches.off,
  }) {
    final done = sessions.where((sets) => sets.any((s) => s.isLogged)).length;
    final foodDays = foodLoggedDayKeys.length;

    return ReviewFromLogs(
      sessionsDone: done,
      sessionsTarget: sessionsTarget,
      foodDaysLogged: foodDays,
      daysUnlogged: (daysInWindow - foodDays).clamp(0, daysInWindow),
      sharedKeys: sharing.on,
    );
  }
}

/// The only write path for a review.
abstract class ReviewRepository {
  /// The review for [weekId], or null when there is none yet.
  Future<WeeklyReview?> read(String relId, String weekId);

  /// Submits her answers.
  ///
  /// [planVersion] is stamped onto the document here and can never be moved
  /// again. Throws [StateError] when a review for that week is already
  /// submitted: a review records, it never revises.
  Future<WeeklyReview> save({
    required String relId,
    required String weekId,
    required ReviewAnswers answers,
    required ReviewFromLogs fromLogs,
    required String planVersion,
    required DateTime submittedAt,
  });

  /// The coach's reply. Separate, and it can touch nothing she wrote.
  Future<WeeklyReview> respond({
    required String relId,
    required String weekId,
    required CoachResponse response,
  });
}

/// An in-memory implementation, strict about the two rules above.
class InMemoryReviewRepository implements ReviewRepository {
  InMemoryReviewRepository({Map<String, WeeklyReview>? seed})
    : _reviews = <String, WeeklyReview>{...?seed};

  final Map<String, WeeklyReview> _reviews;

  /// Every document path this repository wrote. A test asserts that submitting
  /// a review wrote exactly one path and that it was a review.
  final List<String> writes = <String>[];

  String _key(String relId, String weekId) =>
      'relationships/$relId/reviews/$weekId';

  @override
  Future<WeeklyReview?> read(String relId, String weekId) async =>
      _reviews[_key(relId, weekId)];

  @override
  Future<WeeklyReview> save({
    required String relId,
    required String weekId,
    required ReviewAnswers answers,
    required ReviewFromLogs fromLogs,
    required String planVersion,
    required DateTime submittedAt,
  }) async {
    if (WeekKey.tryParse(weekId) == null) {
      throw ArgumentError.value(
        weekId,
        'weekId',
        'A review id is an ISO week, yyyy-Www. A non-deterministic id is how '
            'one week acquires two reviews.',
      );
    }

    final path = _key(relId, weekId);
    final existing = _reviews[path];
    if (existing != null && existing.isSubmitted) {
      throw StateError(
        'The review for $weekId is already submitted. A review records; it '
        'never revises.',
      );
    }

    final review = WeeklyReview(
      weekId: weekId,
      state: ReviewState.submitted,
      dueAt: existing?.dueAt ?? submittedAt,
      answers: answers,
      fromLogs: fromLogs,
      planVersion: planVersion,
      submittedAt: submittedAt,
    );
    _reviews[path] = review;
    writes.add(path);
    return review;
  }

  @override
  Future<WeeklyReview> respond({
    required String relId,
    required String weekId,
    required CoachResponse response,
  }) async {
    final path = _key(relId, weekId);
    final existing = _reviews[path];
    if (existing == null || !existing.isSubmitted) {
      throw StateError('There is no submitted review for $weekId to answer.');
    }
    final answered = existing.withCoachResponse(response);
    _reviews[path] = answered;
    writes.add(path);
    return answered;
  }
}
