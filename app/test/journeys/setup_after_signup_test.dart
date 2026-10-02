// G4: setup entered from the end of sign-up leaves to Home, with the sign-up
// stack cleared. Before this, "I will start tomorrow" popped back to C16, the
// pledge she had already agreed to, and "Start day 1 now" pushed R03 on top of
// the whole sign-up history.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

/// Keeps the navigator's history as a list of route names.
class _Stack extends NavigatorObserver {
  final List<String> names = <String>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.add(route.settings.name ?? '?');

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.removeLast();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      names.remove(route.settings.name ?? '?');

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = names.indexOf(oldRoute?.settings.name ?? '?');
    if (at >= 0) names[at] = newRoute?.settings.name ?? '?';
  }
}

String _name(String id) => appRoutes[id]!.name;

Future<_Stack> _toSetupFromPledge(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final stack = _Stack();
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [stack],
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      initialRoute: _name('C06'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  // The sign-up history she builds on the way to the pledge.
  for (final id in <String>['C07', 'C08', 'C16']) {
    navigator.currentState!.pushNamed(_name(id));
    await tester.pumpAndSettle();
  }
  expect(stack.names, containsAllInOrder(<String>[_name('C06'), _name('C16')]));

  await _tap(tester, 'I agree, let me in');
  expect(OnboardingState.instance.enteredFromSignup, isTrue);
  // Skip through the four questions to O05.
  for (var i = 0; i < 4; i++) {
    await _tap(tester, 'Skip');
  }
  expect(stack.names.last, _name('O05'));
  return stack;
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    // Sign-up screens on, the whole-app gate open: this file is about where
    // setup leads, not about verification.
    AppRouter.featureFlags = FeatureFlags.everything.with_(<Feature, bool>{
      Feature.accountRequired: false,
    });
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.enteredFromSignup = false;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.enteredFromSignup = false;
  });

  testWidgets('"I will start tomorrow" lands on Home and nothing else', (
    tester,
  ) async {
    final stack = await _toSetupFromPledge(tester);
    await _tap(tester, 'I will start tomorrow');

    expect(stack.names, <String>[_name('T01')]);
    expect(AppRouter.intakeRepository.setupDone, isTrue);
    expect(OnboardingState.instance.enteredFromSignup, isFalse);
  });

  testWidgets('"Start day 1 now" opens day one over Home', (tester) async {
    final stack = await _toSetupFromPledge(tester);
    await _tap(tester, 'Start day 1 now');

    expect(stack.names, <String>[_name('T01'), _name('R03')]);
    expect(AppRouter.intakeRepository.setupDone, isTrue);
  });

  testWidgets('"Pick a different program" opens the library over Home', (
    tester,
  ) async {
    final stack = await _toSetupFromPledge(tester);
    await _tap(tester, 'Pick a different program');

    expect(stack.names, <String>[_name('T01'), _name('R11')]);
  });
}
