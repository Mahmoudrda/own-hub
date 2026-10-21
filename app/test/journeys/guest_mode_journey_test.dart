// Guest mode, walked through the real app: browse, try to save, meet Rahma,
// sign up, and find the thing she asked for done once. Then the other way in,
// signing in as a returning woman, and the number field.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/cloud_store.dart';
import 'package:own_hub/app_state/cloud_transport.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/guest_session.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/app_state/snapshot_owner.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/signup/data/fast_verification_claim.dart';
import 'package:own_hub/features/signup/domain/auth_repository.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/signup/presentation/code_view.dart';
import 'package:own_hub/features/signup/presentation/founder_welcome_view.dart';
import 'package:own_hub/features/signup/presentation/phone_number_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_code_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../routing/offline_verification_launch_test.dart' show FakeBackend;

class _Transport implements CloudTransport {
  int calls = 0;

  @override
  Future<List<CloudDoc>> pull(String uid) async {
    calls++;
    return const <CloudDoc>[];
  }

  @override
  Future<void> push(String uid, CloudDoc doc) async => calls++;
}

class _Approving implements FastVerificationClaimer {
  @override
  Future<FastVerification> claim() async => FastVerification.approved;
}

class _Names extends NavigatorObserver {
  final List<Route<dynamic>> stack = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    stack.remove(oldRoute);
    if (newRoute != null) stack.add(newRoute);
  }

  List<String?> get names => [for (final r in stack) r.settings.name];
}

VerificationResult _passed() => VerificationResult(
  method: VerificationMethod.automatic,
  decidedAt: DateTime(2026, 10, 18),
  imagesDeletedAt: DateTime(2026, 10, 18),
);

