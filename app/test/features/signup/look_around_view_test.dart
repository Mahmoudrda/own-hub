// C04, the tour, and C05, the join sheet raised over it.
//
// The stops themselves are covered in demo_tour_test.dart and the sample in
// demo_repositories_test.dart. This file holds the screen's own promises:
// what the route C05 shows, that a tour opened without a sample builds one
// that is labelled and refuses writes, and that it reads its recipes from
// the phone.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        textScaler: TextScaler.linear(textScale),
      ),
      child: child,
    ),
  );
}

void main() {
  late FeatureFlags saved;
  setUp(() {
    saved = AppRouter.featureFlags;
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
    });
  });
  tearDown(() => AppRouter.featureFlags = saved);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  group('C04', () {
    testWidgets('opens on Home with the sample labelled', (tester) async {
      phone(tester);
      await tester.pumpWidget(_host(const LookAroundView()));
      await tester.pumpAndSettle();

      expect(find.byType(TodayView), findsOneWidget);
      expect(find.text('Sample · nothing is saved'), findsOneWidget);
      expect(find.text('Join Own Hub'), findsOneWidget);
      expect(find.text('1 of 7'), findsOneWidget);
      expect(find.text('Home, your day at a glance'), findsOneWidget);
    });

    testWidgets('explains what the app is in plain words', (tester) async {
      phone(tester);
      await tester.pumpWidget(_host(const LookAroundView()));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Own Hub is a fitness app for women only.'),
        findsOneWidget,
      );
    });

    testWidgets('a real action asks her to join, and "Keep looking" stays', (
      tester,
    ) async {
      phone(tester);
      var joined = 0;
      await tester.pumpWidget(_host(LookAroundView(onJoin: () => joined++)));
      await tester.pumpAndSettle();

      final change = find.byKey(const ValueKey('today-change'));
      await tester.ensureVisible(change);
      await tester.pumpAndSettle();
      await tester.tap(change);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Count it'));
      await tester.pumpAndSettle();
      expect(find.text('Join to make this yours'), findsOneWidget);

      await tester.tap(find.text('Keep looking'));
      await tester.pumpAndSettle();
      expect(find.text('Join to make this yours'), findsNothing);
      expect(find.byType(TodayView), findsOneWidget);
      expect(joined, 0);
    });

    testWidgets('holds up in Arabic at a large text size', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        _host(
          const LookAroundView(),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Sample · nothing is saved'),
        findsNothing,
        reason: 'English here means a string bypassed the dictionary',
      );
      expect(find.text('مثال · مفيش حاجة بتتحفظ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('C05, the join sheet raised over C04', () {
    testWidgets('opens with the sheet up, over the tour', (tester) async {
      phone(tester);
      await tester.pumpWidget(
        _host(const LookAroundView(openJoinPrompt: true)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join to make this yours'), findsOneWidget);
      // Join opens her week first, so the sheet does not promise her number.
      expect(
        find.text(
          'First your week, then your number and a quick check that you\'re '
          'a woman.',
        ),
        findsOneWidget,
      );
      // R1-P8: no total time is stated until one has been measured.
      expect(find.textContaining('two minutes'), findsNothing);
      expect(find.byType(TodayView), findsOneWidget, reason: 'still C04');
    });

    testWidgets('with her week already built, the sheet asks for her number', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(
        _host(const LookAroundView(openJoinPrompt: true, setupDone: true)),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'We just need your number and a quick check that you\'re '
          'a woman.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the sheet\'s Join is the same way in', (tester) async {
      phone(tester);
      var joined = 0;
      await tester.pumpWidget(
        _host(LookAroundView(openJoinPrompt: true, onJoin: () => joined++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Join Own Hub').last);
      await tester.pumpAndSettle();
      expect(joined, 1);
      expect(find.text('Join to make this yours'), findsNothing);
    });
  });
}
