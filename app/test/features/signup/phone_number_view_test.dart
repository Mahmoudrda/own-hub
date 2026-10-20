// C06 — What's your number?
//
// The screen that turns a visitor into an account. Two things here are worth
// more than "the text renders": that the copy promises **six** digits, because
// Firebase sends six and a screen promising four would be lying (DECISIONS.md
// D2a), that a half-typed number cannot be submitted, that an Arabic keyboard's
// digits count as digits, and that every failed send is said out loud.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/presentation/phone_number_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
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
  // These cases describe the screen with every feature it can mention switched
  // on. The release shape, where copy about dark features is replaced or
  // hidden, is proved in flag_aware_promises_test.dart.
  late FeatureFlags saved;
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    saved = AppRouter.featureFlags;
    AppRouter.featureFlags = FeatureFlags.everything;
  });
  tearDown(() => AppRouter.featureFlags = saved);

  testWidgets('asks for one thing, and says what it costs her', (tester) async {
    await tester.pumpWidget(
      _host(PhoneNumberView(repository: FakeAuthRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 of 3 · Your number'), findsOneWidget);
    expect(find.text("What's your number?"), findsOneWidget);
    expect(find.text('+20'), findsOneWidget);
    expect(find.text('Agree and send me a code'), findsOneWidget);
    expect(
      find.text(
        'By tapping Agree and send me a code, you accept the Terms of Use '
        'and the Privacy Policy.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('By joining you agree to the community rules.'),
      findsOneWidget,
    );
    // Where her number and her account go, before she sends either.
    expect(find.byKey(const ValueKey('phone-transfer-notice')), findsOneWidget);
    expect(find.textContaining('United States'), findsOneWidget);
    expect(find.textContaining('Frankfurt, Germany'), findsOneWidget);
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

    await tester.tap(find.text('Agree and send me a code'));
    await tester.pumpAndSettle();
    expect(repository.sentTo, isEmpty);

    await tester.enterText(find.byType(TextField), '10055');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and send me a code'));
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
    await tester.tap(find.text('Agree and send me a code'));
    await tester.pumpAndSettle();

    expect(repository.sentTo, ['+201005550132']);
    expect(sent, 1, reason: 'she only moves on once a code is actually sent');
  });

  testWidgets(
    'usage statistics: its own switch, off, applied before the send',
    (tester) async {
      final repository = FakeAuthRepository();
      final order = <String>[];
      await tester.pumpWidget(
        _host(
          PhoneNumberView(
            repository: repository,
            onCrashReportsChosen: (allowed) async =>
                order.add('crash $allowed'),
            onAnalyticsChosen: (allowed) async => order.add('stats $allowed'),
            onCodeSent: () => order.add('sent'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggle = find.byKey(const ValueKey('phone-analytics'));
      await tester.ensureVisible(toggle);
      expect(find.text('Help improve Own Hub'), findsOneWidget);
      expect(
        find.textContaining(
          'Never your health details, name, number or messages',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('PostHog in the US'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '1005550132');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and send me a code'));
      await tester.pumpAndSettle();
      // Not turned on, so off; separate from the crash-report choice.
      expect(order, ['crash false', 'stats false', 'sent']);

      order.clear();
      repository.sentTo.clear();
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and send me a code'));
      await tester.pumpAndSettle();
      expect(order, ['crash false', 'stats true', 'sent']);
    },
  );

  testWidgets('with nowhere to record it, the switch is not drawn', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(PhoneNumberView(repository: FakeAuthRepository())),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('phone-analytics')), findsNothing);
  });

  testWidgets('the local leading zero is dropped, not sent', (tester) async {
    // She types the number the way she says it out loud. "+200100…" is not a
    // number, and this is the most common way a phone field breaks in Egypt.
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_host(PhoneNumberView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '01005550132');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and send me a code'));
    await tester.pumpAndSettle();

    expect(repository.sentTo, ['+201005550132']);
  });

  // An Arabic keyboard types Arabic-Indic digits. The screen counted only
  // 0-9, so the button stayed off for ever and nothing said why.
  testWidgets('Arabic-Indic digits light the button and dial the number', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_host(PhoneNumberView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '٠١٠١٢٣٤٥٦٧٨');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agree and send me a code'));
    await tester.pumpAndSettle();

    expect(repository.sentTo, ['+201012345678']);
  });

  testWidgets('in Arabic, +20 sits to the left of her number', (tester) async {
    await tester.pumpWidget(
      _host(
        PhoneNumberView(repository: FakeAuthRepository()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    final code = tester.getCenter(find.text('+20'));
    final field = tester.getCenter(find.byType(TextField));
    expect(code.dx, lessThan(field.dx));
  });

  group('a failed send is said, and her number stays', () {
    final cases = <AuthFailure, String>{
      AuthFailure.invalidNumber:
          'That number does not look right. Check it and try again.',
      AuthFailure.network:
          'No connection. Your number is still here, try again when you are '
          'back online.',
      AuthFailure.tooManyAttempts:
          'Too many tries. Wait a minute, then ask for a new code.',
      AuthFailure.unknown: 'We could not send the code. Try again in a moment.',
    };
    for (final MapEntry(key: failure, value: line) in cases.entries) {
      testWidgets(failure.name, (tester) async {
        var sent = 0;
        await tester.pumpWidget(
          _host(
            PhoneNumberView(
              repository: _Refusing(failure),
              onCodeSent: () => sent++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '01005550132');
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agree and send me a code'));
        await tester.pumpAndSettle();

        expect(sent, 0);
        expect(find.text(line), findsOneWidget);
        // Shown the way it is sent: ten digits, no trunk zero, grouped.
        expect(find.text('100 555 0132'), findsOneWidget);
        final announced = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('phone-error')),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(announced.properties.liveRegion, isTrue);
      });
    }

    testWidgets('editing the number clears the line', (tester) async {
      await tester.pumpWidget(
        _host(PhoneNumberView(repository: _Refusing(AuthFailure.network))),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '01005550132');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agree and send me a code'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('phone-error')), findsOneWidget);

      await tester.enterText(find.byType(TextField), '01005550133');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('phone-error')), findsNothing);
    });
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        PhoneNumberView(repository: FakeAuthRepository()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('رقم موبايلك إيه؟'), findsOneWidget);
    // A7: the neutral form, not a plural imperative to the team.
    expect(find.text('موافقة وعايزة الكود'), findsOneWidget);
    expect(
      find.text("What's your number?"),
      findsNothing,
      reason: 'English here means a string bypassed AppL10n',
    );
    expect(
      Directionality.of(tester.element(find.text('رقم موبايلك إيه؟'))),
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

/// A provider that refuses every send with [failure].
class _Refusing extends FakeAuthRepository {
  _Refusing(this.failure);

  final AuthFailure failure;

  @override
  Future<void> sendCode(String phoneNumber) async =>
      throw AuthException(failure);
}
