import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/domain/payments_rules.dart';
import 'package:own_hub/features/payments/presentation/record_refund_sheet.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final l10n = AppL10nEn();
final now = DateTime.utc(2026, 10, 27, 12);

/// Opens the sheet by itself once drawn, and keeps what it closed with.
class _Opener extends StatefulWidget {
  const _Opener(this.repo, this.p, this.result);
  final PaymentsRepository repo;
  final Payment p;
  final List<bool?> result;
  @override
  State<_Opener> createState() => _OpenerState();
}

class _OpenerState extends State<_Opener> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        showRecordRefundSheet(
          context: context,
          repository: widget.repo,
          payment: widget.p,
          clientName: 'Mona Adel',
          now: () => now,
        ).then(widget.result.add),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

Payment confirmed({int amount = 50037, int? received}) => payment(
  status: PaymentStatus.refundRequested,
  amountPiasters: amount,
  receivedPiasters: received,
  refundRequestedAt: now.subtract(const Duration(days: 1)),
);

/// A review staff decided in the client's favour: the refund is theirs to
/// name, the coach only records it.
Payment ordered({int piasters = 20050, int amount = 50037}) => payment(
  status: PaymentStatus.inReview,
  amountPiasters: amount,
  disputeKind: 'refund',
  disputeStaffDecision: 'refund_owed',
  refundOwedPiasters: piasters,
  refundOwedDueAt: now.add(const Duration(days: 5)),
);

