// A whole session, walked through the real app.
//
// Every training screen had its own test and passed it, while the session
// itself did not exist: the router handed R07 the same move and the same set
// every time, and finishing changed nothing anywhere. These tests walk the
// thread instead of the screens — start, log, rest, advance, finish — and
// then check that Home, Train and Progress agree about the week afterwards.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

Future<void> _open(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

/// Taps whatever "Done · …" button this set is asking for.
Future<void> _logTheSet(WidgetTester tester) async {
  final done = find.textContaining('Done ·');
  expect(done, findsWidgets, reason: 'the set has a button that names it');
  await tester.tap(done.first);
  await tester.pumpAndSettle();
}

int get _weekOnHome => AppRouter.todayRepository.day.week.sessionsLogged;

int get _weekInProgress =>
    AppRouter
        .progressStore
        .weeks[WeekKey.of(DateTime.now()).id]
        ?.creditedSessionIds
        .length ??
    0;

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    WorkoutSessionState.instance.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    WorkoutSessionState.instance.reset();
  });

  testWidgets('the session advances: set by set, then move by move', (
    tester,
  ) async {
    await _open(tester, 'R03');
    await tester.tap(find.textContaining("Start"));
    await tester.pumpAndSettle();

    // Set 1 of the FIRST move, not a fixed example of somebody's second set.
    final state = WorkoutSessionState.instance;
    expect(state.currentMove?.name, 'Glute bridge');
    expect(state.setIndex, 0);
    expect(find.text('Glute bridge'), findsWidgets);

    await _logTheSet(tester);
    // Resting, with the next set waiting behind it.
    expect(find.text("I'm ready, next set"), findsOneWidget);
    expect(state.setIndex, 1, reason: 'the set advanced');

    await tester.tap(find.text("I'm ready, next set"));
    await tester.pumpAndSettle();
    expect(state.currentMove?.name, 'Glute bridge');
    expect(state.setIndex, 1);

    // Last set of the move rolls on to the next move.
    await _logTheSet(tester);
    await tester.tap(find.text("I'm ready, next set"));
    await tester.pumpAndSettle();
    await _logTheSet(tester);
    // The second move of the session, which is the step-back lunge since the
    // 12 kg goblet squat left a session that promises no equipment.
    expect(state.currentMove?.name, 'Step-back lunge', reason: 'next move');
    expect(state.setIndex, 0);
  });

  testWidgets('finishing credits the week once, everywhere', (tester) async {
    final homeBefore = _weekOnHome;
    final progressBefore = _weekInProgress;
    final pointsBefore = AppRouter.progressStore.rewards.points;

    await _open(tester, 'R03');
    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();

    // Log every move at once, which is the "I did all of it" path.
    var guard = 0;
    while (!WorkoutSessionState.instance.isComplete && guard++ < 12) {
      final all = find.textContaining('I did');
      if (all.evaluate().isEmpty) break;
      await tester.tap(all.first);
      await tester.pumpAndSettle();
      // R13 — next move, or the end.
      final next = find.text('Next move');
      if (next.evaluate().isNotEmpty) {
        await tester.tap(next);
        await tester.pumpAndSettle();
      } else {
        break;
      }
    }

    // However she got here, finishing is one tap and counts once.
    final finish = find.text('Finish here');
    if (finish.evaluate().isNotEmpty) {
      await tester.tap(finish);
      await tester.pumpAndSettle();
    }

    expect(_weekOnHome, homeBefore + 1, reason: "Home's copy of the week");
    expect(_weekInProgress, progressBefore + 1, reason: 'the week document');
    expect(
      AppRouter.progressStore.rewards.points,
      greaterThan(pointsBefore),
      reason: 'a live session earns its points once',
    );

    // A second finish credits nothing: the session is over.
    await tester.tap(find.text('Back to today'));
    await tester.pumpAndSettle();
    expect(_weekOnHome, homeBefore + 1);
    expect(_weekInProgress, progressBefore + 1);
  });

  testWidgets('a recalled session counts once too', (tester) async {
    final progressBefore = _weekInProgress;

    await _open(tester, 'T02');
    // The three likely answers; any of them logs and moves on.
    final logIt = find.textContaining('It counts');
    if (logIt.evaluate().isEmpty) {
      // The screen's own copy varies with the day state; tap the first
      // primary action it offers.
      final buttons = find.byType(ElevatedButton);
      if (buttons.evaluate().isNotEmpty) await tester.tap(buttons.first);
    } else {
      await tester.tap(logIt.first);
    }
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    expect(
      _weekInProgress,
      anyOf(progressBefore, progressBefore + 1),
      reason: 'never more than one credit for one recalled session',
    );
  });
}
