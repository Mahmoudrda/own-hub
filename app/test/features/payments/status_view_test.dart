import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/status_view.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final now = DateTime.utc(2026, 10, 27, 12);

Future<FakePaymentsRepository> open(
  WidgetTester tester,
  List<Payment> payments, {
  void Function(StatusAction, Payment)? onAction,
  List<PaymentEvent> events = const [],
  String lang = 'en',
  double scale = 1,
  bool small = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = FakePaymentsRepository()
    ..events = events
    ..setPayments(payments);
  await tester.pumpWidget(
    host(
      PaymentStatusView(
        paymentId: 'p1',
        repository: fake,
        now: () => now,
        onAction: onAction ?? (_, _) {},
      ),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

Payment at(
  PaymentStatus s, {
  String kind = '',
  RiskOutcome? outcome,
  DateTime? access,
  DateTime? late,
  bool lower = false,
}) => payment(
  status: s,
  disputeKind: kind,
  outcome: outcome,
  accessUntil: access,
  lateUntil: late,
  acceptLower: lower,
  differentAmountPiasters: 30000,
);

void main() {
  testWidgets('loading shows a spinner, not a blank screen', (tester) async {
    phone(tester);
    final fake = FakePaymentsRepository();
    await tester.pumpWidget(
      host(
        PaymentStatusView(
          paymentId: 'p1',
          repository: fake,
          now: () => now,
          onAction: (_, _) {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a payment that is not there says so calmly', (tester) async {
    await open(tester, const []);
    expect(find.byKey(const ValueKey('status-failure')), findsOneWidget);
    expect(find.textContaining('changed'), findsOneWidget);
  });

  testWidgets('every status shows a word and a next line, never a raw code', (
    tester,
  ) async {
    for (final s in PaymentStatus.values) {
      await open(tester, [at(s)]);
      expect(
        find.byKey(const ValueKey('status-word')),
        findsOneWidget,
        reason: s.wire,
      );
      expect(
        find.byKey(const ValueKey('next-line')),
        findsOneWidget,
        reason: s.wire,
      );
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(texts.contains('_'), isFalse, reason: s.wire);
      await tester.pumpWidget(const SizedBox());
    }
  });

  group('the one primary, by state', () {
    final table = <String, (Payment, StatusAction?)>{
      'awaiting': (at(PaymentStatus.awaitingPayment), StatusAction.pay),
      'expired inside the 7 days': (
        at(PaymentStatus.expired, late: now.add(const Duration(days: 3))),
        StatusAction.sendProof,
      ),
      'expired after the 7 days': (
        at(
          PaymentStatus.expired,
          late: now.subtract(const Duration(minutes: 1)),
        ),
        null,
      ),
      'a different amount to pay up': (
        at(PaymentStatus.differentAmount),
        StatusAction.payRest,
      ),
      'a lower amount the coach accepted': (
        at(PaymentStatus.differentAmount, lower: true),
        StatusAction.agree,
      ),
      'red proof, in review': (
        at(PaymentStatus.inReview, kind: 'proof_red'),
        StatusAction.addProof,
      ),
      'coach said not received, in review': (
        at(PaymentStatus.inReview, kind: 'not_received'),
        StatusAction.addProof,
      ),
      'in review for a service problem': (
        at(PaymentStatus.inReview, kind: 'service'),
        null,
      ),
      'confirmed': (at(PaymentStatus.confirmed), StatusAction.openCoaching),
      'resolved paid': (
        at(PaymentStatus.resolvedPaid),
        StatusAction.openCoaching,
      ),
      'proof sent, green': (
        at(PaymentStatus.proofSubmitted, outcome: RiskOutcome.green),
        null,
      ),
      'resolved unpaid': (at(PaymentStatus.resolvedUnpaid), null),
      'refund asked': (at(PaymentStatus.refundRequested), null),
    };
    table.forEach((name, row) {
      testWidgets(name, (tester) async {
        final got = <StatusAction>[];
        await open(tester, [row.$1], onAction: (a, _) => got.add(a));
        final primary = find.byKey(const ValueKey('status-primary'));
        if (row.$2 == null) {
          expect(primary, findsNothing);
        } else {
          expect(primary, findsOneWidget);
          if (row.$2 != StatusAction.agree) {
            await tester.tap(primary);
            expect(got, [row.$2]);
          }
        }
        expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
      });
    });
  });

  testWidgets('agreeing to the lower amount answers the server on the screen', (
    tester,
  ) async {
    final fake = await open(tester, [
      at(PaymentStatus.differentAmount, lower: true),
    ]);
    await tester.tap(find.byKey(const ValueKey('status-primary')));
    await tester.pump();
    expect(fake.calls.last.$1, 'clientRespondDifferentAmount');
    expect(fake.calls.last.$2['agree'], isTrue);
    await tester.tap(find.byKey(const ValueKey('disagree')));
    await tester.pump();
    expect(fake.calls.last.$2['agree'], isFalse);
  });

  testWidgets('wrong amount: says what the coach received', (tester) async {
    await open(tester, [at(PaymentStatus.differentAmount)]);
    expect(find.textContaining('300 EGP'), findsOneWidget);
  });

  testWidgets('green access shows the date only while it is open', (
    tester,
  ) async {
    await open(tester, [
      at(
        PaymentStatus.proofSubmitted,
        outcome: RiskOutcome.green,
        access: now.add(const Duration(days: 3)),
      ),
    ]);
    expect(find.byKey(const ValueKey('green-access')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await open(tester, [
      at(
        PaymentStatus.proofSubmitted,
        outcome: RiskOutcome.green,
        access: now.subtract(const Duration(hours: 1)),
      ),
    ]);
    expect(find.byKey(const ValueKey('green-access')), findsNothing);
  });

  testWidgets(
    'amber says the coach is checking her bank and offers no button',
    (tester) async {
      await open(tester, [
        at(PaymentStatus.proofSubmitted, outcome: RiskOutcome.amber),
      ]);
      expect(find.byKey(const ValueKey('amber')), findsOneWidget);
      expect(find.byKey(const ValueKey('status-primary')), findsNothing);
    },
  );

  testWidgets('red proof asks for her bank history in plain words', (
    tester,
  ) async {
    await open(tester, [at(PaymentStatus.inReview, kind: 'proof_red')]);
    expect(find.textContaining("bank's transaction history"), findsOneWidget);
  });

  testWidgets('success: confirmed says all set and offers her coaching', (
    tester,
  ) async {
    await open(tester, [at(PaymentStatus.confirmed)]);
    expect(find.text('All set. Your coaching is active.'), findsOneWidget);
    expect(find.text('Open my coaching'), findsOneWidget);
  });

  testWidgets(
    'the coach report card asks, sends the answer, and is the one primary',
    (tester) async {
      final fake = await open(tester, [
        payment(coachReportTxn: '123456789012'),
      ]);
      expect(find.byKey(const ValueKey('report-yes')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('status-primary')),
        findsNothing,
        reason: 'one filled button only',
      );
      expect(filledPrimaryActions(tester), 1);
      await tester.tap(find.byKey(const ValueKey('report-yes')));
      await tester.pump();
      expect(fake.calls.last.$1, 'clientAnswerReport');
      expect(fake.calls.last.$2['yes'], isTrue);
      await tester.tap(find.byKey(const ValueKey('report-no')));
      await tester.pump();
      expect(fake.calls.last.$2['yes'], isFalse);
    },
  );

  testWidgets(
    'after she answered the report card is gone and Pay now returns',
    (tester) async {
      await open(tester, [
        payment(coachReportTxn: '123456789012', coachReportAnswered: true),
      ]);
      expect(find.byKey(const ValueKey('report-yes')), findsNothing);
      expect(find.byKey(const ValueKey('status-primary')), findsOneWidget);
    },
  );

  testWidgets('a refusal on an answer shows a calm sentence', (tester) async {
    final fake = await open(tester, [payment(coachReportTxn: '123456789012')]);
    fake.failNext = const PaymentFailure('no_coach_report');
    await tester.tap(find.byKey(const ValueKey('report-yes')));
    await tester.pump();
    expect(find.byKey(const ValueKey('status-error')), findsOneWidget);
    expect(find.textContaining('no_coach_report'), findsNothing);
  });

  testWidgets(
    'the timeline lists events in order in Cairo time, notes by code',
    (tester) async {
      await open(
        tester,
        [at(PaymentStatus.proofSubmitted)],
        events: [
          PaymentEvent(
            at: DateTime.utc(2026, 10, 27, 10),
            to: 'awaiting_payment',
            role: 'client',
            code: 'created',
          ),
          PaymentEvent(
            at: DateTime.utc(2026, 10, 27, 10, 30),
            from: 'awaiting_payment',
            to: 'awaiting_payment',
            role: 'coach',
            code: 'coach_reported',
          ),
          PaymentEvent(
            at: DateTime.utc(2026, 10, 27, 11),
            from: 'awaiting_payment',
            to: 'proof_submitted',
            role: 'client',
            code: 'proof_green',
          ),
          PaymentEvent(
            at: DateTime.utc(2026, 10, 27, 11, 5),
            from: 'x',
            to: 'unknown_status',
            role: 'system',
            code: 'z',
          ),
        ],
      );
      final rows = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where(RegExp(r'^\d\d/\d\d ').hasMatch)
          .toList();
      expect(rows.length, 3, reason: 'an unknown row is not shown');
      expect(rows[0], '27/10 13:00  Payment request created');
      expect(rows[1], contains('Your coach says you paid. Please check.'));
      expect(rows[2], '27/10 14:00  You sent your proof');
    },
  );

  testWidgets('offline: a stream error says it could not reach Own Hub', (
    tester,
  ) async {
    phone(tester);
    final fake = _Failing(const PaymentFailure('', unreachable: true));
    await tester.pumpWidget(
      host(
        PaymentStatusView(
          paymentId: 'p1',
          repository: fake,
          now: () => now,
          onAction: (_, _) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('could not reach Own Hub'), findsOneWidget);
  });

  testWidgets(
    'denied: a permission refusal shows the neutral changed sentence',
    (tester) async {
      phone(tester);
      final fake = _Failing(const PaymentFailure(''));
      await tester.pumpWidget(
        host(
          PaymentStatusView(
            paymentId: 'p1',
            repository: fake,
            now: () => now,
            onAction: (_, _) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('status-failure')), findsOneWidget);
    },
  );

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget and layout, $lang at ${scale}x on ${small ? '375x667' : '390x844'}',
          (tester) async {
            final states = [
              at(PaymentStatus.awaitingPayment),
              at(PaymentStatus.inReview, kind: 'not_received'),
              at(PaymentStatus.confirmed),
              payment(coachReportTxn: '123456789012'),
              at(PaymentStatus.differentAmount, lower: true),
            ];
            for (final s in states) {
              await open(tester, [s], lang: lang, scale: scale, small: small);
              expect(
                countControlsAboveFold(tester, includeChrome: false),
                lessThanOrEqualTo(5),
                reason: s.status.wire,
              );
              expect(
                filledPrimaryActions(tester),
                lessThanOrEqualTo(1),
                reason: s.status.wire,
              );
              expect(tester.takeException(), isNull, reason: s.status.wire);
              await tester.pumpWidget(const SizedBox());
            }
          },
        );
      }
    }
  }
}

class _Failing extends FakePaymentsRepository {
  _Failing(this.failure);
  final PaymentFailure failure;
  @override
  Stream<Payment?> watchPayment(String id) => Stream<Payment?>.error(failure);
}
