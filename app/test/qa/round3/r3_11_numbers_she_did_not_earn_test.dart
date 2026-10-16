// ignore_for_file: avoid_print
//
// R3-11. The documented favourite failure, hunted a fifth time.
//
// The fix pass removed four invented facts: a frozen Monday, a trophy on the
// first session, a meal she never logged, and a Thursday session it wrote into
// her log. Three of those were on screens that state a number beside a label.
// So: walk every screen that states one, with a brand-new phone, and compare
// what it says against what she has actually done.
//
// Three specific suspects, each one a line the fix pass touched and left:
//
//   * `FirstWeekView.points` defaults to 90 and `level` to 2, and the router
//     (T07 and T08) passes neither. The same pass replaced the fixed *string*
//     `n35PointsSoFar` three lines above `widget.points` because it was a
//     number she had not earned.
//   * `oneMoreSessionAndThisWeekCounts` is printed unconditionally on R10 and
//     R12, under a segment bar that draws her real count.
//   * T04's "A rest week covered last week" is unconditional, and T04 has a
//     route.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/features/train/domain/train_repository.dart'
    show SessionSource;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('T07 and T08 state her points and level, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      for (final id in <String>['T07', 'T08']) {
        await open(t, appDestinations[id]!.name, locale: Locale(loc));
        final painted = paintedText(t);
        print('=== R3-11 $id $loc ===');
        print(
          '  real points = ${AppRouter.progressStore.rewards.points}, '
          'real level = ${AppRouter.progressStore.rewards.level}',
        );
        print('  screen says: ${painted.join(" | ")}');
        expect(
          painted.contains('90'),
          isFalse,
          reason:
              '$id tells a woman with '
              '${AppRouter.progressStore.rewards.points} points that she has 90',
        );
      }
      s.dispose();
    });
  }

  testWidgets('R10 and R12 tell her how many sessions are left', (t) async {
    phone(t);
    final s = t.ensureSemantics();

    // She chose four a week.
    await open(t, appDestinations['O03']!.name, locale: const Locale('en'));
    await t.tapAt(t.getRect(find.text('4').first).center);
    await settle(t);
    await tapControl(t, RegExp('Continue'));
    OnboardingState.instance.finish();

    for (var done = 0; done <= 4; done++) {
      if (done > 0) {
        WorkoutSessionState.creditSession(
          sessionId: 'r3-11-$done',
          source: SessionSource.live,
          today: AppRouter.todayRepository,
          progress: AppRouter.progressStore,
        );
      }
      for (final id in <String>['R10', 'R12']) {
        await open(t, appDestinations[id]!.name, locale: const Locale('en'));
        final painted = paintedText(t);
        final week = painted.where((e) => e.contains('of')).join(' / ');
        final claim = painted
            .where((e) => e.contains('One more session'))
            .toList();
        print(
          '  $id  done=$done  week="$week"  '
          'says "one more"? ${claim.isNotEmpty}',
        );

        // At 1 of 4 the true sentence is "three more". Anything that says one
        // is stating a fact about her week that is not true — so the sentence
        // may appear at exactly one remaining and nowhere else. R12 had this
        // guard already; R10, the screen she sees the moment she finishes a
        // workout, printed it at 0, 1, 2, 3 and 4 remaining.
        expect(
          claim.isNotEmpty,
          AppRouter.progressStore.goal.sessionsTarget - done == 1,
          reason:
              '$id with $done of 4 done says '
              '${claim.isEmpty ? "nothing" : claim.first}',
        );
      }
    }

    s.dispose();
  });

  for (final loc in <String>['en', 'ar']) {
    testWidgets('T04 on day one, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();

      // Can she get there at all on day one?
      await open(t, appDestinations['P01']!.name, locale: Locale(loc));
      final p01 = tappables(t).map((e) => e.label).toList();
      print('=== R3-11 P01 day one, $loc ===');
      print('  controls: ${p01.join(" // ")}');
      print(
        '  restWeeksBanked = '
        '${AppRouter.progressStore.goal.restWeeksBanked}, '
        'countedWeeks = ${AppRouter.progressStore.goal.countedWeeks}',
      );

      await open(t, appDestinations['T04']!.name, locale: Locale(loc));
      final painted = paintedText(t);
      print('  T04 by route on day one says:');
      for (final line in painted) {
        print('    | $line');
      }

      // Two taps from Progress on a phone switched on this morning. The rest
      // week card was unconditional, so it told her a rest week had covered a
      // week she was not here for. It is now drawn only when
      // `weeklyGoal.lastRepairedWeek` names one, and the router wires the goal.
      final l10n = AppL10n.of(t.element(find.byType(Navigator).first));
      expect(
        painted.any((line) => line.contains(l10n.aRestWeekCoveredLastWeekSo)),
        isFalse,
        reason:
            'restWeeksBanked = '
            '${AppRouter.progressStore.goal.restWeeksBanked}, countedWeeks = '
            '${AppRouter.progressStore.goal.countedWeeks}: there is no repair '
            'to report on day one',
      );
      s.dispose();
    });
  }
}
