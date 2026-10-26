// Design pass on Eat: the result card, time-of-day picks, "Impact on
// today" rings, and the per-meal diary rows with their Log pill.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/daily_targets.dart';
import 'package:own_hub/features/eat/domain/food_library.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/slot_picks.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart';
import 'package:own_hub/features/eat/presentation/food_portion_sheet.dart';
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/features/eat/presentation/meal_result_card.dart';
import 'package:own_hub/features/eat/presentation/type_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/features/eat/domain/meal_sentence_parser.dart';
import 'package:own_hub/ui/app_ring_stat.dart';

final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

EatPrefs _prefs() => EatPrefs(
  plates: {
    'lunch': Plate(
      plateId: 'lunch',
      items: [PlateItem(foodId: 'chicken_and_rice', size: 'M')],
      dayCounts: const {'2026-09-14': 1},
      slotCounts: const {MealSlot.lunch: 1},
      lastAt: DateTime(2026, 9, 14, 13),
    ),
    'breakfast': Plate(
      plateId: 'breakfast',
      items: [PlateItem(foodId: 'ful_baladi', size: 'M')],
      dayCounts: const {'2026-09-14': 1},
      slotCounts: const {MealSlot.breakfast: 1},
      lastAt: DateTime(2026, 9, 14, 8),
    ),
  },
);

const DailyTargets _ownTargets = DailyTargets(
  kcal: 1800,
  proteinG: 100,
  carbsG: 200,
  fatG: 60,
  fiberG: 25,
  usesDefaults: false,
);

Widget _eat({
  MealRepository? repository,
  MealLogSession? session,
  VoidCallback? onType,
  ValueChanged<LogHandle>? onLogged,
}) => _host(
  EatView(
    constraints: DietaryConstraints.none,
    repository: repository,
    session: session,
    now: _lunchtime,
    onLogged: onLogged,
    onOpenRecipes: () {},
    onType: onType ?? () {},
    onSpeak: () {},
    onSelectTab: (_) {},
  ),
);

List<ParsedItem> _items(BuildContext context, List<String> ids) {
  final library = eatSampleLibrary(AppL10n.of(context));
  return [for (final id in ids) entryFor(library, id)!];
}

