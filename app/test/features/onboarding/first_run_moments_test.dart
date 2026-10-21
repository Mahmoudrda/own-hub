import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/first_run_moments.dart';
import 'package:own_hub/app_state/guest_session.dart';
import 'package:own_hub/app_state/snapshot_owner.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/presentation/deep_breath_view.dart';
import 'package:own_hub/features/onboarding/presentation/goal_view.dart';
import 'package:own_hub/features/onboarding/presentation/starting_program_view.dart';
import 'package:own_hub/features/onboarding/presentation/tick_promise_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _host(Widget child, {bool still = false}) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: child,
  ),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FirstRunMoments.instance.debugSet(loaded: false);
  });

  tearDown(() {
    FirstRunMoments.instance.debugSet(loaded: false);
    AppRouter.featureFlags = savedFlags;
    AppRouter.intakeRepository.reset();
    GuestSession.instance.reset();
  });

  group('the deep breath', () {
    testWidgets('breathes in, breathes out, then goes on by itself', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(_host(DeepBreathView(onDone: () => done++)));
      expect(find.text('Take a deep breath'), findsOneWidget);
      expect(find.text('Breathe in'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2500));
      expect(find.text('Breathe out'), findsOneWidget);
      expect(done, 0);
      await tester.pump(const Duration(milliseconds: 1600));
      expect(done, 1);
    });

    testWidgets('Skip and a tap anywhere both go on, once', (tester) async {
      var done = 0;
      await tester.pumpWidget(_host(DeepBreathView(onDone: () => done++)));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(done, 1);
      await tester.tapAt(const Offset(300, 300));
      await tester.pump(const Duration(seconds: 5));
      expect(done, 1);
    });

    testWidgets('a tap on the screen skips', (tester) async {
      var done = 0;
      await tester.pumpWidget(_host(DeepBreathView(onDone: () => done++)));
      await tester.tapAt(const Offset(300, 400));
      await tester.pump();
      expect(done, 1);
    });

    testWidgets('Reduce Motion: both lines, a Continue button, no timer', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(
        _host(DeepBreathView(onDone: () => done++), still: true),
      );
      expect(find.text('Breathe in'), findsOneWidget);
      expect(find.text('Breathe out'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(done, 0);
      await tester.tap(find.text('Continue'));
      expect(done, 1);
    });

    testWidgets('showing it marks it seen', (tester) async {
      FirstRunMoments.instance.debugSet();
      expect(FirstRunMoments.instance.breathDue, isTrue);
      await tester.pumpWidget(_host(DeepBreathView(onDone: () {})));
      expect(FirstRunMoments.instance.breathDue, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('on a launch', () {
    setUp(() {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        for (final f in Feature.values) f: f != Feature.coachApp,
      });
      GuestSession.instance.reset();
      AppRouter.intakeRepository.reset();
    });

    testWidgets('the first launch shows it once before the questions', (
      tester,
    ) async {
      _phone(tester);
      FirstRunMoments.instance.debugSet();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pump();
      expect(find.byType(DeepBreathView), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(DeepBreathView), findsNothing);
      expect(find.byType(GoalView), findsOneWidget);
      expect(FirstRunMoments.instance.breathDue, isFalse);

      AppRouter.intakeRepository.reset();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(find.byType(DeepBreathView), findsNothing);
    });

    testWidgets('left alone it goes on to the first question by itself', (
      tester,
    ) async {
      _phone(tester);
      FirstRunMoments.instance.debugSet();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pump();
      expect(find.byType(DeepBreathView), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.byType(GoalView), findsOneWidget);
    });

    testWidgets('a returning member on this phone never sees it', (
      tester,
    ) async {
      _phone(tester);
      await SnapshotOwner.instance.claim('u-before');
      addTearDown(SnapshotOwner.instance.resetForTest);
      FirstRunMoments.instance.debugSet();
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(find.byType(DeepBreathView), findsNothing);
      expect(find.byType(GoalView), findsNothing);
    });
  });

  group('the promise tick', () {
    Future<void> drawTick(WidgetTester tester) async {
      final box = tester.getTopLeft(find.byKey(const ValueKey('tick-box')));
      final g = await tester.startGesture(box + const Offset(40, 80));
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(box + Offset(40 + i * 6.0, 80 + i * 8.0));
      }
      for (var i = 1; i <= 12; i++) {
        await g.moveTo(box + Offset(88 + i * 10.0, 144 - i * 9.0));
      }
      await g.up();
    }

    testWidgets('a drawn tick is accepted and continues after the nod', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(_host(TickPromiseView(onDone: () => done++)));
      expect(find.text('Draw a tick to promise yourself'), findsOneWidget);
      await drawTick(tester);
      await tester.pump();
      expect(done, 0);
      await tester.pump(const Duration(seconds: 2));
      expect(done, 1);
    });

    testWidgets('a dot is refused and nothing continues', (tester) async {
      var done = 0;
      await tester.pumpWidget(_host(TickPromiseView(onDone: () => done++)));
      final box = tester.getTopLeft(find.byKey(const ValueKey('tick-box')));
      await tester.tapAt(box + const Offset(60, 60));
      await tester.pump(const Duration(seconds: 3));
      expect(done, 0);
    });

    testWidgets('Skip continues at once', (tester) async {
      var done = 0;
      await tester.pumpWidget(_host(TickPromiseView(onDone: () => done++)));
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(done, 1);
    });

    testWidgets('"I promise" continues, with a Semantics label on the box', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(_host(TickPromiseView(onDone: () => done++)));
      expect(
        find.bySemanticsLabel('Drawing box for your tick'),
        findsOneWidget,
      );
      await tester.tap(find.text('I promise'));
      await tester.pump(const Duration(seconds: 2));
      expect(done, 1);
    });

    testWidgets('Reduce Motion: the promise continues without waiting', (
      tester,
    ) async {
      var done = 0;
      await tester.pumpWidget(
        _host(TickPromiseView(onDone: () => done++), still: true),
      );
      await tester.tap(find.text('I promise'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(done, 1);
    });

    testWidgets('O05: shown once after the primary button, then on', (
      tester,
    ) async {
      FirstRunMoments.instance.debugSet();
      var started = 0;
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(),
            promiseFirst: true,
            onStartNow: () => started++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start day 1 now'));
      await tester.pumpAndSettle();
      expect(find.byType(TickPromiseView), findsOneWidget);
      expect(started, 0);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(TickPromiseView), findsNothing);
      expect(started, 1);

      await tester.tap(find.text('Start day 1 now'));
      await tester.pumpAndSettle();
      expect(find.byType(TickPromiseView), findsNothing);
      expect(started, 2);
    });

    testWidgets('profile-edit and change-plan paths never show it', (
      tester,
    ) async {
      FirstRunMoments.instance.debugSet();
      var saved = 0;
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(),
            onSaveMyWeek: () => saved++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('o05-save-my-week')));
      await tester.pumpAndSettle();
      expect(find.byType(TickPromiseView), findsNothing);
      expect(saved, 1);
      expect(FirstRunMoments.instance.tickDue, isTrue);
    });
  });

  group('review fixes', () {
    testWidgets('a refused stroke says so kindly, then the hint returns', (
      tester,
    ) async {
      await tester.pumpWidget(_host(TickPromiseView(onDone: () {})));
      final box = tester.getTopLeft(find.byKey(const ValueKey('tick-box')));
      final g = await tester.startGesture(box + const Offset(40, 40));
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(box + Offset(40 + i * 12.0, 40));
      }
      await g.up();
      await tester.pump();
      expect(find.text('Try once more, or tap I promise'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Try once more, or tap I promise'), findsNothing);
    });

    testWidgets('a mirrored tick is accepted on the screen', (tester) async {
      var done = 0;
      await tester.pumpWidget(_host(TickPromiseView(onDone: () => done++)));
      final box = tester.getTopLeft(find.byKey(const ValueKey('tick-box')));
      final g = await tester.startGesture(box + const Offset(280, 80));
      for (var i = 1; i <= 8; i++) {
        await g.moveTo(box + Offset(280 - i * 6.0, 80 + i * 8.0));
      }
      for (var i = 1; i <= 12; i++) {
        await g.moveTo(box + Offset(232 - i * 10.0, 144 - i * 9.0));
      }
      await g.up();
      await tester.pump(const Duration(seconds: 2));
      expect(done, 1);
    });

    testWidgets('the breath removes only its own route', (tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: const Text('questions'),
        ),
      );
      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const DeepBreathView()),
      );
      await tester.pumpAndSettle();
      navKey.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => const Text('on top')),
      );
      await tester.pumpAndSettle();
      // The breath ends under something else: it must not pop that.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('on top'), findsOneWidget);
      expect(find.byType(DeepBreathView), findsNothing);
    });

    testWidgets('Start tomorrow shows the tick once too', (tester) async {
      FirstRunMoments.instance.debugSet();
      var tomorrow = 0;
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(),
            promiseFirst: true,
            onStartTomorrow: () => tomorrow++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('I will start tomorrow'));
      await tester.pumpAndSettle();
      expect(find.byType(TickPromiseView), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(tomorrow, 1);
      await tester.tap(find.text('I will start tomorrow'));
      await tester.pumpAndSettle();
      expect(find.byType(TickPromiseView), findsNothing);
      expect(tomorrow, 2);
    });

    test('deleting her account clears both first-run keys', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        kBreathSeenKey: true,
        kTickPromiseSeenKey: true,
      });
      await const ThisPhoneWipe().clearPersistence();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey(kBreathSeenKey), isFalse);
      expect(prefs.containsKey(kTickPromiseSeenKey), isFalse);
    });
  });
}
