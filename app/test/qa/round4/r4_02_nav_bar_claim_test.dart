// R4-02. A screen that tells the bar it is a tab it is not.
//
// `AppNavBar` marks a tab active when `tab.screenId == activeScreenId`, and
// `app_nav_bar.dart:186-189` then gives that tab **no onTap**: "the active tab
// is not a link to itself". So a screen that names someone else's tab paints
// that tab as current and kills it in the same stroke, and the woman standing
// on it has one fewer way out than the bar shows her.
//
// `look_around_view.dart` used to do exactly this — `AppNavBar(activeScreenId:
// 'R01')` on C04 and C05, which were the "look around first" and "join to
// save this" screens, not Train. Round three raised it; this case establishes
// the blast radius, which is the thing that decides whether it blocks a
// launch. C04 is now the tour, and it draws each real screen with its own
// bar, so the claim is true there.
//
// Two cases, on purpose:
//   * at the SHIPPING flag set, which is the app a woman installs. Must be
//     empty.
//   * with everything on, which is the app a later release becomes. Reports,
//     and pins the known offenders so a new one is visible.

@Tags(['qa'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

import '../round1/round1_harness.dart';

/// Every tab id either bar can draw. A claim on one of these is the defect;
/// `activeScreenId: 'P04'` on P04 is not, because no tab owns P04 and the bar
/// simply draws nothing active.
final Set<String> _tabRoots = {
  for (final t in traineeTabs) t.screenId,
  for (final t in coachTabs) t.screenId,
};

/// The routes whose bar claims a tab they are not, at whatever flags are set.
Future<List<String>> _liars(WidgetTester t) async {
  final out = <String>[];
  for (final entry in appDestinations.entries) {
    await boot(t);
    try {
      nav(t).pushNamed(entry.value.name);
      await settle(t);
      if (t.takeException() != null) continue;
    } catch (_) {
      continue;
    }
    final bars = t.widgetList<AppNavBar>(find.byType(AppNavBar));
    for (final bar in bars) {
      final claimed = bar.activeScreenId;
      if (!_tabRoots.contains(claimed)) continue;
      final on = topScreen(t);
      if (on == claimed) continue;
      out.add(
        '${entry.key} (on screen $on) claims tab $claimed'
        '${bar.onSelect == null ? ', and passes no onSelect' : ''}',
      );
    }
  }
  return out;
}

void main() {
  group('at the shipping flag set', () {
    useShippingApp();

    testWidgets('no screen a woman can reach claims a tab it is not', (
      t,
    ) async {
      phone(t);
      final liars = await _liars(t);
      // ignore: avoid_print
      print('R4-02 shipping: ${liars.length} liars');
      for (final l in liars) {
        // ignore: avoid_print
        print('  $l');
      }
      expect(liars, isEmpty, reason: liars.join('\n'));
    });
  });

  group('with every feature on', () {
    late FeatureFlags saved;
    setUp(() {
      saved = AppRouter.featureFlags;
      AppRouter.featureFlags = FeatureFlags.everything;
      wipe();
    });
    tearDown(() {
      wipe();
      AppRouter.featureFlags = saved;
    });

    testWidgets('seventeen dark screens do it, and this is the whole list', (
      t,
    ) async {
      phone(t);
      final liars = await _liars(t);
      // ignore: avoid_print
      print('R4-02 all-on: ${liars.length} liars');
      for (final l in liars) {
        // ignore: avoid_print
        print('  $l');
      }
      // Reported, not tolerated. Every one of these is behind a dark flag
      // today, so none of them can reach a woman in this release; the list is
      // pinned so that an eighteenth — or a shipping one — cannot arrive
      // quietly. The shipping case above is the one that blocks.
      //
      // C04 and C05 left the list when the look-around page became the tour.
      // Each stop is the real screen inside its own `ScreenScope`, so the bar
      // on the Home stop claims Home on a screen that is Home, and the tour
      // maps its tabs to its own stops rather than to routes.
      expect(
        liars.map((l) => l.split(' ').first).toSet(),
        {
          'C14',
          'G03', 'G04', 'G05', 'G11', 'G16',
          'M03', 'M04', 'M05', 'M07', 'M09', 'M10', 'M12', 'M14', 'M15',
          'W02', 'K19',
        },
        reason: liars.join('\n'),
      );
    });
  });
}
