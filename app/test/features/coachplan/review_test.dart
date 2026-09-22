// P0-REVIEW-01 … 03 — W09, and the button that used to do two things.
//
// OQ-10 named the defect in the mockup: one control reading "Save feedback and
// publish changes" tells a coach that answering a review publishes her
// unpublished edits. The owner split it in two. This file holds the split, and
// the three properties around it:
//
//  * the week is **read from her logs** — nothing here is a judgement, and a
//    day she did not log is *not logged*, never a failure;
//  * saving feedback publishes nothing, online or offline, and leaves the
//    published version byte-identical;
//  * a reply carries no version, so a "your plan was updated" card can only
//    ever come from a publish that actually happened.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/features/coachplan/domain/plan/coach_plan_publisher.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft_repository.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/coachplan/domain/review/review_feedback_service.dart';

import 'source_scan.dart';

final DateTime _today = DateTime(2026, 9, 19);

class _RecordingGateway implements PlanPublishGateway {
  final List<PublishRequest> requests = <PublishRequest>[];

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    requests.add(request);
    return PublishReceipt(
      version: 'v${requests.map((r) => r.idempotencyKey).toSet().length}',
      assignmentsWritten: request.payload.length,
      mealSlotsWritten: 0,
    );
  }
}

PlanDraft _draft({String title = 'Full-body'}) => PlanDraft(
  clientUid: 'u1',
  coachUid: 'c1',
  month: '2026-09',
  days: <String, PlanDay>{
    '2026-09-21': PlanDay(
      kind: PlanDayKind.workout,
      workout: DraftWorkout(
        title: title,
        minutes: 30,
        restBetweenSetsSec: 45,
        moves: <PrescribedMove>[
          const PrescribedMove(
            exerciseId: 'glute_bridge',
            order: 1,
            sets: 3,
            reps: 12,
            load: PrescribedLoad.bodyweight(),
          ),
        ],
      ),
    ),
  },
);

