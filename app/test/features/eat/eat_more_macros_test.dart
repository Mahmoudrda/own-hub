// E01: carbs, fat and fibre on the day card once anything carries them, as a
// quiet line under protein; and the camera beside the box only when the
// router offers it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _lunchtime = DateTime(2026, 10, 17, 13, 12);
const String _day = '2026-10-17';
final AppL10n _en = AppL10nEn();
final AppL10n _ar = AppL10nAr();

MealItem _item({int? carbs, int? fat, int? fiber, String id = 'a'}) =>
    MealItem(
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

Widget _host(Widget child, {Locale locale = const Locale('en')}) =>
    MaterialApp(
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
    expect(
      find.text('Carbs 120 g · Fat 45 g · Fibre 18 g'),
      findsOneWidget,
    );
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
    final line = tester.widget<Text>(
      find.byKey(const ValueKey('day-card-more-macros')),
    );
    expect(line.data, _ar.carbsGramsG('30'));
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

  testWidgets('the camera is beside the box only when offered', (
    tester,
  ) async {
    _phone(tester);
    var snapped = 0;
    await tester.pumpWidget(
      _host(_eat(_repoWith([_item()]), onSnap: () => snapped++)),
    );
    await tester.pump();
    final camera = find.byKey(const ValueKey('eat-snap-meal'));
    expect(camera, findsOneWidget);
    expect(find.bySemanticsLabel(_en.snapYourMeal), findsOneWidget);
    await tester.tap(camera);
    expect(snapped, 1);

    await tester.pumpWidget(_host(_eat(_repoWith([_item()]))));
    await tester.pump();
    expect(find.byKey(const ValueKey('eat-snap-meal')), findsNothing);
  });
}
