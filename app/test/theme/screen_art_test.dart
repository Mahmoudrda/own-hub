// Every screen shows one or two illustrations, chosen for what it is for.
//
// Two layers. The table is checked on paper (every built screen covered, none
// over two, every name real). Then every screen is opened through the REAL
// router and the illustrations actually drawn are counted -- because a table
// entry that nothing renders is a promise, not an illustration.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_art.dart';
import 'package:own_hub/theme/screen_art.dart';

/// Illustrations actually rendered, as asset names.
List<String> _drawn(WidgetTester t) => t
    .widgetList<Image>(find.byType(Image))
    .map((i) => i.image)
    .whereType<AssetImage>()
    .map((a) => a.assetName)
    .where((n) => n.startsWith('assets/art/'))
    .toList();

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  group('the table', () {
    test('every name in it is a real illustration', () {
      final names = {
        ...ScreenArt.forScreen.values.expand((v) => v),
        ...ScreenArt.drawsOwnHero.values,
      };
      expect(names.difference(AppArt.all.toSet()), isEmpty);
    });

    test('no screen is given more than two', () {
      final over = ScreenArt.forScreen.entries
          .where((e) => e.value.length > 2)
          .map((e) => e.key);
      expect(over, isEmpty);
    });

    test('a hero screen is not also given a header', () {
      for (final id in ScreenArt.drawsOwnHero.keys) {
        expect(ScreenArt.headerFor(id), isEmpty, reason: id);
      }
    });
  });

  testWidgets('the detector sees a screen that has none', (tester) async {
    // Without this, "zero screens missing an illustration" could mean the
    // detector is blind rather than that every screen is covered.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('no art here'))),
    );
    expect(_drawn(tester), isEmpty);
  });

  testWidgets('every screen draws one or two illustrations when opened', (
    tester,
  ) async {
    // Every feature on, stated rather than borrowed: the subject is EVERY
    // screen, so every screen must be reachable whatever the defaults say.
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: true,
    });
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final none = <String>[];
    final tooMany = <String>[];
    final spread = <int, List<String>>{};
    for (final entry in appDestinations.entries) {
      await tester.pumpWidget(
        MaterialApp(
          // A fresh key per screen. initialRoute is read only when the
          // navigator is CREATED; without this, pumping a new MaterialApp into
          // the same slot reuses the first one, and the loop silently opens the
          // first screen every time while labelling it with each new id.
          key: ValueKey(entry.key),
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          initialRoute: entry.value.name,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      );
      await tester.pump(const Duration(milliseconds: 60));
      tester.takeException();
      // A destination with no screen built yet renders a placeholder. It is
      // not a screen to illustrate, so it is left out of the count.
      if (find.byType(NotBuiltYet).evaluate().isNotEmpty) continue;
      final n = _drawn(tester).toSet().length;
      spread.putIfAbsent(n, () => []).add(entry.key);
      if (n == 0) none.add(entry.key);
      if (n > 3) tooMany.add('${entry.key}($n)');
    }
    // ignore: avoid_print
    print('SCREENS WITH NO ILLUSTRATION (${none.length}): ${none.join(' ')}');
    // ignore: avoid_print
    print('SCREENS WITH MORE THAN THREE: ${tooMany.join(' ')}');
    for (final k in (spread.keys.toList()..sort())) {
      // ignore: avoid_print
      print('DRAWS $k: ${spread[k]!.length} screens'
          '${k >= 3 ? ' -> ${spread[k]!.join(' ')}' : ''}');
    }
    expect(none, isEmpty, reason: 'every screen should show an illustration');
  });
}
