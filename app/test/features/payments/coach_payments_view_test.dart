import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/coach_payments_view.dart';
import 'package:own_hub/features/payments/presentation/payment_record_view.dart';
import 'package:own_hub/features/payments/presentation/payment_text.dart';
import 'package:own_hub/features/payments/presentation/proof_flow.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/desk_model.dart'
    show tagOf;
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_list_item.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import '../private_coaching/coach/coach_fake.dart';
import '../private_coaching/support/fake_coaching_repository.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final now = DateTime.utc(2026, 10, 27, 12);
final sent = DateTime.utc(2026, 10, 27, 11, 32);
final l10n = AppL10nEn();

/// A 1x1 picture, so an evidence image has something to draw.
final Uint8List onePixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

Payment waitingPayment(
  String id, {
  RiskOutcome outcome = RiskOutcome.green,
  String reference = 'OH-4821',
  int amount = 50037,
  String txn = '123456789012',
  List<String> shots = const <String>[],
  DateTime? at,
}) => payment(
  id: id,
  status: PaymentStatus.proofSubmitted,
  subId: 'sub-$id',
  clientUid: 'client-$id',
  outcome: outcome,
  reference: reference,
  amountPiasters: amount,
  txnNumber: txn,
  submittedAt: at ?? sent,
  paidAtClaimed: at ?? sent,
  screenshotPaths: shots,
);

Payment settled(String id, PaymentStatus status, {String kind = ''}) => payment(
  id: id,
  status: status,
  subId: 'sub-$id',
  clientUid: 'client-$id',
  reference: 'OH-$id',
  disputeKind: kind,
);

Payment refundAsked(String id, {required DateTime asked, DateTime? due}) =>
    payment(
      id: id,
      status: PaymentStatus.refundRequested,
      subId: 'sub-$id',
      clientUid: 'client-$id',
      reference: 'OH-$id',
      refundRequestedAt: asked,
      refundCoachDueAt: due,
    );

Payment owed(String id, {required int piasters, DateTime? due}) => payment(
  id: id,
  status: PaymentStatus.inReview,
  subId: 'sub-$id',
  clientUid: 'client-$id',
  reference: 'OH-$id',
  disputeKind: 'refund',
  disputeStaffDecision: 'refund_owed',
  refundOwedPiasters: piasters,
  refundOwedDueAt: due,
);

PrivateCoachingState namedClients(Map<String, String> bySubId) {
  final repo = FakeCoachingRepository(uid: 'coach')
    ..coachSubs.value = [
      for (final e in bySubId.entries)
        Subscription(
          id: e.key,
          coachUid: 'coach',
          clientUid: 'client-${e.key}',
          status: SubscriptionStatus.active,
          clientName: e.value,
        ),
    ];
  return PrivateCoachingState.forTest()..start(repo, isCoach: true);
}

