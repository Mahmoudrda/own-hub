// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-37 to R1-48: Progress, and the account / privacy / deletion flow.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();
  for (final id in [
    'P01',
    'P02',
    'P03',
    'P04',
    'A01',
    'A02',
    'A03',
    'A04',
    'C02',
  ]) {
    testWidgets('$id day one', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('$id PAINTED: ${paintedText(t).join(" | ")}');
      print('$id TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
      s.dispose();
    });
  }
}
