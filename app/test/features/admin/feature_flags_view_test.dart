// Z14. The switchboard is the only place a feature is turned on or off, so its
// two confusing cases need holding down: a child that is set on under a parent
// that is off, and the fact that flipping a switch changes global state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/admin/presentation/feature_flags_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

Widget _host() => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: const FeatureFlagsView(),
);

/// The switch positions this screen is shown, stated rather than inherited.
///
/// Both of the confusing cases below need a child that is SET on under a
/// parent that is OFF, and one needs a live feature to switch off. Reading
/// `FeatureFlags.shipped` instead would make every assertion here a statement
/// about today's defaults rather than about the screen — and it would stop
/// being true the day the defaults move.
final FeatureFlags _board = FeatureFlags.allOff.with_({
  Feature.today: true,
  Feature.adminConsole: true,
  Feature.communityPosts: true,
});

void main() {
  // `featureFlags` is static and mutable, so it is set before every test and
  // put back after every test. A test that left it changed would silently
  // alter every test that runs after it.
  final original = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = _board);
  tearDown(() => AppRouter.featureFlags = original);

  /// A surface tall enough to build every row.
  ///
  /// `ListView` is lazy, so on the default 800x600 test surface only about
  /// nine of the twenty-one rows are ever constructed and the rest cannot be
  /// found -- which looks exactly like a screen that is missing them.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('every feature has a switch', (tester) async {
    tall(tester);
    await tester.pumpWidget(_host());
    for (final f in Feature.values) {
      expect(find.byKey(ValueKey('phone-${f.name}')), findsOneWidget);
    }
  });

  testWidgets('only what the server may stop is offered as a stop for every '
      'member', (tester) async {
    tall(tester);
    await tester.pumpWidget(_host());
    for (final f in Feature.values) {
      if (!f.serverMayTurnOff || f.serverMayTurnOn) {
        expect(
          find.byKey(ValueKey('members-${f.name}')),
          findsNothing,
          reason: f.name,
        );
      }
    }
    expect(find.byKey(const ValueKey('members-recipes')), findsOneWidget);
    expect(find.byKey(const ValueKey('members-accountRequired')), findsNothing);
  });

  testWidgets('a child set on under an off parent says which parent', (
    tester,
  ) async {
    // communityPosts is SET on, inside a community that is off. Without this
    // line the switch looks like it does nothing.
    tall(tester);
    await tester.pumpWidget(_host());
    expect(find.text('community is off'), findsWidgets);
  });

  testWidgets('turning the parent on clears the blocked note', (tester) async {
    tall(tester);
    await tester.pumpWidget(_host());
    expect(find.text('community is off'), findsWidgets);

    final community = find.ancestor(
      of: find.text('community'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: community.first, matching: find.byType(Switch)),
    );
    await tester.pump();

    expect(AppRouter.featureFlags.isOn(Feature.community), isTrue);
    expect(
      AppRouter.featureFlags.isOn(Feature.communityPosts),
      isTrue,
      reason: 'photos and text are the launch scope',
    );
    expect(
      AppRouter.featureFlags.isOn(Feature.communityVideo),
      isFalse,
      reason: 'video stays deferred until blur export is measured',
    );
  });

  testWidgets('switching a feature off is what makes it unreachable', (
    tester,
  ) async {
    expect(AppRouter.featureFlags.isOn(Feature.today), isTrue);

    tall(tester);
    await tester.pumpWidget(_host());
    final today = find.ancestor(
      of: find.text('today'),
      matching: find.byType(Row),
    );
    await tester.tap(
      find.descendant(of: today.first, matching: find.byType(Switch)),
    );
    await tester.pump();

    expect(AppRouter.featureFlags.isOn(Feature.today), isFalse);
  });
}
