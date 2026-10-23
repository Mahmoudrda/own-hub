// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-62 / R1-61: every interactive node on the shipping surface, with its
// label and its tap-target rect.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';
import 'r1_55_large_text_sweep_test.dart' show shippingScreens;

void main() {
  useShippingApp();
  for (final loc in ['en', 'ar']) {
    testWidgets('labels and tap targets, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      final unlabelled = <String>[];
      final small = <String>[];
      var total = 0;
      for (final id in shippingScreens) {
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(appDestinations[id]!.name);
        await settle(t);
        if (t.takeException() != null) continue;
        for (final n
            in find.semantics.byAction(SemanticsAction.tap).evaluate()) {
          final d = n.getSemanticsData();
          total++;
          final label = d.label.trim();
          final tip = d.tooltip.trim();
          final hint = d.hint.trim();
          final r = MatrixUtils.transformRect(
            n.transform ?? Matrix4.identity(),
            n.rect,
          );
          if (label.isEmpty && tip.isEmpty && hint.isEmpty) {
            unlabelled.add(
              '$id  rect=${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}',
            );
          } else if (label.isEmpty) {
            unlabelled.add(
              '$id  LABEL EMPTY, tooltip="$tip" hint="$hint" rect=${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}',
            );
          }
          if (r.width < 44 || r.height < 44) {
            final name = label.isNotEmpty
                ? label
                : (tip.isNotEmpty ? '(tooltip) $tip' : '(unlabelled)');
            small.add(
              '$id  ${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}  ${name.replaceAll("\n", " ")}',
            );
          }
        }
      }
      print(
        '=== $loc: $total tappable nodes over ${shippingScreens.length} screens ===',
      );
      print('UNLABELLED OR LABEL-EMPTY (${unlabelled.length}):');
      for (final u in unlabelled.toSet()) {
        print('  $u');
      }
      print('UNDER 44pt (${small.length}):');
      for (final u in small.toSet()) {
        print('  $u');
      }
      s.dispose();
    });
  }
}
