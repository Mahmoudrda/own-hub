// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-07 / R1-08: the undo bar, measured second by second.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

int get _logged => AppRouter.todayRepository.day.week.sessionsLogged;

void main() {
  useShippingApp();
  testWidgets('bar lifetime, no undo tapped', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp("Legs and glutes, today's plan"));
    for (var ms = 0; ms <= 12000; ms += 500) {
      final bar = find.byType(SnackBar).evaluate().length;
      final undo = hasLabel(t, RegExp('Undo'));
      print('  t=${ms}ms bar=$bar undoReachable=$undo sessions=$_logged');
      await t.pump(const Duration(milliseconds: 500));
    }
    s.dispose();
  });

  testWidgets('undo inside the window', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp("Legs and glutes, today's plan"));
    await t.pump(const Duration(seconds: 2));
    print('at 2s: sessions=$_logged bar=${find.byType(SnackBar).evaluate().length}');
    await tapLabel(t, RegExp('Undo'));
    print('right after Undo: sessions=$_logged bar=${find.byType(SnackBar).evaluate().length}');
    print('  text: ${paintedText(t).where((e)=>e.toLowerCase().contains("logged")||e.toLowerCase().contains("undo")).join(" | ")}');
    await t.pump(const Duration(seconds: 12));
    print('12s after Undo: sessions=$_logged bar=${find.byType(SnackBar).evaluate().length}');
    print('  Home week now: ${AppRouter.todayRepository.day.week.sessionsLogged} of ${AppRouter.todayRepository.day.week.sessionsTarget}');
    s.dispose();
  });

  testWidgets('R07 and the rest of the session', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    for (final id in ['R07','R08','R09','R10','R04','R06','R12','R13','R02']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('$id PAINTED: ${paintedText(t).join(" | ")}');
      print('$id TAPPABLE: ${tappables(t).map((e)=>e.label).join(" | ")}');
    }
    s.dispose();
  });
}
