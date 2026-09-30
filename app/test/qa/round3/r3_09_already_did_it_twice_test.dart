// ignore_for_file: avoid_print
//
// R3-09. Two things the undo fix and the T02 rebuild left behind.
//
//  1. **"I already did it", twice.** The router credits the week document with
//     a session id keyed to the day, so `WorkoutSessionState.creditSession`
//     refuses the second one. Today's own copy is credited separately, by the
//     view, and nothing dedupes it. So Home and Progress can come apart.
//
//  2. **Leaving T02 while the undo bar is up.** `LogCommandBus.flushAll` is
//     called from `_AlreadyDidItViewState.dispose`, and it closes the pending
//     command, which calls `showUndoSnackBar`'s dismiss, which reaches for
//     `ScaffoldMessengerState` from an element that is already deactivated.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

int _progressSessions() => AppRouter.progressStore.weeks.values
    .fold<int>(0, (a, w) => a + w.sessionsLogged);

String _todayWeek() {
  final w = AppRouter.todayRepository.day.week;
  return '${w.sessionsLogged} of ${w.sessionsTarget}';
}

void main() {
  useShippingApp();

  testWidgets('she logs "I already did it" twice in one day', (t) async {
    phone(t);
    final s = t.ensureSemantics();

    print('=== R3-09 before: today=${_todayWeek()} '
        'progress=${_progressSessions()} ===');

    for (var n = 1; n <= 3; n++) {
      await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
      final chip = find.text('30 min');
      expect(chip.evaluate(), isNotEmpty, reason: 'no 30 min chip on T02');
      await t.tapAt(t.getRect(chip.first).center);
      await settle(t);
      t.takeException();
      print('  tap $n: landed on ${topScreen(t)}, today=${_todayWeek()}, '
          'progress=${_progressSessions()}');
    }

    await open(t, appDestinations['T01']!.name, locale: const Locale('en'));
    print('  T01 says: ${paintedText(t).where((e) => e.contains("of")).join(" // ")}');
    await open(t, appDestinations['P01']!.name, locale: const Locale('en'));
    print('  P01 says: ${paintedText(t).where((e) => e.contains("of")).join(" // ")}');

    expect(
      AppRouter.todayRepository.day.week.sessionsLogged,
      _progressSessions(),
      reason:
          'Home has counted ${_todayWeek()} and Progress has counted '
          '${_progressSessions()} for the same taps',
    );
    expect(
      AppRouter.todayRepository.day.week.sessionsLogged,
      lessThanOrEqualTo(AppRouter.todayRepository.day.week.sessionsTarget),
      reason: 'Home is showing her more sessions than her week has',
    );
    s.dispose();
  });

  testWidgets('she logs, then leaves T02 before the undo bar goes', (t) async {
    phone(t);
    final s = t.ensureSemantics();

    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    await t.tapAt(t.getRect(find.text('30 min').first).center);
    // Deliberately do NOT settle: the undo bar is up and the write is pending.
    await t.pump(const Duration(milliseconds: 200));
    print('=== R3-09 undo bar up, leaving the screen ===');

    // She presses a nav tab while the bar is still on screen, which is what
    // unmounts the view that owns the pending command.
    final home = find.descendant(
      of: find.byType(BottomNavigationBar).evaluate().isEmpty
          ? find.byType(Scaffold)
          : find.byType(BottomNavigationBar),
      matching: find.text('Home'),
    );
    if (home.evaluate().isNotEmpty) {
      await t.tapAt(t.getRect(home.first).center);
    } else {
      nav(t).pop();
    }
    await t.pump(const Duration(milliseconds: 200));
    final err = t.takeException();
    print('  exception on leaving: ${err == null ? "none" : "$err".split("\\n").first}');
    await settle(t);
    final err2 = t.takeException();
    print('  exception after settling: '
        '${err2 == null ? "none" : "$err2".split("\\n").first}');

    expect(
      err,
      isNull,
      reason: 'leaving T02 with the undo bar up throws',
    );
    s.dispose();
  });
}
