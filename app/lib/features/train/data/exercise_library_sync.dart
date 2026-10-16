/// The Firestore half of the exercise library (D42), shaped like the workout
/// library's (`workout_sync.dart`).
///
///   * At most once a day, and only for a verified account, read
///     `meta/exercises` (`{version: N}`), one small document. While the phone
///     holds no library yet it asks again after an hour rather than a day, so a
///     library published this morning reaches her this morning.
///   * Only when `N` is newer than what the phone holds, read
///     `meta/exerciseLibrary` and parse it ([ExerciseLibrary.parse] drops a
///     bad row, not the library). Its version must be `N`.
///   * A good library is cached under its own preference key.
///   * Offline, on any error, or with Firebase unavailable: the last cached
///     library, or none. The clips themselves are fetched one at a time, when
///     she opens a move (`exercise_media_store.dart`).
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../app_state/local_persistence.dart';
import '../domain/exercise_library.dart';

const String kExerciseLibraryCacheKey = 'own_hub.exercise_library';
const String kExerciseLibraryCheckKey = 'own_hub.exercise_library_checked_at';

/// Every key the exercise library keeps on the phone. The local erase removes
/// each of them.
const List<String> kExerciseLibraryCacheKeys = <String>[
  kExerciseLibraryCacheKey,
  kExerciseLibraryCheckKey,
];

abstract class ExerciseLibraryRemoteSource {
  /// `meta/exercises.version`, or null when the document is missing.
  Future<int?> readVersion();

  /// `meta/exerciseLibrary`, or null when missing.
  Future<Map<String, Object?>?> readLibrary();
}

class FirestoreExerciseLibrarySource implements ExerciseLibraryRemoteSource {
  FirestoreExerciseLibrarySource(this._db);

  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);

  /// A read that has not answered by now is a connection too poor to use. It
  /// throws, the check counts as failed and tries again in an hour.
  static const Duration readTimeout = Duration(seconds: 10);

  @override
  Future<int?> readVersion() async {
    final doc = await _db
        .doc('meta/exercises')
        .get(_server)
        .timeout(readTimeout);
    final version = doc.data()?['version'];
    return version is int ? version : null;
  }

  @override
  Future<Map<String, Object?>?> readLibrary() async =>
      (await _db.doc('meta/exerciseLibrary').get(_server).timeout(readTimeout))
          .data();
}

enum ExerciseLibraryRefreshOutcome {
  notDue,
  unavailable,
  upToDate,
  updated,
  rejected,
  failed,
}

class ExerciseLibrarySync {
  ExerciseLibrarySync({
    required this.source,
    SnapshotStorage? cache,
    SnapshotStorage? checks,
    DateTime Function()? now,
  }) : cache =
           cache ??
           const PreferencesSnapshotStorage(key: kExerciseLibraryCacheKey),
       checks =
           checks ??
           const PreferencesSnapshotStorage(key: kExerciseLibraryCheckKey),
       _now = now ?? DateTime.now;

  /// Null when no read could succeed right now.
  final ExerciseLibraryRemoteSource? Function() source;
  final SnapshotStorage cache;
  final SnapshotStorage checks;
  final DateTime Function() _now;

  static const Duration checkEvery = Duration(hours: 24);
  static const Duration checkEveryWhileEmpty = Duration(hours: 1);
  static const Duration retryAfterFailure = Duration(hours: 1);

  DateTime? _notBefore;
  Future<(ExerciseLibraryRefreshOutcome, ExerciseLibrary?)>? _inFlight;

  /// The cached library, or [ExerciseLibrary.empty]. Never throws.
  Future<ExerciseLibrary> load() async {
    try {
      final raw = await cache.read();
      if (raw == null) return ExerciseLibrary.empty;
      return ExerciseLibrary.parse(jsonDecode(raw)) ?? ExerciseLibrary.empty;
    } catch (_) {
      return ExerciseLibrary.empty;
    }
  }

  /// Checks the server when it is due. The new library only when it is
  /// [ExerciseLibraryRefreshOutcome.updated]. Never throws.
  Future<(ExerciseLibraryRefreshOutcome, ExerciseLibrary?)> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<(ExerciseLibraryRefreshOutcome, ExerciseLibrary?)> _refresh() async {
    final now = _now();
    final notBefore = _notBefore;
    if (notBefore != null && now.isBefore(notBefore)) {
      return (ExerciseLibraryRefreshOutcome.notDue, null);
    }
    final remote = source();
    if (remote == null) {
      return (ExerciseLibraryRefreshOutcome.unavailable, null);
    }
    final current = await load();
    final every = current.isEmpty ? checkEveryWhileEmpty : checkEvery;
    try {
      final last = DateTime.tryParse(await checks.read() ?? '');
      if (last != null && now.difference(last) < every) {
        _notBefore = last.add(every);
        return (ExerciseLibraryRefreshOutcome.notDue, null);
      }
    } catch (_) {
      // Unreadable: treated as never checked.
    }
    try {
      final version = await remote.readVersion();
      if (version == null || version <= current.version) {
        await _stampChecked(now, every);
        return (ExerciseLibraryRefreshOutcome.upToDate, null);
      }
      final raw = await remote.readLibrary();
      final library = raw == null ? null : ExerciseLibrary.parse(_plain(raw));
      if (library == null || library.version != version) {
        if (kDebugMode) debugPrint('Exercise library refused (v$version)');
        _notBefore = now.add(retryAfterFailure);
        return (ExerciseLibraryRefreshOutcome.rejected, null);
      }
      await cache.write(jsonEncode(library.toJson()));
      await _stampChecked(now, every);
      return (ExerciseLibraryRefreshOutcome.updated, library);
    } catch (error) {
      _notBefore = now.add(retryAfterFailure);
      if (kDebugMode) debugPrint('Exercise library check failed: $error');
      return (ExerciseLibraryRefreshOutcome.failed, null);
    }
  }

  /// "Checked" is written only once the answer is in hand: the library is
  /// cached, or the server said there is nothing newer. A read that timed out
  /// or a download cut short leaves no stamp, so the next launch asks again.
  Future<void> _stampChecked(DateTime now, Duration every) async {
    _notBefore = now.add(every);
    try {
      await checks.write(now.toUtc().toIso8601String());
    } catch (_) {}
  }

  static Object? _plain(Map<String, Object?> data) =>
      jsonDecode(jsonEncode(data, toEncodable: _encode));

  static Object? _encode(Object? value) =>
      value is Timestamp ? value.toDate().toUtc().toIso8601String() : '$value';
}
