// ignore_for_file: avoid_print
//
// Screen budgets: at most one filled primary and at most five other controls
// above the fold at 390x844, excluding the tab bar. Today this reports the
// counts; each screen's assertion is switched on when that screen is simplified.
@Tags(['qa'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/ui/hand/finish_wipe.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

import '../helpers/control_counter.dart';
import '../helpers/primary_actions.dart';
import 'round1/round1_harness.dart';

const bool kChromeCounts = false; // provisional: owner decides whether the shared top bar counts like the tab bar

const maxOtherControls = 5;
const maxPrimaryActions = 1;

/// Screen id to its budget: (max other controls, max filled primaries).
final Map<String, ({int controls, int primary})> budgets = {
  for (final id in screenIds)
    id: (controls: maxOtherControls, primary: maxPrimaryActions),
};

/// Screens whose assertion is on.
const simplified = {'P01'};

/// The Train and workout screens, asserted in their main states below.
const trainScreens = ['R01', 'R02', 'R03', 'R07', 'R09', 'R10'];

const screenIds = [
  'T01',
  'R01',
  'R02',
  'R03',
  'R07',
  'R09',
  'R10',
  'E01',
  'E02',
  'P01',
  'A02',
  'H05',
  'T09',
];

void expectWithinBudget(WidgetTester tester, String id) {
  final budget = budgets[id]!;
  expect(
    countControlsAboveFold(tester, includeChrome: kChromeCounts),
    lessThanOrEqualTo(budget.controls),
    reason: '$id: too many controls above the fold',
  );
  expect(
    filledPrimaryActions(tester),
    lessThanOrEqualTo(budget.primary),
    reason: '$id: more than one filled primary',
  );
}

void main() {
  useShippingApp();
  setUp(() {
    AppRouter.featureFlags = AppRouter.featureFlags.with_(<Feature, bool>{
      Feature.marketplace: true,
      Feature.events: true,
    });
  });

  for (final id in screenIds) {
    testWidgets('$id budget report, EN 390x844', (tester) async {
      phone(tester);
      final ok = await open(
        tester,
        appDestinations[id]!.name,
        locale: const Locale('en'),
      );
      final controls = countControlsAboveFold(tester);
      final primary = filledPrimaryActions(tester);
      print(
        'BUDGET $id top=${topScreen(tester)} opened=$ok '
        'controls=$controls primary=$primary',
      );
    });
    testWidgets(
      '$id within budget',
      (tester) async {
        phone(tester);
        await open(tester, appDestinations[id]!.name);
        expectWithinBudget(tester, id);
      },
      skip: !simplified.contains(id), // enabled when the screen is simplified
    );
  }

  group('You, both tabs, with finished sessions', () {
    TrainSession finished(int i) => TrainSession(
      id: 'y$i',
      source: SessionSource.live,
      dateKey: '2026-10-0${i + 1}',
      sets: [
        LoggedSet(
          prescribed: PrescribedSet(
            exerciseId: 'barbell_hip_thrust',
            order: 1,
            reps: 10,
          ),
          outcome: const SetOutcome(weightKg: 40, reps: 10),
        ),
      ],
      completed: true,
      endedReason: EndedReason.finished,
    );

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final tab in const ['Progress', 'Activities']) {
          testWidgets('P01 $tab, ${locale.languageCode}, ${size.width.toInt()}x'
              '${size.height.toInt()}', (tester) async {
            AppRouter.trainRepository.restore(
              sessions: [for (var i = 0; i < 4; i++) finished(i)],
              flushes: [
                for (var i = 0; i < 4; i++)
                  (
                    sessionId: 'y$i',
                    exerciseId: 'barbell_hip_thrust',
                    sets: finished(i).sets,
                  ),
              ],
            );
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);
            await open(tester, appDestinations['P01']!.name, locale: locale);
            if (tab == 'Activities') {
              final l10n = lookupAppL10n(locale);
              await tester.tap(find.text(l10n.activities));
              await tester.pumpAndSettle();
              expect(find.byKey(const ValueKey('recent-y3')), findsOneWidget);
            }
            final n = countControlsAboveFold(tester);
            print('YOU $tab ${locale.languageCode} $size controls=$n');
            expectWithinBudget(tester, 'P01');
          });
        }
      }
    }
  });

  group('Train and workout, main states', () {
    setUpAll(() {
      StartingProgrammes.adopt(
        File('assets/content/starting_programmes.json').readAsStringSync(),
      );
    });
    tearDownAll(StartingProgrammes.reset);

    Future<void> seed(WidgetTester tester, String id, Locale locale) async {
      await AppRouter.intakeRepository.merge(
        place: TrainingPlace.ladiesGym,
        goal: TrainingGoal.stronger,
        level: TrainingLevel.beginner,
        minutes: 45,
      );
      if (id != 'R07' && id != 'R09' && id != 'R10') return;
      final l10n = lookupAppL10n(locale);
      final session = WorkoutSessionState.instance;
      final day = sampleWorkoutDay(l10n);
      session.start(day, AppRouter.trainRepository);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      if (id == 'R07') return;
      final move = day.moves.first;
      await AppRouter.trainRepository.flushMove(
        sessionId: session.sessionId,
        exerciseId: move.exerciseId,
        sets: [
          for (final set in move.sets)
            LoggedSet(prescribed: set)
                .recording(SetOutcome(weightKg: set.weightKg, reps: set.reps)),
        ],
      );
      session.setLogged();
      if (id == 'R09') return;
      await session.finish(
        repository: AppRouter.trainRepository,
        today: AppRouter.todayRepository,
        progress: AppRouter.progressStore,
      );
    }

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final id in trainScreens) {
          testWidgets('$id ${locale.languageCode} ${size.width.toInt()}x'
              '${size.height.toInt()}', (tester) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);
            await seed(tester, id, locale);
            await open(tester, appDestinations[id]!.name, locale: locale);
            if (id == 'R10') {
              await tester.pump(finishWipeDuration);
              await settle(tester);
            }
            expect(topScreen(tester), id);
            final n = countControlsAboveFold(tester);
            final bare = countControlsAboveFold(tester, includeChrome: false);
            print(
              'TRAIN $id ${locale.languageCode} $size '
              'withChrome=$n withoutChrome=$bare',
            );
            expectWithinBudget(tester, id);
            if (id == 'R10') {
              expect(
                countHeroFigures(tester),
                lessThanOrEqualTo(4),
                reason: 'R10: at most 4 figures in the hero area',
              );
            }
          });
        }
      }
    }
  });

  group('Home and Eat, reported only', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final id in const ['T01', 'E01']) {
          testWidgets('$id report ${locale.languageCode} ${size.width.toInt()}x'
              '${size.height.toInt()}', (tester) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);
            await open(tester, appDestinations[id]!.name, locale: locale);
            print(
              'BUDGET2 $id ${locale.languageCode} $size '
              'controls=${countControlsAboveFold(tester)} '
              'primary=${filledPrimaryActions(tester)}',
            );
          });
        }
      }
    }
  });
}
