// The target weights a coach types reach the client's workout, on the right
// move even when a short day cuts the plan.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/chosen_programme.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/domain/viewed_tier.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../features/private_coaching/support/fake_coaching_repository.dart';

AuthoredMove _move(String id, {int? hold, int? reps = 10, int rest = 60}) =>
    AuthoredMove(
      exerciseId: id,
      nameEn: id,
      nameAr: id,
      sets: hold == null ? 3 : 1,
      reps: hold == null ? reps : null,
      holdSeconds: hold,
      restSeconds: rest,
    );

/// Eight strength moves and a closing stretch.
AuthoredSession _day() => AuthoredSession(
  sessionId: 'mine_1',
  titleEn: 'Legs',
  titleAr: 'رجلين',
  minutes: 40,
  lifeStages: const {LifeStage.none},
  moves: [
    for (var i = 1; i <= 8; i++) _move('m$i'),
    _move('stretch', hold: 30, rest: 0),
  ],
);

CoachPlan _plan(List<double?> kg) => CoachPlan(
  id: 'p1',
  kind: PlanKind.workout,
  coachUid: 'coach1',
  name: 'Coach plan',
  workout: MyPlan(
    days: [MyPlanDay(session: _day(), targetKg: kg)],
  ),
  publishedAt: DateTime.utc(2026, 11, 1),
);

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  setUp(() async {
    AppRouter.featureFlags = FeatureFlags.everything;
    ChosenProgramme.reset();
    ViewedTier.clear();
    WorkoutLibraryState.instance
      ..openedSlot = null
      ..chosenRowId = null;
    await AppRouter.intakeRepository.merge(
      place: TrainingPlace.ladiesGym,
      goal: TrainingGoal.stronger,
      level: TrainingLevel.beginner,
      minutes: 45,
    );
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    PrivateCoachingState.instance.stop();
    ChosenProgramme.reset();
    ViewedTier.clear();
  });

  Future<WorkoutDay?> today(WidgetTester tester, CoachPlan plan) async {
    final repo = FakeCoachingRepository(uid: 'me');
    PrivateCoachingState.instance.start(repo);
    repo.clientSubs.value = [
      Subscription(
        id: 's1',
        coachUid: 'coach1',
        clientUid: 'me',
        status: SubscriptionStatus.active,
      ),
    ];
    repo.plans.value = [plan];
    await tester.pump();
    WorkoutDay? day;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: Builder(
          builder: (context) {
            day = AppRouter.programmeWorkoutDay(context);
            return const SizedBox();
          },
        ),
      ),
    );
    return day;
  }

  String label(WorkoutDay day, String id) =>
      day.moves.firstWhere((m) => m.exerciseId == id).prescriptionLabel;

  testWidgets('a coach\'s target weight is on the move she typed it for', (
    tester,
  ) async {
    final day = await today(
      tester,
      _plan([20, null, null, null, null, null, null, null, 5]),
    );
    expect(AppRouter.herProgramme!.content.programId, kCoachPlanId);
    expect(day, isNotNull);
    expect(label(day!, 'm1'), contains('20 kg'));
    expect(label(day, 'm2'), isNot(contains('kg')));
    expect(label(day, 'stretch'), contains('5 kg'));
  });

  testWidgets('a short day cuts moves but never moves a weight', (
    tester,
  ) async {
    // 25 minutes keeps six strength moves and the stretch, which then sits at
    // place 7 of the shown day and place 9 of the coach's.
    await AppRouter.intakeRepository.merge(minutes: 25);
    final day = await today(
      tester,
      _plan([20, null, null, null, null, null, 7, 8, 5]),
    );
    expect(day!.moves.map((m) => m.exerciseId).toList(), [
      'm1', 'm2', 'm3', 'm4', 'm5', 'm6', 'stretch', //
    ]);
    expect(label(day, 'm1'), contains('20 kg'));
    expect(
      day.moves.where((m) => m.prescriptionLabel.contains('kg')).length,
      2,
      reason:
          'm7 and m8 were cut with their weights; the stretch keeps its own',
    );
    expect(label(day, 'stretch'), contains('5 kg'));
  });

  test(
    'targetsForShown follows the exercise, in order, even when it repeats',
    () {
      final plan = MyPlan(
        days: [
          MyPlanDay(
            session: AuthoredSession(
              sessionId: 'mine_1',
              titleEn: 'x',
              titleAr: 'x',
              minutes: 30,
              lifeStages: const {LifeStage.none},
              moves: [_move('a'), _move('b'), _move('a'), _move('c')],
            ),
            targetKg: const [1, 2, 3, 4],
          ),
        ],
      );
      final shown = AuthoredSession(
        sessionId: 'mine_1',
        titleEn: 'x',
        titleAr: 'x',
        minutes: 15,
        lifeStages: const {LifeStage.none},
        moves: [_move('a'), _move('a'), _move('c')],
      );
      expect(targetsForShown(plan, shown), [1, 3, 4]);
      expect(targetsForShown(null, shown), isEmpty);
      expect(
        targetsForShown(
          plan,
          AuthoredSession(
            sessionId: 'other',
            titleEn: 'x',
            titleAr: 'x',
            minutes: 15,
            lifeStages: const {},
            moves: [_move('a')],
          ),
        ),
        isEmpty,
      );
      expect(kWholeSessionMinutes, 30);
    },
  );
}
