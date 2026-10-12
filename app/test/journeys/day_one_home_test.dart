// Day-one Home after onboarding, and the reason to come back on day two.
//
// Home on day one names her week (the line O05 showed her), opens the three
// things she came for in one tap each (her first workout, a meal, her
// dinners), offers My cycle once and lets her say not now. Finishing a session
// says what is next in the week's terms, and "Back to Today" lands on Home with
// the session's screens gone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';

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

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    // The first release's features, with the gate open: this file is about
    // Home, not about verification.
    AppRouter.featureFlags = FeatureFlags.allOff.with_(<Feature, bool>{
      Feature.today: true,
      Feature.firstWeek: true,
      Feature.quietWeek: true,
      Feature.tiers: true,
      Feature.lockScreenNudge: true,
      Feature.train: true,
      Feature.recordFromMemory: true,
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
    AppRouter.todayRepository.reset();
    AppRouter.intakeRepository
      ..reset()
      ..restore(const Intake(days: 4, minutes: 20), setupDone: true);
    OnboardingState.instance.cycleRowDismissed = false;
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.todayRepository.reset();
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.cycleRowDismissed = false;
  });

  testWidgets('day one names the week she saved', (tester) async {
    await _open(tester, 'T01');

    expect(find.byKey(const ValueKey('day-one-her-week')), findsOneWidget);
    expect(find.textContaining('4'), findsWidgets);
    expect(find.textContaining('20'), findsWidgets);
  });

  // R1-P22 and C1: the short "Your week" never asks where she trains, so
  // Home does not tell her she trains at home.
  testWidgets('after the short setup the week line names no place', (
    tester,
  ) async {
    await _open(tester, 'T01');
    final line = tester.widget<Text>(
      find.byKey(const ValueKey('day-one-her-week')),
    );
    expect(line.data, 'Days a week: 4 · Minutes a session: 20');
    expect(find.textContaining('At home'), findsNothing);
  });

  testWidgets('a place she answered is read back', (tester) async {
    AppRouter.intakeRepository.restore(
      const Intake(days: 4, minutes: 20, place: TrainingPlace.ladiesGym),
      setupDone: true,
      placeAnswered: true,
    );
    await _open(tester, 'T01');
    final line = tester.widget<Text>(
      find.byKey(const ValueKey('day-one-her-week')),
    );
    expect(line.data, contains('At a ladies-only gym'));
  });

  testWidgets('"Tell us one thing you eat" opens Eat, not a blank field', (
    tester,
  ) async {
    final (stack, _) = await _open(tester, 'T01');
    await _tap(tester, find.text('Tell us one thing you eat'));
    expect(stack.names.last, _name('E01'));
  });

  testWidgets('"Plan this week\'s dinners" is one tap from Home', (
    tester,
  ) async {
    final (stack, _) = await _open(tester, 'T01');
    expect(
      find.text('Five Egyptian dinners and one shopping list'),
      findsOneWidget,
    );
    await _tap(tester, find.text("Plan this week's dinners"));
    expect(stack.names.last, _name('E07'));
  });

  group('"Track my cycle"', () {
    testWidgets('opens Y01, and skipping goes back to the same Home', (
      tester,
    ) async {
      final (stack, _) = await _open(tester, 'T01');
      expect(find.text('Optional, and it stays on this phone'), findsOneWidget);
      await _tap(tester, find.text('Track my cycle'));
      expect(stack.names.last, _name('Y01'));

      await _tap(tester, find.text('Skip setup').last);
      expect(stack.names, [_name('T01')], reason: 'not a second Home');
    });

    testWidgets('"Not now" hides it for good', (tester) async {
      await _open(tester, 'T01');
      await _tap(tester, find.text('Not now'));

      expect(find.text('Track my cycle'), findsNothing);
      expect(OnboardingState.instance.cycleRowDismissed, isTrue);
    });
  });

  group('R10, the reason to come back', () {
    testWidgets('it says what is next, in the week\'s terms', (tester) async {
      await _open(tester, 'R10');

      expect(find.byKey(const ValueKey('r10-next-step')), findsOneWidget);
      // Nothing logged in this binary, so the next one is her first.
      expect(
        find.text('Next: session 1, on any day this week'),
        findsOneWidget,
      );
      expect(find.textContaining('streak'), findsNothing);
    });

    testWidgets('"Back to Today" lands on Home alone', (tester) async {
      final (stack, navigator) = await _open(tester, 'T01');
      navigator.currentState!.pushNamed(_name('R03'));
      await tester.pumpAndSettle();
      navigator.currentState!.pushNamed(_name('R10'));
      await tester.pumpAndSettle();

      await _tap(tester, find.text('Back to today'));
      expect(stack.names, [_name('T01')]);
    });
  });
}
