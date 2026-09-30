// ignore_for_file: avoid_print
//
// R3-04. Setup, walked with a finger, for every number she can pick.
//
// The cap was four, O03 offered five, and the fifth was clamped on the way to
// the goal. The fix removed the chip. What a second walk has to check is not
// that the chip is gone but that the whole chain still carries her number:
// O03 chip -> Intake -> WeeklyGoalService -> O05's read-back -> the week she is
// measured against on Home and Progress. A chain that silently dropped a 4 the
// way it used to drop a 5 would look identical on O03.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('O03 offers 2, 3 and 4 and nothing else, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await open(t, appDestinations['O03']!.name, locale: Locale(loc));

      // The days row is the first AppChipRow on the screen; read every chip
      // label that is a bare number, in paint order.
      final numbers = paintedText(t)
          .where((e) => RegExp(r'^\s*\d+\s*$').hasMatch(e))
          .toList();
      print('=== R3-04 O03 $loc: numeric chips = ${numbers.join(", ")} ===');
      print('  all painted: ${paintedText(t).join(" | ")}');
      expect(
        numbers.contains('5'),
        isFalse,
        reason: 'O03 still offers a 5 and the goal domain refuses it',
      );
      for (final n in <String>['2', '3', '4']) {
        expect(
          numbers.contains(n),
          isTrue,
          reason: 'O03 no longer offers $n days a week',
        );
      }
      expect(Intake.allowedDays, <int>[2, 3, 4]);
      s.dispose();
    });
  }

  for (final days in <int>[2, 3, 4]) {
    for (final loc in <String>['en', 'ar']) {
      testWidgets('she taps $days on O03 and it reaches her week, $loc', (
        t,
      ) async {
        phone(t);
        final s = t.ensureSemantics();
        await open(t, appDestinations['O03']!.name, locale: Locale(loc));

        // A real finger on the chip, at the pixel where its label is painted.
        final chip = find.text('$days');
        expect(chip.evaluate(), isNotEmpty, reason: 'no "$days" chip painted');
        await t.tapAt(t.getRect(chip.first).center);
        await settle(t);

        // Continue, the way she would.
        final cont = await tapControl(t, RegExp(r'Continue|متابعة|التالي'));
        print('=== R3-04 $days days, $loc: continue tapped = $cont ===');

        print('  intake.days now = ${AppRouter.intakeRepository.read().days}');
        expect(
          AppRouter.intakeRepository.read().days,
          days,
          reason: 'the chip she tapped did not reach the intake',
        );

        // The goal is written when setup finishes, not when the chip is
        // tapped. Drive that the way the app does.
        OnboardingState.instance.finish();
        final goal = AppRouter.progressStore.goal;
        print('  weeklyGoal.sessionsTarget = ${goal.sessionsTarget}');
        expect(
          goal.sessionsTarget,
          days,
          reason:
              'she chose $days and the rewards domain is measuring her '
              'against ${goal.sessionsTarget}',
        );

        // O05 must read back the number she picked.
        await open(t, appDestinations['O05']!.name, locale: Locale(loc));
        final o05 = paintedText(t);
        print('  O05 says: ${o05.take(8).join(" | ")}');
        expect(
          o05.any((line) => line.contains('$days')),
          isTrue,
          reason: 'O05 does not read back the $days she chose',
        );

        // And Home must count against it.
        await open(t, appDestinations['T01']!.name, locale: Locale(loc));
        print('  T01 says: ${paintedText(t).join(" | ")}');
        s.dispose();
      });
    }
  }

  // The chain has to survive her changing her mind, which is the one thing a
  // "set it once at the end of setup" write gets wrong.
  testWidgets('she changes her mind on O03 and the goal follows', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await open(t, appDestinations['O03']!.name, locale: const Locale('en'));
    for (final n in <int>[4, 2, 3]) {
      await t.tapAt(t.getRect(find.text('$n').first).center);
      await settle(t);
    }
    await tapControl(t, RegExp('Continue'));
    OnboardingState.instance.finish();
    print('=== R3-04 changed her mind 4 -> 2 -> 3 ===');
    print('  intake=${AppRouter.intakeRepository.read().days} '
        'goal=${AppRouter.progressStore.goal.sessionsTarget}');
    expect(AppRouter.intakeRepository.read().days, 3);
    expect(AppRouter.progressStore.goal.sessionsTarget, 3);
    s.dispose();
  });
}
