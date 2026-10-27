import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/events/domain/cairo_time.dart';
import 'package:own_hub/features/payments/data/payments_local_store.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/data/pending_proofs.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/proof_flow.dart';
import 'package:own_hub/features/payments/presentation/proof_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

const receipt =
    'Approved Transaction\nYour transaction was successful\n500.37 EGP\nFrom\nsara.k@instapay 1234\nTo Instapay\nRah*** M***\nrahma.m@instapay\nMore Details';
const details = 'Transaction ID 123456789012\n27/10/2026 14:32';
const cardAlert =
    'Your credit card ending 9412 has been used for EGP 570.00 on 22/10/2026 at WE-FBB-Pre';

final created = parseCairo('2026-10-27 14:00')!;
final clock = parseCairo('2026-10-27 14:40')!;

class RecordingPending extends PendingProofs {
  final List<(PendingProof, int)> added = [];
  @override
  Future<void> add(PendingProof proof, List<Uint8List> images) async =>
      added.add((proof, images.length));
}

PrepareImage preparing(
  String text, {
  bool nothing = false,
  bool broken = false,
}) => (context, raw, expected) async {
  if (broken) throw const FormatException('unreadable');
  if (nothing) return null;
  return PreparedImage(Uint8List.fromList([1, 2, 3]), text);
};

class Harness {
  Harness(this.repo, this.pending, this.sent);
  final FakePaymentsRepository repo;
  final RecordingPending pending;
  final List<(ProofResult?, bool)> sent;
}

Future<Harness> open(
  WidgetTester tester, {
  String text = '$receipt\n$details',
  PrepareImage? prepare,
  bool evidence = false,
  bool consentAsked = true,
  Map<String, Object> prefs = const {},
  String lang = 'en',
  double scale = 1,
  bool small = false,
  FakePaymentsRepository? repo,
}) async {
  SharedPreferences.setMockInitialValues({
    if (consentAsked) 'payments.learnAsked': true,
    ...prefs,
  });
  small ? smallPhone(tester) : phone(tester);
  final fake = repo ?? FakePaymentsRepository();
  final pending = RecordingPending();
  final sent = <(ProofResult?, bool)>[];
  await tester.pumpWidget(
    host(
      ProofView(
        payment: payment(createdAt: created),
        repository: fake,
        addEvidence: evidence,
        now: () => clock,
        picker: () async => [Uint8List(4)],
        prepare: prepare ?? preparing(text),
        pending: pending,
        onSent: (r, {required bool queued}) => sent.add((r, queued)),
      ),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return Harness(fake, pending, sent);
}

Future<void> choose(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('choose')));
  await tester.pump();
  await tester.pump();
}

bool sendEnabled(WidgetTester tester) => filledPrimaryActions(tester) == 1;

Future<void> typeHandle(WidgetTester tester, String v) async {
  await tester.enterText(find.byType(EditableText).last, v);
  await tester.pump();
}

