/// W09 — saving feedback **never publishes**.
///
/// OQ-10 named the defect in the mockup: one button reading "Save feedback and
/// publish changes" implies that saving feedback publishes, "which would
/// violate rule 2 the moment a coach has unpublished edits". The owner split
/// it in two — *Save feedback*, always; *Publish changes*, only when the draft
/// is dirty, and only through W08's publisher.
///
/// This service is the first half. It cannot perform the second: it does not
/// import `CoachPlanPublisher`, holds no gateway, and returns a status that is
/// `draft` by construction. `P0-PUB-01` saves feedback, saves a re-assessment
/// and accepts an assistant draft, then checks the published version is
/// byte-identical.
///
/// ## Unlogged is not skipped
///
/// `P2-ERR-W09`: days without a food log are "not logged", never counted as
/// meals skipped, and a missing rollup is **stated** rather than rendered as
/// zeroes — zeroes read as failure, and this screen is where a woman's week
/// gets described back to her.
library;

import 'package:meta/meta.dart';

import '../plan/plan_draft.dart';

/// G11's API, as this feature calls it. Implemented there; faked here.
abstract class ReviewGateway {
  /// Records the coach's answer on `relationships/{relId}/reviews/{id}`.
  ///
  /// Returns nothing a publisher could use. There is deliberately no version,
  /// no assignment id and no "applied" flag in this contract.
  Future<void> saveCoachResponse({
    required String reviewId,
    required String text,
    String? voiceNoteId,
  });
}

/// W09's primary actions — OQ-10, as the owner settled it.
///
/// One button reading "Save feedback and publish changes" is the defect: it
/// tells a coach that answering a review publishes her unpublished edits. The
/// two are separate acts and they are separate controls.
enum CoachReviewAction {
  /// Always offered. Records her answer, and publishes nothing — online or
  /// offline, dirty draft or clean one.
  saveFeedback,

  /// Offered **only** when the draft holds unpublished edits. It is a
  /// navigation to W08, which is the one screen that publishes; nothing on
  /// W09 performs a publish.
  publishChanges,
}

/// What W09 offers, and what it cannot do whatever it offers.
@immutable
class ReviewScreenActions {
  const ReviewScreenActions._(this.draftIsDirty);

  /// [draftIsDirty] is "W03 holds edits that are not in the published
  /// version". It is passed in rather than computed here, because this file
  /// may not read a draft: see the library note on what it does not import.
  const ReviewScreenActions.forDraft({required bool draftIsDirty})
    : this._(draftIsDirty);

  final bool draftIsDirty;

  /// In the order W09 shows them.
  List<CoachReviewAction> get actions => <CoachReviewAction>[
    CoachReviewAction.saveFeedback,
    if (draftIsDirty) CoachReviewAction.publishChanges,
  ];

  /// Where [CoachReviewAction.publishChanges] goes. Never a callable from
  /// here — the screen id is the whole of the behaviour.
  String get publishChangesOpens => 'W08';

  /// Always false, and named so the absence is visible in the type: no action
  /// on this screen publishes anything.
  bool get publishesHere => false;
}

/// What the coach wrote back.
@immutable
class ReviewFeedback {
  const ReviewFeedback({
    required this.reviewId,
    required this.text,
    this.voiceNoteId,
  });

  final String reviewId;
  final String text;

  /// The mic is never the only way to answer; text is always present.
  final String? voiceNoteId;

  bool get isEmpty => text.trim().isEmpty && voiceNoteId == null;
}

/// What W09 renders after saving.
@immutable
class ReviewSaveOutcome {
  const ReviewSaveOutcome({required this.queued});

  /// True when there was no signal. G8's badge, not a failure toast.
  final bool queued;

  /// Always `draft`. The type has no other value to return.
  PlanDraftStatus get planStatus => PlanDraftStatus.draft;
}

/// One week of her logs, as the coach reads it.
///
/// Every count comes from her own logs. Nothing here is a judgement, and
/// nothing is computed a second time on the coach's side — OQ-14's warning
/// about two sources and one disagreement.
@immutable
class WeekReviewSummary {
  const WeekReviewSummary({
    required this.sessionsPlanned,
    required this.sessionsLogged,
    required this.mealDaysLogged,
    required this.daysInWeek,
    this.swapsUsed = 0,
    this.rollupAvailable = true,
  });

  /// The honest empty state: nothing is zero, because nothing is known.
  const WeekReviewSummary.unavailable()
    : sessionsPlanned = 0,
      sessionsLogged = 0,
      mealDaysLogged = 0,
      daysInWeek = 7,
      swapsUsed = 0,
      rollupAvailable = false;

  final int sessionsPlanned;
  final int sessionsLogged;
  final int mealDaysLogged;
  final int daysInWeek;
  final int swapsUsed;

  /// False when G11's rollup could not be read. The screen says so.
  final bool rollupAvailable;

  /// Days with no food log. **Not logged**, never "meals skipped".
  int get daysNotLogged =>
      rollupAvailable ? daysInWeek - mealDaysLogged : daysInWeek;
}

/// Saves the coach's answer, and nothing else.
class ReviewFeedbackService {
  const ReviewFeedbackService(this.gateway);

  final ReviewGateway gateway;

  /// Records feedback. Returns `draft`, online or offline.
  ///
  /// [online] false queues through G11 and is not an error: "feedback queues
  /// with a badge. Saving it publishes nothing either online or offline."
  Future<ReviewSaveOutcome> save(
    ReviewFeedback feedback, {
    bool online = true,
  }) async {
    if (feedback.isEmpty) {
      // Marking a review answered without answering it is the one thing this
      // screen must not allow: the client always gets a reply.
      throw ArgumentError.value(
        feedback,
        'feedback',
        'A review is answered with words or a voice note, never with neither',
      );
    }

    await gateway.saveCoachResponse(
      reviewId: feedback.reviewId,
      text: feedback.text,
      voiceNoteId: feedback.voiceNoteId,
    );
    return ReviewSaveOutcome(queued: !online);
  }
}

/// A gateway that records calls, for tests and for the offline queue.
class InMemoryReviewGateway implements ReviewGateway {
  final List<String> savedReviewIds = <String>[];

  @override
  Future<void> saveCoachResponse({
    required String reviewId,
    required String text,
    String? voiceNoteId,
  }) async {
    savedReviewIds.add(reviewId);
  }
}
