// M10: the women-only check passed. C13's tick gives one light touch and one
// two-note sound as it draws on, and stays quiet when the screen opened with
// no tap from her (from a notification, say) or when she has sounds off.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/feel_prefs.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/presentation/youre_in_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_sound.dart';

Widget _host({bool reduceMotion = false}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: const YoureInView(),
);

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedHaptics = AppHaptics.enabled;
  late List<String?> felt;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = FeatureFlags.everything;
    AppHaptics.enabled = () => FeelPrefs.instance.haptics;
    felt = <String?>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String?);
          }
          return null;
        });
  });
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppHaptics.enabled = savedHaptics;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    tearDownFakeSound();
  });

  testWidgets('one light touch and one sound as the tick draws', (
    tester,
  ) async {
    final backend = setUpFakeSound();
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 3));
    expect(backend.names, ['verified']);
    expect(felt, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('both play with Reduce Motion on', (tester) async {
    final backend = setUpFakeSound();
    await tester.pumpWidget(_host(reduceMotion: true));
    expect(backend.names, ['verified']);
    expect(felt, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('a screen that opened by itself stays quiet', (tester) async {
    final backend = setUpFakeSound(touched: false);
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 3));
    expect(backend.played, isEmpty);
  });

  testWidgets('with sounds off the touch still comes', (tester) async {
    final backend = setUpFakeSound();
    unawaited(FeelPrefs.instance.setSounds(false));
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 3));
    expect(backend.played, isEmpty);
    expect(felt, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('with haptics off the sound still comes', (tester) async {
    final backend = setUpFakeSound();
    unawaited(FeelPrefs.instance.setHaptics(false));
    await tester.pumpWidget(_host());
    await tester.pump(const Duration(seconds: 3));
    expect(backend.names, ['verified']);
    expect(felt, isEmpty);
  });
}
