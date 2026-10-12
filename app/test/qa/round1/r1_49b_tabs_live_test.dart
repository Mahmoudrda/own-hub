// R1-49 / R1-50, precisely. See r1_49_tabs_live_test.dart for why this case
// exists at all.
//
// The refinement over the first pass: a tab is located **geometrically**, by
// finding the semantics node whose centre falls inside the AppNavBar's own
// painted rectangle. That removes two sources of noise — a page title that
// happens to share a tab's word ("Train" on R01), and an active tab that may
// not carry a tap action — and it answers the only question that matters: if a
// woman puts her finger on that word at the foot of this screen, does anything
// happen?
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

import 'round1_harness.dart';
import 'r1_55_large_text_sweep_test.dart' show shippingScreens;

/// The bar's own rectangle in global coordinates.
Rect _barRect(WidgetTester t) => t.getRect(find.byType(AppNavBar).first);

/// The semantics node that carries [label] and sits inside the bar, if any.
SemanticsNode? _tabNode(WidgetTester t, String label, Rect bar) {
  for (final n in find.semantics.byPredicate((_) => true).evaluate()) {
    final d = n.getSemanticsData();
    if (d.label.trim() != label.trim()) continue;
    final r = MatrixUtils.transformRect(
      n.transform ?? Matrix4.identity(),
      n.rect,
    );
    // A semantics node's own transform is relative to its parent, so walk the
    // ancestors to get a global rectangle.
    var rect = n.rect;
    SemanticsNode? cur = n;
    while (cur != null) {
      rect = MatrixUtils.transformRect(cur.transform ?? Matrix4.identity(), rect);
      cur = cur.parent;
    }
    if (bar.contains(rect.center) || bar.contains(r.center)) return n;
  }
  return null;
}

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('every drawn tab is live, $loc', (tester) async {
      phone(tester);
      final semantics = tester.ensureSemantics();

      final results = <String>[];
      final dead = <String>[];
      final wrong = <String>[];
      final community = <String>[];

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
          final label = tab.label(l10n);
          if (tab.screenId == 'M01') {
            community.add('$id draws a Community tab labelled "$label"');
            continue;
          }
          await boot(tester, locale: Locale(loc));
          nav(tester).pushNamed(route);
          await settle(tester);
          final bar = _barRect(tester);
          final node = _tabNode(tester, label, bar);
          if (node == null) {
            dead.add(
              '$id  "$label"  the bar is painted at $bar but no semantics '
              'node with that label sits inside it',
            );
            continue;
          }
          final data = node.getSemanticsData();
          final hasTap = data.hasAction(SemanticsAction.tap);
          final before = topScreen(tester);
          if (!hasTap) {
            // A tab that is already the screen she is on carries no tap action
            // in some designs. Record it and say which screen it was.
            results.add(
              '$id  "$label"  NO TAP ACTION (tab owns ${tab.screenId}, '
              'she is on $before)',
            );
            if (tab.screenId != id) {
              dead.add(
                '$id  "$label"  drawn in the bar with no tap action, and it '
                'is not this screen\'s own tab (it opens ${tab.screenId})',
              );
            }
            continue;
          }
          try {
            tester.semantics.tap(
              find.semantics.byPredicate((n) => n.id == node.id),
            );
          } catch (e) {
            dead.add('$id  "$label"  tap threw: ${'$e'.split('\n').first}');
            continue;
          }
          await settle(tester);
          final err = tester.takeException();
          if (err != null) {
            dead.add('$id  "$label"  EXCEPTION ${'$err'.split('\n').first}');
            continue;
          }
          final after = topScreen(tester);
          results.add('$id  "$label"  -> $after');
          if (after == before && before != tab.screenId) {
            dead.add('$id  "$label"  nothing happened (still on $before)');
          } else if (after != tab.screenId) {
            wrong.add('$id  "$label"  -> $after, expected ${tab.screenId}');
          }
        }
      }

      // ignore: avoid_print
      print('=== $loc: every tab tap ===');
      for (final r in results) {
        // ignore: avoid_print
        print('  $r');
      }
      // ignore: avoid_print
      print('DEAD (${dead.length}):');
      for (final d in dead) {
        // ignore: avoid_print
        print('  $d');
      }
      // ignore: avoid_print
      print('WRONG DESTINATION (${wrong.length}):');
      for (final d in wrong) {
        // ignore: avoid_print
        print('  $d');
      }
      // ignore: avoid_print
      print('COMMUNITY TAB (${community.length}): ${community.join("; ")}');

      expect(dead, isEmpty, reason: 'a drawn tab is not live');
      expect(wrong, isEmpty, reason: 'a tab went to the wrong screen');
      expect(community, isEmpty, reason: 'Community is dark');
      semantics.dispose();
    });
  }
}
