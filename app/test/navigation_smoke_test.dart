// A walk through the real app, not a screen in isolation.
//
// Every screen has its own widget test, and `nav_reachability_test` proves the
// graph on paper. Neither builds the actual MaterialApp, resolves a route
// through `onGenerateRoute`, and taps a real control -- so neither would catch
// a screen that throws the moment it is pushed for real.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/features/onboarding/presentation/goal_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/l10n/app_l10n.dart';

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  testWidgets('with an account required, the app boots to the welcome screen', (
    tester,
  ) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: true,
    });
    await tester.pumpWidget(const OwnHubApp());
    await tester.pumpAndSettle();
    expect(find.textContaining('women'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no account required, it boots straight onto Home as a '
      'guest who holds both roles', (tester) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    // Setup already behind her. A woman who has never been asked the four
    // questions opens on them instead, which is the case the onboarding
    // journey covers; this one is about the front door underneath.
    AppRouter.intakeRepository.markSetupDone();
    addTearDown(AppRouter.intakeRepository.reset);
    await tester.pumpWidget(const OwnHubApp());
    await tester.pumpAndSettle();
    expect(find.byType(TodayView), findsOneWidget);
    // Both roles: her picture is the switch to the coach side, so neither
    // half of the app is out of reach without an account.
    final roles = RoleScope.rolesOf(tester.element(find.byType(TodayView)));
    expect(roles.canSwitch, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a first launch the setup questions open on top of Home', (
    tester,
  ) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    AppRouter.intakeRepository.reset();
    addTearDown(AppRouter.intakeRepository.reset);
    await tester.pumpWidget(const OwnHubApp());
    await tester.pumpAndSettle();
    expect(find.byType(GoalView), findsOneWidget);
    // Home is underneath rather than replaced, so leaving setup is a pop.
    expect(find.byType(TodayView, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every built screen opens without throwing', (tester) async {
    // The honest version of "can I navigate the app": push each destination
    // through the real router and assert it renders. A screen that throws on
    // push is invisible to a widget test that constructs it directly with
    // hand-made arguments.
    AppRouter.featureFlags = FeatureFlags.shipped;

    final failures = <String>[];
    for (final entry in appDestinations.entries) {
      final id = entry.key;
      final route = AppRouter.onGenerateRoute(
        RouteSettings(name: entry.value.name),
      );
      if (route == null) {
        failures.add('$id: no route');
        continue;
      }
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
      final err = tester.takeException();
      if (err != null) failures.add('$id: $err');
    }

    expect(
      failures,
      isEmpty,
      reason: 'screens that threw when opened through the real router',
    );
  });
}
