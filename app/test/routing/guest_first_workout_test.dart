// D62: a woman with no account may start and finish her FIRST workout. Only a
// finished session uses it up, R10 offers "Keep this workout", her second Start
// asks her to sign in, and nothing else about the guest gate moves.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/app_state/guest_session.dart';
import 'package:own_hub/app_state/snapshot_owner.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/control_counter.dart';
import '../helpers/pause_menu.dart';
import '../helpers/primary_actions.dart';
import '../qa/round1/round1_harness.dart' show topScreen, wipe;

PlannedMove _move() => PlannedMove(
  exerciseId: 'glute_bridge',
  name: 'Glute bridge',
  prescriptionLabel: '3 × 10',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: 'glute_bridge', order: i, reps: 10),
  ],
);

final WorkoutDay _day = WorkoutDay(
  id: 'guest-first',
  title: 'Legs',
  summary: '',
  constraints: '',
  moves: [_move()],
);

FeatureFlags _flags({bool guest = true}) => FeatureFlags.allOff.with_({
  for (final f in Feature.values) f: true,
  Feature.guestFirstWorkout: guest,
});

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  CustomWorkoutState.instance.draft = TodayDraft(
    day: _day,
    dayKey: dayKey(AppClock.now()),
  );
}

BuildContext _context(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first);

/// R03, then Start, as she does it.
Future<void> _startFromR03(WidgetTester tester) async {
  AppRouter.goTo(_context(tester), 'R03');
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(
      AppButton,
      AppL10n.of(_context(tester)).startEverythingsReady,
    ),
  );
  await tester.pumpAndSettle();
}

