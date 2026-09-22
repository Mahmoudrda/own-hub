/// `coaches/{coachUid}/media/*` — B13's library.
///
/// Paged at 30, never unbounded: a coach who has been posting for two years has
/// a library that a `get all` would scan. The cap is in the interface, so a
/// caller cannot ask for more.
///
/// The fake refuses an unblurred item at the door, exactly as the security rule
/// does (`request.resource.data.blurApplied == true`), and refuses to delete an
/// item a block still points at.
library;

import 'dart:async';

import 'coach_media.dart';

/// B13 reads 30 at a time.
const int kMediaPageSize = 30;

class MediaWriteRejected implements Exception {
  MediaWriteRejected(this.reason);
  final String reason;

  @override
  String toString() => 'MediaWriteRejected: $reason';
}

abstract class CoachMediaRepository {
  /// Newest first, at most [limit] (capped at [kMediaPageSize]).
  Future<List<CoachMediaItem>> page({int limit, DateTime? before});

  Stream<List<CoachMediaItem>> watch({int limit});

  Future<CoachMediaItem?> byId(String mediaId);

  /// Adds a blurred item. Throws [BlurNotAppliedError] otherwise.
  Future<CoachMediaItem> add(CoachMediaItem item);

  /// Refuses while any block still references it.
  Future<void> delete(String mediaId);

  /// Reference counting, which is what makes a withdrawal purge bounded.
  Future<void> markUsedBy(String mediaId, String blockId);
  Future<void> releaseFrom(String mediaId, String blockId);
}

class MediaStore {
  MediaStore({Map<String, CoachMediaItem>? items}) : items = {...?items};
  final Map<String, CoachMediaItem> items;
}

class InMemoryCoachMediaRepository implements CoachMediaRepository {
  InMemoryCoachMediaRepository({MediaStore? store})
    : store = store ?? MediaStore();

  final MediaStore store;
  final StreamController<List<CoachMediaItem>> _changes =
      StreamController<List<CoachMediaItem>>.broadcast();

  List<CoachMediaItem> _newestFirst({
    int limit = kMediaPageSize,
    DateTime? before,
  }) {
    final all = store.items.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final filtered = before == null
        ? all
        : all.where((i) => i.createdAt.isBefore(before)).toList();
    final capped = limit.clamp(1, kMediaPageSize);
    return List.unmodifiable(filtered.take(capped));
  }

  @override
  Future<List<CoachMediaItem>> page({
    int limit = kMediaPageSize,
    DateTime? before,
  }) async {
    if (limit > kMediaPageSize) {
      throw MediaWriteRejected(
        'The library is read $kMediaPageSize at a time; asked for $limit.',
      );
    }
    return _newestFirst(limit: limit, before: before);
  }

  @override
  Stream<List<CoachMediaItem>> watch({int limit = kMediaPageSize}) async* {
    yield _newestFirst(limit: limit);
    yield* _changes.stream;
  }

  @override
  Future<CoachMediaItem?> byId(String mediaId) async => store.items[mediaId];

  @override
  Future<CoachMediaItem> add(CoachMediaItem item) async {
    // C11 at the door, as the rule has it.
    if (!item.blurApplied) throw BlurNotAppliedError(item.mediaId);
    if (item.kind != CoachMediaKind.photo &&
        item.kind != CoachMediaKind.video) {
      throw MediaWriteRejected('kind must be photo or video.');
    }
    store.items[item.mediaId] = item;
    _emit();
    return item;
  }

  @override
  Future<void> delete(String mediaId) async {
    final item = store.items[mediaId];
    if (item == null) return;
    CoachMediaPolicy.assertDeletable(item);
    store.items.remove(mediaId);
    _emit();
  }

  @override
  Future<void> markUsedBy(String mediaId, String blockId) async {
    final item = store.items[mediaId];
    if (item == null) return;
    store.items[mediaId] = item.usedByBlock(blockId);
    _emit();
  }

  @override
  Future<void> releaseFrom(String mediaId, String blockId) async {
    final item = store.items[mediaId];
    if (item == null) return;
    store.items[mediaId] = item.releasedByBlock(blockId);
    _emit();
  }

  /// The upload gateway acknowledging. Not on the interface — G8 owns uploads.
  CoachMediaItem gatewayMoved(String mediaId, CoachMediaState next) {
    final item = store.items[mediaId];
    if (item == null) throw MediaWriteRejected('No media $mediaId.');
    final moved = item.inState(next);
    store.items[mediaId] = moved;
    _emit();
    return moved;
  }

  /// A consent withdrawal deleting the client's files.
  ///
  /// Bounded by *the coach's own* content, never by how many women have seen
  /// it: this touches only items whose `clientResultId` matches.
  List<String> functionPurgedForResult(String resultId) {
    final purged = <String>[];
    for (final entry in store.items.entries.toList()) {
      if (entry.value.clientResultId != resultId) continue;
      store.items[entry.key] = entry.value
          .inState(CoachMediaState.purged)
          .releasedByBlock('');
      purged.add(entry.key);
    }
    if (purged.isNotEmpty) _emit();
    return List.unmodifiable(purged);
  }

  void _emit() => _changes.add(_newestFirst());

  Future<void> dispose() => _changes.close();
}
