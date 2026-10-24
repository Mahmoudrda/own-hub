// ignore_for_file: avoid_print
//
// Screen budgets for the Eat tab (release 2): E01 "What I ate today" and E02
// "Find and add". At most one filled primary, at most four hero figures, and
// the controls above the fold counted by the same counter the other screens
// use, in English and Arabic, at 390x844 and 375x667.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_hub_view.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart'
    show PlusButton;
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_progress.dart';
import 'package:own_hub/ui/app_stat_hero.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';

const _maxHeroFigures = 4;

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);
const String _dayId = '2026-09-15';

MealItem _breakfast() => MealItem(
  itemId: 'breakfast-1',
  foodId: 'ful_baladi',
  servings: 1,
  size: 'M',
  loggedAt: DateTime(2026, 9, 15, 8, 40),
  source: MealSource.search,
  origin: MealOrigin.suggestion,
  kcal: 410,
  proteinG: 22,
);

/// Breakfast logged, and a plate she has at lunch twice, so lunch offers it.
InMemoryMealRepository _midDay() {
  final repository = InMemoryMealRepository(
    prefs: EatPrefs(
      plates: {
        'plate_molokhia_chicken': Plate(
          plateId: 'plate_molokhia_chicken',
          items: [PlateItem(foodId: 'molokhia_chicken', size: 'M')],
          dayCounts: const {'2026-09-08': 1, '2026-09-14': 1},
          slotCounts: const {MealSlot.lunch: 2},
          dowCounts: const {DateTime.tuesday: 2},
          lastAt: DateTime(2026, 9, 14, 13),
        ),
      },
    ),
  );
  repository.store.days[_dayId] = MealDay(
    dayId: _dayId,
    slots: {
      MealSlot.breakfast: [_breakfast()],
    },
  );
  return repository;
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUpAll(() {
    EgyptianFoodPack.adopt(
      File('assets/content/foods_eg.json').readAsStringSync(),
    );
  });
  tearDownAll(EgyptianFoodPack.reset);
  // Every control on: the camera, the microphone, Recipes and Plan.
  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = savedFlags);

  final book = RecipeBook.fromJson(
    (jsonDecode(
      File('assets/content/rahma_recipes.json').readAsStringSync(),
    ) as Map).cast<String, Object?>(),
  );

  Widget host(
    InMemoryMealRepository repository,
    MealLogSession session,
    Locale locale,
  ) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: EatHubView(
      constraints: DietaryConstraints.none,
      repository: repository,
      session: session,
      now: _lunchtime,
      book: book,
      onSnap: () {},
      onSpeak: () {},
      onSelectTab: (_) {},
    ),
  );

  void size(WidgetTester tester, Size logical) {
    tester.view.physicalSize = logical * 3;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  int heroFigures(WidgetTester tester) {
    final hero = find.byKey(const ValueKey('eat-hero'));
    if (hero.evaluate().isEmpty) return 0;
    final stat = find.descendant(of: hero, matching: find.byType(AppStatHero));
    final bars = find.descendant(
      of: hero,
      matching: find.byType(AppProgressBar),
    );
    expect(
      find.descendant(
        of: hero,
        matching: find.byKey(const ValueKey('day-card-more-macros')),
      ),
      findsNothing,
      reason: 'fibre is not a hero figure',
    );
    return stat.evaluate().length + bars.evaluate().length;
  }

  /// The "+" buttons that do something, in the viewport.
  int plusButtons(WidgetTester tester) => find
      .byWidgetPredicate((w) => w is PlusButton && w.onPressed != null)
      .hitTestable()
      .evaluate()
      .length;

  // The counter counts every "+" as a control, and each meal row and each food
  // row has its own. [otherCeiling] is the plan's five, with the "+" buttons
  // set aside; [strictCeiling] pins the count with every "+" included.
  final cases =
      <
        ({
          String name,
          InMemoryMealRepository Function() repository,
          Future<void> Function(WidgetTester) enter,
          int otherCeiling,
          int strictCeiling,
        })
      >[
        (
          name: 'E01 empty day',
          repository: InMemoryMealRepository.new,
          enter: (_) async {},
          otherCeiling: 5,
          strictCeiling: 8,
        ),
        (
          name: 'E01 mid-day with logged meals',
          repository: _midDay,
          enter: (_) async {},
          otherCeiling: 5,
          strictCeiling: 8,
        ),
        (
          name: 'E02 find, empty',
          repository: _midDay,
          enter: (tester) async {
            await tester.tap(find.byKey(const ValueKey('eat-hub-search')));
            await tester.pumpAndSettle();
          },
          otherCeiling: 8,
          strictCeiling: 9,
        ),
        (
          name: 'E02 find, typed text',
          repository: _midDay,
          enter: (tester) async {
            await tester.enterText(
              find.byKey(const ValueKey('eat-hub-search')),
              'koshari',
            );
            await tester.pumpAndSettle();
          },
          otherCeiling: 9,
          strictCeiling: 9,
        ),
      ];

  for (final locale in const [Locale('en'), Locale('ar')]) {
    for (final logical in const [Size(390, 844), Size(375, 667)]) {
      for (final c in cases) {
        testWidgets('${c.name}, ${locale.languageCode}, '
            '${logical.width.toInt()}x${logical.height.toInt()}', (
          tester,
        ) async {
          size(tester, logical);
          final repository = c.repository();
          final session = MealLogSession(repository: repository);
          addTearDown(() async {
            await session.bus.flushAll();
            session.dispose();
          });
          await tester.pumpWidget(host(repository, session, locale));
          await tester.pumpAndSettle();
          await c.enter(tester);

          final controls = countControlsAboveFold(tester);
          final plus = plusButtons(tester);
          final figures = heroFigures(tester);
          print(
            'EATBUDGET ${c.name} ${locale.languageCode} '
            '${logical.width.toInt()}x${logical.height.toInt()} '
            'controls=$controls plus=$plus '
            'primary=${filledPrimaryActions(tester)} figures=$figures',
          );
          expect(tester.takeException(), isNull);
          expectAtMostOnePrimaryAction(tester, where: c.name);
          expect(figures, lessThanOrEqualTo(_maxHeroFigures));
          expect(
            controls - plus,
            lessThanOrEqualTo(c.otherCeiling),
            reason: '${c.name}: other controls, the "+" buttons set aside',
          );
          expect(
            controls,
            lessThanOrEqualTo(c.strictCeiling),
            reason: '${c.name}: strict count, every "+" included',
          );
        });
      }
    }
  }
}