/// A finished, measured session on the phone, the way a flush leaves it.
Future<void> _finishedSession({bool abandoned = false}) async {
  final repo = AppRouter.trainRepository;
  final session = await repo.startSession(_day);
  await repo.finishSession(
    sessionId: session.id,
    durationSec: 600,
    reason: abandoned ? EndedReason.abandoned : EndedReason.finished,
  );
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = _flags();
    wipe();
    AppRouter.intakeRepository.markSetupDone();
    GuestSession.instance.reset();
    SnapshotOwner.instance.resetForTest();
    AppRouter.lastVerification = null;
  });
  tearDown(() {
    AppRouter.featureFlags = saved;
    CustomWorkoutState.instance.draft = null;
    GuestSession.instance.reset();
    SnapshotOwner.instance.resetForTest();
    wipe();
  });

  group('what counts as her first workout', () {
    test('only a finished, measured session uses it up', () async {
      expect(GuestSession.finishedWorkouts(), 0);
      // A session with nothing logged, or one she discarded, is closed as
      // abandoned by the session state.
      await _finishedSession(abandoned: true);
      expect(GuestSession.finishedWorkouts(), 0, reason: 'abandoned');
      await _finishedSession();
      expect(GuestSession.finishedWorkouts(), 1);
    });

    test(
      'the gate lets a guest into the live screens only while one is open',
      () {
        String? gate(String id, {required bool open}) =>
            AppRouter.gateDestination(
              id,
              gateClosed: true,
              signedIn: false,
              verified: false,
              waitingOnAReviewer: false,
              guestBrowsing: true,
              guestWorkout: open,
            );
        for (final id in GuestSession.workoutScreens) {
          expect(gate(id, open: true), isNull, reason: id);
          expect(gate(id, open: false), appRoutes['C01']!.name, reason: id);
        }
        // Whatever the first workout allows, nothing else opens with it.
        for (final id in const [
          'R05',
          'R12',
          'P01',
          'M01',
          'H01',
          'K07',
          'T02',
        ]) {
          expect(gate(id, open: true), appRoutes['C01']!.name, reason: id);
        }
      },
    );

    testWidgets('no workout open, no live screen: R07 asks her to sign in', (
      tester,
    ) async {
      await _boot(tester);
      expect(GuestSession.mayOpenForFirstWorkout('R07'), isFalse);
      AppRouter.goTo(_context(tester), 'R07');
      await tester.pumpAndSettle();
      expect(find.text('Rahma Mohsen'), findsOneWidget);
      expect(WorkoutSessionState.instance.day, isNull);
    });
  });

  group('a guest', () {
    testWidgets('starts and finishes her first workout with no sign-in', (
      tester,
    ) async {
      await _boot(tester);
      await _startFromR03(tester);

      expect(find.text('Rahma Mohsen'), findsNothing);
      expect(topScreen(tester), 'R07');
      expect(WorkoutSessionState.instance.isLive, isTrue);
      expect(AppRouter.signedInUid, isNull);
      expect(AppRouter.isVerified, isFalse);

      expect(await logWholeMove(tester), isTrue);
      expect(topScreen(tester), 'R10');
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      expect(GuestSession.finishedWorkouts(), 1);
      expect(GuestSession.instance.pending, isNull);
      // The one filled button keeps the workout; Later is a text button; no
      // Done, no share.
      expect(find.byKey(const ValueKey('r10-keep-workout')), findsOneWidget);
      expect(find.byKey(const ValueKey('r10-later')), findsOneWidget);
      expect(find.text('Keep this workout'), findsOneWidget);
      expect(
        find.text('Create your account and this workout counts in your week.'),
        findsOneWidget,
      );
      expect(find.text('Done'), findsNothing);
      expect(find.byKey(const ValueKey('r10-share')), findsNothing);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('"Keep this workout" opens sign-up on the sign-up side', (
      tester,
    ) async {
      await _boot(tester);
      await _startFromR03(tester);
      expect(await logWholeMove(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('r10-keep-workout')));
      await tester.pumpAndSettle();

      expect(find.text('Rahma Mohsen'), findsOneWidget);
      expect(GuestSession.instance.intent, AuthIntent.signUp);
      // The session is already on the phone and finished, not left pending.
      expect(GuestSession.finishedWorkouts(), 1);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('"Later" goes back to Home with the session kept', (
      tester,
    ) async {
      await _boot(tester);
      await _startFromR03(tester);
      expect(await logWholeMove(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      await tester.tap(find.byKey(const ValueKey('r10-later')));
      await tester.pumpAndSettle();

      expect(topScreen(tester), 'T01');
      expect(GuestSession.finishedWorkouts(), 1);
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('her second Start asks her to sign in and keeps the start', (
      tester,
    ) async {
      await _boot(tester);
      await _finishedSession();
      expect(GuestSession.finishedWorkouts(), 1);

      await _startFromR03(tester);

      expect(find.text('Rahma Mohsen'), findsOneWidget);
      expect(GuestSession.instance.pending?.kind, PendingKind.startWorkout);
      expect(WorkoutSessionState.instance.day, isNull);
    });

    testWidgets('after her first, no live screen can start a second', (
      tester,
    ) async {
      await _boot(tester);
      await _finishedSession();
      // Nothing is under way and R10 of that first one is the only live screen.
      expect(GuestSession.mayOpenForFirstWorkout('R07'), isFalse);
      AppRouter.goTo(_context(tester), 'R07');
      await tester.pumpAndSettle();
      expect(find.text('Rahma Mohsen'), findsOneWidget);
      expect(WorkoutSessionState.instance.day, isNull);
    });

    testWidgets('an abandoned first workout leaves her first still to come', (
      tester,
    ) async {
      await _boot(tester);
      await _finishedSession(abandoned: true);
      await _startFromR03(tester);
      expect(find.text('Rahma Mohsen'), findsNothing);
      expect(topScreen(tester), 'R07');
      await tester.pump(const Duration(seconds: 70));
    });

    testWidgets('setup not done: Start asks her to sign in, as before', (
      tester,
    ) async {
      AppRouter.intakeRepository.reset();
      await _boot(tester);
      await _startFromR03(tester);
      expect(find.text('Rahma Mohsen'), findsOneWidget);
      expect(WorkoutSessionState.instance.day, isNull);
    });

    testWidgets('with the switch off she is asked to sign in, as before', (
      tester,
    ) async {
      AppRouter.featureFlags = _flags(guest: false);
      await _boot(tester);
      await _startFromR03(tester);
      expect(find.text('Rahma Mohsen'), findsOneWidget);
      expect(GuestSession.instance.pending?.kind, PendingKind.startWorkout);
      expect(WorkoutSessionState.instance.day, isNull);
    });

    testWidgets('still cannot open coaching, events, scan or chat', (
      tester,
    ) async {
      await _boot(tester);
      await _startFromR03(tester);
      for (final id in const ['H01', 'T09', 'E12', 'P01']) {
        expect(GuestSession.mayOpenForFirstWorkout(id), isFalse, reason: id);
        expect(GuestSession.screens.contains(id), isFalse, reason: id);
      }
      await tester.pump(const Duration(seconds: 70));
    });
  });

  group('R10 for a guest fits the budget', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final scale in const [1.0, 2.0]) {
          testWidgets('${locale.languageCode} ${size.width.toInt()}x'
              '${size.height.toInt()} text x$scale', (tester) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.reset);
            addTearDown(tester.platformDispatcher.clearAllTestValues);
            await _boot(tester);
            await _startFromR03(tester);
            expect(await logWholeMove(tester), isTrue);
            await tester.pump(const Duration(seconds: 6));
            await tester.pumpAndSettle(const Duration(milliseconds: 100));
            // The workout is walked in English (the Pause rows are found by
            // their words); R10 is then read in the language under test.
            LocaleScope.of(_context(tester)).value = locale;
            await tester.pumpAndSettle();

            expect(topScreen(tester), 'R10');
            expect(
              find.byKey(const ValueKey('r10-keep-workout')),
              findsOneWidget,
            );
            expect(tester.takeException(), isNull);
            expect(
              countControlsAboveFold(tester, includeChrome: false),
              lessThanOrEqualTo(5),
            );
            expect(filledPrimaryActions(tester), lessThanOrEqualTo(1));
            await tester.pump(const Duration(seconds: 70));
          });
        }
      }
    }
  });

  group('after she signs up', () {
    testWidgets('the guest session is hers: adopted, not wiped', (
      tester,
    ) async {
      await _boot(tester);
      await _startFromR03(tester);
      expect(await logWholeMove(tester), isTrue);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      final week = AppRouter.progressStore.rewards.sessionsLogged;
      final sessions = AppRouter.trainRepository
          .completedSessions(limit: 10)
          .length;
      expect(week, greaterThan(0));
      expect(sessions, 1);

      // The phone had no owner, so the first sign-in adopts what is on it.
      await SnapshotOwner.instance.load();
      expect(SnapshotOwner.instance.owner, isNull);
      final erased = await SnapshotOwner.instance.claim('uid-guest');
      expect(erased, isFalse);
      expect(SnapshotOwner.instance.owner, 'uid-guest');
      expect(AppRouter.trainRepository.completedSessions(limit: 10).length, 1);
      expect(AppRouter.progressStore.rewards.sessionsLogged, week);

      // And it is in what is saved on the phone, so it syncs once she is
      // verified, under the existing verified-only rule.
      final raw = jsonEncode(AppSnapshot.capture());
      AppRouter.trainRepository.reset();
      expect(GuestSession.finishedWorkouts(), 0);
      AppSnapshot.restore(raw);
      expect(GuestSession.finishedWorkouts(), 1);
      await tester.pump(const Duration(seconds: 70));
    });
  });
}
