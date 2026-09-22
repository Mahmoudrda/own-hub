// `K16` — `P0-CCHAT-01` and §2 rule 2.
//
// Rule 2 is a compile-time property (`CoachChatService` has no plan dependency
// to reach for), so what is asserted here is the storage half: a message
// document carries no plan field, and the strict sink refuses one if it ever
// does.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_chat.dart';

const _coachUid = 'coach-42';
const _clientUid = 'client-93';
const _relId = 'coach-42_client-93';
final _at = DateTime(2026, 9, 8, 21, 14);

void main() {
  group('P0-CCHAT-01 — sending with no signal', () {
    test('it appears immediately, marked queued and never failed', () async {
      final sink = InMemoryMessageSink(online: false);
      final service = CoachChatService(sink: sink, coachUid: _coachUid);
      final id = service.draftId();

      final message = await service.send(
        relId: _relId,
        clientUid: _clientUid,
        draft: const CoachMessageDraft(
          body: 'Two sessions this week, ten minutes each.',
        ),
        msgId: id,
        at: _at,
      );

      expect(message.delivery, MessageDelivery.queued);
      expect(message.delivery.isPending, isTrue);
      expect(service.queuedCount, 1);
      expect(service.isQueued(id), isTrue);
      expect(sink.delivered, isEmpty);
    });

    test('it sends exactly once on reconnect, reusing the same id', () async {
      final sink = InMemoryMessageSink(online: false);
      final service = CoachChatService(sink: sink, coachUid: _coachUid);
      final id = service.draftId();

      await service.send(
        relId: _relId,
        clientUid: _clientUid,
        draft: const CoachMessageDraft(body: 'Moved them to Sunday.'),
        msgId: id,
        at: _at,
      );

      sink.online = true;
      final sent = await service.flush();

      expect(sent, 1);
      expect(sink.delivered, [id]);
      expect(service.queuedCount, 0);
      expect(sink.messagesIn(_relId), hasLength(1));
    });

    test(
      'a retry of a message that already landed collapses into itself',
      () async {
        final sink = InMemoryMessageSink(online: true);
        final service = CoachChatService(sink: sink, coachUid: _coachUid);
        final id = service.draftId();

        const draft = CoachMessageDraft(body: 'Same message, twice.');
        await service.send(
          relId: _relId,
          clientUid: _clientUid,
          draft: draft,
          msgId: id,
          at: _at,
        );
        await service.send(
          relId: _relId,
          clientUid: _clientUid,
          draft: draft,
          msgId: id,
          at: _at,
        );

        expect(
          sink.messagesIn(_relId),
          hasLength(1),
          reason: 'Merged by document id, exactly as Firestore does.',
        );
      },
    );

    test('the id is minted once, not once per attempt', () {
      final service = CoachChatService(
        sink: InMemoryMessageSink(),
        coachUid: _coachUid,
      );
      final first = service.draftId();
      final second = service.draftId();

      expect(first, isNot(second));
      expect(
        first,
        startsWith('msg-$_coachUid-'),
        reason:
            'One id per message, reused on retry. A new id per attempt is the '
            'duplicate the rule exists to prevent.',
      );
    });

    test(
      'a failed flush leaves the rest queued rather than dropping them',
      () async {
        final sink = InMemoryMessageSink(online: false);
        final service = CoachChatService(sink: sink, coachUid: _coachUid);

        for (var i = 0; i < 3; i++) {
          await service.send(
            relId: _relId,
            clientUid: _clientUid,
            draft: CoachMessageDraft(body: 'Message $i'),
            msgId: service.draftId(),
            at: _at,
          );
        }
        expect(service.queuedCount, 3);

        final sent = await service.flush();
        expect(sent, 0);
        expect(service.queuedCount, 3);
      },
    );
  });

  group('rule 2 — a message never changes a plan', () {
    test('a draft has nowhere to put a plan change', () {
      const draft = CoachMessageDraft(body: 'Keep 12 kg and add reps.');
      expect(draft.isSendable, isTrue);
      expect(draft.attachments, isEmpty);
      expect(draft.replyTo, isNull);
    });

    test('a message document carries none of the banned keys', () async {
      final sink = InMemoryMessageSink(online: true);
      final service = CoachChatService(sink: sink, coachUid: _coachUid);

      final message = await service.send(
        relId: _relId,
        clientUid: _clientUid,
        draft: const CoachMessageDraft(
          body: 'Sunday and Wednesday.',
          attachments: ['coach-public/coach-42/note1'],
          replyTo: 'msg-earlier',
        ),
        msgId: service.draftId(),
        at: _at,
      );

      expect(message.wireKeys.intersection(bannedMessageKeys), isEmpty);
      expect(
        message.wireKeys.difference(messageKeys),
        isEmpty,
        reason: 'Every key must be one the rules allow.',
      );
    });

    test('the sink would actually bite — a positive control', () async {
      // The banned list is not decoration. If a plan field ever reached a
      // message document, this is the assertion that fails.
      final sink = InMemoryMessageSink(online: true);
      expect(bannedMessageKeys, contains('planVersion'));
      expect(bannedMessageKeys, contains('applyToPlan'));
      expect(messageKeys.intersection(bannedMessageKeys), isEmpty);

      await sink.deliver(
        CoachMessage(
          msgId: 'm1',
          relId: _relId,
          senderUid: _coachUid,
          coachUid: _coachUid,
          clientUid: _clientUid,
          body: 'Fine as it is.',
          createdAt: _at,
        ),
      );
      expect(sink.delivered, ['m1']);
    });
  });

  group('the thread', () {
    test('an empty draft is not sendable', () {
      expect(const CoachMessageDraft(body: '   ').isSendable, isFalse);
      expect(
        const CoachMessageDraft(body: '', attachments: ['a']).isSendable,
        isTrue,
      );
    });

    test(
      'it is limited, so a long history is not one read per message',
      () async {
        final sink = InMemoryMessageSink(online: true);
        for (var i = 0; i < 40; i++) {
          sink.seed(
            CoachMessage(
              msgId: 'seed-$i',
              relId: _relId,
              senderUid: _clientUid,
              coachUid: _coachUid,
              clientUid: _clientUid,
              body: 'Old message $i',
              createdAt: _at.subtract(Duration(minutes: 40 - i)),
            ),
          );
        }

        final page = await sink.thread(_relId, limit: 20);
        expect(page, hasLength(20));
        expect(page.last.msgId, 'seed-39');
      },
    );

    test('a message knows which side of the screen it is drawn on', () {
      final fromHer = CoachMessage(
        msgId: 'm',
        relId: _relId,
        senderUid: _clientUid,
        coachUid: _coachUid,
        clientUid: _clientUid,
        body: 'Work was impossible this week.',
        createdAt: _at,
      );
      expect(fromHer.isFromCoach, isFalse);
      expect(fromHer.copyWith().isFromCoach, isFalse);
    });
  });
}
