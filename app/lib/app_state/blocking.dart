/// Blocking, joined to the one list that makes a block visible.
///
/// ## The defect this file exists for
///
/// [FollowGraph.hiddenAuthors] is what the feed, Explore, the stories rail,
/// Activity and every write guard in [InMemoryCommunityRepository] consult
/// before they show or send anything. It was read in all of those places and
/// **written in none of them**: [InMemoryBlockService] recorded the block,
/// `M08` closed with the sheet saying it had worked, and the blocked woman's
/// posts carried on appearing. A block that changes nothing she can see is the
/// worst kind of safety control, because she stops looking for another way out.
///
/// On a real backend `hiddenAuthors` is Function-maintained: `onBlockWrite`
/// recomputes it in both directions from `users/{uid}/blocks` and
/// `users/{uid}/blockedBy`. This build has no Functions, so this file does that
/// one job, the same way `CommunityState` does the counter Function's job and
/// for the same reason. It is a decorator over the existing [BlockService]
/// rather than a second place to block from: every caller of
/// `AppRouter.blockService` gets the hiding, so a new screen cannot wire the
/// record without the effect.
///
/// ## One direction only, honestly
///
/// The Function maintains `hiddenAuthors` in **both** directions: a woman she
/// blocked, and a woman who blocked her. Only the first half can exist here,
/// because nobody else is running this build to block her back. Nothing
/// pretends otherwise.
library;

import 'dart:async';

import '../features/account/domain/safety.dart';
import '../features/community/domain/community_models.dart';
import '../features/community/domain/community_repository.dart';
import 'app_changes.dart';

class BlockingService implements BlockService {
  /// [_blocks] is positional because Dart forbids a named parameter that
  /// begins with an underscore, and the field stays private on purpose: a
  /// caller that reached past this class to the record would write a block
  /// that hides nobody, which is the defect this file exists for.
  BlockingService(this._blocks, {required this.store});

  /// The record. Deterministic ids, offline-capable, capped at fifty.
  final BlockService _blocks;

  /// The store whose graph the feed reads. Not a copy of it.
  final CommunityStore store;

  @override
  List<Block> blocks() => _blocks.blocks();

  @override
  bool isBlocked(String uid) => _blocks.isBlocked(uid);

  @override
  Future<void> block(String uid, BlockSource source) async {
    // The record first. It refuses a woman blocking herself, and that refusal
    // has to travel before anything is hidden.
    await _blocks.block(uid, source);
    _setHidden(uid, true);
    AppChanges.bump();
  }

  @override
  Future<void> unblock(String uid) async {
    await _blocks.unblock(uid);
    _setHidden(uid, false);
    AppChanges.bump();
  }

  /// Adds or removes [uid] from the graph's exclusion list.
  ///
  /// The graph is rewritten whole because [FollowGraph] is immutable and has no
  /// `copyWith`, which is exactly how the repository rewrites it on a follow or
  /// a join.
  void _setHidden(String uid, bool hidden) {
    if (uid.isEmpty) return;
    final graph = store.graph;
    if (graph.hiddenAuthors.contains(uid) == hidden) return;
    if (hidden && graph.hiddenAuthors.length >= kMaxHiddenAuthors) return;
    store.graph = FollowGraph(
      followingKeys: graph.followingKeys,
      groupKeys: graph.groupKeys,
      hiddenAuthors: hidden
          ? <String>[...graph.hiddenAuthors, uid]
          : graph.hiddenAuthors.where((a) => a != uid).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// For tests. Empties the record and the exclusion list together, so one
  /// journey cannot leave a woman hidden from the next.
  void reset() {
    for (final block in _blocks.blocks()) {
      _setHidden(block.blockedUid, false);
      // In-memory, so the removal has already happened by the time this
      // returns. Nothing is waiting on it.
      unawaited(_blocks.unblock(block.blockedUid));
    }
  }
}
