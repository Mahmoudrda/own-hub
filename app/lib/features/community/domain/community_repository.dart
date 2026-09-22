/// What Community reads and writes.
///
/// Built against a strict in-memory fake, the way `TrainRepository` and the
/// Progress repositories are: Phase 3 has no Firebase project, and a fake that
/// accepts anything lets a screen pass its tests and then fail on a phone
/// (`PHASE1-QA-VERDICT`'s standing note, which this file follows deliberately).
///
/// # Four absences, each one a product rule
///
/// **1. No `Stream`, no `watch`, no snapshot listener — anywhere.**
/// `G10-community.md` §2.4 lists this as a requirement, not a preference:
/// *"a live listener on a feed re-reads on every write by anyone she follows —
/// the standard way this bill goes to $500."* Every read below returns a
/// `Future` of one page. Refreshing is [CommunityRepository.refresh] and
/// pull-to-refresh, explicitly. A test asserts no `Stream` appears in this file.
///
/// **2. No roster, in either direction.** There is no `likesOf(postId)`, no
/// `whoLiked`, no `membersOf(groupId)` and no `followersOf(uid)`. The rules say
/// `allow list: if false` on `likes` (except constrained to her own posts) and
/// on `members` outright — 4,210 women are not a list to scrape. A method that
/// does not exist cannot be called by a screen built in a hurry.
///
/// **3. No ordering parameter.** Nothing here takes a sort field, a comparator
/// or a direction. Ordering is `createdAt`, expressed once in
/// [FeedQueryFactory], and rule 11 is the reason.
///
/// **4. No media cache.** There is no `download`, no `prefetch` and no
/// `cacheForOffline`. `G10` §4: community media is *"other women's bodies, and a
/// local cache of it is a privacy liability, not a feature."* Text and counts
/// come from the Firestore cache; the pictures do not come at all.
///
/// # Every write is one document, with a deterministic id
///
/// Spine C1. A like's id is **her uid**, a save's id is the **postId**, a
/// follow's id is the **other uid**, a group membership's id is **her uid**. A
/// replayed offline write therefore collides with itself instead of creating a
/// second document — which is what makes `P0-COM-10` ("like it twice offline,
/// exactly one like exists") true by construction rather than by a check.
///
/// And publishing writes **exactly one document**, for zero followers or five
/// thousand. That is spine C9, and [InMemoryCommunityRepository.documentWrites]
/// is what `P0-COM-02` counts.
// `prefer_initializing_formals` asks for `this._online`, which Dart forbids: a
// named parameter cannot begin with an underscore. The field stays private
// deliberately — goOnline() is what drains the queue and publishes held drafts,
// so flipping the flag directly would report signal while writes were still
// stranded and a post was still sitting on her phone. Same reasoning, and the
// same exemption, as `features/account/domain/safety.dart`.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:meta/meta.dart';

import 'audience_keys.dart';
import 'community_models.dart';
import 'feed_query.dart';
import 'follow_up_policy.dart';
import 'follower_count.dart';

/// One page of the feed, plus what it cost.
///
/// The cost fields are not telemetry — they are how `P0-COM-16` asserts that
/// chunking is bounded and unbiased, and how the plan's "10 reads per chunk per
/// page" stops being a claim in a document.
@immutable
class FeedPage {
  const FeedPage({
    required this.posts,
    this.queriesIssued = const <FeedQuery>[],
    this.documentReads = 0,
    this.fromCache = false,
    this.cursor,
  });

  final List<CommunityPost> posts;

  /// One per audience-key chunk. p50 is 1, p95 is 2, hard cap 10.
  final List<FeedQuery> queriesIssued;

  final int documentReads;

  /// True when the page was served from the local cache with no network.
  final bool fromCache;

  /// `createdAt` of the last post, for the next page.
  final DateTime? cursor;

  bool get isEmpty => posts.isEmpty;
}

