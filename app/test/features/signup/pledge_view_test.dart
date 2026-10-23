// C16 — How we treat each other.
//
// Three rules, one tap. The one worth guarding by name is the second: "no
// comments on anyone else's body, not even a compliment". It is the rule that
// makes a women-only fitness community survive its first month, and it is the
// one most likely to be softened by someone who reads it as unfriendly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/presentation/pledge_view.dart';
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
    saved = AppRouter.featureFlags;
    AppRouter.featureFlags = FeatureFlags.everything;
  });
  tearDown(() => AppRouter.featureFlags = saved);

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

    // R1-P7: said plainly, without the threat of "you lose your place".
    expect(
      find.text(
        'Breaking them can close your account. '
        'You can read them again any time.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('you lose your place'), findsNothing);
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

    expect(find.text('إزاي بنعامل بعض'), findsOneWidget);
    expect(find.text('1 · اللي بيتقال هنا بيفضل هنا'), findsOneWidget);
    expect(find.text('2 · مفيش تعليق على جسم أي ست تانية'), findsOneWidget);
    // R1-P24: the button no longer addresses the app as a woman.
    expect(find.text('موافقة، يلا نبدأ'), findsOneWidget);
    expect(find.text('أوافق، أدخليني'), findsNothing);
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
