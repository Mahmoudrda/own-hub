// ignore_for_file: avoid_print
//
// R5-06. What her snapshot costs as it grows.
//
// `main()` awaits `LocalPersistence.load()` before `runApp`, and that call
// `jsonDecode`s the whole document on the main isolate. On the emulator the
// await measured 256–285 ms on most launches and 6.7 ms on one — the 250 ms
// is a one-time platform-channel handshake that whichever call touches a
// channel first absorbs, and **6.7 ms is the real read-and-decode cost today**,
// against a store holding one week.
//
// It does not stay one week. `AppSnapshot.capture()` writes ten sections and
// nothing in the file prunes any of them: no byte cap, no record cap, no TTL.
// A training session is also stored twice — once in `train.sessions` and again,
// split per move, in `train.flushes` — so a 5-move, 3-set session costs about
// 5.8 KB rather than 2.9 KB.
//
// This measures `jsonEncode`/`jsonDecode` against snapshot-shaped documents at
// the sizes a year and two years of training produce, so the growth curve is a
// number rather than a worry. It asserts nothing: the figures below come off a
// laptop, and a 2020 budget Android runs Dart roughly four to six times slower.
// The curve is the finding.
@Tags(['qa'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// One logged set, exactly the shape `app_snapshot.dart:635-650` writes.
Map<String, Object?> _set(int i) => <String, Object?>{
  'prescribed': <String, Object?>{
    'exerciseId': 'hip_bridge_$i',
    'order': i,
    'weightKg': 12.5,
    'reps': 12,
    'holdSeconds': null,
  },
  'outcome': <String, Object?>{
    'weightKg': 12.5,
    'reps': 11,
    'holdSeconds': null,
    'skipped': false,
  },
};

/// One session envelope, as `app_snapshot.dart:598-611` writes it.
Map<String, Object?> _session(int i) => <String, Object?>{
  'id': 'session_$i',
  'workoutId': 'legs_and_glutes',
  'startedAt': '2026-03-0${(i % 9) + 1}T07:14:22.000Z',
  'finishedAt': '2026-03-0${(i % 9) + 1}T07:41:03.000Z',
  'weekKey': '2026-W${(i % 52) + 1}',
  'sets': <Map<String, Object?>>[for (var s = 0; s < 15; s++) _set(s)],
};

/// A document of roughly [sessions] training sessions, stored the way the app
/// stores them — the sets twice, once under `sessions` and once under
/// `flushes`.
String _document(int sessions) => jsonEncode(<String, Object?>{
  'version': 1,
  'train': <String, Object?>{
    'sessions': <Map<String, Object?>>[
      for (var i = 0; i < sessions; i++) _session(i),
    ],
    'flushes': <Map<String, Object?>>[
      for (var i = 0; i < sessions * 5; i++)
        <String, Object?>{
          'moveId': 'move_$i',
          'at': '2026-03-01T07:14:22.000Z',
          'sets': <Map<String, Object?>>[for (var s = 0; s < 3; s++) _set(s)],
        },
    ],
    'swaps': <Map<String, Object?>>[
      for (var i = 0; i < sessions; i++)
        <String, Object?>{'from': 'a_$i', 'to': 'b_$i'},
    ],
  },
});

void main() {
  test('snapshot encode and decode against a year of training', () {
    print('=== R5-06 snapshot cost by size (host; a budget Android is '
        '4-6x slower) ===');
    print('${"sessions".padRight(10)}${"document".padRight(12)}'
        '${"decode".padRight(11)}encode');

    // 4 sessions a week: ~200 a year, ~400 in two.
    for (final sessions in <int>[13, 52, 200, 400, 800]) {
      final doc = _document(sessions);
      final mb = doc.length / (1024 * 1024);

      // Warm the parser once so the first run does not pay for JIT.
      jsonDecode(doc);

      final decodeWatch = Stopwatch()..start();
      final parsed = jsonDecode(doc);
      decodeWatch.stop();

      final encodeWatch = Stopwatch()..start();
      jsonEncode(parsed);
      encodeWatch.stop();

      final weeks = (sessions / 4).round();
      print('${sessions.toString().padRight(10)}'
          '${"${mb.toStringAsFixed(2)} MB".padRight(12)}'
          '${"${decodeWatch.elapsedMilliseconds} ms".padRight(11)}'
          '${encodeWatch.elapsedMilliseconds} ms'
          '   (~$weeks weeks of training)');
    }

    print('  decode is on the cold-start path, awaited before runApp.');
    print('  encode runs on every 400 ms debounced write, i.e. while she is '
        'logging.');
  });
}
