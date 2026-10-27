import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_client_notes.dart';
import 'package:own_hub/features/private_coaching/domain/check_in.dart';
import 'package:own_hub/features/private_coaching/domain/health_review.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_sheet.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/client_detail_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/clients_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/coach_desk_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/desk_model.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/desk_widgets.dart';

import 'desk_repo.dart';
import 'desk_support.dart';

DateTime ago(int days, [int hours = 0]) =>
    kDeskNow.subtract(Duration(days: days, hours: hours));

void main() {
  setUp(CoachClientNotes.instance.reset);
  tearDown(() {
    CoachClientNotes.instance.reset();
    CheckIns.override = null;
    HealthReviews.override = null;
  });

  group('Today', () {
    DeskRepo seeded({bool flagged = true}) {
      final repo = DeskRepo()
        ..setSubscriptions([
          deskSub(
            'r1',
            status: SubscriptionStatus.requested,
            name: 'Mona Ali',
            createdAt: ago(1),
            intake: deskIntake(health: flagged, ack: flagged),
          ),
          deskSub('a', name: 'Nour Hassan', startsAt: ago(10)),
          deskSub('b', name: 'Dina Samir'),
        ])
        ..setRelationships([
          deskRel('ua', lastAt: ago(10), sender: 'me'),
          deskRel('ub', lastAt: ago(0, 1), unread: 2, text: 'Done today!'),
        ]);
      return repo;
    }

    testWidgets('shows the counts, the request, the follow up and the unread', (
      tester,
    ) async {
      deskPhone(tester);
      final repo = seeded();
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      expect(find.text('Coach desk'), findsOneWidget);
      expect(find.bySemanticsLabel('1 New requests'), findsOneWidget);
      expect(find.bySemanticsLabel('1 Unread chats'), findsOneWidget);
      expect(find.bySemanticsLabel('2 Active clients'), findsOneWidget);
      expect(find.text('Mona Ali asked to join'), findsOneWidget);
      expect(find.text('Health answers to read first'), findsOneWidget);
      expect(find.text('Nour Hassan'), findsOneWidget);
      expect(find.text('No message from you in 10 days'), findsOneWidget);
      expect(find.text('Done today!'), findsOneWidget);
    });

    testWidgets('Accept on a health yes opens her answers first', (
      tester,
    ) async {
      deskPhone(tester);
      final repo = seeded();
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pumpAndSettle();
      expect(repo.responses, isEmpty);
      final sheet = find.byType(AppSheet);
      expect(
        find.descendant(of: sheet, matching: find.text('Her answers')),
        findsOneWidget,
      );
      final accept = find.descendant(of: sheet, matching: find.text('Accept'));
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(repo.responses, [('r1', true, null)]);
    });

    testWidgets('Accept answers an unflagged request at once', (tester) async {
      deskPhone(tester);
      final repo = seeded(flagged: false);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(repo.responses, [('r1', true, null)]);
      expect(find.text('Request accepted'), findsOneWidget);
    });

    testWidgets('K07 flags a request for a pregnancy answer', (tester) async {
      deskPhone(tester);
      final repo = DeskRepo()
        ..setSubscriptions([
          deskSub(
            'r1',
            status: SubscriptionStatus.requested,
            name: 'Mona Ali',
            createdAt: ago(1),
            intake: const Intake(lifeStage: 'pregnant'),
          ),
        ]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();
      expect(find.text('Health answers to read first'), findsOneWidget);
    });

    testWidgets('tapping a request opens her answers, and Accept answers it', (
      tester,
    ) async {
      deskPhone(tester);
      final repo = seeded();
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      await tester.tap(find.text('Mona Ali asked to join'));
      await tester.pumpAndSettle();
      final sheet = find.byType(AppSheet);
      expect(repo.responses, isEmpty);
      expect(
        find.descendant(of: sheet, matching: find.text('Her answers')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('Please go slowly')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.textContaining('heart condition'),
        ),
        findsOneWidget,
      );
      final accept = find.descendant(of: sheet, matching: find.text('Accept'));
      await tester.ensureVisible(accept);
      await tester.pumpAndSettle();
      await tester.tap(accept);
      await tester.pumpAndSettle();
      expect(repo.responses, [('r1', true, null)]);
    });

    testWidgets('Decline asks for a reason chip and sends it', (tester) async {
      deskPhone(tester);
      final repo = seeded();
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      await tester.tap(find.text('Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Why are you declining?'), findsOneWidget);
      expect(repo.responses, isEmpty);
      await tester.tap(find.text('My places are full'));
      await tester.pumpAndSettle();
      expect(repo.responses, [('r1', false, CoachDeclineReason.full)]);
      expect(find.text('Request declined'), findsOneWidget);
    });

    testWidgets('a refused answer says so calmly', (tester) async {
      deskPhone(tester);
      final repo = seeded(flagged: false)
        ..failResponse = const CoachingFailure(CoachingRefusal.wrongStatus);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(
        find.text('Something went wrong. Please try again.'),
        findsOneWidget,
      );
    });

    testWidgets('Message opens that client chat', (tester) async {
      deskPhone(tester);
      final repo = seeded();
      final state = await startedState(tester, repo);
      final opened = <String>[];
      await tester.pumpWidget(
        deskHost(
          CoachDeskView(
            state: state,
            now: () => kDeskNow,
            onOpenChat: opened.add,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Message').first);
      expect(opened, [relOf('ua')]);
    });

    testWidgets('no clients: the empty state teaches', (tester) async {
      deskPhone(tester);
      final state = await startedState(tester, DeskRepo());
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      expect(find.text('No clients yet'), findsOneWidget);
      expect(
        find.text('Share your portfolio link so members can ask to join.'),
        findsOneWidget,
      );
    });

    testWidgets('K07 with no clients shows one Invite a client button', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, DeskRepo());
      var taps = 0;
      await tester.pumpWidget(
        deskHost(
          CoachDeskView(
            state: state,
            now: () => kDeskNow,
            onInviteClient: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Invite a client'));
      expect(taps, 1);
      final filled = tester
          .widgetList<AppButton>(find.byType(AppButton))
          .where((b) => b.variant == AppButtonVariant.filled);
      expect(filled.length, 1);
    });

    testWidgets('all clear: says she is caught up', (tester) async {
      deskPhone(tester);
      final repo = DeskRepo()
        ..setSubscriptions([deskSub('a', name: 'Nour')])
        ..setRelationships([deskRel('ua', lastAt: ago(1), sender: 'me')]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      expect(find.text('You are all caught up'), findsOneWidget);
    });

    testWidgets('a long section shows five rows and Show all opens the list', (
      tester,
    ) async {
      deskPhone(tester);
      final repo = DeskRepo()
        ..setSubscriptions([
          for (var i = 0; i < 12; i++)
            deskSub('s$i', name: 'Client $i', startsAt: ago(10 + i)),
        ])
        ..setRelationships([
          for (var i = 0; i < 12; i++)
            deskRel('us$i', lastAt: ago(10 + i), sender: 'me'),
        ]);
      final state = await startedState(tester, repo);
      DeskFilter? opened;
      await tester.pumpWidget(
        deskHost(
          CoachDeskView(
            state: state,
            now: () => kDeskNow,
            onOpenClients: (f) => opened = f,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('No message from you in 21 days'), findsOneWidget);
      expect(find.text('No message from you in 17 days'), findsOneWidget);
      expect(find.text('No message from you in 16 days'), findsNothing);
      await tester.ensureVisible(find.text('Show all 12'));
      await tester.pump();
      await tester.tap(find.text('Show all 12'));
      expect(opened, DeskFilter.followUp);
    });
  });

  group('Clients', () {
    DeskRepo many(int n) {
      final repo = DeskRepo()
        ..setSubscriptions([
          for (var i = 0; i < n; i++)
            deskSub('s$i', name: 'Mona $i', startsAt: ago(1)),
        ])
        ..setRelationships([
          for (var i = 0; i < n; i++)
            deskRel(
              'us$i',
              lastAt: kDeskNow.subtract(Duration(minutes: i + 1)),
              unread: i % 50 == 0 ? 1 : 0,
            ),
        ]);
      return repo;
    }

    testWidgets('300 clients build lazily and the last one can be reached', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, many(300));
      await tester.pumpWidget(
        deskHost(ClientsView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      final built = find.byType(DeskClientRow).evaluate().length;
      expect(built, greaterThan(3));
      expect(built, lessThan(40));
      expect(find.text('Mona 0'), findsOneWidget);

      for (var i = 0; i < 12 && find.text('Mona 299').evaluate().isEmpty; i++) {
        await tester.fling(
          find.byType(CustomScrollView),
          const Offset(0, -3000),
          6000,
        );
        await tester.pumpAndSettle();
      }
      expect(find.text('Mona 299'), findsOneWidget);
    });

    testWidgets('search narrows by name', (tester) async {
      deskPhone(tester);
      final state = await startedState(tester, many(300));
      await tester.pumpWidget(
        deskHost(ClientsView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'mona 123');
      await tester.pump();
      expect(find.byType(DeskClientRow), findsOneWidget);
      expect(find.text('Mona 123'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pump();
      expect(find.text('Nobody matches that search.'), findsOneWidget);
    });

    testWidgets('the Unread chip keeps the chats with unread lines', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, many(300));
      await tester.pumpWidget(
        deskHost(ClientsView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      expect(find.text('Unread · 6'), findsOneWidget);
      await tester.tap(find.text('Unread · 6'));
      await tester.pump();
      expect(find.byType(DeskClientRow), findsNWidgets(6));
      expect(find.byType(UnreadBadge), findsNWidgets(6));
    });

    testWidgets('a row opens the chat; her avatar opens the details', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, many(3));
      final chats = <String>[];
      final details = <String>[];
      await tester.pumpWidget(
        deskHost(
          ClientsView(
            state: state,
            now: () => kDeskNow,
            onOpenChat: chats.add,
            onOpenClient: details.add,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Mona 1'));
      expect(chats, [relOf('us1')]);
      await tester.tap(find.bySemanticsLabel('Open the details of Mona 1'));
      expect(details, ['s1']);
    });

    testWidgets('a client with no message yet says so', (tester) async {
      deskPhone(tester);
      final repo = DeskRepo()..setSubscriptions([deskSub('a', name: 'Nour')]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(ClientsView(state: state, now: () => kDeskNow)),
      );
      await tester.pump();

      expect(find.text('No messages yet'), findsOneWidget);
      expect(find.text('Strong in 4 weeks · 20 days left'), findsOneWidget);
    });
  });

  group('Client details', () {
    DeskRepo one({DateTime? healthReviewedAt}) => DeskRepo()
      ..setSubscriptions([
        deskSub(
          'a',
          name: 'Nour Hassan',
          intake: deskIntake(health: true, ack: true),
          healthReviewedAt: healthReviewedAt,
        ),
      ])
      ..setRelationships([deskRel('ua', lastAt: ago(1))])
      ..setPlans([
        CoachPlan(
          id: 'p1',
          kind: PlanKind.workout,
          coachUid: 'me',
          name: 'Week one',
          publishedAt: ago(1),
        ),
      ]);

    testWidgets('shows her package, answers and the plans shared', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, one());
      await tester.pumpWidget(
        deskHost(
          ClientDetailView(subId: 'a', state: state, now: () => kDeskNow),
        ),
      );
      await tester.pump();

      expect(find.text('Nour Hassan'), findsOneWidget);
      expect(find.text('Strong in 4 weeks'), findsOneWidget);
      expect(find.text('20 days left'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Shared with you while you coach her'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('She ticked that she will check with her doctor'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('Week one'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Week one'), findsOneWidget);
    });

    testWidgets('the quick actions call back with the subscription', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, one(healthReviewedAt: ago(2)));
      final calls = <String>[];
      await tester.pumpWidget(
        deskHost(
          ClientDetailView(
            subId: 'a',
            state: state,
            now: () => kDeskNow,
            onOpenChat: (id) => calls.add('chat $id'),
            onShareWorkout: (id) => calls.add('workout $id'),
            onShareMeal: (id) => calls.add('meal $id'),
            onScheduleSession: (id) => calls.add('session $id'),
          ),
        ),
      );
      await tester.pump();

      for (final label in [
        'Message',
        'Share a workout',
        'Share a meal plan',
        'Schedule a live session',
      ]) {
        await tester.tap(find.text(label));
      }
      expect(calls, [
        'chat ${relOf('ua')}',
        'workout a',
        'meal a',
        'session a',
      ]);
    });

    testWidgets('the private note is saved on this phone and comes back', (
      tester,
    ) async {
      deskPhone(tester);
      final state = await startedState(tester, one());
      await tester.pumpWidget(
        deskHost(
          ClientDetailView(subId: 'a', state: state, now: () => kDeskNow),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Save note'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(find.byType(TextField), 'knee, ask on Thursday');
      await tester.tap(find.text('Save note'));
      await tester.pump();
      expect(
        CoachClientNotes.instance.forClient('ua'),
        'knee, ask on Thursday',
      );

      await tester.pumpWidget(deskHost(const SizedBox()));
      await tester.pumpWidget(
        deskHost(
          ClientDetailView(subId: 'a', state: state, now: () => kDeskNow),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Save note'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('knee, ask on Thursday'), findsOneWidget);
    });

    testWidgets('an unknown client says so', (tester) async {
      deskPhone(tester);
      final state = await startedState(tester, DeskRepo());
      await tester.pumpWidget(
        deskHost(ClientDetailView(subId: 'zzz', state: state)),
      );
      await tester.pump();
      expect(find.text('We could not find this client.'), findsOneWidget);
    });

    testWidgets('W02 holds the plan buttons until she has read the answers', (
      tester,
    ) async {
      deskPhone(tester);
      final store = InMemoryHealthReviewStore();
      HealthReviews.override = store;
      final sub = deskSub(
        'held1',
        name: 'Sara',
        intake: const Intake(lifeStage: 'pregnant'),
      );
      final repo = DeskRepo()..setSubscriptions([sub]);
      final state = await startedState(tester, repo);

      bool buttonEnabled(String label) {
        final btn = tester.widget<AppButton>(
          find.widgetWithText(AppButton, label),
        );
        return btn.onPressed != null;
      }

      await tester.pumpWidget(
        deskHost(
          ClientDetailView(
            subId: 'held1',
            state: state,
            now: () => kDeskNow,
            onShareWorkout: (_) {},
            onShareMeal: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Read her health answers first'), findsOneWidget);
      expect(
        find.text('Plans are on hold until you have. Her answers are below.'),
        findsOneWidget,
      );
      expect(buttonEnabled('Share a workout'), isFalse);
      expect(buttonEnabled('Share a meal plan'), isFalse);

      store.works = false;
      await tester.tap(find.text('I have read them'));
      await tester.pumpAndSettle();
      expect(find.text('Read her health answers first'), findsOneWidget);
      expect(buttonEnabled('Share a workout'), isFalse);

      store.works = true;
      await tester.tap(find.text('I have read them'));
      await tester.pumpAndSettle();
      expect(find.text('Read her health answers first'), findsNothing);
      expect(buttonEnabled('Share a workout'), isTrue);
      expect(buttonEnabled('Share a meal plan'), isTrue);
      expect(store.read, ['held1']);
    });
  });

  group('text scale 2.0, English and Arabic', () {
    for (final lang in ['en', 'ar']) {
      testWidgets('Today, Clients and Details do not overflow in $lang', (
        tester,
      ) async {
        deskPhone(tester);
        final repo = DeskRepo()
          ..setSubscriptions([
            deskSub(
              'r1',
              status: SubscriptionStatus.requested,
              name: 'منى عبد الرحمن',
              createdAt: ago(1),
              intake: deskIntake(health: true, ack: true),
            ),
            deskSub(
              'a',
              name: 'نور حسن عبد العزيز المصري',
              startsAt: ago(10),
              intake: deskIntake(health: true, ack: true),
              nextSessionAt: DateTime(2026, 10, 24, 18, 30),
            ),
          ])
          ..setRelationships([
            deskRel(
              'ua',
              lastAt: ago(0, 2),
              unread: 120,
              text: 'ممكن نغير ميعاد التمرين بتاع بكرة لأن عندي ظرف مفاجئ',
            ),
          ]);
        final state = await startedState(tester, repo);

        for (final screen in <Widget>[
          CoachDeskView(state: state, now: () => kDeskNow),
          ClientsView(state: state, now: () => kDeskNow),
          ClientDetailView(subId: 'a', state: state, now: () => kDeskNow),
        ]) {
          await tester.pumpWidget(deskHost(screen, lang: lang, scale: 2));
          await tester.pump();
          expect(tester.takeException(), isNull);
          // Scroll the whole page to find any late overflow.
          final scrollable = find.byType(Scrollable);
          if (scrollable.evaluate().isNotEmpty) {
            await tester.drag(scrollable.first, const Offset(0, -3000));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }
        }
      });
    }

    testWidgets('Arabic reads right to left with Western digits', (
      tester,
    ) async {
      deskPhone(tester);
      final repo = DeskRepo()
        ..setSubscriptions([deskSub('a', name: 'نور', startsAt: ago(10))])
        ..setRelationships([deskRel('ua', lastAt: ago(10))]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(
          ClientsView(state: state, now: () => kDeskNow),
          lang: 'ar',
        ),
      );
      await tester.pump();

      expect(
        Directionality.of(tester.element(find.byType(DeskClientRow))),
        TextDirection.rtl,
      );
      expect(find.text('فاضل 20 يوم'), findsNothing);
      expect(find.textContaining('فاضل 20 يوم'), findsOneWidget);
    });
  });

  group('Needs attention', () {
    testWidgets('K07 lists clients that need attention, with reasons, first', (
      tester,
    ) async {
      deskPhone(tester);
      CheckIns.override = InMemoryCheckInStore(
        rows: const <AttentionRow>[
          AttentionRow(
            subId: 's1',
            relId: 'r1',
            clientName: 'Mona',
            reasons: <String>['noCheckIn', 'unread'],
          ),
        ],
      );
      final repo = DeskRepo()
        ..setSubscriptions([deskSub('a', name: 'Nour', startsAt: ago(10))])
        ..setRelationships([deskRel('ua', lastAt: ago(10), sender: 'me')]);
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs attention'), findsOneWidget);
      expect(find.text('Mona'), findsOneWidget);
      expect(find.text('No check-in yet · Unread message'), findsOneWidget);

      final attentionTop = tester.getTopLeft(find.text('Needs attention')).dy;
      final followUpTop = tester.getTopLeft(find.text('Follow up')).dy;
      expect(attentionTop, lessThan(followUpTop));
    });

    testWidgets(
      'a row shows her pain answer and her own note, and a blank name reads as the rest of the desk does',
      (tester) async {
        deskPhone(tester);
        CheckIns.override = InMemoryCheckInStore(
          rows: const <AttentionRow>[
            AttentionRow(
              subId: 'a',
              relId: 'r1',
              clientName: '',
              reasons: <String>['healthFlag'],
              pain: true,
              note: 'my knee hurts when I squat',
            ),
            AttentionRow(
              subId: 'b',
              relId: 'r2',
              clientName: 'Mona',
              reasons: <String>[],
              note: 'loved the new plan',
            ),
          ],
        );
        final repo = DeskRepo()
          ..setSubscriptions([deskSub('a', startsAt: ago(10))])
          ..setRelationships([deskRel('ua', lastAt: ago(10), sender: 'me')]);
        final state = await startedState(tester, repo);
        await tester.pumpWidget(
          deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Health answer to read · Pain or injury this week\nmy knee hurts when I squat',
          ),
          findsOneWidget,
        );
        expect(find.text('loved the new plan'), findsOneWidget);
        expect(find.textContaining('Client #'), findsWidgets);
      },
    );

    testWidgets('tapping a row opens that client', (tester) async {
      deskPhone(tester);
      CheckIns.override = InMemoryCheckInStore(
        rows: const <AttentionRow>[
          AttentionRow(
            subId: 's1',
            relId: 'r1',
            clientName: 'Mona',
            reasons: <String>['noCheckIn'],
          ),
        ],
      );
      String? opened;
      final repo = DeskRepo();
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(
          CoachDeskView(
            state: state,
            now: () => kDeskNow,
            onOpenClient: (id) => opened = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mona'));
      await tester.pump();
      expect(opened, 's1');
    });

    testWidgets('no rows means no heading, in Arabic too', (tester) async {
      deskPhone(tester);
      CheckIns.override = InMemoryCheckInStore();
      final repo = DeskRepo();
      final state = await startedState(tester, repo);
      await tester.pumpWidget(
        deskHost(CoachDeskView(state: state, now: () => kDeskNow)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Needs attention'), findsNothing);

      await tester.pumpWidget(
        deskHost(
          CoachDeskView(
            key: const ValueKey('ar-empty-desk'),
            state: state,
            now: () => kDeskNow,
          ),
          lang: 'ar',
        ),
      );
      await tester.pumpAndSettle();
      // Only the CountTile label ('To follow up') has 'محتاجة متابعة', no section heading.
      expect(find.text('محتاجة متابعة'), findsOneWidget);

      CheckIns.override = InMemoryCheckInStore(
        rows: const <AttentionRow>[
          AttentionRow(
            subId: 's1',
            relId: 'r1',
            clientName: 'منى',
            reasons: <String>['unread'],
          ),
        ],
      );
      await tester.pumpWidget(
        deskHost(
          CoachDeskView(
            key: const ValueKey('ar-desk'),
            state: state,
            now: () => kDeskNow,
          ),
          lang: 'ar',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('محتاجة متابعة'), findsNWidgets(2));
      expect(find.text('رسالة ماتقرتش'), findsOneWidget);
    });
  });
}
