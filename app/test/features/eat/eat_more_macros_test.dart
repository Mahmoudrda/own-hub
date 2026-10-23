// E01: carbs, fat and fibre on the day card once anything carries them, as a
// quiet line under protein; and the camera beside the box only when the
// router offers it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _lunchtime = DateTime(2026, 10, 17, 13, 12);
const String _day = '2026-10-17';
final AppL10n _en = AppL10nEn();

MealItem _item({int? carbs, int? fat, int? fiber, String id = 'a'}) => MealItem(
  itemId: id,
  foodId: 'boiled_eggs',
  servings: 1,
  size: '2',
  loggedAt: _lunchtime.subtract(const Duration(hours: 4)),
  source: MealSource.search,
  origin: MealOrigin.search,
  kcal: 156,
  proteinG: 13,
  carbsG: carbs,
  fatG: fat,
  fiberG: fiber,
);

InMemoryMealRepository _repoWith(List<MealItem> items) {
  final repository = InMemoryMealRepository();
  repository.store.apply(
    MealWrite.transform(
      dayId: _day,
      slot: MealSlot.breakfast,
      tz: WeekKey.fallbackTimezone,
      libVersion: 1,
      added: items,
    ),
  );
  return repository;
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

EatView _eat(MealRepository repository, {VoidCallback? onSnap}) => EatView(
  constraints: DietaryConstraints.none,
  repository: repository,
  now: _lunchtime,
  onType: () {},
  onSnap: onSnap,
  onSelectTab: (_) {},
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the day card adds carbs, fat and fibre under protein', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        _eat(
          _repoWith([
            _item(carbs: 100, fat: 40, fiber: 15),
            _item(id: 'b', carbs: 20, fat: 5, fiber: 3),
          ]),
        ),
      ),
    );
    await tester.pump();
    // Against the default targets: 183 g carbs and 51 g fat.
    expect(find.text('120 of 183 g'), findsOneWidget);
    expect(find.text('45 of 51 g'), findsOneWidget);
    expect(find.text('Fibre 18 g'), findsOneWidget);
  });

  testWidgets('only the figures that are known, and in Arabic too', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(
        _eat(_repoWith([_item(carbs: 30), _item(id: 'b')])),
        locale: const Locale('ar'),
      ),
    );
    await tester.pump();
    expect(find.text('30 من 183 جم'), findsOneWidget);
    expect(find.byKey(const ValueKey('day-card-more-macros')), findsNothing);
  });

  testWidgets('a day of meals without them shows no line at all', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(_eat(_repoWith([_item()]))));
    await tester.pump();
    expect(find.byKey(const ValueKey('day-card-more-macros')), findsNothing);
  });

  testWidgets('a photographed plate is named in its slot by the name she '
      'approved', (tester) async {
    _phone(tester);
    final photo = MealItem(
      itemId: 'p',
      foodId: 'photo_dish_koshary',
      servings: 1,
      size: '',
      loggedAt: _lunchtime.subtract(const Duration(hours: 4)),
      source: MealSource.search,
      origin: MealOrigin.photo,
      kcal: 450,
      proteinG: 15,
      carbsG: 81,
      name: 'Koshary',
      grams: 300,
    );
    await tester.pumpWidget(_host(_eat(_repoWith([photo]))));
    await tester.pump();
    expect(find.text('Koshary'), findsOneWidget);
    // Breakfast is named, never "Later": that is dinner alone, lunch is now.
    expect(find.text(_en.later), findsOneWidget);
  });

  testWidgets('the camera is beside the box only when offered', (tester) async {
    _phone(tester);
    var snapped = 0;
    await tester.pumpWidget(
      _host(_eat(_repoWith([_item()]), onSnap: () => snapped++)),
    );
    await tester.pump();
    final camera = find.byKey(const ValueKey('eat-snap-meal'));
    expect(camera, findsOneWidget);
    expect(find.bySemanticsLabel(_en.snapYourMeal), findsOneWidget);
    await tester.ensureVisible(camera);
    await tester.pump();
    await tester.tap(camera);
    expect(snapped, 1);

    await tester.pumpWidget(_host(_eat(_repoWith([_item()]))));
    await tester.pump();
    expect(find.byKey(const ValueKey('eat-snap-meal')), findsNothing);
  });

  group('the bundled food pack', () {
    final raw = File('assets/content/foods_eg.json').readAsStringSync();
    final pack = jsonDecode(raw) as Map<String, dynamic>;
    final foods = [
      for (final food in pack['foods'] as List) food as Map<String, dynamic>,
    ];

    // Named foods that cannot meet a rule, each with its reason. Mirrors
    // ZERO_ENERGY_OK and ATWATER_EXCEPTIONS in tool/build_food_pack.py.
    const zeroEnergy = {'karkadeh_unsweetened', 'salt', 'water'};
    const atwaterExceptions = {
      'kharoub',
      'cocoa_powder',
      'strawberry_jam',
      'baking_powder',
      'spices_and_seasoning',
      'curry_powder',
      'zaatar_mix',
      'spice_blend_store',
    };

    bool atwaterOk(num p, num c, num f, num kcal) =>
        (4 * p + 4 * c + 9 * f - kcal).abs() <=
        (kcal * 0.15 > 20 ? kcal * 0.15 : 20);

    test('every food has both names and an id nobody else has', () {
      final ids = <String>{};
      for (final food in foods) {
        expect(ids.add(food['id'] as String), isTrue, reason: '${food['id']}');
        expect((food['nameEn'] as String).trim(), isNotEmpty);
        expect((food['nameAr'] as String).trim(), isNotEmpty);
      }
    });

    test('energy is above zero, macros are not negative, and they add up', () {
      for (final food in foods) {
        final id = food['id'] as String;
        final rows = <(String, num, num, num, num)>[];
        final per = food['per100g'] as Map<String, dynamic>;
        rows.add((
          'per 100 g',
          per['kcal'] as num,
          per['proteinG'] as num,
          per['carbsG'] as num,
          per['fatG'] as num,
        ));
        for (final entry in (food['sizes'] as Map<String, dynamic>).entries) {
          final size = entry.value as Map<String, dynamic>;
          rows.add((
            'size ${entry.key}',
            size['kcal'] as num,
            size['proteinG'] as num,
            size['carbsG'] as num,
            size['fatG'] as num,
          ));
        }
        for (final (where, kcal, p, c, f) in rows) {
          final reason = '$id $where';
          if (!zeroEnergy.contains(id)) {
            expect(kcal, greaterThan(0), reason: reason);
          }
          expect(p, greaterThanOrEqualTo(0), reason: reason);
          expect(c, greaterThanOrEqualTo(0), reason: reason);
          expect(f, greaterThanOrEqualTo(0), reason: reason);
          if (!atwaterExceptions.contains(id)) {
            expect(atwaterOk(p, c, f, kcal), isTrue, reason: reason);
          }
        }
      }
    });

    test('every food has a household size with grams, both labels and a basis', () {
      final review = pack['householdReview'] as Map<String, dynamic>;
      final notes = (review['notes'] as Map).cast<String, String>();
      // The dishes' sizes are covered by the review text itself; a single food
      // names the source of any unit weight that is not a USDA one.
      final singles = {
        for (final row
            in (jsonDecode(
                  File('tool/food_pack_singles.json').readAsStringSync(),
                ) as Map)['foods']
                as List)
          (row as Map)['id'] as String,
      };
      expect(review['basis'], isA<String>());
      for (final food in foods) {
        final id = food['id'] as String;
        final named = [
          for (final size in (food['sizes'] as Map<String, dynamic>).values)
            if ((size as Map<String, dynamic>).containsKey('label')) size,
        ];
        expect(named, isNotEmpty, reason: '$id has only S, M and L');
        for (final size in named) {
          final label = size['label'] as Map<String, dynamic>;
          expect((label['en'] as String).trim(), isNotEmpty, reason: id);
          expect((label['ar'] as String).trim(), isNotEmpty, reason: id);
          expect(
            RegExp('[\u0660-\u0669\u06F0-\u06F9\u2014]')
                .hasMatch('${label['en']}${label['ar']}'),
            isFalse,
            reason: '$id: an Arabic-Indic digit or an em dash in a label',
          );
          expect(size['grams'] as num, greaterThan(0), reason: id);
          expect(size['basis'], anyOf('usda', 'estimated'), reason: id);
        }
        // A single food with an estimated size says where the unit weight is from.
        if (singles.contains(id) &&
            named.any((s) => s['basis'] == 'estimated')) {
          expect(notes, contains(id), reason: '$id has no source note');
        }
      }
    });

    test('every food names a category and an allergen list from the app', () {
      final categories = {for (final c in FoodCategory.values) c.name};
      final tokens = {for (final t in AllergenTag.values) t.wireName};
      for (final food in foods) {
        final id = food['id'] as String;
        expect(categories, contains(food['category']), reason: id);
        final allergens = food['allergens'];
        expect(
          allergens,
          isA<List<dynamic>>(),
          reason: '$id has no allergens list',
        );
        for (final tag in allergens as List<dynamic>) {
          expect(tokens, contains(tag), reason: '$id: $tag');
        }
      }
      expect(
        {for (final food in foods) food['category']},
        categories,
        reason: 'every shelf holds at least one food',
      );
    });

    test('no spelling of a name belongs to two foods', () {
      final owner = <String, String>{};
      for (final food in foods) {
        final id = food['id'] as String;
        for (final name in {
          food['nameEn'] as String,
          food['nameAr'] as String,
          ...(food['aliases'] as List).cast<String>(),
        }) {
          final key = FoodLibrary.normalise(name);
          expect(owner.putIfAbsent(key, () => id), id, reason: '"$name"');
        }
      }
    });

    test('foods load into the app with allergens known and a shelf', () {
      EgyptianFoodPack.adopt(raw);
      addTearDown(EgyptianFoodPack.reset);
      final loaded = EgyptianFoodPack.foods(_en);
      expect(loaded, isNotEmpty);
      for (final food in loaded) {
        expect(food.allergens, isNotNull, reason: food.foodId);
        expect(food.category, isNotNull, reason: food.foodId);
        expect(food.defaultSize.id, 'M', reason: food.foodId);
        expect(food.allergensUnknown, isFalse, reason: food.foodId);
      }
    });

    test('every food has a picture prompt for the image build', () {
      final prompts = jsonDecode(
        File('tool/meal_image_prompts.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final food in foods) {
        expect(prompts, contains(food['id']));
      }
    });
  });
}
