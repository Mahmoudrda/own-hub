/// The Firestore half of the community foods, shaped like the exercise
/// library's (`exercise_library_sync.dart`).
///
///   * At most once a day, read `meta/communityFoodsVersion` (`{version: N}`),
///     one small document. While the phone holds no list yet it asks again
///     after an hour.
///   * Only when `N` is newer than what the phone holds, read
///     `meta/communityFoods` and parse it. Its version must be `N`.
///   * A good list is cached under its own preference key.
///   * Offline, on any error, or with Firebase unavailable: the last cached
///     list, or none.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../app_state/local_persistence.dart';
import '../domain/community_foods.dart';

const String kCommunityFoodsCacheKey = 'own_hub.community_foods';
const String kCommunityFoodsCheckKey = 'own_hub.community_foods_checked_at';

/// Every key the community foods keep on the phone. The local erase removes
/// each of them.
const List<String> kCommunityFoodsCacheKeys = <String>[
  kCommunityFoodsCacheKey,
  kCommunityFoodsCheckKey,
];

abstract class CommunityFoodsRemoteSource {
  /// `meta/communityFoodsVersion.version`, or null when missing.
  Future<int?> readVersion();

  /// `meta/communityFoods`, or null when missing.
  Future<Map<String, Object?>?> readFoods();
}

class FirestoreCommunityFoodsSource implements CommunityFoodsRemoteSource {
  FirestoreCommunityFoodsSource(this._db);

  final FirebaseFirestore _db;

  static const GetOptions _server = GetOptions(source: Source.server);
  static const Duration readTimeout = Duration(seconds: 10);

  @override
  Future<int?> readVersion() async {
    final doc = await _db
        .doc('meta/communityFoodsVersion')
        .get(_server)
        .timeout(readTimeout);
    final version = doc.data()?['version'];
    return version is int ? version : null;
  }

  @override
  Future<Map<String, Object?>?> readFoods() async =>
      (await _db.doc('meta/communityFoods').get(_server).timeout(readTimeout))
          .data();
}

enum CommunityFoodsRefreshOutcome {
  notDue,
  unavailable,
  upToDate,
  updated,
  rejected,
  failed,
}

class CommunityFoodsSync {
  CommunityFoodsSync({
    required this.source,
    SnapshotStorage? cache,
    SnapshotStorage? checks,
    DateTime Function()? now,
  }) : cache =
           cache ??
           const PreferencesSnapshotStorage(key: kCommunityFoodsCacheKey),
       checks =
           checks ??
           const PreferencesSnapshotStorage(key: kCommunityFoodsCheckKey),
       _now = now ?? DateTime.now;

  /// Null when no read could succeed right now.
  final CommunityFoodsRemoteSource? Function() source;
  final SnapshotStorage cache;
  final SnapshotStorage checks;
  final DateTime Function() _now;

  static const Duration checkEvery = Duration(hours: 24);
  static const Duration checkEveryWhileEmpty = Duration(hours: 1);
  static const Duration retryAfterFailure = Duration(hours: 1);

  DateTime? _notBefore;
  Future<(CommunityFoodsRefreshOutcome, CommunityFoods?)>? _inFlight;

  /// The cached list, or [CommunityFoods.empty]. Never throws.
  Future<CommunityFoods> load() async {
    try {
      final raw = await cache.read();
      if (raw == null) return CommunityFoods.empty;
      return CommunityFoods.parse(jsonDecode(raw)) ?? CommunityFoods.empty;
    } catch (_) {
      return CommunityFoods.empty;
    }
  }

  /// Checks the server when it is due. The new list only when it is
  /// [CommunityFoodsRefreshOutcome.updated]. Never throws.
  Future<(CommunityFoodsRefreshOutcome, CommunityFoods?)> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<(CommunityFoodsRefreshOutcome, CommunityFoods?)> _refresh() async {
    final now = _now();
    final notBefore = _notBefore;
    if (notBefore != null && now.isBefore(notBefore)) {
      return (CommunityFoodsRefreshOutcome.notDue, null);
    }
    final remote = source();
    if (remote == null) {
      return (CommunityFoodsRefreshOutcome.unavailable, null);
    }
    final current = await load();
    final every = current.isEmpty ? checkEveryWhileEmpty : checkEvery;
    try {
      final last = DateTime.tryParse(await checks.read() ?? '');
      if (last != null && now.difference(last) < every) {
        _notBefore = last.add(every);
        return (CommunityFoodsRefreshOutcome.notDue, null);
      }
    } catch (_) {
      // Unreadable: treated as never checked.
    }
    try {
      final version = await remote.readVersion();
      if (version == null || version <= current.version) {
        await _stampChecked(now, every);
        return (CommunityFoodsRefreshOutcome.upToDate, null);
      }
      final raw = await remote.readFoods();
      final foods = raw == null ? null : CommunityFoods.parse(_plain(raw));
      if (foods == null || foods.version != version) {
        if (kDebugMode) debugPrint('Community foods refused (v$version)');
        _notBefore = now.add(retryAfterFailure);
        return (CommunityFoodsRefreshOutcome.rejected, null);
      }
      await cache.write(jsonEncode(foods.toJson()));
      await _stampChecked(now, every);
      return (CommunityFoodsRefreshOutcome.updated, foods);
    } catch (error) {
      _notBefore = now.add(retryAfterFailure);
      if (kDebugMode) debugPrint('Community foods check failed: $error');
      return (CommunityFoodsRefreshOutcome.failed, null);
    }
  }

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
