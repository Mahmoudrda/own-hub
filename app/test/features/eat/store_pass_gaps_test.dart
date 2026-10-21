// Store-pass gaps on the eat screens: the real photo wait shows the adding
// card, the camera button sits under the search field, "No oven" reads the
// authored tag, and diary rows and quick-add cards carry a food thumbnail.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/meal_scan_state.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_images.dart';
import 'package:own_hub/features/eat/domain/meal_scan.dart';
import 'package:own_hub/features/eat/presentation/eat_day_view_model.dart';
import 'package:own_hub/features/eat/presentation/eat_widgets.dart';
import 'package:own_hub/features/eat/presentation/meal_photo_view.dart';
import 'package:own_hub/features/eat/presentation/meal_result_card.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/features/eat/presentation/type_it_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_field.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'meal_photo_view_test.dart' show FakeCamera, FakeScanClient;

Widget _host(Widget child) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

class _SlowClient extends FakeScanClient {
  final Completer<MealScanResult> gate = Completer<MealScanResult>();

  @override
  Future<MealScanResult> analyse(Uint8List jpeg, {required String locale}) {
    scans++;
    return gate.future;
  }
}

RecipeBook _shipped() => RecipeBook.fromJson(
  (jsonDecode(
    File('assets/content/rahma_recipes.json').readAsStringSync(),
  ) as Map).cast<String, Object?>(),
);

void main() {
  tearDown(MealImages.clear);

  testWidgets('the real photo wait shows the adding card, then it ends', (
    tester,
  ) async {
    _phone(tester);
    SharedPreferences.setMockInitialValues({kMealPhotoConsentKey: 'uid-1'});
    final client = _SlowClient();
    final state = MealScanState.instance;
    state.resetForTest(client: client, camera: FakeCamera());
    addTearDown(state.resetForTest);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: MealPhotoView(
          state: state,
          uid: 'uid-1',
          onScanned: () {},
          onTypeInstead: () {},
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.byKey(const ValueKey('meal-scan-shutter')));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('meal-result-adding')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('meal-scan-analyse')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(client.scans, 1);
    expect(find.byType(MealResultCard), findsOneWidget);
    expect(find.byKey(const ValueKey('meal-result-adding')), findsOneWidget);

    client.gate.complete(
      const MealScanResult(
        items: [
          ScannedItem(
            nameEn: 'Boiled egg',
            nameAr: 'بيض مسلوق',
            grams: 100,
            matched: true,
            per100g: Macros(kcal: 155, proteinG: 12.6),
          ),
        ],
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byKey(const ValueKey('meal-result-adding')), findsNothing);
  });

  testWidgets('E02: the camera button is under the field, above the chips', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: TypeItView(
          constraints: DietaryConstraints.none,
          now: DateTime(2026, 9, 15, 13, 12),
          onClose: () {},
          onSpeak: () {},
          onSnap: () {},
        ),
      ),
    );
    await tester.pump();
    final field = tester.getTopLeft(find.byType(AppField)).dy;
    final snap = tester
        .getTopLeft(find.byKey(const ValueKey('type-it-snap-meal')))
        .dy;
    final chips = tester
        .getTopLeft(find.byKey(const ValueKey('type-it-categories')))
        .dy;
    expect(field, lessThan(snap));
    expect(snap, lessThan(chips));
  });

  test(
    'No oven reads the authored tag and drops oven and air-fryer dishes',
    () {
      final byId = {for (final r in _shipped().recipes) r.recipeId: r};
      for (final id in [
        'rahma_fool_wa_ta3mya',
        'rahma_hwawshi',
        'rahma_chicken_ranch_salad',
        'rahma_makrona_bashmel',
        'rahma_oven_tender_chicken',
      ]) {
        expect(
          recipeMatchesFilter(byId[id]!, RecipeFilter.noOven),
          isFalse,
          reason: id,
        );
      }
      for (final r in byId.values) {
        expect(
          recipeMatchesFilter(r, RecipeFilter.noOven),
          r.dietTags.contains('no_oven'),
          reason: r.recipeId,
        );
      }
      expect(
        recipeMatchesFilter(byId['rahma_potato_w_eggs']!, RecipeFilter.noOven),
        isTrue,
      );
    },
  );

  group('food thumbnails', () {
    setUp(
      () => MealImages.adopt(
        jsonEncode([
          {'id': 'koshari'},
        ]),
      ),
    );

    Widget card(String? asset) => _host(
      QuickAddCard(
        title: 'T',
        meta: 'M',
        addLabel: 'Add T',
        imageAsset: asset,
        onAdd: () {},
      ),
    );

    testWidgets('quick-add: installed id shows an Image', (tester) async {
      await tester.pumpWidget(card(MealImages.assetFor('koshari')));
      expect(find.byType(FoodThumb), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('quick-add: uninstalled id shows the drawn mark', (
      tester,
    ) async {
      await tester.pumpWidget(card(MealImages.assetFor('nope')));
      expect(find.byType(Image), findsNothing);
      expect(find.byType(FoodMark), findsOneWidget);
    });

    testWidgets('diary row: thumbnails for logged items, none when empty', (
      tester,
    ) async {
      Widget row(List<String?> assets) => _host(
        MealDiaryRow(
          name: 'Lunch',
          value: 'x',
          status: SlotStatus.done,
          logLabel: 'Log',
          logSemanticsLabel: 'Log Lunch',
          itemImageAssets: assets,
        ),
      );
      await tester.pumpWidget(
        row([MealImages.assetFor('koshari'), MealImages.assetFor('nope')]),
      );
      expect(find.byType(FoodThumb), findsNWidgets(2));
      expect(find.byType(Image), findsOneWidget);
      expect(find.byType(FoodMark), findsOneWidget);
      await tester.pumpWidget(row(const []));
      expect(find.byType(FoodThumb), findsNothing);
    });
  });
}
