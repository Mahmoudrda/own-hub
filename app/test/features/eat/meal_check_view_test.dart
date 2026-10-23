// E13: Check your meal. Nothing is logged before "Log this meal"; a changed
// weight moves every figure on the card and the total; an item with no
// numbers holds the log back until it is filled or removed; and the log goes
// through the Eat tab's one undo bus with carbs, fat and fibre on it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/meal_scan_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/features/eat/presentation/meal_check_view.dart';
import 'package:own_hub/features/eat/presentation/meal_log_session.dart';
import 'package:own_hub/features/eat/presentation/meal_photo_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

final AppL10n _en = AppL10nEn();
final AppL10n _ar = AppL10nAr();
final DateTime _lunchtime = DateTime(2026, 10, 17, 13, 12);

const MealScanResult _scan = MealScanResult(
  items: [
    ScannedItem(
      nameEn: 'Koshari',
      nameAr: 'كشري',
      grams: 400,
      matched: true,
      source: MealScanSource.dish,
      dishKey: 'koshary',
      dishNameEn: 'Koshary',
      dishNameAr: 'كشري',
      review: 'estimated from a standard recipe, pending dietitian review',
      per100g: Macros(kcal: 150, proteinG: 5, carbsG: 27, fatG: 2.5, fiberG: 3),
      ingredients: [
        ScannedIngredient(nameEn: 'rice, cooked', grams: 100, matched: true),
      ],
    ),
    ScannedItem(
      nameEn: 'Mystery sauce',
      nameAr: 'صوص',
      grams: 30,
      matched: false,
    ),
  ],
);

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

