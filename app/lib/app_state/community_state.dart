/// G10. What the M screens read, and the one place they write.
///
/// ## Why this file exists
///
/// Every community screen is a `StatelessWidget` built from a model computed at
/// route-build time, and `AppRouter.communityStore` was the document store they
/// all read. What was missing is the other half: nothing wrote to it. A like
/// went nowhere, a join flipped no row, and the composer had no composer. This
/// is the write side — and, because a count on a post is written by a Cloud
/// Function that does not exist in this build, it is also the counter.
///
/// Every mutation here does three things in order:
///
///   1. calls the **existing** repository, so the document paths, the block
///      guards and the offline queue are the real ones
///      ([InMemoryCommunityRepository] is strict where `firestore.rules` is
///      strict);
///   2. applies what the counter Function would have applied — `counts.likes`,
///      `counts.comments`, `likedByMe`, `savedByMe` — because
///      [CommunityPost] deliberately has no `copyWith` that moves a count and
///      the client is not the writer of one;
///   3. calls [AppChanges.bump] so every open screen redraws from the new
///      state.
///
/// ## Nothing here is invented
///
/// There are no seeded posts, no seeded likes, no other women and no follower
/// figures. The feed starts empty and fills with what she writes. The only
/// seeded content is the **curated groups** — four rooms named from the
/// dictionary, the same four situations the design names (beginners, postpartum,
/// Ramadan, city) — and their member count is her own membership and nothing
/// else: 0 before she joins, 1 after.
///
/// ## Publishing goes through the publish service, not the repository
///
/// `PostPublishService` is the machine `G10` §3.1 describes: blur, then a
/// five-second undo window holding the work in the product's one
/// [LogCommandBus], then the document. Publishing raises no dialog, and undoing
/// inside the window costs zero writes because nothing has started.
library;

import 'dart:async';

import '../domain/flags/feature_flags.dart';
import '../domain/logging/log_command_bus.dart';
import '../features/account/domain/safety.dart';
import '../features/community/domain/audience_keys.dart';
import '../features/community/domain/blur_policy.dart';
import '../features/community/domain/community_models.dart';
import '../features/community/domain/community_repository.dart';
import '../features/community/domain/follow_up_policy.dart';
import '../features/community/domain/post_publish_service.dart';
import '../features/community/presentation/feed_view_model.dart';
import '../features/community/presentation/groups_view_model.dart';
import '../features/community/presentation/create_view_model.dart';
import '../features/community/presentation/profile_view_model.dart';
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';

/// Where a new post goes. Her page, one of her groups, or her day.
enum PostAudience {
  /// A post on her own page, addressed to `a:{herUid}`.
  page,

  /// A post into a group she has joined — `a:{herUid}` and `g:{groupId}`.
  group,

  /// A story: the same document, with a 24-hour TTL. It belongs on the rail,
  /// never in the feed body.
  day,
}

class CommunityState {
  CommunityState._();

  static final CommunityState instance = CommunityState._();

  /// THE store every M screen reads. Not a copy.
  CommunityStore get store => AppRouter.communityStore;

  String get selfUid => store.selfUid;

  /// The repository, over the same store. Writes go through it so the document
  /// paths and the refusals are the real ones.
  late final InMemoryCommunityRepository repository =
      InMemoryCommunityRepository(store: store, now: DateTime.now());

  /// The product's one undo point. A post is a log like any other.
  final LogCommandBus bus = LogCommandBus();

  late final PostPublishService publisher = PostPublishService(
    repository: repository,
    bus: bus,
    flags: AppRouter.featureFlags,
  );

  /// The room the composer opens into, recorded at the tap that opened M03.
  ///
  /// Null for a post on her own page. Set from inside a group, so "post" there
  /// posts into that group rather than making her choose it again.
  String? composeGroupId;

  /// What she is writing on `M11`, kept while the screen rebuilds under her.
  String followUpCaption = '';

