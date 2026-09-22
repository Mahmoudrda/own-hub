// C01 — the first screen a woman ever sees.
//
// Covers the P2 state rows for C01 (RTL and large text) and the parts of
// P0-VER-01 that begin here. The assertions worth having are the ones that catch
// silent failures: text that vanishes in Arabic, a layout that overflows at the
// largest system font, and copy that bypassed the dictionary.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/welcome_view.dart';
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
  testWidgets('shows the promise, the explanation and both ways in', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WelcomeView()));
    await tester.pumpAndSettle();

    expect(find.text('A room full of women training like you'), findsOneWidget);
    expect(find.textContaining('Quiet workouts for home'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every string comes from the dictionary, in Arabic too', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const WelcomeView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    // If a string were hardcoded in English it would still read English here,
    // which is exactly the failure a hardcoded string produces in production.
    expect(find.text('غرفة مليئة بنساء يتدرّبن مثلك'), findsOneWidget);
    expect(find.text('لنبدأ'), findsOneWidget);
    expect(find.text('لديّ حساب بالفعل'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);
  });

  testWidgets('lays out right-to-left in Arabic', (tester) async {
    await tester.pumpWidget(
      _host(const WelcomeView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    final direction = Directionality.of(tester.element(find.text('لنبدأ')));
    expect(direction, TextDirection.rtl);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    // Arabic runs longer than English and this screen has no scroll, so it is
    // the most likely place in the product for text to be clipped.
    await tester.pumpWidget(
      _host(const WelcomeView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(
      tester.takeException(),
      isNull,
      reason:
          'a RenderFlex overflow at large text is a real defect, not a '
          'cosmetic one — it hides the button she needs',
    );
  });

  testWidgets('both actions are reachable and fire', (tester) async {
    var started = 0;
    var signedIn = 0;
    await tester.pumpWidget(
      _host(
        WelcomeView(onGetStarted: () => started++, onSignIn: () => signedIn++),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Get started'));
    await tester.tap(find.text('I already have an account'));
    await tester.pumpAndSettle();

    expect(started, 1);
    expect(signedIn, 1);
  });

  testWidgets('the primary action meets the minimum tap target', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WelcomeView()));
    await tester.pumpAndSettle();

    final size = tester.getSize(
      find
          .ancestor(
            of: find.text('Get started'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(
      size.height,
      greaterThanOrEqualTo(44),
      reason: 'tapped one-handed, mid-set',
    );
  });
}
