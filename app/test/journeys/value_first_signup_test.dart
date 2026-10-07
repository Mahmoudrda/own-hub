// The value-first order: her week before her number, the gate untouched.
//
// A new woman taps "Show me around" on C01 and takes the tour (C04): the real
// screens with a sample week, nothing asked and nothing kept. "Join Own Hub"
// or "Make it mine" then starts sign-up the value-first way: one screen of
// her week (O03, life stage included), her week (O05) saved, and only then
// her number (C06). "Skip the tour and join" on C01 is the same start without
// the tour. After the check, C13 is the root of the stack and "Start day 1"
// lands her on day one over Home.
//
// Driven through the router's own builders, with the launch flags: the gate
// is closed, the community and the coach app are off. Where a step needs a
// provider this test binary cannot reach (the code on C07, the verdict on
// C12), the screen's own callback is called, which is exactly what the
// screen would call.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/analytics/analytics_gateway.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/signup/domain/legal_acceptance.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/checking_view.dart';
import 'package:own_hub/features/signup/presentation/code_view.dart';
import 'package:own_hub/features/signup/presentation/role_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
}

/// Every event, in order, as the gateway hands it to a sink.
class _Recording implements AnalyticsSink {
  final List<String> events = <String>[];
  final List<Map<String, Object>> properties = <Map<String, Object>>[];

  @override
  Future<void> send(String event, Map<String, Object> props) async {
    events.add(event);
    properties.add(props);
  }
}

String _name(String id) => appRoutes[id]!.name;

Future<(_Stack, GlobalKey<NavigatorState>)> _open(
  WidgetTester tester,
  String id,
) async {
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
      initialRoute: _name(id),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
    ),
  );
  await tester.pumpAndSettle();
  return (stack, navigator);
}

