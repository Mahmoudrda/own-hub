/// The exercise library's clips and posters on the phone (D42).
///
/// Each file is downloaded once, the first time she opens the move or its row
/// comes into view, and kept in the app's cache folder: after that it plays
/// with no signal and costs nothing to show again. The cache folder rather
/// than application support, because these are the library's files, not
/// hers: iCloud does not back them up, and if the system clears the folder
/// they are simply fetched again.
///
/// A file is trusted only at the exact size the catalogue gives. It is written
/// beside its final name as `.part` and renamed only once it is whole, so a
/// download cut off by a tunnel never plays as a broken clip.
///
/// Read through `firebase_storage` with her own sign-in (the content rules let
/// any signed-in account read `content/`), never through a download URL: a URL
/// is a second thing to fetch, and a key that outlives the question it
/// answered.
library;

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/exercise_library.dart';

/// Writes the stored object at [path] into [into]. Throws on any failure.
typedef ExerciseMediaDownloader = Future<void> Function(String path, File into);

abstract class ExerciseMediaStore {
  /// The file on the phone, whole, or null. No network. Never throws.
  Future<File?> local(ExerciseMedia media);

  /// [local], or a download of it. Null when it cannot be had now. Never
  /// throws.
  Future<File?> fetch(ExerciseMedia media);

  /// How far the download of [media] has got, 0 to 1, or null while none is
  /// running (or when the size is not known yet). Never throws.
  ValueListenable<double?> progressOf(ExerciseMedia media);

  /// Deletes every file the library no longer names, and any half download.
  Future<void> keepOnly(Set<String> paths);

  /// Deletes them all. Account deletion.
  Future<void> eraseAll();
}

/// Nothing on the phone, and nothing fetched: tests, and a build with no
/// backend.
class NoExerciseMedia implements ExerciseMediaStore {
  const NoExerciseMedia();

  @override
  Future<File?> local(ExerciseMedia media) async => null;

  @override
  Future<File?> fetch(ExerciseMedia media) async => null;

  @override
  ValueListenable<double?> progressOf(ExerciseMedia media) =>
      ValueNotifier<double?>(null);

  @override
  Future<void> keepOnly(Set<String> paths) async {}

  @override
  Future<void> eraseAll() async {}
}

class FirebaseExerciseMediaStore implements ExerciseMediaStore {
  FirebaseExerciseMediaStore({
    Future<Directory?> Function()? folder,
    this.download,
    this.timeout = const Duration(seconds: 90),
    this.concurrent = 3,
  }) : _folder = folder ?? _cacheFolder;

  final Future<Directory?> Function() _folder;

  /// Replaces the Firebase Storage transfer. Tests.
  final ExerciseMediaDownloader? download;

  /// What every download is given before the size of the file is counted.
  final Duration timeout;

  /// What a clip may take: [timeout] plus the time its bytes need at
  /// 50 KB/s, the slowest connection the app still treats as a connection.
  /// A flat 90 seconds gave up on a 6 MB clip that was arriving, every time,
  /// and spent the data it had already used.
  Duration timeoutFor(ExerciseMedia media) =>
      timeout + Duration(microseconds: media.bytes * 20);

  final Map<String, ValueNotifier<double?>> _progress =
      <String, ValueNotifier<double?>>{};

  @override
  ValueListenable<double?> progressOf(ExerciseMedia media) =>
      _progress.putIfAbsent(media.path, () => ValueNotifier<double?>(null));

  /// Poster downloads at once. A list of posters coming into view does not
  /// start eighty requests on a weak connection. Clips never wait for them:
  /// a clip is what she just tapped.
  final int concurrent;

  final Map<String, Future<File?>> _inFlight = <String, Future<File?>>{};
  int _running = 0;
  final List<Completer<void>> _waiting = <Completer<void>>[];

