import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_local_store.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/payment_text.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';

void main() {
  test('egpText writes piasters and drops .00', () {
    expect(egpText(AppL10nEn(), 50037), '500.37 EGP');
    expect(egpText(AppL10nEn(), 50000), '500 EGP');
    expect(egpText(AppL10nAr(), 50005), '500.05 جنيه');
    expect(egpPlain(50037), '500.37');
  });

  test('Payment.fromMap reads the fields the server writes', () {
    final p = Payment.fromMap('p1', {
      'status': 'proof_submitted',
      'clientUid': 'c',
      'coachUid': 'k',
      'subId': 's',
      'amountPiasters': 50037,
      'reference': 'OH-4821',
      'addressSnapshot': {'address': 'a@instapay', 'accountName': 'Rahma M.'},
      'outcome': 'amber',
      'hint': 'needDetails',
      'access': {'state': 'provisional', 'until': '2026-10-30T10:00:00+00:00'},
      'proof': {'txnNumber': '123456789012'},
      'dispute': {'kind': 'not_received'},
      'coachDecision': {'differentAmountPiasters': 30000, 'acceptLower': true},
      'coachReport': {'txnNumber': '999999999999', 'clientAnswer': null},
      'lateUntil': '2026-11-03T10:00:00+00:00',
    })!;
    expect(p.status, PaymentStatus.proofSubmitted);
    expect(p.subId, 's');
    expect(p.amountPiasters, 50037);
    expect(p.address.accountName, 'Rahma M.');
    expect(p.outcome, RiskOutcome.amber);
    expect(p.hint, 'needDetails');
    expect(p.accessUntil, DateTime.utc(2026, 10, 30, 10));
    expect(p.txnNumber, '123456789012');
    expect(p.disputeKind, 'not_received');
    expect(p.acceptLower, isTrue);
    expect(p.differentAmountPiasters, 30000);
    expect(p.coachReportAnswered, isFalse);
    expect(p.lateUntil, DateTime.utc(2026, 11, 3, 10));
  });

  test('an unknown status is not a payment', () {
    expect(Payment.fromMap('p', {'status': 'zzz'}), isNull);
    expect(Payment.fromMap('', {'status': 'confirmed'}), isNull);
    expect(Payment.fromMap('p', 'not a map'), isNull);
  });

  test('only confirmed and resolved_paid activate a package', () {
    final on = PaymentStatus.values.where((s) => s.activatesPackage).toList();
    expect(on, [PaymentStatus.confirmed, PaymentStatus.resolvedPaid]);
  });

  test('every status wire value round-trips', () {
    for (final s in PaymentStatus.values) {
      expect(PaymentStatus.fromWire(s.wire), s);
    }
  });

  test('timeLeft is zero once past', () {
    final now = DateTime.utc(2026, 10, 27, 12);
    final p = Payment(
      id: 'p',
      clientUid: 'c',
      coachUid: 'k',
      status: PaymentStatus.awaitingPayment,
      expiresAt: now.subtract(const Duration(minutes: 1)),
    );
    expect(p.timeLeft(now), Duration.zero);
  });

  test('a late proof is accepted until lateUntil, then not', () {
    final now = DateTime.utc(2026, 10, 27, 12);
    Payment at(DateTime late, PaymentStatus s) => Payment(
      id: 'p',
      clientUid: 'c',
      coachUid: 'k',
      status: s,
      lateUntil: late,
    );
    expect(
      at(
        now.add(const Duration(days: 1)),
        PaymentStatus.expired,
      ).canSendProof(now),
      isTrue,
    );
    expect(
      at(
        now.subtract(const Duration(minutes: 1)),
        PaymentStatus.expired,
      ).canSendProof(now),
      isFalse,
    );
    expect(
      at(
        now.add(const Duration(days: 1)),
        PaymentStatus.proofSubmitted,
      ).canSendProof(now),
      isFalse,
    );
  });

  test('the coach asks only before any proof and until the client answers', () {
    Payment with_(PaymentStatus s, String txn, bool answered) => Payment(
      id: 'p',
      clientUid: 'c',
      coachUid: 'k',
      status: s,
      coachReportTxn: txn,
      coachReportAnswered: answered,
    );
    expect(
      with_(PaymentStatus.awaitingPayment, '123', false).coachAsks,
      isTrue,
    );
    expect(with_(PaymentStatus.expired, '123', false).coachAsks, isTrue);
    expect(
      with_(PaymentStatus.awaitingPayment, '123', true).coachAsks,
      isFalse,
    );
    expect(
      with_(PaymentStatus.proofSubmitted, '123', false).coachAsks,
      isFalse,
    );
    expect(with_(PaymentStatus.awaitingPayment, '', false).coachAsks, isFalse);
  });

  test('inProgress is everything past waiting that is not over', () {
    final inProgress = PaymentStatus.values
        .where((s) => !s.unpaid && !s.dead)
        .map((s) => s.wire)
        .toSet();
    expect(inProgress.contains('proof_submitted'), isTrue);
    expect(inProgress.contains('awaiting_payment'), isFalse);
    expect(inProgress.contains('cancelled'), isFalse);
    expect(inProgress.contains('resolved_unpaid'), isFalse);
  });

  test('the coach address reads a pending change and knows when it is due', () {
    final a = CoachAddress.fromMap({
      'address': 'old@instapay',
      'accountName': 'Rahma M.',
      'pending': {
        'address': 'new@instapay',
        'accountName': 'Rahma M.',
        'effectiveAt': '2026-10-28T10:00:00+00:00',
      },
    })!;
    expect(a.pendingAt(DateTime.utc(2026, 10, 27, 12)), isTrue);
    expect(a.pendingAt(DateTime.utc(2026, 10, 28, 11)), isFalse);
    expect(CoachAddress.fromMap('x'), isNull);
  });

  test('a timeline event reads the fields the server writes', () {
    final e = PaymentEvent.fromMap({
      'at': '2026-10-27T10:00:00+00:00',
      'from': null,
      'to': 'awaiting_payment',
      'role': 'client',
      'code': 'created',
    });
    expect(e.to, 'awaiting_payment');
    expect(e.from, '');
    expect(e.code, 'created');
  });

  test('a payment reads the proof, decision, dispute and refund fields', () {
    final p = Payment.fromMap('p1', {
      'status': 'in_review',
      'proof': {
        'txnNumber': '123456789012',
        'screenshotPaths': ['payment-proofs/p1/client-ab-1.jpg', 7, 'x.jpg'],
        'screenshotCount': 2,
        'imageFlags': ['sameImage', 'txnReused'],
        'paidAtClaimed': '2026-10-27T11:30:00+00:00',
      },
      'coachDecision': {
        'reasonCode': 'not_seen',
        'statementPaths': ['payment-proofs/p1/coach-cd-1.jpg'],
        'receivedPiasters': 50037,
        'autoConfirmed': true,
      },
      'dispute': {'kind': 'not_received', 'reasonCode': 'not_seen'},
      'refund': {
        'requestedAt': '2026-10-27T10:00:00+00:00',
        'coachDueAt': '2026-10-30T10:00:00+00:00',
      },
    })!;
    expect(p.screenshotPaths, ['payment-proofs/p1/client-ab-1.jpg', 'x.jpg']);
    expect(p.imageFlags, ['sameImage', 'txnReused']);
    expect(p.paidAtClaimed, DateTime.utc(2026, 10, 27, 11, 30));
    expect(p.statementPaths, ['payment-proofs/p1/coach-cd-1.jpg']);
    expect(p.receivedPiasters, 50037);
    expect(p.autoConfirmed, isTrue);
    expect(p.disputeReasonCode, 'not_seen');
    expect(p.notReceivedReason, 'not_seen');
    expect(p.refundCoachDueAt, DateTime.utc(2026, 10, 30, 10));
  });

  test('a payment without those fields reads them as empty, not zero', () {
    final p = Payment.fromMap('p1', {
      'status': 'awaiting_payment',
      'proof': {'screenshotPaths': [], 'imageFlags': [], 'paidAtClaimed': null},
      'coachDecision': null,
    })!;
    expect(p.screenshotPaths, isEmpty);
    expect(p.imageFlags, isEmpty);
    expect(p.paidAtClaimed, isNull);
    expect(p.statementPaths, isEmpty);
    expect(p.receivedPiasters, isNull);
    expect(p.autoConfirmed, isFalse);
    expect(p.disputeReasonCode, '');
    expect(p.refundCoachDueAt, isNull);
  });

  test('an auto-confirmed payment can be flagged for 48 hours, no longer', () {
    const window = Duration(hours: 48);
    final at = DateTime.utc(2026, 10, 27, 12);
    Payment confirmed({bool auto = true, PaymentStatus? status}) => Payment(
      id: 'p',
      clientUid: 'c',
      coachUid: 'k',
      status: status ?? PaymentStatus.confirmed,
      autoConfirmed: auto,
      confirmedAt: at,
    );
    expect(
      confirmed().canFlagAutoConfirmed(
        at.add(const Duration(hours: 47)),
        window,
      ),
      isTrue,
    );
    expect(confirmed().canFlagAutoConfirmed(at.add(window), window), isTrue);
    expect(
      confirmed().canFlagAutoConfirmed(
        at.add(const Duration(hours: 49)),
        window,
      ),
      isFalse,
    );
    expect(confirmed(auto: false).canFlagAutoConfirmed(at, window), isFalse);
    expect(
      confirmed(status: PaymentStatus.inReview)
          .canFlagAutoConfirmed(at, window),
      isFalse,
    );
    expect(
      const Payment(
        id: 'p',
        clientUid: 'c',
        coachUid: 'k',
        status: PaymentStatus.confirmed,
        autoConfirmed: true,
      ).canFlagAutoConfirmed(at, window),
      isFalse,
    );
  });

  test('the coach address reads auto-confirm and the clean count', () {
    final a = CoachAddress.fromMap({
      'address': 'a@instapay',
      'accountName': 'Rahma M.',
      'cleanConfirmed': 3,
      'autoConfirmGreen': true,
    })!;
    expect(a.autoConfirmGreen, isTrue);
    expect(a.cleanConfirmed, 3);
    final fresh = CoachAddress.fromMap({'address': 'a@instapay'})!;
    expect(fresh.autoConfirmGreen, isFalse);
    expect(fresh.cleanConfirmed, 0);
  });

  test('fee statements read the server fields', () {
    final s = FeeStatement.fromMap('k__2026-10', {
      'year': 2026,
      'month': 10,
      'status': 'paid_claimed',
      'totalDuePiasters': 12345,
      'disputedPiasters': 600,
      'claimedTxn': '555566667777',
      'dueAt': '2026-11-30T10:00:00+00:00',
      'paidAt': '2026-11-02T09:00:00+00:00',
      'payTo': {'address': 'ownhub@instapay', 'holderName': 'Own Hub'},
      'lines': [
        {
          'paymentId': 'p1',
          'reference': 'OH-4821',
          'basePiasters': 50000,
          'feePiasters': 7500,
          'feeState': 'owed',
          'owedAt': '2026-10-05T10:00:00+00:00',
        },
        {'paymentId': 'p2'},
      ],
    })!;
    expect(s.totalDuePiasters, 12345);
    expect(s.disputedPiasters, 600);
    expect(s.paymentCount, 2);
    expect(s.paid, isFalse);
    expect(s.claimedTxn, '555566667777');
    expect(s.paidAt, DateTime.utc(2026, 11, 2, 9));
    expect(s.payTo.address, 'ownhub@instapay');
    expect(s.payTo.holderName, 'Own Hub');
    expect(s.lines.first.reference, 'OH-4821');
    expect(s.lines.first.basePiasters, 50000);
    expect(s.lines.first.feePiasters, 7500);
    expect(s.lines.first.feeState, 'owed');
    expect(s.lines.first.owedAt, DateTime.utc(2026, 10, 5, 10));
    expect(s.lines.last.paymentId, 'p2');
    expect(s.lines.last.feeState, '');
  });

  test(
    'a statement made before the owner set the pay-to reads it as empty',
    () {
      final s = FeeStatement.fromMap('k__2026-10', {
        'status': 'open',
        'payTo': {'address': null, 'holderName': null},
        'lines': [],
      })!;
      expect(s.payTo.address, '');
      expect(s.payTo.holderName, '');
      expect(s.claimedTxn, '');
      expect(s.paidAt, isNull);
      expect(
        FeeStatement.fromMap('k__2026-10', {'status': 'open'})!.payTo.address,
        '',
      );
    },
  );

  test('newKey is 24 hex and different each time', () {
    final a = PaymentsLocalStore.newKey();
    final b = PaymentsLocalStore.newKey();
    expect(a, matches(RegExp(r'^[0-9a-f]{24}$')));
    expect(a, isNot(b));
  });

  group('what she may do from PAY3', () {
    final start = DateTime.utc(2026, 10, 1, 12);
    Payment paid({
      PaymentStatus status = PaymentStatus.confirmed,
      DateTime? confirmedAt,
      DateTime? decided,
      DateTime? statusAt,
      DateTime? asked,
      DateTime? recorded,
      List<String> kinds = const <String>[],
    }) => Payment(
      id: 'p',
      clientUid: 'c',
      coachUid: 'k',
      status: status,
      confirmedAt: confirmedAt,
      disputeDecidedAt: decided,
      statusAt: statusAt,
      refundRequestedAt: asked,
      refundRecordedAt: recorded,
      disputeKinds: kinds,
    );

    test(
      'a payment reads when it changed, staff decided and what she raised',
      () {
        final p = Payment.fromMap('p1', {
          'status': 'resolved_paid',
          'statusAt': '2026-10-27T10:00:00+00:00',
          'dispute': {'decidedAt': '2026-10-26T09:00:00+00:00'},
          'disputeKinds': ['service', 3, 'refund'],
        })!;
        expect(p.statusAt, DateTime.utc(2026, 10, 27, 10));
        expect(p.disputeDecidedAt, DateTime.utc(2026, 10, 26, 9));
        expect(p.disputeKinds, ['service', 'refund']);
        expect(
          Payment.fromMap('p1', {'status': 'confirmed'})!.disputeKinds,
          isEmpty,
        );
      },
    );

    test('a refund staff ordered reads the amount and the day it is due', () {
      final p = Payment.fromMap('p1', {
        'status': 'in_review',
        'dispute': {
          'staffDecision': 'refund_owed',
          'refundOwedPiasters': 20000,
          'refundDueAt': '2026-11-03T09:00:00+00:00',
        },
      })!;
      expect(p.disputeStaffDecision, 'refund_owed');
      expect(p.refundOwedPiasters, 20000);
      expect(p.refundOwedDueAt, DateTime.utc(2026, 11, 3, 9));
      expect(p.refundOwed, isTrue);
      final bare = Payment.fromMap('p1', {'status': 'in_review'})!;
      expect(bare.refundOwed, isFalse);
      expect(bare.refundOwedPiasters, 0);
      expect(bare.refundOwedDueAt, isNull);
    });

    test('a refund is owed only while the review stands and names a sum', () {
      Payment of(String status, Object? piasters, [String? decision]) =>
          Payment.fromMap('p1', {
            'status': status,
            'dispute': {
              'staffDecision': decision ?? 'refund_owed',
              'refundOwedPiasters': piasters,
            },
          })!;
      expect(of('in_review', 100).refundOwed, isTrue);
      expect(of('refunded', 100).refundOwed, isFalse);
      expect(of('in_review', 0).refundOwed, isFalse);
      expect(of('in_review', 100, 'no_refund').refundOwed, isFalse);
    });

    test('the refund window is the 14 days after access began', () {
      bool open(Payment p, int day, [int hours = 0]) =>
          p.refundWindowOpen(start.add(Duration(days: day, hours: hours)));
      final p = paid(confirmedAt: start);
      expect(open(p, 13), isTrue);
      expect(open(p, 14), isTrue, reason: 'the server refuses only after');
      expect(open(p, 14, 1), isFalse);
      expect(open(p, 15), isFalse);
    });

    test(
      'access began at the confirmation, else staff decided, else it changed',
      () {
        final later = start.add(const Duration(days: 30));
        final day20 = start.add(const Duration(days: 20));
        expect(
          paid(
            confirmedAt: later,
            decided: start,
            statusAt: start,
          ).accessStartedAt,
          later,
        );
        expect(paid(decided: later, statusAt: start).accessStartedAt, later);
        expect(paid(statusAt: later).accessStartedAt, later);
        expect(
          paid(
            status: PaymentStatus.resolvedPaid,
            decided: day20,
          ).refundWindowOpen(day20.add(const Duration(days: 13))),
          isTrue,
        );
      },
    );

    test('no start time on the document leaves it to the server', () {
      expect(paid().refundWindowOpen(start), isTrue);
    });

    test('only a payment that stands, not yet asked, can ask for a refund', () {
      final now = start.add(const Duration(days: 2));
      expect(paid(confirmedAt: start).refundWindowOpen(now), isTrue);
      expect(
        paid(
          status: PaymentStatus.resolvedPaid,
          confirmedAt: start,
        ).refundWindowOpen(now),
        isTrue,
      );
      expect(
        paid(confirmedAt: start, asked: now).refundWindowOpen(now),
        isFalse,
      );
      for (final s in PaymentStatus.values.where((s) => !s.activatesPackage)) {
        expect(
          paid(status: s, confirmedAt: start).refundWindowOpen(now),
          isFalse,
          reason: s.wire,
        );
      }
    });

    test('the dispute she may open follows the status', () {
      final now = start.add(const Duration(days: 2));
      expect(paid().disputeToOpen(now), DisputeKind.service);
      expect(
        paid(status: PaymentStatus.resolvedPaid).disputeToOpen(now),
        DisputeKind.service,
      );
      expect(
        paid(status: PaymentStatus.refundDenied).disputeToOpen(now),
        DisputeKind.refund,
      );
      expect(
        paid(
          status: PaymentStatus.refunded,
          recorded: start,
        ).disputeToOpen(now),
        DisputeKind.refundNotReceived,
      );
      for (final s in [
        PaymentStatus.awaitingPayment,
        PaymentStatus.proofSubmitted,
        PaymentStatus.expired,
        PaymentStatus.cancelled,
        PaymentStatus.coachNotReceived,
        PaymentStatus.inReview,
        PaymentStatus.resolvedUnpaid,
        PaymentStatus.differentAmount,
        PaymentStatus.refundRequested,
        PaymentStatus.serviceDispute,
      ]) {
        expect(paid(status: s).disputeToOpen(now), isNull, reason: s.wire);
      }
    });

    test('a kind she already raised is not offered again', () {
      final now = start.add(const Duration(days: 2));
      expect(paid(kinds: ['service']).disputeToOpen(now), isNull);
      expect(paid(kinds: ['refund']).disputeToOpen(now), DisputeKind.service);
      expect(
        paid(
          status: PaymentStatus.refundDenied,
          kinds: ['refund'],
        ).disputeToOpen(now),
        isNull,
      );
    });

    test('a refund that never arrived can be reported for 14 days', () {
      Payment refunded() =>
          paid(status: PaymentStatus.refunded, recorded: start);
      expect(
        refunded().disputeToOpen(start.add(const Duration(days: 14))),
        DisputeKind.refundNotReceived,
      );
      expect(
        refunded().disputeToOpen(start.add(const Duration(days: 15))),
        isNull,
      );
    });

    test('only an unpaid payment nobody reported can be cancelled', () {
      for (final s in PaymentStatus.values) {
        expect(
          paid(status: s).canCancel,
          s == PaymentStatus.awaitingPayment || s == PaymentStatus.expired,
          reason: s.wire,
        );
      }
      expect(
        Payment(
          id: 'p',
          clientUid: 'c',
          coachUid: 'k',
          status: PaymentStatus.awaitingPayment,
          coachReportTxn: '123456789012',
        ).canCancel,
        isFalse,
      );
    });
  });
}
