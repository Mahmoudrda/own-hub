// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-29: the symptom-only path, and whether the gentler-session consent is
// reachable on it.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void _dumpConsents(WidgetTester t, String where) {
  for (final n in find.semantics.byPredicate((_) => true).evaluate()) {
    final d = n.getSemanticsData();
    if (d.label.contains('easier workout') ||
        d.label.contains('Workout suggestions') ||
        d.label.contains('workout suggestions') ||
        d.label.contains('gentler')) {
      print(
        '$where  "${d.label}"  tap=${d.hasAction(SemanticsAction.tap)} toggled=${d.flagsCollection.isToggled} enabled=${d.flagsCollection.isEnabled}',
      );
    }
  }
}

void main() {
  useShippingApp();
  testWidgets('symptom-only path', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['Y01']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Track symptoms only'));
    await tapLabel(t, 'Continue');
    print('symptom-only after Continue: top=${topScreen(t)}');
    print('PAINTED: ${paintedText(t).join(" | ")}');
    print('TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
    _dumpConsents(t, 'AFTER-SETUP');
    // go to settings
    nav(t).pushNamed(appDestinations['Y12']!.name);
    await settle(t);
    print('Y12 on symptom-only PAINTED: ${paintedText(t).join(" | ")}');
    print(
      'Y12 on symptom-only TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}',
    );
    _dumpConsents(t, 'Y12');
    nav(t).pushNamed(appDestinations['Y10']!.name);
    await settle(t);
    print('Y10 on symptom-only PAINTED: ${paintedText(t).join(" | ")}');
    _dumpConsents(t, 'Y10');
    s.dispose();
  });

  testWidgets('dates path, same consents for comparison', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['Y01']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Track periods and symptoms'));
    await tapLabel(t, 'Continue');
    print('dates path after Continue: top=${topScreen(t)}');
    _dumpConsents(t, 'Y02');
    print('Y02 TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
    s.dispose();
  });
}