/// Reads and writes for M01–M17.
abstract class CommunityRepository {
  // ------------------------------------------------------------- her state --

  /// `followGraph/{uid}` — her audience keys. One read, then cached.
  Future<FollowGraph> followGraph();

  // ------------------------------------------------------------------ feed --

  /// M01. Cache-first; [refresh] is the pull-to-refresh gesture.
  Future<FeedPage> feed({DateTime? startAfter, bool refresh = false});

  /// M01's stories rail. Bounded by a TTL, not a sweep, and cached five minutes.
  Future<List<CommunityPost>> stories({required DateTime now});

  // ------------------------------------------------------------------ post --

  /// M02. Usually already in memory from the feed, which is why M02 costs zero
  /// reads when opened from M01.
  Future<CommunityPost?> post(String postId);

  Future<List<CommunityComment>> comments(String postId);

  // ---------------------------------------------------------------- groups --

  /// M04's "Yours", from her `groupKeys`.
  Future<List<CommunityGroup>> myGroups();

  /// M04's "Suggested for you".
  Future<List<CommunityGroup>> suggestedGroups({int limit = 8});

  Future<CommunityGroup?> group(String groupId);

  /// M05's group feed.
  Future<List<CommunityPost>> groupPosts(String groupId);

  /// M06. Null when the group has no challenge running.
  Future<GroupChallenge?> openChallenge(String groupId);

  // --------------------------------------------------------------- profile --

  /// M07. **Null means not available** — she is not discoverable, or there is a
  /// block in one direction, and the caller cannot tell which. That collapse is
  /// the guarantee, not an ambiguity to fix.
  Future<PublicProfile?> profile(String uid);

  Future<List<CommunityPost>> profilePosts(String uid, {PostKind? kind});

  // --------------------------------------------------------------- explore --

  Future<List<CommunityPost>> explore({CommunityTopic? topic});

  Future<List<PublicProfile>> searchProfiles(String query);

  Future<List<CommunityGroup>> searchGroups(String query);

  // ------------------------------------------------------------ follow-ups --

  /// M11 — her own posts a follow-up could attach to. Never another woman's.
  Future<List<CommunityPost>> ownFollowUpParents();

  /// M12 — one woman over time. Null when the parent is gone.
  Future<FollowUpChain?> followUpChain(String parentPostId);

  // -------------------------------------------------------- saved/activity --

  /// M15. Thumbnails are denormalised, so this costs no post reads.
  Future<List<SavedPost>> saved();

  /// M14. Three constrained reads, **zero** notification documents.
  Future<List<ActivityItem>> activity();

  // ---------------------------------------------------------------- writes --

  /// Doc id = her uid, so a replay is the same document.
  Future<void> like(String postId);
  Future<void> unlike(String postId);

  /// [commentId] is minted once by the caller (spine C1).
  Future<void> comment({
    required String postId,
    required String commentId,
    required String body,
  });

  /// Doc id = postId. Private anyway.
  Future<void> save(String postId);
  Future<void> unsave(String postId);

  /// Doc id = the other uid.
  Future<void> follow(String uid);
  Future<void> unfollow(String uid);

  /// Doc id = her uid.
  Future<void> joinGroup(String groupId);
  Future<void> leaveGroup(String groupId);

  /// Still a member; the group's posts leave her feed until [until].
  Future<void> muteGroup(String groupId, {required DateTime until});

  /// Creates the one `posts/{postId}` document.
  ///
  /// Called **after** the media is at the CDN — see `PostPublishService`. The
  /// ordering is deliberate and is the one place this product writes the
  /// document last.
  Future<void> publishPost(CommunityPost post);

  /// Deletion is not a hide: the document goes and the media is purged.
  Future<void> deletePost(String postId);

  /// Hers to hide and to unhide. `author_hidden`, never `removed`.
  Future<void> hideOwnPost(String postId);
}