void main() {
  group('meal result card', () {
    testWidgets('shimmers while adding, then fills with Yes and Edit', (
      tester,
    ) async {
      _phone(tester);
      var yes = 0;
      var edit = 0;
      late List<ParsedItem> items;
      final adding = ValueNotifier(true);
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Builder(
              builder: (context) {
                items = _items(context, ['koshari_bowl']);
                return ValueListenableBuilder<bool>(
                  valueListenable: adding,
                  builder: (_, isAdding, _) => MealResultCard(
                    adding: isAdding,
                    items: items,
                    onYes: () => yes++,
                    onEdit: () => edit++,
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Adding up your meal'), findsWidgets);
      expect(find.text('Does this look right?'), findsNothing);

      adding.value = false;
      await tester.pumpAndSettle();

      expect(find.text('Adding up your meal'), findsNothing);
      expect(find.text('Does this look right?'), findsOneWidget);
      expect(find.byKey(const ValueKey('meal-result-dots')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.tap(find.byKey(const ValueKey('meal-result-edit')));
      expect(yes, 1);
      expect(edit, 1);
    });

    testWidgets('does not animate under reduced motion', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _host(const Scaffold(body: MealResultCard(adding: true))),
        ),
      );
      await tester.pump();
      // The shimmer controller never started: no ticker is scheduled.
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
      expect(find.text('Adding up your meal'), findsWidgets);
    });

    testWidgets('does animate when motion is allowed', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(const Scaffold(body: MealResultCard(adding: true))),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpAndSettle();
    });

    testWidgets('E02 shows the card for a sentence and Yes logs it', (
      tester,
    ) async {
      _phone(tester);
      final bus = LogCommandBus();
      var logged = 0;
      await tester.pumpWidget(
        _host(
          TypeItView(
            constraints: DietaryConstraints.none,
            repository: InMemoryMealRepository(),
            bus: bus,
            now: _lunchtime,
            initialText: 'koshari and 2 eggs',
            onLogged: (_) => logged++,
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Does this look right?'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('meal-result-yes')));
      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.pump();
      expect(logged, 1);
      await bus.flushAll();
    });
  });

  group('time-of-day picks', () {
    testWidgets('E01 lists only the foods she had at this meal and + logs', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository(prefs: _prefs());
      await tester.pumpWidget(_eat(repository: repository));
      await tester.pumpAndSettle();

      expect(find.text('Your lunch picks'), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-chicken_and_rice')), findsOne);
      expect(find.byKey(const ValueKey('pick-ful_baladi')), findsNothing);

      final plus = find.descendant(
        of: find.byKey(const ValueKey('pick-chicken_and_rice')),
        matching: find.byType(PlusButton),
      );
      await tester.ensureVisible(plus);
      await tester.tap(plus);
      await tester.pump();
      expect(find.text('Undo'), findsOneWidget);
      expect(repository.writes, isEmpty);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('hidden when she has nothing for this meal', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _eat(repository: InMemoryMealRepository(prefs: const EatPrefs())),
      );
      await tester.pumpAndSettle();
      expect(find.text('Your lunch picks'), findsNothing);
      expect(find.byKey(const ValueKey('slot-picks')), findsNothing);
    });

    testWidgets('E02 shows the same row, in Arabic when she reads Arabic', (
      tester,
    ) async {
      _phone(tester);
      final bus = LogCommandBus();
      await tester.pumpWidget(
        _host(
          TypeItView(
            constraints: DietaryConstraints.none,
            repository: InMemoryMealRepository(prefs: _prefs()),
            bus: bus,
            now: _lunchtime,
            onClose: () {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      // Her picks are rows of the list now, so a row and its "+" stay one
      // control; there is no heading of their own.
      Finder pick(String id) => find.byWidgetPredicate(
        (w) => w.key.toString().contains("'pick-$id-"),
      );
      expect(pick('ful_baladi'), findsNothing);
      expect(pick('chicken_and_rice'), findsOne);
      await bus.flushAll();
    });
  });

  group('allergy guard on picks', () {
    test('a food holding an allergen she named never appears', () {
      const sizes = [
        FoodSize(id: 'M', label: 'Medium', kcal: 300, proteinG: 10),
      ];
      const library = FoodLibrary([
        Food(
          foodId: 'nutty',
          names: ['Nutty'],
          sizes: sizes,
          allergens: {'Peanut'},
        ),
        Food(
          foodId: 'plain',
          names: ['Plain'],
          sizes: sizes,
          allergens: <String>{},
        ),
      ]);
      final prefs = EatPrefs(
        plates: {
          for (final id in ['nutty', 'plain'])
            id: Plate(
              plateId: id,
              items: [PlateItem(foodId: id, size: 'M')],
              dayCounts: const {'2026-09-14': 1},
              slotCounts: const {MealSlot.lunch: 1},
              lastAt: DateTime(2026, 9, 14, 13),
            ),
        },
      );
      final picks = slotPicks(
        prefs: prefs,
        library: library,
        guard: const AllergyGuard(
          DietaryConstraints(allergies: {'peanut'}, dietary: <String>{}),
        ),
        slot: MealSlot.lunch,
      );
      expect([for (final p in picks) p.food.foodId], ['plain']);
    });
  });

  group('Impact on today rings', () {
    Future<void> pumpPanel(WidgetTester tester, DailyTargets? targets) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          Scaffold(
            body: Builder(
              builder: (context) => SingleChildScrollView(
                child: FoodPortionPanel(
                  food: eatSampleLibrary(AppL10n.of(context))
                      .byId('koshari_bowl')!,
                  targets: targets,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('follow the amount', (tester) async {
      final targets = _ownTargets;
      await pumpPanel(tester, targets);
      expect(find.text('Impact on today'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('portion-impact-protein')),
        findsOneWidget,
      );

      String percentOf(String key) {
        final ring = tester.widget<AppRingStat>(find.byKey(ValueKey(key)));
        return ring.big;
      }

      late final int kcal;
      tester.element(find.byType(FoodPortionPanel));
      final food = eatSampleLibrary(
        AppL10n.of(tester.element(find.byType(FoodPortionPanel))),
      ).byId('koshari_bowl')!;
      kcal = food.defaultSize.kcal;
      final exact = (kcal * 100 / targets.kcal).round();
      expect(percentOf('portion-impact-kcal'), '$exact%');

      final before = percentOf('portion-impact-kcal');
      await tester.tap(find.byKey(const ValueKey('portion-more')));
      await tester.pumpAndSettle();
      expect(percentOf('portion-impact-kcal'), isNot(before));
    });

    testWidgets('hidden when the targets are the typical-day defaults', (
      tester,
    ) async {
      await pumpPanel(tester, DailyTargets.compute());
      expect(DailyTargets.compute().usesDefaults, isTrue);
      expect(find.text('Impact on today'), findsNothing);
      expect(find.byKey(const ValueKey('portion-impact')), findsNothing);
    });

    testWidgets('hidden without targets', (tester) async {
      await pumpPanel(tester, null);
      expect(find.text('Impact on today'), findsNothing);
      expect(find.byKey(const ValueKey('portion-impact')), findsNothing);
    });
  });

  group('diary rows', () {
    testWidgets('four meals, each with a + that presets the meal', (
      tester,
    ) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final session = MealLogSession(repository: repository);
      var opened = 0;
      await tester.pumpWidget(
        _eat(repository: repository, session: session, onType: () => opened++),
      );
      await tester.pumpAndSettle();

      for (final meal in const ['breakfast', 'lunch', 'dinner', 'snack']) {
        expect(find.byKey(ValueKey('eat-diary-$meal')), findsOneWidget);
      }
      expect(find.text('Snacks'), findsOneWidget);
      for (final meal in const ['breakfast', 'lunch', 'dinner', 'snack']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('eat-diary-$meal')),
            matching: find.byType(PlusButton),
          ),
          findsOneWidget,
          reason: meal,
        );
      }
      expect(find.byTooltip('Log Dinner'), findsOneWidget);

      final pill = find.descendant(
        of: find.byKey(const ValueKey('eat-diary-dinner')),
        matching: find.byType(PlusButton),
      );
      await tester.ensureVisible(pill);
      expect(tester.getSize(pill).height, greaterThanOrEqualTo(48));
      await tester.tap(pill);
      await tester.pump();
      expect(opened, 1);
      expect(session.takeLogSlot(), MealSlot.dinner);
      session.dispose();
    });

    testWidgets('E02 logs into the meal the pill named', (tester) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final session = MealLogSession(repository: repository)
        ..presetLogSlot(MealSlot.dinner);
      await tester.pumpWidget(
        _host(
          TypeItView(
            constraints: DietaryConstraints.none,
            repository: repository,
            session: session,
            now: _lunchtime,
            initialText: 'koshari and 2 eggs',
            onClose: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('meal-result-yes')));
      await tester.tap(find.byKey(const ValueKey('meal-result-yes')));
      await tester.pump();

      expect(session.pending.single.slot, MealSlot.dinner);
      expect(session.takeLogSlot(), isNull);
      await session.bus.flushAll();
      await tester.pump(const Duration(seconds: 6));
      session.dispose();
    });
  });
}
