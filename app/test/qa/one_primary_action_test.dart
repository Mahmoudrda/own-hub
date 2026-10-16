// §15, Von Restorff and choice overload: every key screen leads with at most
// one filled primary action. A second filled button beside the first makes
// both of them quieter, and asks her to choose before she has a reason to.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

import '../helpers/primary_actions.dart';

Future<void> _settle(WidgetTester tester) async {
  try {
    await tester.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {
    // A long animation is not what this test is about.
  }
}

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  testWidgets('key screens lead with at most one filled action', (
    tester,
  ) async {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final offenders = <String>[];
    for (final id in const [
      'T01',
      'R03',
      'R07',
      'R09',
      'R10',
      'R11',
      'R13',
      'R14',
      'R15',
      'O05',
      'P01',
    ]) {
      final route = appDestinations[id];
      if (route == null) continue;
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _settle(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(route.name);
      await _settle(tester);
      final count = filledPrimaryActions(tester);
      if (count > 1) offenders.add('$id: $count filled actions');
    }
    expect(offenders, isEmpty);
  });

  testWidgets(
    'Home leads with one filled action on day one, a normal day and a done day',
    (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        for (final f in Feature.values) f: f != Feature.accountRequired,
      });
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      final home = AppRouter.todayRepository;
      final before = home.day;
      addTearDown(
        () => home.restore(
          day: before,
          seenNotices: home.seenNotices,
          creditedSessions: home.creditedSessions,
        ),
      );
      final now = DateTime.now();
      final days = {
        'day one': InMemoryTodayRepository.dayOne(date: now),
        for (final state in [DayState.nothingDone, DayState.done])
          state.name: TodayDay(
            date: now,
            state: state,
            arc: const FirstWeekArc(hasAnyLog: true),
            week: const WeekProgress(sessionsLogged: 1, sessionsTarget: 3),
          ),
      };
      final offenders = <String>[];
      for (final MapEntry(key: name, value: day) in days.entries) {
        home.restore(
          day: day,
          seenNotices: home.seenNotices,
          creditedSessions: home.creditedSessions,
        );
        await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
        await _settle(tester);
        tester
            .state<NavigatorState>(find.byType(Navigator).first)
            .pushNamed(appDestinations['T01']!.name);
        await _settle(tester);
        final count = filledPrimaryActions(tester);
        if (count > 1) offenders.add('T01 $name: $count filled actions');
      }
      expect(offenders, isEmpty);
    },
  );
}
