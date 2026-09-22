// D25. The switchboard only means something if a route consults it.
//
// Before this existed, `AppRouter.featureFlags` was a claim with no mechanism:
// every Phase 3 screen was one deep link away from a woman the moment it
// compiled. These tests hold the mechanism in place.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

void main() {
  // `featureFlags` is static and mutable. A test that leaves it changed would
  // silently alter every test that runs after it.
  final original = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = original);

  group('every flow makes an explicit decision', () {
    test('no flow in the route table is missing from the switchboard', () {
      final flows = appRoutes.values.map((r) => r.flow).toSet();
      for (final flow in flows) {
        expect(
          AppRouter.decidedFlows,
          contains(flow),
          reason:
              "flow '$flow' has no gating decision. A flow that is forgotten "
              'becomes ungated by default, which is how an unfinished feature '
              'reaches a woman.',
        );
      }
    });

    test('the switchboard lists no flow that no longer exists', () {
      final flows = appRoutes.values.map((r) => r.flow).toSet();
      for (final decided in AppRouter.decidedFlows) {
        expect(flows, contains(decided), reason: '$decided is stale');
      }
    });
  });

  group('two flows are never gated, deliberately', () {
    test('account is ungated so she can always leave', () {
      // Her export, the privacy centre and account deletion live here. PDPL
      // erasure is not a feature to toggle, and a flag flip must never trap a
      // woman inside an app she cannot get out of.
      expect(AppRouter.featureForFlow('account'), isNull);
    });

    test('onboarding is ungated so nobody is stranded half-registered', () {
      expect(AppRouter.featureForFlow('onboarding'), isNull);
    });
  });

  group('the shipped defaults match what is actually finished', () {
    test('Phase 1 and 2 flows are reachable', () {
      for (final flow in ['signup', 'today', 'train', 'eat', 'progress',
                          'cycle', 'admin']) {
        final f = AppRouter.featureForFlow(flow);
        expect(f, isNotNull, reason: flow);
        expect(
          FeatureFlags.shipped.isOn(f!),
          isTrue,
          reason: '$flow is built and tested; it should not be dark',
        );
      }
    });

    test("every Phase 3 flow is reachable, at the owner's instruction", () {
      for (final flow in ['community', 'coach', 'coachplan', 'coachbrand',
                          'coached', 'coaching', 'assistant']) {
        final f = AppRouter.featureForFlow(flow);
        expect(f, isNotNull, reason: flow);
        expect(
          FeatureFlags.shipped.isOn(f!),
          isTrue,
          reason: '$flow was switched on deliberately',
        );
      }
    });
  });

  group('a switched-off screen cannot be reached, even by deep link', () {
    /// The first route id belonging to [flow].
    String idFor(String flow) =>
        appRoutes.entries.firstWhere((e) => e.value.flow == flow).key;

    testWidgets('a community route renders FeatureOff while community is off',
        (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff;
      final id = idFor('community');
      final route = AppRouter.onGenerateRoute(
        RouteSettings(name: appRoutes[id]!.name),
      );
      expect(route, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (c) => (route! as MaterialPageRoute).builder(c),
          ),
        ),
      );
      expect(find.byType(FeatureOff), findsOneWidget);
      expect(find.byType(NotBuiltYet), findsNothing);
    });

    testWidgets('switching the feature on stops the gate intercepting',
        (tester) async {
      AppRouter.featureFlags =
          FeatureFlags.allOff.with_({Feature.community: true});
      final id = idFor('community');
      final route = AppRouter.onGenerateRoute(
        RouteSettings(name: appRoutes[id]!.name),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (c) => (route! as MaterialPageRoute).builder(c),
          ),
        ),
      );
      // It is no longer intercepted. Whether the screen itself is built is a
      // separate question, answered by NotBuiltYet.
      expect(find.byType(FeatureOff), findsNothing);
    });

    testWidgets('an ungated flow is never intercepted', (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff;
      final id = idFor('account');
      final route = AppRouter.onGenerateRoute(
        RouteSettings(name: appRoutes[id]!.name),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: Builder(
            builder: (c) => (route! as MaterialPageRoute).builder(c),
          ),
        ),
      );
      expect(
        find.byType(FeatureOff),
        findsNothing,
        reason: 'account stays reachable with every switch off',
      );
    });
  });
}
