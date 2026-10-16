// WP3: a change that leaves the document as it was writes nothing. A redraw
// bump used to rewrite megabytes of history on a phone that is already slow.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/routing/app_router.dart';

import '../qa/round6/history_fixture.dart';

class _CountingStorage implements SnapshotStorage {
  String? document;
  int writes = 0;
  int erases = 0;

  @override
  Future<String?> read() async => document;

  @override
  Future<void> write(String snapshot) async {
    writes++;
    document = snapshot;
  }

  @override
  Future<void> erase() async {
    erases++;
    document = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingStorage storage;
  final persistence = LocalPersistence.instance;

  setUp(() {
    persistence.reset();
    storage = _CountingStorage();
    persistence.storage = storage;
    persistence.start();
  });

  tearDown(() {
    persistence.reset();
    AppRouter.trainRepository.reset();
  });

  test(
    'an unchanged document is written once, however often it is asked',
    () async {
      await persistence.flush();
      await persistence.flush();
      await persistence.flush();
      expect(storage.writes, 1);
    },
  );

  test('two flushes in one turn write once (paused, then detached)', () async {
    final first = persistence.flush();
    final second = persistence.flush();
    await Future.wait([first, second]);
    expect(storage.writes, 1);
  });

  test('a real change is written', () async {
    await persistence.flush();
    fillTrainHistory(sessions: 2);
    await persistence.flush();
    expect(storage.writes, 2);
    await persistence.flush();
    expect(storage.writes, 2);
  });

  test('after a deletion the same document is written again', () async {
    await persistence.flush();
    await persistence.erase();
    await persistence.flush();
    expect(storage.writes, 2);
    expect(storage.document, isNotNull);
  });
}
