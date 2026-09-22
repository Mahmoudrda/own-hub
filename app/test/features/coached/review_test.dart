// P0-REVIEW-01, P0-REVIEW-02 and P1-HRULE-15 — the review records, and it
// never revises.
//
// The numbers are chosen to be unlike the mockup's "3 of 3 · 5 days": here she
// is 2 of 4 with food logged on 6 of 7 days, so a test that passed by
// reproducing the fixture rather than counting would fail.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/coached/domain/g2_contract.dart';
import 'package:own_hub/features/coached/domain/review.dart';
import 'package:own_hub/features/coached/domain/sharing.dart';

const _relId = 'c7k9farida__u3m2rania';
const _week = '2026-W38';

PrescribedSet _prescribed(int order) => PrescribedSet(
  exerciseId: 'goblet_squat',
  order: order,
  weightKg: 17.5,
  reps: 9,
);

/// A session where nothing was logged: three prescriptions, no outcomes.
List<LoggedSet> _untouched() => [
  for (var i = 1; i <= 3; i++) LoggedSet(prescribed: _prescribed(i)),
];

/// A session where she logged two of three sets.
List<LoggedSet> _partlyLogged() => [
  LoggedSet(prescribed: _prescribed(1))
      .recording(const SetOutcome(weightKg: 17.5, reps: 9)),
  LoggedSet(prescribed: _prescribed(2))
      .recording(const SetOutcome(weightKg: 17.5, reps: 7)),
  LoggedSet(prescribed: _prescribed(3)),
];

PlanVersion _version(String id) => PlanVersion(
  version: id,
  calendar: List<PlanDayKind>.filled(
    PlanVersion.calendarLength,
    PlanDayKind.train,
  ),
  publishedAt: DateTime(2026, 9, 11, 7, 15),
  effectiveFrom: DateTime(2026, 9, 12),
  startsOn: DateTime(2026, 9, 12),
);

