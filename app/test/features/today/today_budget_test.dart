// T01 Home budgets: one filled primary, at most five other controls above the
// fold and at most four figures, in the screen's main states, in English and
// Arabic, at 390x844 and 375x667.
//
// The counter is the one screen_budget_test.dart uses. A bare TodayView has no
// language strip above it; the strip adds the switch and her picture, which a
// routed Home carries on top of these counts (see the framed case below).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/follow_up_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/followup/domain/follow_up_plan.dart';
import 'package:own_hub/features/followup/presentation/follow_up_card.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_home_card.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/language_switch.dart';
import 'package:own_hub/ui/screen_scope.dart';

import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/app_state/events_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

import '../../qa/round1/round1_harness.dart';
import '../private_coaching/support/fake_coaching_repository.dart';
import '../private_coaching/support/fixtures.dart';
import '../../helpers/control_counter.dart';
import '../../helpers/primary_actions.dart';
import '../private_coaching/plans/plans_support.dart' show workoutPlan;

const maxFigures = 4;

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

enum _State { newWoman, midWeek, coached, followUp, event }

var coachOpened = 0;

TodayView _view(_State state) {
  final dayOne = state == _State.newWoman;
  return TodayView(
    repository: InMemoryTodayRepository(
      day: dayOne
          ? InMemoryTodayRepository.dayOne(date: _tuesday)
          : InMemoryTodayRepository.defaultDay(date: _tuesday),
    ),
    mealRepository: InMemoryMealRepository(),
    now: _tuesday,
    sessionTitle: 'Legs and glutes',
    sessionMinutes: 40,
    onStartSession: () {},
    onRecall: () {},
    onOpenMeal: () {},
    onOpenWeek: () {},
    onNotifications: () {},
    onSelectTab: (_) {},
    onOpenCoach: state == _State.coached ? () => coachOpened++ : null,
    coachCard: state == _State.coached
        ? CoachHomeCard(
            workout: CoachPlan(
              id: 'w1',
              kind: PlanKind.workout,
              coachUid: 'coach1',
              coachName: 'Sara',
              name: 'Strength',
              workout: workoutPlan(),
            ),
            hasUnread: true,
            onStartWorkout: (_, _) {},
          )
        : null,
    followUp: state == _State.followUp
        ? FollowUpCard(
            followUp: const FollowUp(
              kind: FollowUpKind.afterSession,
              session: SessionRecap(dateKey: '2026-09-14', moves: 5, sets: 15),
            ),
            now: _tuesday,
            intakeRepository: InMemoryIntakeRepository(),
          )
        : null,
    nextEvent: state == _State.event
        ? HubEvent(
            id: 'e1',
            titleEn: 'Morning stretch, together',
            titleAr: 'تمدد الصبح',
            startsAt: DateTime.utc(2026, 11, 5, 16, 30),
            endsAt: DateTime.utc(2026, 11, 5, 17, 30),
            mode: EventMode.online,
            link: 'https://meet.example.com/stretch',
            status: EventStatus.published,
          )
        : null,
    onOpenEvents: () {},
  );
}

Widget _host(Widget child, Locale locale, {bool framed = false}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: framed
        ? ScreenScope(
            screenId: 'T01',
            child: LanguageSwitchFrame(
              preference: AppRouter.localePreference,
              child: child,
            ),
          )
        : child,
  );
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Texts on screen that carry a digit: the figures a woman reads.
int _figures(WidgetTester tester) {
  final digit = RegExp(r'[0-9]');
  var count = 0;
  for (final e in find.byType(Text).hitTestable().evaluate()) {
    final text = (e.widget as Text).data ?? '';
    if (digit.hasMatch(text)) count++;
  }
  return count;
}