/// A route push needs more than one frame: the new route is laid out
/// offstage first.
Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  late InMemoryMealRepository repository;
  late MealLogSession session;

  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    repository = InMemoryMealRepository();
    session = MealLogSession(repository: repository);
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    session.reset();
  });

  Future<List<LogHandle>> pumpCheck(
    WidgetTester tester, {
    MealScanResult? result = _scan,
    Locale locale = const Locale('en'),
    double textScale = 1,
    VoidCallback? onCancel,
  }) async {
    final logged = <LogHandle>[];
    await tester.pumpWidget(
      _host(
        MealCheckView(
          result: result,
          constraints: DietaryConstraints.none,
          repository: repository,
          session: session,
          now: _lunchtime,
          onLogged: logged.add,
          onCancel: onCancel ?? () {},
        ),
        locale: locale,
        textScale: textScale,
      ),
    );
    await tester.pump();
    return logged;
  }

  Finder figures(String key) => find.byKey(ValueKey('meal-check-figures-$key'));

  String figuresText(WidgetTester tester, String key) => tester
      .widgetList<Text>(
        find.descendant(of: figures(key), matching: find.byType(Text)),
      )
      .map((t) => t.data)
      .join(' | ');

  testWidgets('every card, the estimate line once, and nothing logged yet', (
    tester,
  ) async {
    _phone(tester);
    await pumpCheck(tester);
    expect(find.text('Koshary'), findsOneWidget);
    expect(find.text(_en.estimatedFromAStandardRecipe), findsOneWidget);
    expect(find.text(_en.theseAreEstimatesCheckTheGrams), findsOneWidget);
    expect(figuresText(tester, 'scan-0'), contains('600 kcal'));
    expect(figuresText(tester, 'scan-0'), contains('Carbs 108 g'));
    expect(figuresText(tester, 'scan-0'), contains('Fibre 12 g'));
    expect(
      find.byKey(const ValueKey('meal-check-unmatched-scan-1')),
      findsOneWidget,
    );
    expect(find.text(_en.weCouldntFindTheNutritionForThis), findsOneWidget);
    // The log is held back while the sauce has no numbers.
    final log = tester.widget<AppButton>(
      find.byKey(const ValueKey('meal-check-log')),
    );
    expect(log.onPressed, isNull);
    expect(find.text(_en.enterTheNumbersForEachItemOr), findsOneWidget);
    expect(repository.writes, isEmpty);
    expect(session.pending, isEmpty);
  });

  testWidgets('a changed weight moves the card and the total, live', (
    tester,
  ) async {
    _phone(tester);
    await pumpCheck(tester);
    await _tap(tester, find.byKey(const ValueKey('meal-check-more-scan-0')));
    expect(figuresText(tester, 'scan-0'), contains('615 kcal'));
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-grams-scan-0')),
      '200',
    );
    await tester.pump();
    expect(figuresText(tester, 'scan-0'), contains('300 kcal'));
    expect(figuresText(tester, 'scan-0'), contains('Protein 10 g'));
    final totals = find.byKey(const ValueKey('meal-check-totals'));
    expect(
      find.descendant(of: totals, matching: find.textContaining('300 kcal')),
      findsOneWidget,
    );
    expect(repository.writes, isEmpty);
  });

  testWidgets('a figure she types is marked as hers', (tester) async {
    _phone(tester);
    await pumpCheck(tester);
    await _tap(tester, find.byKey(const ValueKey('meal-check-edit-scan-0')));
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-figure-scan-0-kcal')),
      '550',
    );
    await tester.pump();
    expect(figuresText(tester, 'scan-0'), contains('550 kcal'));
    expect(find.text(_en.editedByYou), findsOneWidget);
  });

  testWidgets('nothing is logged until "Log this meal", and then through the '
      'undo bus with carbs, fat and fibre', (tester) async {
    _phone(tester);
    final logged = await pumpCheck(tester);
    // Take the sauce off; the plate can now be logged.
    await _tap(tester, find.byKey(const ValueKey('meal-check-remove-scan-1')));
    expect(find.text('Mystery sauce'), findsNothing);
    expect(repository.writes, isEmpty);
    expect(session.pending, isEmpty);

    // Dinner rather than the lunch the hour suggests.
    await _tap(tester, find.text(_en.dinner).last);
    await _tap(tester, find.byKey(const ValueKey('meal-check-log')));

    expect(logged, hasLength(1));
    expect(session.pending, hasLength(1));
    expect(session.pending.single.slot, MealSlot.dinner);
    final item = session.pending.single.items.single;
    expect(item.origin, MealOrigin.photo);
    expect(item.name, 'Koshary');
    expect(item.grams, 400);
    expect(item.kcal, 600);
    expect(item.carbsG, 108);
    expect(item.fatG, 10);
    expect(item.fiberG, 12);
    expect(repository.writes, isEmpty, reason: 'still inside its five seconds');

    // A second tap cannot log it twice.
    await _tap(tester, find.byKey(const ValueKey('meal-check-log')));
    expect(session.pending, hasLength(1));

    session.flushNow();
    await tester.pump();
    expect(repository.writes, hasLength(1));
  });

  testWidgets('cancel leaves without writing anything', (tester) async {
    _phone(tester);
    var cancelled = 0;
    await pumpCheck(tester, onCancel: () => cancelled++);
    await _tap(tester, find.byKey(const ValueKey('meal-check-cancel')));
    expect(cancelled, 1);
    expect(repository.writes, isEmpty);
    expect(session.pending, isEmpty);
  });

  testWidgets('she can add a food from the list, or type one in', (
    tester,
  ) async {
    _phone(tester);
    await pumpCheck(tester);
    await _tap(tester, find.byKey(const ValueKey('meal-check-add')));
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-search')),
      'eggs',
    );
    await tester.pump();
    await _tap(
      tester,
      find.byKey(const ValueKey('meal-check-found-boiled_eggs')),
    );
    expect(find.byKey(const ValueKey('meal-check-item-add-0')), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('meal-check-add')));
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-own-name')),
      'Pickles',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-own-grams')),
      '40',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-own-kcal')),
      '١٠',
    );
    await tester.enterText(
      find.byKey(const ValueKey('meal-check-own-protein')),
      '0',
    );
    await tester.pump();
    await _tap(tester, find.byKey(const ValueKey('meal-check-own-add')));
    expect(find.text('Pickles'), findsOneWidget);
    expect(find.text(_en.addedByYou), findsOneWidget);
    expect(figuresText(tester, 'add-1'), contains('10 kcal'));
  });

  testWidgets('opened with nothing to check, it says so', (tester) async {
    _phone(tester);
    await pumpCheck(tester, result: null);
    expect(find.text(_en.nothingToCheckYetSnapYourMeal), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-check-log')), findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('large text and ${locale.languageCode}', (tester) async {
      _phone(tester);
      await pumpCheck(tester, locale: locale, textScale: 2);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(const ValueKey('meal-check-edit-scan-0')));
      await _tap(tester, find.byKey(const ValueKey('meal-check-parts-scan-0')));
      await _tap(tester, find.byKey(const ValueKey('meal-check-add')));
      expect(tester.takeException(), isNull);
      if (locale.languageCode == 'ar') {
        expect(find.text('كشري'), findsOneWidget);
        expect(find.text(_ar.theseAreEstimatesCheckTheGrams), findsOneWidget);
        expect(
          Directionality.of(tester.element(find.text('كشري'))),
          TextDirection.rtl,
        );
      }
    });
  }

  group('in the app', () {
    final savedFlags = AppRouter.featureFlags;
    setUp(() {
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        for (final f in Feature.values) f: f != Feature.accountRequired,
      });
    });
    tearDown(() {
      AppRouter.featureFlags = savedFlags;
      MealScanState.instance.resetForTest();
      EatAppState.instance.reset();
      AppRouter.mealRepository.store.reset();
    });

    testWidgets('logging closes the check and the camera before E04 opens', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _frames(tester);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pushNamed(appRoutes['E01']!.name);
      await _frames(tester);
      navigator.pushNamed(appRoutes['E12']!.name);
      await _frames(tester);
      expect(find.byType(MealPhotoView), findsOneWidget);
      MealScanState.instance.result = const MealScanResult(
        items: [
          ScannedItem(
            nameEn: 'Boiled egg',
            nameAr: 'بيض مسلوق',
            grams: 100,
            matched: true,
            per100g: Macros(kcal: 155, proteinG: 12.6, carbsG: 1.1),
          ),
        ],
      );
      navigator.pushNamed(appRoutes['E13']!.name);
      await _frames(tester);
      expect(find.byType(MealCheckView), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('meal-check-log')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('meal-check-log')));
      await _frames(tester);

      expect(find.byType(MealCheckView, skipOffstage: false), findsNothing);
      expect(find.byType(MealPhotoView, skipOffstage: false), findsNothing);
      expect(MealScanState.instance.result, isNull);
      final eat = tester.widgetList<EatView>(
        find.byType(EatView, skipOffstage: false),
      );
      expect(eat.where((v) => v.justLogged != null), hasLength(1));

      // Back from E04 is Eat, never the check she already logged.
      navigator.pop();
      await _frames(tester);
      expect(find.byType(MealCheckView, skipOffstage: false), findsNothing);
      await tester.pump(const Duration(seconds: 6));
    });
  });
}
