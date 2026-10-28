import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/payment_record_view.dart';
import 'package:own_hub/features/payments/presentation/problem_view.dart';
import 'package:own_hub/features/payments/presentation/status_view.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final now = DateTime.utc(2026, 10, 27, 12);
final l10n = AppL10nEn();

DateTime ago(int days) => now.subtract(Duration(days: days));

Future<FakePaymentsRepository> open(
  WidgetTester tester,
  Payment p, {
  String lang = 'en',
  double scale = 1,
  bool small = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = FakePaymentsRepository()..setPayments([p]);
  await tester.pumpWidget(
    host(
      PaymentStatusView(
        paymentId: 'p1',
        repository: fake,
        now: () => now,
        onAction: (_, _) {},
      ),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

Finder get menuButton => find.byKey(const ValueKey('overflow-menu'));

Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(menuButton);
  await tester.pumpAndSettle();
}

Future<void> pickRow(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(ValueKey('overflow-row-$label')));
  await tester.pumpAndSettle();
}

List<String> rows(WidgetTester tester) => [
  for (final e in find.byWidgetPredicate((w) {
    final k = w.key;
    return k is ValueKey<String> && k.value.startsWith('overflow-row-');
  }).evaluate())
    (e.widget.key! as ValueKey<String>).value.substring('overflow-row-'.length),
];

const cancel = 'Cancel payment';
const refund = 'Ask for a refund';
const service = 'I have a problem with the service';
const again = 'Ask Own Hub to look again';
const missing = 'The refund did not reach me';
const record = 'Save payment record';

void main() {
  group('the menu offers only what the server accepts', () {
    final table = <String, (Payment, List<String>)>{
      'awaiting payment': (
        payment(status: PaymentStatus.awaitingPayment),
        [cancel],
      ),
      'expired': (payment(status: PaymentStatus.expired), [cancel]),
      'her coach says she paid, she must answer that': (
        payment(coachReportTxn: '123456789012'),
        [],
      ),
      'confirmed on day 2': (
        payment(status: PaymentStatus.confirmed, confirmedAt: ago(2)),
        [refund, service, record],
      ),
      'confirmed on day 13': (
        payment(status: PaymentStatus.confirmed, confirmedAt: ago(13)),
        [refund, service, record],
      ),
      'confirmed on day 15: no refund any more': (
        payment(status: PaymentStatus.confirmed, confirmedAt: ago(15)),
        [service, record],
      ),
      'confirmed, problem already reported': (
        payment(
          status: PaymentStatus.confirmed,
          confirmedAt: ago(2),
          disputeKinds: ['service'],
        ),
        [refund, record],
      ),
      'resolved paid, window from staff decision': (
        payment(status: PaymentStatus.resolvedPaid, disputeDecidedAt: ago(3)),
        [refund, service, record],
      ),
      'resolved paid, decision on day 20': (
        payment(status: PaymentStatus.resolvedPaid, disputeDecidedAt: ago(20)),
        [service, record],
      ),
      'refund denied': (payment(status: PaymentStatus.refundDenied), [again]),
      'refund denied, already taken to Own Hub': (
        payment(status: PaymentStatus.refundDenied, disputeKinds: ['refund']),
        [],
      ),
      'refunded two days ago': (
        payment(status: PaymentStatus.refunded, refundRecordedAt: ago(2)),
        [missing],
      ),
      'refunded 15 days ago': (
        payment(status: PaymentStatus.refunded, refundRecordedAt: ago(15)),
        [],
      ),
      'proof sent': (payment(status: PaymentStatus.proofSubmitted), []),
      'different amount': (payment(status: PaymentStatus.differentAmount), []),
      'not received': (payment(status: PaymentStatus.coachNotReceived), []),
      'under review': (payment(status: PaymentStatus.inReview), []),
      'refund asked': (
        payment(
          status: PaymentStatus.refundRequested,
          refundRequestedAt: ago(1),
        ),
        [],
      ),
      'problem reported': (payment(status: PaymentStatus.serviceDispute), []),
      'review done, not paid': (
        payment(status: PaymentStatus.resolvedUnpaid),
        [],
      ),
      'cancelled': (payment(status: PaymentStatus.cancelled), []),
    };
    for (final e in table.entries) {
      testWidgets(e.key, (tester) async {
        await open(tester, e.value.$1);
        if (e.value.$2.isEmpty) {
          expect(menuButton, findsNothing);
          return;
        }
        await openMenu(tester);
        expect(rows(tester), e.value.$2);
      });
    }
  });

  group('Cancel payment', () {
    Future<FakePaymentsRepository> ask(WidgetTester tester) async {
      final fake = await open(
        tester,
        payment(status: PaymentStatus.awaitingPayment),
      );
      await openMenu(tester);
      await pickRow(tester, cancel);
      return fake;
    }

    testWidgets('asks calmly first and calls nothing yet', (tester) async {
      final fake = await ask(tester);
      expect(
        find.text(
          'Cancel this payment? Only do this if you have not paid. If you '
          'already sent the money, send your proof instead.',
        ),
        findsOneWidget,
      );
      expect(fake.names, isEmpty);
    });

    testWidgets('going back from the question cancels nothing', (tester) async {
      final fake = await ask(tester);
      await tester.tap(find.byKey(const ValueKey('overflow-cancel')));
      await tester.pumpAndSettle();
      expect(fake.names, isEmpty);
      expect(
        find.byKey(const ValueKey('overflow-row-$cancel')),
        findsOneWidget,
      );
    });

    testWidgets('confirming cancels this payment once', (tester) async {
      final fake = await ask(tester);
      await tester.tap(find.byKey(const ValueKey('overflow-confirm')));
      await tester.pumpAndSettle();
      expect(fake.names, ['cancelPayment']);
      expect(fake.calls.single.$2, {'id': 'p1'});
      expect(find.byKey(const ValueKey('status-error')), findsNothing);
    });

    for (final e in {
      'illegal_transition': l10n.thisPaymentChangedRefreshAndTryAgain,
      'payment_not_found': l10n.thisPaymentChangedRefreshAndTryAgain,
      'permission_denied': l10n.weCouldNotDoThatTryAgain,
    }.entries) {
      testWidgets('refused with ${e.key}: a calm line, never the code', (
        tester,
      ) async {
        final fake = await ask(tester);
        fake.failNext = PaymentFailure(e.key);
        await tester.tap(find.byKey(const ValueKey('overflow-confirm')));
        await tester.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget);
        expect(find.textContaining(e.key), findsNothing);
      });
    }

    testWidgets('offline: it says it could not reach Own Hub', (tester) async {
      final fake = await ask(tester);
      fake.failNext = const PaymentFailure('', unreachable: true);
      await tester.tap(find.byKey(const ValueKey('overflow-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });
  });

  group('the screens the menu opens', () {
    testWidgets('Save payment record opens PAY10 and goes back to PAY3', (
      tester,
    ) async {
      await open(
        tester,
        payment(status: PaymentStatus.confirmed, confirmedAt: ago(2)),
      );
      await openMenu(tester);
      await pickRow(tester, record);
      expect(find.byType(PaymentRecordView), findsOneWidget);
      expect(find.byKey(const ValueKey('rec-ref')), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentRecordView), findsNothing);
      expect(find.byType(PaymentStatusView), findsOneWidget);
    });

    testWidgets('Ask for a refund opens PAY8 and goes back to PAY3', (
      tester,
    ) async {
      final fake = await open(
        tester,
        payment(status: PaymentStatus.confirmed, confirmedAt: ago(2)),
      );
      await openMenu(tester);
      await pickRow(tester, refund);
      expect(find.byType(PaymentProblemView), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('problem-send')));
      await tester.pumpAndSettle();
      expect(fake.names, ['requestRefund']);
      expect(find.byType(PaymentProblemView), findsNothing);
      expect(find.byType(PaymentStatusView), findsOneWidget);
    });

    testWidgets('the service problem sends her note to Own Hub', (
      tester,
    ) async {
      final fake = await open(
        tester,
        payment(status: PaymentStatus.confirmed, confirmedAt: ago(2)),
      );
      await openMenu(tester);
      await pickRow(tester, service);
      expect(find.text('Service problem'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'No plan after a week');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('problem-send')));
      await tester.pumpAndSettle();
      expect(fake.names, ['openServiceDispute']);
      expect(fake.calls.single.$2['note'], 'No plan after a week');
      expect(find.byType(PaymentStatusView), findsOneWidget);
    });

    testWidgets('a refused refund can be taken to Own Hub', (tester) async {
      final fake = await open(
        tester,
        payment(status: PaymentStatus.refundDenied),
      );
      await openMenu(tester);
      await pickRow(tester, again);
      expect(find.text('Ask Own Hub to look again'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'I never got my sessions');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('problem-send')));
      await tester.pumpAndSettle();
      expect(fake.names, ['openServiceDispute']);
    });
  });

  group('after she reports, PAY3 says where it stands and what comes next', () {
    final states = <String, (Payment, String, String)>{
      'problem reported': (
        payment(status: PaymentStatus.serviceDispute),
        'Problem reported',
        'Own Hub is looking into it.',
      ),
      'service problem in review': (
        payment(status: PaymentStatus.inReview, disputeKind: 'service'),
        'Under review',
        'Own Hub is looking at both sides.',
      ),
      'refused refund in review': (
        payment(status: PaymentStatus.inReview, disputeKind: 'refund'),
        'Under review',
        'Own Hub is looking at both sides.',
      ),
      'refund never arrived, in review': (
        payment(
          status: PaymentStatus.inReview,
          disputeKind: 'refund_not_received',
        ),
        'Under review',
        'Own Hub is looking at both sides.',
      ),
      'refund asked': (
        payment(status: PaymentStatus.refundRequested),
        'Refund asked',
        'Your coach has 3 days to answer',
      ),
      'refund recorded': (
        payment(status: PaymentStatus.refunded),
        'Refund recorded',
        'Your coach recorded the refund.',
      ),
      'refund refused': (
        payment(status: PaymentStatus.refundDenied),
        'Refund not agreed',
        'open the menu at the top and ask Own Hub to look again',
      ),
    };
    for (final e in states.entries) {
      testWidgets(e.key, (tester) async {
        await open(tester, e.value.$1);
        expect(find.text(e.value.$2), findsOneWidget);
        expect(
          find.textContaining(e.value.$3, findRichText: true),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('status-primary')), findsNothing);
      });
    }
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget with the menu, $lang at ${scale}x on ${small ? '375x667' : '390x844'}',
          (tester) async {
            final states = [
              payment(status: PaymentStatus.awaitingPayment),
              payment(status: PaymentStatus.confirmed, confirmedAt: ago(2)),
              payment(status: PaymentStatus.refundDenied),
              payment(status: PaymentStatus.refunded, refundRecordedAt: ago(2)),
              payment(status: PaymentStatus.refundRequested),
            ];
            for (final s in states) {
              await open(tester, s, lang: lang, scale: scale, small: small);
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
