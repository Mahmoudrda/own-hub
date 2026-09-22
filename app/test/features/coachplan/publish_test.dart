// P0-PLAN-03, P0-PLAN-04, P0-PUB-01, P0-PUB-02 and the life-stage gate.
//
// **Publishing is the only act that changes a plan**, and it happens from W08
// and nowhere else. Everything below is a way of asking the same question:
// after this action, did anything reach the plan that should not have?

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/client_constraints.dart';
import 'package:own_hub/domain/safety/contraindication_tag.dart';
import 'package:own_hub/domain/safety/exercise_candidate_filter.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/domain/safety/referral_registry.dart';
import 'package:own_hub/domain/safety/safety_assessment.dart';
import 'package:own_hub/features/coachplan/domain/assistant_draft_intake.dart';
import 'package:own_hub/features/coachplan/domain/meal/meal_slot_planner.dart';
import 'package:own_hub/features/coachplan/domain/plan/coach_plan_publisher.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/domain/prescription.dart';
import 'package:own_hub/features/coachplan/domain/review/review_feedback_service.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';

import 'source_scan.dart';

final DateTime _today = DateTime(2026, 9, 19);

class _RecordingGateway implements PlanPublishGateway {
  final List<PublishRequest> requests = <PublishRequest>[];

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    requests.add(request);
    // Idempotent on the key, exactly as G2's callable is: the same key twice
    // is the same version, not a second one.
    final versions = requests.map((r) => r.idempotencyKey).toSet();
    return PublishReceipt(
      version: 'v${versions.length}',
      assignmentsWritten: request.payload.length,
      mealSlotsWritten: 0,
    );
  }
}

class _FailingGateway implements PlanPublishGateway {
  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    throw StateError('the callable said no');
  }
}

PlanDraft _draft({String? effectiveFrom, Map<String, PlanDay>? days}) =>
    PlanDraft(
      clientUid: 'u1',
      coachUid: 'c1',
      month: '2026-09',
      effectiveFrom: effectiveFrom,
      days:
          days ??
          <String, PlanDay>{
            '2026-09-14': PlanDay(
              kind: PlanDayKind.workout,
              workout: DraftWorkout(title: 'Full-body', minutes: 35),
              meal: DraftMealDay(
                slots: <PlanMealSlot, MealSlotAssignment?>{
                  PlanMealSlot.breakfast:
                      const MealSlotAssignment.fromLibrary(
                        foodIds: <String>['ful_medames'],
                      ),
                },
              ),
            ),
            '2026-09-20': const PlanDay.rest(),
          },
    );

CoachPlanPublisher _publisher(
  PlanPublishGateway gateway, [
  PublishIntentQueue? queue,
]) => CoachPlanPublisher(
  gateway: gateway,
  queue: queue ?? InMemoryPublishIntentQueue(),
);

