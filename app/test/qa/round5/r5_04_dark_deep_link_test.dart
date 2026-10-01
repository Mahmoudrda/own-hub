// ignore_for_file: avoid_print
//
// R5-04. The first screen a woman ever sees, when the link that brought her
// here names a feature the first release does not ship.
//
// `onGenerateRoute` answers a switched-off screen with `FeatureOff` — an app
// bar reading the raw screen id and one English sentence about a feature flag.
// Pushed on top of the running app that is a dead end she can back out of.
// Reached as the INITIAL route it is the whole product, on first launch, in a
// language she may not read.
//
// `_initialRoute` guarded against `resolvesInThisBuild` only, which covers the
// admin console and nothing else: `community`, `coaching`, `marketplace` and
// `assistant` are all built, tested and resolvable, and all switched off in
// `FeatureFlags.shipped`. Every link anyone shares about those between now and
// the second release arrives here.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

/// The dark routes a link could plausibly name, one per switched-off area.
const Map<String, String> _darkRoutes = <String, String>{
  'community': '/community/m01',
  'coaching desk': '/coaching/h01',
  'marketplace': '/marketplace/g01',
  'assistant': '/assistant/x01',
  'sign-up': '/signup/c01',
  'admin console': '/admin/z01',
};

void main() {
  useShippingApp();

  testWidgets('a link to a switched-off screen opens the front door', (
    t,
  ) async {
    phone(t);
    final landed = <String, String?>{};
    final showedFeatureOff = <String>[];

    for (final entry in _darkRoutes.entries) {
      t.platformDispatcher.defaultRouteNameTestValue = entry.value;
      addTearDown(t.platformDispatcher.clearDefaultRouteNameTestValue);

      await boot(t, locale: const Locale('ar'));
      t.takeException();

      landed[entry.key] = topScreen(t);
      if (find.byType(FeatureOff).evaluate().isNotEmpty) {
        showedFeatureOff.add('${entry.key} (${entry.value})');
      }
    }

    print('=== R5-04 launched by a link to a dark feature ===');
    for (final e in landed.entries) {
      print('  ${e.value}\t<- ${e.key}');
    }
    print('  showed the feature-flag page: '
        '${showedFeatureOff.isEmpty ? "none" : showedFeatureOff.join(" | ")}');

    expect(
      showedFeatureOff,
      isEmpty,
      reason: 'a link to a switched-off feature made the developer '
          'feature-flag page the first screen of the product',
    );
    // T01 is the front door with `accountRequired` off, which is the shipping
    // shape. O01 sits on top of it on a first run, so either is the right
    // answer; `FeatureOff` and a blank page are not.
    expect(
      landed.values.every((s) => s == 'T01' || s == 'O01'),
      isTrue,
      reason: 'a dark link should land on the front door, got $landed',
    );
  });

  testWidgets('a link to a shipped screen still opens that screen', (t) async {
    // The guard must not break the thing the supplied route is FOR. T07's
    // lock-screen nudge has nowhere to land without it, and every screenshot
    // of an arbitrary screen is taken this way.
    phone(t);
    for (final id in <String>['T03', 'R02', 'E01', 'Y03', 'P01']) {
      t.platformDispatcher.defaultRouteNameTestValue =
          appDestinations[id]!.name;
      addTearDown(t.platformDispatcher.clearDefaultRouteNameTestValue);
      await boot(t, locale: const Locale('en'));
      t.takeException();
      expect(
        topScreen(t),
        id,
        reason: 'a link to shipped screen $id did not open it',
      );
    }
  });
}
