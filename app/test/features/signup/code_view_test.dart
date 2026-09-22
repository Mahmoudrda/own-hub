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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await tester.pumpWidget(_host(CodeView(repository: FakeAuthRepository())));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text('Type the code'), findsOneWidget);
    expect(find.textContaining('We sent six digits'), findsOneWidget);
    expect(find.textContaining('sixth digit lands'), findsOneWidget);
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
    expect(
      find.textContaining('+20 100 555 0132'),
      findsNothing,
      reason:
          'the placeholder is a fallback for an impossible state, '
          'never what she is shown',
    );
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
      _host(CodeView(repository: repository, onConfirmed: () => confirmed++)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '417293');
    await tester.pumpAndSettle();

    expect(confirmed, 1, reason: 'no Continue tap was needed');
    expect(repository.current, isA<AuthSignedIn>());
  });

  testWidgets('a wrong code clears the boxes for another try', (tester) async {
    // There is no wrong-code copy in the dictionary yet, so the retry has to be
    // obvious without words: the boxes empty and she types again.
    final repository = FakeAuthRepository(codeToAccept: '417293');
    var confirmed = 0;
    await tester.pumpWidget(
      _host(CodeView(repository: repository, onConfirmed: () => confirmed++)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '000000');
    await tester.pumpAndSettle();

    expect(confirmed, 0);
    expect(repository.current, isA<AuthSignedOut>());
    expect(find.text('0'), findsNothing, reason: 'the boxes emptied');
  });

  testWidgets('"Send it again" asks the provider, not the screen', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    await tester.pumpWidget(_host(CodeView(repository: repository)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send it again'));
    await tester.pumpAndSettle();

    expect(repository.resendCount, 1);
  });

  testWidgets('reads in Arabic, and still says six', (tester) async {
    await tester.pumpWidget(
      _host(
        CodeView(repository: FakeAuthRepository()),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اكتبي الرمز'), findsOneWidget);
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
