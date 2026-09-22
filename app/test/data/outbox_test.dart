// Implements TEST-CASES.csv: P0-LOG-09 (log offline, sync later),
// P0-LOG-11 (two devices offline into the same meal slot), and P0-RWD-01
// (an award cannot be granted twice by an offline replay).
//
// These three are the reason spine constraints C1, C3 and C4 exist. Firestore
// resolves conflicts by last-write-wins and documents no idempotency guarantee
// on retry, so every one of these failures is the DEFAULT behaviour unless the
// write path is built to prevent it.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/data/sync/outbox.dart';
import 'package:own_hub/data/sync/write_intent.dart';

/// A sink that applies intents to an in-memory store, so merge behaviour can be
/// asserted exactly. Optionally fails, to test a partial drain.
class _FakeSink implements WriteSink {
  _FakeSink({this.failOn});

  final Map<String, Map<String, Object?>> store = {};
  final List<WriteIntent> applied = [];
  final String? failOn;

  @override
  Future<void> apply(WriteIntent intent) async {
    if (intent.dedupeKey == failOn) throw StateError('no signal');
    final doc = store.putIfAbsent(intent.path, () => {});
    doc[intent.field] = intent.applyTo(doc[intent.field]);
    applied.add(intent);
  }
}

void main() {
  group('P0-LOG-09 — logging offline, syncing later', () {
    test(
      'a write is queued immediately and sent when signal returns',
      () async {
        final sink = _FakeSink();
        final outbox = Outbox(sink: sink);

        outbox.enqueue(
          WriteIntent(
            path: 'users/u1/meals/2026-09-18',
            field: 'slots.lunch',
            value: ['koshari'],
            strategy: MergeStrategy.arrayUnion,
            dedupeKey: 'meal:2026-09-18:lunch:koshari',
          ),
        );

        expect(outbox.pendingCount, 1);
        expect(sink.applied, isEmpty, reason: 'nothing sent while offline');

        final result = await outbox.drain();
        expect(result.isComplete, isTrue);
        expect(outbox.pendingCount, 0);
        expect(sink.store['users/u1/meals/2026-09-18']!['slots.lunch'], [
          'koshari',
        ]);
        await outbox.dispose();
      },
    );

    test(
      'a failed drain keeps the rest queued rather than dropping them',
      () async {
        final sink = _FakeSink(failOn: 'b');
        final outbox = Outbox(sink: sink);

        for (final key in ['a', 'b', 'c']) {
          outbox.enqueue(
            WriteIntent(
              path: 'users/u1/sessions/s1',
              field: key,
              value: 1,
              strategy: MergeStrategy.increment,
              dedupeKey: key,
            ),
          );
        }

        final result = await outbox.drain();
        expect(result.sent, 1, reason: 'a succeeded, b threw');
        expect(result.isComplete, isFalse);
        expect(outbox.pendingCount, 2, reason: 'b and c are still hers');
        await outbox.dispose();
      },
    );

    test(
      're-draining after a failure does not re-apply what succeeded',
      () async {
        final sink = _FakeSink(failOn: 'b');
        final outbox = Outbox(sink: sink);
        for (final key in ['a', 'b']) {
          outbox.enqueue(
            WriteIntent(
              path: 'users/u1/x',
              field: key,
              value: 1,
              strategy: MergeStrategy.increment,
              dedupeKey: key,
            ),
          );
        }

        await outbox.drain();
        await outbox.drain();

        expect(
          sink.applied.where((i) => i.dedupeKey == 'a').length,
          1,
          reason: 'a must not be applied twice by a retried drain',
        );
        await outbox.dispose();
      },
    );
  });

  group('P0-RWD-01 — a replay cannot pay out twice', () {
    test('enqueueing the same intent twice leaves one', () async {
      final sink = _FakeSink();
      final outbox = Outbox(sink: sink);

      WriteIntent award() => WriteIntent(
        path: 'users/u1',
        field: 'rewards.points',
        value: 30,
        strategy: MergeStrategy.increment,
        // The key identifies the EVENT, not the field, so the same award
        // replayed on reconnect collides with itself.
        dedupeKey: 'award:session-s1',
      );

      outbox.enqueue(award());
      outbox.enqueue(award());

      expect(outbox.pendingCount, 1);
      await outbox.drain();
      expect(
        sink.store['users/u1']!['rewards.points'],
        30,
        reason: 'an increment is commutative but not idempotent',
      );
      await outbox.dispose();
    });

    test('an increment without an explicit dedupe key is rejected outright', () {
      // The assert is the enforcement: you cannot construct the dangerous case.
      expect(
        () => WriteIntent(
          path: 'users/u1',
          field: 'rewards.points',
          value: 30,
          strategy: MergeStrategy.increment,
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('two genuinely different awards both pay', () async {
      final sink = _FakeSink();
      final outbox = Outbox(sink: sink);
      for (final id in ['s1', 's2']) {
        outbox.enqueue(
          WriteIntent(
            path: 'users/u1',
            field: 'rewards.points',
            value: 30,
            strategy: MergeStrategy.increment,
            dedupeKey: 'award:$id',
          ),
        );
      }
      await outbox.drain();
      expect(sink.store['users/u1']!['rewards.points'], 60);
      await outbox.dispose();
    });
  });

  group('P0-LOG-11 — two devices, same meal slot, both survive', () {
    test('arrayUnion merges instead of overwriting', () {
      // The defect this prevents: a plain document merge would replace the array,
      // so whichever device syncs second erases the other's lunch.
      final phone = WriteIntent(
        path: 'users/u1/meals/2026-09-18',
        field: 'slots.lunch',
        value: ['koshari'],
        strategy: MergeStrategy.arrayUnion,
      );
      final tablet = WriteIntent(
        path: 'users/u1/meals/2026-09-18',
        field: 'slots.lunch',
        value: ['two eggs'],
        strategy: MergeStrategy.arrayUnion,
      );

      // Applied in either order, both items survive.
      expect(tablet.applyTo(phone.applyTo(null)), ['koshari', 'two eggs']);
      expect(phone.applyTo(tablet.applyTo(null)), ['two eggs', 'koshari']);
    });

    test('logging the same item twice does not double it', () {
      final again = WriteIntent(
        path: 'users/u1/meals/2026-09-18',
        field: 'slots.lunch',
        value: ['koshari'],
        strategy: MergeStrategy.arrayUnion,
      );
      expect(again.applyTo(['koshari']), ['koshari']);
    });

    test('lastWriteWins really does replace, so it is used deliberately', () {
      final goal = WriteIntent(
        path: 'users/u1',
        field: 'profile.goal',
        value: 'strength',
        strategy: MergeStrategy.lastWriteWins,
      );
      expect(goal.applyTo('general'), 'strength');
    });
  });

  group('the queue is honest about what is waiting', () {
    test('undo can discard a write that has not gone yet', () async {
      final sink = _FakeSink();
      final outbox = Outbox(sink: sink);
      outbox.enqueue(
        WriteIntent(
          path: 'users/u1/sessions/s1',
          field: 'sets',
          value: ['set1'],
          strategy: MergeStrategy.arrayUnion,
          dedupeKey: 'set:s1:1',
        ),
      );

      expect(outbox.isPending('set:s1:1'), isTrue);
      expect(outbox.discard('set:s1:1'), isTrue);
      expect(outbox.pendingCount, 0);

      await outbox.drain();
      expect(sink.applied, isEmpty);
      expect(outbox.discard('set:s1:1'), isFalse, reason: 'already gone');
      await outbox.dispose();
    });

    test('depth is reported for the quiet waiting-for-signal line', () async {
      final sink = _FakeSink();
      final outbox = Outbox(sink: sink);
      final seen = <int>[];
      final sub = outbox.depth.listen(seen.add);

      for (var i = 0; i < 3; i++) {
        outbox.enqueue(
          WriteIntent(
            path: 'users/u1/meals/2026-09-18',
            field: 'slots.snack',
            value: ['item$i'],
            strategy: MergeStrategy.arrayUnion,
            dedupeKey: 'snack:$i',
          ),
        );
      }
      await Future<void>.delayed(Duration.zero);
      expect(outbox.pendingCount, 3);
      expect(seen, [1, 2, 3]);

      await sub.cancel();
      await outbox.dispose();
    });
  });
}
