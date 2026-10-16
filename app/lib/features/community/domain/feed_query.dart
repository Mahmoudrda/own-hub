/// Every query this feature issues, and the single ordering all of them use.
///
/// `G10-community.md` §5, rule 11: *"every factory takes an `Ordering` enum with
/// exactly one value, `newestFirst`."* That is [FeedOrdering] below, and it is
/// the Dart half of "nothing is ranked". The storage half is the single-field
/// index exemptions in `firestore.indexes.json` — `publicProfiles.followerCount`,
/// `posts.counts`, `posts.cost`, `groups.memberCount` — because Firestore
/// auto-indexes every field and the absence of a *composite* index is not
/// sufficient. Both halves are required. `P1-COM-01` is the deployment check.
///
/// ## The feed query the whole plan stands on
///
/// ```
/// posts
///   .where('audienceKeys', arrayContainsAny: chunk)   // <= 30 values
///   .where('visibility', isEqualTo: 'live')
///   .orderBy('createdAt', descending: true)
///   .startAfter([cursor]).limit(10)
/// ```
///
/// Ten reads per chunk per page — p50 one chunk, p95 two, hard cap ten. Merged
/// k-way on the client and trimmed. The writes a post causes: **exactly one**,
/// for zero followers or a hundred thousand.
///
/// ## Why not `in` on `authorUid`
///
/// Identical cost, but it cannot express "the groups she joined" in the same
/// query — so the feed would be two queries and two merge cursors.
/// `audienceKeys` puts a group and an author in one key space.
///
/// ## No snapshot listeners
///
/// `G10` §2.4 names this a requirement, not a preference: *"a live listener on a
/// feed re-reads on every write by anyone she follows — the standard way this
/// bill goes to $500."* Every factory here describes a **one-shot page**. There
/// is no `watch`, no `stream` and no `Stream<...>` return type anywhere in this
/// file or in the repository interface, and a test asserts that.
library;

import 'package:meta/meta.dart';

import 'audience_keys.dart';
import 'community_models.dart';

/// The only ordering this product has.
///
/// One value, deliberately. A second value is the change a reviewer would have
/// to approve, and there is no legitimate second value: not likes, not
/// followers, not "relevance", not engagement. `P1-COM-01` asserts
/// `FeedOrdering.values.length == 1`.
enum FeedOrdering { newestFirst }

/// A page cap. Ten posts, ten reads.
const int kFeedPageSize = 10;

/// The hard cap on chunks per page, so one woman's feed cannot issue an
/// unbounded number of queries however many women she follows.
const int kMaxFeedChunks = 10;

/// One issued query. A description, not an execution — the repository runs it.
///
/// Modelled as a value so a test can assert the *shape* of what the feed would
/// send without a Firestore instance: how many chunks, what filters, which
/// ordering, and that the limit is always present.
@immutable
class FeedQuery {
  const FeedQuery({
    required this.audienceKeys,
    this.visibility = PostVisibility.live,
    this.ordering = FeedOrdering.newestFirst,
    this.limit = kFeedPageSize,
    this.startAfter,
    this.kind,
    this.groupId,
    this.authorUid,
    this.parentPostId,
    this.topic,
    this.expiringAfter,
  });

  /// The `array-contains-any` chunk. Empty for a query that filters another way.
  final List<String> audienceKeys;

  final PostVisibility visibility;

  /// Always [FeedOrdering.newestFirst]. It is a field rather than a constant so
  /// that a second value, if one were ever added, would have to be passed here
  /// explicitly at every call site.
  final FeedOrdering ordering;

  /// Every query carries one. The scalability gate's first line is "no unbounded
  /// collection scan", and this is how that is true by construction.
  final int limit;

  final DateTime? startAfter;
  final PostKind? kind;
  final String? groupId;
  final String? authorUid;
  final String? parentPostId;
  final CommunityTopic? topic;

  /// Stories only: `expiresAt > now`.
  final DateTime? expiringAfter;

  @override
  String toString() =>
      'FeedQuery(keys: ${audienceKeys.length}, kind: ${kind?.wireName}, '
      'group: $groupId, author: $authorUid, limit: $limit, '
      'ordering: ${ordering.name})';
}

/// Builds the queries for the feed and its neighbours.
///
/// Every method returns queries ordered [FeedOrdering.newestFirst] and there is
/// no parameter on any of them that could select a different one.
class FeedQueryFactory {
  const FeedQueryFactory({
    this.pageSize = kFeedPageSize,
    this.chunkSize = kAudienceChunk,
    this.maxChunks = kMaxFeedChunks,
  });

