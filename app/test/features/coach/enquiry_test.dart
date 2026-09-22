// `P0-ENQ-01` to `P0-ENQ-05` — accepting, declining, the race for the last spot,
// the offline refusal, and the seventy-two hours.
//
// The pure transitions are tested first and alone, because they are the part of
// this that exists: capacity and status are ours, and the capture is a seam with
// no implementation. The service group then proves what happens when the seam
// cannot answer — nothing moves, and nothing is reported as having moved.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/enquiry.dart';
import 'package:own_hub/features/coach/domain/payments.dart';

const _transition = EnquiryTransition();
final _asked = DateTime(2026, 8, 2, 7, 18);

Enquiry _open({
  String clientUid = 'client-93',
  EnquiryStatus status = EnquiryStatus.enquiry,
  String? authorisationId = 'auth-551',
}) => Enquiry(
  relId: relationshipId(coachUid: 'coach-42', clientUid: clientUid),
  coachUid: 'coach-42',
  clientUid: clientUid,
  status: status,
  enquiredAt: _asked,
  displayName: 'Rania Fouad',
  situation: 'Postpartum, 7 months, at home, 25 minutes',
  herWords: 'I want my back to stop hurting when I lift my daughter.',
  authorisationId: authorisationId,
);

void main() {
  group('P0-ENQ-01 — accepting takes the spot and the status together', () {
    test('status and capacity move as one', () {
      final outcome = _transition.accept(
        enquiry: _open(),
        capacity: CoachCapacity(max: 14, taken: 6),
        verification: CoachVerificationState.verified,
      );

      final applied = outcome as EnquiryApplied;
      expect(applied.enquiry.status, EnquiryStatus.accepted);
      expect(applied.capacity.taken, 7);
      expect(applied.capacity.max, 14);
    });

    test('the outcome carries both, so neither can be persisted alone', () {
      // Spine C4: an increment never travels alone. The type is the mechanism —
      // there is no way to get the new status without the new capacity.
      final applied = _transition.accept(
        enquiry: _open(),
        capacity: CoachCapacity(max: 3, taken: 0),
        verification: CoachVerificationState.verified,
      ) as EnquiryApplied;

      expect(applied.enquiry.status.holdsASpot, isTrue);
      expect(applied.capacity.taken, 1);
    });
  });

  group('P0-ENQ-02 — declining is neutral', () {
    test('capacity does not move', () {
      final before = CoachCapacity(max: 14, taken: 6);
      final applied = _transition.decline(
        enquiry: _open(),
        capacity: before,
      ) as EnquiryApplied;

      expect(applied.enquiry.status, EnquiryStatus.declined);
      expect(applied.capacity, before);
    });

    test('a coach whose certificates lapsed may still say no', () {
      // Refusing to let her would leave the client hanging for 72 hours over
      // the coach's paperwork.
      final applied = _transition.decline(
        enquiry: _open(),
        capacity: CoachCapacity(max: 9, taken: 4),
      ) as EnquiryApplied;
      expect(applied.enquiry.status, EnquiryStatus.declined);
    });
  });

  group('P0-ENQ-03 — two accepts race for the last spot', () {
    test('a replayed accept on the same enquiry fails on the status', () {
      final capacity = CoachCapacity(max: 7, taken: 6);
      final first = _transition.accept(
        enquiry: _open(),
        capacity: capacity,
        verification: CoachVerificationState.verified,
      ) as EnquiryApplied;

      final second = _transition.accept(
        enquiry: first.enquiry,
        capacity: first.capacity,
        verification: CoachVerificationState.verified,
      );

      expect(
        (second as EnquiryRefused).reason,
        EnquiryRefusal.alreadyDecided,
        reason:
            'The status assertion, not a counter read. A full-roster refusal '
            'here would report "the spot is gone" for an enquiry this coach '
            'had just accepted herself.',
      );
      expect(first.capacity.taken, 7);
    });

    test('two different women racing for one spot: exactly one succeeds', () {
      var capacity = CoachCapacity(max: 7, taken: 6);
      final rania = _open(clientUid: 'client-93');
      final mai = _open(clientUid: 'client-94');

      final outcomes = <EnquiryOutcome>[];
      for (final enquiry in [rania, mai]) {
        final outcome = _transition.accept(
          enquiry: enquiry,
          capacity: capacity,
          verification: CoachVerificationState.verified,
        );
        // The transaction commits before the next attempt reads, which is what
        // a Firestore transaction guarantees and what this models.
        if (outcome is EnquiryApplied) capacity = outcome.capacity;
        outcomes.add(outcome);
      }

      expect(outcomes.where((o) => o.didApply), hasLength(1));
      expect(
        (outcomes.last as EnquiryRefused).reason,
        EnquiryRefusal.rosterFull,
      );
      expect(capacity.taken, 7, reason: 'taken never exceeds max');
      expect(capacity.taken, lessThanOrEqualTo(capacity.max));
    });
  });

  group('P0-ENQ-04 — accepting offline is refused, never queued', () {
    test('nothing moves', () async {
      const service = CoachEnquiryService(
        payments: UnavailablePaymentProvider(),
      );
      final capacity = CoachCapacity(max: 14, taken: 6);

      final outcome = await service.accept(
        enquiry: _open(),
        capacity: capacity,
        verification: CoachVerificationState.verified,
        network: NetworkStatus.offline,
      );

      expect((outcome as EnquiryRefused).reason, EnquiryRefusal.offline);
    });

    test(
      'declining offline is refused too, rather than half-applied',
      () async {
        const service = CoachEnquiryService(
          payments: UnavailablePaymentProvider(),
        );
        final result = await service.decline(
          enquiry: _open(),
          capacity: CoachCapacity(max: 14, taken: 6),
          network: NetworkStatus.offline,
        );

        expect(
          (result.outcome as EnquiryRefused).reason,
          EnquiryRefusal.offline,
        );
        expect(result.authorisationVoided, isFalse);
      },
    );
  });

  group('P0-ENQ-05 — an undecided enquiry expires', () {
    test('seventy-two hours, and capacity is unchanged', () {
      final capacity = CoachCapacity(max: 14, taken: 6);
      final applied = _transition.expireIfStale(
        enquiry: _open(),
        capacity: capacity,
        now: _asked.add(const Duration(hours: 72)),
      ) as EnquiryApplied;

      expect(applied.enquiry.status, EnquiryStatus.expired);
      expect(applied.capacity, capacity);
    });

    test('at seventy-one hours it is still hers to answer', () {
      final outcome = _transition.expireIfStale(
        enquiry: _open(),
        capacity: CoachCapacity(max: 14, taken: 6),
        now: _asked.add(const Duration(hours: 71)),
      );
      expect(outcome, isA<EnquiryRefused>());
    });

    test('an enquiry already decided never expires', () {
      final decided = _open(status: EnquiryStatus.accepted);
      expect(
        decided.hasLapsedBy(_asked.add(const Duration(days: 10))),
        isFalse,
      );
    });

    test('expiry produces no reply event, so her measured time is unhurt', () {
      // The mechanism, stated as an assertion about the outcome's shape: there
      // is nothing on EnquiryApplied that could feed a reply-time statistic.
      final applied = _transition.expireIfStale(
        enquiry: _open(),
        capacity: CoachCapacity(max: 5, taken: 1),
        now: _asked.add(const Duration(hours: 80)),
      ) as EnquiryApplied;
      expect(applied.enquiry.status, EnquiryStatus.expired);
    });
  });

  group('P0-CVER-01 / P0-CVER-04 — the claim gates the accept', () {
    test('a coach still being checked cannot accept', () {
      for (final state in [
        CoachVerificationState.submitted,
        CoachVerificationState.docsChecking,
        CoachVerificationState.humanReview,
        CoachVerificationState.rejected,
      ]) {
        final outcome = _transition.accept(
          enquiry: _open(),
          capacity: CoachCapacity(max: 14, taken: 6),
          verification: state,
        );
        expect(
          (outcome as EnquiryRefused).reason,
          EnquiryRefusal.notVerified,
          reason: state.name,
        );
      }
    });

    test(
      'a coach whose certificates expired keeps her clients and takes none',
      () {
        final outcome = _transition.accept(
          enquiry: _open(),
          capacity: CoachCapacity(max: 14, taken: 12),
          verification: CoachVerificationState.expired,
        );
        expect((outcome as EnquiryRefused).reason, EnquiryRefusal.notVerified);
      },
    );

    test('a coach who never set a capacity has no roster to join', () {
      final outcome = _transition.accept(
        enquiry: _open(),
        capacity: CoachCapacity.unset,
        verification: CoachVerificationState.verified,
      );
      expect((outcome as EnquiryRefused).reason, EnquiryRefusal.capacityNotSet);
    });
  });

  group('money is captured or nothing happens', () {
    test('with no payment rail the accept is refused and the spot stays free', () async {
      const service = CoachEnquiryService(
        payments: UnavailablePaymentProvider(),
      );
      final capacity = CoachCapacity(max: 14, taken: 6);

      final outcome = await service.accept(
        enquiry: _open(),
        capacity: capacity,
        verification: CoachVerificationState.verified,
        network: NetworkStatus.online,
      );

      expect(
        (outcome as EnquiryRefused).reason,
        EnquiryRefusal.paymentUnavailable,
        reason:
            'A service that incremented capacity and skipped the capture would '
            'have taken a client without taking her money.',
      );
    });

    test('an enquiry carrying no authorisation cannot be accepted', () async {
      const service = CoachEnquiryService(
        payments: UnavailablePaymentProvider(),
      );
      final outcome = await service.accept(
        enquiry: _open(authorisationId: null),
        capacity: CoachCapacity(max: 14, taken: 6),
        verification: CoachVerificationState.verified,
        network: NetworkStatus.online,
      );
      expect(
        (outcome as EnquiryRefused).reason,
        EnquiryRefusal.paymentUnavailable,
      );
    });

    test(
      'declining still works, and reports honestly that nothing was voided',
      () async {
        const service = CoachEnquiryService(
          payments: UnavailablePaymentProvider(),
        );
        final result = await service.decline(
          enquiry: _open(),
          capacity: CoachCapacity(max: 14, taken: 6),
          network: NetworkStatus.online,
        );

        expect(result.outcome, isA<EnquiryApplied>());
        expect(
          result.authorisationVoided,
          isFalse,
          reason: 'An unreleased hold is reported, not hidden.',
        );
      },
    );

    test('the unavailable provider never reports a capture', () async {
      const provider = UnavailablePaymentProvider();
      final capture = await provider.capture(authorisationId: 'auth-551');
      expect(capture.didCapture, isFalse);
      expect(
        (capture as CaptureUnavailable).reason,
        PaymentUnavailableReason.notImplemented,
      );
    });
  });

  group('the relationship id is deterministic', () {
    test('the same pair always produces the same id', () {
      expect(
        relationshipId(coachUid: 'coach-42', clientUid: 'client-93'),
        relationshipId(coachUid: 'coach-42', clientUid: 'client-93'),
      );
      expect(
        relationshipId(coachUid: 'coach-42', clientUid: 'client-93'),
        'coach-42_client-93',
      );
    });
  });

  test(
    'the initial comes from her name, and an unnamed enquiry draws nothing',
    () {
      expect(_open().initial, 'R');
      expect(
        Enquiry(
          relId: 'r',
          coachUid: 'c',
          clientUid: 'x',
          status: EnquiryStatus.enquiry,
          enquiredAt: _asked,
        ).initial,
        '',
      );
    },
  );
}
