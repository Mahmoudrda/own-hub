// C06 — What's your number?
//
// The screen that turns a visitor into an account. Two things here are worth
// more than "the text renders": that the copy promises **six** digits, because
// Firebase sends six and a screen promising four would be lying (DECISIONS.md
// D2a), and that a half-typed number cannot be submitted — there is no error
// copy in the dictionary to tell her what went wrong, so the screen must not let
// her get it wrong.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/presentation/phone_number_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('asks for one thing, and says what it costs her', (tester) async {
    await tester.pumpWidget(
      _host(PhoneNumberView(repository: FakeAuthRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text("What's your number?"), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('Send me a code'), findsOneWidget);
    expect(
      find.text('By joining you agree to the community rules.'),
      findsOneWidget,
    );
  });

  testWidgets('promises six digits, never four', (tester) async {
    // D2a. The provider sends six and the length is not configurable, so a
    // screen that says four is a defect the user discovers, not the developer.
    await tester.pumpWidget(
      _host(PhoneNumberView(repository: FakeAuthRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('six-digit code'), findsOneWidget);
    expect(find.textContaining('four'), findsNothing);
  });

  testWidgets('a half-typed number cannot be sent', (tester) async {
    // There is no invalid-number copy in the dictionary, so the only honest
    // behaviour is to refuse to send rather than to fail silently at the
    // provider and leave her waiting for a message.
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_host(PhoneNumberView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();
    expect(repository.sentTo, isEmpty);

    await tester.enterText(find.byType(TextField), '10055');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();
    expect(repository.sentTo, isEmpty, reason: 'still too short');
  });

  testWidgets('a full number is dialled in international form', (tester) async {
    final repository = FakeAuthRepository();
    var sent = 0;
    await tester.pumpWidget(
      _host(PhoneNumberView(repository: repository, onCodeSent: () => sent++)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '1005550132');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    expect(repository.sentTo, ['+201005550132']);
    expect(sent, 1, reason: 'she only moves on once a code is actually sent');
  });

  testWidgets('the local leading zero is dropped, not sent', (tester) async {
    // She types the number the way she says it out loud. "+200100…" is not a
    // number, and this is the most common way a phone field breaks in Egypt.
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_host(PhoneNumberView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '01005550132');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send me a code'));
    await tester.pumpAndSettle();

    expect(repository.sentTo, ['+201005550132']);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        PhoneNumberView(repository: FakeAuthRepository()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ما رقمك؟'), findsOneWidget);
    expect(find.text('أرسلي إليّ رمزًا'), findsOneWidget);
    expect(
      find.text("What's your number?"),
      findsNothing,
      reason: 'English here means a string bypassed AppL10n',
    );
    expect(
      Directionality.of(tester.element(find.text('ما رقمك؟'))),
      TextDirection.rtl,
    );
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        PhoneNumberView(repository: FakeAuthRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
