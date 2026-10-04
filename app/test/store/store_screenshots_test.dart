// The store screenshot set, rendered from the real app.
//
// Six screens in English and six in Arabic, at 1080x2400 (a 20:9 Android
// phone at 2.625x): welcome, Home with a week in progress, a workout mid-set,
// Eat, a recipe from Rahma's book, and progress.
//
// It runs the real `OwnHubApp` with the real fonts, the owner's art and the
// shipped feature flags, with ONE change for this harness only:
// `accountRequired` is off, so the product screens open without a verified
// account. Nothing in lib/ is changed by it. Every piece of data on screen is
// put there the way a woman would put it there, by tapping, and none of it is
// a real person's: no name, no phone number. Community and coaching are off,
// as they are in the shipped flags.
//
// In the normal suite it renders all twelve and fails on any exception or
// overflow, writing nothing. To write the PNGs, give it a folder:
//
//   cd app
//   OWNHUB_SCREENSHOTS_DIR=../docs/release/launch-pack/screenshots \
//     flutter test test/store/store_screenshots_test.dart
//
// which writes {en,ar}/01-welcome.png and so on. The PNGs are not committed.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../qa/round1/font_harness.dart';

/// 1080x2400 physical pixels.
const Size _physical = Size(1080, 2400);
const double _dpr = 2.625;

final String? _outDir = Platform.environment['OWNHUB_SCREENSHOTS_DIR'];

Future<void> _loadIconFont() async {
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final file = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!file.existsSync()) {
    throw StateError('MaterialIcons font not found at ${file.path}');
  }
  final loader = FontLoader('MaterialIcons')
    ..addFont(
      Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
    );
  await loader.load();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// Lets the owner's art decode, then draws it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle();
  for (var pass = 0; pass < 2; pass++) {
    final images = find.byType(Image).evaluate().toList();
    await tester.runAsync(() async {
      for (final element in images) {
        final widget = element.widget as Image;
        await precacheImage(widget.image, element);
      }
    });
    await tester.pumpAndSettle();
  }
}

Future<void> _open(WidgetTester tester, String id) async {
  _nav(tester).pushNamed(appRoutes[id]!.name);
  await _settle(tester);
}

Future<void> _home(WidgetTester tester) async {
  _nav(tester).popUntil((route) => route.isFirst);
  await _settle(tester);
}