void main() {
  group('P0-REVIEW-01 — the week is filled from her logs', () {
    test('a day she did not log is not logged, and never a failure', () {
      const week = WeekReviewSummary(
        sessionsPlanned: 4,
        sessionsLogged: 3,
        mealDaysLogged: 5,
        daysInWeek: 7,
      );
      expect(week.daysNotLogged, 2);
      expect(week.rollupAvailable, isTrue);
    });

    test('a missing rollup is stated, not rendered as zeroes', () {
      const week = WeekReviewSummary.unavailable();
      expect(week.rollupAvailable, isFalse);
      expect(
        week.daysNotLogged,
        7,
        reason: 'nothing is known, so nothing is claimed — zeroes read as '
            'failure on the one screen where her week is described back to her',
      );
    });

    test('nothing on this screen scores her', () {
      final source = coachPlanSources()['domain/review/review_feedback_service.dart']!;
      for (final banned in <String>{
        ...kForbiddenResultFields,
        'adherence',
        'compliance',
        'score',
        'grade',
        'mealsSkipped',
        'missed',
      }) {
        expect(
          source.contains(banned),
          isFalse,
          reason: 'W09 renders counts from her own logs, never a verdict on '
              'them — found "$banned"',
        );
      }
    });

    test('the service reads nothing: it holds a gateway and no repository', () {
      final source = coachPlanSources()['domain/review/review_feedback_service.dart']!;
      expect(source.contains('Repository'), isFalse);
      expect(source.contains('PlanDraft '), isFalse);
      expect(
        source.contains('ReviewGateway'),
        isTrue,
        reason: 'W09 costs one read for the review and zero for the rollup, '
            'which W02 already loaded',
      );
    });
  });

  group('P0-REVIEW-02 — saving a review changes nothing about the plan', () {
    test('the published version is byte-identical afterwards', () async {
      final gateway = _RecordingGateway();
      final publisher = CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      );
      final draftRepo = InMemoryPlanDraftRepository();
      final draft = _draft();
      await draftRepo.save(draft);

      await publisher.publish(
        draft: draft,
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      final published = gateway.requests.single.payload.toString();
      final writesBefore = draftRepo.writes;

      final outcome = await ReviewFeedbackService(
        InMemoryReviewGateway(),
      ).save(
        const ReviewFeedback(
          reviewId: 'r_1',
          text: 'Lovely week. Keep the same weights.',
        ),
      );

      expect(outcome.planStatus, PlanDraftStatus.draft);
      expect(gateway.requests, hasLength(1));
      expect(gateway.requests.single.payload.toString(), published);
      expect(draftRepo.writes, writesBefore);
    });

    test('offline it queues through G11, and still publishes nothing', () async {
      final gateway = _RecordingGateway();
      final outcome = await ReviewFeedbackService(
        InMemoryReviewGateway(),
      ).save(
        const ReviewFeedback(reviewId: 'r_1', text: 'Saved with no signal'),
        online: false,
      );

      expect(outcome.queued, isTrue);
      expect(
        outcome.planStatus,
        PlanDraftStatus.draft,
        reason: 'queued is a badge, not a failure — and not a publish either',
      );
      expect(gateway.requests, isEmpty);
    });

    test('a review is answered with words or a voice note, never neither', () {
      expect(
        () => ReviewFeedbackService(
          InMemoryReviewGateway(),
        ).save(const ReviewFeedback(reviewId: 'r_1', text: '   ')),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('P0-REVIEW-03 — a reply is not a plan update', () {
    test('the gateway returns nothing a card could be built from', () {
      final source = coachPlanSources()['domain/review/review_feedback_service.dart']!;
      expect(
        RegExp(r'Future<void>\s+saveCoachResponse').hasMatch(source),
        isTrue,
        reason: 'no version, no assignment id, no "applied" flag — a reply '
            'with no publish behind it can produce no card',
      );
      for (final banned in <String>{'version', 'assignmentId', 'applied'}) {
        expect(source.contains(banned), isFalse, reason: banned);
      }
    });

    test('the card comes from the publish receipt, which names a real version', () async {
      final gateway = _RecordingGateway();
      final outcome = await CoachPlanPublisher(
        gateway: gateway,
        queue: InMemoryPublishIntentQueue(),
      ).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      expect(outcome.receipt!.version, 'v1');
      expect(
        gateway.requests.single.effectiveFrom,
        '2026-09-19',
        reason: 'the revision the card points at starts today, never in her '
            'finished week',
      );
    });
  });

  group('W09 offers two actions, and performs one of them', () {
    test('save feedback is always there; publish changes only when dirty', () {
      expect(
        const ReviewScreenActions.forDraft(draftIsDirty: false).actions,
        <CoachReviewAction>[CoachReviewAction.saveFeedback],
      );
      expect(
        const ReviewScreenActions.forDraft(draftIsDirty: true).actions,
        <CoachReviewAction>[
          CoachReviewAction.saveFeedback,
          CoachReviewAction.publishChanges,
        ],
      );
    });

    test('each control carries its own label, and not the retired one', () {
      // The two buttons were built first and drawn with empty labels while the
      // dictionary had one string for both acts. It now has two.
      final view = coachPlanSources()['presentation/review_view.dart']!;
      expect(view.contains('l10n.saveFeedback'), isTrue);
      expect(view.contains('l10n.publishChanges'), isTrue);

      // `saveFeedbackAndPublishChanges` is OQ-10's retired single-button copy.
      // On either of these controls it would put the defect back on the screen
      // with two buttons instead of one.
      expect(
        coachPlanSourcesVerbatim()['presentation/review_view.dart']!
            .contains('l10n.saveFeedbackAndPublishChanges'),
        isFalse,
        reason: 'the split is the label; the combined string is the defect',
      );
    });

    test('publishing is a trip to W08, never something W09 does', () {
      const actions = ReviewScreenActions.forDraft(draftIsDirty: true);
      expect(actions.publishChangesOpens, 'W08');
      expect(actions.publishesHere, isFalse);
    });

    test('and W09 could not publish even if its label said so', () {
      final source = coachPlanSources()['domain/review/review_feedback_service.dart']!;
      for (final banned in kForbiddenPublishReferences) {
        expect(
          source.contains(banned),
          isFalse,
          reason: 'the split is the label; this is the reason the label is '
              'true — found "$banned"',
        );
      }
    });
  });

  group('publishing happens from W08 and nowhere else', () {
    test('one file in this feature knows how to publish', () {
      final offenders = <String>[];
      coachPlanSources().forEach((path, source) {
        if (path == 'domain/plan/coach_plan_publisher.dart') return;
        for (final banned in kForbiddenPublishReferences) {
          if (source.contains(banned)) offenders.add('$path names $banned');
        }
      });
      expect(offenders, isEmpty);
    });

    test('and it is the only thing in the feature that holds a gateway', () {
      final offenders = <String>[];
      coachPlanSources().forEach((path, source) {
        if (path == 'domain/plan/coach_plan_publisher.dart') return;
        if (path == 'domain/review/review_feedback_service.dart') return;
        if (RegExp(r'\bGateway\b').hasMatch(source)) {
          offenders.add(path);
        }
      });
      expect(
        offenders,
        isEmpty,
        reason: "W09's is G11's review gateway, which returns void; nothing "
            'else in this feature talks to a server at all',
      );
    });
  });
}