void main() {
  setUp(() {
    AppRouter.featureFlags = AppRouter.featureFlags.with_(<Feature, bool>{
      Feature.events: true,
    });
    FollowUpState.instance.reset();
  });

  group(
    'routed T01: one primary, four figures, other-control counts printed',
    () {
      late FakeCoachingRepository coaching;

      useShippingApp();
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
        AppClock.debugNow = () => _tuesday;
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

      Future<void> arrange(_State state) async {
        if (state != _State.newWoman) {
          await AppRouter.todayRepository.countWalk();
          AppRouter.todayRepository.rollTo(_tuesday);
        }
        if (state == _State.followUp) {
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
        if (state == _State.event) {
          EventsState.instance.seed([_view(_State.event).nextEvent!]);
        }
        if (state == _State.coached) {
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
          for (final state in _State.values) {
            testWidgets('T01 ${state.name}, ${locale.languageCode}, '
                '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
              tester.view.physicalSize = size * 3;
              tester.view.devicePixelRatio = 3.0;
              addTearDown(tester.view.reset);
              await arrange(state);
              await open(tester, appDestinations['T01']!.name, locale: locale);
              expect(topScreen(tester), 'T01');

              expectAtMostOnePrimaryAction(tester, where: 'T01 ${state.name}');
              final primaries = filledPrimaryActions(tester);
              final others = countControlsAboveFold(tester) - primaries;
              // ignore: avoid_print
              print(
                'T01 BUDGET ${state.name} ${locale.languageCode} '
                '${size.width.toInt()}x${size.height.toInt()} '
                'primary=$primaries others=$others '
                'figures=${_figures(tester)}',
              );
              expect(
                _figures(tester),
                lessThanOrEqualTo(maxFigures),
                reason: 'T01 ${state.name}: too many figures',
              );
            });
          }
        }
      }
    },
  );

  testWidgets('nothing sits under the bar: the last card clears it', (
    tester,
  ) async {
    _size(tester, const Size(375, 667));
    await tester.pumpWidget(_host(_view(_State.followUp), const Locale('en')));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -2000));
    await tester.pumpAndSettle();
    final bar = tester.getRect(find.byType(AppNavBar));
    final last = tester.getRect(
      find.byKey(const ValueKey('follow-up-afterSession')),
    );
    expect(last.bottom, lessThanOrEqualTo(bar.top));
  });

  testWidgets(
    'the follow-up card has one question, its chips and no close button',
    (tester) async {
      _size(tester, const Size(390, 844));
      await tester.pumpWidget(
        _host(_view(_State.followUp), const Locale('en')),
      );
      await tester.pumpAndSettle();
      expect(find.text('How do you feel today?'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
      expect(find.text("Don't show this kind again"), findsNothing);
      expect(find.text('Not now'), findsNothing);
    },
  );

  testWidgets('only one contextual card: follow-up beats event beats cycle', (
    tester,
  ) async {
    _size(tester, const Size(390, 1200));
    final base = _view(_State.followUp);
    final event = _view(_State.event).nextEvent;
    Widget home({Widget? followUp, HubEvent? next, bool cycle = false}) =>
        _host(
          TodayView(
            repository: InMemoryTodayRepository(
              day: InMemoryTodayRepository.defaultDay(date: _tuesday)
                  .copyWith(showCycleCard: cycle),
            ),
            mealRepository: InMemoryMealRepository(),
            now: _tuesday,
            followUp: followUp,
            nextEvent: next,
            onSelectTab: (_) {},
          ),
          const Locale('en'),
        );

    await tester.pumpWidget(
      home(followUp: base.followUp, next: event, cycle: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('How do you feel today?'), findsOneWidget);
    expect(find.textContaining('Morning stretch'), findsNothing);
    expect(find.text('My cycle'), findsNothing);

    await tester.pumpWidget(home(next: event, cycle: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('Morning stretch'), findsOneWidget);
    expect(find.text('My cycle'), findsNothing);

    await tester.pumpWidget(home(cycle: true));
    await tester.pumpAndSettle();
    expect(find.text('My cycle'), findsOneWidget);
  });

  testWidgets('a coached woman: her coach is the Today card (D11)', (
    tester,
  ) async {
    coachOpened = 0;
    _size(tester, const Size(390, 844));
    await tester.pumpWidget(_host(_view(_State.coached), const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('coach-home-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('today-card')), findsNothing);
    expect(find.byKey(const ValueKey('coach-home-start')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('today-change')));
    await tester.pumpAndSettle();
    expect(find.text('Do my own plan instead'), findsOneWidget);
    expect(find.text('Edit today'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('change-my-coach')));
    await tester.pumpAndSettle();
    expect(coachOpened, 1);
  });

  testWidgets('the Change sheet closes, then runs the row', (tester) async {
    _size(tester, const Size(390, 844));
    var edits = 0;
    var short = 0;
    var walks = 0;
    await tester.pumpWidget(
      _host(
        TodayView(
          repository: InMemoryTodayRepository(
            day: InMemoryTodayRepository.defaultDay(date: _tuesday),
          ),
          mealRepository: InMemoryMealRepository(),
          now: _tuesday,
          onEditToday: () => edits++,
          onShortVersion: () => short++,
          onTenMinuteWalk: () => walks++,
          onSelectTab: (_) {},
        ),
        const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();
    for (final (key, count) in [
      ('change-edit-today', () => edits),
      ('change-short-version', () => short),
      ('change-ten-minute-walk', () => walks),
    ]) {
      await tester.tap(find.byKey(const ValueKey('today-change')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(count(), 1, reason: key);
      expect(find.byKey(ValueKey(key)), findsNothing, reason: 'sheet closed');
    }
  });
}
