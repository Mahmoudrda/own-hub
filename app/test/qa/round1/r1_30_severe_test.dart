// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-29 / R1-30 / R1-31: the severe branch and the two routes to care.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();
  testWidgets('R1-30 log severe cramps and read the hub', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    // set up the cycle first
    await open(t, appDestinations['Y01']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Track periods and symptoms'));
    await tapLabel(t, 'Continue');
    print('after Y01 continue: top=${topScreen(t)}');
    if (topScreen(t) == 'Y02') {
      await tapLabel(t, 'Save preferences');
    }
    print('after Y02: top=${topScreen(t)}');
    // now the check-in
    nav(t).pushNamed(appDestinations['Y04']!.name);
    await settle(t);
    await tapLabel(t, 'Cramps, appetite, sleep and more');
    // Cramps come first; the bloating row has its own Severe.
    await t.tap(find.text('Severe').first);
    await settle(t);
    await tapLabel(t, 'Save check-in');
    print('after severe check-in: top=${topScreen(t)}');
    print('PAINTED: ${paintedText(t).join(" | ")}');
    print('TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-31 the two routes to care', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['Y01']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Track periods and symptoms'));
    await tapLabel(t, 'Continue');
    if (topScreen(t) == 'Y02') {
      await tapLabel(t, 'Save preferences');
    }
    nav(t).pushNamed(appDestinations['Y04']!.name);
    await settle(t);
    await tapLabel(t, 'Cramps, appetite, sleep and more');
    // Cramps come first; the bloating row has its own Severe.
    await t.tap(find.text('Severe').first);
    await settle(t);
    await tapLabel(t, 'Save check-in');
    for (final label in [
      'Find care near you',
      'Read NHS guidance on period pain',
    ]) {
      if (!hasLabel(t, RegExp(RegExp.escape(label)))) {
        print('NO SUCH CONTROL: $label');
        continue;
      }
      await tapLabel(t, RegExp(RegExp.escape(label)));
      print(
        'TAPPED "$label" -> top=${topScreen(t)} sheets=${find.byType(BottomSheet).evaluate().length}',
      );
      print('   painted now: ${paintedText(t).join(" | ")}');
      await boot(t, locale: const Locale('en'));
      nav(t).pushNamed(appDestinations['Y03']!.name);
      await settle(t);
    }
    s.dispose();
  });

  testWidgets('Y10 toggle has a tap action?', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['Y10']!.name, locale: const Locale('en'));
    for (final n in find.semantics.byPredicate((_) => true).evaluate()) {
      final d = n.getSemanticsData();
      if (d.label.contains('easier workout') ||
          d.label.contains('low energy')) {
        print(
          'Y10 NODE "${d.label}" tap=${d.hasAction(SemanticsAction.tap)} '
          'toggled=${d.flagsCollection.isToggled} enabled=${d.flagsCollection.isEnabled} '
          '',
        );
      }
    }
    print(
      'Y10 all switch-ish: ${find.byType(Switch).evaluate().length} switches',
    );
    s.dispose();
  });
}
