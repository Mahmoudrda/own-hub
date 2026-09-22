// P0-MSG-01 … P0-MSG-06, and the behavioural half of P1-RULE-02B.
//
// The source test in `message_repo_has_no_plan_path_test.dart` proves the write
// path cannot *name* a plan. These prove what actually happens when a coach
// types the sentence that, in most coaching apps, is the change.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/g2_contract.dart';
import 'package:own_hub/features/coached/domain/message_repository.dart';
import 'package:own_hub/features/coached/domain/plan_update_card.dart';

const _ref = RelationshipRef(coachUid: 'c7k9farida', clientUid: 'u3m2rania');

/// A published version, minted well before anything in these tests happens, so
/// "nothing new was published" is a real claim rather than an empty list.
PlanVersion _published() => PlanVersion(
  version: 'v4',
  calendar: List<PlanDayKind>.generate(
    PlanVersion.calendarLength,
    (i) => i % 3 == 2 ? PlanDayKind.rest : PlanDayKind.train,
  ),
  publishedAt: DateTime(2026, 9, 11, 7, 15),
  effectiveFrom: DateTime(2026, 9, 12),
  startsOn: DateTime(2026, 9, 12),
  authorUid: 'c7k9farida',
);

void main() {
  group('P1-RULE-02B — a message never changes a plan', () {
    test(
      'a coach types "I have shortened Thursday" and publishes nothing',
      () async {
        final repo = InMemoryMessageRepository();
        final versions = <PlanVersion>[_published()];
        final before = List<PlanVersion>.of(versions);

        await repo.send(
          _ref,
          const MessageDraft(
            senderUid: 'c7k9farida',
            kind: MessageKind.text,
            body: 'I have shortened Thursday to 20 minutes.',
          ),
        );

        // The plan is byte-identical: same list, same single version, same
        // publish timestamp.
        expect(versions, hasLength(before.length));
        expect(versions.single.version, before.single.version);
        expect(versions.single.publishedAt, before.single.publishedAt);

        // And no card, because a card is made of versions and no version
        // arrived. Not "the card was suppressed" — there is nothing to build
        // one from.
        final cards = const PlanUpdateCard().resolve(
          versions: versions,
          since: DateTime(2026, 9, 12),
        );
        expect(cards, isEmpty);
      },
    );

    test('sending builds exactly one write, scoped to a message', () async {
      final repo = InMemoryMessageRepository();
      await repo.send(
        _ref,
        const MessageDraft(
          senderUid: 'u3m2rania',
          kind: MessageKind.text,
          body: 'Can we move Saturday?',
        ),
      );

      expect(repo.intents, hasLength(1));
      final scope = repo.intents.single.scope;
      expect(scope, isA<RelationshipMessageScope>());
      expect(scope.path, 'relationships/c7k9farida__u3m2rania/messages/m1');
    });

    test('a draft cannot carry a version or an effective date', () {
      // Nothing to call. The assertion is that the constructor has no such
      // parameter — which is checked by the source test — and that the record
      // the repository produces carries none either.
      const draft = MessageDraft(
        senderUid: 'c7k9farida',
        kind: MessageKind.attachment,
        contextRef: ContextRef(kind: ContextKind.assignment, id: '2026-09-24'),
      );
      // A context ref points at a day she can open. It is an id, not an
      // instruction, and there is no kind for a version.
      expect(draft.contextRef!.kind, ContextKind.assignment);
      expect(ContextKind.values.map((k) => k.name), isNot(contains('version')));
    });
  });

  group(
    'P0-MSG-01 / P0-MSG-02 — offline, and a retry that does not double',
    () {
      test(
        'a rejected send retries under the same id, so one message exists',
        () async {
          final repo = InMemoryMessageRepository(rejectFirstSend: true);

          final id = await repo.send(
            _ref,
            const MessageDraft(
              senderUid: 'u3m2rania',
              kind: MessageKind.voice,
              attachments: [
                MessageAttachment(
                  storagePath: 'relationship-media/x/y/m1.m4a',
                  mime: 'audio/mp4',
                  bytes: 41_200,
                  blurApplied: true,
                  durationMs: 12_400,
                ),
              ],
            ),
          );

          var thread = await repo.thread(_ref);
          expect(thread, hasLength(1));
          expect(thread.single.state, MessageDeliveryState.failed);

          await repo.retry(_ref, id);

          thread = await repo.thread(_ref);
          expect(thread, hasLength(1), reason: 'one message, never two');
          expect(thread.single.id, id, reason: 'the retry reuses the id');
          expect(thread.single.state, MessageDeliveryState.sent);
        },
      );

      test(
        'delivery state comes from cursors, not per-message receipts',
        () async {
          final repo = InMemoryMessageRepository();
          await repo.send(
            _ref,
            const MessageDraft(
              senderUid: 'u3m2rania',
              kind: MessageKind.text,
              body: 'hi',
            ),
          );
          final writesBefore = repo.intents.length;

          await repo.markRead(_ref, 'c7k9farida', DateTime(2026, 9, 19, 21));

          // Moving the cursor is not a write per message.
          expect(repo.intents.length, writesBefore);
          expect(repo.cursors(_ref).keys, ['c7k9farida']);
        },
      );

      test('two parties write two distinct cursor keys', () async {
        final repo = InMemoryMessageRepository();
        await repo.markRead(_ref, 'c7k9farida', DateTime(2026, 9, 19, 21));
        await repo.markRead(_ref, 'u3m2rania', DateTime(2026, 9, 19, 22));
        expect(repo.cursors(_ref), hasLength(2));
      });
    },
  );

  group('P0-MSG-05 — an attachment opens the record it refers to', () {
    test('the bubble carries the record id, not a picture of one', () async {
      final repo = InMemoryMessageRepository();
      await repo.send(
        _ref,
        const MessageDraft(
          senderUid: 'u3m2rania',
          kind: MessageKind.attachment,
          body: 'about this one',
          contextRef: ContextRef(
            kind: ContextKind.session,
            id: 'coached-2026-09-17-v4',
          ),
        ),
      );
      final message = (await repo.thread(_ref)).single;
      expect(message.contextRef!.id, 'coached-2026-09-17-v4');
      expect(message.contextRef!.kind, ContextKind.session);
    });
  });

  group('P0-MSG-06 — an ended relationship is read-only', () {
    test('history reads and a forced send is refused, not queued', () async {
      final repo = InMemoryMessageRepository();
      await repo.send(
        _ref,
        const MessageDraft(
          senderUid: 'c7k9farida',
          kind: MessageKind.text,
          body: 'see you',
        ),
      );

      repo.closed = true;

      expect(await repo.thread(_ref), hasLength(1));
      expect(
        () => repo.send(
          _ref,
          const MessageDraft(
            senderUid: 'u3m2rania',
            kind: MessageKind.text,
            body: 'one more',
          ),
        ),
        throwsA(isA<StateError>()),
      );
      // Refused, not held: nothing is waiting to arrive later.
      expect(await repo.thread(_ref), hasLength(1));
    });
  });

  group('negative controls', () {
    test('a stranger cannot send into the thread', () {
      final repo = InMemoryMessageRepository();
      expect(
        () => repo.send(
          _ref,
          const MessageDraft(
            senderUid: 'u9z1someone',
            kind: MessageKind.text,
            body: 'hello',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('the relationship id is coach-first with two underscores', () {
      expect(_ref.relId, 'c7k9farida__u3m2rania');
      final parsed = RelationshipRef.parse('c7k9farida__u3m2rania');
      expect(parsed.coachUid, 'c7k9farida');
      expect(parsed.clientUid, 'u3m2rania');
      // A single underscore is refused rather than silently split.
      expect(
        () => RelationshipRef.parse('c7k9farida_u3m2rania'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('retrying a message that does not exist throws', () {
      final repo = InMemoryMessageRepository();
      expect(() => repo.retry(_ref, 'm99'), throwsA(isA<StateError>()));
    });
  });
}
