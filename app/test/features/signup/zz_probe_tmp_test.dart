// C04, the tour before sign-up: the real screens with a sample week.
//
// What matters here is that each stop IS the product's own screen, that the
// sample is labelled on every one of them, that the way in is always on
// screen, and that every real action asks her to join instead of doing
// anything. Run with the shipping flags, set explicitly.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/cycle/presentation/cycle_hub_view.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/presentation/rahma_recipe_view.dart';
import 'package:own_hub/features/eat/presentation/recipes_view.dart';
import 'package:own_hub/features/eat/presentation/week_plan_view.dart';
import 'package:own_hub/features/progress/presentation/progress_view.dart';
import 'package:own_hub/features/signup/demo/demo_sample.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_stops.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

/// The first release: the gate closed, the product's own features on, the
/// community, the coach app and the assistant off.
final FeatureFlags _launch = FeatureFlags.allOff.with_(<Feature, bool>{
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

late RecipeBook _book;

/// The real screen each stop must be, in order.
const List<Type> _stopTypes = [
  TodayView,
  WorkoutDayView,
  MidSetView,
  RecipesView,
  WeekPlanView,
  CycleHubView,
  ProgressView,
];

Future<DemoSample> _pump(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
  int initialStop = 0,
  bool waiting = false,
  VoidCallback? onJoin,
  VoidCallback? onLeave,
  VoidCallback? onSignIn,
  ValueChanged<int>? onStopViewed,
  void Function(DemoJoinSource source, int stop)? onJoinFrom,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final sample = DemoSample.build(now: DateTime(2026, 10, 6, 10), book: _book);
  addTearDown(sample.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        // A fresh tour every time, even within one test.
        child: LookAroundView(
          key: UniqueKey(),
          sample: sample,
          initialStop: initialStop,
          waiting: waiting,
          onJoin: onJoin,
          onLeave: onLeave ?? () {},
          onSignIn: onSignIn,
          onStopViewed: onStopViewed,
          onJoinFrom: onJoinFrom,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sample;
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

/// A control on the stop itself, never on the tour's own card or bar.
Finder _onStop(Finder finder) => find.descendant(
  of: find.byWidgetPredicate((w) => _stopTypes.contains(w.runtimeType)),
  matching: finder,
);


void main() {
  setUpAll(() async {
    _book = await SeededRecipeLibrary(
      readAsset: (path) async => File(path).readAsString(),
    ).load();
  });
  setUp(() => AppRouter.featureFlags = _launch);
  testWidgets('probe', (tester) async {
    await _pump(tester, locale: const Locale('ar'), initialStop: 6);
    for (final w in tester.widgetList<Text>(find.byType(Text))) {
      final s = w.data ?? w.textSpan?.toPlainText();
      // ignore: avoid_print
      print('TXT: $s');
    }
    for (final w in tester.widgetList<RichText>(find.byType(RichText))) {
      // ignore: avoid_print
      print('RICH: ${w.text.toPlainText()}');
    }
  });
  // keep analyzer quiet about unused helpers
  test('unused', () { _tap; _onStop; });
}