Future<void> _shoot(WidgetTester tester, String lang, String name) async {
  expect(tester.takeException(), isNull, reason: '$lang/$name threw');
  final dir = _outDir;
  if (dir == null) return;
  final element = find.byType(MaterialApp).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    expect(image.width, _physical.width.toInt());
    expect(image.height, _physical.height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$dir/$lang/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

AppL10n _l10n(WidgetTester tester) =>
    AppL10n.of(tester.element(find.byType(Navigator).first));

Future<void> _tapText(WidgetTester tester, String text) async {
  final hit = find.text(text).hitTestable();
  expect(hit, findsWidgets, reason: 'nothing on screen reads "$text"');
  await tester.tap(hit.first);
  await _settle(tester);
}

/// Shoots the screen in both languages from the same state, and leaves it in
/// English, the language the driving taps are written in.
Future<void> _shootBoth(WidgetTester tester, String name) async {
  final locale = LocaleScope.of(tester.element(find.byType(MaterialApp)));
  for (final lang in const ['en', 'ar']) {
    locale.value = Locale(lang);
    await _settle(tester);
    await _shoot(tester, lang, name);
  }
  locale.value = const Locale('en');
  await _settle(tester);
}

/// Reads Rahma's book off the asset bundle in real time, then hands the
/// finished book to Eat the way the app's own loader does.
Future<void> _loadRecipeBook(WidgetTester tester) async {
  final book = await tester.runAsync(
    () => EatAppState.instance.recipeSync.load(),
  );
  expect(book?.recipes, isNotEmpty);
  EatAppState.instance.ensureRecipeBook(library: _Loaded(book!));
  await tester.pump();
  expect(EatAppState.instance.recipeBook.recipes, isNotEmpty);
}

class _Loaded implements RecipeLibrary {
  _Loaded(this.book);
  final RecipeBook book;
  @override
  Future<RecipeBook> load() => SynchronousFuture(book);
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUpAll(() async {
    await loadAppFonts();
    await _loadIconFont();
  });

  testWidgets('store screenshots, English and Arabic', (tester) async {
    tester.view.physicalSize = _physical;
    tester.view.devicePixelRatio = _dpr;
    // A status bar's worth of inset at the top, as on a phone.
    tester.view.padding = const FakeViewPadding(top: 24 * _dpr);
    tester.view.viewPadding = const FakeViewPadding(top: 24 * _dpr);
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await const ThisPhoneWipe().clearPersistence();
    AppRouter.featureFlags = FeatureFlags.shipped.with_(const {
      // This harness only. The shipped flags keep it on.
      Feature.accountRequired: false,
    });
    addTearDown(() => AppRouter.featureFlags = savedFlags);
    addTearDown(() => const ThisPhoneWipe().clearPersistence());

    // Her four setup answers are behind her, and she has answered the
    // allergy question naming nothing, which is what opens Rahma's book.
    AppRouter.intakeRepository.markSetupDone();
    await AppRouter.dietaryRepository.save(
      allergies: <AllergenTag>{},
      dietary: <DietaryTag>{},
    );

    debugDisableShadows = false;
    try {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _settle(tester);
      await _loadRecipeBook(tester);
      final l10n = _l10n(tester);

      // 1. The front door.
      await _open(tester, 'C01');
      await _shootBoth(tester, '01-welcome');
      await _home(tester);

      // 3. A workout, started and one set in.
      await _open(tester, 'R03');
      await _tapText(tester, l10n.startEverythingsReady);
      await _shootBoth(tester, '03-workout');

      // ...and finished, so the week has a session in it.
      var guard = 0;
      while (!WorkoutSessionState.instance.isComplete && guard++ < 12) {
        final all = find.textContaining('log them').hitTestable();
        if (all.evaluate().isEmpty) break;
        await tester.tap(all.first);
        await _settle(tester);
        final next = find.textContaining('Next move').hitTestable();
        if (next.evaluate().isEmpty) break;
        await tester.tap(next.first);
        await _settle(tester);
      }
      final finish = find.text(l10n.finishHere).hitTestable();
      if (finish.evaluate().isNotEmpty) {
        await tester.tap(finish.first);
        await _settle(tester);
      }
      await _home(tester);

      // Two breakfasts logged by typing them, as she would.
      for (final food in const ['ful', 'boiled eggs']) {
        await _open(tester, 'E02');
        await tester.enterText(find.byType(TextField).first, food);
        await _settle(tester);
        await _tapText(tester, l10n.logIt);
        await tester.pump(const Duration(seconds: 6));
        await _settle(tester);
        await _home(tester);
      }

      // 2. Home, with the week under way.
      await _shootBoth(tester, '02-home');

      // 4. Eat: the recipes, scrolled to Rahma's book.
      await _open(tester, 'E05');
      final heading = find.text(l10n.rahmasRecipes);
      await tester.scrollUntilVisible(
        heading,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.runAsync(
        () => Scrollable.ensureVisible(tester.element(heading.first)),
      );
      await _settle(tester);
      await _shootBoth(tester, '04-eat');

      // 5. One of her recipes.
      EatAppState.instance.openRecipeId =
          EatAppState.instance.recipeBook.recipes.first.recipeId;
      await _open(tester, 'E06');
      await _shootBoth(tester, '05-recipe');
      await _home(tester);

      // 6. Progress, which is private to her phone.
      await _open(tester, 'P01');
      await _shootBoth(tester, '06-progress');
    } finally {
      debugDisableShadows = true;
    }
  });
}
