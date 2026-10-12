// R1-49, the measurement that counts: a real finger on every drawn tab.
//
// The first two passes of this case used `tester.semantics.tap`, which is how
// `dead_controls_journey_test.dart` and the tap crawler tap. That method
// dispatches the action straight to the semantics node and **never hit-tests**.
// So a screen that paints a bar under a full-screen scrim passes a semantics
// tap and fails a finger: the scrim eats the pointer, not the action. Every
// existing guard in this repository taps the first way.
//
// This taps the second way, at the exact pixel where the tab's own label is
// painted, which is where a woman puts her thumb.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

import 'round1_harness.dart';
import 'r1_55_large_text_sweep_test.dart' show shippingScreens;

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('a finger on every drawn tab, $loc', (tester) async {
      phone(tester);

      final live = <String>[];
      final dead = <String>[];
      final wrong = <String>[];
      final notPainted = <String>[];

      for (final id in shippingScreens) {
        final route = appDestinations[id]!.name;
        await boot(tester, locale: Locale(loc));
        nav(tester).pushNamed(route);
        await settle(tester);
        if (tester.takeException() != null) continue;
        if (find.byType(AppNavBar).evaluate().isEmpty) continue;

        final ctx = tester.element(find.byType(AppNavBar).first);
        final barWidget = tester.widget<AppNavBar>(find.byType(AppNavBar).first);
        final l10n = AppL10n.of(ctx);
        final tabs =
            barWidget.destinations ?? tabsFor(RoleScope.rolesOf(ctx).active);

        for (final tab in tabs) {
          if (tab.screenId == 'M01') continue;
          final label = tab.label(l10n);
          await boot(tester, locale: Locale(loc));
          nav(tester).pushNamed(route);
          await settle(tester);

          final tabText = find.descendant(
            of: find.byType(AppNavBar),
            matching: find.text(label),
          );
          if (tabText.evaluate().isEmpty) {
            notPainted.add('$id  "$label"');
            continue;
          }
          final at = tester.getRect(tabText.first).center;
          final before = topScreen(tester);
          await tester.tapAt(at);
          await settle(tester);
          final err = tester.takeException();
          final after = topScreen(tester);
          if (err != null) {
            dead.add('$id  "$label" @$at  EXCEPTION ${'$err'.split('\n').first}');
          } else if (after == before && tab.screenId != id) {
            dead.add(
              '$id  "$label" painted at $at, a finger there does nothing '
              '(still on $before; the tab opens ${tab.screenId})',
            );
          } else if (after != tab.screenId && after != before) {
            wrong.add('$id  "$label" -> $after, expected ${tab.screenId}');
          } else {
            live.add('$id  "$label" -> $after');
          }
        }
      }

      // ignore: avoid_print
      print('=== $loc, FINGER TAPS ===');
      // ignore: avoid_print
      print('LIVE (${live.length})');
      // ignore: avoid_print
      print('DEAD (${dead.length}):');
      for (final d in dead) {
        // ignore: avoid_print
        print('  $d');
      }
      // ignore: avoid_print
      print('WRONG (${wrong.length}):');
      for (final d in wrong) {
        // ignore: avoid_print
        print('  $d');
      }
      // ignore: avoid_print
      print('LABEL NOT PAINTED (${notPainted.length}): ${notPainted.join("; ")}');

      expect(
        dead,
        isEmpty,
        reason: 'a bottom-nav tab is painted and a finger on it does nothing',
      );
      expect(wrong, isEmpty);
    });
  }
}
