// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-07 (the race), R1-14 (rest), R1-40 (a best she has not set), R1-08.
@Tags(['qa'])
library;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'round1_harness.dart';

int get _logged => AppRouter.todayRepository.day.week.sessionsLogged;

void main() {
  useShippingApp();
  for (final atMs in [4600, 5000, 5400]) {
    testWidgets('Undo tapped at ${atMs}ms, after the write lands', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      AppRouter.intakeRepository.markSetupDone();
      await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
      await tapLabel(t, RegExp("Legs and glutes, today's plan"));
      await t.pump(Duration(milliseconds: atMs));
      final barUp = find.byType(SnackBar).evaluate().isNotEmpty;
      final undoThere = hasLabel(t, RegExp('Undo'));
      print('at ${atMs}ms: bar=$barUp undo=$undoThere sessions=$_logged');
      if (undoThere) {
        await tapLabel(t, RegExp('Undo'));
        await t.pump(const Duration(seconds: 10));
        print('  after tapping Undo at ${atMs}ms and waiting 10s: sessions=$_logged');
      }
      s.dispose();
    });
  }

  testWidgets('R1-14 walk away from a rest', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['R09']!.name, locale: const Locale('en'));
    print('on R09: ${topScreen(t)}');
    // leave
    nav(t).pushNamed(appDestinations['E01']!.name);
    await settle(t);
    print('navigated to: ${topScreen(t)}');
    for (final s2 in [10, 20, 30, 45, 60]) {
      await t.pump(const Duration(seconds: 10));
      print('  +${s2}s: top=${topScreen(t)}');
    }
    s.dispose();
  });

  testWidgets('R1-40 does R10 claim a best she has not set', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['R10']!.name, locale: const Locale('en'));
    print('R10: ${paintedText(t).join(" | ")}');
    print('bests ledger: ${AppRouter.personalBestLedger.runtimeType}');
    await open(t, appDestinations['P03']!.name, locale: const Locale('en'));
    print('P03 right after: ${paintedText(t).join(" | ")}');
    await open(t, appDestinations['R13']!.name, locale: const Locale('en'));
    print('R13: ${paintedText(t).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-08 does any log path raise a dialog', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    final found = <String>[];
    for (final id in ['T02','T04','T05','R03','R07','R08','R12','R13','E01','E02','E03','Y04','Y09','P04']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      for (final e in tappables(t)) {
        if (!RegExp(r'log|save|done|delete|remove', caseSensitive: false).hasMatch(e.label)) continue;
        await open(t, appDestinations[id]!.name, locale: const Locale('en'));
        try { await tapLabel(t, RegExp(RegExp.escape(e.label))); } catch (_) { continue; }
        t.takeException();
        final d = find.byType(Dialog).evaluate().length + find.byType(AlertDialog).evaluate().length;
        if (d > 0) found.add('$id "${e.label}" raised a dialog');
        await t.pump(const Duration(seconds: 7));
        t.takeException();
      }
    }
    print('DIALOGS ON LOG PATHS (${found.length}): ${found.join(" | ")}');
    s.dispose();
  });
}
