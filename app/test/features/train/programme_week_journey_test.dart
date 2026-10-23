// Her programme in the running app: R02 lists her week, R03 opens today's
// session of it, and the first-gym guide comes once before a gym session.
//
// Built through the real router and the real plans, so the wiring is what is
// tested, not a screen handed a list.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/first_gym_guide_state.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/train_widgets.dart';
import 'package:own_hub/routing/app_router.dart';

import '../../qa/round1/round1_harness.dart';

void main() {
  useShippingApp();

  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);
  setUp(() {
    WorkoutLibraryState.instance.reset();
    FirstGymGuideState.instance.reset();
  });

  Future<void> answer({
    TrainingPlace place = TrainingPlace.home,
    int days = 3,
    int minutes = 15,
    LifeStage? lifeStage,
  }) async {
    AppRouter.intakeRepository.markSetupDone();
    await AppRouter.intakeRepository.merge(
      goal: TrainingGoal.stronger,
      place: place,
      days: days,
      minutes: minutes,
      lifeStage: lifeStage,
    );
  }

  List<MoveRow> rows(WidgetTester t) =>
      t.widgetList<MoveRow>(find.byType(MoveRow)).toList();

  testWidgets('R02 lists her week from her programme, today first', (t) async {
    phone(t);
    await answer();
    await open(t, appDestinations['R02']!.name, locale: const Locale('en'));

    expect(find.text('3-day split'), findsOneWidget);
    expect(find.text('Upper'), findsOneWidget);
    expect(find.text('Lower'), findsOneWidget);
    expect(find.text('Lower II'), findsOneWidget);
    final week = rows(t);
    expect(week, hasLength(3));
    expect(week.map((r) => r.done), [false, false, false]);
    expect(week.map((r) => r.current), [true, false, false]);
    expect(find.text('15 minutes, 4 moves'), findsNWidgets(3));
  });

  testWidgets('a finished session is struck off and the next is today', (
    t,
  ) async {
    phone(t);
    await answer();
    await AppRouter.trainRepository.logRecalled(
      dateKey: dayKey(AppClock.now()),
      method: RecallMethod.history,
    );
    await open(t, appDestinations['R02']!.name, locale: const Locale('en'));

    final week = rows(t);
    expect(week.map((r) => r.done), [true, false, false]);
    expect(week.map((r) => r.current), [false, true, false]);
  });

  testWidgets('tapping a day opens that session on R03, cut to her minutes', (
    t,
  ) async {
    phone(t);
    await answer(minutes: 10);
    await open(t, appDestinations['R02']!.name, locale: const Locale('en'));

    expect(await tapControl(t, RegExp('Lower II')), isTrue);
    expect(topScreen(t), 'R03');
    expect(find.text('Lower II'), findsWidgets);
    expect(find.text('10 minutes, 4 moves'), findsOneWidget);
  });

  testWidgets('R03 opens today\'s session of her programme', (t) async {
    phone(t);
    await answer();
    await open(t, appDestinations['R03']!.name, locale: const Locale('en'));
    expect(find.text('Upper'), findsWidgets);
  });

  testWidgets('the first-gym guide comes once, before a gym session', (
    t,
  ) async {
    phone(t);
    await answer(place: TrainingPlace.ladiesGym);
    await open(t, appDestinations['R03']!.name, locale: const Locale('en'));

    expect(await tapControl(t, RegExp("Start, everything")), isTrue);
    expect(find.byKey(const ValueKey('gym-guide-step-0')), findsOneWidget);
    expect(FirstGymGuideState.instance.seen, isTrue);
    // No session was begun by opening it.
    expect(topScreen(t), isNot('R07'));

    // Skip leaves it, and starts nothing.
    await t.tap(find.byKey(const ValueKey('gym-guide-skip')));
    await settle(t);
    expect(find.byKey(const ValueKey('gym-guide-step-0')), findsNothing);
    expect(topScreen(t), 'R03');

    // Not offered again: Start goes straight into the session.
    expect(await tapControl(t, RegExp("Start, everything")), isTrue);
    expect(topScreen(t), 'R07');
  });

  testWidgets('at home there is no guide', (t) async {
    phone(t);
    await answer();
    await open(t, appDestinations['R03']!.name, locale: const Locale('en'));
    expect(await tapControl(t, RegExp("Start, everything")), isTrue);
    expect(find.byKey(const ValueKey('gym-guide-step-0')), findsNothing);
    expect(topScreen(t), 'R07');
  });

  testWidgets('a starting plan never says it was written for her stage', (
    t,
  ) async {
    phone(t);
    await answer(lifeStage: LifeStage.pregnant);
    await open(t, appDestinations['R03']!.name, locale: const Locale('en'));
    expect(find.textContaining('Written for pregnancy'), findsNothing);
    expect(
      find.textContaining('Day 1 was not written for pregnancy'),
      findsOneWidget,
    );
  });
}