/// Seeded state for the fake. A plain bag, so a test says what the room
/// contains without a builder API.
class CommunityStore {
  CommunityStore({
    this.selfUid = 'me',
    this.selfCard = const AuthorCard(uid: 'me', name: 'Me'),
    List<CommunityPost>? posts,
    Map<String, List<CommunityComment>>? comments,
    List<CommunityGroup>? groups,
    Map<String, GroupChallenge>? challenges,
    Map<String, PublicProfile>? profiles,
    List<SavedPost>? saved,
    List<ActivityItem>? activity,
    FollowGraph? graph,
    Map<String, List<String>>? followers,
  }) : posts = posts ?? <CommunityPost>[],
       comments = comments ?? <String, List<CommunityComment>>{},
       groups = groups ?? <CommunityGroup>[],
       challenges = challenges ?? <String, GroupChallenge>{},
       profiles = profiles ?? <String, PublicProfile>{},
       saved = saved ?? <SavedPost>[],
       activity = activity ?? <ActivityItem>[],
       graph = graph ?? FollowGraph(),
       followers = followers ?? <String, List<String>>{};

  final String selfUid;

  /// Her name and face on her own posts and comments. Not final: the product
  /// says her name in the language she is reading in, and a store built before
  /// the first frame cannot know which that is.
  AuthorCard selfCard;
  final List<CommunityPost> posts;
  final Map<String, List<CommunityComment>> comments;
  final List<CommunityGroup> groups;
  final Map<String, GroupChallenge> challenges;
  final Map<String, PublicProfile> profiles;
  final List<SavedPost> saved;
  final List<ActivityItem> activity;
  FollowGraph graph;

  /// Who follows whom. **Only ever read to prove it is not written to.**
  ///
  /// `P0-COM-02` seeds five thousand here and asserts publishing still writes
  /// one document. Nothing in the repository iterates this map on a write path,
  /// and that is the property under test.
  final Map<String, List<String>> followers;
}

/// In-memory, and strict where the rules are strict.
///
/// The strictness is the point. Every refusal below mirrors a line in
/// `firestore.rules`, so a draft this fake rejects is a draft the server would
/// have rejected too.
class InMemoryCommunityRepository implements CommunityRepository {
  InMemoryCommunityRepository({
    CommunityStore? store,
    bool online = true,
    DateTime? now,
    this.feedQueries = const FeedQueryFactory(),
    this.exploreQueries = const ExploreQueryFactory(),
  }) : _store = store ?? CommunityStore(),
       _online = online,
       _now = now ?? DateTime(2026, 9, 19, 10);

  final CommunityStore _store;
  final DateTime _now;
  final FeedQueryFactory feedQueries;
  final ExploreQueryFactory exploreQueries;

  bool _online;

  /// **Every document path written, in order.**
  ///
  /// The instrument `P0-COM-02` and `P1-COM-09` read. A per-follower write would
  /// show up here as five thousand entries; spine C9 says there must be one.
  final List<String> documentWrites = <String>[];

  /// Media objects that reached "the CDN". Not Firestore documents — the case
  /// says "exactly one document is written, **plus its media objects**".
  final List<String> mediaObjectUploads = <String>[];

  /// Everything that happened on the publish path, **in order**:
  /// `media:<url>` entries, then `doc:<path>`.
  ///
  /// Two separate lists can show that both happened; they cannot show which
  /// happened first. §3.1's whole point is the ordering — the document is
  /// created last, after the bytes are at the CDN — so the ordering needs a
  /// single ordered record to be assertable at all.
  final List<String> events = <String>[];

  /// Writes made while offline, keyed by document path so a replay collides
  /// with itself. A Map, not a List: that is the idempotency.
  final Map<String, Future<void> Function()> _queued =
      <String, Future<void> Function()>{};

  /// Composed offline and not yet published. Visible to her alone.
  final List<CommunityPost> _localDrafts = <CommunityPost>[];

  /// Like documents that exist, by post. The id is always her uid.
  final Map<String, Set<String>> _likes = <String, Set<String>>{};

