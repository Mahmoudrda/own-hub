import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/payment_view.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final fixedNow = DateTime.utc(2026, 10, 27, 12);

Future<FakePaymentsRepository> open(
  WidgetTester tester, {
  FakePaymentsRepository? repo,
  ValueChanged<Payment>? onPaid,
  ValueChanged<Payment>? onInProgress,
  Future<bool> Function(Uri)? opener,
  String? topUpOf,
  String lang = 'en',
  double scale = 1,
  bool small = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = repo ?? FakePaymentsRepository();
  await tester.pumpWidget(
    host(
      PaymentView(
        subId: 'sub1',
        repository: fake,
        now: () => fixedNow,
        onIHavePaid: onPaid ?? (_) {},
        onInProgress: onInProgress,
        opener: opener ?? (_) async => true,
        topUpOf: topUpOf,
      ),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return fake;
}

void main() {
  testWidgets('loading, then the amount, name, address and reference', (
    tester,
  ) async {
    phone(tester);
    final fake = FakePaymentsRepository();
    await tester.pumpWidget(
      host(
        PaymentView(
          subId: 'sub1',
          repository: fake,
          now: () => fixedNow,
          onIHavePaid: (_) {},
        ),
      ),
    );
    expect(
      find.byType(CircularProgressIndicator),
      findsOneWidget,
      reason: 'loading first',
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('500.37 EGP'), findsOneWidget);
    expect(find.text('Rahma M. (name as shown by your bank)'), findsOneWidget);
    expect(find.text('rahma.m@instapay'), findsOneWidget);
    expect(find.textContaining('OH-4821'), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-left')), findsOneWidget);
    expect(fake.calls.single.$1, 'createPayment');
    expect((fake.calls.single.$2['key'] as String).length, 24);
    expect(fake.calls.single.$2['topUpOf'], isNull);
  });

  testWidgets('the copy buttons put the right text on the clipboard', (
    tester,
  ) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
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
    await open(tester);
    for (final k in ['copy-amount', 'copy-address', 'copy-reference']) {
      await tester.tap(find.byKey(ValueKey(k)));
      await tester.pump();
    }
    expect(copied, ['500.37', 'rahma.m@instapay', 'OH-4821']);
  });

  testWidgets('Open InstaPay copies the amount and hands over', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
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
    final opened = <Uri>[];
    await open(
      tester,
      opener: (u) async {
        opened.add(u);
        return true;
      },
    );
    await tester.ensureVisible(find.byKey(const ValueKey('open-instapay')));
    await tester.tap(find.byKey(const ValueKey('open-instapay')));
    await tester.pump();
    expect(copied, ['500.37']);
    expect(opened.single.scheme, 'instapay');
    expect(
      find.textContaining('The amount is copied'),
      findsNothing,
      reason: 'it opened, so nothing more to say',
    );
  });

  testWidgets('when InstaPay cannot be opened it says to open the bank app', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await open(tester, opener: (_) async => false);
    await tester.ensureVisible(find.byKey(const ValueKey('open-instapay')));
    await tester.tap(find.byKey(const ValueKey('open-instapay')));
    await tester.pump();
    expect(find.textContaining('The amount is copied'), findsOneWidget);
  });

  testWidgets(
    'an open payment for the same coaching is reused, not created twice',
    (tester) async {
      final fake = FakePaymentsRepository()..setPayments([payment()]);
      await open(tester, repo: fake);
      expect(fake.names, isNot(contains('createPayment')));
      expect(find.text('500.37 EGP'), findsOneWidget);
    },
  );

  testWidgets('I have paid hands the payment to the caller', (tester) async {
    Payment? got;
    await open(tester, onPaid: (p) => got = p);
    await tester.tap(find.byKey(const ValueKey('i-have-paid')));
    expect(got?.id, 'p1');
  });

  testWidgets(
    'an expired payment shows the 7 day sentence and keeps the primary',
    (tester) async {
      final fake = FakePaymentsRepository()
        ..setPayments([
          payment(
            status: PaymentStatus.expired,
            expiresAt: fixedNow.subtract(const Duration(hours: 2)),
            lateUntil: fixedNow.add(const Duration(days: 5)),
          ),
        ]);
      await open(tester, repo: fake);
      expect(find.byKey(const ValueKey('pay-expired')), findsOneWidget);
      expect(find.byKey(const ValueKey('i-have-paid')), findsOneWidget);
    },
  );

  testWidgets(
    'a payment whose proof is already with the coach goes to its status',
    (tester) async {
      Payment? moved;
      final fake = FakePaymentsRepository()
        ..setPayments([payment(status: PaymentStatus.proofSubmitted)]);
      await open(tester, repo: fake, onInProgress: (p) => moved = p);
      expect(moved?.status, PaymentStatus.proofSubmitted);
      expect(fake.names, isNot(contains('createPayment')));
    },
  );

  testWidgets(
    'a stale list: the server says one is open, she is shown that one',
    (tester) async {
      phone(tester);
      final fake = _Stale(payment());
      await tester.pumpWidget(
        host(
          PaymentView(
            subId: 'sub1',
            repository: fake,
            now: () => fixedNow,
            onIHavePaid: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(fake.names, ['createPayment']);
      expect(find.text('500.37 EGP'), findsOneWidget);
      expect(find.textContaining('already have a payment open'), findsNothing);
    },
  );

  testWidgets('a dead request (cancelled) lets a new one start', (
    tester,
  ) async {
    final fake = FakePaymentsRepository()
      ..setPayments([payment(status: PaymentStatus.cancelled)]);
    await open(tester, repo: fake);
    expect(fake.names, contains('createPayment'));
  });

  testWidgets('"Pay the rest" asks the server for a top up of that payment', (
    tester,
  ) async {
    final fake = await open(tester, topUpOf: 'p0');
    expect(fake.calls.single.$2['topUpOf'], 'p0');
  });

  testWidgets('coach_not_ready shows the message and no primary', (
    tester,
  ) async {
    phone(tester);
    final fake = FakePaymentsRepository()
      ..failNext = const PaymentFailure('coach_not_ready');
    await tester.pumpWidget(
      host(
        PaymentView(
          subId: 'sub1',
          repository: fake,
          now: () => fixedNow,
          onIHavePaid: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('not-ready')), findsOneWidget);
    expect(find.byKey(const ValueKey('i-have-paid')), findsNothing);
  });

  testWidgets('offline: a calm sentence, no primary, nothing raw', (
    tester,
  ) async {
    phone(tester);
    final fake = FakePaymentsRepository()
      ..failNext = const PaymentFailure('', unreachable: true);
    await tester.pumpWidget(
      host(
        PaymentView(
          subId: 'sub1',
          repository: fake,
          now: () => fixedNow,
          onIHavePaid: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('could not reach Own Hub'), findsOneWidget);
    expect(find.byKey(const ValueKey('i-have-paid')), findsNothing);
  });

  testWidgets(
    'denied or refused (too many requests): a calm sentence, never the code',
    (tester) async {
      phone(tester);
      final fake = FakePaymentsRepository()
        ..failNext = const PaymentFailure('too_many_requests');
      await tester.pumpWidget(
        host(
          PaymentView(
            subId: 'sub1',
            repository: fake,
            now: () => fixedNow,
            onIHavePaid: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Too many tries. Please wait a while.'), findsOneWidget);
      expect(find.textContaining('too_many'), findsNothing);
    },
  );

  testWidgets(
    'the switch turned off at the server: payments_off is a calm pause',
    (tester) async {
      phone(tester);
      final fake = FakePaymentsRepository()
        ..failNext = const PaymentFailure('payments_off');
      await tester.pumpWidget(
        host(
          PaymentView(
            subId: 'sub1',
            repository: fake,
            now: () => fixedNow,
            onIHavePaid: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('paused'), findsOneWidget);
    },
  );

  testWidgets('the countdown ticks down each second and stops at zero', (
    tester,
  ) async {
    phone(tester);
    final fake = FakePaymentsRepository()
      ..setPayments([
        payment(expiresAt: fixedNow.add(const Duration(seconds: 3))),
      ]);
    var clock = fixedNow;
    await tester.pumpWidget(
      host(
        PaymentView(
          subId: 'sub1',
          repository: fake,
          now: () => clock,
          onIHavePaid: (_) {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('pay-left'))).data,
      'Time left 00:03',
    );
    clock = fixedNow.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('pay-left'))).data,
      'Time left 00:01',
    );
    clock = fixedNow.add(const Duration(seconds: 4));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('pay-expired')), findsOneWidget);
    expect(find.byKey(const ValueKey('i-have-paid')), findsOneWidget);
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget and layout, $lang at ${scale}x on ${small ? '375x667' : '390x844'}',
          (tester) async {
            await open(tester, lang: lang, scale: scale, small: small);
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
            );
            expect(filledPrimaryActions(tester), 1);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

/// The first list is empty (cache), the create is refused, the second list has it.
class _Stale extends FakePaymentsRepository {
  _Stale(this.open);
  final Payment open;
  int reads = 0;
  @override
  Stream<List<Payment>> watchMyPaymentsAsClient() =>
      Stream<List<Payment>>.value(reads++ == 0 ? const <Payment>[] : [open]);
  @override
  Future<Payment> createPayment({
    required String subId,
    required String idempotencyKey,
    String? topUpOf,
  }) async {
    calls.add(('createPayment', {'subId': subId}));
    throw const PaymentFailure('open_payment_exists');
  }
}
