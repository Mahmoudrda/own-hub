// R1-P5: waiting for a woman reviewer with no week of her own.
//
// She signed in with an account she already had, or took the niqab path
// before building one, so C14 has no week on it. "Build your week while we
// check" opens the short "Your week" (O03, O07 and O04, one question a
// screen) and its result (O05), which ends in "Save my week" and lands back
// on C14 with her week on it. Day one is behind the gate, so nothing on the
// way offers it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/ui/app_step_bar.dart';
import 'package:own_hub/ui/screen_scope.dart';

String? _showing(WidgetTester tester) {
  final scopes = tester.widgetList<ScreenScope>(find.byType(ScreenScope));
  return scopes.isEmpty ? null : scopes.last.screenId;
}

(int, int) _bar(WidgetTester tester) {
  final bar = tester.widget<AppStepBar>(find.byType(AppStepBar));
  return (bar.step, bar.total);
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_(const {
      Feature.accountRequired: true,
      Feature.signUp: true,
      Feature.appTour: true,
      Feature.verification: true,
      Feature.today: true,
      Feature.firstWeek: true,
      Feature.quietWeek: true,
      Feature.tiers: true,
      Feature.lockScreenNudge: true,
      Feature.train: true,
      Feature.recordFromMemory: true,
      Feature.program: true,
      Feature.exerciseVideo: true,
      Feature.exerciseSwap: true,
      Feature.followAlong: true,
      Feature.workoutLibrary: true,
      Feature.trainingReminders: true,
      Feature.eat: true,
      Feature.recipes: true,
      Feature.weekPlan: true,
      Feature.groceryList: true,
      Feature.progress: true,
      Feature.milestones: true,
      Feature.personalBests: true,
      Feature.bodyPrivately: true,
      Feature.shareCard: true,
      Feature.cycle: true,
      Feature.cycleMeals: true,
      Feature.cycleCalendar: true,
      Feature.cyclePatterns: true,
      Feature.privacyCentre: true,
    });
    AppRouter.intakeRepository.reset();
    AppRouter.serverVerification = const ServerVerification(
      ServerVerificationState.pending,
    );
    OnboardingState.instance
      ..beforeSignup = false
      ..shortSetupAfterSignup = false
      ..whileWaiting = false;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.intakeRepository.reset();
    AppRouter.serverVerification = null;
    OnboardingState.instance
      ..shortSetupAfterSignup = false
      ..whileWaiting = false;
  });

  testWidgets('she builds her week from C14 and comes back to it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.onGenerateRoute,
        onUnknownRoute: AppRouter.onUnknownRoute,
        initialRoute: appRoutes['C14']!.name,
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    expect(_showing(tester), 'C14');
    expect(find.byKey(const ValueKey('c14-saved-week')), findsNothing);

    await _tap(tester, find.text('Build your week while we check'));
    expect(_showing(tester), 'O03');
    // The short week: three questions on the bar, no count in the title (she
    // has an account, so it is not "1 of 3 · Your week" either) and no Skip.
    expect(_bar(tester), (1, 3));
    expect(find.textContaining('1 of 6'), findsNothing);
    expect(find.text('1 of 3'), findsNothing);
    expect(find.text('1 of 3 · Your week'), findsNothing);
    expect(find.text('Skip'), findsNothing);

    await _tap(tester, find.text('Continue'));
    expect(_showing(tester), 'O07');
    expect(_bar(tester), (2, 3));
    expect(find.text('Skip'), findsNothing);

    await _tap(tester, find.text('Continue'));
    expect(_showing(tester), 'O04');
    expect(_bar(tester), (3, 3));
    expect(find.text('Anything we should train around?'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);

    await _tap(tester, find.text('See my week'));
    expect(_showing(tester), 'O05');
    // Day one is behind the gate: nothing here starts it.
    expect(find.text('Start day 1 now'), findsNothing);
    expect(find.text('I will start tomorrow'), findsNothing);
    expect(find.text('Save my week and join'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('o05-save-my-week')));
    expect(_showing(tester), 'C14');
    expect(AppRouter.intakeRepository.setupDone, isTrue);
    expect(OnboardingState.instance.whileWaiting, isFalse);
    expect(find.byKey(const ValueKey('c14-saved-week')), findsOneWidget);
    expect(find.text('Build your week while we check'), findsNothing);
    // The short setup never asked where she trains.
    expect(find.textContaining('At home'), findsNothing);
  });
}
