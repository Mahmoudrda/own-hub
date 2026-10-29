import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/payments_switch.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/events/domain/cairo_time.dart';
import 'package:own_hub/features/payments/data/payments_hub.dart';
import 'package:own_hub/features/payments/data/proof_images.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/pay_card.dart';
import 'package:own_hub/features/payments/presentation/payment_view.dart';
import 'package:own_hub/features/payments/presentation/payments_navigation.dart';
import 'package:own_hub/features/payments/presentation/proof_flow.dart';
import 'package:own_hub/features/payments/presentation/proof_view.dart';
import 'package:own_hub/features/payments/presentation/status_view.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../private_coaching/coach/coach_fake.dart';
import '../private_coaching/plans/plans_support.dart' as plans;
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final flagsOn = FeatureFlags.allOff.with_({
  Feature.marketplace: true,
  Feature.instapayPayments: true,
});
final flagsOff = FeatureFlags.allOff.with_({Feature.marketplace: true});

/// An H05-like page: the payment entry the router would give, on one screen.
class _Page extends StatelessWidget {
  const _Page({
    required this.flags,
    this.status = SubscriptionStatus.awaitingPayment,
  });
  final FeatureFlags flags;
  final SubscriptionStatus status;

  @override
  Widget build(BuildContext context) {
    final entry = PaymentsNav.payEntry(
      context,
      plans.sub(status: status),
      flags: flags,
      coachRoute: 'H05',
    );
    return Scaffold(body: Column(children: [const Text('H05 body'), ?entry]));
  }
}

Future<void> pumpPage(
  WidgetTester tester,
  FeatureFlags flags, {
  SubscriptionStatus status = SubscriptionStatus.awaitingPayment,
}) async {
  phone(tester);
  await tester.pumpWidget(host(_Page(flags: flags, status: status)));
  await tester.pump();
  await tester.pump();
}

final Finder payNow = find.byKey(const ValueKey('pay-now'));
final Finder seePayment = find.byKey(const ValueKey('see-payment'));