  bool get online => _online;

  String get selfUid => _store.selfUid;

  int get queuedWriteCount => _queued.length;

  void goOffline() => _online = false;

  /// Reconnects and drains. Each queued write runs once, because the queue is
  /// keyed by its document path.
  Future<void> goOnline() async {
    _online = true;
    final pending = _queued.values.toList();
    _queued.clear();
    for (final write in pending) {
      await write();
    }
    // Drafts upload their media first, then create their one document each.
    final drafts = _localDrafts.toList();
    _localDrafts.clear();
    for (final draft in drafts) {
      await publishPost(draft);
    }
  }

  /// Runs [write] now, or holds it under [path] until she reconnects.
  Future<void> _write(String path, Future<void> Function() write) async {
    if (!_online) {
      _queued[path] = write;
      return;
    }
    await write();
  }

  void _record(String path) => documentWrites.add(path);

  // --------------------------------------------------------------- reads --

  @override
  Future<FollowGraph> followGraph() async => _store.graph;

  @override
  Future<FeedPage> feed({DateTime? startAfter, bool refresh = false}) async {
    final graph = _store.graph;
    final queries = feedQueries.page(
      keys: graph.audienceKeys,
      startAfter: startAfter,
    );

    final keySet = graph.audienceKeys.toSet();
    final matched =
        _store.posts
            .where((p) => p.visibility.isVisibleInFeed)
            // A story belongs on the rail, not in the feed body.
            .where((p) => p.kind != PostKind.story)
            // Blocked in either direction: filtered client-side against the
            // Function-maintained hiddenAuthors. G7 requires the feed to
            // denormalise exclusion rather than evaluate notBlockedBy() per
            // document, which would be one billed read per post per page.
            .where((p) => !graph.hides(p.authorUid))
            // Her own posts are always hers to see. She does not follow
            // herself, so without this a post would drop out of her own feed
            // the instant it published — and P0-COM-12's "her own feed shows
            // it" would stop being true the moment the draft synced, which is
            // the worst possible moment for a post to appear to vanish.
            .where(
              (p) =>
                  p.authorUid == selfUid ||
                  p.audienceKeys.values.any(keySet.contains),
            )
            .where(
              (p) => startAfter == null || p.createdAt.isBefore(startAfter),
            )
            .toList()
          // createdAt, descending. There is no score and no engagement weight.
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Her own queued posts render in her own feed at full opacity, badged.
    final mine =
        _localDrafts.map((p) => p.withViewerState(pendingUpload: true)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final page = <CommunityPost>[
      ...mine,
      ...matched.take(feedQueries.pageSize),
    ];

    return FeedPage(
      posts: page,
      queriesIssued: queries,
      // Ten per chunk per page, which is the figure §2.1 commits to.
      documentReads: queries.length * feedQueries.pageSize,
      fromCache: !_online,
      cursor: matched.isEmpty ? null : matched.last.createdAt,
    );
  }

  @override
  Future<List<CommunityPost>> stories({required DateTime now}) async {
    final graph = _store.graph;
    final keySet = graph.audienceKeys.toSet();
    return _store.posts
        .where((p) => p.kind == PostKind.story)
        .where((p) => !p.hasExpiredAt(now))
        .where((p) => !graph.hides(p.authorUid))
        // "Your day" — her own ring is the first one on the rail.
        .where(
          (p) =>
              p.authorUid == selfUid ||
              p.audienceKeys.values.any(keySet.contains),
        )
        .toList();
  }

  @override
  Future<CommunityPost?> post(String postId) async {
    final graph = _store.graph;
    for (final p in _store.posts) {
      if (p.postId != postId) continue;
      if (graph.hides(p.authorUid)) return null; // "not available"
      if (!p.visibility.isVisibleInFeed && p.authorUid != selfUid) return null;
      return p;
    }
    return null;
  }

  @override
  Future<List<CommunityComment>> comments(String postId) async {
    final graph = _store.graph;
    return (_store.comments[postId] ?? const <CommunityComment>[])
        .where((c) => !graph.hides(c.authorCard.uid))
        .toList();
  }

  @override
  Future<List<CommunityGroup>> myGroups() async =>
      _store.groups.where((g) => g.joined).toList();

  @override
  Future<List<CommunityGroup>> suggestedGroups({int limit = 8}) async =>
      _store.groups.where((g) => !g.joined).take(limit).toList();

  @override
  Future<CommunityGroup?> group(String groupId) async {
    for (final g in _store.groups) {
      if (g.groupId == groupId) return g;
    }
    return null;
  }

  @override
  Future<List<CommunityPost>> groupPosts(String groupId) async {
    final graph = _store.graph;
    return (_store.posts
        .where((p) => p.groupId == groupId)
        .where((p) => p.visibility.isVisibleInFeed)
        .where((p) => p.kind != PostKind.story)
        .where((p) => !graph.hides(p.authorUid))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<GroupChallenge?> openChallenge(String groupId) async =>
      _store.challenges[groupId];

  @override
  Future<PublicProfile?> profile(String uid) async {
    // Hidden either way → absent, exactly as a woman who turned her profile off
    // is absent. The caller cannot distinguish the two.
    if (_store.graph.hides(uid)) return null;
    return _store.profiles[uid];
  }

  @override
  Future<List<CommunityPost>> profilePosts(String uid, {PostKind? kind}) async {
    if (_store.graph.hides(uid)) return const <CommunityPost>[];
    return (_store.posts
        .where((p) => p.authorUid == uid)
        .where((p) => p.visibility.isVisibleInFeed)
        .where((p) => kind == null || p.kind == kind)
        .where((p) => !p.isFollowUp || kind == PostKind.photo)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<List<CommunityPost>> explore({CommunityTopic? topic}) async {
    final graph = _store.graph;
    return (_store.posts
        .where((p) => p.visibility.isVisibleInFeed)
        .where((p) => p.kind != PostKind.story)
        .where((p) => !graph.hides(p.authorUid))
        .where((p) => topic == null || p.topics.contains(topic))
        .take(exploreQueries.gridSize)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));
  }

  @override
  Future<List<PublicProfile>> searchProfiles(String query) async {
    final search = exploreQueries.searchProfiles(query);
    if (search == null) return const <PublicProfile>[];
    return _store.profiles.values
        .where((p) => !_store.graph.hides(p.uid))
        .where((p) => p.name.toLowerCase().startsWith(search.prefix))
        .take(search.limit)
        .toList();
  }

  @override
  Future<List<CommunityGroup>> searchGroups(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <CommunityGroup>[];
    return _store.groups
        .where((g) => g.name.toLowerCase().contains(q))
        .toList();
  }

  @override
  Future<List<CommunityPost>> ownFollowUpParents() async =>
      (_store.posts
          .where((p) => p.authorUid == selfUid)
          .where((p) => !p.isFollowUp)
          .where((p) => p.visibility.isVisibleInFeed)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)));

  @override
  Future<FollowUpChain?> followUpChain(String parentPostId) async {
    final parent = await post(parentPostId);
    if (parent == null) return null;
    final children =
        _store.posts.where((p) => p.parentPostId == parentPostId).toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return FollowUpChain(
      authorUid: parent.authorUid,
      moments: <FollowUpMoment>[
        FollowUpMoment(
          postId: parent.postId,
          authorUid: parent.authorUid,
          takenAt: parent.createdAt,
          cost: parent.cost,
        ),
        for (final c in children)
          FollowUpMoment(
            postId: c.postId,
            authorUid: c.authorUid,
            takenAt: c.createdAt,
            cost: c.cost,
          ),
      ],
    );
  }

  @override
  Future<List<SavedPost>> saved() async =>
      (_store.saved.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt)));

