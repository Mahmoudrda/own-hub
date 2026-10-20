// D42's data layer: the catalogue read from meta/ when due and kept in the
// cache, and each clip downloaded once, whole, into the phone's cache folder.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/features/train/data/exercise_library_sync.dart';
import 'package:own_hub/features/train/data/exercise_media_store.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';

import '../../helpers/exercise_library_fixture.dart';

class _Memory implements SnapshotStorage {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String snapshot) async => value = snapshot;

  @override
  Future<void> erase() async => value = null;
}

class _Source implements ExerciseLibraryRemoteSource {
  int? version;
  Map<String, Object?>? library;
  Object? offline;

  /// Thrown from the library read only, after the version read succeeded.
  Object? libraryFails;
  int versionReads = 0;

  @override
  Future<int?> readVersion() async {
    versionReads++;
    if (offline != null) throw offline!;
    return version;
  }

  @override
  Future<Map<String, Object?>?> readLibrary() async {
    if (libraryFails != null) throw libraryFails!;
    return library;
  }
}

void main() {
  group('the catalogue', () {
    _Source remote() => _Source()
      ..version = 3
      ..library = sampleExerciseLibrary().toJson();

    test('nothing reachable: no library, and nothing thrown', () async {
      final sync = ExerciseLibrarySync(
        source: () => null,
        cache: _Memory(),
        checks: _Memory(),
      );
      expect(
        (await sync.refresh()).$1,
        ExerciseLibraryRefreshOutcome.unavailable,
      );
      expect((await sync.load()).isEmpty, isTrue);
    });

    test('a newer version is fetched, cached and read back offline', () async {
      final cache = _Memory();
      final source = remote();
      final sync = ExerciseLibrarySync(
        source: () => source,
        cache: cache,
        checks: _Memory(),
      );
      final (outcome, library) = await sync.refresh();
      expect(outcome, ExerciseLibraryRefreshOutcome.updated);
      expect(library!.exercises, hasLength(6));
      final offline = ExerciseLibrarySync(
        source: () => null,
        cache: cache,
        checks: _Memory(),
      );
      expect((await offline.load()).version, 3);
    });

    test(
      'with a library on the phone, the version is read once a day',
      () async {
        final source = remote();
        final cache = _Memory()
          ..value = jsonEncode(sampleExerciseLibrary().toJson());
        final checks = _Memory();
        var now = DateTime.utc(2026, 10, 14, 9);
        ExerciseLibrarySync make() => ExerciseLibrarySync(
          source: () => source,
          cache: cache,
          checks: checks,
          now: () => now,
        );
        await make().refresh();
        now = now.add(const Duration(hours: 3));
        expect(
          (await make().refresh()).$1,
          ExerciseLibraryRefreshOutcome.notDue,
        );
        expect(source.versionReads, 1);
      },
    );

    test('a download that fails leaves no "checked" stamp, so the next launch '
        'asks again; a cached library stamps it', () async {
      final source = remote()..libraryFails = const SocketException('cut');
      final checks = _Memory();
      final cache = _Memory();
      final now = DateTime.utc(2026, 10, 14, 9);
      ExerciseLibrarySync make() => ExerciseLibrarySync(
        source: () => source,
        cache: cache,
        checks: checks,
        now: () => now,
      );
      expect((await make().refresh()).$1, ExerciseLibraryRefreshOutcome.failed);
      expect(checks.value, isNull);
      expect(cache.value, isNull);

      source.libraryFails = null;
      expect(
        (await make().refresh()).$1,
        ExerciseLibraryRefreshOutcome.updated,
      );
      expect(checks.value, isNotNull);
      expect(source.versionReads, 2);
    });

    test('a server read gives up after ten seconds', () {
      expect(
        FirestoreExerciseLibrarySource.readTimeout,
        const Duration(seconds: 10),
      );
    });

    test(
      'with nothing on the phone yet, it asks again after an hour',
      () async {
        final source = _Source()..version = null;
        final checks = _Memory();
        var now = DateTime.utc(2026, 10, 14, 9);
        ExerciseLibrarySync make() => ExerciseLibrarySync(
          source: () => source,
          cache: _Memory(),
          checks: checks,
          now: () => now,
        );
        expect(
          (await make().refresh()).$1,
          ExerciseLibraryRefreshOutcome.upToDate,
        );
        now = now.add(const Duration(minutes: 30));
        expect(
          (await make().refresh()).$1,
          ExerciseLibraryRefreshOutcome.notDue,
        );
        now = now.add(const Duration(minutes: 40));
        source.version = 3;
        source.library = sampleExerciseLibrary().toJson();
        expect(
          (await make().refresh()).$1,
          ExerciseLibraryRefreshOutcome.updated,
        );
      },
    );

    test(
      'a library whose version disagrees is refused, and the cache stands',
      () async {
        final cache = _Memory()
          ..value = jsonEncode(sampleExerciseLibrary().toJson());
        final source = remote()
          ..version = 5
          ..library = {...sampleExerciseLibrary().toJson(), 'version': 4};
        final sync = ExerciseLibrarySync(
          source: () => source,
          cache: cache,
          checks: _Memory(),
        );
        expect(
          (await sync.refresh()).$1,
          ExerciseLibraryRefreshOutcome.rejected,
        );
        expect((await sync.load()).version, 3);
      },
    );

    test('offline: failed, and nothing thrown', () async {
      final source = remote()..offline = Exception('no signal');
      final sync = ExerciseLibrarySync(
        source: () => source,
        cache: _Memory(),
        checks: _Memory(),
      );
      expect((await sync.refresh()).$1, ExerciseLibraryRefreshOutcome.failed);
    });

    test('its keys are wiped with the rest of the phone', () {
      expect(kExerciseLibraryCacheKeys, [
        kExerciseLibraryCacheKey,
        kExerciseLibraryCheckKey,
      ]);
    });
  });

  group('the clips on the phone', () {
    late Directory folder;
    setUp(() => folder = Directory.systemTemp.createTempSync('ownhub_clips_'));
    tearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });

    const clip = ExerciseMedia(
      path: 'content/exercises/glute_bridge/glute_bridge_front_aaaa1111.mp4',
      bytes: 8,
    );

    test(
      'a whole download is kept under its own name and served after',
      () async {
        var downloads = 0;
        final store = FirebaseExerciseMediaStore(
          folder: () async => folder,
          download: (path, into) async {
            downloads++;
            await into.writeAsBytes(List.filled(8, 1));
          },
        );
        final file = await store.fetch(clip);
        expect(
          file!.path,
          endsWith('glute_bridge__glute_bridge_front_aaaa1111.mp4'),
        );
        expect(await store.local(clip), isNotNull);
        await store.fetch(clip);
        expect(downloads, 1, reason: 'served from the phone the second time');
        expect(
          folder.listSync().where((f) => f.path.endsWith('.part')),
          isEmpty,
        );
      },
    );

    test('a short download is thrown away, never played', () async {
      final store = FirebaseExerciseMediaStore(
        folder: () async => folder,
        download: (path, into) async => into.writeAsBytes(List.filled(3, 1)),
      );
      expect(await store.fetch(clip), isNull);
      expect(folder.listSync(), isEmpty);
    });

    test(
      'a file of the wrong size on the phone is deleted, not trusted',
      () async {
        File('${folder.path}/glute_bridge__glute_bridge_front_aaaa1111.mp4')
            .writeAsBytesSync([1, 2]);
        final store = FirebaseExerciseMediaStore(
          folder: () async => folder,
          download: (_, _) async {},
        );
        expect(await store.local(clip), isNull);
        expect(folder.listSync(), isEmpty);
      },
    );

    test('two asks for one clip start one download', () async {
      var downloads = 0;
      final store = FirebaseExerciseMediaStore(
        folder: () async => folder,
        download: (path, into) async {
          downloads++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await into.writeAsBytes(List.filled(8, 1));
        },
      );
      final both = await Future.wait([store.fetch(clip), store.fetch(clip)]);
      expect(both.every((f) => f != null), isTrue);
      expect(downloads, 1);
    });

    test(
      'a download that never ends is given up on, and leaves nothing behind',
      () async {
        final store = FirebaseExerciseMediaStore(
          folder: () async => folder,
          timeout: const Duration(milliseconds: 50),
          download: (path, into) async {
            await into.writeAsBytes([1]);
            await Completer<void>().future;
          },
        );
        expect(await store.fetch(clip), isNull);
        expect(folder.listSync(), isEmpty);
      },
    );

    test('a clip is given time for its bytes, not a flat ninety seconds', () {
      final store = FirebaseExerciseMediaStore(folder: () async => folder);
      const small = ExerciseMedia(
        path: 'content/exercises/a/a.mp4',
        bytes: 50000,
      );
      const big = ExerciseMedia(
        path: 'content/exercises/a/b.mp4',
        bytes: 6000000,
      );
      // 50 KB/s: a second per 50 KB.
      expect(store.timeoutFor(small), const Duration(seconds: 91));
      expect(store.timeoutFor(big), const Duration(seconds: 90 + 120));
    });

    test(
      'progress is offered while a download runs and cleared after',
      () async {
        final store = FirebaseExerciseMediaStore(
          folder: () async => folder,
          download: (path, into) async {
            await into.writeAsBytes(List.filled(8, 1));
          },
        );
        final progress = store.progressOf(clip);
        expect(progress.value, isNull);
        await store.fetch(clip);
        expect(progress.value, isNull);
      },
    );

    test(
      'a poster that fails or times out gives its slot to the next',
      () async {
        const posters = [
          ExerciseMedia(path: 'content/exercises/a/a_aaaa1111.webp', bytes: 4),
          ExerciseMedia(path: 'content/exercises/b/b_bbbb2222.webp', bytes: 4),
          // Big enough that its own limit (the timeout plus 20 microseconds
          // a byte, about two seconds here) is far past what a loaded machine
          // takes to write it, so only the poster that never answers can
          // time out.
          ExerciseMedia(
            path: 'content/exercises/c/c_cccc3333.webp',
            bytes: 100000,
          ),
        ];
        final store = FirebaseExerciseMediaStore(
          folder: () async => folder,
          concurrent: 1,
          timeout: const Duration(milliseconds: 400),
          download: (path, into) async {
            if (path.contains('/a/')) throw StateError('no signal');
            if (path.contains('/b/')) await Completer<void>().future;
            await into.writeAsBytes(
              List.filled(path.contains('/c/') ? 100000 : 4, 1),
            );
          },
        );
        final files = await Future.wait([
          for (final p in posters) store.fetch(p),
        ]);
        expect(files[0], isNull);
        expect(files[1], isNull);
        expect(
          files[2],
          isNotNull,
          reason: 'one slot, freed by the two before it',
        );
      },
    );

    test('a failed download is null, and nothing thrown', () async {
      final store = FirebaseExerciseMediaStore(
        folder: () async => folder,
        download: (_, _) async => throw StateError('connection lost'),
      );
      expect(await store.fetch(clip), isNull);
    });

    test(
      'with no backend and no sign-in, a fetch is null and nothing thrown',
      () async {
        final store = FirebaseExerciseMediaStore(folder: () async => folder);
        expect(await store.fetch(clip), isNull);
        expect(folder.listSync(), isEmpty);
      },
    );

    test('only files under content/exercises are ever asked for', () async {
      var downloads = 0;
      final store = FirebaseExerciseMediaStore(
        folder: () async => folder,
        download: (_, _) async => downloads++,
      );
      expect(
        await store.fetch(
          const ExerciseMedia(path: 'users/x/selfie.jpg', bytes: 8),
        ),
        isNull,
      );
      expect(
        await store.fetch(
          const ExerciseMedia(path: 'content/exercises/../../x', bytes: 8),
        ),
        isNull,
      );
      expect(downloads, 0);
    });

    test('a new library keeps what it names and drops the rest', () async {
      File('${folder.path}/glute_bridge__glute_bridge_front_aaaa1111.mp4')
          .writeAsBytesSync([1]);
      File('${folder.path}/old_move__old_front.mp4').writeAsBytesSync([1]);
      File('${folder.path}/x.mp4.part').writeAsBytesSync([1]);
      final store = FirebaseExerciseMediaStore(
        folder: () async => folder,
        download: (_, _) async {},
      );
      await store.keepOnly({clip.path});
      expect(
        [for (final f in folder.listSync()) f.uri.pathSegments.last],
        ['glute_bridge__glute_bridge_front_aaaa1111.mp4'],
      );
      await store.eraseAll();
      expect(folder.existsSync(), isFalse);
    });
  });
}
