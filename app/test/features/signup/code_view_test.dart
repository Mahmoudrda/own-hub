// C07 — Type the code.
//
// The screen DECISIONS.md D2a is about. The single most valuable assertion in
// this file is that there are **six** boxes and that the six comes from the auth
// layer rather than from a literal on the screen: if the widget and the provider
// ever disagree about the length, the app tells her to expect a number of digits
// that will never arrive. That is test P0-VER-08's whole subject.
//
// Second most valuable: the code checks itself. "0 extra taps on Android" is the
// screen's stated metric, and it is false the moment a woman has to press
// Continue after typing the last digit.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/ui/app_button.dart';

import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/presentation/code_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_code_field.dart';

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
  testWidgets('shows the step, the promise and the resend', (tester) async {
    final repository = FakeAuthRepository();
    await repository.sendCode('+20 111 222 3333');
    await tester.pumpWidget(_host(CodeView(repository: repository)));
    await tester.pumpAndSettle();
    expect(find.textContaining('We sent six digits'), findsOneWidget);
    await tester.pumpWidget(_host(CodeView(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.text('2 of 3 · Your number'), findsOneWidget);
    expect(find.text('Type the code'), findsOneWidget);
    expect(find.textContaining('sixth digit lands'), findsOneWidget);
    // A code was just sent, so the resend waits first, then is offered.
    expect(find.text('Send it again in 0:30'), findsOneWidget);
    await tester.pump(CodeView.resendWait);
    await tester.pump();
    expect(find.text('Send it again'), findsOneWidget);
  });

  testWidgets('it shows the number SHE typed, not a sample', (tester) async {
    // A mistyped number has to be obvious here. If this screen shows the
    // prototype's placeholder, she waits for a message that will never arrive
    // and has no way to see why — the one moment the real number matters.
    final repository = FakeAuthRepository();
    await repository.sendCode('+20 111 222 3333');

    await tester.pumpWidget(_host(CodeView(repository: repository)));
    await tester.pumpAndSettle();

    expect(find.textContaining('+20 111 222 3333'), findsOneWidget);
    expect(find.textContaining('+20 100 555 0132'), findsNothing);
  });

  testWidgets('with no number in hand it names none, not a sample', (
    tester,
  ) async {
    await tester.pumpWidget(_host(CodeView(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.textContaining('We sent six digits'), findsNothing);
    expect(find.textContaining('+20 100 555 0132'), findsNothing);
  });

  testWidgets('and shows it in Arabic too', (tester) async {
    // P0-A11Y-01: the number stays in Western digits inside Arabic text.
    final repository = FakeAuthRepository();
    await repository.sendCode('+20 111 222 3333');

    await tester.pumpWidget(
      _host(CodeView(repository: repository), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('+20 111 222 3333'), findsOneWidget);
  });

  testWidgets('six boxes, and the six comes from the auth layer', (
    tester,
  ) async {
    // Not `expect(6)` against a literal in the widget: the point is that the
    // screen is built from the same constant the validator checks against.
    await tester.pumpWidget(_host(CodeView(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    final field = tester.widget<AppCodeField>(find.byType(AppCodeField));
    expect(field.length, kVerificationCodeLength);
    expect(kVerificationCodeLength, 6, reason: 'D2a: Firebase sends six');
  });

  testWidgets('all six digits are shown, one to a box', (tester) async {
    await tester.pumpWidget(_host(CodeView(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '417293');
    await tester.pumpAndSettle();

    // Six distinct digits, so each appearing exactly once proves six boxes
    // rendered rather than four.
    for (final digit in ['4', '1', '7', '2', '9', '3']) {
      expect(find.text(digit), findsOneWidget, reason: digit);
    }
  });

  testWidgets('it checks itself when the sixth digit lands', (tester) async {
    // The screen's own promise, and the Android auto-retrieval path. She never
    // taps Continue on a code that works.
    final repository = FakeAuthRepository(codeToAccept: '417293');
    var confirmed = 0;
    await tester.pumpWidget(
      _host(
        CodeView(repository: repository, onConfirmed: () async => confirmed++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '417293');
    await tester.pumpAndSettle();

    expect(confirmed, 1, reason: 'no Continue tap was needed');
    expect(repository.current, isA<AuthSignedIn>());
  });

  testWidgets('a wrong code is said, and her digits stay', (tester) async {
    final repository = FakeAuthRepository(codeToAccept: '417293');
    var confirmed = 0;
    await tester.pumpWidget(
      _host(
        CodeView(repository: repository, onConfirmed: () async => confirmed++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();

    expect(confirmed, 0);
    expect(repository.current, isA<AuthSignedOut>());
    expect(
      find.text(
        'That code did not match. Check the message and type it again.',
      ),
      findsOneWidget,
    );
    expect(find.text('0'), findsNWidgets(6), reason: 'her digits stay');
  });

  group('every other failure is said too', () {
    final cases = <AuthFailure, String>{
      AuthFailure.codeExpired:
          'That code has expired. Ask for a new one below.',
      AuthFailure.network: 'No connection. Try again when you are back online.',
      AuthFailure.tooManyAttempts:
          'Too many tries. Wait a minute, then ask for a new code.',
      AuthFailure.unknown:
          'We could not check the code. Try again in a moment.',
    };
    for (final MapEntry(key: failure, value: line) in cases.entries) {
      testWidgets(failure.name, (tester) async {
        await tester.pumpWidget(
          _host(CodeView(repository: _Refusing(failure))),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '417293');
        await tester.pumpAndSettle();

        expect(find.text(line), findsOneWidget);
        final announced = tester.widget<Semantics>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('code-error')),
                matching: find.byType(Semantics),
              )
              .first,
        );
        expect(announced.properties.liveRegion, isTrue);
      });
    }
  });

  // The provider has accepted the code, and the router is still reading her
  // claim. That wait used to be silent with Continue live, and a second tap
  // pushed the next screen twice.
  testWidgets('it stays busy until the next screen is chosen', (tester) async {
    final repository = FakeAuthRepository(codeToAccept: '417293');
    final gate = Completer<void>();
    var confirmed = 0;
    await tester.pumpWidget(
      _host(
        CodeView(
          repository: repository,
          onConfirmed: () {
            confirmed++;
            return gate.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '417293');
    await tester.pump();
    expect(find.text('Checking your code'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(confirmed, 1, reason: 'a second tap does nothing while checking');

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Checking your code'), findsNothing);
    expect(confirmed, 1);
  });

  testWidgets('"Edit number" goes back to the number', (tester) async {
    var edited = 0;
    await tester.pumpWidget(
      _host(
        CodeView(
          repository: FakeAuthRepository(),
          onEditNumber: () => edited++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit number'));
    await tester.pumpAndSettle();
    expect(edited, 1);
  });

  testWidgets('"Send it again" asks the provider, not the screen', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_host(CodeView(repository: repository)));
    await tester.pumpAndSettle();
    await tester.pump(CodeView.resendWait);
    await tester.pump();

    await tester.tap(find.text('Send it again'));
    await tester.pumpAndSettle();

    expect(repository.resendCount, 1);
    await tester.pump(CodeView.resendWait);
  });

  group('"Send it again" waits after a code was sent', () {
    AppButton resendButton(WidgetTester tester, String label) =>
        tester.widget<AppButton>(
          find.ancestor(of: find.text(label), matching: find.byType(AppButton)),
        );

    testWidgets('the screen opens on a countdown, and a tap sends nothing', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await tester.pumpWidget(_host(CodeView(repository: repository)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Send it again in 0:30'), findsOneWidget);
      expect(resendButton(tester, 'Send it again in 0:30').onPressed, isNull);
      await tester.tap(find.text('Send it again in 0:30'));
      await tester.pump(const Duration(seconds: 5));
      expect(repository.resendCount, 0);
      expect(find.text('Send it again in 0:25'), findsOneWidget);
    });

    testWidgets('after thirty seconds it sends, once, and waits again', (
      tester,
    ) async {
      final repository = FakeAuthRepository();
      await tester.pumpWidget(_host(CodeView(repository: repository)));
      await tester.pump();
      await tester.pump(CodeView.resendWait);
      await tester.pump();

      expect(resendButton(tester, 'Send it again').onPressed, isNotNull);
      await tester.tap(find.text('Send it again'));
      await tester.pump();
      expect(repository.resendCount, 1);
      expect(find.text('Send it again in 0:30'), findsOneWidget);
      await tester.pump(CodeView.resendWait);
      await tester.pump();
      expect(find.text('Send it again'), findsOneWidget);
    });

    testWidgets('the countdown reads in Arabic', (tester) async {
      await tester.pumpWidget(
        _host(
          CodeView(repository: FakeAuthRepository()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('اطلبي الكود تاني بعد 0:30'), findsOneWidget);
      await tester.pump(CodeView.resendWait);
    });
  });

  testWidgets('reads in Arabic, and still says six', (tester) async {
    final repository = FakeAuthRepository();
    await repository.sendCode('+20 111 222 3333');
    await tester.pumpWidget(
      _host(CodeView(repository: repository), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('اكتبي الكود'), findsOneWidget);
    expect(
      find.textContaining('ستة أرقام'),
      findsOneWidget,
      reason: 'D2a changed the Arabic copy too, not only the English',
    );
    expect(find.textContaining('أربعة أرقام'), findsNothing);
    expect(find.text('Type the code'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    // Six 30px digits in a row is the tightest horizontal layout in the flow.
    await tester.pumpWidget(
      _host(
        CodeView(repository: FakeAuthRepository()),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}

/// A provider that refuses every code with [failure].
class _Refusing extends FakeAuthRepository {
  _Refusing(this.failure);

  final AuthFailure failure;

  @override
  Future<void> confirmCode(String code) async => throw AuthException(failure);
}
