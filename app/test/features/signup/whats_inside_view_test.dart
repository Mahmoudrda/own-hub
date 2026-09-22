// C03 — What's inside. The screen that makes the product's four promises.
//
// Worth testing beyond "the text is present": these four lines are the claims
// the whole product is judged against, and three of them are load-bearing
// elsewhere — "no equipment" constrains the programme generator, "verified with
// ID" is the women-only gate, "paid monthly in Egyptian pounds" is the payment
// model. If the copy drifts, those promises drift with it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/whats_inside_view.dart';
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
  testWidgets('makes all four promises', (tester) async {
    await tester.pumpWidget(_host(const WhatsInsideView()));
    await tester.pumpAndSettle();

    expect(find.text("What's inside"), findsOneWidget);
    expect(find.text('Quiet workouts for home'), findsOneWidget);
    expect(find.text('Food you already cook'), findsOneWidget);
    expect(find.text('Women only, every member checked'), findsOneWidget);
    expect(find.text('Coaches who get it'), findsOneWidget);
  });

  testWidgets('each promise carries its explanation, not just a headline', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WhatsInsideView()));
    await tester.pumpAndSettle();

    // The specifics are the promise. "Quiet workouts" without "no jumping, your
    // neighbours will never know" is marketing; with it, it is a commitment.
    expect(find.textContaining('No jumping, no equipment'), findsOneWidget);
    expect(find.textContaining('Koshari, ful and molokhia'), findsOneWidget);
    expect(find.textContaining('verified with ID'), findsOneWidget);
    expect(find.textContaining('Egyptian pounds'), findsOneWidget);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const WhatsInsideView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("What's inside"),
      findsNothing,
      reason: 'English copy here means a string bypassed AppL10n',
    );
    expect(
      Directionality.of(tester.element(find.byType(WhatsInsideView).first)),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('four promises survive the largest text size in Arabic', (
    tester,
  ) async {
    // The densest screen in the flow: four wrapped paragraphs plus two buttons.
    await tester.pumpWidget(
      _host(
        const WhatsInsideView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('both ways forward work', (tester) async {
    var created = 0;
    var looked = 0;
    await tester.pumpWidget(
      _host(
        WhatsInsideView(
          onCreateAccount: () => created++,
          onLookAround: () => looked++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create my account'));
    await tester.tap(find.text('Look around first'));
    await tester.pumpAndSettle();

    expect(created, 1);
    expect(looked, 1);
  });
}
