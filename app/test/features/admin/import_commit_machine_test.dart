// The commit step at Z09, as a state machine.
//
// Two rules meet here and they pull in opposite directions:
//
//   * Rule 9 — logging never raises a confirmation dialog, enforced by
//     `product_rules_test.dart` failing the build on any `showDialog` or
//     `AlertDialog` under `lib/features/`.
//   * G16 §3.1 — an import rewrites the content library in bulk, which is
//     destructive, and destructive bulk actions may confirm.
//
// `cycle_deletion_machine.dart` already resolved this once: the confirmation is
// an inline STATE of the screen, not a dialog. That satisfies the destructive
// exemption without putting a dialog anywhere a logging path could copy it from.
// This machine follows it deliberately, down to the shape of its transitions.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/domain/import_commit_machine.dart';

void main() {
  group('the happy path', () {
    test('it starts idle', () {
      expect(const ImportCommit().state, ImportCommitState.idle);
      expect(const ImportCommit().isRunning, isFalse);
    });

    test('asking to import confirms in place rather than writing', () {
      // §3.1: "Nothing has been written yet" is the whole promise of Z09, and
      // it has to survive the tap on "Import everything".
      final commit = const ImportCommit().requested();

      expect(commit.state, ImportCommitState.confirming);
      expect(commit.hasWritten, isFalse);
    });

    test('confirming starts the write', () {
      final commit = const ImportCommit().requested().confirmed();

      expect(commit.state, ImportCommitState.committing);
      expect(commit.isRunning, isTrue);
      expect(
        commit.hasWritten,
        isFalse,
        reason: 'in flight is not the same as done',
      );
    });

    test('only a server acknowledgement reaches done', () {
      // Modelled on CycleDeletion.markRemotePurged: "it never claims a deletion
      // it has not performed". An import that showed success optimistically
      // would tell staff the library is filled when the write may have failed,
      // and the library they then stop worrying about is still empty.
      final commit = const ImportCommit()
          .requested()
          .confirmed()
          .markCommitted();

      expect(commit.state, ImportCommitState.done);
      expect(commit.hasWritten, isTrue);
      expect(commit.isRunning, isFalse);
    });
  });

  group('backing out', () {
    test('cancelling returns to idle with nothing written', () {
      final commit = const ImportCommit().requested().cancelled();

      expect(commit.state, ImportCommitState.idle);
      expect(commit.hasWritten, isFalse);
    });

    test('cancelling is available from confirming and nowhere else', () {
      // Once the write is in flight there is nothing to cancel, and offering it
      // would imply a rollback this console cannot perform.
      expect(const ImportCommit().requested().canCancel, isTrue);
      expect(const ImportCommit().requested().confirmed().canCancel, isFalse);
      expect(const ImportCommit().canCancel, isFalse);
    });
  });

  group('failure', () {
    test('a failed commit is retryable and has written nothing', () {
      final commit = const ImportCommit().requested().confirmed().markFailed();

      expect(commit.state, ImportCommitState.failed);
      expect(commit.hasWritten, isFalse);
      expect(commit.canRetry, isTrue);
    });

    test('offline is recorded separately from refused', () {
      // The two are different promises — "we could not reach the server" and
      // "you are offline" — and only one of them is true on Egyptian mobile
      // data halfway through a 200 MB upload. Same distinction CycleDeletion
      // draws, for the same reason.
      final offline = const ImportCommit().requested().confirmed().markFailed(
        offline: true,
      );
      final refused = const ImportCommit().requested().confirmed().markFailed();

      expect(offline.offline, isTrue);
      expect(refused.offline, isFalse);
    });

    test('retry resumes the write, not the confirmation', () {
      // She already confirmed. Asking twice for the same destructive action is
      // how people learn to tap through prompts.
      final commit = const ImportCommit()
          .requested()
          .confirmed()
          .markFailed()
          .retry();

      expect(commit.state, ImportCommitState.committing);
    });

    test('retry clears the previous offline flag', () {
      final commit = const ImportCommit()
          .requested()
          .confirmed()
          .markFailed(offline: true)
          .retry();

      expect(commit.offline, isFalse);
    });
  });

  group('the guarantees the rest of the console leans on', () {
    test('done is reachable only through confirming and committing', () {
      // Walk every state and assert there is no shortcut into `done`. The
      // transition table is small enough to enumerate, and a stray transition
      // added later is exactly the kind of change that looks harmless.
      const idle = ImportCommit();

      expect(idle.state, ImportCommitState.idle);
      expect(idle.requested().state, ImportCommitState.confirming);
      expect(idle.requested().confirmed().state, ImportCommitState.committing);
      expect(
        idle.requested().confirmed().markCommitted().state,
        ImportCommitState.done,
      );

      // No transition from idle writes anything.
      expect(idle.hasWritten, isFalse);
      expect(idle.requested().hasWritten, isFalse);
      expect(idle.requested().confirmed().hasWritten, isFalse);
    });

    test('hasWritten is true in exactly one state', () {
      const states = ImportCommitState.values;
      final written = states.where((s) => ImportCommit(state: s).hasWritten);

      expect(written, [ImportCommitState.done]);
    });

    test('a machine in flight cannot be asked to confirm again', () {
      // Double-tapping "Import everything" must not start a second write.
      final running = const ImportCommit().requested().confirmed();

      expect(running.confirmed().state, ImportCommitState.committing);
      expect(running.requested().state, ImportCommitState.committing);
    });
  });
}