  final int pageSize;
  final int chunkSize;
  final int maxChunks;

  /// M01 — her feed. One query per chunk of her audience keys.
  ///
  /// Returns an empty list when she holds no keys at all, because that is the
  /// day-one state and issuing a query with an empty `arrayContainsAny` would be
  /// both an error and a read she should not be charged for.
  List<FeedQuery> page({required List<String> keys, DateTime? startAfter}) {
    if (keys.isEmpty) return const <FeedQuery>[];
    final chunks = chunkAudienceKeys(keys, chunkSize: chunkSize);
    final capped = chunks.length > maxChunks
        ? chunks.sublist(0, maxChunks)
        : chunks;
    return <FeedQuery>[
      for (final chunk in capped)
        FeedQuery(audienceKeys: chunk, limit: pageSize, startAfter: startAfter),
    ];
  }

  /// M01's stories rail. Cached five minutes; a story is bounded by its TTL.
  List<FeedQuery> stories({required List<String> keys, required DateTime now}) {
    if (keys.isEmpty) return const <FeedQuery>[];
    return <FeedQuery>[
      for (final chunk in chunkAudienceKeys(keys, chunkSize: chunkSize))
        FeedQuery(
          audienceKeys: chunk,
          kind: PostKind.story,
          expiringAfter: now,
          limit: 20,
        ),
    ];
  }

  /// M05 — one group's feed.
  FeedQuery group(String groupId, {DateTime? startAfter}) => FeedQuery(
    audienceKeys: const <String>[],
    groupId: groupId,
    limit: pageSize,
    startAfter: startAfter,
  );

  /// M07 — a woman's profile grid, optionally one tab of it.
  FeedQuery profile(String authorUid, {PostKind? kind, DateTime? startAfter}) =>
      FeedQuery(
        audienceKeys: const <String>[],
        authorUid: authorUid,
        kind: kind,
        limit: 12,
        startAfter: startAfter,
      );

  /// M12 — the follow-up thread. Ascending in time, because a chain reads
  /// forwards: Week 1, Week 4, Now.
  ///
  /// Still one ordering: [FeedOrdering.newestFirst] names the *field*, and the
  /// thread is the one surface that walks it the other way. It is expressed as a
  /// separate factory rather than a `descending` flag so that no caller can
  /// reverse the feed itself.
  FeedQuery followUps(String parentPostId) => FeedQuery(
    audienceKeys: const <String>[],
    parentPostId: parentPostId,
    limit: pageSize,
  );

  /// M11 — her own posts that a follow-up could attach to: hers, and not
  /// themselves follow-ups.
  FeedQuery ownParents(String authorUid) => FeedQuery(
    audienceKeys: const <String>[],
    authorUid: authorUid,
    limit: pageSize,
  );
}

/// M10 — Explore.
///
/// A separate factory because Explore is the surface where a ranking would be
/// most tempting: "trending", "popular", "for you". It has the same single
/// ordering and the same absence of a sort parameter.
class ExploreQueryFactory {
  const ExploreQueryFactory({this.gridSize = 18, this.searchLimit = 20});

  final int gridSize;
  final int searchLimit;

  /// The grid, optionally narrowed by one chip.
  FeedQuery grid({CommunityTopic? topic, DateTime? startAfter}) => FeedQuery(
    audienceKeys: const <String>[],
    topic: topic,
    limit: gridSize,
    startAfter: startAfter,
  );

  /// Name search over `publicProfiles`, which contains only discoverable women.
  ///
  /// A prefix range on `nameLower`, capped at [searchLimit] — the rules refuse a
  /// `list` with a larger limit. Returns null for a blank query rather than
  /// issuing an unbounded scan.
  ProfileSearch? searchProfiles(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;
    return ProfileSearch(prefix: q, limit: searchLimit);
  }
}

/// A prefix search, bounded at both ends.
@immutable
class ProfileSearch {
  const ProfileSearch({required this.prefix, required this.limit});

  final String prefix;
  final int limit;

  /// The exclusive upper bound — `prefix` with its last code unit incremented,
  /// which is how a prefix range is expressed to Firestore.
  String get upperBound {
    if (prefix.isEmpty) return prefix;
    final last = prefix.codeUnitAt(prefix.length - 1);
    return prefix.substring(0, prefix.length - 1) +
        String.fromCharCode(last + 1);
  }
}
