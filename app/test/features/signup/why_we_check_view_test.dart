// C09 — One check, then you are in.
//
// The riskiest screen in the product, and the one whose copy is load-bearing
// rather than decorative. Three of these lines are promises the product is
// judged against, and each is a §2 rule in her words:
//
//   * "We never guess from your face"        → rule 8
//   * "both images are deleted after"        → rule 7
//   * "I wear niqab, check me another way"  → the niqab path is first class
//
// If any of them drifts out of the copy, the rule is still true in the backend
// and false to the woman reading the screen, which is the same as false.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/why_we_check_view.dart';
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
  testWidgets('states what is read, matched, deleted, and how long', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WhyWeCheckView()));
    await tester.pumpAndSettle();

    expect(find.text('One check, then you are in'), findsOneWidget);
    expect(find.textContaining('national ID card'), findsOneWidget);
    expect(
      find.textContaining('matched to the photo on the card'),
      findsOneWidget,
    );
    expect(find.textContaining('deleted after the check'), findsOneWidget);
    expect(find.textContaining('about 90 seconds'), findsOneWidget);
    expect(find.textContaining('licensed Egyptian provider'), findsOneWidget);
  });

  testWidgets('RULE 8 — it says out loud that her face is never judged', (
    tester,
  ) async {
    // The card says she is a woman; the app does not decide that by looking at
    // her. This sentence is the difference between this product and the thing a
    // court has already ruled is discrimination.
    await tester.pumpWidget(_host(const WhyWeCheckView()));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('We never guess from your face'),
      findsOneWidget,
    );
  });

  testWidgets(
    'RULE 7 — deletion is promised before she is asked for anything',
    (tester) async {
      await tester.pumpWidget(_host(const WhyWeCheckView()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('We keep the result, nothing else'),
        findsOneWidget,
      );
    },
  );

  testWidgets('the niqab path is on this screen, not hidden behind a failure', (
    tester,
  ) async {
    var scanned = 0;
    var niqab = 0;
    await tester.pumpWidget(
      _host(
        WhyWeCheckView(onScanId: () => scanned++, onNiqabPath: () => niqab++),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('I wear niqab, check me another way'), findsOneWidget);

    await tester.tap(find.text('I wear niqab, check me another way'));
    await tester.pumpAndSettle();

    expect(niqab, 1);
    expect(
      scanned,
      0,
      reason: 'she must not pass through the camera path to reach it',
    );
  });

  testWidgets('"Scan my ID" is the consent act and leads to the camera', (
    tester,
  ) async {
    var scanned = 0;
    await tester.pumpWidget(_host(WhyWeCheckView(onScanId: () => scanned++)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scan my ID'));
    await tester.pumpAndSettle();

    expect(scanned, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const WhyWeCheckView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('تحقّق واحد، ثم تدخلين'), findsOneWidget);
    expect(find.text('صوّري بطاقتي'), findsOneWidget);
    expect(
      find.textContaining('ولا نخمّن من وجهك أبدًا'),
      findsOneWidget,
      reason: 'rule 8 must be as plain in Arabic as in English',
    );
    expect(find.text('One check, then you are in'), findsNothing);
  });

  testWidgets('four bullets and two buttons survive the largest text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const WhyWeCheckView(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
