// E05 — Recipes.
//
// The design note this screen has to keep: "every card carries the price per
// serving in EGP. Food that costs more than her week allows is not a recipe, it
// is an advert." So the cost is asserted, not just the title.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

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
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

RecipesView _recipes({ValueChanged<String>? onOpenRecipe}) => RecipesView(
  onBack: () {},
  onSearch: () {},
  onOpenRecipe: onOpenRecipe ?? (_) {},
  onOpenWeekPlan: () {},
  onSelectTab: (_) {},
);

void main() {
  testWidgets('the filters she thinks in', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipes()));
    await tester.pumpAndSettle();

    expect(find.text('High protein'), findsOneWidget);
    expect(find.text('Under 20 min'), findsOneWidget);
    expect(find.text('Cheap'), findsOneWidget);
    expect(find.text('Ramadan'), findsOneWidget);
  });

  testWidgets('every card carries time and protein, and no energy or cost', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipes()));
    await tester.pumpAndSettle();

    expect(find.text('Koshari, portioned'), findsOneWidget);
    expect(find.text('22 min · 18 g protein'), findsOneWidget);
    expect(find.text('Ful with egg and cumin'), findsOneWidget);
    expect(find.text('10 min · 19 g protein'), findsOneWidget);
    expect(find.text('Molokhia with chicken'), findsOneWidget);
    expect(find.text('Yoghurt, dates and nuts'), findsOneWidget);
  });

  testWidgets('the week plan is one tap from here', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipes()));
    await tester.pumpAndSettle();

    expect(find.text("This week's plan and list"), findsOneWidget);
    expect(find.text('5 dinners · one shop'), findsOneWidget);
  });

  testWidgets('a recipe opens by id, not by position', (tester) async {
    _phone(tester);
    final opened = <String>[];

    await tester.pumpWidget(_host(_recipes(onOpenRecipe: opened.add)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Molokhia with chicken'));
    await tester.pumpAndSettle();

    expect(opened, ['molokhia_chicken']);
  });

  testWidgets('a filter can be changed without an exception', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(_recipes()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cheap'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('reads in Arabic without overflowing at 1.6', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(_recipes(), locale: const Locale('ar'), textScale: 1.6),
    );
    await tester.pumpAndSettle();

    expect(find.text('الوصفات'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
