// ignore_for_file: avoid_print
//
// R3-05. Is the number she chose the number she is shown?
//
// R3-04 proves the chip reaches `WeeklyGoal.sessionsTarget`. That is the write.
// This is the read: after choosing four days a week, every screen that states
// her week must state four. The old defect was a silent clamp, and a silent
// clamp and a stale copy look exactly the same to her — "This week, 0 of 3" on
// a woman who asked for four.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

void main() {
  useShippingApp();

  for (final days in <int>[2, 4]) {
    testWidgets('she chose $days: what every week line says', (t) async {
      phone(t);
      final s = t.ensureSemantics();

      await open(t, appDestinations['O03']!.name, locale: const Locale('en'));
      await t.tapAt(t.getRect(find.text('$days').first).center);
      await settle(t);
      await tapControl(t, RegExp('Continue'));
      OnboardingState.instance.finish();

      print('=== R3-05 chose $days ===');
      print('  goal.sessionsTarget      = '
          '${AppRouter.progressStore.goal.sessionsTarget}');
      print('  today.day.week           = '
          '${AppRouter.todayRepository.day.week.sessionsLogged} of '
          '${AppRouter.todayRepository.day.week.sessionsTarget}');

      for (final id in <String>['T01', 'R01', 'P01', 'T04', 'T07']) {
        await open(t, appDestinations[id]!.name, locale: const Locale('en'));
        final week = paintedText(t)
            .where((e) => RegExp(r'\d+\s*(of|/)\s*\d+').hasMatch(e))
            .toList();
        print('  $id week lines: ${week.join(" // ")}');
      }

      expect(
        AppRouter.todayRepository.day.week.sessionsTarget,
        days,
        reason: 'Home keeps its own copy of the week and it did not follow',
      );
      s.dispose();
    });
  }

  // A woman who finishes a session: does the count she is shown move, and
  // against the target she chose?
  testWidgets('she chose 4, logs one session, and Home counts it', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['O03']!.name, locale: const Locale('en'));
    await t.tapAt(t.getRect(find.text('4').first).center);
    await settle(t);
    await tapControl(t, RegExp('Continue'));
    OnboardingState.instance.finish();

    AppRouter.todayRepository.recordSession('s1');
    await open(t, appDestinations['T01']!.name, locale: const Locale('en'));
    final lines = paintedText(t)
        .where((e) => RegExp(r'\d+\s*(of|/)\s*\d+').hasMatch(e))
        .toList();
    print('=== R3-05 after one session, chose 4 ===');
    print('  week = ${AppRouter.todayRepository.day.week.sessionsLogged} of '
        '${AppRouter.todayRepository.day.week.sessionsTarget}');
    print('  T01 lines: ${lines.join(" // ")}');
    for (final id in <String>['R01', 'P01']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('  $id: ${paintedText(t).where((e) => RegExp(r"\d+\s*(of|/)\s*\d+").hasMatch(e)).join(" // ")}');
    }
    s.dispose();
  });
}
