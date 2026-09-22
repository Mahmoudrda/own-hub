// C16 — How we treat each other.
//
// Three rules, one tap. The one worth guarding by name is the second: "no
// comments on anyone else's body, not even a compliment". It is the rule that
// makes a women-only fitness community survive its first month, and it is the
// one most likely to be softened by someone who reads it as unfriendly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/pledge_view.dart';
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
  testWidgets('shows all three rules, each with its one sentence', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const PledgeView()));
    await tester.pumpAndSettle();

    expect(find.text('How we treat each other'), findsOneWidget);
    expect(
      find.text('Three rules. They are the whole reason this place works.'),
      findsOneWidget,
    );

    expect(find.text('1 · What is said here stays here'), findsOneWidget);
    expect(
      find.text('No screenshots, no sharing anyone else outside.'),
      findsOneWidget,
    );

    expect(find.text("2 · No comments on anyone else's body"), findsOneWidget);
    expect(
      find.text('Not even a compliment. Talk about the work instead.'),
      findsOneWidget,
    );

    expect(find.text('3 · No selling, no recruiting'), findsOneWidget);
    expect(find.text('Coaches have profiles for that.'), findsOneWidget);
  });

  testWidgets('the body-comments rule keeps its teeth', (tester) async {
    // "Not even a compliment" is the whole rule. Without that clause it is an
    // etiquette note rather than a boundary.
    await tester.pumpWidget(_host(const PledgeView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Not even a compliment'), findsOneWidget);
  });

  testWidgets('says what breaking one costs', (tester) async {
    await tester.pumpWidget(_host(const PledgeView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('you lose your place'), findsOneWidget);
    expect(find.textContaining('read them again any time'), findsOneWidget);
  });

  testWidgets('agreeing is one tap, and it is reported', (tester) async {
    var agreed = 0;
    await tester.pumpWidget(_host(PledgeView(onAgree: () => agreed++)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('I agree, let me in'));
    await tester.pumpAndSettle();

    expect(agreed, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const PledgeView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('كيف نعامل بعضنا'), findsOneWidget);
    expect(find.text('1 · ما يُقال هنا يبقى هنا'), findsOneWidget);
    expect(find.text('2 · لا تعليق على جسد أي امرأة أخرى'), findsOneWidget);
    expect(find.text('أوافق، أدخليني'), findsOneWidget);
    expect(find.text('How we treat each other'), findsNothing);
  });

  testWidgets('three stacked cards survive the largest text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const PledgeView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
