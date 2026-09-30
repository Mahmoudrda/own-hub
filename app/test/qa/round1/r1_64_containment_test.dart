// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-54, R1-64, R1-65, R1-66, R1-63b.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';
import 'r1_55_large_text_sweep_test.dart' show shippingScreens;

void main() {
  useShippingApp();

  testWidgets('R1-54 deep-push the dark routes', (t) async {
    phone(t);
    for (final r in ['/community/m01','/coaching/h01','/assistant/x01','/admin/z01','/signup/c10','/signup/c01','/marketplace/g01']) {
      await boot(t, locale: const Locale('en'));
      nav(t).pushNamed(r);
      await settle(t);
      final err = t.takeException();
      print('$r -> top=${topScreen(t)} featureOff=${find.byType(FeatureOff).evaluate().isNotEmpty} '
            'notBuilt=${find.byType(NotBuiltYet).evaluate().isNotEmpty} err=${err ?? "none"}');
      print('   painted: ${paintedText(t).take(5).join(" | ")}');
    }
  });

  testWidgets('R1-64 testing aids on the shipping surface', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    print('testingAidsAllowed=${AppRouter.testingAidsAllowed} (kDebugMode is true in flutter test)');
    final hits = <String>[];
    for (final id in shippingScreens) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      for (final e in tappables(t)) {
        if (RegExp(r'All screens|for testing|test payment|admin|screen index', caseSensitive: false).hasMatch(e.label)) {
          hits.add('$id: ${e.label}');
        }
      }
    }
    print('TESTING AIDS VISIBLE IN DEBUG (${hits.length}): ${hits.join(" | ")}');
    // now the release shape: accountRequired on is what release_readiness_test sets
    AppRouter.featureFlags = FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});
    print('with accountRequired ON, testingAidsAllowed=${AppRouter.testingAidsAllowed}');
    s.dispose();
  });

  testWidgets('R1-66 two clean launches are identical', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    final runs = <String>[];
    for (var i = 0; i < 2; i++) {
      wipe();
      await boot(t, locale: const Locale('en'));
      runs.add(paintedText(t).join('|'));
      // and Home underneath
      await tapLabel(t, 'Skip'); await tapLabel(t, 'Skip');
      await tapLabel(t, 'Skip'); await tapLabel(t, 'Skip');
      await tapLabel(t, 'I will start tomorrow');
      runs.add(paintedText(t).join('|'));
    }
    print('launch1 == launch2 ? ${runs[0] == runs[2]}');
    print('home1  == home2   ? ${runs[1] == runs[3]}');
    if (runs[1] != runs[3]) { print('  H1: ${runs[1]}'); print('  H2: ${runs[3]}'); }
    s.dispose();
  });

  testWidgets('R1-63b reduced motion', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    t.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true, accessibleNavigation: true);
    addTearDown(t.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final missing = <String>[];
    for (final id in shippingScreens) {
      if (!await open(t, appDestinations[id]!.name, locale: const Locale('en'))) {
        missing.add('$id threw'); continue;
      }
      final n = find.semantics.byAction(SemanticsAction.tap).evaluate().length;
      if (n == 0) missing.add('$id has no tappable node with animations off');
    }
    print('REDUCED MOTION: ${missing.isEmpty ? "every screen still has reachable controls" : missing.join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-65 first-run states are not routable', (t) async {
    phone(t);
    for (final id in ['T06','E09','Y11','Y14','M17']) {
      await boot(t, locale: const Locale('en'));
      final route = '/${id == "T06" ? "today" : id == "E09" ? "eat" : id.startsWith("Y") ? "cycle" : "community"}/${id.toLowerCase()}';
      nav(t).pushNamed(route);
      await settle(t);
      t.takeException();
      print('$id via $route -> top=${topScreen(t)} painted=${paintedText(t).take(3).join(" | ")}');
    }
  });
}