  /// Whether she asked for the cost card on `M11`. Off by default: it is an
  /// offer, never a requirement.
  bool followUpCostOn = false;

  /// Which of `M16`'s three modes is chosen. Null means the first one.
  RecordMode? recordMode;

  /// Which post `M08` is about, recorded at the tap that opened it.
  ///
  /// Null when the sheet is about a woman or a group rather than one post —
  /// and that is exactly what decides whether "delete this post" is offered.
  String? safetyPostId;

  var _ids = 0;

  String _mint(String prefix) {
    _ids++;
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_ids';
  }

  // ------------------------------------------------------------- the room --

  /// The four curated rooms, by id. Names come from the dictionary, so the
  /// Arabic build says them in Arabic.
  static const List<String> groupIds = <String>[
    'g-beginners',
    'g-postpartum',
    'g-ramadan',
    'g-city',
  ];

  /// Puts the curated groups and her own card in the store, and keeps them in
  /// step with the language she is reading in.
  ///
  /// Called at the top of every community screen's builder. It notifies
  /// nothing — a build must not — and it is idempotent.
  void ensureSeeded(AppL10n l10n) {
    final names = <String, String>{
      groupIds[0]: l10n.beginnersGroup,
      groupIds[1]: l10n.postpartumRebuild,
      groupIds[2]: l10n.ramadanTraining,
      groupIds[3]: l10n.cairoWestSide,
    };
    final blurbs = <String, String>{
      groupIds[3]: l10n.ladiesOnlyGymsAndWalkingGroups,
    };
    const topics = <String, CommunityTopic>{
      'g-beginners': CommunityTopic.beginner,
      'g-postpartum': CommunityTopic.postpartum,
      'g-ramadan': CommunityTopic.ramadan,
      'g-city': CommunityTopic.walking,
    };

    for (final id in groupIds) {
      final at = store.groups.indexWhere((g) => g.groupId == id);
      final existing = at < 0 ? null : store.groups[at];
      // Her membership is the only member count there is. A curated room with
      // "4,210 women" on it would be the prototype's figure stated as a fact.
      final group = CommunityGroup(
        groupId: id,
        name: names[id]!,
        memberCount: (existing?.joined ?? false) ? 1 : 0,
        blurb: blurbs[id] ?? '',
        topics: <CommunityTopic>[topics[id]!],
        joined: existing?.joined ?? false,
        mutedUntil: existing?.mutedUntil,
      );
      if (at < 0) {
        store.groups.add(group);
      } else {
        store.groups[at] = group;
      }
    }

    // Her name on her own posts and comments. "You" is what the rest of the
    // product calls her; nothing here invents one.
    store.selfCard = AuthorCard(uid: selfUid, name: l10n.you);
    store.profiles[selfUid] = PublicProfile(
      uid: selfUid,
      name: l10n.you,
      postCount: ownPosts.length,
    );
  }

  // --------------------------------------------------------------- reading --

  CommunityPost? post(String? postId) {
    if (postId == null) return null;
    for (final p in store.posts) {
      if (p.postId == postId) return p;
    }
    return null;
  }

  CommunityGroup? group(String? groupId) {
    if (groupId == null) return null;
    for (final g in store.groups) {
      if (g.groupId == groupId) return g;
    }
    return null;
  }

