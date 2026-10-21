// E13 keeps a confirmed meal as one of her foods and offers its dish name and
// numbers to the shared list, unless she turned sharing off. Neither can fail
// or hold back the log.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/community_foods_state.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/data/community_food_client.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/custom_food.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_check.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/meal_check_view.dart';
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_toggle.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AppL10n _en = AppL10nEn();
final DateTime _lunchtime = DateTime(2026, 10, 17, 13, 12);

const MealScanResult _scan = MealScanResult(
  items: [
    ScannedItem(
      nameEn: 'Koshari',
      nameAr: 'كشري',
      grams: 400,
      matched: true,
      per100g: Macros(kcal: 150, proteinG: 5, carbsG: 27, fatG: 2.5, fiberG: 3),
    ),
  ],
);

class _FakeClient implements CommunityFoodClient {
  final List<Map<String, Object?>> sent = [];
  bool fails = false;

  @override
  Future<void> submit(Map<String, Object?> dish) async {
    sent.add(dish);
    if (fails) throw StateError('refused');
  }
}

void main() {
  late InMemoryMealRepository repository;
  late MealLogSession session;
  late _FakeClient client;
  final community = CommunityFoodsState.instance;
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    repository = InMemoryMealRepository();
    session = MealLogSession(repository: repository);
    client = _FakeClient();
    community.reset();
    community.client = client;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    session.reset();
    community.reset();
    EatCustomFoods.current = const [];
  });

  Future<void> pumpCheck(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: MealCheckView(
          result: _scan,
          constraints: DietaryConstraints.none,
          repository: repository,
          session: session,
          now: _lunchtime,
          onLogged: (LogHandle _) {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  Future<void> logIt(WidgetTester tester) async {
    final log = find.byKey(const ValueKey('meal-check-log'));
    await tester.ensureVisible(log);
    await tester.pump();
    await tester.tap(log);
    await tester.pump();
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    session.flushNow();
    await tester.pump();
  }

  testWidgets('logging keeps the meal as her food and offers the dish', (
    tester,
  ) async {
    await community.setSharing(true);
    await pumpCheck(tester);
    expect(find.text(_en.helpOtherWomenLogThisDish), findsOneWidget);
    expect(find.text(_en.onlyTheDishWhatsInItAnd), findsOneWidget);

    await logIt(tester);
    expect(
      client.sent,
      isEmpty,
      reason: 'nothing leaves inside the undo window',
    );
    expect((await repository.prefs()).customFoods, isEmpty);
    await settle(tester);

    final prefs = await repository.prefs();
    expect(prefs.customFoods, hasLength(1));
    final food = prefs.customFoods.single;
    expect(food.name, 'Koshari');
    expect(food.kcal, 600);
    expect(food.proteinG, 20);
    expect(food.carbsG, 108);
    expect(food.fatG, 10);
    expect(EatCustomFoods.current.single.name, 'Koshari');

    expect(client.sent, [
      {
        'nameEn': 'Koshari',
        'nameAr': 'كشري',
        'items': [
          {'name': 'Koshari', 'grams': 400},
        ],
        'kcal': 600,
        'proteinG': 20,
        'carbsG': 108,
        'fatG': 10,
      },
    ]);
    expect(community.noticeSeen, isTrue);
  });

  testWidgets('a meal she undoes is neither kept nor shared', (tester) async {
    await pumpCheck(tester);
    await logIt(tester);
    final handle = session.pending.single.handle;
    expect(session.undo(handle), isTrue);
    await settle(tester);
    await tester.pump(const Duration(seconds: 6));
    expect(client.sent, isEmpty);
    expect((await repository.prefs()).customFoods, isEmpty);
    expect(community.noticeSeen, isFalse);
  });

  test('sharing off and an immediate offer sends nothing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kShareDishesKey: false,
    });
    community.reset();
    community.client = client;
    await community.offer(<String, Object?>{'nameEn': 'x'});
    expect(client.sent, isEmpty);
    expect(community.sharing, isFalse);
  });

  test('turning sharing off before settings load is not overwritten', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    community.reset();
    community.client = client;
    await community.setSharing(false);
    await community.offer(<String, Object?>{'nameEn': 'x'});
    expect(client.sent, isEmpty);
    expect(
      (await SharedPreferences.getInstance()).getBool(kShareDishesKey),
      isFalse,
    );
  });

  test('a kept meal carries the union of its parts\' allergens', () async {
    final food = await EatAppState.instance.rememberMealAsFood(
      repository,
      name: 'Plate',
      kcal: 400,
      proteinG: 20,
      allergens: {'gluten', 'sesame'},
    );
    expect(food.allergens, {'gluten', 'sesame'});
    expect(food.toFood().allergens, {'gluten', 'sesame'});
    final unknown = await EatAppState.instance.rememberMealAsFood(
      repository,
      name: 'Photo plate',
      kcal: 400,
      proteinG: 20,
    );
    expect(unknown.allergens, isNull, reason: 'unknown is not none');
    expect(unknown.toFood().allergensUnknown, isTrue);
    final again = CustomFood.fromJson(food.toJson())!;
    expect(again.allergens, {'gluten', 'sesame'});
  });

  test(
    'a photo plate\'s allergens are unknown, a library plate\'s are known',
    () {
      expect(MealCheck.fromScan(_scan).allergens, isNull);
      expect(MealCheck.empty.allergens, isNull);
      const bread = Food(
        foodId: 'f1',
        names: ['Bread'],
        sizes: [FoodSize(id: '1', label: '1', kcal: 100, proteinG: 3)],
        allergens: {'gluten'},
      );
      const tahini = Food(
        foodId: 'f2',
        names: ['Tahini'],
        sizes: [FoodSize(id: '1', label: '1', kcal: 100, proteinG: 3)],
        allergens: {'sesame'},
      );
      final foods = [
        CheckItem.library('a', bread, bread.sizes.first),
        CheckItem.library('b', tahini, tahini.sizes.first),
      ];
      expect(MealCheck(foods).allergens, {'gluten', 'sesame'});
      expect(
        MealCheck([...foods, ...MealCheck.fromScan(_scan).items]).allergens,
        isNull,
      );
    },
  );

  testWidgets('a second meal with the same name replaces, never duplicates', (
    tester,
  ) async {
    final first = await EatAppState.instance.rememberMealAsFood(
      repository,
      name: 'Koshari',
      kcal: 300,
      proteinG: 10,
    );
    await pumpCheck(tester);
    await logIt(tester);
    await settle(tester);

    final foods = (await repository.prefs()).customFoods;
    expect(foods, hasLength(1));
    expect(foods.single.id, first.id);
    expect(foods.single.kcal, 600);
    await settle(tester);
  });

  testWidgets('by default nothing is sent, the food is still kept', (
    tester,
  ) async {
    await pumpCheck(tester);
    expect(community.sharing, isFalse);

    await logIt(tester);
    await settle(tester);

    expect(client.sent, isEmpty);
    expect((await repository.prefs()).customFoods, hasLength(1));
    await settle(tester);
  });

  testWidgets('with the switch turned on and off again nothing is sent', (
    tester,
  ) async {
    await pumpCheck(tester);
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    expect(community.sharing, isTrue);
    await tester.tap(find.byType(AppToggle));
    await tester.pump();
    expect(community.sharing, isFalse);

    await logIt(tester);
    await settle(tester);

    expect(client.sent, isEmpty);
    expect((await repository.prefs()).customFoods, hasLength(1));
    final saved = await SharedPreferences.getInstance();
    expect(saved.getBool(kShareDishesKey), isFalse);
    await settle(tester);
  });

  testWidgets('a refused share never blocks the log', (tester) async {
    client.fails = true;
    await community.setSharing(true);
    await pumpCheck(tester);
    await logIt(tester);
    expect(session.pending, isNotEmpty);
    await settle(tester);
    expect(client.sent, hasLength(1));
  });

  testWidgets('the switch is shown only until she has seen it once', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      kShareDishesSeenKey: true,
    });
    await pumpCheck(tester);
    expect(find.text(_en.helpOtherWomenLogThisDish), findsNothing);
    expect(community.sharing, isFalse);
    await logIt(tester);
    await settle(tester);
    expect(client.sent, isEmpty);
  });

  test('a plate that cannot be shared is not offered', () {
    // No carbs or fat on the part: nothing honest to send.
    const bare = MealScanResult(
      items: [
        ScannedItem(
          nameEn: 'Tea',
          nameAr: 'شاي',
          grams: 200,
          matched: true,
          per100g: Macros(kcal: 40, proteinG: 1),
        ),
      ],
    );
    expect(MealCheck.fromScan(bare).communityDish('en'), isNull);
    // Energy far from 4/4/9: the server would refuse it.
    const odd = MealScanResult(
      items: [
        ScannedItem(
          nameEn: 'Odd',
          nameAr: 'غريب',
          grams: 100,
          matched: true,
          per100g: Macros(kcal: 900, proteinG: 1, carbsG: 1, fatG: 1),
        ),
      ],
    );
    expect(MealCheck.fromScan(odd).communityDish('en'), isNull);
  });
}
