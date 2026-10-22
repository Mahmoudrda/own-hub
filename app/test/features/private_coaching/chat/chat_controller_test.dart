import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/chat_screen.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_controller.dart';

import 'chat_support.dart';

ChatThreadController make(
  FakeChatRepository repo, {
  String? subId = 'sub1',
  Duration markDelay = const Duration(seconds: 2),
  int? unreadAtOpen,
}) => ChatThreadController(
  repository: repo,
  relId: 'c1__me',
  myUid: 'me',
  otherUid: 'c1',
  subId: subId,
  now: () => kClock,
  markDelay: markDelay,
  unreadAtOpen: unreadAtOpen,
);

void main() {
  test('one live listener while open, cancelled on dispose', () async {
    final repo = FakeChatRepository();
    final c = make(repo)..start();
    await Future<void>.delayed(Duration.zero);
    expect(repo.lineListens, 1);
    expect(repo.lineCancels, 0);
    c.start();
    expect(repo.lineListens, 1);
    c.dispose();
    await Future<void>.delayed(Duration.zero);
    expect(repo.lineCancels, 1);
    // A late push after dispose must not throw.
    repo.push([line('a', 'c1', 'x')]);
  });

  test('opening marks the thread read once', () async {
    final repo = FakeChatRepository();
    final c = make(repo)..start();
    await Future<void>.delayed(Duration.zero);
    expect(repo.count('markThreadRead'), 1);
    c.dispose();
  });

  test('opening with nothing unread makes no mark call', () async {
    final repo = FakeChatRepository();
    final c = make(repo, unreadAtOpen: 0)..start();
    await Future<void>.delayed(Duration.zero);
    expect(repo.count('markThreadRead'), 0);
    c.dispose();
  });

  test(
    'unread count 0 but the newest first line is hers to read: marks',
    () async {
      final repo = FakeChatRepository()..current = [line('a', 'c1', 'a')];
      final c = make(repo, unreadAtOpen: 0)..start();
      await Future<void>.delayed(Duration.zero);
      expect(repo.count('markThreadRead'), 1);
      c.dispose();
    },
  );

  test('unread count 0 and the newest first line is mine: no mark', () async {
    final repo = FakeChatRepository()
      ..current = [line('m', 'me', 'mine'), line('a', 'c1', 'a')];
    final c = make(repo, unreadAtOpen: 0)..start();
    await Future<void>.delayed(Duration.zero);
    expect(repo.count('markThreadRead'), 0);
    c.dispose();
  });

  test('opening with unread lines marks the thread once', () async {
    final repo = FakeChatRepository();
    final c = make(repo, unreadAtOpen: 3)..start();
    await Future<void>.delayed(Duration.zero);
    expect(repo.count('markThreadRead'), 1);
    c.dispose();
  });

  test('a line arriving after an unmarked open is still marked', () {
    fakeAsync((async) {
      final repo = FakeChatRepository();
      final c = make(repo, unreadAtOpen: 0)..start();
      async.flushMicrotasks();
      repo.push([line('a', 'c1', 'a')]);
      async.flushMicrotasks();
      repo.push([line('b', 'c1', 'b'), line('a', 'c1', 'a')]);
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 3));
      expect(repo.count('markThreadRead'), 1);
      c.dispose();
    });
  });

  test('lines arriving while open mark read at most once per delay', () {
    fakeAsync((async) {
      final repo = FakeChatRepository();
      final c = make(repo)..start();
      async.flushMicrotasks();
      repo.push([line('a', 'c1', 'a')]);
      async.flushMicrotasks();
      expect(
        repo.count('markThreadRead'),
        1,
        reason: 'the first batch is the open',
      );
      repo.push([line('b', 'c1', 'b'), line('a', 'c1', 'a')]);
      repo.push([
        line('c', 'c1', 'c'),
        line('b', 'c1', 'b'),
        line('a', 'c1', 'a'),
      ]);
      async.elapse(const Duration(seconds: 1));
      expect(repo.count('markThreadRead'), 1);
      async.elapse(const Duration(seconds: 2));
      expect(repo.count('markThreadRead'), 2);
      async.elapse(const Duration(seconds: 10));
      expect(
        repo.count('markThreadRead'),
        2,
        reason: 'nothing new, nothing sent',
      );
      c.dispose();
    });
  });

  test('her own new line does not mark read', () {
    fakeAsync((async) {
      final repo = FakeChatRepository()..current = [line('a', 'c1', 'a')];
      final c = make(repo)..start();
      async.flushMicrotasks();
      repo.push([line('m', 'me', 'mine', pending: true), line('a', 'c1', 'a')]);
      async.elapse(const Duration(seconds: 5));
      expect(repo.count('markThreadRead'), 1);
      c.dispose();
    });
  });

  test('in the background it waits, and marks when she comes back', () {
    fakeAsync((async) {
      final repo = FakeChatRepository();
      final c = make(repo)..start();
      async.flushMicrotasks();
      c.foreground = false;
      repo.push([line('a', 'c1', 'a')]);
      repo.push([line('b', 'c1', 'b'), line('a', 'c1', 'a')]);
      async.elapse(const Duration(seconds: 5));
      expect(repo.count('markThreadRead'), 1);
      c.foreground = true;
      async.flushMicrotasks();
      expect(repo.count('markThreadRead'), 2);
      c.dispose();
    });
  });

  test('a contact number is refused before anything is written', () {
    final repo = FakeChatRepository();
    final c = make(repo)..start();
    final outcome = c.send('call me on 01012345678');
    expect(outcome, isA<Refused>());
    expect((outcome as Refused).reason, ChatScreenReason.contact);
    expect(repo.count('sendText'), 0);
    expect(make(repo).send('   '), isA<NothingToSend>());
    c.dispose();
  });

  test('each reason is told apart', () {
    final repo = FakeChatRepository();
    final c = make(repo);
    ChatScreenReason? reason(String t) => (c.send(t) as Refused).reason;
    expect(reason('send to instapay'), ChatScreenReason.payment);
    expect(reason('see www.example.com'), ChatScreenReason.link);
    expect(reason('you are stupid'), ChatScreenReason.abuse);
    c.dispose();
  });

  test('a good line is sent once, trimmed', () async {
    final repo = FakeChatRepository();
    final c = make(repo)..start();
    expect(c.send('  see you at 6  '), isA<Sent>());
    await Future<void>.delayed(Duration.zero);
    expect(repo.count('sendText'), 1);
    c.dispose();
  });

  test('a refusal that comes back later gives the text back', () async {
    final repo = FakeChatRepository()
      ..failWith['sendText'] = const CoachingFailure(
        CoachingRefusal.badRequest,
      );
    final c = make(repo)..start();
    expect(c.send('hello'), isA<Sent>());
    await Future<void>.delayed(Duration.zero);
    expect(c.takeSendFailure()?.text, 'hello');
    expect(c.takeSendFailure(), isNull);
    c.dispose();
  });

  group('older pages', () {
    test('one get() per page; a short page is the start', () async {
      final repo = FakeChatRepository();
      repo.olderPages['c1__me'] = [
        for (var i = 0; i < 3; i++)
          line('o$i', 'c1', 'old $i', at: DateTime.utc(2026, 10, 1, 10 - i)),
      ];
      repo.push([
        for (var i = 0; i < CoachingLimits.messagePageSize; i++)
          line(
            'l$i',
            'c1',
            'x',
            at: DateTime.utc(2026, 10, 24, 10).subtract(Duration(minutes: i)),
          ),
      ]);
      final c = make(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(c.reachedStart, isFalse);
      await c.loadOlder();
      expect(repo.count('olderMessages'), 1);
      expect(c.lines.length, CoachingLimits.messagePageSize + 3);
      expect(c.reachedStart, isTrue);
      await c.loadOlder();
      expect(repo.count('olderMessages'), 1, reason: 'no read past the start');
      c.dispose();
    });

    test('a window under one page is already the start', () async {
      final repo = FakeChatRepository()..current = [line('a', 'c1', 'a')];
      final c = make(repo)..start();
      await Future<void>.delayed(Duration.zero);
      expect(c.reachedStart, isTrue);
      await c.loadOlder();
      expect(repo.count('olderMessages'), 0);
      c.dispose();
    });
  });

  test('unseen counts lines that arrive while she reads above', () async {
    final repo = FakeChatRepository()..current = [line('a', 'c1', 'a')];
    final c = make(repo)..start();
    await Future<void>.delayed(Duration.zero);
    repo.push([line('b', 'c1', 'b'), line('a', 'c1', 'a')]);
    await Future<void>.delayed(Duration.zero);
    expect(c.unseen, 0);
    c.scrolledUp(true);
    repo.push([
      line('c', 'c1', 'c'),
      line('b', 'c1', 'b'),
      line('a', 'c1', 'a'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(c.unseen, 1);
    c.scrolledUp(false);
    expect(c.unseen, 0);
    c.dispose();
  });

  test('session documents are listened to only once a card exists', () async {
    final repo = FakeChatRepository();
    final c = make(repo)..start();
    repo.push([line('a', 'c1', 'a')]);
    await Future<void>.delayed(Duration.zero);
    expect(repo.sessions.containsKey('sub1'), isFalse);
    repo.push([
      line('s', 'c1', '', type: MessageType.session, sessionId: 's1'),
      line('a', 'c1', 'a'),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(repo.sessions.containsKey('sub1'), isTrue);
    expect(await c.confirmSession('s1'), isTrue);
    expect(repo.count('respondLiveSession'), 1);
    c.dispose();
  });

  group('report and block', () {
    test('reporting a line writes its ids and the reason', () async {
      final repo = FakeChatRepository();
      final c = make(repo);
      await c.reportMessage(
        line('m9', 'c1', 'x'),
        reason: 'harassment',
        note: 'n',
        locale: 'en',
      );
      final call = repo.calls.singleWhere((x) => x.$1 == 'reportMessage').$2;
      expect(call, {
        'relId': 'c1__me',
        'messageId': 'm9',
        'senderUid': 'c1',
        'reason': 'harassment',
        'note': 'n',
        'locale': 'en',
      });
      c.dispose();
    });

    test('reporting the profile goes to the coach', () async {
      final repo = FakeChatRepository();
      final c = make(repo);
      await c.reportProfile(reason: 'spam', locale: 'ar');
      expect(repo.calls.last.$1, 'reportCoachProfile');
      expect(repo.calls.last.$2['coachUid'], 'c1');
      c.dispose();
    });

    test(
      'blocking uses the app\'s block list with the message source',
      () async {
        final blocks = InMemoryBlockService(selfUid: 'me');
        final c = make(FakeChatRepository());
        await c.block(blocks);
        expect(blocks.writes, ['block:c1']);
        expect(blocks.blocks().single.source, BlockSource.message);
        c.dispose();
      },
    );

    test(
      'the latest line from the other party is what a profile report cites',
      () async {
        final repo = FakeChatRepository()
          ..current = [line('b', 'me', 'b'), line('a', 'c1', 'a')];
        final c = make(repo)..start();
        await Future<void>.delayed(Duration.zero);
        expect(c.lastFromOther?.id, 'a');
        c.dispose();
      },
    );
  });
}