void main() {
  late FakePaymentsRepository repo;

  setUp(() {
    SharedPreferences.setMockInitialValues({'payments.learnAsked': true});
    repo = FakePaymentsRepository();
    PaymentsHub.override = repo;
    PaymentsSwitch.resetForTest();
  });
  tearDown(() {
    PaymentsHub.override = null;
    PaymentsHub.reauthOverride = null;
    PaymentsNav.picker = pickProofImages;
    PaymentsNav.prepare = prepareProofImage;
    PaymentsSwitch.resetForTest();
  });

  group('no payment UI when it is off', () {
    testWidgets(
      'the compiled-in flag off: no entry at all, even with the server switch on',
      (tester) async {
        PaymentsSwitch.enabled = true;
        repo.setPayments([payment(status: PaymentStatus.proofSubmitted)]);
        await pumpPage(tester, flagsOff);
        expect(find.byType(PayEntryCard), findsNothing);
        expect(payNow, findsNothing);
        expect(seePayment, findsNothing);
      },
    );

    testWidgets('the server switch missing: nothing offers a new payment', (
      tester,
    ) async {
      repo.enabled = false;
      await pumpPage(tester, flagsOn);
      expect(payNow, findsNothing);
      expect(seePayment, findsNothing);
      expect(PaymentsSwitch.live, isFalse);
    });

    testWidgets(
      'the switch is read when the card opens, then Pay now appears',
      (tester) async {
        repo.enabled = true;
        await pumpPage(tester, flagsOn);
        await tester.pump();
        expect(PaymentsSwitch.enabled, isTrue);
        expect(payNow, findsOneWidget);
      },
    );

    testWidgets('a read that fails keeps what it had', (tester) async {
      PaymentsSwitch.enabled = true;
      repo.enabled = null;
      await PaymentsSwitch.load();
      expect(PaymentsSwitch.enabled, isTrue);
      repo.enabled = false;
      await PaymentsSwitch.load();
      expect(PaymentsSwitch.enabled, isFalse);
    });

    testWidgets('live needs BOTH the flag and the server switch', (
      tester,
    ) async {
      final before = AppRouter.featureFlags;
      addTearDown(() => AppRouter.featureFlags = before);
      PaymentsSwitch.enabled = true;
      AppRouter.featureFlags = flagsOn;
      expect(PaymentsSwitch.live, isTrue);
      AppRouter.featureFlags = flagsOff;
      expect(PaymentsSwitch.live, isFalse);
      AppRouter.featureFlags = flagsOn;
      PaymentsSwitch.enabled = false;
      expect(PaymentsSwitch.live, isFalse);
    });

    testWidgets(
      'switched off while a payment is open: its status stays readable and answerable',
      (tester) async {
        PaymentsSwitch.enabled = false;
        repo.setPayments([payment(status: PaymentStatus.proofSubmitted)]);
        await pumpPage(tester, flagsOn);
        expect(payNow, findsNothing);
        expect(seePayment, findsOneWidget);
        await tester.tap(seePayment);
        await tester.pumpAndSettle();
        expect(find.byType(PaymentStatusView), findsOneWidget);
        expect(find.byKey(const ValueKey('status-word')), findsOneWidget);
      },
    );

    testWidgets(
      'an unpaid request with the switch off can still be opened to finish',
      (tester) async {
        repo.enabled = false;
        repo.setPayments([payment()]);
        await pumpPage(tester, flagsOn);
        expect(seePayment, findsOneWidget);
        expect(payNow, findsNothing);
      },
    );

    testWidgets(
      'the coach row and the My coach card are not drawn without the entry',
      (tester) async {
        phone(tester);
        await tester.pumpWidget(
          host(
            MyCoachView(
              repository: plans.RecordingRepo(),
              subscription: plans.sub(
                status: SubscriptionStatus.awaitingPayment,
              ),
              onMessage: () {},
            ),
          ),
        );
        await tester.pump();
        expect(payNow, findsNothing);
        expect(seePayment, findsNothing);
      },
    );

    testWidgets('K18 hides the InstaPay row until it is on', (tester) async {
      for (final on in [false, true]) {
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
        await tester.pumpWidget(
          host(CoachSpaceView(repository: coach, instapayOn: on)),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('My InstaPay address'),
          on ? findsOneWidget : findsNothing,
        );
        // With payments on the note must not say coaching is free.
        expect(
          find.textContaining('Coaching is free until'),
          on ? findsNothing : findsOneWidget,
        );
        expect(
          find.text(
            'Members can ask to join your packages. When you accept, they pay '
            'you by InstaPay.',
          ),
          on ? findsOneWidget : findsNothing,
        );
        await tester.pumpWidget(const SizedBox());
      }
    });
  });

  group('the entry on My coach', () {
    testWidgets('no payment yet and the switch on: Pay now', (tester) async {
      PaymentsSwitch.enabled = true;
      await pumpPage(tester, flagsOn);
      expect(payNow, findsOneWidget);
      expect(seePayment, findsNothing);
    });

    testWidgets('once she is active a confirmed payment shows nothing', (
      tester,
    ) async {
      PaymentsSwitch.enabled = true;
      repo.setPayments([payment(status: PaymentStatus.confirmed)]);
      await pumpPage(tester, flagsOn, status: SubscriptionStatus.active);
      expect(payNow, findsNothing);
      expect(seePayment, findsNothing);
    });

    testWidgets('a proof with the coach shows See your payment, not Pay now', (
      tester,
    ) async {
      PaymentsSwitch.enabled = true;
      repo.setPayments([payment(status: PaymentStatus.proofSubmitted)]);
      await pumpPage(tester, flagsOn);
      expect(payNow, findsNothing);
      expect(seePayment, findsOneWidget);
    });

    testWidgets('a payment of another coaching does not count', (tester) async {
      PaymentsSwitch.enabled = true;
      repo.setPayments([
        payment(status: PaymentStatus.proofSubmitted, subId: 'other'),
      ]);
      await pumpPage(tester, flagsOn);
      expect(payNow, findsOneWidget);
    });

    testWidgets(
      'the card appears inside My coach for a coach who waits for her money',
      (tester) async {
        PaymentsSwitch.enabled = true;
        phone(tester);
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => MyCoachView(
                repository: plans.RecordingRepo(),
                subscription: plans.sub(
                  status: SubscriptionStatus.awaitingPayment,
                ),
                onMessage: () {},
                payCard: PaymentsNav.payEntry(
                  context,
                  plans.sub(status: SubscriptionStatus.awaitingPayment),
                  flags: flagsOn,
                  coachRoute: 'H05',
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(payNow, findsOneWidget);
      },
    );
  });

  group('pay in 4 taps', () {
    testWidgets(
      'Pay now, copy the amount, copy the address, I have paid: PAY2 is open',
      (tester) async {
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
        PaymentsSwitch.enabled = true;
        await pumpPage(tester, flagsOn);
        var taps = 0;
        Future<void> tap(Finder f) async {
          await tester.tap(f);
          taps++;
          await tester.pump();
          await tester.pump();
        }

        await tap(payNow);
        expect(find.byType(PaymentView), findsOneWidget);
        await tap(find.byKey(const ValueKey('copy-amount')));
        await tap(find.byKey(const ValueKey('copy-address')));
        await tap(find.byKey(const ValueKey('i-have-paid')));
        expect(taps, 4);
        expect(find.byType(ProofView), findsOneWidget);
        expect(repo.names, ['createPayment']);
      },
    );

    testWidgets('a proof already sent goes to its status, not to PAY1 again', (
      tester,
    ) async {
      PaymentsSwitch.enabled = true;
      repo.setPayments([payment(status: PaymentStatus.awaitingPayment)]);
      await pumpPage(tester, flagsOn);
      await tester.tap(payNow);
      await tester.pump();
      await tester.pump();
      expect(find.byType(PaymentView), findsOneWidget);
      // The proof lands meanwhile (another phone, or the queue): the next open goes to PAY3.
      await tester.pageBack();
      await tester.pumpAndSettle();
      repo.setPayments([payment(status: PaymentStatus.proofSubmitted)]);
      await tester.pump();
      await tester.pump();
      expect(payNow, findsNothing);
      expect(seePayment, findsOneWidget);
    });

    testWidgets(
      'sending the proof lands on PAY3 and Back returns to My coach, not to PAY1',
      (tester) async {
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
        PaymentsSwitch.enabled = true;
        final created = parseCairo('2026-10-27 14:00')!;
        PaymentsNav.picker = () async => [Uint8List(4)];
        PaymentsNav.prepare = (context, raw, expected) async => PreparedImage(
          Uint8List.fromList([1]),
          'Approved Transaction\nYour transaction was successful\n500.37 EGP\nrahma.m@instapay\nTransaction ID 123456789012\n${_stamp(created)}',
        );
        await pumpPage(tester, flagsOn);
        await tester.tap(payNow);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('i-have-paid')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('choose')));
        await tester.pump();
        await tester.pump();
        repo.setPayments([
          payment(
            status: PaymentStatus.proofSubmitted,
            outcome: RiskOutcome.green,
          ),
        ]);
        await tester.tap(find.byKey(const ValueKey('send')));
        await tester.pumpAndSettle();
        expect(repo.names, contains('submitProof'));
        expect(find.byType(PaymentStatusView), findsOneWidget);
        expect(find.byType(PaymentView), findsNothing);
        expect(find.byType(ProofView), findsNothing);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.text('H05 body'), findsOneWidget);
      },
    );

    testWidgets('Add proof on PAY3 opens PAY6 and a send returns to PAY3', (
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
      PaymentsSwitch.enabled = true;
      PaymentsNav.picker = () async => [Uint8List(4)];
      PaymentsNav.prepare = (context, raw, expected) async =>
          PreparedImage(Uint8List.fromList([1]), '');
      repo.setPayments([
        payment(status: PaymentStatus.inReview, disputeKind: 'not_received'),
      ]);
      await pumpPage(tester, flagsOn);
      await tester.tap(seePayment);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('status-primary')));
      await tester.pumpAndSettle();
      expect(find.text('Add proof'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose')));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pumpAndSettle();
      expect(repo.names, contains('addEvidence'));
      expect(find.byType(PaymentStatusView), findsOneWidget);
      expect(find.byType(ProofView), findsNothing);
    });
  });
}

String _stamp(DateTime instant) {
  final c = toCairo(instant.add(const Duration(minutes: 32)));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(c.day)}/${two(c.month)}/${c.year} ${two(c.hour)}:${two(c.minute)}';
}
