// ignore_for_file: avoid_print
//
// Step 8 budgets: Settings (A02), My coach (H05), a coach's page (H02), a
// coach's plan (H03) and Events (T09). In each state at most one filled
// primary and at most five other controls above the fold, in English and
// Arabic, at 390x844 and 375x667. The shared top bar and the tab bar are not
// counted. Each screen's own rule is asserted beside its budget.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/account/presentation/profile_view.dart';
import 'package:own_hub/features/events/domain/event_registration.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/events/presentation/events_view.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_plan_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_portfolio_view.dart';
import 'package:own_hub/ui/app_button.dart';

import '../features/private_coaching/plans/plans_support.dart';
import '../helpers/control_counter.dart';
import '../helpers/primary_actions.dart';

const _sizes = <(String, Size)>[
  ('390x844', Size(390, 844)),
  ('375x667', Size(375, 667)),
];
const _langs = ['en', 'ar'];

void _size(WidgetTester t, Size size) {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void _budget(WidgetTester t, String where) {
  final n = countControlsAboveFold(t, includeChrome: false);
  print('BUDGET $where: $n controls, ${filledPrimaryActions(t)} primary');
  expect(
    n,
    lessThanOrEqualTo(5),
    reason: '$where: more than 5 controls above the fold',
  );
  expectAtMostOnePrimaryAction(t, where: where);
}

/// The sheet sits over the page, so only its own buttons are counted.
void _sheetPrimary(WidgetTester t, String where) {
  final filled = find.descendant(
    of: find.byType(BottomSheet),
    matching: find.byWidgetPredicate(
      (w) =>
          w is AppButton &&
          w.variant == AppButtonVariant.filled &&
          w.onPressed != null,
    ),
  );
  expect(
    filled.evaluate().length,
    lessThanOrEqualTo(1),
    reason: '$where: one filled primary in the sheet',
  );
}

class _Seats implements EventRegistrar {
  @override
  Future<bool> isRegistered(String eventId) async => false;

  @override
  Future<SeatResult> register(String eventId) async =>
      const SeatResult(registered: true, seatsTaken: 1, capacity: 20);

  @override
  Future<SeatResult> cancel(String eventId) async =>
      const SeatResult(registered: false, seatsTaken: 0, capacity: 20);
}

final _clock = DateTime.utc(2026, 10, 24, 12);

HubEvent _event(int n, {bool place = true}) => HubEvent(
  id: 'e$n',
  titleEn: 'Event $n',
  titleAr: 'فعالية $n',
  descriptionEn: 'Thirty quiet minutes.',
  descriptionAr: 'نص هادي',
  startsAt: DateTime.utc(2026, 11, 5 + n, 16, 30),
  endsAt: DateTime.utc(2026, 11, 5 + n, 17, 30),
  mode: place ? EventMode.place : EventMode.online,
  placeName: place ? 'Zamalek gym' : null,
  locationAddress: place ? '1 Nile road' : null,
  locationUrl: place ? 'https://maps.google.com/?q=1' : null,
  link: place ? null : 'https://meet.example.com/x',
  capacity: 20,
  status: EventStatus.published,
);

CoachPackage _package(String id, int order) => CoachPackage(
  id: id,
  title: 'Package $id',
  description: 'Plan and chat',
  includes: const ['Weekly plan', 'Chat'],
  durationDays: 28,
  liveSessionsPerMonth: 2,
  priceFinalEgp: 2000,
  active: true,
  order: order,
);

const _coach = CoachProfile(
  uid: 'c2',
  displayName: 'Coach Sara',
  headline: 'Slow and steady',
  languages: ['ar', 'en'],
  specialties: ['strength', 'mobility'],
  approach: 'Plans that fit a week.',
  yearsExperience: 6,
  published: true,
  acceptingClients: true,
  badges: ['verifiedCoach'],
);

void main() {
  for (final (sizeName, size) in _sizes) {
    for (final lang in _langs) {
      final at = '$sizeName $lang';
      final locale = Locale(lang);

      group('A02 Settings, $at', () {
        testWidgets('every optional row on stays within budget', (t) async {
          _size(t, size);
          await t.pumpWidget(
            host(
              ProfileView(
                dietaryRepository: InMemoryDietaryProfileRepository(),
                firstName: 'Nadia',
                onOpenCoachSpace: () {},
                onOpenTraining: () {},
                onOpenAdmin: () {},
                onOpenAllScreens: () {},
                onSignIn: () {},
                onSelectTab: (_) {},
              ),
              locale: locale,
            ),
          );
          await t.pumpAndSettle();
          _budget(t, 'A02 $at');
          // Rows that repeat You, the language switch or Home's bell are gone.
          if (lang == 'en') {
            for (final row in ['My cycle', 'My coach', 'Notifications']) {
              expect(find.text(row), findsNothing);
            }
          }
        });
      });

      group('H05 My coach, $at', () {
        Future<RecordingRepo> open(
          WidgetTester t,
          SubscriptionStatus status, {
          List<LiveSession> sessions = const [],
        }) async {
          _size(t, size);
          final repo = RecordingRepo()..sessions = sessions;
          await t.pumpWidget(
            host(
              MyCoachView(
                repository: repo,
                subscription: sub(status: status),
                plans: [
                  CoachPlan(
                    id: 'w1',
                    kind: PlanKind.workout,
                    coachUid: 'coach1',
                    name: 'Strength',
                    workout: workoutPlan(),
                  ),
                  CoachPlan(
                    id: 'm1',
                    kind: PlanKind.meal,
                    coachUid: 'coach1',
                    name: 'Week',
                    meal: mealBody(),
                  ),
                ],
                hasUnread: true,
                now: () => _clock,
                onMessage: () {},
                onBlock: () {},
                onFind: () {},
              ),
              locale: locale,
            ),
          );
          await t.pumpAndSettle();
          return repo;
        }

        testWidgets('active: a filled Message, sessions one tap each', (
          t,
        ) async {
          await open(
            t,
            SubscriptionStatus.active,
            sessions: [
              LiveSession(
                id: 'p',
                status: SessionStatus.proposed,
                startsAt: DateTime.utc(2026, 10, 28, 15),
                minutes: 45,
              ),
              LiveSession(
                id: 'c',
                status: SessionStatus.confirmed,
                startsAt: DateTime.utc(2026, 10, 24, 10),
                minutes: 30,
                link: 'https://meet.google.com/abc-defg-hij',
              ),
            ],
          );
          _budget(t, 'H05 active $at');
          expect(
            t
                .widget<AppButton>(find.byKey(const ValueKey('coach-message')))
                .variant,
            AppButtonVariant.filled,
          );
          // Report, Block and End coaching are gone from the page itself.
          expect(find.byKey(const ValueKey('end-coaching')), findsNothing);
          expect(find.byKey(const ValueKey('session-confirm-p')), findsNothing);

          await t.tap(find.byKey(const ValueKey('session-p')));
          await t.pumpAndSettle();
          _sheetPrimary(t, 'H05 session sheet $at');
          expect(
            find.byKey(const ValueKey('session-confirm-p')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('session-decline-p')),
            findsOneWidget,
          );
        });

        testWidgets('Report, Block and End coaching sit in the menu', (
          t,
        ) async {
          await open(t, SubscriptionStatus.active);
          await t.tap(find.byKey(const ValueKey('overflow-menu')));
          await t.pumpAndSettle();
          final rows = find.byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('overflow-row-'),
          );
          expect(rows, findsNWidgets(3));
          _sheetPrimary(t, 'H05 menu $at');
        });

        for (final status in [
          SubscriptionStatus.requested,
          SubscriptionStatus.declined,
          SubscriptionStatus.endedEarly,
        ]) {
          testWidgets('${status.name}: within budget', (t) async {
            await open(t, status);
            _budget(t, 'H05 ${status.name} $at');
          });
        }

        testWidgets('no coach: one Find a coach', (t) async {
          _size(t, size);
          await t.pumpWidget(host(NoCoachView(onFind: () {}), locale: locale));
          await t.pumpAndSettle();
          _budget(t, 'H05 none $at');
        });
      });

      group('H02 coach page, $at', () {
        testWidgets('Ask to join is pinned and the only filled button', (
          t,
        ) async {
          _size(t, size);
          await t.pumpWidget(
            host(
              CoachPortfolioView(
                coach: _coach,
                packages: [
                  _package('a', 0),
                  _package('b', 1),
                  _package('c', 2),
                ],
                repository: RecordingRepo(),
                blocks: InMemoryBlockService(selfUid: 'me'),
              ),
              locale: locale,
            ),
          );
          await t.pumpAndSettle();
          _budget(t, 'H02 $at');
          expect(filledPrimaryActions(t), 1);
          final ask = find.byWidgetPredicate(
            (w) => w is AppButton && w.variant == AppButtonVariant.filled,
          );
          expect(ask, findsOneWidget);
          // Pinned: still on screen after the page scrolls.
          await t.drag(find.byType(Scrollable).first, const Offset(0, -2000));
          await t.pumpAndSettle();
          expect(ask, findsOneWidget);
          expect(t.getRect(ask).bottom, lessThanOrEqualTo(size.height));
        });
      });

      group('H03 coach plan, $at', () {
        Future<void> pump(WidgetTester t, CoachPlanView view) async {
          _size(t, size);
          await t.pumpWidget(host(view, locale: locale));
          await t.pumpAndSettle();
        }

        testWidgets('workout: only today has a filled Start', (t) async {
          await pump(
            t,
            CoachPlanView(
              plan: CoachPlan(
                id: 'w1',
                kind: PlanKind.workout,
                coachUid: 'coach1',
                name: 'Strength',
                workout: workoutPlan(),
              ),
              doneThisWeek: 1,
              onStartWorkout: (_) {},
            ),
          );
          _budget(t, 'H03 workout $at');
          final starts = find.byWidgetPredicate(
            (w) =>
                w is AppButton &&
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('plan-start-'),
          );
          expect(starts, findsOneWidget);
          expect(t.widget<AppButton>(starts).variant, AppButtonVariant.filled);
        });

        testWidgets('meal: one tap per meal, Log this in the sheet', (t) async {
          await pump(
            t,
            CoachPlanView(
              plan: CoachPlan(
                id: 'm1',
                kind: PlanKind.meal,
                coachUid: 'coach1',
                name: 'Week',
                meal: mealBody(),
                publishedAt: DateTime.utc(2026, 10, 24, 6),
              ),
              catalog: catalog(),
              now: () => _clock,
              onLog: (_, _) {},
              onOpenRecipe: (_) {},
            ),
          );
          _budget(t, 'H03 meal $at');
          await t.tap(find.byKey(const ValueKey('plan-item-0-breakfast-0')));
          await t.pumpAndSettle();
          _sheetPrimary(t, 'H03 meal sheet $at');
        });
      });

      group('T09 Events, $at', () {
        Future<void> pump(WidgetTester t, Widget view) async {
          _size(t, size);
          await t.pumpWidget(host(view, locale: locale));
          await t.pumpAndSettle();
        }

        testWidgets('a list of cards, nothing to press inside them', (t) async {
          await pump(
            t,
            EventsView(
              events: [for (var i = 1; i <= 4; i++) _event(i)],
              registrar: _Seats(),
              now: () => _clock,
            ),
          );
          _budget(t, 'T09 list $at');
          expect(filledPrimaryActions(t), 0);
          expect(find.byKey(const ValueKey('event-e1')), findsOneWidget);
        });

        testWidgets('detail: Reserve is the primary, Maps a text link', (
          t,
        ) async {
          await pump(
            t,
            EventsView(
              events: [_event(1)],
              registrar: _Seats(),
              onOpenLink: (_) {},
              now: () => _clock,
            ),
          );
          await t.tap(find.byKey(const ValueKey('event-e1')));
          await t.pumpAndSettle();
          _budget(t, 'T09 detail $at');
          final filled = find.byWidgetPredicate(
            (w) => w is AppButton && w.variant == AppButtonVariant.filled,
          );
          expect(filled, findsOneWidget);
          final maps = find.byWidgetPredicate(
            (w) => w is AppButton && w.icon == Icons.map_outlined,
          );
          expect(maps, findsOneWidget);
          expect(t.widget<AppButton>(maps).variant, AppButtonVariant.text);
        });

        testWidgets('detail of an online event is within budget', (t) async {
          await pump(
            t,
            EventsView(
              events: [_event(2, place: false)],
              registrar: _Seats(),
              onOpenLink: (_) {},
              now: () => _clock,
            ),
          );
          await t.tap(find.byKey(const ValueKey('event-e2')));
          await t.pumpAndSettle();
          _budget(t, 'T09 online detail $at');
        });

        testWidgets('empty: within budget', (t) async {
          await pump(t, const EventsView());
          _budget(t, 'T09 empty $at');
        });
      });
    }
  }
}
