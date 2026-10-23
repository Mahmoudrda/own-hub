// ignore_for_file: avoid_print
//
// R6-01. What her snapshot costs, measured against the document the app
// actually writes.
//
// R5-06 measured hand-written JSON shaped like the real thing. This measures
// the real thing: a populated `InMemoryTrainRepository` run through
// `AppSnapshot.capture()` and `jsonEncode`, so the figure moves when the
// persisted shape moves. That is the point — it is the before/after instrument
// for the flush de-duplication.
//
// Asserts nothing. The figures come off a laptop and a 2020 budget Android runs
// Dart roughly four to six times slower; the curve is the finding, and
// `test/app_state/snapshot_train_shape_test.dart` holds the ceiling that stops
// it regressing.
//
// What it read before and after the flush stopped repeating prescriptions,
// medians of nine on one laptop:
//
//   history           document            jsonEncode        jsonDecode
//   200 (~1 year)     0.88 -> 0.47 MB      5.2 -> 3.3 ms     5.2 -> 2.9 ms
//   400 (~2 years)    1.76 -> 0.93 MB     10.5 -> 6.6 ms    13.9 -> 5.3 ms
//   800 (~4 years)    3.52 -> 1.86 MB     20.8 -> 13.7 ms   27.0 -> 17.4 ms
//
// Per session: 4.50 KB -> 2.38 KB.
@Tags(['qa'])
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/routing/app_router.dart';

import 'history_fixture.dart';

/// Milliseconds for one [run], as the median of [runs] goes after a warm-up.
double _median(int runs, void Function() run) {
  run();
  final samples = <int>[];
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    run();
    watch.stop();
    samples.add(watch.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2] / 1000;
}

void main() {
  tearDown(AppRouter.trainRepository.reset);

  test('snapshot encode and decode against the shape the app writes', () {
    print(
      '=== R6-01 real snapshot cost by history (host; a budget Android is '
      '4-6x slower) ===',
    );
    print(
      '${"sessions".padRight(10)}${"document".padRight(12)}'
      '${"train".padRight(12)}${"decode".padRight(11)}encode',
    );

    // 4 sessions a week: ~200 a year, ~400 in two, ~800 in four.
    for (final sessions in <int>[13, 52, 200, 400, 800]) {
      fillTrainHistory(sessions: sessions);

      final captured = AppSnapshot.capture();
      final doc = jsonEncode(captured);
      final trainBytes = jsonEncode(captured['train']).length;
      final mb = doc.length / (1024 * 1024);

      // Medians of nine, so the figure is the one she pays most of the time
      // rather than whichever run the JIT or a GC landed on. The first run of
      // each is thrown away for the same reason.
      final decode = _median(9, () => jsonDecode(doc));
      final parsed = jsonDecode(doc);
      final encode = _median(9, () => jsonEncode(parsed));

      final weeks = (sessions / 4).round();
      print(
        '${sessions.toString().padRight(10)}'
        '${"${mb.toStringAsFixed(2)} MB".padRight(12)}'
        '${"${(trainBytes / (1024 * 1024)).toStringAsFixed(2)} MB".padRight(12)}'
        '${"${decode.toStringAsFixed(1)} ms".padRight(11)}'
        '${encode.toStringAsFixed(1)} ms'
        '   (~$weeks weeks of training)',
      );
    }
  });

  test('where the bytes are, at two years of training', () {
    fillTrainHistory(sessions: 400);
    final captured = AppSnapshot.capture();
    final total = jsonEncode(captured).length;
    print(
      '=== R6-01 section sizes at 400 sessions (total '
      '${(total / 1024).round()} KB) ===',
    );
    final rows = <MapEntry<String, int>>[
      for (final entry in captured.entries)
        MapEntry(entry.key, jsonEncode(entry.value).length),
    ]..sort((a, b) => b.value.compareTo(a.value));
    for (final row in rows) {
      print(
        '  ${row.key.padRight(10)}${"${(row.value / 1024).round()} KB".padLeft(8)}'
        '  ${(100 * row.value / total).toStringAsFixed(1)}%',
      );
    }

    final train = Map<String, Object?>.from(captured['train']! as Map);
    for (final key in <String>['sessions', 'flushes', 'swaps', 'counter']) {
      final bytes = jsonEncode(train[key]).length;
      print(
        '  train.${key.padRight(10)}${"${(bytes / 1024).round()} KB".padLeft(8)}',
      );
    }
    print('  per session: ${(total / 400 / 1024).toStringAsFixed(2)} KB');
  });
}