Future<FakePaymentsRepository> openInbox(
  WidgetTester tester,
  List<Payment> payments, {
  CoachAddress? address = const CoachAddress(
    address: 'rahma.m@instapay',
    accountName: 'Rahma M.',
  ),
  PrivateCoachingState? coaching,
  FakePaymentsRepository? repo,
  String lang = 'en',
  double scale = 1,
  bool small = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = repo ?? FakePaymentsRepository(uid: 'coach');
  fake
    ..address = address
    ..setPayments(payments);
  await tester.pumpWidget(
    host(
      CoachPaymentsView(
        repository: fake,
        coaching: coaching ?? PrivateCoachingState.forTest(),
        now: () => now,
        picker: () async => [
          Uint8List.fromList([1, 2, 3]),
        ],
        prepare: (context, raw, expected) async => PreparedImage(raw, ''),
      ),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

bool sendEnabled(WidgetTester tester) =>
    tester
        .widget<AppButton>(find.byKey(const ValueKey('report-send')))
        .onPressed !=
    null;

Future<void> openMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const ValueKey('overflow-menu')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('overflow-row-$label')));
  await tester.pumpAndSettle();
}

class _Offline extends FakePaymentsRepository {
  _Offline(this.failure) : super(uid: 'coach');
  final PaymentFailure failure;
  @override
  Stream<List<Payment>> watchMyPaymentsAsCoach() =>
      Stream<List<Payment>>.error(failure);
}

void main() {
  testWidgets('loading shows a spinner, not a blank screen', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      host(CoachPaymentsView(repository: FakePaymentsRepository(uid: 'coach'))),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('the list', () {
    testWidgets('waiting payments come first, with a pill each', (
      tester,
    ) async {
      await openInbox(tester, [
        waitingPayment('p1'),
        waitingPayment('p2', outcome: RiskOutcome.amber, reference: 'OH-9'),
        settled('p3', PaymentStatus.confirmed),
      ], coaching: namedClients({'sub-p1': 'Mona Adel'}));
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.byKey(const ValueKey('waiting-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('waiting-p2')), findsOneWidget);
      expect(find.text('Mona Adel'), findsOneWidget);
      expect(find.text('Matches'), findsOneWidget);
      expect(find.text('Check your bank'), findsOneWidget);
      expect(
        find.text('OH-4821 · 500.37 EGP · proof sent ${cairoStamp(sent)}'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('waiting-p1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('earlier-p3'))).dy,
        ),
      );
      // Two are waiting, so nothing opens by itself.
      expect(find.byKey(const ValueKey('look-for')), findsNothing);
    });

    testWidgets('a client with no name shows her tag, never a uid', (
      tester,
    ) async {
      await openInbox(tester, [waitingPayment('p1'), waitingPayment('p2')]);
      expect(find.text('Client ${tagOf('client-p1')}'), findsOneWidget);
      expect(find.text('Client ${tagOf('client-p2')}'), findsOneWidget);
      expect(find.textContaining('client-p1'), findsNothing);
    });

    testWidgets('the oldest proof is on top', (tester) async {
      await openInbox(tester, [
        waitingPayment('new', at: sent),
        waitingPayment('old', at: sent.subtract(const Duration(hours: 5))),
      ]);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('waiting-old'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('waiting-new'))).dy,
        ),
      );
    });

    testWidgets('Earlier keeps the last ten settled ones in her voice', (
      tester,
    ) async {
      await openInbox(tester, [
        waitingPayment('w1'),
        waitingPayment('w2'),
        for (var i = 0; i < 12; i++) settled('s$i', PaymentStatus.confirmed),
        settled('nr', PaymentStatus.coachNotReceived),
        payment(id: 'unpaid', status: PaymentStatus.awaitingPayment),
        payment(id: 'gone', status: PaymentStatus.cancelled),
      ]);
      expect(find.text('Earlier'), findsOneWidget);
      final earlier = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('earlier-'),
      );
      expect(earlier, findsNWidgets(10));
      expect(find.byKey(const ValueKey('earlier-unpaid')), findsNothing);
      expect(find.byKey(const ValueKey('earlier-gone')), findsNothing);
      expect(find.textContaining('Your coach says'), findsNothing);
    });

    testWidgets('a payment that confirmed itself within 48 hours opens the '
        'not-received sheet, any other confirmed one its record', (
      tester,
    ) async {
      Payment confirmed(
        String id, {
        required bool auto,
        required int hoursAgo,
      }) => payment(
        id: id,
        status: PaymentStatus.confirmed,
        autoConfirmed: auto,
        confirmedAt: now.subtract(Duration(hours: hoursAgo)),
      );
      await openInbox(tester, [
        confirmed('fresh', auto: true, hoursAgo: 10),
        confirmed('stale', auto: true, hoursAgo: 49),
        confirmed('byhand', auto: false, hoursAgo: 10),
      ]);
      bool opens(String id) =>
          tester
              .widget<AppListItem>(find.byKey(ValueKey('earlier-$id')))
              .onTap !=
          null;
      expect(opens('fresh'), isTrue);
      expect(opens('stale'), isTrue);
      expect(opens('byhand'), isTrue);
      await tester.tap(find.byKey(const ValueKey('earlier-stale')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentRecordView), findsOneWidget);
      expect(find.byKey(const ValueKey('reason-not_seen')), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('earlier-fresh')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reason-not_seen')), findsOneWidget);
      expect(find.byType(PaymentRecordView), findsNothing);
    });

    testWidgets('the record of an earlier confirmed payment names nobody', (
      tester,
    ) async {
      await openInbox(tester, [
        settled('s1', PaymentStatus.confirmed),
      ], coaching: namedClients({'sub-s1': 'Mona Adel'}));
      await tester.tap(find.byKey(const ValueKey('earlier-s1')));
      await tester.pumpAndSettle();
      expect(find.byType(PaymentRecordView), findsOneWidget);
      expect(find.text('Mona Adel'), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('rec-client'))).data,
        tagOf('client-s1'),
      );
    });

    testWidgets('only a confirmed payment has a record: the rest do not open', (
      tester,
    ) async {
      await openInbox(tester, [
        settled('nr', PaymentStatus.coachNotReceived),
        settled('rv', PaymentStatus.inReview, kind: 'proof_red'),
        settled('rf', PaymentStatus.refunded),
        settled('ok', PaymentStatus.resolvedPaid),
      ]);
      bool opens(String id) =>
          tester
              .widget<AppListItem>(find.byKey(ValueKey('earlier-$id')))
              .onTap !=
          null;
      expect(opens('nr'), isFalse);
      expect(opens('rv'), isFalse);
      expect(opens('rf'), isFalse);
      expect(opens('ok'), isTrue);
    });

    testWidgets('a coach-opened dispute reads "You said it has not arrived"', (
      tester,
    ) async {
      await openInbox(tester, [
        settled('p1', PaymentStatus.inReview, kind: 'not_received'),
        settled('p2', PaymentStatus.coachNotReceived),
      ]);
      expect(
        find.textContaining('You said it has not arrived'),
        findsNWidgets(2),
      );
      expect(find.textContaining('Your coach says'), findsNothing);
    });

    testWidgets('nothing waiting says so in a calm note', (tester) async {
      await openInbox(tester, [settled('p1', PaymentStatus.confirmed)]);
      expect(find.text('Nothing is waiting for you.'), findsOneWidget);
      expect(find.byKey(const ValueKey('look-for')), findsNothing);
    });

    testWidgets('no address shows the card, an address hides it', (
      tester,
    ) async {
      await openInbox(tester, const [], address: null);
      expect(find.byKey(const ValueKey('add-address')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await openInbox(tester, const []);
      expect(find.byKey(const ValueKey('add-address')), findsNothing);
    });

    testWidgets('the add-address button opens the address screen', (
      tester,
    ) async {
      await openInbox(tester, const [], address: null);
      await tester.tap(find.byKey(const ValueKey('add-address')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('address-primary')), findsOneWidget);
    });

    testWidgets('a refund request has its own section, not Earlier', (
      tester,
    ) async {
      final asked = now.subtract(const Duration(days: 1));
      final due = asked.add(const Duration(days: 3));
      await openInbox(tester, [
        refundAsked('p1', asked: asked, due: due),
        settled('p2', PaymentStatus.confirmed),
      ], coaching: namedClients({'sub-p1': 'Mona Adel'}));
      expect(find.text('Refund requests'), findsOneWidget);
      expect(find.byKey(const ValueKey('refund-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('earlier-p1')), findsNothing);
      expect(find.byKey(const ValueKey('earlier-p2')), findsOneWidget);
      expect(find.text('Mona Adel'), findsOneWidget);
      expect(
        find.text(
          'OH-p1 · 500.37 EGP\nAsked ${cairoStamp(asked)}. '
          'Answer by ${cairoStamp(due)}.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('refund-p1'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('earlier-p2'))).dy,
        ),
      );
    });

    testWidgets('a refund Own Hub ordered is in the refund section, with the '
        'sum and the day, never in Earlier', (tester) async {
      final due = now.add(const Duration(days: 5));
      await openInbox(tester, [
        owed('p1', piasters: 20000, due: due),
        settled('p2', PaymentStatus.confirmed),
      ], coaching: namedClients({'sub-p1': 'Mona Adel'}));
      expect(find.text('Refund requests'), findsOneWidget);
      expect(find.byKey(const ValueKey('refund-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('earlier-p1')), findsNothing);
      expect(find.text('Earlier'), findsOneWidget, reason: 'p2 is still there');
      expect(find.text('Mona Adel'), findsOneWidget);
      expect(
        find.text(
          'OH-p1 · 200 EGP\nOwn Hub decided you owe a refund. Send it by '
          '${cairoDate(due)}.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an ordered refund past its day says it was due', (
      tester,
    ) async {
      final due = now.subtract(const Duration(days: 1));
      await openInbox(tester, [owed('p1', piasters: 20000, due: due)]);
      expect(
        find.textContaining(
          'Own Hub decided you owe a refund. It was due on ${cairoDate(due)}.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Send it by'), findsNothing);
    });

    testWidgets('a review that is not a refund order stays in Earlier', (
      tester,
    ) async {
      await openInbox(tester, [
        payment(
          id: 'p1',
          status: PaymentStatus.inReview,
          subId: 'sub-p1',
          clientUid: 'client-p1',
          reference: 'OH-p1',
          disputeStaffDecision: 'reopen',
          refundOwedPiasters: 20000,
        ),
      ]);
      expect(find.text('Refund requests'), findsNothing);
      expect(find.byKey(const ValueKey('earlier-p1')), findsOneWidget);
    });

    testWidgets('a tap opens the sheet with the ordered sum locked, and '
        'recording sends exactly that sum', (tester) async {
      final fake = await openInbox(tester, [
        owed('p1', piasters: 20050, due: now.add(const Duration(days: 5))),
      ]);
      await tester.tap(find.byKey(const ValueKey('refund-p1')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('refund-owed-amount')))
            .data,
        '200.50',
      );
      expect(find.byKey(const ValueKey('refund-amount')), findsNothing);
      expect(find.byKey(const ValueKey('deny-refund')), findsNothing);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('refund-txn')),
          matching: find.byType(TextField),
        ),
        '1234567890123',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record-refund')));
      await tester.pumpAndSettle();
      expect(fake.names, ['recordRefund']);
      expect(fake.calls.single.$2['amount'], 20050);
      expect(fake.calls.single.$2['kind'], 'refund');
      expect(find.text(l10n.sentYourClientWillSeeIt), findsOneWidget);
    });

    testWidgets('no refund request, no section', (tester) async {
      await openInbox(tester, [settled('p1', PaymentStatus.confirmed)]);
      expect(find.text('Refund requests'), findsNothing);
    });

    testWidgets('the due date is three days after the request when the '
        'document has none', (tester) async {
      final asked = now.subtract(const Duration(hours: 5));
      await openInbox(tester, [refundAsked('p1', asked: asked)]);
      expect(
        find.textContaining(
          'Answer by ${cairoStamp(asked.add(const Duration(days: 3)))}.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('past the due date it says Own Hub may step in', (
      tester,
    ) async {
      final asked = now.subtract(const Duration(days: 4));
      final due = asked.add(const Duration(days: 3));
      await openInbox(tester, [refundAsked('p1', asked: asked, due: due)]);
      expect(
        find.textContaining(
          'The answer was due ${cairoStamp(due)}. Own Hub may step in.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Answer by'), findsNothing);
    });

    testWidgets('a refunded payment is final: listed once, no action', (
      tester,
    ) async {
      await openInbox(tester, [
        settled('r1', PaymentStatus.refunded),
        settled('d1', PaymentStatus.refundDenied),
      ]);
      expect(find.byKey(const ValueKey('refund-r1')), findsNothing);
      expect(find.text('Refund requests'), findsNothing);
      for (final id in ['r1', 'd1']) {
        final row = tester.widget<AppListItem>(
          find.byKey(ValueKey('earlier-$id')),
        );
        expect(row.onTap, isNull, reason: id);
      }
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('a tap opens the sheet and recording says the client will '
        'see it', (tester) async {
      final fake = await openInbox(tester, [
        refundAsked('p1', asked: now.subtract(const Duration(days: 1))),
      ], coaching: namedClients({'sub-p1': 'Mona Adel'}));
      await tester.tap(find.byKey(const ValueKey('refund-p1')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Mona Adel · OH-p1 · 500.37 EGP'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('refund-txn')),
          matching: find.byType(TextField),
        ),
        '1234567890123',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record-refund')));
      await tester.pumpAndSettle();
      expect(fake.names, ['recordRefund']);
      expect(fake.calls.single.$2['id'], 'p1');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text(l10n.sentYourClientWillSeeIt), findsOneWidget);
    });

    testWidgets('closing the sheet changes nothing and says nothing', (
      tester,
    ) async {
      final fake = await openInbox(tester, [
        refundAsked('p1', asked: now.subtract(const Duration(days: 1))),
      ]);
      await tester.tap(find.byKey(const ValueKey('refund-p1')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(fake.calls, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('offline: a stream error says it could not reach Own Hub', (
      tester,
    ) async {
      await openInbox(
        tester,
        const [],
        repo: _Offline(const PaymentFailure('', unreachable: true)),
      );
      expect(
        find.byKey(const ValueKey('coach-payments-failure')),
        findsOneWidget,
      );
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });

    testWidgets('a refused read shows the calm generic line', (tester) async {
      await openInbox(
        tester,
        const [],
        repo: _Offline(const PaymentFailure('permission_denied')),
      );
      expect(find.text(l10n.weCouldNotDoThatTryAgain), findsOneWidget);
    });
  });

  group('the decision sheet', () {
    testWidgets('exactly one waiting payment opens it by itself', (
      tester,
    ) async {
      await openInbox(tester, [waitingPayment('p1')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('look-for')), findsOneWidget);
      expect(find.text('Look for exactly 500.37 EGP'), findsOneWidget);
      expect(find.text('Transaction number 123456789012'), findsOneWidget);
      expect(find.text('Paid at ${cairoStamp(sent)}'), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-green')), findsOneWidget);
    });

    testWidgets('two waiting payments do not open a sheet', (tester) async {
      await openInbox(tester, [waitingPayment('p1'), waitingPayment('p2')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('look-for')), findsNothing);
    });

    testWidgets('the sheet opens once, not again after she closes it', (
      tester,
    ) async {
      final fake = await openInbox(tester, [waitingPayment('p1')]);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(195, 20));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('look-for')), findsNothing);
      fake.setPayments([waitingPayment('p1')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('look-for')), findsNothing);
    });

    testWidgets('a row opens the sheet; an amber proof says to look closely', (
      tester,
    ) async {
      await openInbox(tester, [
        waitingPayment('p1', outcome: RiskOutcome.amber),
        waitingPayment('p2'),
      ]);
      await tester.tap(find.byKey(const ValueKey('waiting-p1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('sheet-amber')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-green')), findsNothing);
    });

    testWidgets('no transaction number and no claimed time: those lines go', (
      tester,
    ) async {
      await openInbox(tester, [
        payment(
          id: 'p1',
          status: PaymentStatus.proofSubmitted,
          outcome: RiskOutcome.green,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('look-for')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-txn')), findsNothing);
      expect(find.byKey(const ValueKey('sheet-paid-at')), findsNothing);
    });

    testWidgets('I received it confirms once and closes the sheet', (
      tester,
    ) async {
      final fake = await openInbox(tester, [
        waitingPayment('p1'),
        waitingPayment('p2'),
      ]);
      await tester.tap(find.byKey(const ValueKey('waiting-p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('received')));
      await tester.pumpAndSettle();
      expect(fake.names.where((n) => n == 'coachConfirm'), hasLength(1));
      expect(fake.calls.last.$2['id'], 'p1');
      expect(fake.calls.last.$2['received'], isNull);
      expect(find.byKey(const ValueKey('look-for')), findsNothing);
      expect(find.text('Confirmed. Your client can start.'), findsOneWidget);
    });

    for (final (reason, expected) in <(String, String)>[
      ('wrong_status', l10n.thisPaymentChangedRefreshAndTryAgain),
      ('illegal_transition', l10n.thisPaymentChangedRefreshAndTryAgain),
      ('payment_not_found', l10n.thisPaymentChangedRefreshAndTryAgain),
      ('something_new', l10n.weCouldNotDoThatTryAgain),
    ]) {
      testWidgets(
        'I received it refused with $reason: a calm line, sheet stays',
        (tester) async {
          final fake = await openInbox(tester, [waitingPayment('p1')]);
          await tester.pumpAndSettle();
          fake.failNext = PaymentFailure(reason);
          await tester.tap(find.byKey(const ValueKey('received')));
          await tester.pumpAndSettle();
          expect(find.text(expected), findsOneWidget);
          expect(find.byKey(const ValueKey('received')), findsOneWidget);
          expect(find.textContaining(reason), findsNothing);
        },
      );
    }

    testWidgets('no signal on I received it says it could not reach Own Hub', (
      tester,
    ) async {
      final fake = await openInbox(tester, [waitingPayment('p1')]);
      await tester.pumpAndSettle();
      fake.failNext = const PaymentFailure('', unreachable: true);
      await tester.tap(find.byKey(const ValueKey('received')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });

    testWidgets('Not received hands over to its own screen', (tester) async {
      await openInbox(tester, [waitingPayment('p1')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('not-received')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reason-not_seen')), findsOneWidget);
    });

    testWidgets('Different amount hands over to its own screen', (
      tester,
    ) async {
      await openInbox(tester, [waitingPayment('p1')]);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('different-amount')));
      await tester.pumpAndSettle();
      expect(find.text('How much did you receive?'), findsOneWidget);
    });

    testWidgets('the coach never gets a button to see the client proof', (
      tester,
    ) async {
      final fake = await openInbox(tester, [
        waitingPayment('p1', shots: ['payment-proofs/p1/client-a-1.jpg']),
      ]);
      fake.partyImageBytes = onePixel;
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('see-proof')), findsNothing);
      expect(find.byKey(const ValueKey('proof-picture')), findsNothing);
      expect(fake.names, isNot(contains('partyImage')));
      expect(find.byKey(const ValueKey('look-for')), findsOneWidget);
    });

    testWidgets('no pictures on the payment: still no button to see them', (
      tester,
    ) async {
      await openInbox(tester, [waitingPayment('p1')]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('see-proof')), findsNothing);
    });
  });

  group('auto-confirm', () {
    const eligible = CoachAddress(
      address: 'a@instapay',
      accountName: 'R',
      cleanConfirmed: 3,
    );

    testWidgets('hidden below three clean payments while it is off', (
      tester,
    ) async {
      await openInbox(
        tester,
        const [],
        address: const CoachAddress(
          address: 'a@instapay',
          accountName: 'R',
          cleanConfirmed: 2,
        ),
      );
      expect(find.byKey(const ValueKey('auto-confirm')), findsNothing);
    });

    testWidgets('shown at three, and flips through setAutoConfirm', (
      tester,
    ) async {
      final fake = await openInbox(tester, const [], address: eligible);
      expect(find.byKey(const ValueKey('auto-confirm')), findsOneWidget);
      expect(
        find.text(
          'Only payments that match. You can still flag one within 48 hours.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('auto-confirm')));
      await tester.pumpAndSettle();
      expect(fake.calls.last.$1, 'setAutoConfirm');
      expect(fake.calls.last.$2['enabled'], isTrue);
      await tester.tap(find.byKey(const ValueKey('auto-confirm')));
      await tester.pumpAndSettle();
      expect(fake.calls.last.$2['enabled'], isFalse);
      expect(fake.names.where((n) => n == 'setAutoConfirm'), hasLength(2));
    });

    testWidgets('already on stays visible so she can turn it off', (
      tester,
    ) async {
      await openInbox(
        tester,
        const [],
        address: const CoachAddress(
          address: 'a@instapay',
          accountName: 'R',
          autoConfirmGreen: true,
        ),
      );
      expect(find.byKey(const ValueKey('auto-confirm')), findsOneWidget);
    });

    testWidgets('auto_confirm_off says it is not available yet', (
      tester,
    ) async {
      final fake = await openInbox(tester, const [], address: eligible);
      fake.failNext = const PaymentFailure('auto_confirm_off');
      await tester.tap(find.byKey(const ValueKey('auto-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.automaticConfirmingIsNotAvailableToYou),
        findsOneWidget,
      );
    });

    testWidgets('wrong_status here means not enough clean payments', (
      tester,
    ) async {
      final fake = await openInbox(tester, const [], address: eligible);
      fake.failNext = const PaymentFailure('wrong_status');
      await tester.tap(find.byKey(const ValueKey('auto-confirm')));
      await tester.pumpAndSettle();
      expect(
        find.text('Automatic confirming opens after 3 payments that matched.'),
        findsOneWidget,
      );
      expect(
        find.text(l10n.thisPaymentChangedRefreshAndTryAgain),
        findsNothing,
      );
    });

    testWidgets('no signal on the switch says it could not reach Own Hub', (
      tester,
    ) async {
      final fake = await openInbox(tester, const [], address: eligible);
      fake.failNext = const PaymentFailure('', unreachable: true);
      await tester.tap(find.byKey(const ValueKey('auto-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });
  });

  group('A client paid me', () {
    testWidgets('lists only payments the server would find, then reports one', (
      tester,
    ) async {
      final fake = await openInbox(tester, [
        payment(id: 'open', clientUid: 'client-open', reference: 'OH-1111'),
        payment(
          id: 'late',
          status: PaymentStatus.expired,
          clientUid: 'client-late',
          reference: 'OH-2222',
          lateUntil: now.subtract(const Duration(days: 1)),
        ),
        payment(
          id: 'asked',
          clientUid: 'client-asked',
          reference: 'OH-3333',
          coachReportTxn: '123456789012',
        ),
        waitingPayment('w1', reference: 'OH-4444'),
        waitingPayment('w2', reference: 'OH-5555'),
      ]);
      await openMenuItem(tester, 'A client paid me');
      expect(find.byKey(const ValueKey('report-open')), findsOneWidget);
      expect(find.byKey(const ValueKey('report-late')), findsNothing);
      expect(find.byKey(const ValueKey('report-nolate')), findsNothing);
      expect(find.byKey(const ValueKey('report-asked')), findsNothing);
      expect(find.byKey(const ValueKey('report-w1')), findsNothing);
      expect(sendEnabled(tester), isFalse);
      await tester.tap(find.byKey(const ValueKey('report-open')));
      await tester.enterText(find.byType(TextField), '12345');
      await tester.pump();
      expect(sendEnabled(tester), isFalse);
      await tester.enterText(find.byType(TextField), '123456789012');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();
      expect(fake.calls.last.$1, 'coachReport');
      expect(fake.calls.last.$2['reference'], 'OH-1111');
      expect(fake.calls.last.$2['subId'], isNull);
      expect(fake.calls.last.$2['txn'], '123456789012');
      expect(
        find.text('Sent. Your client will be asked to confirm.'),
        findsOneWidget,
      );
    });

    testWidgets('nobody to report says so, and Send stays off', (tester) async {
      await openInbox(tester, [waitingPayment('w1'), waitingPayment('w2')]);
      await openMenuItem(tester, 'A client paid me');
      expect(
        find.text('No client has an open payment right now.'),
        findsOneWidget,
      );
      expect(sendEnabled(tester), isFalse);
    });

    testWidgets('a refusal stays on the sheet as a calm line', (tester) async {
      final fake = await openInbox(tester, [
        payment(id: 'open', reference: 'OH-1111'),
      ]);
      await openMenuItem(tester, 'A client paid me');
      await tester.tap(find.byKey(const ValueKey('report-open')));
      await tester.enterText(find.byType(TextField), '123456789012');
      await tester.pump();
      fake.failNext = const PaymentFailure('txn_reused');
      await tester.tap(find.byKey(const ValueKey('report-send')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.thisTransactionNumberWasAlreadyUsed),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('report-send')), findsOneWidget);
    });

    testWidgets('My address in the menu opens the address screen', (
      tester,
    ) async {
      await openInbox(tester, const []);
      await openMenuItem(tester, 'My InstaPay address');
      expect(find.byKey(const ValueKey('address-primary')), findsOneWidget);
    });
  });

  group('K18', () {
    testWidgets(
      'the Payments row shows with the flag on, even if new payments are paused',
      (tester) async {
        for (final given in [false, true]) {
          tester.view.physicalSize = const Size(390, 3600);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final coach = CoachRepo()
            ..coaches.value = [
              const CoachProfile(
                uid: 'me',
                displayName: 'Coach Sara',
                headline: 'Strength coach',
                approach: 'A simple plan around your week.',
                published: true,
                acceptingClients: true,
              ),
            ];
          var opened = 0;
          var statements = 0;
          await tester.pumpWidget(
            host(
              CoachSpaceView(
                repository: coach,
                instapayOn: false,
                onOpenPayments: given ? () => opened++ : null,
                onOpenStatements: given ? () => statements++ : null,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Payments'), given ? findsOneWidget : findsNothing);
          expect(
            find.text('Fee bills'),
            given ? findsOneWidget : findsNothing,
          );
          expect(find.text('My InstaPay address'), findsNothing);
          if (given) {
            await tester.tap(find.text('Payments'));
            expect(opened, 1);
            await tester.tap(find.text('Fee bills'));
            expect(statements, 1);
          }
          await tester.pumpWidget(const SizedBox());
        }
      },
    );
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        final where = '$lang at ${scale}x on ${small ? '375x667' : '390x844'}';
        testWidgets('budget and layout of the list, $where', (tester) async {
          final states = <(String, List<Payment>, CoachAddress?)>[
            (
              'waiting, earlier, address, auto-confirm',
              [
                waitingPayment('p1'),
                waitingPayment('p2', outcome: RiskOutcome.amber),
                settled('p3', PaymentStatus.confirmed),
                settled('p4', PaymentStatus.inReview, kind: 'not_received'),
              ],
              const CoachAddress(
                address: 'a@instapay',
                accountName: 'R',
                cleanConfirmed: 5,
                autoConfirmGreen: true,
              ),
            ),
            (
              'refund requests above earlier, with the switch on',
              [
                waitingPayment('p1'),
                waitingPayment('p2'),
                refundAsked('p5', asked: now.subtract(const Duration(days: 1))),
                refundAsked('p6', asked: now.subtract(const Duration(days: 4))),
                settled('p3', PaymentStatus.refunded),
              ],
              const CoachAddress(
                address: 'a@instapay',
                accountName: 'R',
                cleanConfirmed: 5,
                autoConfirmGreen: true,
              ),
            ),
            (
              'an ordered refund above earlier',
              [
                owed(
                  'p7',
                  piasters: 20000,
                  due: now.add(const Duration(days: 5)),
                ),
                owed(
                  'p8',
                  piasters: 20000,
                  due: now.subtract(const Duration(days: 1)),
                ),
                settled('p3', PaymentStatus.confirmed),
              ],
              null,
            ),
            (
              'waiting and earlier with no address',
              [
                waitingPayment('p1'),
                waitingPayment('p2'),
                settled('p3', PaymentStatus.confirmed),
              ],
              null,
            ),
            ('empty with no address', const <Payment>[], null),
          ];
          for (final (name, payments, address) in states) {
            await openInbox(
              tester,
              payments,
              address: address,
              lang: lang,
              scale: scale,
              small: small,
            );
            await tester.pumpAndSettle();
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
              reason: name,
            );
            expect(filledPrimaryActions(tester), 0, reason: name);
            expect(tester.takeException(), isNull, reason: name);
            await tester.pumpWidget(const SizedBox());
          }
        });

        testWidgets('budget and layout of the sheet, $where', (tester) async {
          await openInbox(
            tester,
            [
              waitingPayment('p1', shots: ['a.jpg']),
              waitingPayment('p2'),
            ],
            lang: lang,
            scale: scale,
            small: small,
          );
          await tester.tap(find.byKey(const ValueKey('waiting-p1')));
          await tester.pumpAndSettle();
          expect(find.byKey(const ValueKey('look-for')), findsOneWidget);
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
}
