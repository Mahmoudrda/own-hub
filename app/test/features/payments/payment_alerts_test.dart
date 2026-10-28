// Payment alerts are a second yes, asked for at the point of need: one card on
// the coach's Payments inbox and one on a payment's status screen. The card
// says what will be sent, asks nothing until she taps, and goes once she has
// said yes. These use fakes for the phone and the repository; the registrar
// and the server's topic filter have their own tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/app_state/push_registration.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/coach_payments_view.dart';
import 'package:own_hub/features/payments/presentation/payment_alerts_card.dart';
import 'package:own_hub/features/payments/presentation/status_view.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final now = DateTime.utc(2026, 10, 27, 12);

class _Phone {
  _Phone(this.state, {this.answer = PushOptIn.on});

  PushAlertState state;
  PushOptIn answer;
  final List<String> asked = [];
  int settings = 0;

  PaymentAlertsAccess get access => PaymentAlertsAccess(
    state: () async => state,
    turnOn: (locale) async {
      asked.add(locale);
      return answer;
    },
    openSettings: () => settings++,
  );
}

Future<void> _openCard(
  WidgetTester tester,
  _Phone phone_, {
  PaymentAlertsFor who = PaymentAlertsFor.coach,
  String lang = 'en',
}) async {
  phone(tester);
  await tester.pumpWidget(
    host(
      Scaffold(
        body: PaymentAlertsCard(who: who, access: phone_.access),
      ),
      lang: lang,
    ),
  );
  await tester.pump();
}

Finder get turnOn => find.byKey(const ValueKey('payment-alerts-turn-on'));
Finder get card => find.byKey(const ValueKey('payment-alerts-card'));
Finder get settingsButton =>
    find.byKey(const ValueKey('payment-alerts-settings'));

