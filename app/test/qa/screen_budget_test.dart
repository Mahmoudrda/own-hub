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
import 'package:own_hub/app_state/events_state.dart';
import 'package:own_hub/app_state/follow_up_state.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/followup/presentation/follow_up_card.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/ui/hand/finish_wipe.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

import 'package:own_hub/app_state/coach_client_notes.dart';
import 'package:own_hub/features/private_coaching/domain/check_in.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/client_detail_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/coach_desk_view.dart';

import '../features/private_coaching/coach/coach_fake.dart';
import '../features/private_coaching/desk/desk_repo.dart';
import '../features/private_coaching/desk/desk_support.dart';
import '../helpers/control_counter.dart';
import '../helpers/primary_actions.dart';
import '../features/private_coaching/plans/plans_support.dart' show workoutPlan;
import '../features/private_coaching/support/fake_coaching_repository.dart';
import '../features/private_coaching/support/fixtures.dart';
import 'round1/round1_harness.dart';

/// Owner decision (24 Oct 2026): the shared top bar (her picture and the
/// language switch) is chrome, excluded from every budget like the tab bar.
const bool kChromeCounts = false;

const maxOtherControls = 5;
const maxPrimaryActions = 1;

/// The coach's screens: K07 Today, K18 Coach space, W02 Client overview.
/// They need a coach's state, so they are pumped as widgets below, not opened
/// by route.
const coachScreens = ['K07', 'K18', 'W02'];

/// Coach screens that are measured but not asserted, because they are over
/// budget today. K07 with a new request, a follow-up, an unread chat and a
/// "Needs attention" row at once shows 9 controls at 390x844 and 7 at
/// 375x667 (budget 5), and 1 filled primary. Move an id out of this set when
/// the screen is simplified.
const coachScreensOverBudget = {'K07'};

/// Screen id to its budget: (max other controls, max filled primaries).
final Map<String, ({int controls, int primary})> budgets = {
  for (final id in [...screenIds, ...coachScreens])
    id: (controls: maxOtherControls, primary: maxPrimaryActions),
};

