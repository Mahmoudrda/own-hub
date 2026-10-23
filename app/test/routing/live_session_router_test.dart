// A live session through the real router: the language switch relabels it, and
// "Skip this move" behaves the same on R05 as on R06, and skipping every move
// with nothing logged ends the session uncounted, back where it started.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

Future<void> _boot(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  _nav(tester).pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

String? _topRoute(WidgetTester tester) {
  String? name;
  _nav(tester).popUntil((route) {
    name = route.settings.name;
    return true;
  });
  return name;
}

bool _hasArabic(String text) => RegExp(r'[؀-ۿ]').hasMatch(text);

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    WorkoutSessionState.instance.reset();
    // An empty library offers no swap for any move, so R05 always shows the
    // skip button these tests tap.
    ExerciseLibraryState.instance.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    WorkoutSessionState.instance.reset();
    ExerciseLibraryState.instance.reset();
    CustomWorkoutState.instance.draft = null;
  });

  testWidgets('a session started in English reads in Arabic after the switch', (
    tester,
  ) async {
    await _boot(tester, 'R03');
    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();

    final session = WorkoutSessionState.instance;
    expect(session.isLive, isTrue);
    final englishTitle = session.day!.title;
    expect(_hasArabic(englishTitle), isFalse);

    LocaleScope.of(tester.element(find.byType(Navigator).first))
        .value = const Locale(
      'ar',
    );
    await tester.pumpAndSettle();

    expect(session.day!.title, isNot(englishTitle));
    expect(_hasArabic(session.day!.title), isTrue);

    // R05, R09 and R13 read the same day, so their set lines are Arabic too.
    expect(session.day!.moves.first.name, isNotEmpty);
    expect(
      _hasArabic(session.day!.moves.first.prescriptionLabel) ||
          _hasArabic(session.day!.moves.first.name),
      isTrue,
    );
  });

  testWidgets('R05 skip with no alternatives moves on, like R06', (
    tester,
  ) async {
    await _boot(tester, 'R03');
    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();

    final session = WorkoutSessionState.instance;
    final before = session.moveIndex;
    _nav(tester).pushNamed(appDestinations['R05']!.name);
    await tester.pumpAndSettle();

    final skip = find.byKey(const ValueKey('r05-skip-move'));
    expect(skip, findsOneWidget);
    await tester.tap(skip);
    await tester.pumpAndSettle();
    expect(session.moveIndex, before + 1);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('skipping every move with nothing logged leaves uncounted', (
    tester,
  ) async {
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    final origin = _topRoute(tester);
    _nav(tester).pushNamed(appDestinations['R03']!.name);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Start'));
    await tester.pumpAndSettle();

    final session = WorkoutSessionState.instance;
    final weekBefore = AppRouter.progressStore.rewards.sessionsLogged;
    final skip = find.byKey(const ValueKey('r05-skip-move'));
    var guard = 0;
    // Short pumps, not pumpAndSettle: a follow-along hold would otherwise run
    // its countdown out and log the set itself.
    while (session.isLive && guard++ < 20) {
      // A follow-along move is closed first, so its clock cannot run out
      // under the skip.
      if (_topRoute(tester) == appDestinations['R06']!.name) {
        _nav(tester).pop();
        await tester.pump(const Duration(milliseconds: 600));
      }
      _nav(tester).pushNamed(appDestinations['R05']!.name);
      for (var i = 0; i < 8 && skip.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(skip, findsOneWidget, reason: 'move ${session.moveIndex}');
      await tester.tap(skip, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pumpAndSettle();

    expect(session.isLive, isFalse);
    expect(session.loggedSetCount, 0);
    expect(AppRouter.progressStore.rewards.sessionsLogged, weekBefore);
    expect(_topRoute(tester), origin);
    expect(
      find.text('Nothing logged, so this one is not counted.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('one move of three sets rests once per set and ends on R10', (
    tester,
  ) async {
    await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
    await tester.pumpAndSettle();
    final origin = _topRoute(tester);
    final session = WorkoutSessionState.instance;
    CustomWorkoutState.instance.draft = TodayDraft(
      day: _oneMoveDay,
      dayKey: dayKey(AppClock.now()),
    );
    // Opened the way Home's first-week step opens it: straight to the set
    // screen, with no workout started on R03.
    AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
    await tester.pumpAndSettle();
    expect(session.isLive, isTrue);
    expect(find.text('1 of 3'), findsOneWidget);

    final done = find.textContaining('Done');
    for (var set = 1; set <= 3; set++) {
      await tester.tap(done);
      // A few frames: the looping screens must settle on one resting screen.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      if (set < 3) {
        expect(_topRoute(tester), appDestinations['R09']!.name);
        expect(
          find.byType(RestingView, skipOffstage: false),
          findsNWidgets(set),
          reason: 'one rest screen per logged set, none re-pushed',
        );
        expect(session.setIndex, set);
        // The clock counts down instead of sitting at 1:00.
        await tester.pump(const Duration(seconds: 3));
        expect(find.text('1:00'), findsNothing);
        await tester.tap(find.text("I'm ready, next set"));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(_topRoute(tester), appDestinations['R07']!.name);
        expect(find.text('${set + 1} of 3'), findsOneWidget);
      }
    }
    // The last set ends the workout on R10 once, never on R03 with "0 of 0".
    await tester.pump(const Duration(seconds: 2));
    expect(_topRoute(tester), isNot(origin));
    expect(session.isLive, isFalse);
    expect(find.text('0 of 0'), findsNothing);
    await tester.pump(const Duration(seconds: 70));
    expect(find.byType(MidSetView), findsNothing);
  });

  testWidgets(
    'R05, R09 and R13 read their set lines in the language on screen',
    (tester) async {
      await _boot(tester, 'R03');
      await tester.tap(find.textContaining('Start'));
      await tester.pumpAndSettle();
      LocaleScope.of(tester.element(find.byType(Navigator).first))
          .value = const Locale(
        'ar',
      );
      await tester.pumpAndSettle();

      for (final id in ['R05', 'R13', 'R09']) {
        _nav(tester).pushNamed(appDestinations[id]!.name);
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        final shown = [
          for (final text in tester.widgetList<Text>(find.byType(Text)))
            if (text.data != null) text.data!,
          for (final text in tester.widgetList<RichText>(find.byType(RichText)))
            text.text.toPlainText(),
        ];
        // No set line is left in English: every "×" line has Arabic in it.
        final lines = shown.where((t) => t.contains('×')).toList();
        if (id != 'R09') expect(lines, isNotEmpty, reason: id);
        for (final line in lines) {
          expect(_hasArabic(line), isTrue, reason: '$id: $line');
        }
      }
      await tester.pump(const Duration(seconds: 70));
    },
  );

  group('ending the workout from inside it', () {
    const end = ValueKey('session-end');

    /// Home, then R03 and its Start, so R07 is on top of a live session.
    Future<String?> startFromR03(WidgetTester tester) async {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      final origin = _topRoute(tester);
      _nav(tester).pushNamed(appDestinations['R03']!.name);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Start'));
      await tester.pumpAndSettle();
      expect(WorkoutSessionState.instance.isLive, isTrue);
      return origin;
    }

    /// A few short frames: a rest screen keeps a clock running, so the page
    /// cannot be settled, and one long frame would stop mid-transition.
    Future<void> frames(WidgetTester tester) async {
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
    }

    Future<void> logOneSet(WidgetTester tester) async {
      await tester.tap(find.textContaining('Done'));
      await frames(tester);
      expect(_topRoute(tester), appDestinations['R09']!.name);
    }

    testWidgets(
      'the control is on R03 and R05 to R09 while a workout is live',
      (tester) async {
        await startFromR03(tester);
        for (final id in ['R03', 'R05', 'R06', 'R07', 'R08', 'R09', 'R13']) {
          _nav(tester).pushNamed(appDestinations[id]!.name);
          await frames(tester);
          // R08 draws its own sheet over the page, so its control is there
          // but behind the sheet's scrim until the sheet is put away.
          final found = id == 'R08'
              ? find.byKey(end)
              : find.byKey(end).hitTestable();
          expect(found, findsOneWidget, reason: id);
        }
        await tester.pump(const Duration(seconds: 70));
      },
    );

    testWidgets('the control is not drawn with no workout live', (
      tester,
    ) async {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      expect(WorkoutSessionState.instance.isLive, isFalse);
      for (final id in ['R03', 'R05', 'R06', 'R07', 'R08', 'R09', 'R13']) {
        _nav(tester).pushNamed(appDestinations[id]!.name);
        await frames(tester);
        expect(find.byKey(end), findsNothing, reason: id);
      }
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('Finish and save counts the workout and opens R10', (
      tester,
    ) async {
      await startFromR03(tester);
      final before = AppRouter.progressStore.rewards.sessionsLogged;
      await logOneSet(tester);

      await tester.tap(find.byKey(end));
      await tester.pumpAndSettle();
      expect(find.text('Sets saved so far: 1'), findsOneWidget);
      await tester.tap(find.text('Finish and save'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(_topRoute(tester), appDestinations['R10']!.name);
      expect(WorkoutSessionState.instance.isLive, isFalse);
      expect(AppRouter.progressStore.rewards.sessionsLogged, before + 1);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('Discard with sets logged counts nothing and goes back', (
      tester,
    ) async {
      final origin = await startFromR03(tester);
      final before = AppRouter.progressStore.rewards.sessionsLogged;
      await logOneSet(tester);

      await tester.tap(find.byKey(end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard this workout'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(WorkoutSessionState.instance.isLive, isFalse);
      expect(AppRouter.progressStore.rewards.sessionsLogged, before);
      expect(_topRoute(tester), origin);
      expect(
        find.text('Workout discarded. It is not counted.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('with nothing logged only Discard is offered, and it is not '
        'counted', (tester) async {
      final origin = await startFromR03(tester);
      final before = AppRouter.progressStore.rewards.sessionsLogged;

      await tester.tap(find.byKey(end));
      await tester.pumpAndSettle();
      expect(find.text('Finish and save'), findsNothing);
      await tester.tap(find.text('Discard this workout'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(WorkoutSessionState.instance.isLive, isFalse);
      expect(AppRouter.progressStore.rewards.sessionsLogged, before);
      expect(_topRoute(tester), origin);
      expect(
        find.text('Nothing logged, so this one is not counted.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('Back on R03 with a pending edit asks only how to end the '
        'workout', (tester) async {
      tester.view.physicalSize = const Size(1170, 4200);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await startFromR03(tester);
      await logOneSet(tester);

      // The day she is training is a workout of hers, so R03 would ask whether
      // to update it.
      CustomWorkoutState.instance.pin(
        WorkoutSessionState.instance.day!,
        customId: 'mine1',
      );
      _nav(tester).pushNamed(appDestinations['R03']!.name);
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('r03-edit-toggle')));
      await frames(tester);
      await tester.tap(find.byKey(const ValueKey('r03-remove-0')));
      await frames(tester);
      expect(find.text('Donkey kick'), findsNothing);
      await tester.pump(const Duration(seconds: 6));

      unawaited(_nav(tester).maybePop());
      await frames(tester);

      expect(find.text('Finish and save'), findsOneWidget);
      expect(find.text('Update my saved workout?'), findsNothing);
      expect(find.text('Update my plan?'), findsNothing);
      await tester.tap(find.text('Keep going'));
      await frames(tester);
      expect(WorkoutSessionState.instance.isLive, isTrue);
      expect(_topRoute(tester), appDestinations['R03']!.name);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('Keep going leaves the workout as it was', (tester) async {
      await startFromR03(tester);
      await logOneSet(tester);
      await tester.tap(find.byKey(end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(WorkoutSessionState.instance.isLive, isTrue);
      expect(_topRoute(tester), appDestinations['R09']!.name);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('close sends her to the sheet once a set is logged', (
      tester,
    ) async {
      await startFromR03(tester);
      // Nothing logged yet: close simply leaves the screen.
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(_topRoute(tester), appDestinations['R03']!.name);
      await tester.tap(find.textContaining('Start'));
      await tester.pumpAndSettle();
      expect(_topRoute(tester), appDestinations['R07']!.name);

      await logOneSet(tester);
      await tester.tap(find.byTooltip('Close'));
      await frames(tester);
      expect(find.text('Finish and save'), findsOneWidget);
      await tester.tap(find.text('Keep going'));
      await frames(tester);
      expect(_topRoute(tester), appDestinations['R09']!.name);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('Back from R05 leaves it freely once a set is logged', (
      tester,
    ) async {
      await startFromR03(tester);
      await logOneSet(tester);
      _nav(tester).pushNamed(appDestinations['R05']!.name);
      await frames(tester);
      expect(_topRoute(tester), appDestinations['R05']!.name);
      await _nav(tester).maybePop();
      await frames(tester);
      expect(find.text('Finish and save'), findsNothing);
      expect(_topRoute(tester), appDestinations['R09']!.name);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('closing R08 after the change sheet leaves it freely', (
      tester,
    ) async {
      await startFromR03(tester);
      await logOneSet(tester);
      _nav(tester).pushNamed(appDestinations['R08']!.name);
      await frames(tester);
      expect(_topRoute(tester), isNot(appDestinations['R09']!.name));
      // Put the change sheet away without saving.
      await tester.tapAt(const Offset(10, 10));
      await frames(tester);
      expect(find.text('Finish and save'), findsNothing);
      expect(find.text('Keep going'), findsNothing);
      expect(_topRoute(tester), appDestinations['R09']!.name);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('Back from R10 after finishing on R07 shows no sample set', (
      tester,
    ) async {
      final origin = await startFromR03(tester);
      await logOneSet(tester);
      await tester.tap(find.text("I'm ready, next set"));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(_topRoute(tester), appDestinations['R07']!.name);
      await tester.tap(find.byKey(end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and save'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_topRoute(tester), appDestinations['R10']!.name);

      _nav(tester).pop();
      await frames(tester);
      expect(find.textContaining('Donkey kick'), findsNothing);
      expect(find.byType(MidSetView), findsNothing);
      expect(_topRoute(tester), isNot(appDestinations['R07']!.name));
      expect(_topRoute(tester), isNot(appDestinations['R10']!.name));
      expect(origin, isNotNull);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('a second workout opened on R07 after a finished one still '
        'runs', (tester) async {
      await startFromR03(tester);
      await logOneSet(tester);
      await tester.tap(find.byKey(end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and save'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_topRoute(tester), appDestinations['R10']!.name);
      expect(WorkoutSessionState.instance.isLive, isFalse);

      AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(WorkoutSessionState.instance.isLive, isTrue);
      expect(_topRoute(tester), appDestinations['R07']!.name);
      expect(find.byType(MidSetView), findsOneWidget);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets("R09 counts the plan's rest for the move she just did", (
      tester,
    ) async {
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await tester.pumpAndSettle();
      CustomWorkoutState.instance.draft = TodayDraft(
        day: _ninetySecondRestDay,
        dayKey: dayKey(AppClock.now()),
      );
      AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Done'));
      await frames(tester);
      expect(_topRoute(tester), appDestinations['R09']!.name);
      expect(
        WorkoutSessionState.instance.restDuration,
        const Duration(seconds: 90),
      );
      expect(find.textContaining('1:2'), findsWidgets);
      await tester.pump(const Duration(seconds: 100));
    });

    group('Discard after a set that beats a best', () {
      const old = PersonalBest(
        exerciseId: 'glute_bridge',
        metric: BestMetric.reps,
        dateKey: '2026-01-01',
        sessionId: 'earlier',
        reps: 5,
      );

      setUp(() => AppRouter.progressStore.bests['glute_bridge'] = old);
      tearDown(() => AppRouter.progressStore.bests.remove('glute_bridge'));

      /// R07 on a one-move day of glute bridges, a workout live, one set done.
      Future<void> oneBridgeSet(WidgetTester tester) async {
        await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
        await tester.pumpAndSettle();
        CustomWorkoutState.instance.draft = TodayDraft(
          day: _bridgeDay,
          dayKey: dayKey(AppClock.now()),
        );
        AppRouter.goTo(tester.element(find.byType(Scaffold).first), 'R07');
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Done'));
        await frames(tester);
        expect(_topRoute(tester), appDestinations['R09']!.name);
      }

      /// Short pumps only, so the set's undo window has not run out.
      Future<void> discard(WidgetTester tester) async {
        await tester.tap(find.byKey(end));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.tap(find.text('Discard this workout'));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
      }

      void expectUntouched() {
        final held = AppRouter.progressStore.bests['glute_bridge'];
        expect(held?.reps, 5);
        expect(held?.dateKey, '2026-01-01');
      }

      testWidgets('while the last set is still waiting to be written', (
        tester,
      ) async {
        AppRouter.todayRepository.reset();
        await oneBridgeSet(tester);
        final points = AppRouter.progressStore.rewards.points;
        final count = AppRouter.progressStore.rewards.bestsCount;
        final ledger = AppRouter.personalBestLedger.bestsCount;
        expect(
          AppRouter.trainRepository.flushes.where(
            (f) => f.sessionId == WorkoutSessionState.instance.sessionId,
          ),
          isEmpty,
          reason: 'the set is still inside its undo window',
        );
        await discard(tester);
        expectUntouched();
        expect(AppRouter.progressStore.rewards.points, points);
        expect(AppRouter.progressStore.rewards.bestsCount, count);
        expect(AppRouter.personalBestLedger.bestsCount, ledger);
        expect(
          AppRouter.todayRepository.day.arc.completed,
          isNot(contains(FirstWeekStep.logSet)),
          reason: 'a discarded workout completes no first-week step',
        );
        await tester.pump(const Duration(seconds: 10));
      });

      testWidgets('after the set was already written and paid', (tester) async {
        await oneBridgeSet(tester);
        final points = AppRouter.progressStore.rewards.points;
        final count = AppRouter.progressStore.rewards.bestsCount;
        final ledger = AppRouter.personalBestLedger.bestsCount;
        // Past the undo window, so the set is written and the best paid.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(seconds: 1));
        }
        expect(
          AppRouter.progressStore.bests['glute_bridge'],
          isNot(same(old)),
          reason: 'the set did beat her best before she discarded',
        );
        await discard(tester);
        expectUntouched();
        expect(AppRouter.progressStore.rewards.points, points);
        expect(AppRouter.progressStore.rewards.bestsCount, count);
        expect(AppRouter.personalBestLedger.bestsCount, ledger);
        await tester.pump(const Duration(seconds: 10));
      });
    });

    testWidgets(
      'a rest left behind after the finish does not reopen the move',
      (tester) async {
        await startFromR03(tester);
        await logOneSet(tester);
        await tester.tap(find.byKey(end));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finish and save'));
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(_topRoute(tester), appDestinations['R10']!.name);

        // Back from the finish screen lands on the rest she left behind.
        _nav(tester).pop();
        await tester.pumpAndSettle();
        expect(_topRoute(tester), appDestinations['R09']!.name);
        await tester.tap(find.text("I'm ready, next set"));
        await tester.pumpAndSettle();
        expect(find.byType(MidSetView), findsNothing);
        expect(WorkoutSessionState.instance.isLive, isFalse);
        await tester.pump(const Duration(seconds: 70));
      },
    );
  });
}

const _bridgeDay = WorkoutDay(
  id: 'one-bridge',
  title: 'Glutes',
  summary: '5 minutes, 1 move',
  constraints: 'Quiet · no equipment · floor',
  moves: [
    PlannedMove(
      exerciseId: 'glute_bridge',
      name: 'Glute bridge',
      prescriptionLabel: '3 × 12 · bodyweight',
      sets: [
        PrescribedSet(exerciseId: 'glute_bridge', order: 1, reps: 12),
        PrescribedSet(exerciseId: 'glute_bridge', order: 2, reps: 12),
        PrescribedSet(exerciseId: 'glute_bridge', order: 3, reps: 12),
      ],
    ),
  ],
);

const _ninetySecondRestDay = WorkoutDay(
  id: 'ninety',
  title: 'Legs and glutes',
  summary: '5 minutes, 1 move',
  constraints: 'Quiet · no equipment · floor',
  moves: [
    PlannedMove(
      exerciseId: 'donkey_kick',
      name: 'Donkey kick',
      prescriptionLabel: '3 × 12 · Rest 90 seconds',
      restSeconds: 90,
      sets: [
        PrescribedSet(exerciseId: 'donkey_kick', order: 1, reps: 12),
        PrescribedSet(exerciseId: 'donkey_kick', order: 2, reps: 12),
        PrescribedSet(exerciseId: 'donkey_kick', order: 3, reps: 12),
      ],
    ),
  ],
);

const _oneMoveDay = WorkoutDay(
  id: 'one-move',
  title: 'Legs and glutes',
  summary: '5 minutes, 1 move',
  constraints: 'Quiet · no equipment · floor',
  moves: [
    PlannedMove(
      exerciseId: 'donkey_kick',
      name: 'Donkey kick',
      prescriptionLabel: '3 × 12 · bodyweight',
      sets: [
        PrescribedSet(exerciseId: 'donkey_kick', order: 1, reps: 12),
        PrescribedSet(exerciseId: 'donkey_kick', order: 2, reps: 12),
        PrescribedSet(exerciseId: 'donkey_kick', order: 3, reps: 12),
      ],
    ),
  ],
);