  @override
  Future<List<ActivityItem>> activity() async {
    final graph = _store.graph;
    return _store.activity
        .where((a) => a.actor == null || !graph.hides(a.actor!.uid))
        .toList();
  }

  // -------------------------------------------------------------- writes --

  /// Refuses a write that would reach a woman on either side of a block.
  ///
  /// Mirrors `notBlockedBy()` in the rules. The message is deliberately about
  /// the *action*, never about a block: nothing this throws may end up rendered
  /// as "you are blocked".
  void _assertMayContact(String otherUid) {
    if (_store.graph.hides(otherUid)) {
      throw StateError('not available');
    }
  }

  @override
  Future<void> like(String postId) async {
    final target = _store.posts.where((p) => p.postId == postId).firstOrNull;
    if (target != null) _assertMayContact(target.authorUid);
    // The id is her uid. Liking twice writes the same path twice and leaves one
    // document — which is the whole of P0-COM-10.
    final path = 'posts/$postId/likes/$selfUid';
    await _write(path, () async {
      _record(path);
      (_likes[postId] ??= <String>{}).add(selfUid);
    });
  }

  @override
  Future<void> unlike(String postId) async {
    final path = 'posts/$postId/likes/$selfUid';
    await _write(path, () async {
      _record(path);
      _likes[postId]?.remove(selfUid);
    });
  }

