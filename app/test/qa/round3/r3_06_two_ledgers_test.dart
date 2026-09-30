// ignore_for_file: avoid_print
//
// R3-06. Home and Progress keep two separate copies of her week. Do they agree?
//
// `today.day.week` is what Home and Train draw; `progressStore.weeks[key]` is
// what Progress draws. `WorkoutSessionState.creditSession` is the one function
// that writes both, and it writes them from two different branches. A product
// whose documented favourite failure is "fixed one of several identical
// instances" should have this checked rather than assumed.
//
// Also: what happens when she does the same thing twice quickly.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/features/train/domain/train_repository.dart' show SessionSource;
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

List<String> _counts(WidgetTester t) => paintedText(t)
    .where((e) => RegExp(r'\d+\s*(of|/|من)\s*\d+').hasMatch(e))
    .toList();

void main() {
  useShippingApp();

  testWidgets('one real session, and every screen agrees', (t) async {
    phone(t);
    final s = t.ensureSemantics();

    await open(t, appDestinations['O03']!.name, locale: const Locale('en'));
    await t.tapAt(t.getRect(find.text('4').first).center);
    await settle(t);
    await tapControl(t, RegExp('Continue'));
    OnboardingState.instance.finish();

    WorkoutSessionState.creditSession(
      sessionId: 'r3-session-1',
      source: SessionSource.live,
      today: AppRouter.todayRepository,
      progress: AppRouter.progressStore,
    );

    final today = AppRouter.todayRepository.day.week;
    final key = AppRouter.progressStore.weeks.keys.toList();
    print('=== R3-06 after one real session (target 4) ===');
    print('  today copy    : ${today.sessionsLogged} of ${today.sessionsTarget}');
    print('  progress weeks: $key -> '
        '${AppRouter.progressStore.weeks.values.map((w) => "${w.sessionsLogged}/${w.sessionsTarget}").join(",")}');

    for (final id in <String>['T01', 'R01', 'P01']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      print('  $id: ${_counts(t).join(" // ")}');
    }

    expect(
      AppRouter.progressStore.weeks.values.first.sessionsLogged,
      today.sessionsLogged,
      reason: 'Progress and Home disagree about how many sessions she has done',
    );
    expect(
      AppRouter.progressStore.weeks.values.first.sessionsTarget,
      today.sessionsTarget,
      reason: 'Progress and Home disagree about what her week is',
    );
    s.dispose();
  });

  // The same session twice, quickly. A double tap on "Done" is the single
  // commonest thing a woman does to a button that does not visibly respond.
  testWidgets('the same session credited twice counts once', (t) async {
    phone(t);
    OnboardingState.instance.finish();
    for (var i = 0; i < 2; i++) {
      WorkoutSessionState.creditSession(
        sessionId: 'r3-double',
        source: SessionSource.live,
        today: AppRouter.todayRepository,
        progress: AppRouter.progressStore,
      );
    }
    final week = AppRouter.todayRepository.day.week;
    print('=== R3-06 double credit: ${week.sessionsLogged} of '
        '${week.sessionsTarget}, points='
        '${AppRouter.progressStore.rewards.points}, sessionsLogged='
        '${AppRouter.progressStore.rewards.sessionsLogged} ===');
    expect(week.sessionsLogged, 1, reason: 'a double tap counted twice');
    expect(AppRouter.progressStore.rewards.sessionsLogged, 1);
  });

  // T02's "I already did it" is the other doubled tap, and it goes through a
  // different branch (creditToday: false).
  testWidgets('T02 "I already did it", tapped twice quickly', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    OnboardingState.instance.finish();

    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    print('=== R3-06 T02 controls: '
        '${tappables(t).map((e) => e.label).join(" // ")} ===');
    final before = AppRouter.progressStore.weeks.values
        .fold<int>(0, (a, w) => a + w.sessionsLogged);

    final hit = await tapControl(t, RegExp('already did it'));
    print('  first tap reached the control? $hit  -> ${topScreen(t)}');
    // Straight back and again, the way a woman who is not sure it worked does.
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    final hit2 = await tapControl(t, RegExp('already did it'));
    print('  second tap reached the control? $hit2 -> ${topScreen(t)}');

    final after = AppRouter.progressStore.weeks.values
        .fold<int>(0, (a, w) => a + w.sessionsLogged);
    final todayCopy = AppRouter.todayRepository.day.week;
    print('  progress sessions: $before -> $after');
    print('  today copy: ${todayCopy.sessionsLogged} of '
        '${todayCopy.sessionsTarget}');
    await open(t, appDestinations['P01']!.name, locale: const Locale('en'));
    print('  P01: ${_counts(t).join(" // ")}');
    await open(t, appDestinations['T01']!.name, locale: const Locale('en'));
    print('  T01: ${_counts(t).join(" // ")}');
    s.dispose();
  });
}
