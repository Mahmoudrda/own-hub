// C14 — Being checked.
//
// "Never a dead end" is this screen's stated metric, so that is what the tests
// assert. Three of them are really one product rule in three forms:
//
//   * the waiting card is amber, not error — a caution, not a failure;
//   * the copy says a woman reviewer is looking, with a time;
//   * workouts, recipes and coach profiles are all reachable from here.
//
// The last is G1's route contract: R01, E05 and H01 must render for an
// unverified account, because this screen's promise depends on it. If those rows
// ever stop being tappable, a pending check silently becomes a locked door.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/signup/presentation/being_checked_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_card.dart';

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
  testWidgets('says who is looking and how long it takes', (tester) async {
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    expect(find.text('Being checked'), findsOneWidget);
    expect(find.text('A woman reviewer is looking'), findsOneWidget);
    expect(
      find.text('Usually under two hours. We will text you.'),
      findsOneWidget,
    );
  });

  testWidgets('it is a caution, not a failure', (tester) async {
    // Amber is "not finished"; error is "something is wrong". One word of code
    // is the difference between waiting and being accused.
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    final card = tester.widget<AppCard>(
      find
          .ancestor(
            of: find.text('A woman reviewer is looking'),
            matching: find.byType(AppCard),
          )
          .first,
    );
    expect(card.variant, AppCardVariant.amber);
    expect(card.variant, isNot(AppCardVariant.error));
  });

  testWidgets('everything except the community is open while she waits', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const BeingCheckedView()));
    await tester.pumpAndSettle();

    expect(
      find.text('While you wait, everything here is open'),
      findsOneWidget,
    );
    expect(find.text('Workouts and videos'), findsOneWidget);
    expect(find.text('All 124, including the quiet ones'), findsOneWidget);
    expect(find.text('Recipes'), findsWidgets);
    expect(find.text('Coach profiles'), findsOneWidget);
    expect(find.textContaining('The community stays closed'), findsOneWidget);
  });

  testWidgets('all three destinations are actually reachable', (tester) async {
    var workouts = 0;
    var recipes = 0;
    var coaches = 0;
    await tester.pumpWidget(
      _host(
        BeingCheckedView(
          onOpenWorkouts: () => workouts++,
          onOpenRecipes: () => recipes++,
          onOpenCoaches: () => coaches++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workouts and videos'));
    await tester.tap(find.text('With portions and cost per serving'));
    await tester.tap(find.text('Coach profiles'));
    await tester.pumpAndSettle();

    expect(workouts, 1);
    expect(recipes, 1);
    expect(coaches, 1);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const BeingCheckedView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('قيد المراجعة'), findsOneWidget);
    expect(find.text('تطّلع عليها مراجِعة الآن'), findsOneWidget);
    expect(find.text('Being checked'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const BeingCheckedView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
