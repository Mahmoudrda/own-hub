// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-28 to R1-36: My cycle, including the severe branch.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();
  for (final id in [
    'Y01',
    'Y02',
    'Y03',
    'Y04',
    'Y05',
    'Y06',
    'Y07',
    'Y08',
    'Y09',
    'Y10',
    'Y12',
    'Y13',
  ]) {
    testWidgets('$id as opened', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('$id PAINTED: ${paintedText(t).join(" | ")}');
      print('$id TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
      s.dispose();
    });
  }
  testWidgets('R1-29 the symptom-only path from Y01', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['Y01']!.name, locale: const Locale('en'));
    print('Y01 choices: ${tappables(t).map((e) => e.label).join(" | ")}');
    s.dispose();
  });
}
