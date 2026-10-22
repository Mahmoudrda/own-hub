// R09: one light buzz when the rest reaches zero with the app in the
// foreground, never twice, and never when she comes back after the end.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: child,
);

void main() {
  final saved = AppHaptics.enabled;
  late List<String?> felt;
  var wall = DateTime(2026, 10, 22, 10);
  var ready = 0;

  setUp(() {
    felt = <String?>[];
    ready = 0;
    wall = DateTime(2026, 10, 22, 10);
    AppHaptics.enabled = () => true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String?);
          }
          return null;
        });
  });
  tearDown(() {
    AppHaptics.enabled = saved;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> open(WidgetTester tester, {int seconds = 3}) async {
    await tester.pumpWidget(
      _host(
        RestingView(
          remaining: Duration(seconds: seconds),
          total: const Duration(seconds: 60),
          clock: () => wall,
          onReady: () => ready++,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('buzzes once when the rest reaches zero, not before', (
    tester,
  ) async {
    await open(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(felt, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(felt, ['HapticFeedbackType.lightImpact']);
    expect(ready, 1);
    // Nothing ticks on afterwards.
    await tester.pump(const Duration(seconds: 5));
    expect(felt, hasLength(1));
  });

  testWidgets('switched off, rest ends without a buzz', (tester) async {
    AppHaptics.enabled = () => false;
    await open(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(ready, 1);
    expect(felt, isEmpty);
  });

  testWidgets('tapping ready early does not buzz', (tester) async {
    await open(tester, seconds: 30);
    await tester.tap(find.text('I\'m ready, next set'));
    await tester.pump();
    expect(ready, 1);
    expect(felt, isEmpty);
  });

  testWidgets('coming back after the end does not buzz', (tester) async {
    await open(tester, seconds: 30);
    await tester.pump(const Duration(seconds: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    wall = wall.add(const Duration(seconds: 90));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(ready, 1);
    expect(felt, isEmpty);
  });
}
