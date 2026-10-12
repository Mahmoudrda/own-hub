// R1-52 / R1-51 / R1-53 / R1-63: every control on every shipping screen,
// tapped once, at the shipping flag set, with the real fonts in.
//
// The method is the tap crawler's, with three changes:
//
//  1. the flags are the six the first release ships, not every feature on;
//  2. **the skip list is gone.** The original skips every bottom-nav label on
//     every screen but two, which is why "1,102 taps, zero exceptions" says
//     nothing about the tabs. R1-49 measures those separately with a finger;
//     here they are simply crawled like anything else;
//  3. every string rendered on every screen is collected, so R1-63 ("nothing
//     on a shipping screen mentions a dark feature") is answered by reading
//     what is actually drawn rather than by reading a guard.
@Tags(['qa'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import 'round1_harness.dart';
import 'r1_55_large_text_sweep_test.dart' show shippingScreens;

/// What the page says and what is selected on it, so "nothing changed" is a
/// measurement rather than an impression.
String _state(WidgetTester t) {
  final out = StringBuffer();
  for (final n in find.semantics.byPredicate((_) => true).evaluate()) {
    final d = n.getSemanticsData();
    out
      ..write(d.label)
      ..write('|')
      ..write(d.value)
      ..write(d.flagsCollection.isSelected)
      ..write(d.flagsCollection.isToggled)
      ..write(d.flagsCollection.isChecked)
      ..write(';');
  }
  return out.toString();
}

/// Words that name something this release has switched off.
const Map<String, List<String>> darkWords = <String, List<String>>{
  'en': <String>[
    'coach', 'community', 'follower', 'assistant', 'earnings', 'payment',
    'subscribe', 'verified', 'verification', 'reviewer', 'group chat',
    'marketplace', 'premium', 'upgrade', 'pay ',
  ],
  'ar': <String>[
    'مدرب', 'مدرّب', 'المجتمع', 'متابع', 'المساعد', 'الأرباح', 'ادفعي',
    'اشتراك', 'موثّق', 'التحقق', 'مراجعة', 'السوق',
  ],
};

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('crawl the shipping surface, $loc', (tester) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      final log = StringBuffer();
      final hard = <String>[];
      final inert = <String>[];
      final darkMentions = <String>[];
      var taps = 0;

      for (final id in shippingScreens) {
        final route = appDestinations[id]!.name;
        if (!await open(tester, route, locale: Locale(loc))) {
          hard.add('$id OPEN threw');
          continue;
        }

        // R1-63: read everything the screen says.
        for (final s in paintedText(tester)) {
          for (final w in darkWords[loc]!) {
            if (s.toLowerCase().contains(w)) {
              darkMentions.add('$id\t$w\t$s');
            }
          }
        }

        final count =
            find.semantics.byAction(SemanticsAction.tap).evaluate().length;
        log.writeln('$id\t—\tSCREEN\t$count tappable');

        for (var i = 0; i < count; i++) {
          await open(tester, route, locale: Locale(loc));
          final nodes =
              find.semantics.byAction(SemanticsAction.tap).evaluate().toList();
          if (i >= nodes.length) break;
          final node = nodes[i];
          final d = node.getSemanticsData();
          final label = <String>[d.label, d.tooltip, d.hint]
              .where((s) => s.trim().isNotEmpty)
              .join(' / ')
              .replaceAll('\n', ' ');
          if (d.flagsCollection.isTextField) {
            log.writeln('$id\t$i\tFIELD\t$label');
            continue;
          }
          final topBefore = topScreen(tester);
          final stateBefore = _state(tester);
          String outcome;
          taps++;
          try {
            tester.semantics
                .tap(find.semantics.byPredicate((n) => n.id == node.id));
            await tester.pump();
            await settle(tester);
            final err = tester.takeException();
            final topAfter = topScreen(tester);
            if (err != null) {
              outcome = 'EXCEPTION\t${'$err'.split('\n').first}';
            } else if (find.byType(NotBuiltYet).evaluate().isNotEmpty) {
              outcome = 'NOT-BUILT';
            } else if (find.byType(FeatureOff).evaluate().isNotEmpty) {
              outcome = 'FEATURE-OFF';
            } else if (find.byType(BottomSheet).evaluate().isNotEmpty) {
              outcome = 'SHEET';
            } else if (find.byType(Dialog).evaluate().isNotEmpty ||
                find.byType(AlertDialog).evaluate().isNotEmpty) {
              outcome = 'DIALOG';
            } else if (topAfter != topBefore) {
              outcome = 'NAV\t$topAfter';
            } else if (find.byType(SnackBar).evaluate().isNotEmpty) {
              outcome = 'SNACK';
            } else {
              outcome = _state(tester) == stateBefore
                  ? 'NO-VISIBLE-EFFECT'
                  : 'CHANGED';
            }
          } catch (e) {
            outcome = 'EXCEPTION\t${'$e'.split('\n').first}';
          }
          await tester.pump(const Duration(seconds: 7));
          tester.takeException();
          if (outcome.startsWith('EXCEPTION') || outcome.startsWith('NOT-BUILT')) {
            hard.add('$id [$label] $outcome');
          }
          if (outcome == 'NO-VISIBLE-EFFECT') {
            inert.add('$id\t$label');
          }
          log.writeln('$id\t$i\t$outcome\t$label');
        }
      }

      final out = Platform.environment['OWNHUB_QA_REPORT'];
      if (out != null) File('$out.$loc.tsv').writeAsStringSync(log.toString());

      // ignore: avoid_print
      print('=== $loc: $taps taps over ${shippingScreens.length} screens ===');
      // ignore: avoid_print
      print('EXCEPTIONS OR PLACEHOLDERS (${hard.length}):');
      for (final h in hard) {
        // ignore: avoid_print
        print('  $h');
      }
      // ignore: avoid_print
      print('NO VISIBLE EFFECT (${inert.length}):');
      for (final h in inert) {
        // ignore: avoid_print
        print('  $h');
      }
      // ignore: avoid_print
      print('DARK-FEATURE MENTIONS (${darkMentions.length}):');
      for (final h in darkMentions.toSet()) {
        // ignore: avoid_print
        print('  $h');
      }

      expect(hard, isEmpty, reason: 'an exception or a placeholder');
      semantics.dispose();
    });
  }
}
