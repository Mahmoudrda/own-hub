import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/payments/data/payments_local_store.dart';
import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/data/pending_proofs.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_payments_repository.dart';

PendingProof proof({
  String key = 'abcdef0123456789abcdef01',
  String paymentId = 'p1',
}) => PendingProof(
  paymentId: paymentId,
  key: key,
  amountPiasters: 50037,
  txnNumber: '123456789012',
  senderHandle: 'sara.k@instapay',
  paidAtClaimed: DateTime.utc(2026, 10, 27, 11, 32),
  phoneReading: const {'success': true},
  otherPayerOk: false,
  files: const [],
);

void main() {
  late Directory dir;
  late PendingProofs queue;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('pending-proofs');
    queue = PendingProofs(dir: dir);
  });
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test(
    'add then flush sends with the stored key and deletes the pictures',
    () async {
      await queue.add(proof(), [
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList([4, 5]),
      ]);
      expect(dir.listSync().length, 2);
      final fake = FakePaymentsRepository();
      expect(await queue.flush(fake), 1);
      final c = fake.calls.single.$2;
      expect(c['key'], 'abcdef0123456789abcdef01');
      expect(c['images'], 2);
      expect(c['amount'], 50037);
      expect(c['txn'], '123456789012');
      expect(
        dir.listSync(),
        isEmpty,
        reason: 'no copy stays on the phone after it is sent',
      );
      expect(await queue.all(), isEmpty);
    },
  );

  test('the folder of queued pictures is kept out of the backup', () async {
    final kept = <String>[];
    dir.deleteSync(recursive: true);
    queue = PendingProofs(dir: dir, keepOutOfBackup: (p) async => kept.add(p));
    await queue.add(proof(), [Uint8List(3)]);
    await queue.add(proof(key: 'bbbbbbbbbbbbbbbbbbbbbbbb'), [Uint8List(3)]);
    expect(kept, [dir.path], reason: 'marked once, when it is created');

    await queue.clear();
    await queue.add(proof(), [Uint8List(3)]);
    expect(kept, [dir.path, dir.path], reason: 'and again when it is remade');
  });

  test('no signal stops the flush and keeps everything', () async {
    await queue.add(proof(), [Uint8List(3)]);
    final fake = FakePaymentsRepository()
      ..failNext = const PaymentFailure('', unreachable: true);
    expect(await queue.flush(fake), 0);
    expect((await queue.all()).length, 1);
    expect(dir.listSync().length, 1);
  });

  test(
    'a refusal the server will always repeat drops the entry and its pictures',
    () async {
      await queue.add(proof(), [Uint8List(3)]);
      final fake = FakePaymentsRepository()
        ..failNext = const PaymentFailure('txn_reused');
      expect(await queue.flush(fake), 0);
      expect(await queue.all(), isEmpty);
      expect(dir.listSync(), isEmpty);
    },
  );

  test(
    'adding the same key twice keeps one entry and one set of pictures',
    () async {
      await queue.add(proof(), [Uint8List(3)]);
      await queue.add(proof(), [Uint8List(3), Uint8List(3)]);
      expect((await queue.all()).length, 1);
      expect(dir.listSync().length, 2);
    },
  );

  test('two different proofs go out oldest first', () async {
    await queue.add(proof(key: 'aaaaaaaaaaaaaaaaaaaaaaaa', paymentId: 'p1'), [
      Uint8List(3),
    ]);
    await queue.add(proof(key: 'bbbbbbbbbbbbbbbbbbbbbbbb', paymentId: 'p2'), [
      Uint8List(3),
    ]);
    final fake = FakePaymentsRepository();
    expect(await queue.flush(fake), 2);
    expect([for (final c in fake.calls) c.$2['paymentId']], ['p1', 'p2']);
  });

  test('a missing picture drops that entry instead of looping', () async {
    await queue.add(proof(), [Uint8List(3)]);
    for (final f in dir.listSync()) {
      f.deleteSync();
    }
    expect(await queue.flush(FakePaymentsRepository()), 0);
    expect(await queue.all(), isEmpty);
  });

  test(
    'clear (Delete everything) removes the list and every picture',
    () async {
      await queue.add(proof(), [Uint8List(3)]);
      await queue.clear();
      expect(await queue.all(), isEmpty);
      expect(dir.existsSync(), isFalse);
    },
  );

  test('delete everything also forgets her handle and her answer', () async {
    final store = PaymentsLocalStore();
    await store.saveSenderHandle('Sara.K@InstaPay');
    await store.answerLearnConsent(true);
    expect(await store.senderHandle(), 'sara.k@instapay');
    await store.erase();
    expect(await store.senderHandle(), '');
    expect(await store.consentAsked(), isFalse);
    expect(await store.learnConsent(), isFalse);
  });

  test('a damaged queue reads as empty', () async {
    SharedPreferences.setMockInitialValues({
      'payments.pendingProofs': 'not json',
    });
    expect(await queue.all(), isEmpty);
  });
}