  /// How many like documents exist for [postId]. Not a roster — a count of
  /// documents in the fake, for tests. There is no API that names who.
  int likeDocCount(String postId) => _likes[postId]?.length ?? 0;

  @override
  Future<void> comment({
    required String postId,
    required String commentId,
    required String body,
  }) async {
    if (body.length > kMaxCommentLength) {
      throw ArgumentError.value(
        body.length,
        'body',
        'the rules cap a comment at $kMaxCommentLength characters',
      );
    }
    final target = _store.posts.where((p) => p.postId == postId).firstOrNull;
    if (target != null) _assertMayContact(target.authorUid);

    final path = 'posts/$postId/comments/$commentId';
    final queuedOffline = !_online;
    await _write(path, () async {
      _record(path);
      final list = _store.comments[postId] ??= <CommunityComment>[];
      final landed = CommunityComment(
        commentId: commentId,
        authorCard: _store.selfCard,
        postAuthorUid: target?.authorUid ?? '',
        body: body,
        createdAt: _now,
      );
      // Minted once, so a replay lands on the same id. The optimistic copy is
      // REPLACED rather than skipped: returning early would leave the queued
      // glyph sitting on a comment that has already synced, which reads as a
      // comment stuck forever.
      final at = list.indexWhere((c) => c.commentId == commentId);
      if (at >= 0) {
        list[at] = landed;
      } else {
        list.add(landed);
      }
    });

    if (queuedOffline) {
      // Shows at once, at full opacity, with the queued glyph. No spinner and
      // no failure message for something that will sync.
      (_store.comments[postId] ??= <CommunityComment>[]).add(
        CommunityComment(
          commentId: commentId,
          authorCard: _store.selfCard,
          postAuthorUid: target?.authorUid ?? '',
          body: body,
          createdAt: _now,
          pendingSync: true,
        ),
      );
    }
  }

  @override
  Future<void> save(String postId) async {
    final path = 'users/$selfUid/saved/$postId';
    await _write(path, () async {
      _record(path);
      if (_store.saved.any((s) => s.postId == postId)) return;
      final target = _store.posts.where((p) => p.postId == postId).firstOrNull;
      _store.saved.add(
        SavedPost(
          postId: postId,
          kind: target?.kind ?? PostKind.photo,
          authorUid: target?.authorUid ?? '',
          savedAt: _now,
          thumbUrl: target?.media.firstOrNull?.thumbUrl,
        ),
      );
    });
  }

