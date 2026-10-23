// R1-53 / R1-54. What the shipping flag set actually resolves to.
//
// Push every route in `appDestinations` with the six shipped features on and
// everything else off, and record what came back: a real screen, `FeatureOff`,
// `NotBuiltYet`, or an exception. Nothing in this repository has ever done this
// at the shipping flag set.
@Tags(['qa'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();

  testWidgets('every route, at the shipping flag set', (tester) async {
    phone(tester);

    final rendered = <String>[];
    final featureOff = <String>[];
    final notBuilt = <String>[];
    final threw = <String>[];
    final unresolved = <String>[];

    for (final entry in appDestinations.entries) {
      await boot(tester);
      Object? err;
      try {
        nav(tester).pushNamed(entry.value.name);
        await settle(tester);
        err = tester.takeException();
      } catch (e) {
        err = e;
      }
      if (err != null) {
        threw.add('${entry.key}: ${'$err'.split('\n').first}');
        continue;
      }
      if (find.byType(NotBuiltYet).evaluate().isNotEmpty) {
        notBuilt.add(entry.key);
      } else if (find.byType(FeatureOff).evaluate().isNotEmpty) {
        featureOff.add(entry.key);
      } else if (topScreen(tester) == entry.key) {
        rendered.add(entry.key);
      } else {
        unresolved.add('${entry.key} -> ${topScreen(tester)}');
      }
    }

    // ignore: avoid_print
    print('SHIPPING SURFACE (${rendered.length}): ${rendered.join(" ")}');
    // ignore: avoid_print
    print('FEATURE-OFF (${featureOff.length}): ${featureOff.join(" ")}');
    // ignore: avoid_print
    print('NOT-BUILT-YET (${notBuilt.length}): ${notBuilt.join(" ")}');
    // ignore: avoid_print
    print('THREW (${threw.length}):');
    for (final t in threw) {
      // ignore: avoid_print
      print('  $t');
    }
    // ignore: avoid_print
    print(
      'DID NOT LAND ON ITSELF (${unresolved.length}): ${unresolved.join(" ")}',
    );

    expect(threw, isEmpty, reason: 'a route threw on open');
    expect(
      notBuilt,
      isEmpty,
      reason: 'a route resolves to the not-built-yet panel at shipping flags',
    );
  });
}
