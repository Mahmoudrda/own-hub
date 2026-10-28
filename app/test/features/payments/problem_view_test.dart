import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/problem_view.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final l10n = AppL10nEn();

/// A page with one button that opens the screen, so "closes" can be seen.
class _Launcher extends StatelessWidget {
  const _Launcher(this.view);
  final Widget view;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('launch'),
        onPressed: () =>
            Navigator.of(context)
                .push<void>(MaterialPageRoute<void>(builder: (_) => view)),
        child: const Text('go'),
      ),
    ),
  );
}

Future<FakePaymentsRepository> open(
  WidgetTester tester,
  DisputeKind? dispute, {
  String lang = 'en',
  double scale = 1,
  bool small = false,
  bool launcher = false,
  FakePaymentsRepository? repo,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = repo ?? FakePaymentsRepository();
  final view = PaymentProblemView(
    payment: payment(status: PaymentStatus.confirmed),
    dispute: dispute,
    repository: fake,
  );
  await tester.pumpWidget(
    host(launcher ? _Launcher(view) : view, lang: lang, scale: scale),
  );
  if (launcher) {
    await tester.tap(find.byKey(const ValueKey('launch')));
    await tester.pumpAndSettle();
  }
  return fake;
}

Finder get sendButton => find.byKey(const ValueKey('problem-send'));
bool get _sendOn =>
    (sendButton.evaluate().single.widget as AppButton).onPressed != null;

Future<void> write(WidgetTester tester, String note) async {
  await tester.enterText(find.byType(TextField), note);
  await tester.pump();
}

Future<void> send(WidgetTester tester) async {
  await tester.ensureVisible(sendButton);
  await tester.pumpAndSettle();
  await tester.tap(sendButton);
  await tester.pumpAndSettle();
}

class _Slow extends FakePaymentsRepository {
  final gate = Completer<void>();
  @override
  Future<PaymentStatus> requestRefund(String paymentId) async {
    await super.requestRefund(paymentId);
    await gate.future;
    return nextStatus;
  }
}

class _Refuses extends FakePaymentsRepository {
  _Refuses(this.failure);
  final PaymentFailure failure;
  @override
  Future<PaymentStatus> requestRefund(String paymentId) async => throw failure;
  @override
  Future<PaymentStatus> openServiceDispute(
    String paymentId, {
    String? note,
  }) async => throw failure;
}

void main() {
  group('Ask for a refund', () {
    testWidgets('says the window and the days she waits, and has no field', (
      tester,
    ) async {
      await open(tester, null);
      expect(
        find.text(
          'You can ask once in the first 14 days. Your coach has 3 days to '
          'answer, then Own Hub steps in.',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.ownHubDoesNotMoveMoneyIf), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Ask for a refund'), findsNWidgets(2));
      expect(_sendOn, isTrue);
    });

    testWidgets('one tap asks once, says what happens, and closes', (
      tester,
    ) async {
      final fake = await open(tester, null, launcher: true);
      await send(tester);
      expect(fake.names, ['requestRefund']);
      expect(fake.calls.single.$2, {'id': 'p1'});
      expect(find.byType(PaymentProblemView), findsNothing);
      expect(
        find.text('Sent. Your coach has 3 days to answer.'),
        findsOneWidget,
      );
    });

    testWidgets('while it is sending the button is off, so no second ask', (
      tester,
    ) async {
      final slow = _Slow();
      final fake = await open(tester, null, launcher: true, repo: slow);
      await tester.tap(sendButton);
      await tester.pump();
      expect(_sendOn, isFalse);
      await tester.tap(sendButton, warnIfMissed: false);
      slow.gate.complete();
      await tester.pumpAndSettle();
      expect(fake.names, ['requestRefund']);
    });
  });

  group('Service problem and the other two', () {
    final titles = {
      DisputeKind.service: ('Service problem', 'Tell us what went wrong.'),
      DisputeKind.refund: (
        'Ask Own Hub to look again',
        'Your coach did not agree to the refund.',
      ),
      DisputeKind.refundNotReceived: (
        'Refund problem',
        'Your coach says she sent the money back.',
      ),
    };

    for (final e in titles.entries) {
      testWidgets('${e.key.name}: its own title and words', (tester) async {
        await open(tester, e.key);
        expect(find.text(e.value.$1), findsOneWidget);
        expect(find.textContaining(e.value.$2), findsOneWidget);
        expect(find.text('Send'), findsOneWidget);
      });
    }

    testWidgets('Send stays off until the note is 5 to 300 characters', (
      tester,
    ) async {
      await open(tester, DisputeKind.service);
      expect(_sendOn, isFalse);
      await write(tester, 'abcd');
      expect(_sendOn, isFalse);
      await write(tester, '  abcd  ');
      expect(_sendOn, isFalse);
      await write(tester, 'abcde');
      expect(_sendOn, isTrue);
      await write(tester, 'a' * 400);
      expect(
        tester
            .widget<TextField>(find.byType(TextField))
            .controller!
            .text
            .length,
        300,
      );
    });

    for (final kind in DisputeKind.values) {
      testWidgets('${kind.name}: sends the note with the payment id once', (
        tester,
      ) async {
        final fake = await open(tester, kind, launcher: true);
        await write(tester, '  My coach has not answered  ');
        await send(tester);
        expect(fake.names, ['openServiceDispute']);
        expect(fake.calls.single.$2, {
          'id': 'p1',
          'note': 'My coach has not answered',
        });
        expect(find.byType(PaymentProblemView), findsNothing);
        expect(find.text(l10n.sentOwnHubWillLookAtIt), findsOneWidget);
      });
    }
  });

  group('every refusal is a calm line and she can try again', () {
    final lines = <String, String>{
      'refund_window_closed': 'The first 14 days are over, so a refund can no longer be asked for here.',
      'refund_already_requested': l10n.youAlreadyAskedForARefundOn,
      'dispute_window_closed': l10n.theTimeToReportAProblemOn,
      'dispute_already_used': l10n.youAlreadyReportedThisOwnHubHas,
      'dispute_limit': l10n.youHaveReachedTheNumberOfReports,
      'illegal_transition': l10n.thisPaymentChangedRefreshAndTryAgain,
      'payment_not_found': l10n.thisPaymentChangedRefreshAndTryAgain,
      'permission_denied': l10n.weCouldNotDoThatTryAgain,
    };
    for (final dispute in [null, DisputeKind.service]) {
      for (final e in lines.entries) {
        testWidgets('${dispute?.name ?? 'refund'}: ${e.key}', (tester) async {
          await open(tester, dispute, repo: _Refuses(PaymentFailure(e.key)));
          if (dispute != null) await write(tester, 'It did not happen');
          await send(tester);
          expect(find.text(e.value), findsOneWidget);
          expect(find.textContaining(e.key), findsNothing);
          expect(find.byType(PaymentProblemView), findsOneWidget);
          expect(_sendOn, isTrue, reason: 'she can try again');
        });
      }
    }

    testWidgets('offline: it says it could not reach Own Hub', (tester) async {
      await open(
        tester,
        null,
        repo: _Refuses(const PaymentFailure('', unreachable: true)),
      );
      await send(tester);
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget and layout, $lang at ${scale}x on ${small ? '375x667' : '390x844'}',
          (tester) async {
            for (final dispute in <DisputeKind?>[null, ...DisputeKind.values]) {
              await open(
                tester,
                dispute,
                lang: lang,
                scale: scale,
                small: small,
              );
              final why = dispute?.name ?? 'refund';
              expect(
                countControlsAboveFold(tester, includeChrome: false),
                lessThanOrEqualTo(5),
                reason: why,
              );
              expect(
                filledPrimaryActions(tester),
                lessThanOrEqualTo(1),
                reason: why,
              );
              expect(tester.takeException(), isNull, reason: why);
              await tester.pumpWidget(const SizedBox());
            }
          },
        );
      }
    }
  }
}
