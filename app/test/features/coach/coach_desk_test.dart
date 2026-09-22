// The desk — `K06`, `K07`, `K24`, `K25` — and `P0-CSCALE-01`'s read budget.
//
// Two properties matter more than the rest: the queue cap is enforced by the
// type rather than by the writer, and `K24` is chosen by the roster rather than
// reached by navigating.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_desk.dart';
import 'package:own_hub/features/coach/domain/coach_repository.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/payments.dart';

final _evening = DateTime(2026, 9, 8, 19, 30);

DeskQueueItem _item(int n, {DeskReason reason = DeskReason.checkIn}) =>
    DeskQueueItem(
      relId: 'coach-42_client-$n',
      displayName: 'Client $n',
      reason: reason,
      waitingSince: _evening.subtract(Duration(hours: n)),
    );

void main() {
  group('the queue caps at thirty, with an overflow count', () {
    test('thirty is allowed', () {
      final desk = CoachDesk(
        queue: [for (var i = 1; i <= 30; i++) _item(i)],
        overflowCount: 0,
      );
      expect(desk.queue, hasLength(30));
    });

    test('thirty-one is a Cloud Function bug and fails loudly', () {
      expect(
        () => CoachDesk(queue: [for (var i = 1; i <= 31; i++) _item(i)]),
        throwsArgumentError,
        reason:
            'Truncating silently would hide the one thing the cap guarantees.',
      );
    });

    test('everyone past the cap is a number', () {
      final desk = CoachDesk(
        queue: [for (var i = 1; i <= 30; i++) _item(i)],
        overflowCount: 170,
      );
      expect(desk.waitingCount, 200);
      expect(desk.queue, hasLength(30));
    });

    test('a negative overflow is refused', () {
      expect(() => CoachDesk(overflowCount: -1), throwsArgumentError);
    });
  });

  group('oldest first, decided by the desk and not by the screen', () {
    test('the queue sorts itself', () {
      final desk = CoachDesk(queue: [_item(2), _item(9), _item(5)]);
      expect(desk.queue.map((i) => i.displayName).toList(), [
        'Client 9',
        'Client 5',
        'Client 2',
      ]);
      expect(desk.oldestWaitingSince, desk.queue.first.waitingSince);
    });

    test('an empty queue has no oldest', () {
      expect(CoachDesk().oldestWaitingSince, isNull);
      expect(CoachDesk().waitingCount, 0);
    });

    test('enquiries are findable without a second pass over the roster', () {
      final desk = CoachDesk(
        queue: [
          _item(1),
          _item(2, reason: DeskReason.newEnquiry),
          _item(3, reason: DeskReason.reviewDue),
        ],
      );
      expect(desk.enquiries, hasLength(1));
      expect(desk.enquiries.single.reason, DeskReason.newEnquiry);
    });

    test('a row draws its initial from the name it carries', () {
      expect(_item(4).initial, 'C');
      expect(
        DeskQueueItem(
          relId: 'r',
          displayName: '',
          reason: DeskReason.message,
          waitingSince: _evening,
        ).initial,
        '',
      );
    });
  });

  group('P0-CDAY-01 — K24 is a branch of K07, chosen by the roster', () {
    CoachDesk deskIn(CoachVerificationState state) =>
        CoachDesk(verification: state);

    test('an empty roster and a pending check draws the amber card', () {
      final state = CoachToday.resolve(
        desk: deskIn(CoachVerificationState.humanReview),
        capacity: CoachCapacity(max: 14),
      );
      expect(state, CoachTodayState.dayOneUnverified);
      expect(state.isDayOne, isTrue);
      expect(state.showsVerificationCard, isTrue);
    });

    test('an empty roster and a cleared coach draws it without the card', () {
      final state = CoachToday.resolve(
        desk: deskIn(CoachVerificationState.verified),
        capacity: CoachCapacity(max: 14),
      );
      expect(state, CoachTodayState.dayOneVerified);
      expect(state.isDayOne, isTrue);
      expect(state.showsVerificationCard, isFalse);
    });

    test(
      'accepting a first client flips the same route, with no navigation',
      () {
        final desk = deskIn(CoachVerificationState.verified);
        var capacity = CoachCapacity(max: 14);
        expect(
          CoachToday.resolve(desk: desk, capacity: capacity),
          CoachTodayState.dayOneVerified,
        );

        capacity = capacity.withOneMoreTaken()!;
        expect(
          CoachToday.resolve(desk: desk, capacity: capacity),
          CoachTodayState.working,
        );
      },
    );

    test('a quiet evening for a busy coach is not day one', () {
      // The branch reads the roster, not the queue. Branching on an empty queue
      // would show the day-one screen the moment she caught up.
      final state = CoachToday.resolve(
        desk: CoachDesk(verification: CoachVerificationState.verified),
        capacity: CoachCapacity(max: 14, taken: 11),
      );
      expect(state, CoachTodayState.working);
      expect(state.isDayOne, isFalse);
    });
  });

  group('K25 — four steps, and nothing that can fail', () {
    test('there is no failed state to construct', () {
      expect(CoachStepState.values, hasLength(3));
      expect(CoachStepState.values.map((s) => s.name).toList(), [
        'done',
        'now',
        'waiting',
      ]);
    });

    test('the first unfinished step is the current one', () {
      const week = CoachFirstWeek(
        completed: {
          CoachFirstWeekStep.publishPage,
          CoachFirstWeekStep.saveSplit,
        },
      );

      expect(week.doneCount, 2);
      expect(week.stepCount, 4);
      expect(week.isComplete, isFalse);
      expect(week.stateOf(CoachFirstWeekStep.publishPage), CoachStepState.done);
      expect(
        week.stateOf(CoachFirstWeekStep.setUpAssessment),
        CoachStepState.now,
      );
      expect(
        week.stateOf(CoachFirstWeekStep.answerEnquiry),
        CoachStepState.waiting,
      );
    });

    test('a step never un-completes', () {
      var week = const CoachFirstWeek();
      week = week.withStep(CoachFirstWeekStep.saveSplit);
      week = week.withStep(CoachFirstWeekStep.saveSplit);
      expect(week.doneCount, 1);
    });

    test('finishing all four completes it, and nothing expires', () {
      var week = const CoachFirstWeek();
      for (final step in CoachFirstWeekStep.values) {
        week = week.withStep(step);
      }
      expect(week.isComplete, isTrue);
      expect(
        week.stateOf(CoachFirstWeekStep.answerEnquiry),
        CoachStepState.done,
      );
    });

    test('the cleared-certificates card is off the public root', () {
      const week = CoachFirstWeek();
      expect(week.certificatesCleared, isFalse);
      expect(week.withCertificatesCleared().certificatesCleared, isTrue);
    });
  });

  group('the desk carries money only when the seam can supply it', () {
    test('a fresh desk reports earnings as unavailable, not as zero', () {
      final desk = CoachDesk();
      expect(desk.earnings, isA<EarningsUnavailable>());
      expect(desk.earnings.statementOrNull, isNull);
    });
  });

  group('P0-CSCALE-01 — opening Today costs two document reads', () {
    for (final roster in [0, 12, 60]) {
      test('at $roster clients', () async {
        final repository = InMemoryCoachRepository(
          profile: InMemoryCoachRepository.working().copyWith(
            capacity: CoachCapacity(max: 60, taken: roster),
          ),
          desk: CoachDesk(
            queue: [
              for (var i = 1; i <= (roster > 30 ? 30 : roster); i++) _item(i),
            ],
            overflowCount: roster > 30 ? roster - 30 : 0,
            verification: CoachVerificationState.verified,
          ),
        );
        repository.resetReadCount();

        // Exactly what the screen does on open: one profile, one desk.
        final profile = repository.profile;
        final desk = repository.desk;
        CoachToday.resolve(desk: desk, capacity: profile.capacity);

        expect(
          repository.documentReads,
          2,
          reason:
              'Reads on K07 are constant at two, independent of roster size. '
              'A per-client read here is the unbounded scan the scalability '
              'gate exists to catch.',
        );
      });
    }

    test('a forty-item queue is a cap violation, not a slow screen', () {
      expect(
        () => CoachDesk(queue: [for (var i = 1; i <= 40; i++) _item(i)]),
        throwsArgumentError,
      );
    });
  });
}
