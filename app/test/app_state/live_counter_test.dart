// A new phone takes in her sessions from the cloud; the next live session must
// not reuse one of their ids and overwrite it.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

TrainSession _s(String id) => TrainSession(
  id: id,
  source: SessionSource.live,
  dateKey: '2026-10-17',
  sets: const [],
  completed: true,
);

void main() {
  test('the counter moves past every live id taken in from the cloud', () {
    expect(liveCounterAbove([_s('live-3'), _s('live-12'), _s('recall-9')], 0), 12);
  });

  test('a counter already ahead stays where it is', () {
    expect(liveCounterAbove([_s('live-2')], 7), 7);
  });

  test('no live ids keeps the counter', () {
    expect(liveCounterAbove([_s('recall-4')], 0), 0);
  });
}
