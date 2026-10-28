import 'dart:typed_data';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/coach_decision_view.dart';
import 'package:own_hub/features/payments/presentation/proof_flow.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

final l10n = AppL10nEn();
final pic = Uint8List.fromList([1, 2, 3]);

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
  DecisionMode mode, {
  Future<PreparedImage?> Function(Uint8List raw)? prepare,
  Future<List<Uint8List>> Function()? picker,
  String lang = 'en',
  double scale = 1,
  bool small = false,
  bool launcher = false,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final fake = FakePaymentsRepository(uid: 'coach');
  final view = CoachDecisionView(
    payment: payment(
      status: PaymentStatus.proofSubmitted,
      txnNumber: '123456789012',
    ),
    mode: mode,
    repository: fake,
    picker: picker ?? () async => [pic],
    prepare: (context, raw, expected) async =>
        prepare == null ? PreparedImage(raw, 'text') : prepare(raw),
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

Finder get sendButton => find.byKey(const ValueKey('decision-send'));
bool get _sendOn =>
    (sendButton.evaluate().single.widget as AppButton).onPressed != null;

/// Scrolls the control into view first: the form is longer than the phone.
Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

Future<void> fillNotReceived(
  WidgetTester tester, {
  bool reason = true,
  bool tick = true,
  String note = 'It is not in my account',
  bool picture = true,
}) async {
  if (reason) await tapKey(tester, 'reason-paid_by_someone_else');
  if (tick) await tapKey(tester, 'searched');
  if (note.isNotEmpty) {
    await tester.enterText(find.byType(TextField), note);
    await tester.pump();
  }
  if (picture) {
    await tapKey(tester, 'add-statement');
    await tester.pumpAndSettle();
  }
}

void main() {
  group('Not received', () {
    testWidgets(
      'Send stays off until reason, tick, note and picture are all there',
      (tester) async {
        await open(tester, DecisionMode.notReceived);
        expect(_sendOn, isFalse);
        await tapKey(tester, 'reason-not_seen');
        expect(_sendOn, isFalse);
        await tapKey(tester, 'searched');
        expect(_sendOn, isFalse);
        await tester.enterText(find.byType(TextField), 'abcd');
        await tester.pump();
        expect(_sendOn, isFalse);
        await tester.enterText(find.byType(TextField), 'abcde');
        await tester.pump();
        expect(_sendOn, isFalse);
        await tapKey(tester, 'add-statement');
        await tester.pumpAndSettle();
        expect(_sendOn, isTrue);
      },
    );

    testWidgets('a screen reader hears the tick as a check, ticked or not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await open(tester, DecisionMode.notReceived);
      CheckedState state() => tester
          .getSemantics(find.byKey(const ValueKey('searched')))
          .getSemanticsData()
          .flagsCollection
          .isChecked;
      await tester.ensureVisible(find.byKey(const ValueKey('searched')));
      await tester.pumpAndSettle();
      expect(state(), CheckedState.isFalse);
      await tapKey(tester, 'searched');
      expect(state(), CheckedState.isTrue);
      handle.dispose();
    });

    for (final missing in ['reason', 'tick', 'note', 'picture']) {
      testWidgets('without the $missing it cannot be sent', (tester) async {
        await open(tester, DecisionMode.notReceived);
        await fillNotReceived(
          tester,
          reason: missing != 'reason',
          tick: missing != 'tick',
          note: missing == 'note' ? '' : 'It is not in my account',
          picture: missing != 'picture',
        );
        expect(_sendOn, isFalse);
      });
    }

    testWidgets('a note over 300 characters is cut at 300', (tester) async {
      await open(tester, DecisionMode.notReceived);
      await tester.enterText(find.byType(TextField), 'a' * 400);
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text.length, 300);
    });

    testWidgets(
      'it sends the reason, note and picture, then closes with a line',
      (tester) async {
        final fake = await open(
          tester,
          DecisionMode.notReceived,
          launcher: true,
        );
        await fillNotReceived(tester);
        expect(find.text('Pictures added: 1'), findsOneWidget);
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
        expect(fake.calls.last.$1, 'coachNotReceived');
        expect(fake.calls.last.$2['reason'], 'paid_by_someone_else');
        expect(fake.calls.last.$2['note'], 'It is not in my account');
        expect(fake.calls.last.$2['images'], 1);
        expect(sendButton, findsNothing);
        expect(find.text('Sent. Own Hub will look at it.'), findsOneWidget);
      },
    );

    testWidgets('the tick names the amount and the transaction number', (
      tester,
    ) async {
      await open(tester, DecisionMode.notReceived);
      expect(
        find.text(
          'I searched my bank for 500.37 EGP and transaction number 123456789012.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a picture that cannot be read says so and adds nothing', (
      tester,
    ) async {
      await open(
        tester,
        DecisionMode.notReceived,
        prepare: (_) async => throw const FormatException('unreadable'),
      );
      await fillNotReceived(tester);
      expect(find.text(l10n.thisPictureIsTooBigOrCould), findsOneWidget);
      expect(_sendOn, isFalse);
    });

    testWidgets('backing out of the hide step adds nothing', (tester) async {
      await open(tester, DecisionMode.notReceived, prepare: (_) async => null);
      await fillNotReceived(tester);
      expect(find.textContaining('Pictures added'), findsNothing);
      expect(_sendOn, isFalse);
    });

    testWidgets('picking nothing changes nothing', (tester) async {
      await open(
        tester,
        DecisionMode.notReceived,
        picker: () async => <Uint8List>[],
      );
      await fillNotReceived(tester);
      expect(find.textContaining('Pictures added'), findsNothing);
    });

    for (final (reason, expected) in <(String, String)>[
      ('appears_in_statement', l10n.thisPaymentAppearsInYourStatementPlease),
      ('evidence_required', l10n.pleaseTickThatYouSearchedYourBank),
      ('reason_required', l10n.pleaseTellUsWhatYouSawIn),
      ('illegal_transition', l10n.thisPaymentChangedRefreshAndTryAgain),
      ('payment_not_found', l10n.thisPaymentChangedRefreshAndTryAgain),
      ('wrong_status', l10n.thisPaymentChangedRefreshAndTryAgain),
      ('too_many_screenshots', l10n.youHaveSentTooManyPicturesFor),
      ('image_invalid', l10n.weCouldNotUseThatPicturePick),
      ('', l10n.weCouldNotDoThatTryAgain),
    ]) {
      testWidgets('refused with "$reason": one calm line, nothing closes', (
        tester,
      ) async {
        final fake = await open(
          tester,
          DecisionMode.notReceived,
          launcher: true,
        );
        await fillNotReceived(tester);
        fake.failNext = PaymentFailure(reason);
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
        expect(find.text(expected), findsOneWidget);
        expect(sendButton, findsOneWidget);
        expect(_sendOn, isTrue);
        if (reason.isNotEmpty) {
          expect(find.textContaining(reason), findsNothing);
        }
      });
    }

    testWidgets('no signal says it could not reach Own Hub', (tester) async {
      final fake = await open(tester, DecisionMode.notReceived);
      await fillNotReceived(tester);
      fake.failNext = const PaymentFailure('', unreachable: true);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(find.text(l10n.weCouldNotReachOwnHubCheck), findsOneWidget);
    });
  });

  group('Different amount', () {
    Future<void> type(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
    }

    testWidgets('the same amount, under a pound and nothing keep Send off', (
      tester,
    ) async {
      await open(tester, DecisionMode.differentAmount);
      expect(_sendOn, isFalse);
      for (final text in ['500.37', '0.5', 'abc', '']) {
        await type(tester, text);
        expect(_sendOn, isFalse, reason: text);
      }
      await type(tester, '300');
      expect(_sendOn, isTrue);
    });

    testWidgets(
      'a lower amount offers the switch, and sends it off by default',
      (tester) async {
        final fake = await open(
          tester,
          DecisionMode.differentAmount,
          launcher: true,
        );
        expect(find.byKey(const ValueKey('accept-lower')), findsNothing);
        await type(tester, '300');
        expect(find.byKey(const ValueKey('accept-lower')), findsOneWidget);
        await tester.tap(sendButton);
        await tester.pumpAndSettle();
        expect(fake.calls.last.$1, 'coachDifferentAmount');
        expect(fake.calls.last.$2['received'], 30000);
        expect(fake.calls.last.$2['acceptLower'], isFalse);
        expect(sendButton, findsNothing);
        expect(find.text('Sent. Your client will see it.'), findsOneWidget);
      },
    );

    testWidgets('the switch is sent when turned on', (tester) async {
      final fake = await open(tester, DecisionMode.differentAmount);
      await type(tester, '400.5');
      await tester.tap(find.byKey(const ValueKey('accept-lower')));
      await tester.pump();
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(fake.calls.last.$2['received'], 40050);
      expect(fake.calls.last.$2['acceptLower'], isTrue);
    });

    testWidgets('Arabic digits and a comma are read', (tester) async {
      final fake = await open(tester, DecisionMode.differentAmount);
      await type(tester, '٣٠٠٫٥');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(fake.calls.last.$2['received'], 30050);
    });

    testWidgets('more than was asked confirms with the amount received', (
      tester,
    ) async {
      final fake = await open(
        tester,
        DecisionMode.differentAmount,
        launcher: true,
      );
      await type(tester, '600');
      expect(find.byKey(const ValueKey('accept-lower')), findsNothing);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(fake.calls.last.$1, 'coachConfirm');
      expect(fake.calls.last.$2['received'], 60000);
      expect(find.text('Confirmed. Your client can start.'), findsOneWidget);
    });

    testWidgets('accepting too little is refused with its own line', (
      tester,
    ) async {
      final fake = await open(tester, DecisionMode.differentAmount);
      await type(tester, '100');
      await tester.tap(find.byKey(const ValueKey('accept-lower')));
      await tester.pump();
      fake.failNext = const PaymentFailure('accept_lower_too_low');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(find.text(l10n.thatIsTooFarBelowThePrice), findsOneWidget);
      expect(sendButton, findsOneWidget);
    });

    testWidgets('a refusal keeps the amount and shows a calm line', (
      tester,
    ) async {
      final fake = await open(tester, DecisionMode.differentAmount);
      await type(tester, '300');
      fake.failNext = const PaymentFailure('wrong_status');
      await tester.tap(sendButton);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.thisPaymentChangedRefreshAndTryAgain),
        findsOneWidget,
      );
      expect(find.text('300'), findsOneWidget);
    });
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        for (final mode in DecisionMode.values) {
          testWidgets(
            'budget and layout of ${mode.name}, $lang at ${scale}x on '
            '${small ? '375x667' : '390x844'}',
            (tester) async {
              await open(tester, mode, lang: lang, scale: scale, small: small);
              expect(
                countControlsAboveFold(tester, includeChrome: false),
                lessThanOrEqualTo(5),
              );
              if (mode == DecisionMode.differentAmount) {
                await tester.enterText(find.byType(TextField), '300');
                await tester.pump();
                expect(
                  countControlsAboveFold(tester, includeChrome: false),
                  lessThanOrEqualTo(5),
                );
              } else {
                await fillNotReceived(tester);
              }
              expect(filledPrimaryActions(tester), 1);
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
