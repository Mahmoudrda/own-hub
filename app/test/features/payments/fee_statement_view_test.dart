import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/fee_statement_view.dart';
import 'package:own_hub/features/payments/presentation/payment_text.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final now = DateTime.utc(2026, 11, 10, 12);
final l10n = AppL10nEn();

FeeLine line(
  String id, {
  int base = 50000,
  int fee = 7500,
  String state = 'owed',
  String reference = '',
}) => FeeLine(
  paymentId: id,
  reference: reference.isEmpty ? 'OH-$id' : reference,
  basePiasters: base,
  feePiasters: fee,
  feeState: state,
);

FeeStatement statement({
  String id = 'coach__2026-10',
  int year = 2026,
  int month = 10,
  String status = 'open',
  int? total,
  List<FeeLine>? lines,
  FeePayTo payTo = const FeePayTo(
    address: 'ownhub@instapay',
    holderName: 'Own Hub Ltd',
  ),
  String claimedTxn = '',
  DateTime? dueAt,
  DateTime? holdAt,
  bool onHold = false,
}) {
  final ls = lines ?? [line('p1'), line('p2', fee: 4000)];
  return FeeStatement(
    id: id,
    year: year,
    month: month,
    status: status,
    totalDuePiasters:
        total ??
        ls
            .where((l) => l.feeState == 'owed')
            .fold(0, (a, l) => a + l.feePiasters),
    lines: ls,
    payTo: payTo,
    claimedTxn: claimedTxn,
    dueAt: dueAt ?? now.add(const Duration(days: 20)),
    holdAt: holdAt ?? now.add(const Duration(days: 24)),
    onHold: onHold,
  );
}

