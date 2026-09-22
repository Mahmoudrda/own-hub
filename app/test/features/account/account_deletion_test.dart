// P0-DEL-01 — account and data deletion actually deletes.
//
// The hardest case in the product, and the one whose failure mode is silence: a
// deletion that reports success while data survives looks identical, from the
// screen, to one that worked. So every test here asserts something the screen
// could not show you.
//
// The three properties, in the order G7 §3.3 ranks them:
//
//   1. Auth locked FIRST, Auth record deleted LAST.
//   2. Not offline-capable — no optimistic state, no local tombstone, no
//      progress bar that is not backed by a server ack.
//   3. The client-side wipe, which is the half that fails on-device while
//      passing on the server.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/account_deletion_service.dart';
import 'package:own_hub/features/account/domain/deletion_manifest.dart';

({
  AccountDeletionService service,
  FakeDeletionTransport transport,
  RecordingLocalWipe wipe,
})
_subject({bool online = true}) {
  final transport = FakeDeletionTransport(online: online);
  final wipe = RecordingLocalWipe();
  final service = AccountDeletionService(transport: transport, localWipe: wipe);
  addTearDown(() async {
    await service.dispose();
    await transport.close();
  });
  return (service: service, transport: transport, wipe: wipe);
}

void main() {
  group('deletion is not offline-capable, and does not pretend to be', () {
    test('with no connection it refuses, and nothing is requested', () async {
      final s = _subject(online: false);

      s.service.beginConfirmation();
      final outcome = await s.service.request();

      expect(outcome, DeletionOutcome.refusedOffline);
      expect(
        s.transport.requests,
        0,
        reason:
            'the callable fails offline, so success cannot be faked — a queued '
            'Firestore write would sync later and look like it worked',
      );
    });

    test('a refusal leaves no optimistic state and no tombstone', () async {
      final s = _subject(online: false);

      s.service.beginConfirmation();
      await s.service.request();

      expect(
        s.service.state,
        DeletionState.confirming,
        reason: 'it did not advance to requested',
      );
      expect(s.service.journal, [
        DeletionState.idle,
        DeletionState.confirming,
      ], reason: 'G7 §4: no optimistic state, no local tombstone');
    });

    test('a refusal runs no part of the local wipe', () async {
      final s = _subject(online: false);

      s.service.beginConfirmation();
      await s.service.request();

      expect(
        s.wipe.calls,
        isEmpty,
        reason:
            'signing her out because the network was down would destroy her '
            'session for a deletion that never happened',
      );
    });

    test('she can cancel the confirmation and nothing has changed', () async {
      final s = _subject();

      s.service.beginConfirmation();
      s.service.cancelConfirmation();

      expect(s.service.state, DeletionState.idle);
      expect(s.transport.requests, 0);
      expect(s.wipe.calls, isEmpty);
    });
  });

  group('progress comes from the server or it does not come at all', () {
    test('an accepted request advances only to requested', () async {
      final s = _subject();

      s.service.beginConfirmation();
      final outcome = await s.service.request();

      expect(outcome, DeletionOutcome.accepted);
      expect(s.transport.requests, 1);
      expect(
        s.service.state,
        DeletionState.requested,
        reason:
            'the client does not advance itself past the request — every state '
            'after this arrives on serverStates()',
      );
    });

    test(
      'the states the screen sees are the ones the server acknowledged',
      () async {
        final s = _subject();
        final seen = <DeletionState>[];
        s.service.states.listen(seen.add);

        s.service.beginConfirmation();
        await s.service.request();

        s.transport.emit(DeletionState.authLocked);
        s.transport.emit(DeletionState.purgingFirestore);
        s.transport.emit(DeletionState.purgingStorage);
        await pumpEventQueue();

        expect(seen, [
          DeletionState.confirming,
          DeletionState.requested,
          DeletionState.authLocked,
          DeletionState.purgingFirestore,
          DeletionState.purgingStorage,
        ]);
      },
    );

    test('a second request while one is running is refused', () async {
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();
      final again = await s.service.request();

      expect(again, DeletionOutcome.alreadyInProgress);
      expect(s.transport.requests, 1);
    });
  });

  group('order is the guarantee', () {
    test('Auth is locked before anything is purged', () {
      // Structural, via the ladder rather than via a comment.
      expect(
        DeletionState.authLocked.rank,
        lessThan(DeletionState.purgingFirestore.rank),
      );
      for (final purge in [
        DeletionState.purgingFirestore,
        DeletionState.purgingStorage,
        DeletionState.purgingGroupHooks,
        DeletionState.purgingThirdParty,
      ]) {
        expect(purge.isPurging, isTrue);
        expect(
          DeletionState.authLocked.rank,
          lessThan(purge.rank),
          reason: 'nothing can be written back mid-purge',
        );
      }
    });

    test('the Auth record is deleted after every purge', () {
      for (final purge in [
        DeletionState.purgingFirestore,
        DeletionState.purgingStorage,
        DeletionState.purgingGroupHooks,
        DeletionState.purgingThirdParty,
      ]) {
        expect(
          DeletionState.authDeleted.rank,
          greaterThan(purge.rank),
          reason:
              'deleting Auth last is what keeps the request attributable and '
              'resumable',
        );
      }
    });

    test('a server state that moves backwards is REJECTED, not believed', () async {
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();

      s.transport.emit(DeletionState.authLocked);
      s.transport.emit(DeletionState.purgingThirdParty);
      await pumpEventQueue();

      // A backend that announced the Auth record gone and then went back to
      // purging Firestore has got the order wrong. The client refuses it rather
      // than rendering a deletion that has not finished.
      s.transport.emit(DeletionState.authDeleted);
      await pumpEventQueue();
      s.transport.emit(DeletionState.purgingFirestore);
      await pumpEventQueue();

      expect(s.service.state, DeletionState.authDeleted);
      expect(s.service.rejected, [DeletionState.purgingFirestore]);
    });

    test('the full run reaches done, in order', () async {
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();

      for (final state in [
        DeletionState.authLocked,
        DeletionState.purgingFirestore,
        DeletionState.purgingStorage,
        DeletionState.purgingGroupHooks,
        DeletionState.purgingThirdParty,
        DeletionState.authDeleted,
        DeletionState.done,
      ]) {
        s.transport.emit(state);
        await pumpEventQueue();
      }

      expect(s.service.state, DeletionState.done);
      expect(s.service.rejected, isEmpty);

      // The journal is monotonic along the ladder.
      final ranks = s.service.journal.map((st) => st.rank).toList();
      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], greaterThan(ranks[i - 1]));
      }
    });
  });

  group('the client-side half', () {
    test('locking Auth wipes this handset, in the required order', () async {
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();
      s.transport.emit(DeletionState.authLocked);
      await pumpEventQueue();

      expect(
        s.wipe.calls,
        kLocalWipeOrder,
        reason:
            'sign out first — a still-authenticated SDK repopulates the cache '
            'that is about to be cleared; key last — wiping ciphertext while '
            'leaving the key is not deletion',
      );
      expect(s.wipe.calls, [
        'signOut',
        'terminateFirestore',
        'clearPersistence',
        'purgeLocalMeasurements',
        'destroyPhotoStoreKey',
      ]);
    });

    test('the wipe runs once, not on every subsequent state', () async {
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();
      for (final state in [
        DeletionState.authLocked,
        DeletionState.purgingFirestore,
        DeletionState.purgingStorage,
        DeletionState.done,
      ]) {
        s.transport.emit(state);
        await pumpEventQueue();
      }

      expect(s.wipe.calls, hasLength(kLocalWipeOrder.length));
    });

    test(
      'the local cache is cleared, or P0-DEL-01 fails on the device',
      () async {
        final s = _subject();

        s.service.beginConfirmation();
        await s.service.request();
        s.transport.emit(DeletionState.authLocked);
        await pumpEventQueue();

        // Without these two the woman's data is still readable from the
        // unbounded offline cache on this handset, while every server-side
        // assertion passes.
        expect(s.wipe.calls, contains('terminateFirestore'));
        expect(s.wipe.calls, contains('clearPersistence'));
        expect(
          s.wipe.calls.indexOf('terminateFirestore'),
          lessThan(s.wipe.calls.indexOf('clearPersistence')),
        );
      },
    );

    test('the client covers exactly the manifest rows only it can reach', () async {
      // Driven off the manifest, so a new handset-only row without a wipe step
      // is a visible omission rather than a silent survival.
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();
      s.transport.emit(DeletionState.authLocked);
      await pumpEventQueue();

      expect(kHandsetOnlyRows.map((r) => r.number).toList()..sort(), [
        9,
        33,
        34,
      ]);

      // Row 9 — the local sync queue, cleared by clearPersistence().
      expect(s.wipe.calls, contains('clearPersistence'));
      // Row 33 — G6's progress photos, which have no server copy at all.
      expect(s.wipe.calls, contains('purgeLocalMeasurements'));
      // Row 34 — the key that makes row 33 a deletion rather than a rename.
      expect(s.wipe.calls, contains('destroyPhotoStoreKey'));
    });
  });

  group('failure never reports success', () {
    test('only done is a success', () {
      expect(DeletionState.done.isSuccess, isTrue);

      for (final state in DeletionState.values.where(
        (s) => s != DeletionState.done,
      )) {
        expect(
          state.isSuccess,
          isFalse,
          reason: '${state.name} must not tell her the account is gone',
        );
      }
    });

    test(
      'failedRetryable is accepted from mid-purge and is not a success',
      () async {
        final s = _subject();

        s.service.beginConfirmation();
        await s.service.request();
        s.transport.emit(DeletionState.authLocked);
        await pumpEventQueue();
        s.transport.emit(DeletionState.purgingStorage);
        await pumpEventQueue();
        s.transport.emit(DeletionState.failedRetryable);
        await pumpEventQueue();

        expect(s.service.state, DeletionState.failedRetryable);
        expect(s.service.state.isSuccess, isFalse);
        expect(
          s.service.rejected,
          isEmpty,
          reason:
              'a failure can interrupt any step, so it is always admissible',
        );
      },
    );

    test('the sweeper can resume after a failure', () async {
      final s = _subject();

      s.service.beginConfirmation();
      await s.service.request();
      s.transport.emit(DeletionState.authLocked);
      await pumpEventQueue();
      s.transport.emit(DeletionState.failedRetryable);
      await pumpEventQueue();

      // reconciling re-runs anything not done after 15 minutes, and the run
      // picks up rather than starting over.
      s.transport.emit(DeletionState.reconciling);
      await pumpEventQueue();
      s.transport.emit(DeletionState.purgingFirestore);
      await pumpEventQueue();
      s.transport.emit(DeletionState.done);
      await pumpEventQueue();

      expect(s.service.state, DeletionState.done);
    });
  });
}