Future<(FakePaymentsRepository, List<bool?>)> open(
  WidgetTester tester, {
  Payment? p,
  String lang = 'en',
  double scale = 1,
  bool small = false,
  FakePaymentsRepository? repo,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = repo ?? FakePaymentsRepository(uid: 'coach');
  final result = <bool?>[];
  await tester.pumpWidget(
    host(_Opener(fake, p ?? confirmed(), result), lang: lang, scale: scale),
  );
  await tester.pumpAndSettle();
  return (fake, result);
}

Finder field(String key) => find.descendant(
  of: find.byKey(ValueKey(key)),
  matching: find.byType(TextField),
);

String amountText(WidgetTester tester) =>
    tester.widget<TextField>(field('refund-amount')).controller!.text;

Future<void> type(WidgetTester tester, String key, String text) async {
  await tester.enterText(field(key), text);
  await tester.pump();
}

AppButton button(WidgetTester tester, String key) =>
    tester.widget<AppButton>(find.byKey(ValueKey(key)));

bool recordOn(WidgetTester tester) =>
    button(tester, 'record-refund').onPressed != null;

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

class _Refuses extends FakePaymentsRepository {
  _Refuses(this.failure) : super(uid: 'coach');
  final PaymentFailure failure;
  @override
  Future<PaymentStatus> recordRefund({
    required String paymentId,
    required String txnNumber,
    required int amountPiasters,
    required String kind,
    DateTime? paidAt,
  }) async => throw failure;
  @override
  Future<PaymentStatus> denyRefund(
    String paymentId, {
    required String reasonCode,
  }) async => throw failure;
}

void main() {
  group('a refund Own Hub ordered', () {
    testWidgets('shows the sum as text, with no field and no way to disagree', (
      tester,
    ) async {
      await open(tester, p: ordered());
      expect(find.text('Mona Adel · OH-4821 · 500.37 EGP'), findsOneWidget);
      expect(find.text('Amount sent back (EGP)'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('refund-owed-amount')))
            .data,
        '200.50',
      );
      expect(find.text('Own Hub set this amount.'), findsOneWidget);
      expect(find.byKey(const ValueKey('refund-amount')), findsNothing);
      expect(find.byKey(const ValueKey('refund-partial')), findsNothing);
      expect(find.byKey(const ValueKey('deny-refund')), findsNothing);
      expect(recordOn(tester), isFalse, reason: 'no transaction number yet');
    });

    testWidgets('recording sends the ordered sum as a refund, once', (
      tester,
    ) async {
      final (fake, result) = await open(tester, p: ordered());
      await type(tester, 'refund-txn', '1234567890123');
      expect(recordOn(tester), isTrue);
      await tapKey(tester, 'record-refund');
      expect(fake.names, ['recordRefund']);
      expect(fake.calls.single.$2['amount'], 20050);
      expect(fake.calls.single.$2['kind'], 'refund');
      expect(fake.calls.single.$2['txn'], '1234567890123');
      expect(fake.calls.single.$2['paidAt'], now);
      expect(result, [true]);
    });

    testWidgets('a sum larger than the payment is refused by the server '
        'with a calm line', (tester) async {
      final fake = _Refuses(const PaymentFailure('bad_request'));
      await open(tester, p: ordered(piasters: 90000), repo: fake);
      await type(tester, 'refund-txn', '1234567890123');
      await tapKey(tester, 'record-refund');
      expect(find.text(l10n.pleaseCheckTheAmountItCannotBe), findsOneWidget);
      expect(recordOn(tester), isTrue);
    });

    testWidgets('no signal keeps the sheet and says so', (tester) async {
      final fake = _Refuses(const PaymentFailure('', unreachable: true));
      await open(tester, p: ordered(), repo: fake);
      await type(tester, 'refund-txn', '1234567890123');
      await tapKey(tester, 'record-refund');
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
      expect(find.byKey(const ValueKey('record-refund')), findsOneWidget);
    });

    for (final lang in ['en', 'ar']) {
      for (final scale in [1.0, 2.0]) {
        for (final small in [false, true]) {
          testWidgets('budget and layout, $lang at ${scale}x on '
              '${small ? '375x667' : '390x844'}', (tester) async {
            await open(
              tester,
              p: ordered(),
              lang: lang,
              scale: scale,
              small: small,
            );
            await type(tester, 'refund-txn', '1234567890123');
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
            );
            expect(filledPrimaryActions(tester), 1);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });

  group('Record refund', () {
    testWidgets('shows who, what and the plain words, with one filled button', (
      tester,
    ) async {
      await open(tester);
      expect(find.text('Mona Adel · OH-4821 · 500.37 EGP'), findsOneWidget);
      expect(find.text(l10n.sendTheMoneyBackToYourClient), findsOneWidget);
      expect(find.text('Amount sent back (EGP)'), findsOneWidget);
      expect(find.text('Transaction number'), findsOneWidget);
      expect(recordOn(tester), isFalse, reason: 'no transaction number yet');
      await type(tester, 'refund-txn', '1234567890');
      expect(filledPrimaryActions(tester), 1);
    });

    testWidgets('the amount starts as the full amount', (tester) async {
      await open(tester);
      expect(amountText(tester), '500.37');
    });

    testWidgets('a lower accepted amount is the full one, never more', (
      tester,
    ) async {
      await open(tester, p: confirmed(received: 30000));
      expect(amountText(tester), '300');
      await tester.pumpWidget(const SizedBox());
      await open(tester, p: confirmed(received: 60000));
      expect(amountText(tester), '500.37');
    });

    testWidgets('a part of the payment is accepted and said out loud', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'refund-txn', '1234567890');
      expect(find.byKey(const ValueKey('refund-partial')), findsNothing);
      await type(tester, 'refund-amount', '250');
      expect(recordOn(tester), isTrue);
      expect(
        find.text('Part of the payment: 250 EGP of 500.37 EGP.'),
        findsOneWidget,
      );
    });

    testWidgets('nothing, zero, too little and too much keep it off', (
      tester,
    ) async {
      await open(tester);
      await type(tester, 'refund-txn', '1234567890');
      expect(recordOn(tester), isTrue);
      for (final bad in ['', '0', '0.5', 'abc', '500.38', '600', '1.234']) {
        await type(tester, 'refund-amount', bad);
        expect(recordOn(tester), isFalse, reason: bad);
      }
      await type(tester, 'refund-amount', '500.37');
      expect(recordOn(tester), isTrue);
      await type(tester, 'refund-amount', '1');
      expect(recordOn(tester), isTrue);
    });

    testWidgets('the transaction number is 10 to 20 digits', (tester) async {
      await open(tester);
      for (final bad in [
        '',
        '123456789',
        '12345678901234567890'
            '1',
        '12345678AB',
        'TXN1234567890',
      ]) {
        await type(tester, 'refund-txn', bad);
        expect(recordOn(tester), isFalse, reason: bad);
      }
      for (final good in [
        '1234567890',
        '12345678901234567890',
        ' 1234 5678 9012 ',
      ]) {
        await type(tester, 'refund-txn', good);
        expect(recordOn(tester), isTrue, reason: good);
      }
    });

    testWidgets('records the amount, the number, the kind and the time once', (
      tester,
    ) async {
      final (fake, result) = await open(tester);
      await type(tester, 'refund-amount', '250.5');
      await type(tester, 'refund-txn', '1234567890123');
      await tapKey(tester, 'record-refund');
      expect(fake.names, ['recordRefund']);
      expect(fake.calls.single.$2, {
        'id': 'p1',
        'txn': '1234567890123',
        'amount': 25050,
        'kind': 'refund',
        'paidAt': now,
      });
      expect(result, [true]);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('Arabic digits go to the server as Latin digits', (
      tester,
    ) async {
      final (fake, _) = await open(tester);
      await type(tester, 'refund-amount', '٢٥٠');
      await type(tester, 'refund-txn', '١٢٣٤٥٦٧٨٩٠١٢');
      await tapKey(tester, 'record-refund');
      expect(fake.calls.single.$2['txn'], '123456789012');
      expect(fake.calls.single.$2['amount'], 25000);
    });

    final refusals = <String, String>{
      'txn_reused': l10n.thisTransactionNumberWasAlreadyUsed,
      'refund_txn_invalid': l10n.pleaseCheckTheTransactionNumberFromYour,
      'refund_paid_at_invalid': l10n.theDateOrTimeOnYourPhone,
      'bad_request': l10n.pleaseCheckTheAmountItCannotBe,
      'illegal_transition': l10n.thisPaymentChangedRefreshAndTryAgain,
      'payment_not_found': l10n.thisPaymentChangedRefreshAndTryAgain,
      'coach_not_ready': l10n.weCouldNotDoThatTryAgain,
      'permission_denied': l10n.weCouldNotDoThatTryAgain,
    };
    for (final e in refusals.entries) {
      testWidgets('refused with ${e.key}: a calm line and she can retry', (
        tester,
      ) async {
        final (_, result) = await open(
          tester,
          repo: _Refuses(PaymentFailure(e.key)),
        );
        await type(tester, 'refund-txn', '1234567890123');
        await tapKey(tester, 'record-refund');
        expect(find.text(e.value), findsOneWidget);
        expect(find.textContaining(e.key), findsNothing);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(result, isEmpty);
        expect(recordOn(tester), isTrue);
      });
    }

    testWidgets('offline: it says it could not reach Own Hub', (tester) async {
      await open(
        tester,
        repo: _Refuses(const PaymentFailure('', unreachable: true)),
      );
      await type(tester, 'refund-txn', '1234567890123');
      await tapKey(tester, 'record-refund');
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });
  });

  group('I do not agree', () {
    testWidgets('asks why, with the three reasons the server knows', (
      tester,
    ) async {
      await open(tester);
      await tapKey(tester, 'deny-refund');
      expect(find.text('Why do you not agree?'), findsOneWidget);
      expect(
        find.text('Your client can then ask Own Hub to look at it.'),
        findsOneWidget,
      );
      for (final code in kDenyReasons) {
        expect(find.byKey(ValueKey('deny-$code')), findsOneWidget);
      }
      expect(find.text('I already gave the sessions'), findsOneWidget);
      expect(find.text('It is outside the terms'), findsOneWidget);
      expect(find.text('Another reason'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-refund')), findsNothing);
      expect(filledPrimaryActions(tester), 0);
    });

    testWidgets('Send waits for a reason, then sends it once', (tester) async {
      final (fake, result) = await open(tester);
      await tapKey(tester, 'deny-refund');
      expect(button(tester, 'deny-send').onPressed, isNull);
      await tapKey(tester, 'deny-outside_terms');
      expect(button(tester, 'deny-send').onPressed, isNotNull);
      await tapKey(tester, 'deny-send');
      expect(fake.names, ['denyRefund']);
      expect(fake.calls.single.$2, {'id': 'p1', 'reason': 'outside_terms'});
      expect(result, [true]);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('going back keeps what she typed', (tester) async {
      await open(tester);
      await type(tester, 'refund-amount', '250');
      await type(tester, 'refund-txn', '1234567890');
      await tapKey(tester, 'deny-refund');
      await tapKey(tester, 'deny-back');
      expect(amountText(tester), '250');
      expect(recordOn(tester), isTrue);
    });

    for (final e in {
      'illegal_transition': l10n.thisPaymentChangedRefreshAndTryAgain,
      'payment_not_found': l10n.thisPaymentChangedRefreshAndTryAgain,
      'permission_denied': l10n.weCouldNotDoThatTryAgain,
    }.entries) {
      testWidgets('refused with ${e.key}: a calm line, still open', (
        tester,
      ) async {
        final (_, result) = await open(
          tester,
          repo: _Refuses(PaymentFailure(e.key)),
        );
        await tapKey(tester, 'deny-refund');
        await tapKey(tester, 'deny-other');
        await tapKey(tester, 'deny-send');
        expect(find.text(e.value), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(result, isEmpty);
      });
    }

    testWidgets('offline: it says it could not reach Own Hub', (tester) async {
      await open(
        tester,
        repo: _Refuses(const PaymentFailure('', unreachable: true)),
      );
      await tapKey(tester, 'deny-refund');
      await tapKey(tester, 'deny-other');
      await tapKey(tester, 'deny-send');
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget and layout, $lang at ${scale}x on ${small ? '375x667' : '390x844'}',
          (tester) async {
            await open(tester, lang: lang, scale: scale, small: small);
            await type(tester, 'refund-amount', '250');
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
              reason: 'record',
            );
            expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
            expect(tester.takeException(), isNull, reason: 'record');
            await tapKey(tester, 'deny-refund');
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
              reason: 'deny',
            );
            expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
            expect(tester.takeException(), isNull, reason: 'deny');
          },
        );
      }
    }
  }
}
