// The store screenshot sets, rendered from the real app.
//
// Eight screens in English and eight in Arabic, in three sizes:
//
//   play       1080x1920 (9:16, inside Play's 2:1 rule, promotion-eligible)
//   apple-6.3  1206x2622 (the 6.3" Dynamic Island size Apple now requires)
//   apple-6.9  1320x2868 (the 6.9" size)
//
// Welcome, Home with a week in progress, a workout mid-set, Eat, a recipe from
// Rahma's book, her progress card, and two stops of the pre-signup tour (a week of
// dinners, and My cycle). Every PNG is opaque RGB with no alpha channel, as
// App Store Connect requires; the encoder is below, so no tool is needed.
//
// It runs the real `OwnHubApp` with the real fonts, the owner's art and the
// shipped feature flags, with ONE change for this harness only:
// `accountRequired` is off, so the product screens open without a verified
// account. Nothing in lib/ is changed by it. Every piece of data on screen is
// put there the way a woman would put it there, by tapping, and none of it is
// a real person's: no name, no phone number. Community and coaching are off,
// as they are in the shipped flags.
//
// In the normal suite it renders every set and fails on any exception or
// overflow, writing nothing. To write the PNGs, give it a folder (docs/ lives
// in the main checkout and is not committed):
//
//   cd app
//   OWNHUB_SCREENSHOTS_DIR=/path/to/docs/release/launch-pack/screenshots \
//     flutter test test/store/store_screenshots_test.dart
//
// which writes {play,apple-6.3,apple-6.9}/{en,ar}/01-welcome.png and so on.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_stops.dart';
import 'package:own_hub/features/today/presentation/today_cards.dart'
    show weekdayLabel;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../qa/round1/font_harness.dart';

/// One store size: the folder it is written to, its pixels, its density, and
/// the status bar and home indicator insets of the phone it stands for.
class _DeviceSet {
  const _DeviceSet(this.folder, this.physical, this.dpr, this.top, this.bottom);
  final String folder;
  final Size physical;
  final double dpr;
  final double top;
  final double bottom;
}

const List<_DeviceSet> _sets = <_DeviceSet>[
  // A 16:9 Android phone at 2.625x (411x731 points).
  _DeviceSet('play', Size(1080, 1920), 2.625, 24, 0),
  // iPhone 6.3" at 3x (402x874 points).
  _DeviceSet('apple-6.3', Size(1206, 2622), 3, 62, 34),
  // iPhone 6.9" at 3x (440x956 points).
  _DeviceSet('apple-6.9', Size(1320, 2868), 3, 62, 34),
];

final String? _outDir = Platform.environment['OWNHUB_SCREENSHOTS_DIR'];

/// The morning every set is rendered on: a Monday at half past nine, so the
/// two breakfasts below land under Breakfast and Home names the same day in
/// every run, whatever hour the harness is started at.
final DateTime pinnedMorning = DateTime(2026, 10, 12, 9, 30);

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

Future<void> _shoot(
  WidgetTester tester,
  _DeviceSet set,
  String lang,
  String name,
) async {
  expect(
    tester.takeException(),
    isNull,
    reason: '${set.folder}/$lang/$name threw',
  );
  final dir = _outDir;
  if (dir == null) return;
  final element = find.byType(MaterialApp).evaluate().single;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    expect(image.width, set.physical.width.toInt());
    expect(image.height, set.physical.height.toInt());
    final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final file = File('$dir/${set.folder}/$lang/$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(
      encodeOpaquePng(rgba!.buffer.asUint8List(), image.width, image.height),
    );
    image.dispose();
  });
}

/// A PNG with colour type 2 (RGB, 8 bits), so there is no alpha channel for a
/// store to refuse. [rgba] is premultiplied, as `rawRgba` gives it, and any
/// pixel that is not fully opaque is laid over white.
@visibleForTesting
Uint8List encodeOpaquePng(Uint8List rgba, int width, int height) {
  final rowBytes = width * 3 + 1;
  final raw = Uint8List(rowBytes * height);
  var o = 0;
  for (var y = 0; y < height; y++) {
    raw[o++] = 0; // filter: none
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      final white = 255 - rgba[i + 3];
      raw[o++] = (rgba[i] + white).clamp(0, 255);
      raw[o++] = (rgba[i + 1] + white).clamp(0, 255);
      raw[o++] = (rgba[i + 2] + white).clamp(0, 255);
    }
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8) // bit depth
    ..setUint8(9, 2) // colour type: RGB, no alpha
    ..setUint8(10, 0)
    ..setUint8(11, 0)
    ..setUint8(12, 0);
  final out = BytesBuilder()
    ..add(const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  void chunk(String type, List<int> data) {
    final typed = <int>[...type.codeUnits, ...data];
    out
      ..add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List())
      ..add(typed)
      ..add((ByteData(4)..setUint32(0, _crc32(typed))).buffer.asUint8List());
  }

  chunk('IHDR', header.buffer.asUint8List());
  chunk('IDAT', ZLibEncoder(level: 6).convert(raw));
  chunk('IEND', const <int>[]);
  return out.takeBytes();
}

