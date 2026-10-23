// ignore_for_file: avoid_print
//
// R3-10. Read the changed copy, in context, in both languages.
//
// Copy changed on R12, P04, Y11, O04 (life stage), T04, T05, T07, T02 and R10.
// A diff shows the new sentence; only the screen shows whether it still fits
// under the heading above it and beside the number next to it. T08 is here too
// because it used to render the not-built panel and now ships.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

const List<String> _changed = <String>[
  'R12',
  'P04',
  'Y11',
  'O04',
  'T04',
  'T05',
  'T07',
  'T02',
  'R10',
  'T08',
];

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('the changed screens, read end to end, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      for (final id in _changed) {
        final dest = appDestinations[id];
        if (dest == null) {
          print('=== $id $loc: NOT IN appDestinations ===');
          continue;
        }
        await boot(t, locale: Locale(loc));
        nav(t).pushNamed(dest.name);
        await settle(t);
        final err = t.takeException();
        print(
          '=== $id $loc  top=${topScreen(t)}  '
          '${err == null ? "" : "THREW ${'$err'.split('\n').first}"} ===',
        );
        for (final line in paintedText(t)) {
          print('  | $line');
        }
        print('  CONTROLS: ${tappables(t).map((e) => e.label).join(" // ")}');
      }
      s.dispose();
    });
  }

  // T08 specifically: it is the finished state of the first week. Walk it as a
  // woman who has finished, and as one who has not.
  for (final loc in <String>['en', 'ar']) {
    testWidgets('T08 for a woman who has done nothing, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations['T08']!.name, locale: Locale(loc));
      final t08 = paintedText(t);
      await open(t, appDestinations['T07']!.name, locale: Locale(loc));
      final t07 = paintedText(t);
      print('=== R3-10 T08 vs T07, $loc ===');
      print('  identical? ${t08.join("|") == t07.join("|")}');
      print('  T08 only: ${t08.where((e) => !t07.contains(e)).join(" // ")}');
      print('  T07 only: ${t07.where((e) => !t08.contains(e)).join(" // ")}');

      // The thing a not-built panel says, in either language.
      for (final tell in <String>[
        'not built',
        'Not built',
        'placeholder',
        'coming soon',
        'لم يُبنَ',
        'قريبًا',
      ]) {
        expect(
          t08.any((line) => line.contains(tell)),
          isFalse,
          reason: 'T08 still says "$tell"',
        );
      }
      s.dispose();
    });
  }
}
