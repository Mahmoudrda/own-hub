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

  test('fee statements read the server fields', () {
    final s = FeeStatement.fromMap('k__2026-10', {
      'year': 2026,
      'month': 10,
      'status': 'open',
      'totalDuePiasters': 12345,
      'lines': [{}, {}],
    })!;
    expect(s.totalDuePiasters, 12345);
    expect(s.paymentCount, 2);
    expect(s.paid, isFalse);
  });

  test('newKey is 24 hex and different each time', () {
    final a = PaymentsLocalStore.newKey();
    final b = PaymentsLocalStore.newKey();
    expect(a, matches(RegExp(r'^[0-9a-f]{24}$')));
    expect(a, isNot(b));
  });
}
