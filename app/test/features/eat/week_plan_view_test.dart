// E07 — This week, and E08 — Grocery list.
//
// Both read the SAME mealPlans/{yyyy-Www} document, which is what makes opening
// the list from the plan cost zero additional reads. The tests seed one
// repository and drive both screens from it, so that sharing is exercised
// rather than assumed.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/item_id.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/grocery_list_view.dart';
import 'package:own_hub/features/eat/presentation/week_plan_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 13, 12);
final String _weekId = WeekKey.of(_tuesday).id;

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

InMemoryMealRepository _seeded() =>
    InMemoryMealRepository(plans: {_weekId: sampleMealPlan(_weekId)});

void main() {
  group('E07 — the week plan', () {
    testWidgets('five dinners, built from recipes she has logged', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onRegenerate: () {},
            onOpenRecipe: (_) {},
            onOpenGroceryList: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('This week'), findsOneWidget);
      expect(
        find.textContaining('Five dinners, built from recipes'),
        findsOneWidget,
      );
      expect(find.text('Molokhia with chicken'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);
      expect(find.text('Koshari, portioned'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Ful with egg'), findsOneWidget);
      expect(find.text('Friday'), findsOneWidget);
    });

    testWidgets('a lead given replaces the line, and with no way to pick a '
        'dinner the rows offer no swap', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: _seeded(),
            now: _tuesday,
            lead: 'A sample week.',
            onOpenRecipe: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A sample week.'), findsOneWidget);
      expect(find.textContaining('Five dinners, built from'), findsNothing);
      expect(find.byIcon(Icons.swap_horiz), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNWidgets(5));
    });

    testWidgets('the one-shop card leads to the list', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onOpenRecipe: (_) {},
            onOpenGroceryList: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('One shop covers it'), findsOneWidget);
      // "23 items · about 640 EGP" counted a list it had not read and priced a
      // market it does not know: `GroceryLine` carries an ingredient, a group
      // and a tick, and no price at all. Half the sentence would have to be
      // invented, so the sentence is not said.
      expect(find.text('23 items · about 640 EGP'), findsNothing);
      expect(find.text('See the grocery list'), findsOneWidget);
    });

    testWidgets('a swap opens the recipe by id', (tester) async {
      _phone(tester);
      final opened = <String>[];

      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onOpenRecipe: opened.add,
            onOpenGroceryList: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Koshari, portioned'));
      await tester.pumpAndSettle();

      expect(opened, ['koshari_portioned']);
    });

    testWidgets('reads in Arabic without overflowing at 1.6', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onOpenRecipe: (_) {},
            onOpenGroceryList: () {},
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الأسبوع ده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('E08 — the grocery list', () {
    testWidgets('grouped the way an Egyptian market trip goes', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          GroceryListView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onShare: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grocery list'), findsOneWidget);
      expect(find.textContaining('Grouped the way you shop'), findsOneWidget);
      expect(find.text('Vegetables'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Cupboard'), findsOneWidget);
      expect(find.text('Tomatoes 1 kg'), findsOneWidget);
      expect(find.text('Chicken 1 kg'), findsOneWidget);
      expect(find.text('Cumin'), findsOneWidget);
    });

    testWidgets('a tick survives — it reaches the document', (tester) async {
      _phone(tester);
      final repository = _seeded();

      await tester.pumpWidget(
        _host(
          GroceryListView(
            repository: repository,
            now: _tuesday,
            onBack: () {},
            onShare: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final onions = groceryItemKey(ingredientId: 'onions', unit: 'kg');
      expect(
        repository.store.plans[_weekId]!.groceries[onions]!.ticked,
        isFalse,
      );

      await tester.tap(find.text('Onions 1 kg'));
      await tester.pumpAndSettle();

      expect(
        repository.store.plans[_weekId]!.groceries[onions]!.ticked,
        isTrue,
        reason:
            'E08 must survive being closed mid-shop, so a tick is not '
            'merely a widget state',
      );
    });

    testWidgets('ticking again un-ticks it', (tester) async {
      _phone(tester);
      final repository = _seeded();

      await tester.pumpWidget(
        _host(
          GroceryListView(
            repository: repository,
            now: _tuesday,
            onBack: () {},
            onShare: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tomatoes ships ticked in the sample week.
      final tomatoes = groceryItemKey(ingredientId: 'tomatoes', unit: 'kg');
      await tester.tap(find.text('Tomatoes 1 kg'));
      await tester.pumpAndSettle();

      expect(
        repository.store.plans[_weekId]!.groceries[tomatoes]!.ticked,
        isFalse,
      );
    });

    testWidgets('ticking a line draws the tick and gives a light tap', (
      tester,
    ) async {
      _phone(tester);
      final felt = <String?>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              felt.add(call.arguments as String?);
            }
            return null;
          });
      final saved = AppHaptics.enabled;
      AppHaptics.enabled = () => true;
      addTearDown(() {
        AppHaptics.enabled = saved;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(
        _host(
          GroceryListView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onShare: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = find.byType(HandTick).evaluate().length;

      await tester.tap(find.text('Onions 1 kg'));
      await tester.pump();
      expect(find.byType(HandTick), findsNWidgets(before + 1));
      expect(felt, ['HapticFeedbackType.lightImpact']);
      await tester.pumpAndSettle();

      // Taking a tick back is not a thing to celebrate.
      await tester.tap(find.text('Onions 1 kg'));
      await tester.pumpAndSettle();
      expect(find.byType(HandTick), findsNWidgets(before));
      expect(felt, hasLength(1));
    });

    testWidgets('reads in Arabic without overflowing at 1.6', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          GroceryListView(
            repository: _seeded(),
            now: _tuesday,
            onBack: () {},
            onShare: () {},
            onSelectTab: (_) {},
          ),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('قايمة المشتريات'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