  /// Her own posts, newest first, follow-ups included.
  List<CommunityPost> get ownPosts => <CommunityPost>[
    for (final p in store.posts)
      if (p.authorUid == selfUid && p.kind != PostKind.story) p,
  ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// What M01's body shows: the same filter [InMemoryCommunityRepository.feed]
  /// applies, read synchronously because a route builder cannot await.
  List<CommunityPost> feedPosts({required DateTime now}) {
    final keys = store.graph.audienceKeys.toSet();
    return <CommunityPost>[
      for (final p in store.posts)
        if (p.visibility.isVisibleInFeed &&
            p.kind != PostKind.story &&
            !store.graph.hides(p.authorUid) &&
            (p.authorUid == selfUid ||
                p.audienceKeys.values.any(keys.contains)))
          p,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// The rail: live stories only.
  List<CommunityPost> stories({required DateTime now}) => <CommunityPost>[
    for (final p in store.posts)
      if (p.kind == PostKind.story &&
          !p.hasExpiredAt(now) &&
          !store.graph.hides(p.authorUid))
        p,
  ];

  FeedScreenModel feedModel(AppL10n l10n, {DateTime? at}) {
    ensureSeeded(l10n);
    final now = at ?? DateTime.now();
    return FeedScreenModel.from(
      graph: store.graph,
      page: FeedPage(posts: feedPosts(now: now)),
      viewerUid: selfUid,
      now: now,
      stories: stories(now: now),
      suggestedGroups: store.groups.where((g) => !g.joined).toList(),
      groupNames: <String, String>{
        for (final g in store.groups) g.groupId: g.name,
      },
    );
  }

  /// M07's three tabs. The reels tab exists only while video does — consulted,
  /// never hard-coded, exactly as [ProfileScreenModel] decides it.
  List<ProfileTab> get profileTabs => <ProfileTab>[
    ProfileTab.photos,
    if (AppRouter.featureFlags.isOn(Feature.communityVideo)) ProfileTab.reels,
    ProfileTab.followUps,
  ];

  ProfileTab tabAt(int index) {
    final tabs = profileTabs;
    if (index < 0 || index >= tabs.length) return ProfileTab.photos;
    return tabs[index];
  }

  /// M07. Which tiles she sees depends on which tab is open, so the reels tab
  /// is not her photos again under a different icon.
  ProfileScreenModel profileModel(
    AppL10n l10n,
    String uid, {
    int tabIndex = 0,
  }) {
    ensureSeeded(l10n);
    final tab = tabAt(tabIndex);
    final posts = <CommunityPost>[
      for (final p in store.posts)
        if (p.authorUid == uid &&
            p.visibility.isVisibleInFeed &&
            p.kind != PostKind.story &&
            _matchesTab(p, tab))
          p,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ProfileScreenModel.from(
      profile: store.profiles[uid],
      viewerUid: selfUid,
      subjectUid: uid,
      posts: posts,
      isFollowing: store.graph.followingKeys.contains('$kAuthorKeyPrefix$uid'),
      flags: AppRouter.featureFlags,
    );
  }

  bool _matchesTab(CommunityPost post, ProfileTab tab) => switch (tab) {
    // A follow-up lives in the thread it belongs to, not loose in her grid.
    ProfileTab.photos => post.kind != PostKind.reel && !post.isFollowUp,
    ProfileTab.reels => post.kind == PostKind.reel,
    // The parents: a tile here opens a thread, so it has to have one.
    ProfileTab.followUps =>
      !post.isFollowUp && store.posts.any((c) => c.parentPostId == post.postId),
  };

  GroupsScreenModel groupsModel(AppL10n l10n, {DateTime? at}) {
    ensureSeeded(l10n);
    return GroupsScreenModel.from(
      yours: store.groups.where((g) => g.joined).toList(),
      suggested: store.groups.where((g) => !g.joined).toList(),
      now: at ?? DateTime.now(),
    );
  }

  /// M10. The chip narrows the grid — the filter the repository applies,
  /// applied here for the same reason as [feedPosts].
  ExploreScreenModel exploreModel(CommunityTopic? topic) =>
      ExploreScreenModel.from(
        posts: <CommunityPost>[
          for (final p in store.posts)
            if (p.visibility.isVisibleInFeed &&
                p.kind != PostKind.story &&
                !store.graph.hides(p.authorUid) &&
                (topic == null || p.topics.contains(topic)))
              p,
        ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
        selected: topic,
      );

  /// M15. The chips narrow what she saved; "All" is everything.
  SavedScreenModel savedModel(int filter) => SavedScreenModel.from(
    <SavedPost>[
      for (final s in store.saved)
        if (_savedMatches(s, filter)) s,
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt)),
  );

  bool _savedMatches(SavedPost saved, int filter) {
    if (filter <= 0) return true;
    final topics = post(saved.postId)?.topics ?? const <CommunityTopic>[];
    // 1 = quiet moves, 2 = meals. Nothing in community is a meal, so that chip
    // narrows to nothing rather than pretending a post is one.
    if (filter == 1) return topics.contains(CommunityTopic.quiet);
    return false;
  }

  /// M14. Real activity on her posts, and the one nudge that is an action.
  ActivityScreenModel activityModel() {
    final prompt = _followUpPrompt();
    return ActivityScreenModel.from(<ActivityItem>[
      ...store.activity.reversed,
      if (prompt != null)
        ActivityItem(
          id: 'follow-up-${prompt.postId}',
          kind: ActivityKind.followUpPrompt,
          at: prompt.createdAt,
          postId: prompt.postId,
        ),
    ]);
  }

  /// Her oldest post that could carry a follow-up and has none yet. Null when
  /// there is nothing to follow up on — the prompt is never a decoration.
  CommunityPost? _followUpPrompt() {
    final candidates = <CommunityPost>[
      for (final p in ownPosts)
        if (!p.isFollowUp &&
            !store.posts.any((c) => c.parentPostId == p.postId))
          p,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return candidates.isEmpty ? null : candidates.first;
  }

  // --------------------------------------------------------------- writing --

  /// Like or unlike. One tap, no dialog, and the count is hers.
  Future<void> toggleLike(String postId) async {
    final target = post(postId);
    if (target == null) return;
    final liked = target.likedByMe;
    await _guarded(
      () => liked ? repository.unlike(postId) : repository.like(postId),
    );
    _replace(
      target,
      likedByMe: !liked,
      likeCount: (target.likeCount + (liked ? -1 : 1)).clamp(0, 1 << 30),
    );
    if (!liked && target.authorUid == selfUid) {
      _record(ActivityKind.liked, postId: postId);
    }
    AppChanges.bump();
  }

  /// Save or unsave. Private by construction — M15 is hers alone.
  Future<void> toggleSave(String postId) async {
    final target = post(postId);
    if (target == null) return;
    final saved = target.savedByMe;
    await _guarded(
      () => saved ? repository.unsave(postId) : repository.save(postId),
    );
    _replace(target, savedByMe: !saved);
    AppChanges.bump();
  }

  /// Comments on a post. Hers is on screen the moment she sends it.
  Future<void> addComment(String postId, String body) async {
    final text = body.trim();
    if (text.isEmpty || text.length > kMaxCommentLength) return;
    final target = post(postId);
    if (target == null) return;
    await _guarded(
      () =>
          repository.comment(postId: postId, commentId: _mint('c'), body: text),
    );
    _replace(target, commentCount: target.commentCount + 1);
    if (target.authorUid == selfUid) {
      _record(ActivityKind.commented, postId: postId, body: text);
    }
    AppChanges.bump();
  }

  Future<void> toggleFollow(String uid) async {
    if (uid.isEmpty || uid == selfUid) return;
    final following = store.graph.followingKeys.contains(
      '$kAuthorKeyPrefix$uid',
    );
    await _guarded(
      () => following ? repository.unfollow(uid) : repository.follow(uid),
    );
    AppChanges.bump();
  }

  Future<void> joinGroup(String groupId) async {
    await _guarded(() => repository.joinGroup(groupId));
    _setMemberCount(groupId, 1);
    AppChanges.bump();
  }

  Future<void> leaveGroup(String groupId) async {
    await _guarded(() => repository.leaveGroup(groupId));
    _setMemberCount(groupId, 0);
    AppChanges.bump();
  }

  /// Still a member, just quiet. A week, exactly as M08 says.
  Future<void> muteGroup(String groupId) async {
    await _guarded(
      () => repository.muteGroup(
        groupId,
        until: DateTime.now().add(const Duration(days: 7)),
      ),
    );
    AppChanges.bump();
  }

  /// Undoes a mute: the group's posts come back to her feed.
  Future<void> unmuteGroup(String groupId) async {
    final at = store.groups.indexWhere((g) => g.groupId == groupId);
    if (at < 0) return;
    final g = store.groups[at];
    store.groups[at] = CommunityGroup(
      groupId: g.groupId,
      name: g.name,
      memberCount: g.memberCount,
      blurb: g.blurb,
      topics: g.topics,
      postsToday: g.postsToday,
      joined: g.joined,
    );
    if (g.joined) {
      // The key the mute took out of her graph goes back in.
      await _guarded(() => repository.joinGroup(groupId));
    }
    AppChanges.bump();
  }

  bool isMuted(String? groupId) {
    final g = group(groupId);
    return g != null && g.isMutedAt(DateTime.now());
  }

  /// Hers to delete. The document goes, its follow-ups go with it, and the
  /// saved tile survives as "not available" rather than a broken image.
  Future<void> deletePost(String postId) async {
    final target = post(postId);
    if (target == null || target.authorUid != selfUid) return;
    await _guarded(() => repository.deletePost(postId));
    store.activity.removeWhere((a) => a.postId == postId);
    AppChanges.bump();
  }

  /// Files a report against the woman who wrote something.
  ///
  /// The same [ReportService] A04 reads, so a report filed here is already in
  /// the safety centre. Nothing about it claims a moderator has read it.
  Future<void> report(String subjectUid, ReportReason reason) async {
    if (subjectUid.isEmpty || subjectUid == selfUid) return;
    try {
      await AppRouter.reportService.file(
        subjectUid: subjectUid,
        reason: reason,
      );
    } on StateError {
      // Reporting herself, which the service refuses. Nothing to say.
    }
    AppChanges.bump();
  }

  // ------------------------------------------------------------ publishing --

  /// Writes a post. Returns the handle behind the five-second undo bar.
  ///
  /// Text only: the launch scope is photos and text, and there is no camera in
  /// this build, so `media` is empty — which is the same document with nothing
  /// in `media[]` rather than a second kind of post.
  LogHandle? publishText({
    required String caption,
    required String describe,
    PostAudience audience = PostAudience.page,
    String? groupId,
    List<CommunityTopic> topics = const <CommunityTopic>[],
    String? parentPostId,
  }) {
    final text = caption.trim();
    if (text.isEmpty || text.length > kMaxCaptionLength) return null;
    final now = DateTime.now();
    final inGroup = audience == PostAudience.group && groupId != null;

    final publication = publisher.publish(
      draft: PostDraft(
        postId: _mint('p'),
        authorCard: store.selfCard,
        kind: audience == PostAudience.day ? PostKind.story : PostKind.photo,
        audienceKeys: inGroup
            ? AudienceKeys.inGroup(authorUid: selfUid, groupId: groupId)
            : AudienceKeys.forAuthor(selfUid),
        media: const <CommunityMediaDraft>[],
        caption: text,
        topics: topics.take(kMaxPostTopics).toList(),
        groupId: inGroup ? groupId : null,
        parentPostId: parentPostId,
      ),
      describe: describe,
      now: now,
    );
    // The bus commits when the window closes; the screens have to be told.
    unawaited(_bumpWhenPublished());
    return publication.undoHandle;
  }

  /// Attaches a follow-up to one of her own posts.
  ///
  /// [FollowUpPolicy] decides whether it may attach at all, so a follow-up the
  /// rules would refuse is never composed — not merely refused on the way out.
  LogHandle? publishFollowUp({
    required String parentPostId,
    required String caption,
    required String describe,
    FollowUpCost? cost,
  }) {
    final parent = post(parentPostId);
    if (parent == null) return null;
    const policy = FollowUpPolicy();
    final mayAttach = policy.canAttach(
      parent: FollowUpParent(
        postId: parent.postId,
        authorUid: parent.authorUid,
        parentPostId: parent.parentPostId,
      ),
      authorUid: selfUid,
    );
    if (!mayAttach) return null;

    final publication = publisher.publish(
      draft: PostDraft(
        postId: _mint('p'),
        authorCard: store.selfCard,
        kind: PostKind.photo,
        audienceKeys: AudienceKeys.forAuthor(selfUid),
        media: const <CommunityMediaDraft>[],
        caption: caption.trim(),
        groupId: parent.groupId,
        parentPostId: parent.postId,
        cost: cost,
      ),
      describe: describe,
      now: DateTime.now(),
    );
    unawaited(_bumpWhenPublished());
    return publication.undoHandle;
  }

  Future<void> _bumpWhenPublished() async {
    await Future<void>.delayed(bus.window + const Duration(milliseconds: 50));
    AppChanges.bump();
  }

  // ------------------------------------------------------------- internals --

  /// Runs a repository write and swallows the one refusal it can raise.
  ///
  /// `_assertMayContact` throws `StateError('not available')` for a woman on
  /// either side of a block. It is deliberately unnamed: nothing may render as
  /// "you are blocked", so nothing here turns it into a message.
  Future<void> _guarded(Future<void> Function() write) async {
    try {
      await write();
    } on StateError {
      // Not available. The screen already renders that state on its own.
    }
  }

  void _setMemberCount(String groupId, int count) {
    final at = store.groups.indexWhere((g) => g.groupId == groupId);
    if (at < 0) return;
    final g = store.groups[at];
    store.groups[at] = CommunityGroup(
      groupId: g.groupId,
      name: g.name,
      memberCount: count,
      blurb: g.blurb,
      topics: g.topics,
      postsToday: g.postsToday,
      joined: g.joined,
      mutedUntil: g.mutedUntil,
    );
  }

  void _record(ActivityKind kind, {required String postId, String? body}) {
    store.activity.add(
      ActivityItem(
        id: _mint('a'),
        kind: kind,
        at: DateTime.now(),
        actor: store.selfCard,
        postId: postId,
        commentBody: body,
      ),
    );
  }

  /// The counter Function's job, done here because this build has no Function.
  ///
  /// [CommunityPost] has no `copyWith` that moves a count — the client is not
  /// the writer of one — so the document is rewritten whole, which is exactly
  /// what the server does when it recomputes a count absolutely.
  void _replace(
    CommunityPost post, {
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
    bool? savedByMe,
  }) {
    final at = store.posts.indexWhere((p) => p.postId == post.postId);
    if (at < 0) return;
    store.posts[at] = CommunityPost(
      postId: post.postId,
      authorCard: post.authorCard,
      kind: post.kind,
      audienceKeys: post.audienceKeys,
      createdAt: post.createdAt,
      media: post.media,
      caption: post.caption,
      topics: post.topics,
      groupId: post.groupId,
      parentPostId: post.parentPostId,
      cost: post.cost,
      blurApplied: post.blurApplied,
      blurOptOut: post.blurOptOut,
      visibility: post.visibility,
      expiresAt: post.expiresAt,
      likeCount: likeCount ?? post.likeCount,
      commentCount: commentCount ?? post.commentCount,
      followUpCount: post.followUpCount,
      latestFollowUpAt: post.latestFollowUpAt,
      likedByMe: likedByMe ?? post.likedByMe,
      savedByMe: savedByMe ?? post.savedByMe,
      pendingUpload: post.pendingUpload,
      schemaV: post.schemaV,
    );
  }

  /// For tests. Empties the room she is in, so one journey cannot leak into the
  /// next.
  void reset() {
    bus.dispose();
    composeGroupId = null;
    followUpCaption = '';
    followUpCostOn = false;
    recordMode = null;
    safetyPostId = null;
    store.posts.clear();
    store.comments.clear();
    store.groups.clear();
    store.challenges.clear();
    store.profiles.clear();
    store.saved.clear();
    store.activity.clear();
    store.graph = FollowGraph();
    _ids = 0;
  }
}
