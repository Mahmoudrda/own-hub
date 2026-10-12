// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-19, R1-20, R1-32, R1-38: log a meal, log a period, and check the numbers.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

void main() {
  useShippingApp();
  testWidgets('R1-19/R1-20 log a meal from E01 and read E04', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['E01']!.name, locale: const Locale('en'));
    final row = tappables(t).firstWhere((e) => e.label.startsWith('Koshari bowl'));
    t.semantics.tap(find.semantics.byPredicate((n) => n.id == row.id));
    await settle(t);
    print('after tapping the Koshari row: top=${topScreen(t)} snacks=${find.byType(SnackBar).evaluate().length}');
    print('  painted: ${paintedText(t).join(" | ")}');
    print('  tappable: ${tappables(t).map((e)=>e.label).join(" | ")}');
    print('  meals logged=${AppRouter.mealRepository.store.days.length}');
    await t.pump(const Duration(seconds: 7));
    print('after 7s: top=${topScreen(t)} snacks=${find.byType(SnackBar).evaluate().length} meals=${AppRouter.mealRepository.store.days.length}');
    print('  painted: ${paintedText(t).join(" | ")}');
    // now E04 and Home
    await open(t, appDestinations['E04']!.name, locale: const Locale('en'));
    print('E04 after one meal: ${paintedText(t).join(" | ")}');
    await boot(t, locale: const Locale('en'));
    print('HOME after one meal: ${paintedText(t).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-32 log a period and delete it', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['Y09']!.name, locale: const Locale('en'));
    print('Y09 tappable: ${tappables(t).map((e)=>e.label).join(" | ")}');
    await tapLabel(t, 'Save');
    print('after Save: top=${topScreen(t)} painted=${paintedText(t).take(8).join(" | ")}');
    await open(t, appDestinations['Y08']!.name, locale: const Locale('en'));
    print('Y08 after logging: ${paintedText(t).join(" | ")}');
    await open(t, appDestinations['Y10']!.name, locale: const Locale('en'));
    print('Y10 after logging: ${paintedText(t).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-38 progress after one session', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    AppRouter.todayRepository.recordSession('s1');
    for (final id in ['P01','P02','P03']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('$id after one session: ${paintedText(t).join(" | ")}');
    }
    await boot(t, locale: const Locale('en'));
    print('HOME after one session: ${paintedText(t).join(" | ")}');
    await open(t, appDestinations['R01']!.name, locale: const Locale('en'));
    print('R01 after one session: ${paintedText(t).take(6).join(" | ")}');
    s.dispose();
  });
}
