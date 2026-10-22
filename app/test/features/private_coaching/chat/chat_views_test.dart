import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_list_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_logic.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_sheets.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';

import 'chat_support.dart';

const ChatPerson _coach = ChatPerson(
  uid: 'c1',
  name: 'Coach Sara',
  subtitle: 'Your coach',
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<FakeChatRepository> _thread(
  WidgetTester tester, {
  List<ChatMessage>? lines,
  Locale locale = const Locale('en'),
  double scale = 1,
  bool open = true,
  ShareChoices share = const ShareChoices(),
  bool otherIsCoach = true,
  ChatPerson person = _coach,
  InMemoryBlockService? blocks,
  void Function(String)? onOpenLink,
  FakeChatRepository? repo,
}) async {
  _phone(tester);
  final r = repo ?? FakeChatRepository();
  r.current = lines ?? r.current;
  await tester.pumpWidget(
    app(
      ChatThreadView(
        repository: r,
        relId: 'c1__me',
        myUid: 'me',
        person: person,
        otherIsCoach: otherIsCoach,
        subId: 'sub1',
        open: open,
        share: share,
        blocks: blocks,
        onOpenLink: onOpenLink,
        now: () => kClock,
      ),
      locale: locale,
      scale: scale,
    ),
  );
  await tester.pump();
  await tester.pump();
  return r;
}

List<ChatMessage> _sample() => [
  line('4', 'me', 'See you at six', pending: true),
  line('3', 'me', 'Done, thank you', at: DateTime(2026, 10, 24, 11, 5)),
  line('2', 'c1', 'How did the squats feel?', at: DateTime(2026, 10, 24, 11)),
  line('1', 'me', 'Hello coach', at: DateTime(2026, 10, 23, 20)),
];

void main() {
  group('thread', () {
    testWidgets('bubbles, day separators and the three tick states', (
      tester,
    ) async {
      final repo = FakeChatRepository();
      repo.otherRead.value = DateTime(2026, 10, 24, 11, 30);
      await _thread(tester, lines: _sample(), repo: repo);
      expect(find.text('See you at six'), findsOneWidget);
      expect(find.text('How did the squats feel?'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('Coach Sara'), findsOneWidget);
      expect(find.text('Your coach'), findsOneWidget);
      // Pending: clock. 11:05 line was read after (11:30): two ticks. The
      // 20:00 line yesterday also reads as two.
      expect(find.byIcon(Icons.access_time), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNWidgets(2));
      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.text('11:05'), findsOneWidget);
    });

    testWidgets('one tick until her read marker passes the line', (
      tester,
    ) async {
      await _thread(
        tester,
        lines: [line('3', 'me', 'hi', at: DateTime(2026, 10, 24, 11))],
      );
      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets(
      'each bubble has a spoken label with sender, text, time and state',
      (tester) async {
        final handle = tester.ensureSemantics();
        await _thread(tester, lines: _sample());
        expect(
          find.bySemanticsLabel('You, Done, thank you, 11:05, Sent'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Coach Sara, How did the squats feel?, 11:00'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('You, See you at six, Sending'),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    for (final (name, locale) in [
      ('English', const Locale('en')),
      ('Arabic', const Locale('ar')),
    ]) {
      testWidgets('$name at text scale 2.0 lays out without overflow', (
        tester,
      ) async {
        final repo = FakeChatRepository();
        await _thread(
          tester,
          lines: [
            ..._sample(),
            line('h', 'c1', 'x', hidden: true),
            line(
              'p',
              'c1',
              '',
              type: MessageType.workoutPlan,
              planName: 'Strength week 1',
            ),
            line(
              's',
              'c1',
              '',
              type: MessageType.session,
              sessionId: 's1',
              startsAt: DateTime(2026, 10, 25, 18),
              minutes: 45,
            ),
            line(
              'y',
              'c1',
              '',
              type: MessageType.system,
              systemKind: SystemMessageKind.endsSoon,
            ),
          ],
          locale: locale,
          scale: 2,
          share: ShareChoices(onRecipe: () {}),
          repo: repo,
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(TextField), findsOneWidget);
      });
    }

    testWidgets('in Arabic my bubble sits on the left and hers on the right', (
      tester,
    ) async {
      await _thread(
        tester,
        lines: [
          line('2', 'me', 'ازيك', at: DateTime(2026, 10, 24, 11, 5)),
          line('1', 'c1', 'تمام', at: DateTime(2026, 10, 24, 11)),
        ],
        locale: const Locale('ar'),
      );
      final mine = tester.getTopLeft(find.text('ازيك')).dx;
      final hers = tester.getTopLeft(find.text('تمام')).dx;
      expect(mine, lessThan(hers));
      final box = tester.getSize(find.byType(Scaffold));
      expect(mine, lessThan(box.width / 2));
      expect(hers, greaterThan(box.width / 2));
    });

    testWidgets('in English my bubble sits on the right', (tester) async {
      await _thread(
        tester,
        lines: [
          line('2', 'me', 'hi there', at: DateTime(2026, 10, 24, 11, 5)),
          line('1', 'c1', 'hello', at: DateTime(2026, 10, 24, 11)),
        ],
      );
      expect(
        tester.getTopLeft(find.text('hi there')).dx,
        greaterThan(tester.getTopLeft(find.text('hello')).dx),
      );
    });

    testWidgets('the live listener is cancelled when the thread closes', (
      tester,
    ) async {
      final repo = await _thread(tester, lines: _sample());
      expect(repo.lineListens, 1);
      expect(repo.lineCancels, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(repo.lineCancels, 1);
    });

    testWidgets('opening the thread marks it read', (tester) async {
      final repo = await _thread(tester, lines: _sample());
      expect(repo.count('markThreadRead'), 1);
    });

    testWidgets('an empty thread says hello', (tester) async {
      await _thread(tester, lines: const []);
      expect(find.text('No messages yet. Say hello.'), findsOneWidget);
    });

    testWidgets('a hidden line shows the notice, not the words', (
      tester,
    ) async {
      await _thread(
        tester,
        lines: [line('h', 'me', 'call 01012345678', hidden: true)],
      );
      expect(
        find.text(
          'This message was hidden because it had contact or payment details',
        ),
        findsOneWidget,
      );
      expect(find.text('call 01012345678'), findsNothing);
    });

    testWidgets('system lines read as centred notes', (tester) async {
      await _thread(
        tester,
        lines: [
          line(
            'y',
            'c1',
            '',
            type: MessageType.system,
            systemKind: SystemMessageKind.started,
          ),
        ],
      );
      expect(find.text('Coaching started'), findsOneWidget);
    });
  });

  group('composer', () {
    testWidgets(
      'a phone number is not sent; the text stays and the reason is calm',
      (tester) async {
        final repo = await _thread(tester, lines: _sample());
        await tester.enterText(find.byType(TextField), 'call 01012345678');
        await tester.pump();
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        expect(
          find.textContaining("Phone numbers can't be sent in the chat"),
          findsOneWidget,
        );
        expect(find.text('call 01012345678'), findsOneWidget);
        expect(repo.count('sendText'), 0);
        // Editing the text clears the note.
        await tester.enterText(find.byType(TextField), 'call me');
        await tester.pump();
        expect(find.textContaining("Phone numbers can't"), findsNothing);
      },
    );

    testWidgets('payment, link and abuse each get their own sentence', (
      tester,
    ) async {
      await _thread(tester, lines: _sample());
      for (final (text, expected) in [
        ('pay by instapay', 'Payment details'),
        ('go to www.example.com', 'Links'),
        ('you are stupid', 'Some words in this message'),
      ]) {
        await tester.enterText(find.byType(TextField), text);
        await tester.pump();
        await tester.tap(find.byTooltip('Send'));
        await tester.pump();
        expect(find.textContaining(expected), findsOneWidget, reason: text);
      }
    });

    testWidgets('the same refusal in Arabic', (tester) async {
      await _thread(
        tester,
        lines: _sample(),
        locale: const Locale('ar'),
        scale: 2,
      );
      await tester.enterText(find.byType(TextField), 'كلميني 01012345678');
      await tester.pump();
      await tester.tap(find.byTooltip(l10nFor('ar').send));
      await tester.pump();
      expect(find.textContaining('مينفعش نبعت أرقام تليفون'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a good line is sent and the field clears', (tester) async {
      final repo = await _thread(tester, lines: _sample());
      await tester.enterText(find.byType(TextField), 'Thank you coach');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      expect(repo.count('sendText'), 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });

    testWidgets('send is off while the field is blank', (tester) async {
      await _thread(tester, lines: _sample());
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets(
      'a client has no plus; a coach does, and each choice calls back',
      (tester) async {
        await _thread(tester, lines: _sample());
        expect(find.byTooltip('Share something'), findsNothing);
        final taps = <String>[];
        await _thread(
          tester,
          lines: _sample(),
          share: ShareChoices(
            onRecipe: () => taps.add('recipe'),
            onWorkoutPlan: () => taps.add('workout'),
            onMealPlan: () => taps.add('meal'),
            onSession: () => taps.add('session'),
          ),
        );
        for (final (label, key) in [
          ('Share a recipe', 'recipe'),
          ('Share a workout plan', 'workout'),
          ('Share a meal plan', 'meal'),
          ('Schedule a live session', 'session'),
        ]) {
          await tester.tap(find.byTooltip('Share something'));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(taps.last, key);
        }
        expect(taps.length, 4);
      },
    );

    testWidgets('a closed thread is read-only with a banner', (tester) async {
      await _thread(tester, lines: _sample(), open: false);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.text(
          'This coaching has ended. You can read the chat but not write in it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Done, thank you'), findsOneWidget);
    });
  });

  group('cards', () {
    LiveSession session(
      SessionStatus status, {
      String proposedBy = 'c1',
      String link = 'https://meet.google.com/abc-defg-hij',
    }) => LiveSession(
      id: 's1',
      status: status,
      startsAt: DateTime(2026, 10, 25, 18),
      minutes: 45,
      link: link,
      proposedBy: proposedBy,
    );

    List<ChatMessage> withSession() => [
      line(
        's',
        'c1',
        '',
        type: MessageType.session,
        sessionId: 's1',
        startsAt: DateTime(2026, 10, 25, 18),
        minutes: 45,
      ),
      line('1', 'c1', 'hi', at: DateTime(2026, 10, 23, 12)),
    ];

    testWidgets('the client confirms a proposed session', (tester) async {
      final repo = FakeChatRepository();
      repo.sessions['sub1'] = Feed<List<LiveSession>>([
        session(SessionStatus.proposed),
      ]);
      await _thread(tester, lines: withSession(), repo: repo);
      await tester.pump();
      expect(find.text('45 min'), findsOneWidget);
      expect(find.text('Waiting for confirmation'), findsOneWidget);
      expect(find.text('Join the call'), findsNothing);
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      expect(repo.count('respondLiveSession'), 1);
    });

    testWidgets('the client can say she cannot make it', (tester) async {
      final repo = FakeChatRepository();
      repo.sessions['sub1'] = Feed<List<LiveSession>>([
        session(SessionStatus.proposed),
      ]);
      await _thread(tester, lines: withSession(), repo: repo);
      await tester.pump();
      await tester.tap(find.text("Can't make it"));
      await tester.pump();
      expect(repo.count('respondLiveSession'), 1);
      expect(repo.calls.last.$2['confirm'], isFalse);
    });

    testWidgets('a confirmed session opens its link in the browser', (
      tester,
    ) async {
      final repo = FakeChatRepository();
      repo.sessions['sub1'] = Feed<List<LiveSession>>([
        session(SessionStatus.confirmed),
      ]);
      String? opened;
      await _thread(
        tester,
        lines: withSession(),
        repo: repo,
        onOpenLink: (l) => opened = l,
      );
      await tester.pump();
      expect(find.text('Confirm'), findsNothing);
      await tester.tap(find.text('Join the call'));
      expect(opened, 'https://meet.google.com/abc-defg-hij');
    });

    testWidgets('a link outside the meeting hosts is not opened', (
      tester,
    ) async {
      final repo = FakeChatRepository();
      repo.sessions['sub1'] = Feed<List<LiveSession>>([
        session(SessionStatus.confirmed, link: 'https://evil.example.com/x'),
      ]);
      String? opened;
      await _thread(
        tester,
        lines: withSession(),
        repo: repo,
        onOpenLink: (l) => opened = l,
      );
      await tester.pump();
      await tester.tap(find.text('Join the call'));
      expect(opened, isNull);
    });

    testWidgets('the coach who proposed it sees no Confirm', (tester) async {
      final repo = FakeChatRepository(uid: 'c1');
      repo.sessions['sub1'] = Feed<List<LiveSession>>([
        session(SessionStatus.proposed),
      ]);
      _phone(tester);
      await tester.pumpWidget(
        app(
          ChatThreadView(
            repository: repo,
            relId: 'c1__me',
            myUid: 'c1',
            person: const ChatPerson(uid: 'me', name: 'Mona'),
            subId: 'sub1',
            now: () => kClock,
          ),
        ),
      );
      repo.push([
        line(
          's',
          'c1',
          '',
          type: MessageType.session,
          sessionId: 's1',
          startsAt: DateTime(2026, 10, 25, 18),
          minutes: 45,
        ),
      ]);
      await tester.pump();
      await tester.pump();
      expect(find.text('Confirm'), findsNothing);
      expect(find.text('Live session'), findsOneWidget);
    });

    testWidgets('plan and recipe cards open through their callbacks', (
      tester,
    ) async {
      _phone(tester);
      final repo = FakeChatRepository()
        ..current = [
          line('r', 'c1', '', type: MessageType.recipe, recipeId: 'koshari'),
          line(
            'p',
            'c1',
            '',
            type: MessageType.workoutPlan,
            planName: 'Strength week 1',
          ),
        ];
      ChatMessage? plan;
      String? recipe;
      await tester.pumpWidget(
        app(
          ChatThreadView(
            repository: repo,
            relId: 'c1__me',
            myUid: 'me',
            person: _coach,
            otherIsCoach: true,
            recipeTitleOf: (id) => 'Koshari bowl',
            onOpenPlan: (m) => plan = m,
            onOpenRecipe: (id) => recipe = id,
            now: () => kClock,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Strength week 1'), findsOneWidget);
      expect(find.text('Koshari bowl'), findsOneWidget);
      await tester.tap(find.text('Open').first);
      await tester.tap(find.text('Open').last);
      expect(plan?.planName, 'Strength week 1');
      expect(recipe, 'koshari');
    });
  });

  group('mixed direction names', () {
    for (final (locale, shown) in [
      (const Locale('ar'), '\u2068day split-3\u2069'),
      (const Locale('en'), 'day split-3'),
    ]) {
      testWidgets('a plan name in ${locale.languageCode} keeps its own order', (
        tester,
      ) async {
        _phone(tester);
        final repo = FakeChatRepository()
          ..current = [
            line(
              'p',
              'c1',
              '',
              type: MessageType.workoutPlan,
              planName: 'day split-3',
            ),
          ];
        await tester.pumpWidget(
          app(
            ChatThreadView(
              repository: repo,
              relId: 'c1__me',
              myUid: 'me',
              person: _coach,
              otherIsCoach: true,
              now: () => kClock,
            ),
            locale: locale,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(find.text(shown), findsOneWidget);
      });
    }
  });

  group('scrolling', () {
    List<ChatMessage> many() => [
      for (var i = 0; i < 50; i++)
        line(
          'm$i',
          i.isEven ? 'c1' : 'me',
          'line number $i',
          at: DateTime(2026, 10, 24, 11).subtract(Duration(minutes: i)),
        ),
    ];

    testWidgets('reaching the top loads one older page', (tester) async {
      final repo = FakeChatRepository();
      repo.olderPages['c1__me'] = [
        for (var i = 0; i < 5; i++)
          line(
            'o$i',
            'c1',
            'older $i',
            at: DateTime(2026, 10, 20, 10).subtract(Duration(minutes: i)),
          ),
      ];
      await _thread(tester, lines: many(), repo: repo);
      for (var i = 0; i < 12; i++) {
        await tester.fling(find.byType(ListView), const Offset(0, 1500), 3000);
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.pumpAndSettle();
      expect(repo.count('olderMessages'), 1);
      expect(find.text('older 0', skipOffstage: false), findsOneWidget);
    });

    testWidgets(
      'a new line while scrolled up shows the pill, which jumps back',
      (tester) async {
        final repo = await _thread(tester, lines: many());
        await tester.drag(find.byType(ListView), const Offset(0, 400));
        await tester.pump();
        expect(find.text('New messages'), findsNothing);
        repo.push([
          line('new', 'c1', 'fresh news', at: DateTime(2026, 10, 24, 12)),
          ...many(),
        ]);
        await tester.pump();
        await tester.pump();
        expect(find.text('New messages'), findsOneWidget);
        await tester.tap(find.text('New messages'));
        await tester.pumpAndSettle();
        expect(find.text('New messages'), findsNothing);
        expect(find.text('fresh news'), findsOneWidget);
      },
    );
  });

  group('report and block', () {
    testWidgets('long press her line: report it with a reason', (tester) async {
      final repo = await _thread(tester, lines: _sample());
      await tester.longPress(find.text('How did the squats feel?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report this message'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Harassment or bullying'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      final call = repo.calls.singleWhere((c) => c.$1 == 'reportMessage').$2;
      expect(call['messageId'], '2');
      expect(call['senderUid'], 'c1');
      expect(call['reason'], 'harassment');
      expect(call['relId'], 'c1__me');
      expect(find.text('Your report is private.'), findsOneWidget);
    });

    testWidgets('her own line can be copied but not reported', (tester) async {
      await _thread(tester, lines: _sample());
      await tester.longPress(find.text('Done, thank you'));
      await tester.pumpAndSettle();
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Report this message'), findsNothing);
    });

    testWidgets('the menu reports a coach\'s profile', (tester) async {
      final repo = await _thread(tester, lines: _sample());
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or advertising'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.$1, 'reportCoachProfile');
      expect(repo.calls.last.$2['coachUid'], 'c1');
    });

    testWidgets('a coach reporting a client cites her latest line', (
      tester,
    ) async {
      final repo = await _thread(
        tester,
        otherIsCoach: false,
        person: const ChatPerson(uid: 'c1', name: 'Mona'),
        lines: _sample(),
      );
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spam or advertising'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.$1, 'reportMessage');
      expect(repo.calls.last.$2['messageId'], '2');
    });

    testWidgets('blocking asks first, then writes the block and leaves', (
      tester,
    ) async {
      final blocks = InMemoryBlockService(selfUid: 'me');
      await _thread(tester, lines: _sample(), blocks: blocks);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('Block Coach Sara?'), findsOneWidget);
      expect(blocks.writes, isEmpty);
      await tester.tap(find.widgetWithText(InkWell, 'Block').last);
      await tester.pumpAndSettle();
      expect(blocks.writes, ['block:c1']);
    });

    testWidgets('Not now leaves the block list alone', (tester) async {
      final blocks = InMemoryBlockService(selfUid: 'me');
      await _thread(tester, lines: _sample(), blocks: blocks);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(blocks.writes, isEmpty);
    });

    testWidgets('no block list, no Block in the menu', (tester) async {
      await _thread(tester, lines: _sample());
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      expect(find.text('Block'), findsNothing);
    });
  });

  group('list', () {
    ChatPerson who(String uid) =>
        ChatPerson(uid: uid, name: uid == 'c1' ? 'Coach Sara' : 'Coach Dina');

    Future<void> pumpList(
      WidgetTester tester,
      List<Relationship> rels, {
      Locale locale = const Locale('en'),
      double scale = 1,
      void Function(Relationship)? onOpen,
    }) async {
      _phone(tester);
      await tester.pumpWidget(
        app(
          ChatListView(
            relationships: rels,
            myUid: 'me',
            personOf: who,
            onOpen: onOpen ?? (_) {},
            now: () => kClock,
          ),
          locale: locale,
          scale: scale,
        ),
      );
      await tester.pumpAndSettle();
    }

    final rels = [
      rel(
        id: 'c2__me',
        coach: 'c2',
        last: LastMessage(
          text: 'Great work',
          senderUid: 'c2',
          at: DateTime(2026, 10, 23, 9),
        ),
      ),
      rel(
        id: 'c1__me',
        unread: {'me': 3},
        last: LastMessage(
          text: 'See you at six',
          senderUid: 'c1',
          at: DateTime(2026, 10, 24, 9, 5),
        ),
      ),
      rel(id: 'c3__me', coach: 'c3'),
    ];

    for (final (locale, mine) in [
      (const Locale('en'), 'My coach'),
      (const Locale('ar'), 'مدرّبتي'),
    ]) {
      testWidgets(
        'the coach list never names a client "$mine" (${locale.languageCode})',
        (tester) async {
          _phone(tester);
          await tester.pumpWidget(
            app(
              ChatListView(
                relationships: [rel(id: 'me__c9', coach: 'me', client: 'c9')],
                myUid: 'me',
                personOf: (uid) => ChatPerson(uid: uid, name: mine),
                onOpen: (_) {},
                now: () => kClock,
              ),
              locale: locale,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(mine), findsNothing);
        },
      );
    }

    testWidgets('the client list names the coach', (tester) async {
      await pumpList(tester, [rel()]);
      expect(find.text('Coach Sara'), findsOneWidget);
    });

    testWidgets('newest first, with preview, time and unread badge', (
      tester,
    ) async {
      await pumpList(tester, rels);
      final names = tester
          .widgetList<Text>(
            find.byWidgetPredicate(
              (w) =>
                  w is Text &&
                  (w.data == 'Coach Sara' || w.data == 'Coach Dina'),
            ),
          )
          .map((t) => t.data)
          .toList();
      expect(names, ['Coach Sara', 'Coach Dina', 'Coach Dina']);
      expect(find.text('See you at six'), findsOneWidget);
      expect(find.text('09:05'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('her own last line is marked You:', (tester) async {
      await pumpList(tester, [
        rel(
          last: LastMessage(
            text: 'Thank you',
            senderUid: 'me',
            at: DateTime(2026, 10, 24, 9),
          ),
        ),
      ]);
      expect(find.text('You: Thank you'), findsOneWidget);
    });

    testWidgets('search narrows by name, and says so when nothing matches', (
      tester,
    ) async {
      await pumpList(tester, rels);
      await tester.enterText(find.byType(TextField), 'sara');
      await tester.pump();
      expect(find.text('Coach Sara'), findsOneWidget);
      expect(find.text('Coach Dina'), findsNothing);
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pump();
      expect(find.text('No chats match your search.'), findsOneWidget);
    });

    testWidgets('no relationships: the empty state, no search', (tester) async {
      await pumpList(tester, const []);
      expect(find.text('No chats yet'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('tapping a row opens that relationship', (tester) async {
      Relationship? opened;
      await pumpList(tester, rels, onOpen: (r) => opened = r);
      await tester.tap(find.text('Coach Sara'));
      expect(opened?.id, 'c1__me');
    });

    testWidgets('a row is one spoken button with the unread count', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpList(tester, rels);
      expect(
        find.bySemanticsLabel('Coach Sara, See you at six, 09:05, 3 unread'),
        findsOneWidget,
      );
      handle.dispose();
    });

    for (final (name, locale) in [
      ('English', const Locale('en')),
      ('Arabic', const Locale('ar')),
    ]) {
      testWidgets('$name at text scale 2.0 lays out without overflow', (
        tester,
      ) async {
        await pumpList(tester, rels, locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
        await pumpList(tester, const [], locale: locale, scale: 2);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the row is at least 48 high', (tester) async {
      await pumpList(tester, rels);
      expect(
        tester.getSize(find.byType(ChatRowTile).first).height,
        greaterThanOrEqualTo(48),
      );
    });
  });
}
