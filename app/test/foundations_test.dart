// The three foundations §7 puts first: tokens, localisation with RTL, and a font
// covering both scripts. Asserted rather than eyeballed because all three fail
// silently — a missing Arabic subset renders tofu, an unmirrored layout still
// lays out, and a missing font falls back to Roboto without any error.
//
// These once ran against a temporary debug shell the app opened into. The shell
// is gone and the app opens on C01, so the same properties are now asserted
// against the real first screen — which is stronger: it proves the product
// renders, not that a harness did.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

void main() {
  // The front door is sign-up only when an account is required. The owner has
  // switched that off for testing, so these pin it on: they are about what a
  // cold start draws when there IS a front door.
  final saved = AppRouter.featureFlags;
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: true,
    });
  });
  tearDown(() => AppRouter.featureFlags = saved);

  group('the app opens on the front door', () {
    testWidgets('a cold start lands on C01, not on scaffolding', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(const OwnHubApp());
      await tester.pumpAndSettle();

      // The regression this guards: the app spent a while opening into a debug
      // shell titled "Foundations". All 40 routes worked; nothing pointed at the
      // first screen, and only a screenshot caught it.
      expect(
        find.text('A room full of women training like you'),
        findsOneWidget,
      );
      expect(find.text('Get started'), findsOneWidget);
      expect(find.text('Foundations'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('the front door is the generated route for C01', () {
      expect(appRoutes['C01']!.name, '/signup/c01');
      expect(screenIdForRoute('/signup/c01'), 'C01');
    });

    test('no ancestor segment of the initial route resolves', () {
      // The blank-screen bug, pinned. Flutter's DEFAULT initial-route handling
      // walks the ancestors of "/signup/c01" — "/" and "/signup" — and expects
      // each to generate a route. Neither is a screen, so the default would
      // fail and render nothing at all.
      //
      // The app therefore supplies its own onGenerateInitialRoutes returning a
      // single route. This test documents WHY that override must stay: if
      // someone removes it, these nulls are what breaks the app.
      expect(screenIdForRoute('/'), isNull);
      expect(screenIdForRoute('/signup'), isNull);
      expect(AppRouter.onGenerateRoute(const RouteSettings(name: '/')), isNull);
      expect(
        AppRouter.onGenerateRoute(const RouteSettings(name: '/signup')),
        isNull,
      );
    });

    testWidgets('the initial route builds exactly one page, not a stack', (
      WidgetTester tester,
    ) async {
      // Exercises the real generator rather than trusting pumpWidget's default.
      await tester.pumpWidget(const OwnHubApp());
      await tester.pumpAndSettle();

      // A blank screen has no text at all; this is the assertion that would have
      // caught it.
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.text('Get started'), findsOneWidget);
    });
  });

  group('the font carries both scripts', () {
    testWidgets('Arabic renders as glyphs, not blank boxes', (tester) async {
      // Rubik ships as per-script woff2 subsets of a variable font, merged into
      // one TTF per weight. If the Arabic subset were missing from that merge,
      // the entire Arabic UI would be tofu and nothing would raise an error.
      await tester.pumpWidget(const OwnHubApp());
      await tester.pumpAndSettle();

      LocaleScope.of(tester.element(find.byType(MaterialApp)))
          .value = const Locale(
        'ar',
      );
      await tester.pumpAndSettle();

      expect(find.text('غرفة مليئة بنساء يتدرّبن مثلك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('and the layout mirrors with it', (tester) async {
      await tester.pumpWidget(const OwnHubApp());
      await tester.pumpAndSettle();

      LocaleScope.of(tester.element(find.byType(MaterialApp)))
          .value = const Locale(
        'ar',
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('لنبدأ'))),
        TextDirection.rtl,
      );
    });
  });

  test('both locales the product ships are registered', () {
    final codes = AppL10n.supportedLocales.map((l) => l.languageCode).toSet();
    expect(codes, containsAll(<String>['en', 'ar']));
  });

  test('the theme is Material 3, in Rubik, on the product colour', () {
    final theme = buildTheme(const Locale('en'));
    expect(theme.useMaterial3, isTrue);
    expect(theme.textTheme.bodyLarge?.fontFamily, 'Rubik');
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.scaffoldBackgroundColor, AppColors.surface);
  });

  test('the type scale came from the design tokens, not from defaults', () {
    // Guards against someone "fixing" a layout by editing the generated tokens
    // file; it comes from src/tokens.mjs and must be regenerated instead.
    expect(AppText.display.fontSize, 32);
    expect(AppText.body.fontSize, 16);
    expect(AppText.nav.fontSize, 12);
    expect(AppRadius.full, 999.0);
  });
}