  @override
  Future<void> unsave(String postId) async {
    final path = 'users/$selfUid/saved/$postId';
    await _write(path, () async {
      _record(path);
      _store.saved.removeWhere((s) => s.postId == postId);
    });
  }

  @override
  Future<void> follow(String uid) async {
    _assertMayContact(uid);
    final path = 'followGraph/$selfUid/following/$uid';
    await _write(path, () async {
      _record(path);
      final key = '$kAuthorKeyPrefix$uid';
      if (_store.graph.followingKeys.contains(key)) return;
      _store.graph = FollowGraph(
        followingKeys: <String>[..._store.graph.followingKeys, key],
        groupKeys: _store.graph.groupKeys,
        hiddenAuthors: _store.graph.hiddenAuthors,
        updatedAt: _now,
      );
    });
  }

  @override
  Future<void> unfollow(String uid) async {
    final path = 'followGraph/$selfUid/following/$uid';
    await _write(path, () async {
      _record(path);
      _store.graph = FollowGraph(
        followingKeys: _store.graph.followingKeys
            .where((k) => k != '$kAuthorKeyPrefix$uid')
            .toList(),
        groupKeys: _store.graph.groupKeys,
        hiddenAuthors: _store.graph.hiddenAuthors,
        updatedAt: _now,
      );
    });
  }

  @override
  Future<void> joinGroup(String groupId) async {
    final path = 'groups/$groupId/members/$selfUid';
    await _write(path, () async {
      _record(path);
      _setJoined(groupId, true);
      final key = '$kGroupKeyPrefix$groupId';
      if (_store.graph.groupKeys.contains(key)) return;
      _store.graph = FollowGraph(
        followingKeys: _store.graph.followingKeys,
        groupKeys: <String>[..._store.graph.groupKeys, key],
        hiddenAuthors: _store.graph.hiddenAuthors,
        updatedAt: _now,
      );
    });
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    final path = 'groups/$groupId/members/$selfUid';
    await _write(path, () async {
      _record(path);
      _setJoined(groupId, false);
      _store.graph = FollowGraph(
        followingKeys: _store.graph.followingKeys,
        groupKeys: _store.graph.groupKeys
            .where((k) => k != '$kGroupKeyPrefix$groupId')
            .toList(),
        hiddenAuthors: _store.graph.hiddenAuthors,
        updatedAt: _now,
      );
    });
  }

  @override
  Future<void> muteGroup(String groupId, {required DateTime until}) async {
    final path = 'groups/$groupId/members/$selfUid';
    await _write(path, () async {
      _record(path);
      final i = _store.groups.indexWhere((g) => g.groupId == groupId);
      if (i < 0) return;
      final g = _store.groups[i];
      // Still a member. Her posts still count for the challenge; only the feed
      // key goes, and the Function restores it when the mute lapses.
      _store.groups[i] = CommunityGroup(
        groupId: g.groupId,
        name: g.name,
        memberCount: g.memberCount,
        blurb: g.blurb,
        topics: g.topics,
        postsToday: g.postsToday,
        joined: g.joined,
        mutedUntil: until,
      );
      _store.graph = FollowGraph(
        followingKeys: _store.graph.followingKeys,
        groupKeys: _store.graph.groupKeys
            .where((k) => k != '$kGroupKeyPrefix$groupId')
            .toList(),
        hiddenAuthors: _store.graph.hiddenAuthors,
        updatedAt: _now,
      );
    });
  }

  void _setJoined(String groupId, bool joined) {
    final i = _store.groups.indexWhere((g) => g.groupId == groupId);
    if (i < 0) return;
    final g = _store.groups[i];
    _store.groups[i] = CommunityGroup(
      groupId: g.groupId,
      name: g.name,
      memberCount: g.memberCount,
      blurb: g.blurb,
      topics: g.topics,
      postsToday: g.postsToday,
      joined: joined,
      mutedUntil: g.mutedUntil,
    );
  }

