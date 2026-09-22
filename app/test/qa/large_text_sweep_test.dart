// Every screen, opened at the largest text a phone will give it.
//
// A woman who turns her text up is not an edge case: the accessibility sizes on
// both platforms go well past 1.6, and at that size a row that was tight at
// 1.0 throws "RenderFlex overflowed" and shows a striped bar where her numbers
// were. The redesign swept this by hand once and fixed twelve screens; this
// keeps the sweep, so a screen built later cannot quietly reintroduce it.
//
// It asserts nothing about beauty. It asserts only that nothing overflows.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {
    // A long animation is not what this test is about.
  }
}

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  testWidgets('no screen overflows at 1.6x text', (tester) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final overflowed = <String>[];
    for (final entry in appDestinations.entries) {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _settle(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(entry.value.name);
      await _settle(tester);
      final thrown = tester.takeException();
      if (thrown != null) {
        overflowed.add('${entry.key}: $thrown'.split('\n').first);
      }
    }

    // ignore: avoid_print
    print('OVERFLOWED AT 1.6x (${overflowed.length}):');
    for (final line in overflowed) {
      // ignore: avoid_print
      print('  $line');
    }
    expect(overflowed, isEmpty);
  });
}