final List<int> _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return c ^ 0xFFFFFFFF;
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
Future<void> _shootBoth(
  WidgetTester tester,
  _DeviceSet set,
  String name,
) async {
  final locale = LocaleScope.of(tester.element(find.byType(MaterialApp)));
  for (final lang in const ['en', 'ar']) {
    locale.value = Locale(lang);
    await _settle(tester);
    await _shoot(tester, set, lang, name);
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

  test('the encoder writes an RGB PNG with no alpha channel', () {
    final png = encodeOpaquePng(
      Uint8List.fromList(const <int>[10, 20, 30, 255, 0, 0, 0, 0]),
      2,
      1,
    );
    expect(png.sublist(1, 4), 'PNG'.codeUnits);
    // IHDR: width 2, height 1, bit depth 8, colour type 2 (RGB).
    final ihdr = ByteData.sublistView(png, 16, 29);
    expect(ihdr.getUint32(0), 2);
    expect(ihdr.getUint32(4), 1);
    expect(ihdr.getUint8(8), 8);
    expect(ihdr.getUint8(9), 2);
    // The CRC of an empty IEND chunk is a known constant.
    expect(png.sublist(png.length - 4), const <int>[0xAE, 0x42, 0x60, 0x82]);
  });

  for (final set in _sets) {
    testWidgets('store screenshots ${set.folder}, English and Arabic', (
      tester,
    ) async {
      await _render(tester, set, savedFlags);
    });
  }
}

Future<void> _render(
  WidgetTester tester,
  _DeviceSet set,
  FeatureFlags savedFlags,
) async {
  {
    tester.view.physicalSize = set.physical;
    tester.view.devicePixelRatio = set.dpr;
    // The status bar (and on an iPhone the home indicator), as on a phone.
    final inset = FakeViewPadding(
      top: set.top * set.dpr,
      bottom: set.bottom * set.dpr,
    );
    tester.view.padding = inset;
    tester.view.viewPadding = inset;
    tester.platformDispatcher.localesTestValue = const [Locale('en')];
    addTearDown(tester.view.reset);

    // The app's clock starts at [pinnedMorning] and moves with the test's
    // fake time, so a workout still lasts as long as it is pumped for.
    final start = tester.binding.clock.now();
    AppClock.debugNow = () =>
        pinnedMorning.add(tester.binding.clock.now().difference(start));
    addTearDown(() => AppClock.debugNow = null);
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
      await _shootBoth(tester, set, '01-welcome');
      await _home(tester);

      // 3. A workout, started and one set in.
      await _open(tester, 'R03');
      await _tapText(tester, l10n.startEverythingsReady);
      await _shootBoth(tester, set, '03-workout');

      // ...and finished, so the week has a session in it.
      Future<void> finishTheWorkout() async {
        var guard = 0;
        while (!WorkoutSessionState.instance.isComplete && guard++ < 12) {
          final all = find.textContaining('I did').hitTestable();
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
      }

      await finishTheWorkout();

      // Two breakfasts logged by typing them, as she would.
      for (final food in const ['ful', 'boiled eggs']) {
        await _open(tester, 'E02');
        await tester.enterText(find.byType(TextField).first, food);
        await _settle(tester);
        await _tapText(tester, l10n.addIt);
        await tester.pump(const Duration(seconds: 6));
        await _settle(tester);
        await _home(tester);
      }

      // 2. Home, with the week under way: on the pinned Monday, with both
      // breakfasts filed under Breakfast rather than whatever the hour was.
      expect(find.text(weekdayLabel(l10n, pinnedMorning)), findsWidgets);
      expect(find.textContaining(l10n.breakfast), findsWidgets);
      await _shootBoth(tester, set, '02-home');

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
      await _shootBoth(tester, set, '04-eat');

      // 5. One of her recipes: a savoury one everyone knows, not the first
      // page of her sweet section.
      final recipes = EatAppState.instance.recipeBook.recipes;
      EatAppState.instance.openRecipeId = recipes
          .firstWhere(
            (r) => r.recipeId == 'rahma_shakshoka',
            orElse: () => recipes.first,
          )
          .recipeId;
      await _open(tester, 'E06');
      await _shootBoth(tester, set, '05-recipe');
      await _home(tester);

      // 6. Her progress card, after the rest of her week's sessions, so it
      // shows what she did rather than a page of zeros. Her weight is not on
      // it: that is off until she turns it on.
      for (var i = 0; i < 2; i++) {
        await _open(tester, 'R03');
        await _tapText(tester, l10n.startEverythingsReady);
        await finishTheWorkout();
      }
      await _open(tester, 'P05');
      expect(find.text(l10n.shareMyCard), findsOneWidget);
      await _shootBoth(tester, set, '06-progress');
      await _home(tester);

      // 7 and 8. The tour she can take before she has an account: the real
      // screens on a sample week, labelled as a sample.
      await _open(tester, 'C04');
      for (var i = 0; i < DemoStop.weekPlan.index; i++) {
        await _tapText(tester, l10n.next);
      }
      await _shootBoth(tester, set, '07-tour-dinners');
      await _tapText(tester, l10n.next);
      expect(find.text(l10n.yourCycleIfYouWantIt), findsOneWidget);
      await _shootBoth(tester, set, '08-tour-cycle');
    } finally {
      debugDisableShadows = true;
    }
  }
}
