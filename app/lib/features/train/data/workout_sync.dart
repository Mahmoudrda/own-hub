/// The Firestore half of the workout library, shaped exactly like the recipe
/// library's (`eat/data/recipe_sync.dart`).
///
///   * At most once a day, and only for a verified account, read
///     `meta/workouts` (`{version: N}`), one small document.
///   * Only when `N` is newer than what the phone holds, read
///     `workoutLibrary/v{N}`, parse it and hold it to [workoutProblems]. One
///     problem refuses the whole set.
///   * A complete, valid set is cached under its own preference key and handed
///     over whole.
///   * Offline, on any error, or with Firebase unavailable: the last cached
///     set, or nothing. The bundled session (`sampleWorkoutDay`) is always
///     there beside it, so day one never depends on a network.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../app_state/local_persistence.dart';
import '../domain/workout_library.dart';

const String kWorkoutCacheKey = 'own_hub.workouts';
const String kWorkoutCheckKey = 'own_hub.workouts_checked_at';

/// Every key the workout library keeps on the phone. The local erase removes
/// each of them.
const List<String> kWorkoutCacheKeys = <String>[
  kWorkoutCacheKey,
  kWorkoutCheckKey,
];

abstract class WorkoutRemoteSource {
  /// `meta/workouts.version`, or null when the document is missing.
  Future<int?> readVersion();

  /// `workoutLibrary/v{version}`, or null when missing.
  Future<Map<String, Object?>?> readLibrary(int version);
}

class FirestoreWorkoutSource implements WorkoutRemoteSource {
  FirestoreWorkoutSource(this._db);

  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);

  /// A read that has not answered by now is a connection too poor to use. It
  /// throws, the check counts as failed and tries again in an hour.
  static const Duration readTimeout = Duration(seconds: 10);

  @override
  Future<int?> readVersion() async {
    final doc = await _db
        .doc('meta/workouts')
        .get(_server)
        .timeout(readTimeout);
    final version = doc.data()?['version'];
    return version is int ? version : null;
  }

  @override
  Future<Map<String, Object?>?> readLibrary(int version) async =>
      (await _db
              .doc('workoutLibrary/v$version')
              .get(_server)
              .timeout(readTimeout))
          .data();
}

enum WorkoutRefreshOutcome {
  notDue,
  unavailable,
  upToDate,
  updated,
  rejected,
  failed,
}

class WorkoutSync {
  WorkoutSync({
    required this.source,
    SnapshotStorage? cache,
    SnapshotStorage? checks,
    DateTime Function()? now,
  }) : cache = cache ?? const PreferencesSnapshotStorage(key: kWorkoutCacheKey),
       checks =
           checks ?? const PreferencesSnapshotStorage(key: kWorkoutCheckKey),
       _now = now ?? DateTime.now;

  /// Null when no read could succeed right now.
  final WorkoutRemoteSource? Function() source;
  final SnapshotStorage cache;
  final SnapshotStorage checks;
  final DateTime Function() _now;

  static const Duration checkEvery = Duration(hours: 24);
  static const Duration retryAfterFailure = Duration(hours: 1);

  DateTime? _notBefore;
  Future<(WorkoutRefreshOutcome, WorkoutLibrary?)>? _inFlight;

  /// The cached library, or [WorkoutLibrary.empty]. Never throws.
  Future<WorkoutLibrary> load() async {
    try {
      final raw = await cache.read();
      if (raw == null) return WorkoutLibrary.empty;
      return WorkoutLibrary.parse(
        (jsonDecode(raw) as Map).cast<String, Object?>(),
      );
    } catch (_) {
      return WorkoutLibrary.empty;
    }
  }

  /// Checks the server if a day has passed. The new library only when it is
  /// [WorkoutRefreshOutcome.updated]. Never throws.
  Future<(WorkoutRefreshOutcome, WorkoutLibrary?)> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<(WorkoutRefreshOutcome, WorkoutLibrary?)> _refresh() async {
    final now = _now();
    final notBefore = _notBefore;
    if (notBefore != null && now.isBefore(notBefore)) {
      return (WorkoutRefreshOutcome.notDue, null);
    }
    final remote = source();
    if (remote == null) return (WorkoutRefreshOutcome.unavailable, null);
    try {
      final last = DateTime.tryParse(await checks.read() ?? '');
      if (last != null && now.difference(last) < checkEvery) {
        _notBefore = last.add(checkEvery);
        return (WorkoutRefreshOutcome.notDue, null);
      }
    } catch (_) {
      // Unreadable: treated as never checked.
    }
    try {
      final version = await remote.readVersion();
      final current = await load();
      if (version == null || version <= current.version) {
        await _stampChecked(now);
        return (WorkoutRefreshOutcome.upToDate, null);
      }
      final raw = await remote.readLibrary(version);
      if (raw == null) {
        _notBefore = now.add(retryAfterFailure);
        return (WorkoutRefreshOutcome.rejected, null);
      }
      final WorkoutLibrary library;
      try {
        library = WorkoutLibrary.parse(_plain(raw));
        if (library.version != version) {
          throw const FormatException('version does not match');
        }
      } on FormatException catch (error) {
        if (kDebugMode) debugPrint('Workout library refused: $error');
        _notBefore = now.add(retryAfterFailure);
        return (WorkoutRefreshOutcome.rejected, null);
      }
      await cache.write(jsonEncode(library.toJson()));
      await _stampChecked(now);
      return (WorkoutRefreshOutcome.updated, library);
    } catch (error) {
      _notBefore = now.add(retryAfterFailure);
      if (kDebugMode) debugPrint('Workout library check failed: $error');
      return (WorkoutRefreshOutcome.failed, null);
    }
  }

  /// "Checked today" is written only once the answer is in hand: the library
  /// is cached, or the server said there is nothing newer. A read that timed
  /// out or a download cut short leaves no stamp, so the next launch asks
  /// again instead of waiting a day on a library she never received.
  Future<void> _stampChecked(DateTime now) async {
    _notBefore = now.add(checkEvery);
    try {
      await checks.write(now.toUtc().toIso8601String());
    } catch (_) {}
  }

  static Map<String, Object?> _plain(Map<String, Object?> data) =>
      (jsonDecode(jsonEncode(data, toEncodable: _encode)) as Map)
          .cast<String, Object?>();

  static Object? _encode(Object? value) =>
      value is Timestamp ? value.toDate().toUtc().toIso8601String() : '$value';
}