void main() {
  group('P0-PLAN-03 — publishing with gaps', () {
    test('every empty slot publishes as an explicit free choice', () async {
      final gateway = _RecordingGateway();
      final draft = _draft();

      expect(draft.unfilledMealSlots, 7, reason: '3 + 4 empty slots');

      await _publisher(gateway).publish(
        draft: draft,
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );

      final days = gateway.requests.single.payload['days']! as Map<String, Object?>;
      final monday = days['2026-09-14']! as Map<String, Object?>;
      final slots =
          (monday['meal']! as Map<String, Object?>)['slots']!
              as Map<String, Object?>;

      expect(slots['lunch'], <String, Object?>{'freeChoice': true});
      expect(slots['dinner'], <String, Object?>{'freeChoice': true});
      expect(
        slots['breakfast'],
        isA<Map<String, Object?>>().having(
          (m) => m['source'],
          'source',
          'library',
        ),
      );
      expect(
        (slots['lunch']! as Map<String, Object?>).containsKey('foodIds'),
        isFalse,
        reason: 'a free choice invents nothing to eat',
      );
    });

    test('the stored draft still shows her the gap she left', () {
      final draft = _draft();
      final forPublish = CoachPlanPublisher.withExplicitFreeChoice(draft);

      expect(forPublish.unfilledMealSlots, 0);
      expect(
        draft.unfilledMealSlots,
        7,
        reason: 'W06 tomorrow still shows the gaps, not phantom free choices',
      );
    });
  });

  group('P0-PLAN-04 — a revision never rewrites finished work', () {
    test('effectiveFrom is clamped to today', () async {
      final gateway = _RecordingGateway();
      await _publisher(gateway).publish(
        draft: _draft(effectiveFrom: '2026-09-01'),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      expect(gateway.requests.single.effectiveFrom, '2026-09-19');
    });

    test('a future date she chose is kept', () {
      expect(
        CoachPlanPublisher.clampToToday(
          requested: '2026-09-25',
          today: _today,
        ),
        '2026-09-25',
      );
    });

    test('no date at all means from today', () {
      expect(
        CoachPlanPublisher.clampToToday(requested: null, today: _today),
        '2026-09-19',
      );
    });
  });

  group('P0-PLAN-01 — publishing offline', () {
    test('the intent is queued, and three presses queue one intent', () async {
      final gateway = _RecordingGateway();
      final queue = InMemoryPublishIntentQueue();
      final publisher = _publisher(gateway, queue);
      final draft = _draft();
      final context = PublishContext(
        lifeStage: LifeStage.over1y,
        today: _today,
        online: false,
      );

      for (var press = 0; press < 3; press++) {
        final outcome = await publisher.publish(draft: draft, context: context);
        expect(outcome.isQueued, isTrue);
        expect(outcome.isFailed, isFalse, reason: 'offline is not a failure');
        expect(outcome.resultingStatus, PlanDraftStatus.draft);
      }

      expect(queue.pending, hasLength(1));
      expect(gateway.requests, isEmpty, reason: 'nothing was sent');
    });

    test('offline changes the label and says what is waiting', () {
      // W08's two offline sentences. Both were withheld while the dictionary
      // carried neither — the control was drawn with an empty label — and both
      // describe `queuedOffline` exactly: the intent is held under its
      // idempotency key and publishes once on reconnect.
      final view = coachPlanSources()['presentation/publish_view.dart']!;
      expect(view.contains('l10n.wellPublishTheMomentYoureBackOnline'), isTrue);
      expect(view.contains('l10n.waitingToSend'), isTrue);

      // Neither is the one that would be a lie: `publishPlan` offline claims
      // the plan has gone out.
      expect(
        RegExp(r'publishWhenOnline\s*=>\s*l10n\.publishPlan').hasMatch(view),
        isFalse,
      );
      // And no withheld label is left behind.
      expect(
        view.contains("_publishLabel(l10n, PublishButtonLabel.publishWhenOnline) => ''"),
        isFalse,
      );
    });

    test('the queued badge is a badge, not an error and not a spinner', () {
      final view = coachPlanSources()['presentation/publish_view.dart']!;
      expect(view.contains('CoachPlanKeys.queued'), isTrue);
      expect(view.contains('outcome?.isQueued'), isTrue);
      for (final banned in <String>[
        'CircularProgressIndicator',
        'LinearProgressIndicator',
      ]) {
        expect(
          view.contains(banned),
          isFalse,
          reason: 'offline is not a wait: $banned',
        );
      }
    });

    test('the queued intent is the request that would have been sent', () async {
      final queue = InMemoryPublishIntentQueue();
      final publisher = _publisher(_RecordingGateway(), queue);
      final draft = _draft();

      await publisher.publish(
        draft: draft,
        context: PublishContext(
          lifeStage: LifeStage.over1y,
          today: _today,
          online: false,
        ),
      );

      final online = publisher.requestFor(
        draft: draft,
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      expect(queue.pending.single.idempotencyKey, online.idempotencyKey);
      expect(
        queue.pending.single.payload.toString(),
        online.payload.toString(),
        reason: 'replaying it cannot produce a second version',
      );
    });

    test('the same content hashes the same, every time', () {
      expect(_draft().contentHash, _draft().contentHash);
      expect(
        _draft().contentHash,
        isNot(
          _draft(
            days: <String, PlanDay>{'2026-09-14': const PlanDay.rest()},
          ).contentHash,
        ),
      );
    });

    test('an error from the callable leaves the draft intact', () async {
      final outcome = await _publisher(_FailingGateway()).publish(
        draft: _draft(),
        context: PublishContext(lifeStage: LifeStage.over1y, today: _today),
      );
      expect(outcome.isFailed, isTrue);
      expect(outcome.resultingStatus, PlanDraftStatus.draft);
    });
  });

  group('the life-stage gate', () {
    Clearance clearance(bool granted) =>
        Clearance(granted: granted, recordedAt: DateTime(2026, 9, 1));

    test('clearance withheld in the first six weeks blocks publishing', () async {
      final gateway = _RecordingGateway();
      final outcome = await _publisher(gateway).publish(
        draft: _draft(),
        context: PublishContext(
          lifeStage: LifeStage.postpartum0to6w,
          clearance: clearance(false),
          today: _today,
        ),
      );

      expect(outcome.isRefused, isTrue);
      expect(outcome.refusal, PublishRefusal.clearanceWithheld);
      expect(gateway.requests, isEmpty);
    });

    test('no clearance recorded at all blocks too — unknown is not absent', () async {
      final outcome = await _publisher(_RecordingGateway()).publish(
        draft: _draft(),
        context: PublishContext(
          lifeStage: LifeStage.postpartum0to6w,
          today: _today,
        ),
      );
      expect(outcome.refusal, PublishRefusal.clearanceUnrecorded);
    });

    test('granted clearance publishes', () async {
      final outcome = await _publisher(_RecordingGateway()).publish(
        draft: _draft(),
        context: PublishContext(
          lifeStage: LifeStage.postpartum0to6w,
          clearance: clearance(true),
          today: _today,
        ),
      );
      expect(outcome.isPublished, isTrue);
    });

    test('every other life stage publishes without a clearance', () async {
      for (final stage in <LifeStage>[
        LifeStage.pregnant,
        LifeStage.postpartum6wTo1y,
        LifeStage.over1y,
        LifeStage.none,
      ]) {
        final outcome = await _publisher(_RecordingGateway()).publish(
          draft: _draft(),
          context: PublishContext(lifeStage: stage, today: _today),
        );
        expect(outcome.isPublished, isTrue, reason: stage.wireName);
      }
    });

    test('an unverified coach authors everything and publishes nothing', () async {
      final outcome = await _publisher(_RecordingGateway()).publish(
        draft: _draft(),
        context: PublishContext(
          lifeStage: LifeStage.over1y,
          today: _today,
          coachVerified: false,
        ),
      );
      expect(outcome.refusal, PublishRefusal.coachNotVerified);
    });
  });

  group('P1-RULE-20 — a referral never blocks a publish', () {
    test('an active referral publishes, and is not an error anywhere', () async {
      final assessment = SafetyAssessment(
        assessmentId: 'c1_u1__2026-09-01',
        clientUid: 'u1',
        coachUid: 'c1',
        takenAt: DateTime(2026, 9, 1),
        lifeStage: LifeStage.postpartum6wTo1y,
        screening: <ScreeningItem>[
          ScreeningItem(
            id: 'pelvic_floor',
            outcome: ScreeningOutcome.refer,
            suppresses: <ContraindicationTag>{
              ContraindicationTag.pelvicFloorLoad,
              ContraindicationTag.jumping,
              ContraindicationTag.highImpact,
            },
          ),
        ],
      );

      expect(ReferralRegistry.activeTags(assessment), isNotEmpty);

      final outcome = await _publisher(_RecordingGateway()).publish(
        draft: _draft(),
        context: PublishContext(
          lifeStage: assessment.lifeStage,
          today: _today,
        ),
      );
      expect(
        outcome.isPublished,
        isTrue,
        reason: 'refer is an outcome, not a failure',
      );

      // And the refusal enum has nothing referral-shaped to return.
      expect(
        PublishRefusal.values.map((r) => r.name),
        isNot(contains(anyOf('referral', 'referred', 'referralOutstanding'))),
      );
    });

    test('a referral suppresses moves before the picker is built', () {
      final constraints = ClientConstraintResolver.resolve(
        assessment: SafetyAssessment(
          assessmentId: 'c1_u1__2026-09-01',
          clientUid: 'u1',
          coachUid: 'c1',
          takenAt: DateTime(2026, 9, 1),
          lifeStage: LifeStage.over1y,
          screening: <ScreeningItem>[
            ScreeningItem(
              id: 'pelvic_floor',
              outcome: ScreeningOutcome.refer,
              suppresses: <ContraindicationTag>{ContraindicationTag.jumping},
            ),
          ],
        ),
        allergies: const <String>{},
        dietary: const <String>{},
      );

      final survivors = ExerciseCandidateFilter(constraints).screen(
        const <ScreenableExercise>[
          ScreenableExercise(
            exerciseId: 'glute_bridge',
            tags: <ContraindicationTag>{ContraindicationTag.none},
            quiet: true,
            floorOnly: true,
          ),
          ScreenableExercise(
            exerciseId: 'box_jump',
            tags: <ContraindicationTag>{ContraindicationTag.jumping},
            quiet: false,
            floorOnly: false,
          ),
        ],
      );

      expect(survivors.map((e) => e.exerciseId), <String>['glute_bridge']);
    });
  });

  group('P0-PUB-01 — only publishing changes a plan', () {
    test('saving feedback publishes nothing and ends at draft', () async {
      final gateway = _RecordingGateway();
      final reviews = InMemoryReviewGateway();

      final outcome = await ReviewFeedbackService(reviews).save(
        const ReviewFeedback(
          reviewId: 'r1',
          text: 'Two sessions this week, ten minutes each.',
        ),
      );

      expect(outcome.planStatus, PlanDraftStatus.draft);
      expect(reviews.savedReviewIds, <String>['r1']);
      expect(gateway.requests, isEmpty, reason: 'no callable was invoked');
    });

    test('an empty review is refused — the client always gets a reply', () {
      expect(
        () => ReviewFeedbackService(InMemoryReviewGateway()).save(
          const ReviewFeedback(reviewId: 'r1', text: '   '),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('feedback offline queues, and still publishes nothing', () async {
      final outcome = await ReviewFeedbackService(InMemoryReviewGateway()).save(
        const ReviewFeedback(reviewId: 'r1', text: 'Nice work'),
        online: false,
      );
      expect(outcome.queued, isTrue);
      expect(outcome.planStatus, PlanDraftStatus.draft);
    });

    test('unlogged days are unlogged, never skipped meals', () {
      const week = WeekReviewSummary(
        sessionsPlanned: 3,
        sessionsLogged: 3,
        mealDaysLogged: 5,
        daysInWeek: 7,
      );
      expect(week.daysNotLogged, 2);

      const missing = WeekReviewSummary.unavailable();
      expect(missing.rollupAvailable, isFalse);
      expect(
        missing.daysNotLogged,
        7,
        reason: 'a missing rollup is stated, not rendered as zeroes',
      );
    });
  });

  group('P0-PUB-02 — the assistant cannot publish', () {
    ClientConstraints constraints() => ClientConstraintResolver.resolve(
      assessment: SafetyAssessment(
        assessmentId: 'c1_u1__2026-09-01',
        clientUid: 'u1',
        coachUid: 'c1',
        takenAt: DateTime(2026, 9, 1),
        lifeStage: LifeStage.over1y,
        avoid: <ContraindicationTag>{ContraindicationTag.jumping},
      ),
      allergies: const <String>{'nuts'},
      dietary: const <String>{},
    );

    final pack = <String, Food>{
      'ful_medames': Food(
        foodId: 'ful_medames',
        names: const <String>['Ful'],
        sizes: const <FoodSize>[
          FoodSize(id: 'M', label: 'Medium', kcal: 410, proteinG: 22),
        ],
        allergens: const <String>{},
      ),
      'nut_bar': Food(
        foodId: 'nut_bar',
        names: const <String>['Nut bar'],
        sizes: const <FoodSize>[
          FoodSize(id: 'M', label: 'One', kcal: 200, proteinG: 6),
        ],
        allergens: const <String>{'nuts'},
      ),
    };

    AssistantDraftIntake intake() => AssistantDraftIntake(
      constraints: constraints(),
      catalogue: (id) => switch (id) {
        'glute_bridge' => const ScreenableExercise(
          exerciseId: 'glute_bridge',
          tags: <ContraindicationTag>{ContraindicationTag.none},
          quiet: true,
          floorOnly: true,
        ),
        'box_jump' => const ScreenableExercise(
          exerciseId: 'box_jump',
          tags: <ContraindicationTag>{ContraindicationTag.jumping},
          quiet: false,
          floorOnly: false,
        ),
        _ => null,
      },
      safety: MealSafety(
        constraints: constraints(),
        foods: (id) => pack[id],
      ),
    );

    AssistantDraft incoming({String status = 'draft'}) => AssistantDraft(
      clientUid: 'u1',
      month: '2026-09',
      status: status,
      days: <String, PlanDay>{
        '2026-09-21': PlanDay(
          kind: PlanDayKind.workout,
          workout: DraftWorkout(
            title: 'Drafted',
            minutes: 20,
            moves: <PrescribedMove>[
              PrescribedMove(
                exerciseId: 'glute_bridge',
                order: 1,
                sets: 3,
                reps: 12,
                load: const PrescribedLoad.bodyweight(),
              ),
              PrescribedMove(
                exerciseId: 'box_jump',
                order: 2,
                sets: 3,
                reps: 10,
                load: const PrescribedLoad.bodyweight(),
              ),
              PrescribedMove(
                exerciseId: 'invented_move',
                order: 3,
                sets: 3,
                reps: 10,
                load: const PrescribedLoad.bodyweight(),
              ),
            ],
          ),
          meal: DraftMealDay(
            slots: <PlanMealSlot, MealSlotAssignment?>{
              PlanMealSlot.breakfast: const MealSlotAssignment.fromLibrary(
                foodIds: <String>['ful_medames', 'nut_bar', 'invented_food'],
              ),
            },
          ),
        ),
      },
    );

    test('anything not a draft is rejected outright', () {
      expect(
        () => intake().accept(incoming(status: 'published'), coachUid: 'c1'),
        throwsA(isA<AssistantDraftNotADraft>()),
      );
    });

    test('ids outside the packs are dropped, never rendered', () {
      final report = intake().accept(incoming(), coachUid: 'c1');

      expect(report.droppedExerciseIds, contains('invented_move'));
      expect(report.droppedFoodIds, contains('invented_food'));
      expect(
        report.draft.days['2026-09-21']!.workout!.moves.map(
          (m) => m.exerciseId,
        ),
        <String>['glute_bridge'],
      );
    });

    test('constraints are re-applied on acceptance, not trusted', () {
      final report = intake().accept(incoming(), coachUid: 'c1');

      expect(
        report.droppedExerciseIds,
        contains('box_jump'),
        reason: 'her avoid list is re-run here, whatever the model believed',
      );
      expect(
        report.droppedFoodIds,
        contains('nut_bar'),
        reason: 'the allergy guard is re-run here too',
      );
      expect(
        report.draft.days['2026-09-21']!.meal!.slots[PlanMealSlot.breakfast]!
            .foodIds,
        <String>['ful_medames'],
      );
    });

    test('the accepted draft is a draft, from the assistant', () {
      final report = intake().accept(incoming(), coachUid: 'c1');
      expect(report.draft.status, PlanDraftStatus.draft);
      expect(report.draft.origin, DraftOrigin.assistant);
    });
  });
}
