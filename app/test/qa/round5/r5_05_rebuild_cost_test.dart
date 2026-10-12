// ignore_for_file: avoid_print
//
// R5-05. What one `AppChanges.bump()` costs, and how it grows with the stack.
//
// `app_router.dart:404-409` wraps EVERY routed screen in a
// `ListenableBuilder(listenable: AppChanges.instance)`. There are 102
// `AppChanges.bump()` call sites, and `lib/` contains zero `RepaintBoundary`
// and zero `ListView.builder` — `AppScaffold` is a `SingleChildScrollView`
// around an eager `Column`, so a screen builds all of its rows whether or not
// they are on screen.
//
// Put together: one tap that logs a set rebuilds and re-lays-out the whole of
// every screen in the navigator stack, not just the one she is looking at.
// Paint is saved — all 18 `shouldRepaint` overrides compare their fields and
// none returns an unconditional true — but build and layout are not.
//
// This measures it rather than asserting a budget, because the only honest
// budget is a real handset's and this runs on a laptop. The shape of the
// curve is the finding: flat means the fan-out does not matter, linear in the
// stack depth means it does.
//
// It did. `RedrawOnChange` replaced the `ListenableBuilder`, so a bump now
// rebuilds only the screen she is looking at and a covered screen catches up
// when it is uncovered. Re-run on one laptop, before and after:
//
//   depth 1  6.3 -> 4.7 ms      depth 4 (+E01)  10.2 -> 4.1 ms
//   depth 2  11.2 -> 6.6 ms     depth 5 (+E07)   8.4 -> 2.2 ms
//   depth 3  7.6 -> 1.6 ms      depth 6 (+P01)  11.6 -> 4.1 ms
//
// Flat, and now the cost of whichever screen is on top. The contract it
// replaced is held by `test/app_state/redraw_on_change_test.dart`.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';
import 'r5_01_small_screen_sweep_test.dart' show device;

/// Milliseconds for one bump, as the median of [runs] pumps.
Future<double> _bumpCost(WidgetTester t, {int runs = 20}) async {
  final samples = <int>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    AppChanges.bump();
    await t.pump();
    watch.stop();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2] / 1000;
}

void main() {
  useShippingApp();

  testWidgets('one bump, against navigator depth', (t) async {
    // iPhone 7, the small end: a shorter viewport builds the same eager Column
    // and lays out more of it per point of width.
    device(t, width: 375, height: 667, dpr: 2.0);

    // Deliberately a stack of the heaviest shipped screens she can actually
    // reach in this order: Home, a workout, the move, Eat, the week's plan.
    const stack = <String>['R01', 'R02', 'E01', 'E07', 'P01'];

    await boot(t, locale: const Locale('ar'));
    print('=== R5-05 one AppChanges.bump(), 375x667, Arabic ===');
    print('  depth 1 (front door alone): '
        '${(await _bumpCost(t)).toStringAsFixed(2)} ms');

    for (var i = 0; i < stack.length; i++) {
      nav(t).pushNamed(appDestinations[stack[i]]!.name);
      await settle(t);
      t.takeException();
      final ms = await _bumpCost(t);
      print('  depth ${i + 2} (+${stack[i]}): ${ms.toStringAsFixed(2)} ms');
    }

    // No assertion on a number a laptop produced. The case exists so the cost
    // is written down and so a change that makes it worse is visible in a
    // diff rather than on a handset in Cairo.
  });
}