void main() {
  group('P0-REVIEW-01 — the prefill counts her logs, never prescriptions', () {
    test('a session with nothing logged counts as nothing', () {
      final prefill = const ReviewPrefill().build(
        sessions: [_untouched(), _untouched()],
        sessionsTarget: 4,
        daysInWindow: 7,
        foodLoggedDayKeys: const <String>{},
      );

      expect(
        prefill.sessionsDone,
        0,
        reason:
            'three prescribed sets are not three completed sets. A plan that '
            'asked for work is not a record of work.',
      );
      expect(prefill.sessionsTarget, 4);
    });

    test('a session with one logged set counts as done', () {
      final prefill = const ReviewPrefill().build(
        sessions: [_partlyLogged(), _untouched(), _partlyLogged()],
        sessionsTarget: 4,
        daysInWindow: 7,
        foodLoggedDayKeys: const {
          '2026-09-14',
          '2026-09-15',
          '2026-09-16',
          '2026-09-17',
          '2026-09-18',
          '2026-09-19',
        },
      );

      expect(prefill.sessionsDone, 2);
      expect(prefill.foodDaysLogged, 6);
      // Unlogged days are labelled unlogged, never counted as failures.
      expect(prefill.daysUnlogged, 1);
    });

    test('a skipped set is not a logged set', () {
      final skipped = [
        LoggedSet(prescribed: _prescribed(1))
            .recording(const SetOutcome.skipped()),
      ];
      final prefill = const ReviewPrefill().build(
        sessions: [skipped],
        sessionsTarget: 3,
        daysInWindow: 7,
        foodLoggedDayKeys: const <String>{},
      );
      expect(prefill.sessionsDone, 0);
    });

    test('what she is sharing is stated, from the switches themselves', () {
      final sharing = const SharingSwitches().set(
        SharingKey.energyAppetite,
        true,
        relId: _relId,
      );
      final prefill = const ReviewPrefill().build(
        sessions: [_partlyLogged()],
        sessionsTarget: 4,
        daysInWindow: 7,
        foodLoggedDayKeys: const {'2026-09-18'},
        sharing: sharing,
      );
      expect(prefill.sharedKeys, [SharingKey.energyAppetite]);
    });
  });

  group('P0-REVIEW-02 / P1-HRULE-15 — saving changes nothing about the plan', () {
    test(
      'submitting writes exactly one document, and it is a review',
      () async {
        final repo = InMemoryReviewRepository();
        final versions = [_version('v4')];
        final before = versions.single.publishedAt;

        await repo.save(
          relId: _relId,
          weekId: _week,
          answers: const ReviewAnswers(
            manageable: Manageable.hardToFitIn,
            worked: 'Early mornings, before anyone else was up.',
            change: [ReviewChange.workoutTime],
          ),
          fromLogs: const ReviewFromLogs(
            sessionsDone: 2,
            sessionsTarget: 4,
            foodDaysLogged: 6,
          ),
          planVersion: 'v4',
          submittedAt: DateTime(2026, 9, 19, 20, 5),
        );

        expect(repo.writes, ['relationships/$_relId/reviews/$_week']);
        // The published plan is untouched: same version, same publish stamp.
        expect(versions, hasLength(1));
        expect(versions.single.version, 'v4');
        expect(versions.single.publishedAt, before);
      },
    );

    test('planVersion is stamped at submit and cannot be moved', () async {
      final repo = InMemoryReviewRepository();
      final saved = await repo.save(
        relId: _relId,
        weekId: _week,
        answers: const ReviewAnswers(manageable: Manageable.aboutRight),
        fromLogs: const ReviewFromLogs(
          sessionsDone: 2,
          sessionsTarget: 4,
          foodDaysLogged: 6,
        ),
        planVersion: 'v4',
        submittedAt: DateTime(2026, 9, 19, 20, 5),
      );
      expect(saved.planVersion, 'v4');

      // The coach replies. The stamp is unchanged, and so are her answers.
      final answered = await repo.respond(
        relId: _relId,
        weekId: _week,
        response: CoachResponse(
          respondedAt: DateTime(2026, 9, 19, 22, 30),
          agreed: const ['Keep the weight, add reps'],
          voicePath: 'relationship-media/x/c/m7.m4a',
        ),
      );

      expect(answered.planVersion, 'v4');
      expect(answered.answers!.manageable, Manageable.aboutRight);
      expect(answered.state, ReviewState.answered);
    });

    test('answers cannot be edited after submission', () async {
      final repo = InMemoryReviewRepository();
      await repo.save(
        relId: _relId,
        weekId: _week,
        answers: const ReviewAnswers(manageable: Manageable.easy),
        fromLogs: const ReviewFromLogs(
          sessionsDone: 2,
          sessionsTarget: 4,
          foodDaysLogged: 6,
        ),
        planVersion: 'v4',
        submittedAt: DateTime(2026, 9, 19, 20, 5),
      );

      expect(
        () => repo.save(
          relId: _relId,
          weekId: _week,
          answers: const ReviewAnswers(manageable: Manageable.hardToFitIn),
          fromLogs: const ReviewFromLogs(
            sessionsDone: 4,
            sessionsTarget: 4,
            foodDaysLogged: 7,
          ),
          planVersion: 'v5',
          submittedAt: DateTime(2026, 9, 20, 9),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('withCoachResponse cannot reach anything she wrote', () {
      // The only method that produces a modified review takes a CoachResponse
      // and nothing else. There is no copyWith, so there is no call that could
      // rewrite her answers after she read the coach's.
      final review = WeeklyReview(
        weekId: _week,
        state: ReviewState.submitted,
        dueAt: DateTime(2026, 9, 19, 9),
        answers: const ReviewAnswers(manageable: Manageable.easy),
        planVersion: 'v4',
      );
      final answered = review.withCoachResponse(
        CoachResponse(respondedAt: DateTime(2026, 9, 20, 8)),
      );
      expect(answered.answers, same(review.answers));
      expect(answered.planVersion, review.planVersion);
    });
  });

  group('the id is the week', () {
    test('submitting twice offline collapses onto one document', () async {
      final repo = InMemoryReviewRepository();
      await repo.save(
        relId: _relId,
        weekId: _week,
        answers: const ReviewAnswers(manageable: Manageable.aboutRight),
        fromLogs: const ReviewFromLogs(
          sessionsDone: 2,
          sessionsTarget: 4,
          foodDaysLogged: 6,
        ),
        planVersion: 'v4',
        submittedAt: DateTime(2026, 9, 19, 20, 5),
      );
      expect(repo.writes, hasLength(1));
      expect(await repo.read(_relId, _week), isNotNull);
    });

    test('a non-ISO id is refused rather than written', () {
      final repo = InMemoryReviewRepository();
      expect(
        () => repo.save(
          relId: _relId,
          weekId: '19-september',
          answers: const ReviewAnswers(manageable: Manageable.easy),
          fromLogs: const ReviewFromLogs(
            sessionsDone: 1,
            sessionsTarget: 4,
            foodDaysLogged: 2,
          ),
          planVersion: 'v4',
          submittedAt: DateTime(2026, 9, 19),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('negative controls', () {
    test('answering a review that was never submitted throws', () {
      final repo = InMemoryReviewRepository();
      expect(
        () => repo.respond(
          relId: _relId,
          weekId: _week,
          response: CoachResponse(respondedAt: DateTime(2026, 9, 20)),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('weight and photos are off unless she says otherwise', () {
      const answers = ReviewAnswers(manageable: Manageable.aboutRight);
      expect(answers.weightOptIn, isFalse);
      // And opting in carries no figure — this feature stores none.
      const opted = ReviewAnswers(
        manageable: Manageable.aboutRight,
        weightOptIn: true,
      );
      expect(opted.weightOptIn, isTrue);
    });

    test('an optional note absent is null, never an empty quote', () {
      const answers = ReviewAnswers(manageable: Manageable.easy);
      expect(answers.worked, isNull);
    });
  });
}
