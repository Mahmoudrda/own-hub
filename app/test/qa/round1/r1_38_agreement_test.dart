// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-38: after a session logged THROUGH THE UI, do Home, Train and Progress agree?
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();
  testWidgets('one session logged through T02', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp("Legs and glutes, today's plan"));
    await t.pump(const Duration(seconds: 8));
    t.takeException();
    print(
      'store: today=${AppRouter.todayRepository.day.week.sessionsLogged}/'
      '${AppRouter.todayRepository.day.week.sessionsTarget}  '
      'progress=${AppRouter.progressStore.goal.sessionsTarget}',
    );
    for (final id in ['T01', 'R01', 'P01']) {
      if (id == 'T01') {
        await boot(t, locale: const Locale('en'));
      } else {
        await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      }
      final week = paintedText(t)
          .where((e) => RegExp(r'of 3|of 4|week').hasMatch(e))
          .toList();
      print('$id says: ${week.join(" | ")}');
    }
    s.dispose();
  });
}