Future<void> _tap(WidgetTester tester, String label) async {
  final target = find.text(label).last;
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

VerificationResult _passed() => VerificationResult(
  method: VerificationMethod.automatic,
  startedAt: DateTime(2026, 10, 6, 12, 0, 0),
  decidedAt: DateTime(2026, 10, 6, 12, 1, 12),
  imagesDeletedAt: DateTime(2026, 10, 6, 12, 1, 12),
);

/// The first release, stated rather than inherited: the gate closed, the
/// product's own features on, the community and the coach app off.
final FeatureFlags _launch = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.accountRequired: true,
  Feature.signUp: true,
  Feature.today: true,
  Feature.train: true,
  Feature.eat: true,
  Feature.progress: true,
  Feature.cycle: true,
  Feature.privacyCentre: true,
});

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedAnalytics = AppRouter.analytics;
  late _Recording recording;

  setUp(() async {
    // The check's memory lives in shared preferences; with no platform
    // behind it a read would wait for ever.
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = _launch;
    recording = _Recording();
    AppRouter.analytics = AnalyticsGateway(recording);
    AppRouter.intakeRepository.reset();
    await AppRouter.forgetVerification();
    OnboardingState.instance
      ..beforeSignup = false
      ..shortSetupAfterSignup = false
      ..enteredFromSignup = false;
  });

  tearDown(() async {
    AppRouter.featureFlags = savedFlags;
    AppRouter.analytics = savedAnalytics;
    AppRouter.intakeRepository.reset();
    await AppRouter.forgetVerification();
    AppRouter.lastSignupRole = null;
    OnboardingState.instance
      ..beforeSignup = false
      ..shortSetupAfterSignup = false
      ..enteredFromSignup = false;
  });

  group('before sign-up', () {
    testWidgets('C01, one screen of her week, her week, then her number', (
      tester,
    ) async {
      expect(
        AppRouter.featureFlags.isOn(Feature.accountRequired),
        isTrue,
        reason: 'the gate is closed in this walk',
      );
      final (stack, _) = await _open(tester, 'C01');

      await _tap(tester, 'Skip the tour and join');
      expect(stack.names.last, _name('O03'));
      expect(find.text('1 of 3 · Your week'), findsOneWidget);
      expect(find.text('Skip'), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing);

      await _tap(tester, '4');
      await _tap(tester, 'A knee, back or shoulder');
      await _tap(tester, 'See my week');
      expect(stack.names.last, _name('O05'));
      expect(find.text('Built from your answers'), findsOneWidget);
      expect(find.text('Start day 1 now'), findsNothing);

      await _tap(tester, 'Save my week and join');

      expect(stack.names, [
        _name('C01'),
        _name('O03'),
        _name('O05'),
        _name('C06'),
      ]);
      expect(find.text('2 of 3 · Your number'), findsOneWidget);
      // M1: O03 and O05 never count as acceptance. C06 says what her tap will
      // accept, and nothing is recorded until she taps it.
      expect(
        find.text(
          'By tapping Agree and send me a code, you accept the Terms of Use '
          'and the Privacy Policy.',
        ),
        findsOneWidget,
      );
      expect(find.text('Agree and send me a code'), findsOneWidget);
      expect(await PendingLegalAcceptance.read(), isNull);
      expect(AppRouter.intakeRepository.setupDone, isTrue);
      expect(AppRouter.intakeRepository.read().days, 4);
      expect(AppRouter.intakeRepository.read().lifeStage, LifeStage.painInjury);
      expect(AppRouter.progressStore.goal.sessionsTarget, 4);
      expect(
        OnboardingState.instance.isDue,
        isFalse,
        reason: 'her week is done, so the walk is not owed after the check',
      );
    });

    testWidgets('a week already saved opens straight on O05', (tester) async {
      AppRouter.intakeRepository.markSetupDone();
      final (stack, _) = await _open(tester, 'C01');

      await _tap(tester, 'Skip the tour and join');
      expect(stack.names.last, _name('O05'));
      expect(find.text('Save my week and join'), findsOneWidget);
    });

    testWidgets('the funnel is reported in order', (tester) async {
      await _open(tester, 'C01');
      await _tap(tester, 'Skip the tour and join');
      await _tap(tester, 'See my week');
      await _tap(tester, 'Save my week and join');

      final funnel = [
        for (var i = 0; i < recording.events.length; i++)
          recording.events[i] == 'screenViewed'
              ? recording.properties[i]['screenId']!
              : recording.events[i],
      ];
      expect(
        funnel,
        containsAllInOrder(<Object>[
          'C01',
          'signUpStarted',
          'O03',
          'O05',
          'intakeCompleted',
          'C06',
        ]),
      );
    });
  });

  group('her week, kept on this phone before she joins', () {
    testWidgets('no week saved, nothing to delete', (tester) async {
      await _open(tester, 'C01');
      expect(find.text('Delete what I saved on this phone'), findsNothing);
    });

    testWidgets('C01 deletes it, after asking once', (tester) async {
      await _open(tester, 'C01');
      await _tap(tester, 'Skip the tour and join');
      await _tap(tester, '4');
      await _tap(tester, 'A knee, back or shoulder');
      await _tap(tester, 'See my week');
      await _tap(tester, 'Save my week and join');
      expect(AppRouter.intakeRepository.setupDone, isTrue);
      expect(OnboardingState.instance.beforeSignup, isTrue);

      // She stops at her number and comes back to the front door.
      final (stack, _) = await _open(tester, 'C01');
      expect(find.text('Delete what I saved on this phone'), findsOneWidget);

      await _tap(tester, 'Delete what I saved on this phone');
      expect(find.text('Delete what you saved on this phone?'), findsOneWidget);
      await _tap(tester, 'Keep it');
      expect(AppRouter.intakeRepository.setupDone, isTrue);
      expect(
        AppRouter.intakeRepository.read().lifeStage,
        LifeStage.painInjury,
        reason: 'keeping it keeps it',
      );

      await _tap(tester, 'Delete what I saved on this phone');
      await _tap(tester, 'Delete it');
      expect(AppRouter.intakeRepository.setupDone, isFalse);
      expect(AppRouter.intakeRepository.read(), Intake.defaults);
      expect(AppRouter.progressStore.goal.sessionsTarget, 3);
      expect(OnboardingState.instance.beforeSignup, isFalse);
      expect(stack.names, [_name('C01')]);
      expect(find.text('Deleted from this phone.'), findsOneWidget);
      expect(find.text('Delete what I saved on this phone'), findsNothing);

      // And the next start asks her week again.
      await _tap(tester, 'Skip the tour and join');
      expect(stack.names.last, _name('O03'));
    });
  });

  group('the tour first', () {
    testWidgets('"Show me around" opens the tour, and Join starts her week', (
      tester,
    ) async {
      final (stack, _) = await _open(tester, 'C01');

      await _tap(tester, 'Show me around');
      expect(stack.names, [_name('C01'), _name('C04')]);
      expect(find.text('Sample · nothing is saved'), findsOneWidget);
      expect(OnboardingState.instance.beforeSignup, isFalse);

      await _tap(tester, 'Join Own Hub');
      expect(stack.names, [_name('C01'), _name('C04'), _name('O03')]);
      expect(find.text('1 of 3 · Your week'), findsOneWidget);
      expect(OnboardingState.instance.beforeSignup, isTrue);
    });

    testWidgets('back from her week returns her to the stop she left', (
      tester,
    ) async {
      final (stack, navigator) = await _open(tester, 'C01');
      await _tap(tester, 'Show me around');
      await _tap(tester, 'Next');
      await _tap(tester, 'Next');
      expect(find.text('3 of 7'), findsOneWidget);

      await _tap(tester, 'Join Own Hub');
      expect(stack.names.last, _name('O03'));

      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(stack.names, [_name('C01'), _name('C04')]);
      expect(find.text('3 of 7'), findsOneWidget);
    });

    testWidgets('the join sheet starts the same sign-up', (tester) async {
      final (stack, _) = await _open(tester, 'C01');
      await _tap(tester, 'Show me around');

      await _tap(tester, 'Count it');
      expect(find.text('Join to make this yours'), findsOneWidget);
      expect(
        stack.names,
        [_name('C01'), _name('C04'), '?'],
        reason: 'the sheet, over the tour, and no screen behind it',
      );

      await _tap(tester, 'Join Own Hub');
      expect(stack.names, [_name('C01'), _name('C04'), _name('O03')]);
    });

    testWidgets('"Make it mine" at the end, straight to O05 once her week '
        'is saved', (tester) async {
      AppRouter.intakeRepository.markSetupDone();
      final (stack, _) = await _open(tester, 'C01');
      await _tap(tester, 'Show me around');
      for (var i = 0; i < 7; i++) {
        await _tap(tester, 'Next');
      }
      expect(find.text('That is Own Hub'), findsOneWidget);

      await _tap(tester, 'Make it mine');
      expect(stack.names, [_name('C01'), _name('C04'), _name('O05')]);
      expect(find.text('Save my week and join'), findsOneWidget);
    });

    testWidgets('"I already have an account" from the end is the number', (
      tester,
    ) async {
      final (stack, _) = await _open(tester, 'C01');
      await _tap(tester, 'Show me around');
      for (var i = 0; i < 7; i++) {
        await _tap(tester, 'Next');
      }
      await _tap(tester, 'I already have an account');
      expect(stack.names.last, _name('C06'));
    });

    testWidgets('leaving the tour is the front door again', (tester) async {
      final (stack, _) = await _open(tester, 'C01');
      await _tap(tester, 'Show me around');
      await _tap(tester, 'Next');

      await tester.tap(find.byTooltip('Leave the tour'));
      await tester.pumpAndSettle();
      expect(stack.names, [_name('C01')]);
    });

    testWidgets('the tour reports its screen view and its funnel, no more', (
      tester,
    ) async {
      await _open(tester, 'C01');
      await _tap(tester, 'Show me around');
      for (var i = 0; i < 7; i++) {
        await _tap(tester, 'Next');
      }
      // The tour's own screen view, Firebase's tutorial_begin, each stop,
      // and tutorial_complete on the end card.
      expect(recording.events, [
        'screenViewed',
        'screenViewed',
        'tourStarted',
        for (var i = 0; i < 8; i++) 'tourStopViewed',
        'tourCompleted',
      ]);
      expect(recording.properties[1]['screenId'], 'C04');
      expect(recording.properties[2], isEmpty);
      expect(
        [for (final p in recording.properties.sublist(3, 11)) p['tourStop']],
        ['1', '2', '3', '4', '5', '6', '7', 'end'],
      );
      for (final p in recording.properties.sublist(3, 11)) {
        expect(p.keys, ['tourStop'], reason: 'a stop, and nothing about her');
      }
      expect(recording.properties[11], isEmpty);

      await _tap(tester, 'Make it mine');
      expect(recording.events.sublist(12, 15), [
        'tourJoinTapped',
        'signUpStarted',
        'screenViewed',
      ]);
      expect(recording.properties[12], {'source': 'end', 'tourStop': 'end'});
      expect(recording.properties[13], {'source': 'tour'});
    });
  });

  group('after the code', () {
    testWidgets('with the coach app off, C08 is skipped for the one check', (
      tester,
    ) async {
      OnboardingState.instance.beforeSignup = true;
      final (stack, _) = await _open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(stack.names.last, _name('C09b'));
      expect(AppRouter.lastSignupRole, SignupRole.trainee);
      expect(OnboardingState.instance.beforeSignup, isFalse);
      // C09's promise and C09b's disclosure on one screen.
      expect(find.text('3 of 3 · Quick check'), findsOneWidget);
      expect(find.text('One check, then you are in'), findsOneWidget);
      expect(find.text('Before the camera opens'), findsOneWidget);
      expect(find.text('I agree, start the camera'), findsOneWidget);
      expect(find.text('I wear niqab, check me another way'), findsOneWidget);
      expect(find.text('I would rather not'), findsOneWidget);
    });

    testWidgets('with the coach app on, she is still asked', (tester) async {
      AppRouter.featureFlags = _launch.with_(<Feature, bool>{
        Feature.coachApp: true,
      });
      final (stack, _) = await _open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(stack.names.last, _name('C08'));
    });

    testWidgets('the niqab path leaves C09b for a reviewer, no lens', (
      tester,
    ) async {
      final (stack, _) = await _open(tester, 'C09b');

      await _tap(tester, 'I wear niqab, check me another way');

      expect(stack.names.last, _name('C15'));
      expect(stack.names, isNot(contains(_name('C10'))));
    });
  });

  group('after the check', () {
    testWidgets('a verdict makes C13 the root of the stack', (tester) async {
      final (stack, _) = await _open(tester, 'C12');

      // No provider answers in this binary, so the screen has already moved
      // on to a reviewer by itself; its verdict callback is what a pass calls.
      tester
          .widget<CheckingView>(find.byType(CheckingView, skipOffstage: false))
          .onVerified!
          .call(_passed());
      await tester.pumpAndSettle();

      expect(stack.names, [_name('C13')]);
    });

    testWidgets('"Start day 1" with her week saved: day one over Home', (
      tester,
    ) async {
      AppRouter.intakeRepository.markSetupDone();
      AppRouter.lastVerification = _passed();
      final (stack, navigator) = await _open(tester, 'C13');

      expect(find.text('Read the three rules'), findsNothing);
      expect(find.text('Go to Home'), findsOneWidget);
      await _tap(tester, 'Start day 1');

      expect(stack.names, [_name('T01'), _name('R03')]);

      // Back from day one is Home, never the check or the camera.
      await navigator.currentState!.maybePop();
      await tester.pumpAndSettle();
      expect(stack.names, [_name('T01')]);
    });

    testWidgets('"Start day 1" without a week: the short setup, then day one', (
      tester,
    ) async {
      AppRouter.lastVerification = _passed();
      final (stack, _) = await _open(tester, 'C13');

      await _tap(tester, 'Start day 1');
      expect(stack.names.last, _name('O03'));
      expect(find.text('Anything we should train around?'), findsOneWidget);
      expect(find.text('1 of 3 · Your week'), findsNothing);

      await _tap(tester, 'See my week');
      await _tap(tester, 'Start day 1 now');

      expect(stack.names, [_name('T01'), _name('R03')]);
      expect(AppRouter.intakeRepository.setupDone, isTrue);
      expect(OnboardingState.instance.shortSetup, isFalse);
    });

    testWidgets('"Go to Home" lands on Home alone', (tester) async {
      AppRouter.lastVerification = _passed();
      final (stack, _) = await _open(tester, 'C13');

      await _tap(tester, 'Go to Home');
      expect(stack.names, [_name('T01')]);
    });
  });
}