  @override
  Future<void> publishPost(CommunityPost post) async {
    // Structural C9: two keys at most, whatever the audience. Asserted here as
    // well as in the type, because this is the boundary the server sees.
    if (post.audienceKeys.size > 2) {
      throw StateError(
        'audienceKeys has ${post.audienceKeys.size} entries. Spine C9 caps it '
        'at 2 — a field that grows with an audience is fan-out on write.',
      );
    }

    if (!_online) {
      // The document waits. Her own feed and profile show it badged; no post
      // document exists for anyone else until the media is up (P0-COM-12).
      _localDrafts.add(post);
      return;
    }

    // Media first, document last. A post whose media 404s is a broken card in
    // OTHER women's feeds — a failure she cannot see and cannot fix.
    for (final m in post.media) {
      mediaObjectUploads.add(m.url);
      events.add('media:${m.url}');
    }

    final path = 'posts/${post.postId}';
    _record(path);
    events.add('doc:$path');

    // Minted once, so a retried publish targets the same document.
    final existing = _store.posts.indexWhere((p) => p.postId == post.postId);
    if (existing >= 0) {
      _store.posts[existing] = post;
    } else {
      _store.posts.add(post);
    }

    // NOTE what does not happen here: nothing iterates followers, and there is
    // no second collection to copy into. Publishing for a woman with five
    // thousand followers appends exactly one path above, and P0-COM-02 counts
    // it. The followers map is seeded and never touched.
  }

  @override
  Future<void> deletePost(String postId) async {
    final path = 'posts/$postId';
    await _write(path, () async {
      _record(path);
      final gone = _store.posts.where((p) => p.postId == postId).toList();
      _store.posts.removeWhere((p) => p.postId == postId);
      // Follow-ups have no existence apart from their parent.
      _store.posts.removeWhere((p) => p.parentPostId == postId);
      _store.comments.remove(postId);
      _likes.remove(postId);
      // The saved tile survives as "not available" rather than a broken image.
      for (var i = 0; i < _store.saved.length; i++) {
        if (_store.saved[i].postId != postId) continue;
        final s = _store.saved[i];
        _store.saved[i] = SavedPost(
          postId: s.postId,
          kind: s.kind,
          authorUid: s.authorUid,
          savedAt: s.savedAt,
        );
      }
      // The R2 objects go too, and the CDN is purged for those exact URLs.
      for (final p in gone) {
        for (final m in p.media) {
          mediaObjectUploads.remove(m.url);
        }
      }
    });
  }

  @override
  Future<void> hideOwnPost(String postId) async {
    final path = 'posts/$postId';
    await _write(path, () async {
      _record(path);
      final i = _store.posts.indexWhere((p) => p.postId == postId);
      if (i < 0) return;
      final p = _store.posts[i];
      if (p.authorUid != selfUid) {
        throw StateError('only her own post is hers to hide');
      }
      _store.posts[i] = CommunityPost(
        postId: p.postId,
        authorCard: p.authorCard,
        kind: p.kind,
        audienceKeys: p.audienceKeys,
        createdAt: p.createdAt,
        media: p.media,
        caption: p.caption,
        topics: p.topics,
        groupId: p.groupId,
        parentPostId: p.parentPostId,
        cost: p.cost,
        blurApplied: p.blurApplied,
        blurOptOut: p.blurOptOut,
        visibility: PostVisibility.authorHidden,
        expiresAt: p.expiresAt,
        likeCount: p.likeCount,
        commentCount: p.commentCount,
        followUpCount: p.followUpCount,
        latestFollowUpAt: p.latestFollowUpAt,
        likedByMe: p.likedByMe,
        savedByMe: p.savedByMe,
        schemaV: p.schemaV,
      );
    });
  }

  /// How many followers the author has, for a test that wants to state the
  /// number it seeded. Read-only, and used by no write path.
  FollowerCount followerCountOf(String uid) =>
      FollowerCount(_store.followers[uid]?.length ?? 0);
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
