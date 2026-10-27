import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';
import 'package:own_hub/features/payments/presentation/payment_address_view.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import 'support/fake_payments_repository.dart';
import 'support/payments_host.dart';

Future<(FakePaymentsRepository, FakePhoneReauth)> open(
  WidgetTester tester, {
  String lang = 'en',
  double scale = 1,
  bool small = false,
  CoachAddress? address,
  DateTime Function()? now,
}) async {
  small ? smallPhone(tester) : phone(tester);
  final repo = FakePaymentsRepository()..address = address;
  final reauth = FakePhoneReauth();
  await tester.pumpWidget(
    host(
      PaymentAddressView(repository: repo, reauth: reauth, now: now),
      lang: lang,
      scale: scale,
    ),
  );
  await tester.pump();
  return (repo, reauth);
}

Future<void> fill(
  WidgetTester tester, {
  String address = 'Rahma.M@instapay',
  String name = 'Rahma M.',
}) async {
  await tester.enterText(find.byType(EditableText).at(0), address);
  await tester.enterText(find.byType(EditableText).at(1), name);
  await tester.pump();
}

void main() {
  testWidgets('the primary is off until both fields are valid', (tester) async {
    await open(tester);
    expect(filledPrimaryActions(tester), 0);
    await tester.enterText(find.byType(EditableText).at(0), 'rahma.m@instapay');
    await tester.pump();
    expect(filledPrimaryActions(tester), 0);
    await tester.enterText(find.byType(EditableText).at(1), 'Rahma M.');
    await tester.pump();
    expect(filledPrimaryActions(tester), 1);
  });

  testWidgets(
    'a code, then the confirm, then the address goes to the server in lower case',
    (tester) async {
      final (repo, reauth) = await open(tester);
      repo.nextAddressChange = AddressChange(
        pending: true,
        effectiveAt: DateTime.utc(2026, 10, 28, 12, 30),
      );
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('address-primary')));
      await tester.pump();
      expect(reauth.calls, ['sendCode']);
      expect(
        repo.calls,
        isEmpty,
        reason: 'nothing is saved before the code is confirmed',
      );
      expect(
        find.text('Rahma.M@instapay'),
        findsNothing,
        reason: 'the form is replaced by the code step',
      );
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('address-primary')));
      await tester.pump();
      await tester.pump();
      expect(reauth.calls, ['sendCode', 'confirm:123456']);
      expect(repo.calls.single.$1, 'setAddress');
      expect(repo.calls.single.$2['address'], 'rahma.m@instapay');
      expect(find.byKey(const ValueKey('address-status')), findsOneWidget);
      expect(find.textContaining('starts working at 28/10'), findsOneWidget);
    },
  );

  testWidgets(
    'a first address is active at once and says so, with no 24 hour line',
    (tester) async {
      final (repo, _) = await open(tester);
      repo.nextAddressChange = const AddressChange(pending: false);
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('address-primary')));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('address-primary')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Your address is saved and ready.'), findsOneWidget);
      expect(find.textContaining('starts working at'), findsNothing);
    },
  );

  testWidgets('a waiting change is shown from her profile', (tester) async {
    await open(
      tester,
      now: () => DateTime.utc(2026, 10, 27, 12),
      address: CoachAddress(
        address: 'old@instapay',
        accountName: 'Rahma M.',
        pendingAddress: 'new@instapay',
        pendingAccountName: 'Rahma M.',
        pendingEffectiveAt: DateTime.utc(2026, 10, 28, 9),
      ),
    );
    await tester.pump();
    expect(find.text('old@instapay'), findsOneWidget);
    expect(find.textContaining('starts working at'), findsOneWidget);
  });

  testWidgets('a wrong code stays on the code step with a calm sentence', (
    tester,
  ) async {
    final (repo, reauth) = await open(tester);
    await fill(tester);
    await tester.tap(find.byKey(const ValueKey('address-primary')));
    await tester.pump();
    reauth.failNext = const PaymentFailure('otp_wrong');
    await tester.enterText(find.byType(EditableText).last, '000000');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('address-primary')));
    await tester.pump();
    expect(find.text('The code is not right. Try again.'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.textContaining('otp_wrong'), findsNothing);
  });

  testWidgets(
    'the server refusing the address returns to the form with its sentence',
    (tester) async {
      final (repo, _) = await open(tester);
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('address-primary')));
      await tester.pump();
      repo.failNext = const PaymentFailure('address_format');
      await tester.enterText(find.byType(EditableText).last, '123456');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('address-primary')));
      await tester.pump();
      await tester.pump();
      expect(
        find.text(
          'That does not look like an InstaPay address. It looks like name@instapay.',
        ),
        findsWidgets,
      );
      expect(
        find.byType(EditableText),
        findsNWidgets(2),
        reason: 'back on the form',
      );
    },
  );

  testWidgets('no signal says so and keeps what she typed', (tester) async {
    final (_, reauth) = await open(tester);
    await fill(tester);
    reauth.failNext = const PaymentFailure('', unreachable: true);
    await tester.tap(find.byKey(const ValueKey('address-primary')));
    await tester.pump();
    expect(find.textContaining('could not reach Own Hub'), findsOneWidget);
    expect(find.text('Rahma.M@instapay'), findsOneWidget);
  });

  testWidgets('a phone number in the address field warns', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(EditableText).at(0), '01012345678');
    await tester.pump();
    expect(
      find.text('That looks like a phone number. Use your @ address instead.'),
      findsOneWidget,
    );
    expect(filledPrimaryActions(tester), 0);
  });

  for (final lang in ['en', 'ar']) {
    for (final scale in [1.0, 2.0]) {
      for (final small in [false, true]) {
        testWidgets(
          'budget and layout, $lang at ${scale}x on ${small ? '375x667' : '390x844'}, both steps',
          (tester) async {
            await open(tester, lang: lang, scale: scale, small: small);
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
            );
            expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
            expect(tester.takeException(), isNull);
            await tester.enterText(
              find.byType(EditableText).at(0),
              'rahma.m@instapay',
            );
            await tester.enterText(find.byType(EditableText).at(1), 'Rahma M.');
            await tester.pump();
            await tester.tap(find.byKey(const ValueKey('address-primary')));
            await tester.pump();
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