void main() {
  group('the card', () {
    testWidgets('offers one tap and says what will be sent', (tester) async {
      await _openCard(tester, _Phone(PushAlertState.off));
      expect(card, findsOneWidget);
      expect(find.textContaining('payment updates only'), findsOneWidget);
      expect(find.text('Turn on payment alerts'), findsOneWidget);
      expect(settingsButton, findsNothing);
    });

    testWidgets('asks nothing until she taps, then goes', (tester) async {
      final phone_ = _Phone(PushAlertState.off);
      await _openCard(tester, phone_);
      expect(phone_.asked, isEmpty);

      await tester.tap(turnOn);
      await tester.pump();
      expect(phone_.asked, ['en']);
      expect(turnOn, findsNothing);
      expect(
        find.text('Payment alerts are on for this phone.'),
        findsOneWidget,
      );
    });

    testWidgets('speaks her language to the registrar', (tester) async {
      final phone_ = _Phone(PushAlertState.off);
      await _openCard(tester, phone_, lang: 'ar');
      await tester.tap(turnOn);
      await tester.pump();
      expect(phone_.asked, ['ar']);
    });

    testWidgets('is not drawn once she has said yes', (tester) async {
      await _openCard(tester, _Phone(PushAlertState.on));
      expect(card, findsNothing);
      expect(turnOn, findsNothing);
    });

    testWidgets('is not drawn on a phone that cannot get them', (tester) async {
      await _openCard(tester, _Phone(PushAlertState.unavailable));
      expect(card, findsNothing);
    });

    testWidgets('is not drawn at all when the app gives it no access', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        host(
          const Scaffold(body: PaymentAlertsCard(who: PaymentAlertsFor.coach)),
        ),
      );
      await tester.pump();
      expect(card, findsNothing);
    });

    testWidgets('on a phone that refuses notifications, points to Settings', (
      tester,
    ) async {
      final phone_ = _Phone(PushAlertState.blocked);
      await _openCard(tester, phone_);
      expect(turnOn, findsNothing);
      expect(find.textContaining('turn them on in Settings'), findsOneWidget);
      await tester.tap(settingsButton);
      expect(phone_.settings, 1);
      expect(phone_.asked, isEmpty);
    });

    testWidgets('a refusal at the prompt turns into the Settings line', (
      tester,
    ) async {
      final phone_ = _Phone(PushAlertState.off, answer: PushOptIn.denied);
      await _openCard(tester, phone_);
      await tester.tap(turnOn);
      await tester.pump();
      expect(turnOn, findsNothing);
      expect(settingsButton, findsOneWidget);
      expect(find.textContaining('turn them on in Settings'), findsOneWidget);
    });

    testWidgets('a phone that cannot register says so and may try again', (
      tester,
    ) async {
      final phone_ = _Phone(PushAlertState.off, answer: PushOptIn.unavailable);
      await _openCard(tester, phone_);
      await tester.tap(turnOn);
      await tester.pump();
      expect(find.byKey(const ValueKey('payment-alerts-failed')), findsOne);
      expect(turnOn, findsOneWidget);
      phone_.answer = PushOptIn.on;
      await tester.tap(turnOn);
      await tester.pump();
      expect(phone_.asked.length, 2);
      expect(turnOn, findsNothing);
    });

    testWidgets('the client sees her own words', (tester) async {
      await _openCard(
        tester,
        _Phone(PushAlertState.off),
        who: PaymentAlertsFor.client,
      );
      expect(find.text('Tell me when it changes'), findsOneWidget);
      expect(find.textContaining('your payment is confirmed'), findsOneWidget);
    });
  });

  group('on the screens', () {
    Future<void> inbox(
      WidgetTester tester,
      _Phone phone_, {
      String lang = 'en',
      double scale = 1,
      bool small = false,
      bool crowded = false,
    }) async {
      small ? smallPhone(tester) : phone(tester);
      // Crowded: no address yet (so its card and button show), two waiting,
      // four earlier, and the auto-confirm switch on offer.
      final fake = FakePaymentsRepository(uid: 'coach')
        ..address = crowded
            ? const CoachAddress(cleanConfirmed: 5, autoConfirmGreen: true)
            : const CoachAddress(address: 'a@instapay', accountName: 'R')
        ..setPayments([
          payment(
            id: 'p1',
            status: PaymentStatus.proofSubmitted,
            submittedAt: now,
          ),
          payment(
            id: 'p2',
            status: PaymentStatus.proofSubmitted,
            submittedAt: now,
            reference: 'OH-4822',
          ),
          if (crowded) ...[
            for (var i = 3; i < 7; i++)
              payment(
                id: 'p$i',
                status: PaymentStatus.confirmed,
                reference: 'OH-48$i',
              ),
          ],
        ]);
      await tester.pumpWidget(
        host(
          CoachPaymentsView(
            repository: fake,
            coaching: PrivateCoachingState.forTest(),
            now: () => now,
            alerts: phone_.access,
          ),
          lang: lang,
          scale: scale,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    Future<void> status(
      WidgetTester tester,
      _Phone phone_,
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
            alerts: phone_.access,
          ),
          lang: lang,
          scale: scale,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the coach inbox carries the card', (tester) async {
      final phone_ = _Phone(PushAlertState.off);
      await inbox(tester, phone_);
      expect(turnOn, findsOneWidget);
      await tester.tap(turnOn);
      await tester.pump();
      expect(phone_.asked, ['en']);
    });

    testWidgets('the coach inbox draws nothing once alerts are on', (
      tester,
    ) async {
      await inbox(tester, _Phone(PushAlertState.on));
      expect(card, findsNothing);
    });

    testWidgets('a payment still to happen offers it to the client', (
      tester,
    ) async {
      await status(
        tester,
        _Phone(PushAlertState.off),
        payment(status: PaymentStatus.proofSubmitted),
      );
      expect(find.text('Tell me when it changes'), findsOneWidget);
    });

    testWidgets('a settled payment does not', (tester) async {
      for (final s in [
        PaymentStatus.confirmed,
        PaymentStatus.cancelled,
        PaymentStatus.refunded,
      ]) {
        await status(tester, _Phone(PushAlertState.off), payment(status: s));
        expect(card, findsNothing, reason: s.wire);
        await tester.pumpWidget(const SizedBox());
      }
    });

    final pay3 = <(String, Payment)>[
      ('awaiting payment', payment(status: PaymentStatus.awaitingPayment)),
      ('proof sent', payment(status: PaymentStatus.proofSubmitted)),
      (
        'a different amount, she may agree',
        payment(
          status: PaymentStatus.differentAmount,
          acceptLower: true,
          differentAmountPiasters: 30000,
        ),
      ),
      (
        'the coach says she paid',
        payment(
          status: PaymentStatus.awaitingPayment,
          coachReportTxn: '123456789012',
        ),
      ),
    ];

    for (final lang in ['en', 'ar']) {
      for (final scale in [1.0, 2.0]) {
        for (final small in [false, true]) {
          final where =
              '$lang at ${scale}x on ${small ? '375x667' : '390x844'}';
          for (final state in [PushAlertState.off, PushAlertState.blocked]) {
            for (final crowded in [false, true]) {
              testWidgets('budget and layout of the inbox, ${state.name}'
                  '${crowded ? ', crowded' : ''}, $where', (tester) async {
                await inbox(
                  tester,
                  _Phone(state),
                  lang: lang,
                  scale: scale,
                  small: small,
                  crowded: crowded,
                );
                expect(card, findsOneWidget);
                expect(
                  countControlsAboveFold(tester, includeChrome: false),
                  lessThanOrEqualTo(5),
                );
                expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
                expect(tester.takeException(), isNull);
              });
            }

            testWidgets('budget and layout of PAY3, ${state.name}, $where', (
              tester,
            ) async {
              for (final (name, p) in pay3) {
                await tester.pumpWidget(const SizedBox());
                await status(
                  tester,
                  _Phone(state),
                  p,
                  lang: lang,
                  scale: scale,
                  small: small,
                );
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
              }
            });
          }
        }
      }
    }
  });
}
