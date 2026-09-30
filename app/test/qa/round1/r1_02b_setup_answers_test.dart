// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-02: does her answer reach the target she is measured against?
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

Future<void> _toO03(WidgetTester t) async {
  await boot(t, locale: const Locale('en'));
  await tapLabel(t, 'Continue'); // O01 -> O02
  await tapLabel(t, 'Continue'); // O02 -> O03
}

void main() {
  useShippingApp();
  // Was ['2','3','4','5']. Stale: O03 offered a fifth chip whose value the
  // rewards system then refused, and the fix was to stop offering it rather
  // than to raise `kMaxSessionsTarget`. `Intake.allowedDays` is the list, and
  // this sweep walks exactly what the screen draws.
  for (final days in ['2', '3', '4']) {
    testWidgets('she picks $days days a week', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await _toO03(t);
      expect(topScreen(t), 'O03');
      await tapLabel(t, days);
      print('O03 after tapping $days: ${paintedText(t).join(" | ")}');
      await tapLabel(t, 'Continue'); // O04
      await tapLabel(t, 'Continue'); // O05
      print('O05 summary: ${paintedText(t).take(4).join(" | ")}');
      await tapLabel(t, 'Start day 1 now');
      print('PICKED $days -> TOP=${topScreen(t)} setupDone=${AppRouter.intakeRepository.setupDone} '
            'intakeDays=${AppRouter.intakeRepository.read().days} '
            'homeTarget=${AppRouter.todayRepository.day.week.sessionsTarget} '
            'progressTarget=${AppRouter.progressStore.goal.sessionsTarget}');
      s.dispose();
    });
  }

  testWidgets('O05 three exits', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    for (final exit in ['Start day 1 now', 'I will start tomorrow', 'Pick a different program']) {
      wipe();
      await boot(t, locale: const Locale('en'));
      await tapLabel(t, 'Continue');
      await tapLabel(t, 'Continue');
      await tapLabel(t, 'Continue');
      await tapLabel(t, 'Continue');
      expect(topScreen(t), 'O05');
      await tapLabel(t, exit);
      print('O05 "$exit" -> TOP=${topScreen(t)} setupDone=${AppRouter.intakeRepository.setupDone}');
      print('   now tappable: ${tappables(t).map((e) => e.label).join(" | ")}');
    }
    s.dispose();
  });

  testWidgets('the X closes on each question', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    for (final n in [0, 1, 2, 3]) {
      wipe();
      await boot(t, locale: const Locale('en'));
      for (var i = 0; i < n; i++) { await tapLabel(t, 'Continue'); }
      final before = topScreen(t);
      // `tapControl`, not `tapLabel`: the X is an IconButton named by its
      // tooltip (app_scaffold.dart:202), so its semantics LABEL is empty and
      // `byLabel('Skip setup')` found nothing. The control was always reachable
      // by a screen reader; the matcher was reading the wrong field.
      final closed = await tapControl(t, 'Skip setup');
      expect(closed, isTrue, reason: 'every question must offer a way out');
      print('X on $before -> TOP=${topScreen(t)} setupDone=${AppRouter.intakeRepository.setupDone} '
            'homeTarget=${AppRouter.todayRepository.day.week.sessionsTarget}');
    }
    s.dispose();
  });
}
