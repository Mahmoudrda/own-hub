// Y09 — saving a period gets a response she can feel and see: a light tap and
// a tick drawn on, then the page moves on. The kitten is never on Cycle.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/features/cycle/presentation/log_period_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/hand.dart';

Widget _host(Widget child, {bool disableAnimations = false}) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: disableAnimations),
      child: child,
    ),
  ),
);

void main() {
  final felt = <String?>[];
  final saved = AppHaptics.enabled;

  setUp(() {
    felt.clear();
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

  testWidgets('Save draws a tick and gives a light tap, then moves on', (
    tester,
  ) async {
    var moved = 0;
    await tester.pumpWidget(_host(LogPeriodView(onSaved: () => moved++)));
    await tester.pumpAndSettle();
    expect(find.byType(HandTick), findsNothing);

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(find.byType(HandTick), findsOneWidget);
    expect(felt, ['HapticFeedbackType.lightImpact']);
    expect(moved, 0, reason: 'the tick is drawn before the page moves on');

    await tester.pump(HandMotion.draw);
    await tester.pumpAndSettle();
    expect(moved, 1);
    expect(felt, hasLength(1), reason: 'one save, one tap');
  });

  testWidgets('under reduced motion it moves on at once', (tester) async {
    var moved = 0;
    await tester.pumpWidget(
      _host(LogPeriodView(onSaved: () => moved++), disableAnimations: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(moved, 1);
    expect(felt, ['HapticFeedbackType.lightImpact']);
  });

  test('no kitten on Y09', () {
    final source = File('lib/features/cycle/presentation/log_period_view.dart')
        .readAsStringSync();
    expect(source.contains('Kitten('), isFalse);
  });
}