Future<FakePaymentsRepository> open(
  WidgetTester tester,
  List<FeeStatement> statements, {
  FakePaymentsRepository? repo,
  String lang = 'en',
  double scale = 1,
  bool small = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = repo ?? FakePaymentsRepository(uid: 'coach');
  fake.statements = statements;
  await tester.pumpWidget(
    host(
      FeeStatementView(repository: fake, now: () => now),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

class _Failing extends FakePaymentsRepository {
  _Failing(this.failure) : super(uid: 'coach');
  final PaymentFailure failure;
  @override
  Stream<List<FeeStatement>> watchMyStatements() =>
      Stream<List<FeeStatement>>.error(failure);
}

class _Refuses extends FakePaymentsRepository {
  _Refuses(this.failure) : super(uid: 'coach');
  final PaymentFailure failure;
  @override
  Future<void> recordFeePayment({
    required String statementId,
    required String txnNumber,
  }) async {
    calls.add(('recordFeePayment', {'id': statementId, 'txn': txnNumber}));
    throw failure;
  }
}

Finder get markFee => find.byKey(const ValueKey('mark-fee'));
Finder get sendFee => find.byKey(const ValueKey('fee-send'));

Finder txnField() => find.descendant(
  of: find.byKey(const ValueKey('fee-txn')),
  matching: find.byType(TextField),
);

bool sendOn(WidgetTester tester) =>
    tester.widget<AppButton>(sendFee).onPressed != null;

Future<void> openSheet(WidgetTester tester) async {
  await tester.tap(markFee);
  await tester.pumpAndSettle();
}

Future<void> pickMonth(WidgetTester tester, String id) async {
  final row = find.byKey(ValueKey('month-$id'));
  await tester.ensureVisible(row);
  await tester.pump();
  await tester.tap(row);
  await tester.pump();
}

Future<void> typeTxn(WidgetTester tester, String text) async {
  await tester.enterText(txnField(), text);
  await tester.pump();
}

String textOf(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  group('an open statement', () {
    testWidgets('shows the month, the total, one line per payment and where to '
        'pay', (tester) async {
      await open(tester, [statement()]);
      expect(find.text('Fee for 2026-10'), findsOneWidget);
      expect(textOf(tester, 'fee-total'), '115 EGP');
      expect(find.text('Payments: 2'), findsOneWidget);
      expect(find.byKey(const ValueKey('fee-line-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('fee-line-p2')), findsOneWidget);
      expect(find.text('OH-p1'), findsOneWidget);
      expect(find.text('75 EGP fee on 500 EGP\nDue'), findsOneWidget);
      expect(find.text('40 EGP fee on 500 EGP\nDue'), findsOneWidget);
      expect(find.text('Pay Own Hub\'s fee by InstaPay to:'), findsOneWidget);
      expect(textOf(tester, 'fee-address'), 'ownhub@instapay');
      expect(textOf(tester, 'fee-holder'), 'Account name: Own Hub Ltd');
      expect(
        textOf(tester, 'fee-rule'),
        'Unpaid on 04/12/2026, your account goes on hold. '
        'Your current clients keep their plans.',
      );
      expect(textOf(tester, 'fee-due'), 'Due by 30/11/2026');
      expect(markFee, findsOneWidget);
    });

    testWidgets('Copy puts the address from the statement on the clipboard', (
      tester,
    ) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await open(tester, [statement()]);
      await tester.tap(find.byKey(const ValueKey('copy-fee-address')));
      await tester.pump();
      expect(copied, 'ownhub@instapay');
      expect(find.text(l10n.copied), findsOneWidget);
    });

    testWidgets('no address on the statement: a calm line and no Copy', (
      tester,
    ) async {
      await open(tester, [statement(payTo: const FeePayTo())]);
      expect(
        textOf(tester, 'fee-no-address'),
        'Own Hub will send you the address to pay to.',
      );
      expect(find.byKey(const ValueKey('copy-fee-address')), findsNothing);
      expect(find.byKey(const ValueKey('fee-address')), findsNothing);
      expect(markFee, findsOneWidget);
    });

    testWidgets('a holder name is shown only when there is one', (
      tester,
    ) async {
      await open(tester, [
        statement(payTo: const FeePayTo(address: 'ownhub@instapay')),
      ]);
      expect(find.byKey(const ValueKey('fee-holder')), findsNothing);
    });

    testWidgets('past its due date it says when the account goes on hold', (
      tester,
    ) async {
      await open(tester, [
        statement(dueAt: now.subtract(const Duration(days: 1))),
      ]);
      expect(
        textOf(tester, 'fee-late'),
        'This fee is late. Your account goes on hold on 04/12/2026 '
        'if it is still unpaid.',
      );
      expect(find.byKey(const ValueKey('fee-due')), findsNothing);
      expect(find.byKey(const ValueKey('fee-rule')), findsNothing);
      expect(markFee, findsOneWidget, reason: 'she can still pay it');
    });

    testWidgets('on hold it says so, and she can still record her payment', (
      tester,
    ) async {
      await open(tester, [
        statement(
          dueAt: now.subtract(const Duration(days: 5)),
          holdAt: now.subtract(const Duration(days: 1)),
          onHold: true,
        ),
      ]);
      expect(
        textOf(tester, 'fee-hold'),
        'Your account is on hold. It ends when Own Hub confirms this fee.',
      );
      expect(find.byKey(const ValueKey('fee-late')), findsNothing);
      expect(markFee, findsOneWidget);
    });

    testWidgets('disputed, settled and waived fees are listed, not counted', (
      tester,
    ) async {
      await open(tester, [
        statement(
          lines: [
            line('p1'),
            line('p2', fee: 3000, state: 'disputed'),
            line('p3', fee: 2000, state: 'settled'),
            line('p4', fee: 1000, state: 'waived'),
          ],
        ),
      ]);
      expect(textOf(tester, 'fee-total'), '75 EGP');
      expect(find.text('Disputed, pending'), findsOneWidget);
      expect(find.text('30 EGP'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('20 EGP'), findsOneWidget);
      expect(find.text('Waived'), findsOneWidget);
      expect(find.text('10 EGP'), findsOneWidget);
      expect(
        find.text('30 EGP fee on 500 EGP\nDisputed, pending'),
        findsOneWidget,
      );
      expect(find.text('20 EGP fee on 500 EGP\nSettled'), findsOneWidget);
      expect(find.text('10 EGP fee on 500 EGP\nWaived'), findsOneWidget);
    });

    testWidgets('nothing disputed, settled or waived: no such rows', (
      tester,
    ) async {
      await open(tester, [statement()]);
      expect(find.byKey(const ValueKey('fee-disputed')), findsNothing);
      expect(find.byKey(const ValueKey('fee-settled')), findsNothing);
      expect(find.byKey(const ValueKey('fee-waived')), findsNothing);
    });

    testWidgets('a line with no reference shows the payment tag', (
      tester,
    ) async {
      await open(tester, [
        statement(
          lines: [const FeeLine(paymentId: 'abcdef12', feePiasters: 7500)],
        ),
      ]);
      expect(find.text('#ef12'), findsOneWidget);
    });

    testWidgets('every owed fee already disputed: nothing to pay yet', (
      tester,
    ) async {
      await open(tester, [
        statement(lines: [line('p1', state: 'disputed')]),
      ]);
      expect(textOf(tester, 'fee-total'), '0 EGP');
      expect(markFee, findsNothing);
      expect(find.byKey(const ValueKey('fee-address')), findsNothing);
    });
  });

  group('Mark fee as paid', () {
    testWidgets('Send stays off until the number has six letters or digits', (
      tester,
    ) async {
      await open(tester, [statement()]);
      await openSheet(tester);
      expect(sendOn(tester), isFalse);
      await typeTxn(tester, '12345');
      expect(sendOn(tester), isFalse);
      await typeTxn(tester, '12-34 5');
      expect(sendOn(tester), isFalse, reason: 'separators are not counted');
      await typeTxn(tester, 'AB12CD');
      expect(sendOn(tester), isTrue, reason: 'letters count too');
    });

    testWidgets('sends the statement id and the number once, then says it '
        'was recorded', (tester) async {
      final fake = await open(tester, [statement()]);
      await openSheet(tester);
      await typeTxn(tester, ' 555566667777 ');
      await tester.tap(sendFee);
      await tester.pumpAndSettle();
      expect(fake.names, ['recordFeePayment']);
      expect(fake.calls.single.$2, {
        'id': 'coach__2026-10',
        'txn': '555566667777',
      });
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l10n.recordedOwnHubWillConfirmIt), findsOneWidget);
    });

    testWidgets('Arabic-Indic digits go to the server as Latin digits', (
      tester,
    ) async {
      final fake = await open(tester, [statement()]);
      await openSheet(tester);
      await typeTxn(tester, '٥٥٥٥٦٦٦٦٧٧٧٧');
      await tester.tap(sendFee);
      await tester.pumpAndSettle();
      expect(fake.calls.single.$2['txn'], '555566667777');
    });

    for (final e in {
      'txn_reused': l10n.thisTransactionNumberWasAlreadyUsed,
      'bad_request': l10n.pleaseCheckTheTransactionNumberFromYour_653l2,
      'wrong_status': l10n.thisStatementChangedGoBackAndOpen,
      'payment_not_found': l10n.thisStatementChangedGoBackAndOpen,
      'permission_denied': l10n.weCouldNotDoThatTryAgain,
    }.entries) {
      testWidgets('refused with ${e.key}: a calm line on the sheet, never '
          'the code', (tester) async {
        final fake = _Refuses(PaymentFailure(e.key));
        await open(tester, [statement()], repo: fake);
        await openSheet(tester);
        await typeTxn(tester, '555566667777');
        await tester.tap(sendFee);
        await tester.pumpAndSettle();
        expect(find.text(e.value), findsOneWidget);
        expect(find.textContaining(e.key), findsNothing);
        expect(sendFee, findsOneWidget, reason: 'she can fix it and retry');
        expect(sendOn(tester), isTrue);
      });
    }

    testWidgets('no signal: it says it could not reach Own Hub', (
      tester,
    ) async {
      final fake = _Refuses(const PaymentFailure('', unreachable: true));
      await open(tester, [statement()], repo: fake);
      await openSheet(tester);
      await typeTxn(tester, '555566667777');
      await tester.tap(sendFee);
      await tester.pumpAndSettle();
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });

    test('feeFailureText never returns a raw code', () {
      for (final code in [
        'bad_request',
        'wrong_status',
        'payment_not_found',
        'txn_reused',
        'permission_denied',
        '',
      ]) {
        final text = feeFailureText(l10n, PaymentFailure(code));
        expect(text, isNotEmpty);
        if (code.isNotEmpty) expect(text, isNot(contains(code)));
      }
      expect(
        feeFailureText(AppL10nAr(), const PaymentFailure('bad_request')),
        isNot(feeFailureText(l10n, const PaymentFailure('bad_request'))),
      );
    });
  });

  group('the other states', () {
    testWidgets('marked as paid: the number is shown, no primary, no pay-to', (
      tester,
    ) async {
      await open(tester, [
        statement(status: 'paid_claimed', claimedTxn: '555566667777'),
      ]);
      expect(textOf(tester, 'fee-status'), 'Paid. Own Hub will confirm.');
      expect(textOf(tester, 'fee-claimed-txn'), '555566667777');
      expect(markFee, findsNothing);
      expect(find.byKey(const ValueKey('fee-address')), findsNothing);
      expect(find.byKey(const ValueKey('fee-late')), findsNothing);
    });

    testWidgets('paid: confirmed, no primary, no pay-to', (tester) async {
      await open(tester, [
        statement(
          status: 'paid',
          lines: [line('p1', state: 'settled')],
          total: 0,
        ),
      ]);
      expect(textOf(tester, 'fee-status'), 'Paid and confirmed.');
      expect(markFee, findsNothing);
      expect(find.byKey(const ValueKey('fee-address')), findsNothing);
      expect(find.byKey(const ValueKey('fee-settled')), findsOneWidget);
    });

    testWidgets('no statement yet says when the first comes', (tester) async {
      await open(tester, const []);
      expect(
        find.text(
          'No fee bill yet. One is made each time a client payment is confirmed.',
        ),
        findsOneWidget,
      );
      expect(markFee, findsNothing);
    });

    testWidgets('loading shows a spinner', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        host(FeeStatementView(repository: FakePaymentsRepository())),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('offline: a stream error says it could not reach Own Hub', (
      tester,
    ) async {
      await open(
        tester,
        const [],
        repo: _Failing(const PaymentFailure('', unreachable: true)),
      );
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
      expect(markFee, findsNothing);
    });

    testWidgets('a refused read shows the calm generic line', (tester) async {
      await open(
        tester,
        const [],
        repo: _Failing(const PaymentFailure('permission_denied')),
      );
      expect(find.byKey(const ValueKey('statements-failure')), findsOneWidget);
      expect(find.textContaining('permission'), findsNothing);
    });
  });

  test('the coach space notice: due within a day, late, or nothing', () {
    FeeStatement bill({
      required Duration due,
      Duration hold = const Duration(days: 4),
      bool onHold = false,
      String status = 'open',
      int total = 7500,
    }) => FeeStatement(
      id: 'x',
      status: status,
      totalDuePiasters: total,
      dueAt: now.add(due),
      holdAt: now.add(hold),
      onHold: onHold,
    );
    expect(feeNoticeFor([bill(due: const Duration(days: 2))], now), isNull);
    final soon = feeNoticeFor([bill(due: const Duration(hours: 20))], now)!;
    expect(soon.late, isFalse);
    expect(soon.holdOn, now.add(const Duration(days: 4)));
    final late = feeNoticeFor([bill(due: const Duration(hours: -2))], now)!;
    expect(late.late, isTrue);
    expect(
      feeNoticeFor([
        bill(due: const Duration(hours: -2)),
        bill(due: const Duration(days: -5), onHold: true),
      ], now),
      isNull,
      reason: 'an account on hold has its own banner',
    );
    expect(
      feeNoticeFor([bill(due: const Duration(hours: -2), total: 0)], now),
      isNull,
    );
    expect(
      feeNoticeFor([bill(due: const Duration(hours: -2), status: 'paid')], now),
      isNull,
    );
  });

  test('a bill that owes nothing is not an account on hold', () {
    FeeStatement read(Map<String, Object?> m) => FeeStatement.fromMap(
      'b',
      <String, Object?>{'status': 'open', 'overdueNotified': true, ...m},
    )!;
    expect(read(<String, Object?>{'totalDuePiasters': 7500}).onHold, isTrue);
    expect(read(<String, Object?>{'totalDuePiasters': 0}).onHold, isFalse);
    expect(read(<String, Object?>{'status': 'paid'}).onHold, isFalse);
  });

  test('the coach space notice: due soon, late, and silent once held', () {
    FeeStatement bill({
      required Duration due,
      bool onHold = false,
      int total = 7500,
    }) => FeeStatement(
      id: 'b',
      status: 'open',
      totalDuePiasters: total,
      dueAt: now.add(due),
      holdAt: now.add(due + const Duration(days: 4)),
      onHold: onHold,
    );
    expect(feeNoticeFor([bill(due: const Duration(days: 2))], now), isNull);
    final soon = feeNoticeFor([bill(due: const Duration(hours: 20))], now)!;
    expect(soon.late, isFalse);
    final late = feeNoticeFor([bill(due: const Duration(hours: -1))], now)!;
    expect(late.late, isTrue);
    expect(
      feeNoticeFor([bill(due: const Duration(hours: -1), onHold: true)], now),
      isNull,
    );
    expect(
      feeNoticeFor([bill(due: const Duration(hours: -1), total: 0)], now),
      isNull,
    );
  });

  group('a bill for one payment', () {
    FeeStatement bill(String id, String pay, DateTime owed) => FeeStatement(
      id: 'coach__$id',
      year: 2026,
      month: 10,
      status: 'open',
      totalDuePiasters: 7500,
      lines: [
        FeeLine(
          paymentId: pay,
          reference: 'OH-$pay',
          basePiasters: 50000,
          feePiasters: 7500,
          feeState: 'owed',
          owedAt: owed,
        ),
      ],
      payTo: const FeePayTo(address: 'ownhub@instapay'),
      dueAt: now.add(const Duration(days: 2)),
      holdAt: now.add(const Duration(days: 6)),
    );

    testWidgets('is titled by the day the fee became owed, and a push opens '
        'the exact one', (tester) async {
      phone(tester);
      final fake = FakePaymentsRepository(uid: 'coach')
        ..statements = [
          bill('pa', 'pa', DateTime.utc(2026, 10, 12, 9)),
          bill('pb', 'pb', DateTime.utc(2026, 10, 20, 9)),
        ];
      await tester.pumpWidget(
        host(
          FeeStatementView(repository: fake, now: () => now, initialBill: 'pb'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Fee bill of 20/10/2026'), findsOneWidget);
      expect(find.text('12/10/2026'), findsOneWidget);
    });
  });

  group('other months', () {
    final older = statement(
      id: 'coach__2026-09',
      month: 9,
      lines: [line('q1', fee: 12000)],
      dueAt: now.subtract(const Duration(days: 12)),
    );
    final paidMonth = statement(
      id: 'coach__2026-08',
      month: 8,
      status: 'paid',
      lines: [line('r1', state: 'settled')],
      total: 0,
    );

    testWidgets('are listed with their total and state, the newest shown', (
      tester,
    ) async {
      await open(tester, [statement(), older, paidMonth]);
      expect(find.text('Other months'), findsOneWidget);
      expect(find.text('2026-09'), findsOneWidget);
      expect(find.text('120 EGP · Due'), findsOneWidget);
      expect(find.text('0 EGP · Paid'), findsOneWidget);
      expect(find.text('Fee for 2026-10'), findsOneWidget);
      expect(find.byKey(const ValueKey('month-coach__2026-10')), findsNothing);
    });

    testWidgets('a tap shows that month, so an older unpaid one can be paid', (
      tester,
    ) async {
      final fake = await open(tester, [statement(), older, paidMonth]);
      await pickMonth(tester, 'coach__2026-09');
      expect(find.text('Fee for 2026-09'), findsOneWidget);
      expect(textOf(tester, 'fee-total'), '120 EGP');
      expect(find.byKey(const ValueKey('fee-late')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('month-coach__2026-10')),
        findsOneWidget,
      );
      await openSheet(tester);
      await typeTxn(tester, '555566667777');
      await tester.tap(sendFee);
      await tester.pumpAndSettle();
      expect(fake.calls.single.$2['id'], 'coach__2026-09');
    });

    testWidgets('a paid month has no primary', (tester) async {
      await open(tester, [statement(), paidMonth]);
      await pickMonth(tester, 'coach__2026-08');
      expect(find.text('Fee for 2026-08'), findsOneWidget);
      expect(markFee, findsNothing);
    });

    testWidgets('a single statement has no such list', (tester) async {
      await open(tester, [statement()]);
      expect(find.text('Other months'), findsNothing);
    });
  });

  testWidgets('Arabic: Western digits, the address left to right', (
    tester,
  ) async {
    await open(tester, [statement()], lang: 'ar');
    final all = [
      for (final e in find.byType(Text).evaluate())
        (e.widget as Text).data ?? '',
    ].join(' ');
    expect(RegExp(r'[٠-٩]').hasMatch(all), isFalse);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('fee-address')))
          .textDirection,
      TextDirection.ltr,
    );
    expect(find.text('Fee for 2026-10'), findsNothing);
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        final where = '$lang at ${scale}x on ${small ? '375x667' : '390x844'}';
        testWidgets('budget and layout, $where', (tester) async {
          final states = <(String, List<FeeStatement>)>[
            (
              'open with other months',
              [
                statement(),
                statement(id: 'coach__2026-09', month: 9),
                statement(id: 'coach__2026-08', month: 8, status: 'paid'),
              ],
            ),
            (
              'late, no address',
              [
                statement(
                  payTo: const FeePayTo(),
                  dueAt: now.subtract(const Duration(days: 3)),
                ),
              ],
            ),
            (
              'disputed, settled and waived lines',
              [
                statement(
                  lines: [
                    line('p1'),
                    line('p2', state: 'disputed'),
                    line('p3', state: 'settled'),
                    line('p4', state: 'waived'),
                  ],
                ),
              ],
            ),
            (
              'marked as paid',
              [statement(status: 'paid_claimed', claimedTxn: '555566667777')],
            ),
            ('paid', [statement(status: 'paid', total: 0)]),
            ('empty', const <FeeStatement>[]),
          ];
          for (final (name, list) in states) {
            await open(tester, list, lang: lang, scale: scale, small: small);
            await tester.pumpAndSettle();
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
              reason: name,
            );
            expect(
              filledPrimaryActions(tester),
              lessThanOrEqualTo(1),
              reason: name,
            );
            expect(tester.takeException(), isNull, reason: name);
            await tester.pumpWidget(const SizedBox());
          }
        });

        testWidgets('budget and layout of the sheet, $where', (tester) async {
          await open(
            tester,
            [statement()],
            lang: lang,
            scale: scale,
            small: small,
          );
          await openSheet(tester);
          await typeTxn(tester, '555566667777');
          expect(sendOn(tester), isTrue);
          expect(
            countControlsAboveFold(tester, includeChrome: false),
            lessThanOrEqualTo(5),
          );
          expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
