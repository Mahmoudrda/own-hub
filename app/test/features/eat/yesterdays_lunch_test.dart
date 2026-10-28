// "Yesterday's lunch again": one row, from what she really logged for lunch the
// day before, offered only at lunch while lunch is empty, and never past her
// allergy guard. It was a parameter nothing ever passed.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_day_view_model.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';

final _koshari = Food(
  foodId: 'koshari_bowl',
  names: const ['Koshari bowl'],
  allergens: const <String>{},
  popularity: 90,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 470, proteinG: 21)],
);

final _tahini = Food(
  foodId: 'tahini_salad',
  names: const ['Tahini salad'],
  allergens: const <String>{'sesame'},
  popularity: 85,
  sizes: const [FoodSize(id: 'M', label: 'Medium', kcal: 220, proteinG: 6)],
);

final _library = FoodLibrary([_koshari, _tahini]);

MealItem _item(String foodId, {num servings = 1, String size = 'M'}) =>
    MealItem(
      itemId: '$foodId-$servings-$size',
      foodId: foodId,
      servings: servings,
      size: size,
      loggedAt: DateTime(2026, 9, 14, 13),
      source: MealSource.search,
      origin: MealOrigin.suggestion,
      kcal: 470,
      proteinG: 21,
    );

MealDay _yesterday(List<MealItem> lunch, {MealSlot slot = MealSlot.lunch}) =>
    MealDay(dayId: '2026-09-14', slots: {slot: lunch});

EatDayViewModel _model({DietaryConstraints? constraints}) => EatDayViewModel(
  library: _library,
  guard: AllergyGuard(constraints ?? DietaryConstraints.none),
);

final _lunchtime = DateTime(2026, 9, 15, 13, 12);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
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

EatView _eat(
  MealRepository repository, {
  LogCommandBus? bus,
  DietaryConstraints constraints = DietaryConstraints.none,
  DateTime? now,
  FoodLibrary? library,
}) => EatView(
  constraints: constraints,
  repository: repository,
  library: library,
  bus: bus,
  now: now ?? _lunchtime,
  onOpenRecipes: () {},
  onType: () {},
  onSpeak: () {},
  onSelectTab: (_) {},
);

InMemoryMealRepository _repoWith(MealDay? yesterday, {MealDay? today}) {
  final repository = InMemoryMealRepository();
  if (yesterday != null) repository.store.days[yesterday.dayId] = yesterday;
  if (today != null) repository.store.days[today.dayId] = today;
  return repository;
}

void main() {
  group('the row, from what she logged', () {
    test('is what she ate for lunch, as she ate it', () {
      final row = _model().yesterdaysLunch(
        _yesterday([_item('koshari_bowl', servings: 2)]),
      );
      expect(row, isNotNull);
      expect(row!.entries.single.food.foodId, 'koshari_bowl');
      expect(row.entries.single.servings, 2);
      expect(row.kcal, 940);
    });

    test('is nothing when she logged no lunch, or no day at all', () {
      expect(_model().yesterdaysLunch(null), isNull);
      expect(_model().yesterdaysLunch(const MealDay(dayId: 'x')), isNull);
      expect(
        _model().yesterdaysLunch(
          _yesterday([_item('koshari_bowl')], slot: MealSlot.dinner),
        ),
        isNull,
        reason: 'only lunch',
      );
    });

    test('is nothing when one food fails her allergy guard', () {
      final day = _yesterday([_item('koshari_bowl'), _item('tahini_salad')]);
      expect(_model().yesterdaysLunch(day), isNotNull);
      expect(
        _model(constraints: const DietaryConstraints(allergies: {'sesame'}))
            .yesterdaysLunch(day),
        isNull,
        reason: 'a meal minus a food is not the meal she ate',
      );
    });

    test('is nothing when a food has left the pack or its size is gone', () {
      expect(
        _model().yesterdaysLunch(_yesterday([_item('retired_dish')])),
        isNull,
      );
      expect(
        _model().yesterdaysLunch(
          _yesterday([_item('koshari_bowl', size: 'XL')]),
        ),
        isNull,
      );
    });

    test('is nothing for less than a whole serving', () {
      expect(
        _model().yesterdaysLunch(
          _yesterday([_item('koshari_bowl', servings: 1.5)]),
        ),
        isNull,
      );
    });
  });

  group('on Eat', () {
    testWidgets('lunch yesterday, lunch empty today: one tap logs it', (
      tester,
    ) async {
      _phone(tester);
      final repository = _repoWith(_yesterday([_item('molokhia_chicken')]));
      final bus = LogCommandBus();
      await tester.pumpWidget(_host(_eat(repository, bus: bus)));
      await tester.pumpAndSettle();

      expect(find.text("Yesterday's lunch again"), findsOneWidget);
      final ate = find.text('I ate this');
      await tester.ensureVisible(ate);
      await tester.pump();
      await tester.tap(ate);
      await tester.pump(const Duration(seconds: 6));

      final write = repository.writes.single;
      expect(write.added.single.foodId, 'molokhia_chicken');
      expect(write.slot, MealSlot.lunch);
      bus.dispose();
    });

    testWidgets('no lunch yesterday: no row', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(_eat(_repoWith(null))));
      await tester.pumpAndSettle();
      expect(find.text("Yesterday's lunch again"), findsNothing);
    });

    testWidgets('lunch already logged today: no row', (tester) async {
      _phone(tester);
      final repository = _repoWith(
        _yesterday([_item('molokhia_chicken')]),
        today: MealDay(
          dayId: '2026-09-15',
          slots: {
            MealSlot.lunch: [_item('molokhia_chicken')],
          },
        ),
      );
      await tester.pumpWidget(_host(_eat(repository)));
      await tester.pumpAndSettle();
      expect(find.text("Yesterday's lunch again"), findsNothing);
    });

    testWidgets('outside lunchtime: no row', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(
            _repoWith(_yesterday([_item('molokhia_chicken')])),
            now: DateTime(2026, 9, 15, 20),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Yesterday's lunch again"), findsNothing);
    });

    testWidgets('with an allergy to something in it: no row', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(
            _repoWith(_yesterday([_item('tahini_salad')])),
            library: _library,
            constraints: const DietaryConstraints(allergies: {'sesame'}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Yesterday's lunch again"), findsNothing);
    });

    testWidgets('the same meal with no allergy is offered', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(
            _repoWith(_yesterday([_item('tahini_salad')])),
            library: _library,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("Yesterday's lunch again"), findsOneWidget);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('stays inside the screen budget on a small phone, '
            '${locale.languageCode} at ${scale}x', (tester) async {
          tester.view.physicalSize = const Size(1125, 2001);
          tester.view.devicePixelRatio = 3.0;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            _host(
              _eat(_repoWith(_yesterday([_item('molokhia_chicken')]))),
              locale: locale,
              textScale: scale,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(
              locale.languageCode == 'en'
                  ? "Yesterday's lunch again"
                  : 'غدا امبارح تاني',
            ),
            findsOneWidget,
          );
          expect(
            countControlsAboveFold(tester, includeChrome: false),
            lessThanOrEqualTo(5),
          );
          expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('reads in Arabic too', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(_repoWith(_yesterday([_item('molokhia_chicken')]))),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('غدا امبارح تاني'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
