// Implements TEST-CASES.csv: P1-RULE-09 (undo, never confirmation),
// P0-LOG-02 (undo within five seconds) and the offline half of P0-LOG-09.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';

void main() {
  group('P0-LOG-02 — a log can be taken back within five seconds', () {
    test('nothing is committed until the window closes', () {
      fakeAsync((async) {
        var committed = 0;
        final bus = LogCommandBus();
        bus.submit(
          UndoableLog(
            describe: 'Goblet squat, 12 kg × 10',
            commit: () async => committed++,
          ),
        );

        async.elapse(const Duration(seconds: 4));
        expect(committed, 0, reason: 'still inside the undo window');

        async.elapse(const Duration(seconds: 2));
        expect(committed, 1, reason: 'window closed, so it persisted');
        bus.dispose();
      });
    });

    test('undo inside the window prevents the write entirely', () {
      fakeAsync((async) {
        var committed = 0;
        final bus = LogCommandBus();
        final handle = bus.submit(
          UndoableLog(
            describe: 'Ful and baladi',
            commit: () async => committed++,
          ),
        );

        async.elapse(const Duration(seconds: 3));
        expect(handle.undo(), isTrue);

        async.elapse(const Duration(seconds: 10));
        expect(
          committed,
          0,
          reason:
              'the write never reached the repository, so there is '
              'nothing queued to resurface when she reconnects',
        );
        bus.dispose();
      });
    });

    test('undo after the window reports false instead of throwing', () {
      fakeAsync((async) {
        final bus = LogCommandBus();
        final handle = bus.submit(
          UndoableLog(describe: 'x', commit: () async {}),
        );
        async.elapse(const Duration(seconds: 6));

        // A woman tapping Undo a moment late must not crash her session.
        expect(handle.undo(), isFalse);
        bus.dispose();
      });
    });

    test('leaving the screen commits rather than losing the log', () {
      fakeAsync((async) {
        var committed = 0;
        final bus = LogCommandBus();
        bus.submit(UndoableLog(describe: 'x', commit: () async => committed++));

        bus.flushAll();
        async.flushMicrotasks();
        expect(committed, 1);
        bus.dispose();
      });
    });

    test('the snackbar names the same numbers the button named', () {
      fakeAsync((async) {
        final bus = LogCommandBus();
        final handle = bus.submit(
          UndoableLog(
            describe: 'Goblet squat, 12 kg × 10',
            commit: () async {},
          ),
        );
        expect(handle.describe, 'Goblet squat, 12 kg × 10');
        bus.dispose();
      });
    });
  });

  group('P1-RULE-09 — confirmation is not expressible', () {
    test('several logs each keep their own window', () {
      fakeAsync((async) {
        final committed = <String>[];
        final bus = LogCommandBus();

        final first = bus.submit(
          UndoableLog(
            describe: 'set 1',
            commit: () async => committed.add('set 1'),
          ),
        );
        async.elapse(const Duration(seconds: 2));
        bus.submit(
          UndoableLog(
            describe: 'set 2',
            commit: () async => committed.add('set 2'),
          ),
        );

        expect(first.undo(), isTrue);
        async.elapse(const Duration(seconds: 10));

        expect(committed, [
          'set 2',
        ], reason: 'undoing one log must not disturb another');
        bus.dispose();
      });
    });

    test('isPending reports the window honestly', () {
      fakeAsync((async) {
        final bus = LogCommandBus();
        final handle = bus.submit(
          UndoableLog(describe: 'x', commit: () async {}),
        );
        expect(bus.isPending(handle), isTrue);
        async.elapse(const Duration(seconds: 6));
        expect(bus.isPending(handle), isFalse);
        bus.dispose();
      });
    });
  });
}