void main() {
  testWidgets(
    'a green reading fills the number and enables send without typing',
    (tester) async {
      await open(tester);
      expect(sendEnabled(tester), isFalse, reason: 'nothing chosen yet');
      await choose(tester);
      expect(find.text('Transaction number  123456789012'), findsOneWidget);
      expect(find.text('Everything matches. Tap send.'), findsOneWidget);
      expect(find.text('Pictures added: 1'), findsOneWidget);
      expect(sendEnabled(tester), isTrue, reason: 'her handle is optional');
    },
  );

  testWidgets(
    'no number found opens the field and keeps send off until she types one',
    (tester) async {
      await open(tester, text: receipt);
      await choose(tester);
      expect(find.text('Transaction number  Not found yet'), findsOneWidget);
      expect(sendEnabled(tester), isFalse);
      await tester.enterText(find.byType(EditableText).first, '123456');
      await tester.pump();
      expect(sendEnabled(tester), isTrue);
    },
  );

  testWidgets('a short typed number is not enough', (tester) async {
    await open(tester, text: receipt);
    await choose(tester);
    await tester.enterText(find.byType(EditableText).first, '12345');
    await tester.pump();
    expect(sendEnabled(tester), isFalse);
  });

  testWidgets('a card alert says what it is and disables send', (tester) async {
    await open(tester, text: cardAlert);
    await choose(tester);
    expect(find.textContaining('card message'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '123456789012');
    await tester.pump();
    expect(sendEnabled(tester), isFalse);
  });

  testWidgets('amber and red keep send on: the server decides', (tester) async {
    await open(tester, text: receipt);
    await choose(tester);
    await tester.enterText(find.byType(EditableText).first, '123456789012');
    await tester.pump();
    expect(sendEnabled(tester), isTrue);
    await tester.pumpWidget(const SizedBox());
    await open(
      tester,
      text: '${receipt.replaceAll('500.37 EGP', '450.00 EGP')}\n$details',
    );
    await choose(tester);
    expect(find.textContaining('does not match'), findsOneWidget);
    expect(sendEnabled(tester), isTrue);
  });

  testWidgets('the saved handle hides the handle field', (tester) async {
    await open(tester, prefs: {'payments.senderHandle': 'me@instapay'});
    await choose(tester);
    expect(find.text('Your own InstaPay address'), findsNothing);
  });

  testWidgets(
    'a phone number as her handle warns, never blocks, and is not sent',
    (tester) async {
      final h = await open(
        tester,
        text: '$receipt\n$details'.replaceAll(
          'From\nsara.k@instapay 1234\n',
          '',
        ),
      );
      await choose(tester);
      await typeHandle(tester, '01012345678');
      expect(
        find.text(
          "A phone number would show on your coach's receipt. Use your @ address if you have one.",
        ),
        findsOneWidget,
      );
      expect(sendEnabled(tester), isTrue);
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      expect(
        h.repo.calls.single.$2['handle'],
        isNull,
        reason: 'a phone number would be refused by the server',
      );
    },
  );

  testWidgets(
    'send passes the amount, number, a valid handle and the reading once, with a 24 hex key',
    (tester) async {
      final h = await open(tester);
      await choose(tester);
      await typeHandle(tester, 'Sara.K@InstaPay');
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      expect(h.repo.names, ['submitProof']);
      final c = h.repo.calls.single.$2;
      expect(c['key'], matches(RegExp(r'^[0-9a-f]{24}$')));
      expect(c['amount'], 50037);
      expect(c['images'], 1);
      expect(c['txn'], '123456789012');
      expect(c['handle'], 'sara.k@instapay');
      expect((c['reading'] as Map)['learnConsent'], isFalse);
      expect((c['reading'] as Map).containsKey('text'), isFalse);
      expect((c['paidAt'] as DateTime), parseCairo('2026-10-27 14:32'));
      expect(h.sent.single.$1?.outcome, RiskOutcome.green);
      expect(h.sent.single.$2, isFalse);
    },
  );

  testWidgets(
    'a second tap while the first is still on its way sends nothing more',
    (tester) async {
      final fake = FakePaymentsRepository()..hold = Completer<void>();
      final h = await open(tester, repo: fake);
      await choose(tester);
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('send')), warnIfMissed: false);
      await tester.pump();
      expect(fake.names, ['submitProof']);
      expect(
        filledPrimaryActions(tester),
        0,
        reason: 'the button is off while sending',
      );
      fake.hold!.complete();
      await tester.pump();
      await tester.pump();
      expect(h.sent.length, 1);
    },
  );

  testWidgets(
    'an amber answer with a retry keeps her here, shows the fix and uses a new key',
    (tester) async {
      final fake = FakePaymentsRepository()
        ..nextProof = const ProofResult(
          status: PaymentStatus.awaitingPayment,
          outcome: RiskOutcome.amber,
          reasons: ['amountUnreadable'],
          retry: true,
        );
      final h = await open(tester, repo: fake);
      await choose(tester);
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      expect(h.sent, isEmpty);
      expect(
        find.text(
          'We could not read the amount. Pick a clearer screenshot or type the transaction number.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      final keys = [for (final c in fake.calls) c.$2['key']];
      expect(keys.length, 2);
      expect(keys[0], isNot(keys[1]));
    },
  );

  testWidgets('someone else paid: she is asked, and the resend says so', (
    tester,
  ) async {
    final fake = FakePaymentsRepository()
      ..nextProof = const ProofResult(
        status: PaymentStatus.awaitingPayment,
        outcome: RiskOutcome.amber,
        reasons: ['someoneElsePaid'],
        retry: true,
      );
    final h = await open(tester, repo: fake);
    await choose(tester);
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('other-paid')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('other-paid')));
    fake.nextProof = const ProofResult(
      status: PaymentStatus.proofSubmitted,
      outcome: RiskOutcome.green,
    );
    await tester.tap(find.byKey(const ValueKey('other-paid')));
    await tester.pump();
    await tester.pump();
    expect(fake.calls.last.$2['other'], isTrue);
    expect(fake.calls.first.$2['other'], isFalse);
    expect(h.sent.single.$1?.outcome, RiskOutcome.green);
  });

  testWidgets(
    'no signal queues the proof with the same key and tells the caller',
    (tester) async {
      final fake = FakePaymentsRepository()
        ..failNext = const PaymentFailure('', unreachable: true);
      final h = await open(tester, repo: fake);
      await choose(tester);
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      expect(h.sent.single, (null, true));
      final (proof, images) = h.pending.added.single;
      expect(proof.key, fake.calls.single.$2['key']);
      expect(proof.amountPiasters, 50037);
      expect(images, 1);
    },
  );

  testWidgets('a permanent refusal shows a calm sentence and queues nothing', (
    tester,
  ) async {
    final fake = FakePaymentsRepository()
      ..failNext = const PaymentFailure('txn_reused');
    final h = await open(tester, repo: fake);
    await choose(tester);
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('This transaction number was already used.'),
      findsOneWidget,
    );
    expect(h.pending.added, isEmpty);
    expect(h.sent, isEmpty);
  });

  testWidgets('the first send asks the question once; the answer is kept', (
    tester,
  ) async {
    final h = await open(tester, consentAsked: false);
    await choose(tester);
    await tester.tap(find.byKey(const ValueKey('send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Help improve receipt reading?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('consent-yes')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(
      ((h.repo.calls.single.$2['reading']) as Map)['learnConsent'],
      isTrue,
    );
    expect(await PaymentsLocalStore().consentAsked(), isTrue);
  });

  testWidgets(
    'a picture that cannot be read is said so; backing out says nothing',
    (tester) async {
      await open(tester, prepare: preparing('', broken: true));
      await choose(tester);
      expect(
        find.text(
          'This picture is too big or could not be read. Pick another.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await open(tester, prepare: preparing('', nothing: true));
      await choose(tester);
      expect(find.text('Pictures added: 1'), findsNothing);
      expect(find.byKey(const ValueKey('proof-error')), findsNothing);
    },
  );

  group('PAY6, add proof after a dispute', () {
    testWidgets(
      'same steps, its own title and button, no number or handle fields',
      (tester) async {
        await open(tester, evidence: true);
        expect(find.text('Add proof'), findsOneWidget);
        expect(find.byKey(const ValueKey('edit')), findsNothing);
        expect(find.byType(EditableText), findsNothing);
        expect(sendEnabled(tester), isFalse);
        await choose(tester);
        expect(find.text('Send'), findsOneWidget);
        expect(sendEnabled(tester), isTrue);
      },
    );

    testWidgets('send adds the pictures and nothing else', (tester) async {
      final h = await open(tester, evidence: true);
      await choose(tester);
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      expect(h.repo.names, ['addEvidence']);
      expect(h.repo.calls.single.$2['images'], 1);
      expect(h.sent.single, (null, false));
    });

    testWidgets('a refusal (wrong status) is a calm sentence', (tester) async {
      final fake = FakePaymentsRepository()
        ..failNext = const PaymentFailure('wrong_status');
      await open(tester, evidence: true, repo: fake);
      await choose(tester);
      await tester.tap(find.byKey(const ValueKey('send')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text('This payment changed. Refresh and try again.'),
        findsOneWidget,
      );
    });
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
            expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
            await choose(tester);
            await tester.ensureVisible(find.byKey(const ValueKey('edit')));
            await tester.tap(find.byKey(const ValueKey('edit')));
            await tester.pump();
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
            );
            expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