  static Future<Directory?> _cacheFolder() async {
    try {
      final base = await getApplicationCacheDirectory();
      return await Directory('${base.path}/exercise_clips')
          .create(recursive: true);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _fromStorage(
    String path,
    File into,
    Duration timeout,
    ValueNotifier<double?> progress,
  ) async {
    if (!FirebaseBoot.isReady || FirebaseAuth.instance.currentUser == null) {
      throw StateError('not signed in');
    }
    final task = FirebaseBoot.library.ref(path).writeToFile(into);
    final watching = task.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      if (total > 0) progress.value = snapshot.bytesTransferred / total;
    }, onError: (Object _) {});
    try {
      await task.timeout(timeout);
    } on TimeoutException {
      // Stopped, not abandoned: a transfer left running would go on spending
      // her data for a file this phone has already given up on.
      await task.cancel();
      rethrow;
    } finally {
      unawaited(watching.cancel());
    }
  }

  /// `content/exercises/glute_bridge/a.mp4` is kept as `glute_bridge__a.mp4`.
  static String localName(String path) {
    const prefix = '$kExerciseMediaPrefix/';
    final rest = path.startsWith(prefix) ? path.substring(prefix.length) : path;
    return rest.replaceAll('/', '__');
  }

  static bool _safe(String path) =>
      path.startsWith('$kExerciseMediaPrefix/') && !path.contains('..');

  @override
  Future<File?> local(ExerciseMedia media) async {
    if (!_safe(media.path)) return null;
    try {
      final dir = await _folder();
      if (dir == null) return null;
      final file = File('${dir.path}/${localName(media.path)}');
      if (!await file.exists()) return null;
      if (await file.length() == media.bytes) return file;
      await file.delete();
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<File?> fetch(ExerciseMedia media) {
    if (!_safe(media.path)) return Future.value();
    // A block, not an arrow: `remove` returns this same future, and a
    // `whenComplete` handed a future waits for it, so it would wait for itself.
    return _inFlight[media.path] ??= _fetch(media).whenComplete(() {
      _inFlight.remove(media.path);
    });
  }

  Future<File?> _fetch(ExerciseMedia media) async {
    final kept = await local(media);
    if (kept != null) return kept;
    final poster = media.path.endsWith('.webp');
    if (poster) await _slot();
    final progress = _progress.putIfAbsent(
      media.path,
      () => ValueNotifier<double?>(null),
    );
    try {
      final dir = await _folder();
      if (dir == null) return null;
      final name = localName(media.path);
      final part = File('${dir.path}/$name.part');
      try {
        final limit = timeoutFor(media);
        final custom = download;
        await (custom != null
                ? custom(media.path, part)
                : _fromStorage(media.path, part, limit, progress))
            .timeout(limit);
        if (!await part.exists() || await part.length() != media.bytes) {
          if (await part.exists()) await part.delete();
          return null;
        }
        return await part.rename('${dir.path}/$name');
      } catch (_) {
        try {
          if (await part.exists()) await part.delete();
        } catch (_) {}
        return null;
      }
    } catch (_) {
      return null;
    } finally {
      progress.value = null;
      if (poster) _release();
    }
  }

  Future<void> _slot() async {
    if (_running < concurrent) {
      _running++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeAt(0).complete();
    } else {
      _running--;
    }
  }

  @override
  Future<void> keepOnly(Set<String> paths) async {
    try {
      final dir = await _folder();
      if (dir == null) return;
      final keep = {for (final p in paths) localName(p)};
      final busy = {for (final p in _inFlight.keys) '${localName(p)}.part'};
      await for (final entry in dir.list()) {
        if (entry is! File) continue;
        final name = entry.uri.pathSegments.last;
        if (busy.contains(name)) continue;
        if (name.endsWith('.part') || !keep.contains(name)) {
          await entry.delete();
        }
      }
    } catch (_) {
      // A file left behind is fetched again or cleared with the cache.
    }
  }

  @override
  Future<void> eraseAll() async {
    try {
      final dir = await _folder();
      if (dir != null && await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {}
  }
}
