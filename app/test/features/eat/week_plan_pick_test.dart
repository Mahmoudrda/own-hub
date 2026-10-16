// R1-P11: the week plan can be chosen, and planning has a day-one door.
//
// E07's rows open E05 in pick mode for an empty day (and from the swap icon
// for any day); the recipe she taps there goes on that day. "Fill my week"
// puts Rahma's dinners on every empty day and leaves the days she chose
// alone. Eat on day one offers the week plan and Rahma's recipes, which were
// three screens away.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/features/eat/presentation/week_plan_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 13, 12);
final String _weekId = WeekKey.of(_tuesday).id;

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

const Map<String, String> _titles = {
  'rahma_a': 'Molokhia, her way',
  'rahma_b': 'Lentil soup, her way',
};

void main() {
  group('E07', () {
    testWidgets('"Fill my week" fills every empty day and keeps hers', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      await repository.swapDinner(
        weekId: _weekId,
        day: PlanDay.tue,
        recipeId: 'koshari_portioned',
      );
      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: repository,
            now: _tuesday,
            fillFrom: const ['rahma_a', 'rahma_b'],
            recipeTitle: (id) => _titles[id],
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('e07-fill-week')));
      await tester.pumpAndSettle();

      final plan = (await repository.mealPlan(_weekId))!;
      expect(plan.dinners[PlanDay.tue], 'koshari_portioned');
      for (final day in [PlanDay.mon, PlanDay.wed, PlanDay.thu, PlanDay.fri]) {
        expect(plan.dinners[day], isIn(_titles.keys), reason: '$day');
      }
      // Her names, not a fallback label, on the rows.
      expect(find.text('Molokhia, her way'), findsWidgets);
      expect(find.text('Lentil soup, her way'), findsWidgets);
      // Every day is planned, so the button has nothing left to do.
      expect(find.byKey(const ValueKey('e07-fill-week')), findsNothing);
    });

    testWidgets('no candidates, no button', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          WeekPlanView(repository: InMemoryMealRepository(), now: _tuesday),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('e07-fill-week')), findsNothing);
    });

    testWidgets('an empty day asks what goes on it, and the week updates', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final asked = <PlanDay>[];
      await tester.pumpWidget(
        _host(
          WeekPlanView(
            repository: repository,
            now: _tuesday,
            onPickDinner: (day) async {
              asked.add(day);
              // What E05 in pick mode does with her tap.
              await repository.swapDinner(
                weekId: _weekId,
                day: day,
                recipeId: 'rahma_a',
              );
            },
            recipeTitle: (id) => _titles[id],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('e07-day-wed')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('e07-plan-week')));
      await tester.pumpAndSettle();
      expect(asked, [PlanDay.mon]);
      expect(find.text('Molokhia, her way'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('e07-day-wed')));
      await tester.pumpAndSettle();
      expect(asked, [PlanDay.mon, PlanDay.wed]);

      // A planned day changes from its swap icon.
      expect(find.byTooltip('Change this dinner'), findsWidgets);
      await tester.tap(find.byKey(const ValueKey('e07-swap-wed')));
      await tester.pumpAndSettle();
      expect(asked, [PlanDay.mon, PlanDay.wed, PlanDay.wed]);
    });
  });

  group('E05 in pick mode', () {
    testWidgets('says which day, and a tap puts the recipe there', (
      tester,
    ) async {
      _phone(tester);
      final picked = <String>[];
      final opened = <String>[];
      await tester.pumpWidget(
        _host(
          RecipesView(
            pickLabel: 'Pick a dinner for Monday',
            onPick: picked.add,
            onOpenRecipe: opened.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pick a dinner for Monday'), findsOneWidget);
      // Not a door to the week she is already choosing for.
      expect(find.text("This week's plan and list"), findsNothing);

      await tester.tap(find.text("Koshari, portioned"));
      await tester.pumpAndSettle();
      expect(picked, ['koshari_portioned']);
      expect(opened, isEmpty);
    });

    testWidgets('the ordinary library still opens a recipe', (tester) async {
      _phone(tester);
      final opened = <String>[];
      await tester.pumpWidget(_host(RecipesView(onOpenRecipe: opened.add)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('e05-pick-label')), findsNothing);
      expect(find.text("This week's plan and list"), findsOneWidget);
    });

    testWidgets('the day line reads in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => RecipesView(
              pickLabel: AppL10n.of(context)
                  .pickADinnerForDay(AppL10n.of(context).monday),
              onPick: (_) {},
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('اختاري عشا ليوم'), findsOneWidget);
    });
  });

  group('Eat on day one', () {
    testWidgets('offers the week plan', (tester) async {
      _phone(tester);
      var opened = 0;
      await tester.pumpWidget(
        _host(
          EatView(
            constraints: DietaryConstraints.none,
            repository: InMemoryMealRepository(),
            now: _tuesday,
            onOpenWeekPlan: () => opened++,
            onOpenRecipes: () {},
            onType: () {},
            onSpeak: () {},
            onSelectTab: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No plates yet'), findsOneWidget, reason: 'day one');
      final row = find.byKey(const ValueKey('eat-day-one-week-plan'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      expect(opened, 1);
    });
  });

  group('through the router', () {
    final savedFlags = AppRouter.featureFlags;
    setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
    tearDown(() => AppRouter.featureFlags = savedFlags);

    testWidgets('a day swapped on E05 is on E07 when she is back', (
      tester,
    ) async {
      _phone(tester);
      final weekId = WeekKey.of(DateTime.now()).id;
      // Her app starts with no week; this one has a week to swap in.
      AppRouter.mealRepository.store.plans[weekId] = sampleMealPlan(weekId);
      addTearDown(() => AppRouter.mealRepository.store.plans.remove(weekId));
      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          initialRoute: appRoutes['E07']!.name,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('e07-swap-wed')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('e05-pick-label')), findsOneWidget);
      expect(find.text('Pick a dinner for Wednesday'), findsOneWidget);

      await tester.tap(find.text('Koshari, portioned'));
      await tester.pumpAndSettle();

      expect(find.byType(WeekPlanView), findsOneWidget);
      final after = (await AppRouter.mealRepository.mealPlan(weekId))!;
      expect(after.dinners[PlanDay.wed], 'koshari_portioned');
      expect(find.text('Koshari, portioned'), findsNWidgets(2));
    });
  });
}
