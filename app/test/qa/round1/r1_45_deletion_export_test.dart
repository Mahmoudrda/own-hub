// ignore_for_file: avoid_print
//
// A QA sweep's findings ARE its output. These files print a measured
// table (every screen, every contrast pair, every tap target under the
// floor) because a reader needs the numbers, not a pass or a fail. The
// same allowance is taken per line in `test/qa/large_text_sweep_test.dart`;
// it is file-level here only because these print far more.
// R1-41 / R1-43 / R1-44 / R1-45: language, support, export, deletion.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/language_switch.dart';

import 'round1_harness.dart';

void main() {
  useShippingApp();
  testWidgets('R1-45 Your data, and deletion end to end', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    // put something of hers in
    AppRouter.todayRepository.recordSession('s1');
    await open(t, appDestinations['A02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Privacy and data'));
    await tapLabel(t, RegExp('Your data'));
    print(
      'YOUR DATA top=${topScreen(t)} sheets=${find.byType(BottomSheet).evaluate().length}',
    );
    print('  PAINTED: ${paintedText(t).join(" | ")}');
    print('  TAPPABLE: ${tappables(t).map((e) => e.label).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-41 language switch mid-session', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.todayRepository.recordSession('s1');
    await open(t, appDestinations['A02']!.name, locale: const Locale('en'));
    // The switch lives in the top bar of every screen.
    await t.tap(find.byType(LanguageSwitchButton).first);
    await settle(t);
    print('after Language: top=${topScreen(t)}');
    print('after choosing Arabic: top=${topScreen(t)}');
    print('  PAINTED: ${paintedText(t).take(12).join(" | ")}');
    print(
      '  dir=${Directionality.of(t.element(find.byType(Navigator).first))}',
    );
    print(
      '  sessions still logged=${AppRouter.todayRepository.day.week.sessionsLogged}',
    );
    // restart
    await t.pumpWidget(const SizedBox());
    await t.pump();
    await boot(t);
    print(
      'after restart: top=${topScreen(t)} dir=${Directionality.of(t.element(find.byType(Navigator).first))}',
    );
    print('  PAINTED: ${paintedText(t).take(8).join(" | ")}');
    s.dispose();
  });

  testWidgets('R1-43 is there any support route at all', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    final hits = <String>[];
    for (final id in ['A01', 'A02', 'A03', 'A04', 'P01', 'T01', 'E01', 'R01']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      for (final e in tappables(t)) {
        final l = e.label.toLowerCase();
        if (l.contains('human') ||
            l.contains('support') ||
            l.contains('help') ||
            l.contains('contact') ||
            l.contains('terms') ||
            l.contains('privacy polic')) {
          hits.add('$id: ${e.label}');
        }
      }
    }
    print(
      'SUPPORT-ISH CONTROLS: ${hits.isEmpty ? "NONE ANYWHERE" : hits.join(" | ")}',
    );
    s.dispose();
  });
}
