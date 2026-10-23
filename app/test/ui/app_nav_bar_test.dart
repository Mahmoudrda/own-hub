// The bottom navigation.
//
// This is the surface the product's "everything is two taps away" goal is
// measured from, and the one widget that appears on most screens — so a mistake
// here is a mistake almost everywhere. Worth testing properly rather than
// assuming.
//
// Since D11 the bar also follows her active role, which makes it the place a
// role switch either works or visibly does not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  ValueNotifier<UserRoles>? roles,
}) {
  final app = MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: Scaffold(
      bottomNavigationBar: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
  return roles == null ? app : RoleScope(notifier: roles, child: app);
}

void main() {
  // The bar hides a tab whose feature is off, and the first release ships
  // without the community. This file is about the bar's own behaviour, so it
  // states the world it wants rather than inheriting one that will move again.
  final savedFlags = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('a woman sees her five destinations', () {
    testWidgets('all five, labelled, in order', (tester) async {
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'R01')));
      await tester.pumpAndSettle();

      for (final label in ['Home', 'Train', 'Eat', 'Community', 'Insights']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(traineeTabs.length, 5);
      expect(
        [for (final t in traineeTabs) t.screenId],
        ['T01', 'R01', 'E01', 'M01', 'P01'],
      );
      // Left to right in the order of the list.
      final xs = [
        for (final label in ['Home', 'Train', 'Eat', 'Community', 'Insights'])
          tester.getCenter(find.text(label)).dx,
      ];
      expect(xs, [...xs]..sort());
    });

    testWidgets('Events takes the community\'s slot while it is dark', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.everything.with_({
        Feature.community: false,
      });
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'T01')));
      await tester.pumpAndSettle();

      expect(
        [for (final t in tabsFor(AppRole.trainee)) t.screenId],
        ['T01', 'R01', 'E01', 'T09', 'P01'],
      );
      expect(find.text('Events'), findsOneWidget);
      expect(find.text('Community'), findsNothing);
    });

    testWidgets('there is no floating Log food button', (tester) async {
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'T01')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-log-food')), findsNothing);
      expect(find.text('Log food'), findsNothing);
    });

    testWidgets('Coaching is not one of them', (tester) async {
      // D11. The fifth tab pointed at H01 — "Find a coach" — which is a
      // trainee feature and is still in the product, reachable from her
      // profile. What left the bar is the tab, not the capability. This
      // assertion is the guard against someone restoring the tab because a
      // trainee "obviously needs a way to find a coach".
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'T01')));
      await tester.pumpAndSettle();

      expect(find.text('Coaching'), findsNothing);
      expect(traineeTabs.any((t) => t.screenId == 'H01'), isFalse);
    });

    testWidgets('labelled in Arabic too', (tester) async {
      await tester.pumpWidget(
        _host(
          const AppNavBar(activeScreenId: 'R01'),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // Tab labels are translated like everything else — a nav bar stuck in
      // English is a very visible way to bypass the dictionary.
      expect(find.text('التمرين'), findsOneWidget);
      expect(find.text('المجتمع'), findsOneWidget);
      expect(find.text('إحصائياتك'), findsOneWidget);
      expect(find.text('Train'), findsNothing);
    });
  });

  group('the bar follows her active role', () {
    test('each role maps to exactly one bar', () {
      // Contents, not identity: the bar filters out anything switched off, so
      // it returns a fresh list rather than the canonical one.
      expect(tabsFor(AppRole.trainee), equals(traineeTabs));
      expect(tabsFor(AppRole.coach), equals(coachTabs));
    });

    testWidgets('with no scope at all it falls back to the trainee bar', (
      tester,
    ) async {
      // Screens render standalone in tests and in the design gallery. That
      // must not blow up, and must not silently show a coach a client bar.
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'T01')));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Clients'), findsNothing);
    });

    testWidgets(
      'a coach account gets the coach bar without any screen asking',
      (tester) async {
        final roles = ValueNotifier(UserRoles.coach);
        addTearDown(roles.dispose);

        await tester.pumpWidget(
          _host(const AppNavBar(activeScreenId: 'K07'), roles: roles),
        );
        await tester.pumpAndSettle();

        expect(find.text('Clients'), findsOneWidget);
        expect(find.text('Community'), findsNothing);
      },
    );

    testWidgets('switching role swaps the bar in place', (tester) async {
      // The whole point of resolving from the scope rather than from nine
      // screens: one switch, and every screen showing this bar is correct.
      final roles = ValueNotifier(UserRoles.both);
      addTearDown(roles.dispose);

      await tester.pumpWidget(
        _host(const AppNavBar(activeScreenId: 'T01'), roles: roles),
      );
      await tester.pumpAndSettle();
      expect(find.text('Eat'), findsOneWidget);
      expect(find.text('Earnings'), findsNothing);

      roles.value = roles.value.switched();
      await tester.pumpAndSettle();

      expect(find.text('Earnings'), findsOneWidget);
      expect(find.text('Eat'), findsNothing);
    });
  });

  group('the active tab', () {
    testWidgets('is marked, and is not a link to itself', (tester) async {
      var selected = <String>[];
      await tester.pumpWidget(
        _host(AppNavBar(activeScreenId: 'R01', onSelect: selected.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Train'));
      await tester.pumpAndSettle();
      expect(selected, isEmpty, reason: 'tapping the current tab does nothing');

      await tester.tap(find.text('Eat'));
      await tester.pumpAndSettle();
      expect(selected, ['E01']);

      await tester.tap(find.text('Insights'));
      await tester.pumpAndSettle();
      expect(selected, ['E01', 'P01']);
    });

    testWidgets('reports its selected state to assistive technology', (
      tester,
    ) async {
      // Colour alone is not a reliable signal, so the selected state must be
      // announced and not merely drawn.
      //
      // Deliberately matched by PROPERTY rather than by position. There are a
      // dozen Semantics ancestors above a tab label and ours is somewhere in
      // the middle, so `.first`/`.last` pick a framework wrapper — an earlier
      // version of this test did exactly that, landed on the root node covering
      // the whole screen, and failed while the widget was correct. Matching the
      // node that actually declares `selected` also survives Flutter adding or
      // removing wrappers.
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'T01')));
      await tester.pumpAndSettle();

      bool? declaredSelection(String label) {
        final nodes = find
            .ancestor(of: find.text(label), matching: find.byType(Semantics))
            .evaluate()
            .map((e) => (e.widget as Semantics).properties)
            .where((p) => p.selected != null);
        return nodes.isEmpty ? null : nodes.first.selected;
      }

      expect(
        declaredSelection('Home'),
        isTrue,
        reason: 'the current tab must announce itself as selected',
      );
      expect(
        declaredSelection('Eat'),
        isFalse,
        reason: 'and the others must announce that they are not',
      );
    });

    testWidgets('navigates by screen id, not by route string', (tester) async {
      final selected = <String>[];
      await tester.pumpWidget(
        _host(AppNavBar(activeScreenId: 'T01', onSelect: selected.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Community'));
      await tester.pumpAndSettle();
      expect(
        selected,
        ['M01'],
        reason:
            'screens are identified the same way in the design, the '
            'plans and the code',
      );
    });
  });

  group('a coach sees hers', () {
    testWidgets('four destinations, and none of the trainee ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const AppNavBar(activeScreenId: 'K07', destinations: coachTabs)),
      );
      await tester.pumpAndSettle();

      expect(coachTabs.length, 4);
      for (final label in ['Today', 'Clients', 'Chats', 'Earnings']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      // A coach does not get the trainee tabs.
      expect(find.text('Community'), findsNothing);
    });
  });

  group('the Eat tab', () {
    testWidgets('is a normal tab that wears a quiet chip until it is open', (
      tester,
    ) async {
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'T01')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-tab-emphasis')), findsOneWidget);
      expect(traineeTabs.where((t) => t.emphasis).map((t) => t.screenId), [
        'E01',
      ]);

      // Open, it takes the marker like every other tab and the chip goes.
      await tester.pumpWidget(_host(const AppNavBar(activeScreenId: 'E01')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-tab-emphasis')), findsNothing);
    });

    testWidgets('a coach does not get it', (tester) async {
      await tester.pumpWidget(
        _host(const AppNavBar(activeScreenId: 'K07', destinations: coachTabs)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('nav-tab-emphasis')), findsNothing);
    });

    testWidgets('in Arabic at the largest text size five tabs fit', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AppNavBar(activeScreenId: 'T01'),
          locale: const Locale('ar'),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('الأكل'), findsOneWidget);
      expect(find.text('إحصائياتك'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('survives the largest system text size in Arabic', (
    tester,
  ) async {
    // Five labels across a phone width, and Arabic labels are longer.
    await tester.pumpWidget(
      _host(
        const AppNavBar(activeScreenId: 'T01'),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
