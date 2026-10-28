// A02: one row, "Sounds and touch", and in its sheet her two switches. Both
// start on, each is its own, and turning one off silences exactly that.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/feel_prefs.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/account/presentation/profile_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host({Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: ProfileView(dietaryRepository: InMemoryDietaryProfileRepository()),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeelPrefs.instance.debugReset();
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.sounds: true,
      Feature.haptics: true,
    });
  });
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    FeelPrefs.instance.debugReset();
  });

  Future<void> openSheet(WidgetTester tester, {String row = 'Sounds and touch'}) async {
    _phone(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    await tester.tap(find.text(row));
    await tester.pumpAndSettle();
  }

  testWidgets('the row opens a sheet with both switches on', (tester) async {
    await openSheet(tester);
    expect(find.byKey(const ValueKey('a02-sounds')), findsOneWidget);
    expect(find.byKey(const ValueKey('a02-haptics')), findsOneWidget);
    expect(find.text('Sounds'), findsOneWidget);
    expect(find.text('Haptics'), findsOneWidget);
    expect(FeelPrefs.instance.sounds, isTrue);
    expect(FeelPrefs.instance.haptics, isTrue);
  });

  testWidgets('tapping Sounds turns only sounds off, and again turns them on', (
    tester,
  ) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('a02-sounds')));
    await tester.pumpAndSettle();
    expect(FeelPrefs.instance.sounds, isFalse);
    expect(FeelPrefs.instance.haptics, isTrue);
    await tester.tap(find.byKey(const ValueKey('a02-sounds')));
    await tester.pumpAndSettle();
    expect(FeelPrefs.instance.sounds, isTrue);
  });

  testWidgets('tapping Haptics turns only haptics off', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('a02-haptics')));
    await tester.pumpAndSettle();
    expect(FeelPrefs.instance.haptics, isFalse);
    expect(FeelPrefs.instance.sounds, isTrue);
  });

  testWidgets('each switch states its state to a screen reader', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Sounds').first),
      matchesSemantics(
        label: 'Sounds',
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('her choice is kept on the phone', (tester) async {
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('a02-sounds')));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kSoundsOnKey), isFalse);
  });

  testWidgets('a feature the server turned off has no switch', (tester) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.sounds: false,
      Feature.haptics: true,
    });
    await openSheet(tester);
    expect(find.byKey(const ValueKey('a02-sounds')), findsNothing);
    expect(find.byKey(const ValueKey('a02-haptics')), findsOneWidget);
  });

  testWidgets('with both turned off there is no row at all', (tester) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.sounds: false,
      Feature.haptics: false,
    });
    _phone(tester);
    await tester.pumpWidget(_host());
    await tester.pumpAndSettle();
    expect(find.text('Sounds and touch'), findsNothing);
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    testWidgets('the sheet fits a small phone at 200% text, '
        '${locale.languageCode}', (tester) async {
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(locale),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.0)),
            child: child!,
          ),
          home: ProfileView(
            dietaryRepository: InMemoryDietaryProfileRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.byIcon(Icons.volume_up_outlined),
        find.byType(Scrollable).first,
        const Offset(0, -200),
      );
      await tester.tap(find.byIcon(Icons.volume_up_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('a02-sounds')), findsOneWidget);
      expect(find.byKey(const ValueKey('a02-haptics')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('it reads in Egyptian Arabic too', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(locale: const Locale('ar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الصوت واللمس'));
    await tester.pumpAndSettle();
    expect(find.text('الأصوات'), findsOneWidget);
    expect(find.text('الاهتزاز'), findsOneWidget);
  });
}
