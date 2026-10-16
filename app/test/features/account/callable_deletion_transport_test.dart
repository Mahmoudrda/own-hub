// S4: the real transport behind A02's deletion.
//
// It calls `delete_account`, replays the journal the server answered with,
// and lets `AccountDeletionService` hold its guarantees: the handset wipe runs
// on `authLocked`, `done` is the only success, and offline nothing is called.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/features/account/data/callable_deletion_transport.dart';
import 'package:own_hub/features/account/domain/account_deletion_service.dart';

const List<String> _journal = <String>[
  'requested',
  'authLocked',
  'purgingFirestore',
  'purgingStorage',
  'purgingGroupHooks',
  'purgingThirdParty',
  'authDeleted',
  'done',
];

Future<void> _drain() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'the journal names are the contract journal, and the app knows them',
    () {
      final contract = jsonDecode(
        File('../contracts/identity_contract.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      expect(contract['deletionJournal'], _journal);
      expect(
        CallableDeletionTransport.journalFrom(<String, Object?>{
          'journal': _journal,
        }).map((s) => s.name),
        _journal,
      );
      expect(
        (contract['callables'] as Map).keys,
        contains(kDeleteAccountCallable),
      );
    },
  );

  test(
    'a completed server deletion reaches done and wipes this phone once',
    () async {
      var calls = 0;
      final transport = CallableDeletionTransport(
        isOnline: () => true,
        call: () async {
          calls++;
          return <String, Object?>{'state': 'done', 'journal': _journal};
        },
      );
      final wipe = RecordingLocalWipe();
      final service = AccountDeletionService(
        transport: transport,
        localWipe: wipe,
      );

      expect(await service.request(), DeletionOutcome.accepted);
      await _drain();

      expect(calls, 1);
      expect(service.state, DeletionState.done);
      expect(wipe.calls, kLocalWipeOrder);
      await service.dispose();
    },
  );

  test('offline, nothing is called and nothing changes', () async {
    var calls = 0;
    final transport = CallableDeletionTransport(
      isOnline: () => false,
      call: () async {
        calls++;
        return null;
      },
    );
    final service = AccountDeletionService(
      transport: transport,
      localWipe: RecordingLocalWipe(),
    );
    expect(await service.request(), DeletionOutcome.refusedOffline);
    expect(calls, 0);
    expect(service.state, DeletionState.idle);
    await service.dispose();
  });

  test('a call that could not connect is offline, not a deletion', () async {
    final transport = CallableDeletionTransport(
      isOnline: () => true,
      call: () async =>
          throw FirebaseFunctionsException(message: 'x', code: 'unavailable'),
    );
    await expectLater(
      transport.requestDeletion(),
      throwsA(isA<DeletionOffline>()),
    );
  });

  test('a server failure is unfinished, never success', () async {
    final transport = CallableDeletionTransport(
      isOnline: () => true,
      call: () async => throw FirebaseFunctionsException(
        message: 'internal_error',
        code: 'internal',
      ),
    );
    await expectLater(
      transport.requestDeletion(),
      throwsA(isA<DeletionUnfinished>()),
    );
  });

  test('an answer that does not end in done is not success', () async {
    final transport = CallableDeletionTransport(
      isOnline: () => true,
      call: () async => <String, Object?>{
        'state': 'done',
        'journal': <String>['requested', 'authLocked'],
      },
    );
    await expectLater(
      transport.requestDeletion(),
      throwsA(isA<DeletionUnfinished>()),
    );
  });

  group('deleteAccount, as A02 runs it', () {
    test('done on the server is done, and this phone is wiped', () async {
      final wipe = RecordingLocalWipe();
      final result = await deleteAccount(
        transport: CallableDeletionTransport(
          isOnline: () => true,
          call: () async => <String, Object?>{
            'state': 'done',
            'journal': _journal,
          },
        ),
        wipe: wipe,
      );
      expect(result, AccountDeletionResult.done);
      expect(wipe.calls.take(5), kLocalWipeOrder);
    });

    test('offline: nothing deleted anywhere, nothing wiped', () async {
      final wipe = RecordingLocalWipe();
      final result = await deleteAccount(
        transport: CallableDeletionTransport(
          isOnline: () => true,
          call: () async => throw FirebaseFunctionsException(
            message: 'x',
            code: 'unavailable',
          ),
        ),
        wipe: wipe,
      );
      expect(result, AccountDeletionResult.offline);
      expect(wipe.calls, isEmpty);
    });

    test('App Check refusal: nothing deleted, told to update', () async {
      final wipe = RecordingLocalWipe();
      final result = await deleteAccount(
        transport: CallableDeletionTransport(
          isOnline: () => true,
          call: () async => throw FirebaseFunctionsException(
            message: 'app_check_missing',
            code: 'failed-precondition',
          ),
        ),
        wipe: wipe,
      );
      expect(result, AccountDeletionResult.appCannotReach);
      expect(wipe.calls, isEmpty);
    });

    test(
      'a server failure is unfinished, never done, and wipes this phone',
      () async {
        final wipe = RecordingLocalWipe();
        final result = await deleteAccount(
          transport: CallableDeletionTransport(
            isOnline: () => true,
            call: () async => throw FirebaseFunctionsException(
              message: 'internal_error',
              code: 'internal',
            ),
          ),
          wipe: wipe,
        );
        expect(result, AccountDeletionResult.unfinished);
        expect(wipe.calls, kLocalWipeOrder);
      },
    );
  });

  group('N9: no client write can follow the purge', () {
    test(
      'writes are stopped and the offline queue cleared before the call',
      () async {
        final order = <String>[];
        final result = await deleteAccount(
          transport: CallableDeletionTransport(
            isOnline: () => true,
            call: () async {
              order.add('delete_account');
              return <String, Object?>{'state': 'done', 'journal': _journal};
            },
          ),
          wipe: RecordingLocalWipe(),
          quiesce: () async => order.add('quiesce'),
        );
        expect(result, AccountDeletionResult.done);
        expect(order, <String>['quiesce', 'delete_account']);
      },
    );

    test('offline, nothing is quiesced and nothing is called', () async {
      final order = <String>[];
      final result = await deleteAccount(
        transport: CallableDeletionTransport(
          isOnline: () => false,
          call: () async {
            order.add('delete_account');
            return null;
          },
        ),
        wipe: RecordingLocalWipe(),
        quiesce: () async => order.add('quiesce'),
      );
      expect(result, AccountDeletionResult.offline);
      expect(order, isEmpty);
    });
  });
}
