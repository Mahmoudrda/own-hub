// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-01 / R1-06 / R1-11: what a woman sees in her first sixty seconds.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

Future<void> _skipSetup(WidgetTester t, {String loc = 'en'}) async {
  await boot(t, locale: Locale(loc));
  for (var i = 0; i < 4; i++) { await tapLabel(t, loc == 'en' ? 'Skip' : 'تخطّي'); }
  // O05
  await tapLabel(t, loc == 'en' ? 'I will start tomorrow' : 'سأبدأ غدًا');
}

void main() {
  useShippingApp();
  testWidgets('R1-01 Home on day one', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await _skipSetup(t);
    print('TOP=${topScreen(t)}');
    print('HOME: ${paintedText(t).join(" | ")}');
    print('TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
    s.dispose();
  });
  testWidgets('R1-06 one tap to Train, one tap to Eat', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await _skipSetup(t);
    await tapLabel(t, 'Train');
    print('TRAIN: ${paintedText(t).join(" | ")}');
    await tapLabel(t, 'Eat');
    print('EAT: ${paintedText(t).join(" | ")}');
    s.dispose();
  });
  for (final id in ['T04', 'T05', 'T07', 'T08', 'T02', 'T03']) {
    testWidgets('$id as opened on day one', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('$id TOP=${topScreen(t)}');
      print('$id PAINTED: ${paintedText(t).join(" | ")}');
      print('$id TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
      s.dispose();
    });
  }
}
