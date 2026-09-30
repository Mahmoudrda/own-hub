// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-07, R1-12, R1-13, R1-45: a whole session, the undo bar, and deletion.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

int get _logged => AppRouter.todayRepository.day.week.sessionsLogged;

void main() {
  useShippingApp();

  testWidgets('R1-45 delete everything', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.todayRepository.recordSession('s1');
    AppRouter.intakeRepository.markSetupDone();
    print('before: sessions=$_logged setupDone=${AppRouter.intakeRepository.setupDone}');
    await open(t, appDestinations['A02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Your data'));
    await tapLabel(t, 'Delete everything');
    print('after delete: top=${topScreen(t)} sessions=$_logged setupDone=${AppRouter.intakeRepository.setupDone}');
    print('  PAINTED: ${paintedText(t).take(10).join(" | ")}');
    // restart
    await t.pumpWidget(const SizedBox()); await t.pump();
    await boot(t);
    print('after restart: top=${topScreen(t)} sessions=$_logged');
    print('  PAINTED: ${paintedText(t).take(8).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-07 log I already did it, and undo', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    print('before: sessions=$_logged');
    await tapLabel(t, RegExp("Legs and glutes, today's plan"));
    print('after tapping the plan row: sessions=$_logged snack=${find.byType(SnackBar).evaluate().length}');
    print('  bar text: ${paintedText(t).where((e)=>e.toLowerCase().contains("undo")||e.toLowerCase().contains("logged")||e.toLowerCase().contains("saved")).join(" | ")}');
    print('  tappable: ${tappables(t).map((e)=>e.label).join(" | ")}');
    if (hasLabel(t, RegExp('Undo'))) {
      await tapLabel(t, RegExp('Undo'));
      print('after undo: sessions=$_logged');
      print('  painted: ${paintedText(t).where((e)=>e.toLowerCase().contains("undo")||e.toLowerCase().contains("logged")).join(" | ")}');
    }
    s.dispose();
  });

  testWidgets('R1-07b the undo bar closes by itself', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp("Legs and glutes, today's plan"));
    for (final secs in [1, 3, 5, 6, 8]) {
      await t.pump(const Duration(seconds: 1));
      print('  t=${secs}s snackbars=${find.byType(SnackBar).evaluate().length} sessions=$_logged');
    }
    s.dispose();
  });

  testWidgets('R1-12/R1-13 a whole session', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['R03']!.name, locale: const Locale('en'));
    print('R03 PAINTED: ${paintedText(t).join(" | ")}');
    print('R03 TAPPABLE: ${tappables(t).map((e)=>e.label).join(" | ")}');
    for (var step = 0; step < 14; step++) {
      final before = topScreen(t);
      final labels = tappables(t).map((e)=>e.label).toList();
      final next = labels.firstWhere(
        (l) => RegExp(r'Start|Log|Next|Done|Finish|Continue|Save|Rest|Skip', caseSensitive: false).hasMatch(l),
        orElse: () => '');
      if (next.isEmpty) { print('step $step: on $before, nothing to advance: $labels'); break; }
      // `tapControl`, not `tapLabel`: `next` comes off `tappables`, which
      // flattens a label's newlines to spaces for printing. R07's button is one
      // label reading "Done · 12 reps\nRest starts itself", so a regex built
      // from the printed form never matched the real one and the walk stopped
      // at step 1. `tapControl` compares against the same flattened form.
      if (!await tapControl(t, RegExp(RegExp.escape(next)))) {
        print('step $step: on $before, "$next" could not be activated');
        break;
      }
      print('step $step: $before --"$next"--> ${topScreen(t)}  sessions=$_logged');
      if (topScreen(t) == 'R10') {
        print('R10 PAINTED: ${paintedText(t).join(" | ")}');
        break;
      }
    }
    print('END sessions=$_logged');
    s.dispose();
  });
}
