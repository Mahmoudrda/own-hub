// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-51 back everywhere, R1-58 empty states, R1-36 tap depth, R1-15, R1-26.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_empty_state.dart';
import 'round1_harness.dart';
import 'r1_55_large_text_sweep_test.dart' show shippingScreens;

void main() {
  useShippingApp();

  testWidgets('R1-51 system back from every shipping screen', (t) async {
    phone(t);
    final trapped = <String>[];
    final blank = <String>[];
    for (final id in shippingScreens) {
      if (!await open(t, appDestinations[id]!.name, locale: const Locale('en'))) continue;
      final before = topScreen(t);
      final popped = await t.binding.handlePopRoute();
      await settle(t);
      t.takeException();
      final after = topScreen(t);
      final text = paintedText(t);
      if (after == before && before != null) trapped.add('$id: back did nothing (popped=$popped)');
      if (text.isEmpty) blank.add('$id: back landed on a blank page');
    }
    print('BACK TRAPS (${trapped.length}): ${trapped.join(" | ")}');
    print('BLANK AFTER BACK (${blank.length}): ${blank.join(" | ")}');
  });

  testWidgets('R1-58 which screens use the shared empty state', (t) async {
    phone(t);
    final uses = <String>[];
    for (final id in shippingScreens) {
      if (!await open(t, appDestinations[id]!.name, locale: const Locale('en'))) continue;
      if (find.byType(AppEmptyState).evaluate().isNotEmpty) uses.add(id);
    }
    print('SHARED AppEmptyState ON DAY ONE (${uses.length}): ${uses.join(" ")}');
  });

  testWidgets('R1-36 tap depth Home -> log a period', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await boot(t, locale: const Locale('en'));
    for (var i = 0; i < 6; i++) { await tapLabel(t, 'Continue'); if (topScreen(t) == 'O05') break; }
    await tapLabel(t, 'I will start tomorrow');
    print('0 taps: on ${topScreen(t)}  tappable=${tappables(t).map((e)=>e.label).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-15 the workout library', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['R11']!.name, locale: const Locale('en'));
    final rows = tappables(t).map((e)=>e.label).where((l) => RegExp(r'min').hasMatch(l)).toList();
    print('R11 rows (${rows.length}): ${rows.join(" | ")}');
    for (final r in rows) {
      await open(t, appDestinations['R11']!.name, locale: const Locale('en'));
      // `tapControl`, not `tapLabel`: `rows` comes off `tappables`, which
      // flattens a label's newlines to spaces. The library row is one label
      // reading "Legs and glutes\n15 min · beginner · no equipment", so a regex
      // built from the printed form never matched the real one and the sweep
      // stopped on its second row. `tapControl` compares the flattened form.
      final opened = await tapControl(t, RegExp(RegExp.escape(r)));
      print('  "$r" -> ${opened ? topScreen(t) : "NOT ACTIVATABLE"}: ${paintedText(t).take(6).join(" | ")}');
    }
    s.dispose();
  });

  testWidgets('R1-26 the two filters that can select nothing', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    for (final f in ['Cheap', 'No nuts']) {
      await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
      if (!hasLabel(t, RegExp(RegExp.escape(f)))) { print('$f: no such chip on a fresh install'); continue; }
      await tapLabel(t, RegExp(RegExp.escape(f)));
      print('$f -> ${paintedText(t).join(" | ")}');
    }
    s.dispose();
  });
}