/// Screens whose assertion is on.
const simplified = {
  'T01',
  'E01',
  'E02',
  'E03',
  'P01',
  'A02',
  'H05',
  'H02',
  'H03',
  'T09',
};

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
  'E03',
  'P01',
  'A02',
  'H05',
  'H02',
  'H03',
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

  group('Home, asserted in every state', () {
    final tuesday = DateTime(2026, 9, 15, 9, 41);
    late FakeCoachingRepository coaching;

    setUp(() {
      AppRouter.featureFlags = shippingFlags().with_(<Feature, bool>{
        Feature.events: true,
        Feature.followUps: true,
      });
      wipe();
      FollowUpState.instance.reset();
      FollowUpCard.lastThanks = null;
      EventsState.instance.seed(const []);
      AppRouter.intakeRepository.markSetupDone();
      coaching = FakeCoachingRepository(uid: 'me');
      AppClock.debugNow = () => tuesday;
    });
    tearDown(() {
      AppClock.debugNow = null;
      PrivateCoachingState.instance.stop();
      AppRouter.trainRepository.reset();
      AppRouter.intakeRepository.reset();
      EventsState.instance.seed(const []);
      FollowUpState.instance.reset();
      wipe();
    });

    Future<void> arrange(String state) async {
      if (state != 'newWoman') {
        await AppRouter.todayRepository.countWalk();
        AppRouter.todayRepository.rollTo(tuesday);
      }
      if (state == 'followUp') {
        AppRouter.trainRepository.restore(
          sessions: [
            TrainSession(
              id: 'live-2026-09-14',
              source: SessionSource.live,
              dateKey: '2026-09-14',
              completed: true,
              endedReason: EndedReason.finished,
              sets: [
                for (var i = 0; i < 3; i++)
                  LoggedSet(
                    prescribed: PrescribedSet(
                      exerciseId: 'goblet_squat',
                      order: i,
                      weightKg: 12.5,
                      reps: 10,
                    ),
                    outcome: const SetOutcome(weightKg: 12.5, reps: 10),
                  ),
              ],
            ),
          ],
        );
      }
      if (state == 'event') {
        EventsState.instance.seed([
          HubEvent(
            id: 'e1',
            titleEn: 'Morning stretch, together',
            titleAr: 'تمدد الصبح',
            startsAt: DateTime.utc(2026, 11, 5, 16, 30),
            endsAt: DateTime.utc(2026, 11, 5, 17, 30),
            mode: EventMode.online,
            link: 'https://meet.example.com/stretch',
            status: EventStatus.published,
          ),
        ]);
      }
      if (state == 'coached') {
        coaching.clientSubs.value = [
          sub('s1', SubscriptionStatus.active, coachUid: 'c1'),
        ];
        coaching.plans.value = [
          CoachPlan(
            id: 'w1',
            kind: PlanKind.workout,
            coachUid: 'c1',
            name: 'Strength',
            workout: workoutPlan(),
          ),
        ];
        PrivateCoachingState.instance.start(coaching);
      }
    }

    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final state in const [
          'newWoman',
          'midWeek',
          'coached',
          'followUp',
          'event',
        ]) {
          testWidgets('T01 $state ${locale.languageCode} '
              '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);
            await arrange(state);
            await open(tester, appDestinations['T01']!.name, locale: locale);
            expect(topScreen(tester), 'T01');
            expectWithinBudget(tester, 'T01');
          });
        }
      }
    }
  });

  group('Coach screens, asserted in the states a coach meets', () {
    setUp(CoachClientNotes.instance.reset);
    tearDown(() {
      CoachClientNotes.instance.reset();
      CheckIns.override = null;
    });

    final day = kDeskNow.subtract(const Duration(days: 10));

    // K07: a new request with a health yes, one client to follow up, one with
    // an unread message and one on the "Needs attention" list.
    Future<void> pumpK07(WidgetTester tester, String lang) async {
      CheckIns.override = InMemoryCheckInStore(
        rows: const <AttentionRow>[
          AttentionRow(
            subId: 'a',
            relId: 'r1',
            clientName: 'Nour Hassan',
            reasons: <String>['healthFlag', 'unread'],
            pain: true,
            note: 'my knee hurts when I squat',
          ),
        ],
      );
      final repo = DeskRepo()
        ..setSubscriptions([
          deskSub(
            'r1',
            status: SubscriptionStatus.requested,
            name: 'Mona Ali',
            createdAt: day,
            intake: deskIntake(health: true, ack: true),
          ),
          deskSub('a', name: 'Nour Hassan', startsAt: day),
          deskSub('b', name: 'Dina Samir'),
        ])
        ..setRelationships([
          deskRel('ua', lastAt: day, sender: 'me'),
          deskRel('ub', lastAt: kDeskNow, unread: 2, text: 'Done today!'),
        ]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(
          CoachDeskView(state: state, now: () => kDeskNow),
          lang: lang,
        ),
      );
      await tester.pumpAndSettle();
      // The state meant is the one on screen, not a skeleton or an empty page.
      expect(
        find.text(lookupAppL10n(Locale(lang)).needsAttention),
        findsWidgets,
      );
      expect(find.textContaining('Mona Ali'), findsOneWidget);
      expect(find.textContaining('my knee hurts when I squat'), findsOneWidget);
    }

    // K18: a published coach who is taking clients.
    Future<void> pumpK18(WidgetTester tester, String lang) async {
      final repo = CoachRepo()
        ..coaches.value = [
          const CoachProfile(
            uid: 'me',
            displayName: 'Coach Sara',
            headline: 'Strength coach for busy women',
            approach: 'I build a simple plan around your week.',
            published: true,
            acceptingClients: true,
          ),
        ];
      await tester.pumpWidget(
        deskHost(
          CoachSpaceView(
            repository: repo,
            onPreviewPortfolio: (_) {},
            onOpenDashboard: () {},
            onOpenChats: () {},
            onInviteClient: () {},
            onShareProfile: (_) {},
          ),
          lang: lang,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Coach Sara'), findsOneWidget);
    }

    // W02: a client whose health yes is not read yet, the hold card state.
    Future<void> pumpW02(WidgetTester tester, String lang) async {
      final repo = DeskRepo()
        ..setSubscriptions([
          deskSub(
            'a',
            name: 'Nour Hassan',
            startsAt: day,
            intake: deskIntake(health: true, ack: true),
          ),
        ])
        ..setRelationships([deskRel('ua', lastAt: day, sender: 'me')]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(
          ClientDetailView(subId: 'a', state: state, now: () => kDeskNow),
          lang: lang,
        ),
      );
      await tester.pumpAndSettle();
      final l10n = lookupAppL10n(Locale(lang));
      expect(find.text('Nour Hassan'), findsWidgets);
      expect(find.text(l10n.readHerHealthAnswersFirst), findsOneWidget);
      expect(find.text(l10n.iHaveReadThem), findsOneWidget);
    }

    final pumps = {'K07': pumpK07, 'K18': pumpK18, 'W02': pumpW02};
    for (final lang in const ['en', 'ar']) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final id in coachScreens) {
          testWidgets('$id $lang ${size.width.toInt()}x${size.height.toInt()}', (
            tester,
          ) async {
            tester.view.physicalSize = size * 3;
            tester.view.devicePixelRatio = 3.0;
            addTearDown(tester.view.reset);
            await pumps[id]!(tester, lang);
            print(
              'COACH $id $lang $size '
              'controls=${countControlsAboveFold(tester, includeChrome: kChromeCounts)} '
              'primary=${filledPrimaryActions(tester)}',
            );
            if (!coachScreensOverBudget.contains(id)) {
              expectWithinBudget(tester, id);
            }
          });
        }
      }
    }
  });

  group('Eat, reported only', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      for (final size in const [Size(390, 844), Size(375, 667)]) {
        for (final id in const ['E01']) {
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
