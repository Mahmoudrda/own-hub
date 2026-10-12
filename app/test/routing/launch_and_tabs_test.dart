// Two promises about how the app moves.
//
// A verified member's launch does not wait on the status read: her token
// already decides the gate, so the read of `users/{uid}.verification` runs
// after the first frame. A woman whose token does not carry the claim still
// waits for it, because for her it decides between the check and C14.
//
// A tab is a place, not a step: tapping one closes what was stacked above
// Home, so tabs never pile up and back from any tab is Home.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/routing/app_router.dart';

import 'offline_verification_launch_test.dart' show FakeBackend;

FeatureFlags get _gated =>
    FeatureFlags.allOff.with_({for (final f in Feature.values) f: true});

void main() {
  group('launch', () {
    final savedBackend = AppRouter.verificationBackend;
    final savedFlags = AppRouter.featureFlags;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppRouter.forgetVerification();
      AppRouter.featureFlags = _gated;
    });

    tearDown(() async {
      AppRouter.verificationBackend = savedBackend;
      AppRouter.featureFlags = savedFlags;
      await AppRouter.forgetVerification();
    });

    test('a verified member does not wait for the status read', () async {
      final status = Completer<ServerVerification?>();
      AppRouter.verificationBackend = FakeBackend(
        claim: ({bool forceRefresh = false}) async => true,
        status: () => status.future,
      );

      final watch = Stopwatch()..start();
      await AppRouter.readVerificationAtLaunch(
        bound: const Duration(seconds: 2),
      );
      watch.stop();

      expect(watch.elapsed, lessThan(const Duration(milliseconds: 500)));
      expect(AppRouter.isVerified, isTrue);
      expect(AppRouter.verificationGate('T01'), isNull);

      // It still lands when it answers.
      status.complete(
        const ServerVerification(ServerVerificationState.approved),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        AppRouter.serverVerification?.state,
        ServerVerificationState.approved,
      );
    });

    test('without the claim, the status read still decides before the first '
        'frame', () async {
      AppRouter.verificationBackend = FakeBackend(
        claim: ({bool forceRefresh = false}) async => false,
        status: () async =>
            const ServerVerification(ServerVerificationState.pending),
      );

      await AppRouter.readVerificationAtLaunch();

      expect(
        AppRouter.serverVerification?.state,
        ServerVerificationState.pending,
      );
      expect(AppRouter.isVerified, isFalse);
      expect(AppRouter.awaitingReviewer, isTrue);
    });
  });

  group('tabs', () {
    late GlobalKey<NavigatorState> navigator;
    late _Stack observed;

    Future<void> pumpAt(WidgetTester tester, String first) async {
      navigator = GlobalKey<NavigatorState>();
      observed = _Stack();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          navigatorObservers: [observed],
          initialRoute: appDestinations[first]!.name,
          // One route, as `main.dart`'s `_firstRunStack` opens the app: not
          // Flutter's default split into "/", "/today" and "/today/t01".
          onGenerateInitialRoutes: (name) => [_page(RouteSettings(name: name))],
          onGenerateRoute: _page,
        ),
      );
      await tester.pumpAndSettle();
    }

    List<String> stack() => [
      for (final route in observed.routes) route.settings.name!,
    ];

    BuildContext top(WidgetTester tester) =>
        tester.element(find.byType(Scaffold).last);

    testWidgets('tapping between tabs never piles screens up', (tester) async {
      await pumpAt(tester, 'T01');
      AppRouter.goTo(top(tester), 'P02');
      await tester.pumpAndSettle();

      for (final tab in ['R01', 'E01', 'P01', 'R01', 'E01']) {
        AppRouter.goToTab(top(tester), tab);
        await tester.pumpAndSettle();
      }

      expect(stack(), [
        appDestinations['T01']!.name,
        appDestinations['E01']!.name,
      ]);
    });

    testWidgets('back from a tab is Home', (tester) async {
      await pumpAt(tester, 'T01');
      AppRouter.goToTab(top(tester), 'P01');
      await tester.pumpAndSettle();
      AppRouter.goTo(top(tester), 'P05');
      await tester.pumpAndSettle();
      AppRouter.goToTab(top(tester), 'E01');
      await tester.pumpAndSettle();

      navigator.currentState!.pop();
      await tester.pumpAndSettle();

      expect(find.text(appDestinations['T01']!.name), findsOneWidget);
      expect(stack(), [appDestinations['T01']!.name]);
    });

    testWidgets('tapping Home leaves Home alone on the stack', (tester) async {
      await pumpAt(tester, 'T01');
      AppRouter.goToTab(top(tester), 'R01');
      await tester.pumpAndSettle();
      AppRouter.goTo(top(tester), 'R11');
      await tester.pumpAndSettle();

      AppRouter.goToTab(top(tester), 'T01');
      await tester.pumpAndSettle();

      expect(stack(), [appDestinations['T01']!.name]);
    });

    testWidgets('content links still stack, so back returns to them', (
      tester,
    ) async {
      await pumpAt(tester, 'T01');
      AppRouter.goTo(top(tester), 'P01');
      await tester.pumpAndSettle();
      AppRouter.goTo(top(tester), 'P05');
      await tester.pumpAndSettle();

      expect(stack(), [
        appDestinations['T01']!.name,
        appDestinations['P01']!.name,
        appDestinations['P05']!.name,
      ]);
    });
  });
}

Route<void> _page(RouteSettings settings) => MaterialPageRoute<void>(
  settings: settings,
  builder: (_) => Scaffold(body: Text(settings.name!)),
);

/// The navigator's stack, bottom first, as the navigator reports it.
class _Stack extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : routes.indexOf(oldRoute);
    if (at < 0 || newRoute == null) return;
    routes[at] = newRoute;
  }
}