String get _todayId {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

MealStore get _store => AppRouter.mealRepository.store;

List<MealItem> get _written =>
    _store.days[_todayId]?.allItems.toList() ?? const <MealItem>[];

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  late _Transport transport;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.coachApp,
    });
    AppRouter.lastVerification = null;
    AppRouter.serverVerification = null;
    AppRouter.awaitingReviewer = false;
    AppRouter.consentRecorded = true;
    GuestSession.instance.reset();
    EatAppState.instance.reset();
    _store.days.clear();
    transport = _Transport();
    CloudStore.instance.transport = transport;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.lastVerification = null;
    AppRouter.serverVerification = null;
    AppRouter.awaitingReviewer = false;
    AppRouter.consentRecorded = false;
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.beforeSignup = false;
    GuestSession.instance.reset();
    EatAppState.instance.reset();
    _store.days.clear();
    fastVerificationClaimerOverride = null;
  });

  testWidgets('a guest with 60 minutes, 6 days and Advanced logs a meal, '
      'signs up, and both are kept', (tester) async {
    _phone(tester);
    const hers = Intake(days: 6, minutes: 60, level: TrainingLevel.advanced);
    AppRouter.intakeRepository.restore(hers, setupDone: true);

    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    expect(find.byType(TodayView), findsOneWidget);
    expect(find.byKey(const ValueKey('sign-in-pill')), findsOneWidget);

    // She browses to Eat's search and types a meal.
    _nav(tester).pushNamed(appRoutes['E02']!.name);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'koshari');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add it'));
    await tester.pumpAndSettle();

    // Nothing is written, nothing leaves the phone, and Rahma appears.
    expect(find.byType(FounderWelcomeView), findsOneWidget);
    expect(_written, isEmpty);
    expect(GuestSession.instance.pending?.kind, PendingKind.logMeal);
    expect(transport.calls, 0, reason: 'guests are local-only');

    await tester.tap(find.text('Continue to sign up'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneNumberView), findsOneWidget);

    // She is verified; Home comes up and replays what she asked for, once.
    AppRouter.lastVerification = _passed();
    _nav(tester).pushNamedAndRemoveUntil(appRoutes['T01']!.name, (_) => false);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(_written, hasLength(1));
    expect(_written.single.foodId, startsWith('koshari'));
    expect(GuestSession.instance.pending, isNull);
    final kept = AppRouter.intakeRepository.read();
    expect(kept.minutes, 60);
    expect(kept.days, 6);
    expect(kept.level, TrainingLevel.advanced);

    // And a second visit to Home does not log it again.
    _nav(tester).pushNamedAndRemoveUntil(appRoutes['T01']!.name, (_) => false);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(_written, hasLength(1));
  });

  testWidgets('a guest who taps Start on the workout meets Rahma first', (
    tester,
  ) async {
    _phone(tester);
    AppRouter.intakeRepository.markSetupDone();
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    _nav(tester).pushNamed(appRoutes['R03']!.name);
    await tester.pumpAndSettle();
    expect(find.byType(FounderWelcomeView), findsNothing, reason: 'view only');

    await tester.tap(
      find.widgetWithText(AppButton, "Start, everything's ready"),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FounderWelcomeView), findsOneWidget);
    expect(GuestSession.instance.pending?.kind, PendingKind.startWorkout);
  });

  group('signing in again', () {
    Future<_Names> open(WidgetTester tester, String id) async {
      _phone(tester);
      final names = _Names();
      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: [names],
          onGenerateRoute: AppRouter.onGenerateRoute,
          initialRoute: appRoutes[id]!.name,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      return names;
    }

    testWidgets('from the Home pill, a returning woman is not sent through '
        'setup', (tester) async {
      AppRouter.intakeRepository.markSetupDone();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('sign-in-pill')));
      await tester.pumpAndSettle();
      expect(find.byType(FounderWelcomeView), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with your number'), findsOneWidget);
    });

    testWidgets('a code accepted for a verified woman lands on Home', (
      tester,
    ) async {
      AppRouter.intakeRepository.markSetupDone();
      AppRouter.lastVerification = _passed();
      final names = await open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(names.names.last, appRoutes['T01']!.name);
      expect(names.names.any((n) => n!.startsWith('/onboarding')), isFalse);
    });

    testWidgets('a number the team already knows opens the app with no check', (
      tester,
    ) async {
      AppRouter.intakeRepository.markSetupDone();
      fastVerificationClaimerOverride = _Approving();
      final names = await open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(AppRouter.isVerified, isTrue);
      expect(names.names.last, appRoutes['T01']!.name);
      expect(names.names, isNot(contains(appRoutes['C09b']!.name)));
    });

    testWidgets('on a new phone, her cloud profile skips setup', (
      tester,
    ) async {
      // Verified by her token, nothing set up on this phone, and the pull
      // brings her profile (setupDone) down before the next screen is chosen.
      final saved = AppRouter.verificationBackend;
      final savedPull = AppRouter.cloudPull;
      addTearDown(() {
        AppRouter.verificationBackend = saved;
        AppRouter.cloudPull = savedPull;
      });
      AppRouter.verificationBackend = FakeBackend(
        uid: 'u1',
        claim: ({bool forceRefresh = false}) async => true,
        status: () async =>
            const ServerVerification(ServerVerificationState.approved),
      );
      var pulled = 0;
      AppRouter.cloudPull = (uid, bound) async {
        pulled++;
        AppRouter.intakeRepository.markSetupDone();
      };
      expect(AppRouter.intakeRepository.setupDone, isFalse);
      final names = await open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(pulled, 1);
      expect(names.names.last, appRoutes['T01']!.name);
      expect(names.names.any((n) => n!.startsWith('/onboarding')), isFalse);
    });

    testWidgets('a pending woman goes to C14, never back to the consent', (
      tester,
    ) async {
      AppRouter.serverVerification = const ServerVerification(
        ServerVerificationState.pending,
      );
      final names = await open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(names.names.last, appRoutes['C14']!.name);
      expect(names.names, isNot(contains(appRoutes['C09b']!.name)));
    });

    testWidgets('a rejected woman goes to C14 as well', (tester) async {
      AppRouter.serverVerification = const ServerVerification(
        ServerVerificationState.rejected,
      );
      final names = await open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(names.names.last, appRoutes['C14']!.name);
    });

    testWidgets('a new woman still goes to the check', (tester) async {
      final names = await open(tester, 'C07');

      await tester.widget<CodeView>(find.byType(CodeView)).onConfirmed!.call();
      await tester.pumpAndSettle();

      expect(names.names.last, appRoutes['C09b']!.name);
    });
  });

  group('a phone that still holds an account that signed out', () {
    setUp(() async {
      await SnapshotOwner.instance.claim('u-before');
    });
    tearDown(SnapshotOwner.instance.resetForTest);

    test('opens on the welcome, not on her data', () {
      expect(GuestSession.isBrowsing, isFalse);
      expect(AppRouter.frontDoor, appRoutes['C01']!.name);
      expect(AppRouter.verificationGate('T01'), appRoutes['C01']!.name);
      expect(OnboardingState.instance.isDue, isFalse);
    });
  });

  testWidgets('Back on Rahma\'s page drops what she had asked for', (
    tester,
  ) async {
    _phone(tester);
    AppRouter.intakeRepository.markSetupDone();
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    GuestSession.require(
      tester.element(find.byType(TodayView)),
      const PendingAction.startWorkout(),
    );
    await tester.pumpAndSettle();
    expect(GuestSession.instance.pending, isNotNull);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(FounderWelcomeView), findsNothing);
    expect(GuestSession.instance.pending, isNull);
  });

  group('the number', () {
    Future<FakeAuthRepository> pump(
      WidgetTester tester, {
      VoidCallback? onCodeSent,
      bool signIn = false,
    }) async {
      _phone(tester);
      final repository = FakeAuthRepository();
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: PhoneNumberView(
            repository: repository,
            signIn: signIn,
            onCodeSent: onCodeSent,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    String shown(WidgetTester tester) =>
        tester.widget<EditableText>(find.byType(EditableText)).controller.text;

    testWidgets('an existing number on Sign up goes on to the code, number '
        'kept', (tester) async {
      var sent = 0;
      final repository = await pump(tester, onCodeSent: () => sent++);
      await tester.enterText(find.byType(EditableText), '01005550132');
      await tester.pumpAndSettle();

      // She realises she has an account and flips to sign in.
      await tester.tap(find.byKey(const ValueKey('phone-toggle-intent')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with your number'), findsOneWidget);
      expect(shown(tester), '100 555 0132');

      await tester.tap(find.text('Agree and send me a code'));
      await tester.pumpAndSettle();
      expect(sent, 1);
      expect(repository.sentTo, ['+201005550132']);
    });

    testWidgets('the toggle goes both ways and keeps the digits', (
      tester,
    ) async {
      await pump(tester, signIn: true);
      expect(find.text('Sign in with your number'), findsOneWidget);
      await tester.enterText(find.byType(EditableText), '1005550132');
      await tester.tap(find.byKey(const ValueKey('phone-toggle-intent')));
      await tester.pumpAndSettle();
      expect(find.text('Sign in with your number'), findsNothing);
      expect(shown(tester), '100 555 0132');
    });

    for (final pasted in const [
      '+20 100 555 0132',
      '+201005550132',
      '00201005550132',
      '201005550132',
      '01005550132',
      '1005550132',
      '٠١٠٠٥٥٥٠١٣٢',
      '+٢٠ ١٠٠ ٥٥٥ ٠١٣٢',
    ]) {
      testWidgets('pasting $pasted gives one clean number', (tester) async {
        final repository = await pump(tester);
        await tester.enterText(find.byType(EditableText), pasted);
        await tester.pumpAndSettle();
        expect(shown(tester), '100 555 0132');

        await tester.tap(find.text('Agree and send me a code'));
        await tester.pumpAndSettle();
        expect(repository.sentTo, ['+201005550132']);
      });
    }

    testWidgets('the number is grouped as she types', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '10055');
      await tester.pumpAndSettle();
      expect(shown(tester), '100 55');
    });

    testWidgets('the field offers the phone number to autofill', (
      tester,
    ) async {
      await pump(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.autofillHints, contains(AutofillHints.telephoneNumber));
      expect(field.autofocus, isTrue);
    });
  });

  group('the code', () {
    testWidgets('Arabic-Indic digits are accepted and the last one submits', (
      tester,
    ) async {
      String? done;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCodeField(length: 6, onCompleted: (code) => done = code),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '٤١٧٢٩٣');
      await tester.pump();
      expect(done, '417293');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '417293',
      );
    });

    testWidgets('a pasted code with a space in it still lands', (tester) async {
      String? done;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppCodeField(length: 6, onCompleted: (code) => done = code),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '417 293');
      await tester.pump();
      expect(done, '417293');
    });
  });
}
