// ignore_for_file: avoid_print
//
// R3-08. T02 is "I already did it": four duration chips and a Save. It is the
// only way a woman logs a session she did without her phone. This puts a real
// finger on each chip at the pixel where its own label is painted — the way
// `r1_49d_tabs_finger_test.dart` taps, with `tester.getRect` on the painted
// `Text`, not with a semantics rect, which is expressed relative to the parent
// node and is not a screen coordinate.
//
// The same walk on T05 and R05, because all three carry the same scrim.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

Future<String?> _fingerOn(
  WidgetTester t,
  String screen,
  String label,
  Locale locale,
) async {
  await open(t, appDestinations[screen]!.name, locale: locale);
  final f = find.text(label);
  if (f.evaluate().isEmpty) return '(not painted)';
  final at = t.getRect(f.first).center;
  await t.tapAt(at);
  await settle(t);
  final err = t.takeException();
  if (err != null) return 'EXCEPTION ${'$err'.split('\n').first}';
  return '${topScreen(t)}  @$at';
}

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('T02: a finger on each duration chip and Save, $loc', (
      t,
    ) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations['T02']!.name, locale: Locale(loc));
      final painted = paintedText(t);
      print('=== R3-08 T02 $loc painted ===');
      for (final p in painted) {
        print('  | $p');
      }

      final chips = loc == 'en'
          ? <String>['20 min', '30 min', '45 min', '1 hour', 'Save']
          : <String>['20 دقيقة', '30 دقيقة', '45 دقيقة', 'ساعة', 'احفظي'];

      for (final chip in chips) {
        final where = await _fingerOn(t, 'T02', chip, Locale(loc));
        print('  FINGER on "$chip" -> $where');
      }

      // Then the real sequence: pick 30, then Save.
      await open(t, appDestinations['T02']!.name, locale: Locale(loc));
      final thirty = find.text(loc == 'en' ? '30 min' : '30 دقيقة');
      if (thirty.evaluate().isNotEmpty) {
        await t.tapAt(t.getRect(thirty.first).center);
        await settle(t);
        t.takeException();
        print('  after tapping 30: on ${topScreen(t)}');
        final save = find.text(loc == 'en' ? 'Save' : 'احفظي');
        if (save.evaluate().isNotEmpty) {
          await t.tapAt(t.getRect(save.first).center);
          await settle(t);
          t.takeException();
          print('  after Save: on ${topScreen(t)}');
        } else {
          print('  Save is no longer painted after picking 30');
        }
        final week = AppRouter.todayRepository.day.week;
        final prog = AppRouter.progressStore.weeks.values.fold<int>(
          0,
          (a, w) => a + w.sessionsLogged,
        );
        print(
          '  today week = ${week.sessionsLogged} of ${week.sessionsTarget},'
          ' progress sessions = $prog',
        );
      }
      s.dispose();
    });
  }

  // The scrim's own job: does tapping it still close the sheet?
  for (final loc in <String>['en', 'ar']) {
    testWidgets('the scrim still dismisses, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      for (final id in <String>['T02', 'T05', 'R05']) {
        await open(t, appDestinations[id]!.name, locale: Locale(loc));
        final before = topScreen(t);
        // Top-left corner of the content area, well clear of every control and
        // of the top bar: where a woman taps to mean "not this".
        await t.tapAt(const Offset(195, 120));
        await settle(t);
        t.takeException();
        print(
          '=== R3-08 scrim tap on $id $loc: $before -> ${topScreen(t)} '
          '(sheet still up? '
          '${find.text(loc == "en" ? "Save" : "احفظي").evaluate().isNotEmpty}) ===',
        );
      }
      s.dispose();
    });
  }
}
