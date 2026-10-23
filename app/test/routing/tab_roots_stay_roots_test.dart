// Eat and Insights are tab roots. Home and the screens opened from it link to
// them as tabs, so no tab is ever pushed on top of another screen: the stack
// is Home and the tab, nothing between.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/chosen_programme.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/data/egyptian_food_pack.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/today/presentation/already_did_it_view.dart';
import 'package:own_hub/features/today/presentation/first_week_view.dart';
import 'package:own_hub/features/today/presentation/quiet_week_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/features/train/domain/viewed_tier.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

class _Stack extends NavigatorObserver {
  final List<Route<dynamic>> routes = [];

  List<String> get names => [for (final r in routes) r.settings.name!];

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

void main() {
  final savedFlags = AppRouter.featureFlags;
  late _Stack stack;

  // One route, as the app opens: not Flutter's default split of the path.
  Widget app() {
    stack = _Stack();
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(const Locale('en')),
      navigatorObservers: [stack],
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
      onGenerateInitialRoutes: (name) => [
        AppRouter.onGenerateRoute(RouteSettings(name: name))!,
      ],
      initialRoute: appRoutes['T01']!.name,
    );
  }

  Future<void> openHome(WidgetTester tester) async {
    _phone(tester);
    await tester.runAsync(EgyptianFoodPack.ensureLoaded);
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 600));
    expect(stack.names, [appRoutes['T01']!.name]);
  }

  Future<void> push(WidgetTester tester, String id) async {
    final context = tester.element(find.byType(Scaffold).last);
    AppRouter.goTo(context, id);
    await tester.pumpAndSettle();
  }

  void expectTabOverHome(String id) {
    expect(stack.names, [appRoutes['T01']!.name, appRoutes[id]!.name]);
  }

  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  setUp(() async {
    AppRouter.featureFlags = FeatureFlags.everything;
    AppRouter.consentRecorded = true;
    AppRouter.lastVerification = VerificationResult(
      method: VerificationMethod.automatic,
      decidedAt: DateTime(2026, 10, 2),
      imagesDeletedAt: DateTime(2026, 10, 2),
    );
    ChosenProgramme.reset();
    ViewedTier.clear();
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
    WorkoutLibraryState.instance
      ..openedSlot = null
      ..chosenRowId = null;
    await AppRouter.todayRepository.countWalk();
    await AppRouter.intakeRepository.merge(
      place: TrainingPlace.ladiesGym,
      goal: TrainingGoal.stronger,
      level: TrainingLevel.beginner,
      minutes: 45,
    );
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.consentRecorded = false;
    AppRouter.lastVerification = null;
    ChosenProgramme.reset();
    ViewedTier.clear();
    EatAppState.instance.reset();
    EgyptianFoodPack.reset();
  });

  group('from Home', () {
    testWidgets('open meal leaves Home and Eat', (tester) async {
      await openHome(tester);
      tester.widget<TodayView>(find.byType(TodayView)).onOpenMeal!();
      await tester.pumpAndSettle();
      expectTabOverHome('E01');
    });

    testWidgets('tell us what you eat leaves Home and Eat', (tester) async {
      await openHome(tester);
      tester.widget<TodayView>(find.byType(TodayView)).onTellUsWhatYouEat!();
      await tester.pumpAndSettle();
      expectTabOverHome('E01');
    });

    testWidgets('open week leaves Home and Insights', (tester) async {
      await openHome(tester);
      tester.widget<TodayView>(find.byType(TodayView)).onOpenWeek!();
      await tester.pumpAndSettle();
      expectTabOverHome('P01');
    });
  });

  group('from a screen opened over Home', () {
    testWidgets('the already-did-it page opens Eat without stacking', (
      tester,
    ) async {
      await openHome(tester);
      await push(tester, 'T02');
      tester
          .widget<AlreadyDidItView>(find.byType(AlreadyDidItView))
          .onOpenMeal!();
      await tester.pumpAndSettle();
      expectTabOverHome('E01');
    });

    testWidgets('the quiet week opens Eat without stacking', (tester) async {
      await openHome(tester);
      await push(tester, 'T04');
      tester.widget<QuietWeekView>(find.byType(QuietWeekView)).onOpenMeal!();
      await tester.pumpAndSettle();
      expectTabOverHome('E01');
    });

    testWidgets('the quiet week opens Insights without stacking', (
      tester,
    ) async {
      await openHome(tester);
      await push(tester, 'T04');
      tester.widget<QuietWeekView>(find.byType(QuietWeekView)).onOpenWeek!();
      await tester.pumpAndSettle();
      expectTabOverHome('P01');
    });

    for (final id in ['T07', 'T08']) {
      testWidgets('$id opens Insights without stacking', (tester) async {
        await openHome(tester);
        await push(tester, id);
        tester
            .widget<FirstWeekView>(find.byType(FirstWeekView))
            .onSeeProgress!();
        await tester.pumpAndSettle();
        expectTabOverHome('P01');
      });
    }
  });
}
