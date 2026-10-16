// Lists stop at their ends on Android: no stretch and no glow when she pulls
// past the top or the bottom. iPhone keeps its own bounce.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_routes.dart';

import '../qa/round1/round1_harness.dart';

Future<void> _pullBothWays(WidgetTester t) async {
  final scrollable = find.byType(Scrollable).first;
  await t.drag(scrollable, const Offset(0, 400));
  await t.pump(const Duration(milliseconds: 100));
  await t.drag(scrollable, const Offset(0, -20000));
  await t.pump(const Duration(milliseconds: 100));
}

void main() {
  useShippingApp();

  testWidgets('a stock Material 3 list on Android does stretch (the control)', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await t.pumpWidget(
      MaterialApp(
        home: ListView(children: [for (var i = 0; i < 40; i++) Text('row $i')]),
      ),
    );
    await _pullBothWays(t);
    expect(find.byType(StretchingOverscrollIndicator), findsWidgets);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('the app on Android neither stretches nor glows past an end', (
    t,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    phone(t);
    for (final id in const ['A04', 'E05', 'R14']) {
      expect(await open(t, appRoutes[id]!.name), isTrue, reason: id);
      await _pullBothWays(t);
      expect(
        find.byType(StretchingOverscrollIndicator),
        findsNothing,
        reason: id,
      );
      expect(find.byType(GlowingOverscrollIndicator), findsNothing, reason: id);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
