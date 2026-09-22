/// What M01, M02, M08 and M13 draw — computed without a widget in sight.
///
/// `ARCHITECTURE.md` §1: *"A view model may not restate a rule, and a widget may
/// never contain one."* So nothing here decides anything. The tab's rendering
/// comes from [CommunityTabState], the follow button from [FollowStateResolver],
/// what a report may claim from [CommunityReportCopy]. This file only
/// *arranges* those answers, which is why every screen below is testable
/// without pumping a frame.
///
/// ## Counts are her real figures, never the prototype's
///
/// Every number on these screens — likes, comments, members — arrives as an
/// `int` from a document and is rendered through `countLabel`. None of them is
/// a dictionary string. That is not a style preference: the dictionary carries
/// the mockup's figures baked into sentences (`seeAll27Comments`,
/// `posted8WeeksAgo96Likes`, `n4210Women38PostsToday`), and rendering one of
/// those states the prototype's number as a fact about a real post.
/// `test/baked_in_samples_test.dart` counts exactly that defect and its ceiling
/// is already at its limit, so this feature adds none.
///
/// ## Follower counts are absent, not hidden
///
/// There is no follower figure anywhere in this file. `Feature.communityFollowerCounts`
/// is off, and `FollowerCount` cannot be ranked whether it is shown or not.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../../account/domain/safety.dart';
import '../domain/community_models.dart';
import '../domain/community_repository.dart';
import '../domain/community_tab_state.dart';
import '../domain/follow_state.dart';
import '../domain/report_copy.dart';

/// One post card, on the feed or on M02.
@immutable
class PostCardModel {
  const PostCardModel({
    required this.postId,
    required this.authorUid,
    required this.authorName,
    required this.likeCount,
    required this.commentCount,
    this.avatarRef,
    this.verified = true,
    this.caption = '',
    this.groupName,
    this.hasMedia = false,
    this.blurred = true,
    this.likedByMe = false,
    this.savedByMe = false,
    this.pendingUpload = false,
    this.followState = FollowState.notFollowing,
    this.isMine = false,
  });

  factory PostCardModel.from(
    CommunityPost post, {
    required String viewerUid,
    String? groupName,
    bool isFollowingAuthor = false,
    bool hiddenEitherWay = false,
    FollowStateResolver resolver = const FollowStateResolver(),
  }) => PostCardModel(
    postId: post.postId,
    authorUid: post.authorUid,
    authorName: post.authorCard.name,
    avatarRef: post.authorCard.avatarRef,
    verified: post.authorCard.verified,
    caption: post.caption,
    groupName: groupName,
    hasMedia: post.media.isNotEmpty,
    blurred: post.blurApplied,
    likeCount: post.likeCount,
    commentCount: post.commentCount,
    likedByMe: post.likedByMe,
    savedByMe: post.savedByMe,
    pendingUpload: post.pendingUpload,
    isMine: post.authorUid == viewerUid,
    followState: resolver.resolve(
      viewerUid: viewerUid,
      otherUid: post.authorUid,
      isFollowing: isFollowingAuthor,
      hiddenEitherWay: hiddenEitherWay,
    ),
  );

  final String postId;
  final String authorUid;
  final String authorName;
  final String? avatarRef;
  final bool verified;
  final String caption;

  /// The group a post was published into, already resolved to its name.
  final String? groupName;

  final bool hasMedia;

  /// Whether faces in the image are blurred. Almost always true.
  final bool blurred;

  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool savedByMe;

  /// Composed offline. Renders at **full opacity** with the queued glyph —
  /// never dimmed, never a spinner, never "failed to save".
  final bool pendingUpload;

  final FollowState followState;
  final bool isMine;

  /// Her figures, in Western digits in both languages.
  String get likeLabel => countLabel(likeCount);
  String get commentLabel => countLabel(commentCount);

  /// A caption-only post — the other half of the launch scope.
  bool get isTextOnly => !hasMedia;

  /// The follow button is offered only where it means something.
  bool get showsFollowButton =>
      followState == FollowState.notFollowing ||
      followState == FollowState.pendingLocal;

  /// **Always false.** Follower counts are off at launch, and nothing on a feed
  /// card would be an appropriate place for one even when they are on.
  bool get showsFollowerCount => false;
}

/// One ring on the stories rail.
@immutable
class StoryRingModel {
  const StoryRingModel({
    required this.postId,
    required this.authorName,
    this.isMine = false,
    this.seen = false,
    this.expiringSoon = false,
  });

  final String postId;
  final String authorName;

  /// "Your day" — hers is first.
  final bool isMine;

  /// Seen state is **local sqflite**, zero writes.
  final bool seen;

  /// Under an hour left, so the ring dims (§3.3).
  final bool expiringSoon;
}

/// M01, including its day-one branch (M17) — which is a state, not a route.
@immutable
class FeedScreenModel {
  const FeedScreenModel({
    required this.state,
    required this.posts,
    required this.rail,
    required this.suggestedGroups,
  });

  /// Builds the whole tab from what was read.
  ///
  /// Pure: the same inputs always produce the same screen, and there is no
  /// clock, no listener and no repository among the parameters.
  factory FeedScreenModel.from({
    required FollowGraph graph,
    required FeedPage page,
    required String viewerUid,
    required DateTime now,
    List<CommunityPost> stories = const <CommunityPost>[],
    List<CommunityGroup> suggestedGroups = const <CommunityGroup>[],
    Map<String, String> groupNames = const <String, String>{},
    bool online = true,
    bool hasCachedPage = false,
  }) {
    final state = CommunityTabState.resolve(
      followingKeyCount: graph.followingKeys.length,
      groupKeyCount: graph.groupKeys.length,
      firstPagePostCount: page.posts.length,
      online: online,
      hasCachedPage: hasCachedPage,
    );

    final following = graph.followingKeys.toSet();

    return FeedScreenModel(
      state: state,
      posts: <PostCardModel>[
        for (final p in page.posts)
          PostCardModel.from(
            p,
            viewerUid: viewerUid,
            groupName: p.groupId == null ? null : groupNames[p.groupId],
            isFollowingAuthor: following.contains('a:${p.authorUid}'),
          ),
      ],
      rail: <StoryRingModel>[
        for (final s in stories)
          StoryRingModel(
            postId: s.postId,
            authorName: s.authorCard.name,
            isMine: s.authorUid == viewerUid,
            expiringSoon:
                s.expiresAt != null &&
                s.expiresAt!.difference(now) < const Duration(hours: 1),
          ),
      ]..sort((a, b) => a.isMine == b.isMine ? 0 : (a.isMine ? -1 : 1)),
      // Only day one offers groups: it is the one state whose smallest action
      // is "join one", and HANDOFF 17 says an empty state gets exactly one.
      suggestedGroups: state == CommunityTabState.dayOne
          ? suggestedGroups.take(3).toList()
          : const <CommunityGroup>[],
    );
  }

  final CommunityTabState state;
  final List<PostCardModel> posts;
  final List<StoryRingModel> rail;

  /// The three groups M17 offers. Empty in every other state.
  final List<CommunityGroup> suggestedGroups;

  /// M17 renders inside the Community route, as a branch of this screen.
  bool get showsDayOne => state == CommunityTabState.dayOne;

  /// Joined, but nobody has posted yet — a different message and a different
  /// smallest action.
  bool get showsJoinedButSilent => state == CommunityTabState.joinedOnly;

  bool get showsOfflineCold => state == CommunityTabState.offlineCold;

  bool get showsRail => state == CommunityTabState.ready && rail.isNotEmpty;
}

/// One comment on M02.
@immutable
class CommentModel {
  const CommentModel({
    required this.commentId,
    required this.authorName,
    required this.body,
    this.isCoach = false,
    this.pendingSync = false,
  });

  final String commentId;
  final String authorName;
  final String body;

  /// Coaches are labelled inside comments so advice is attributable (G11).
  final bool isCoach;

  /// Written offline. Full opacity, queued glyph.
  final bool pendingSync;
}

/// M02 — a post and its comments.
@immutable
class PostThreadModel {
  const PostThreadModel({
    required this.availability,
    required this.comments,
    this.post,
    this.offersVoiceNote = false,
  });

  factory PostThreadModel.from({
    required CommunityPost? post,
    required String viewerUid,
    List<CommunityComment> comments = const <CommunityComment>[],
    bool hiddenEitherWay = false,
    String? groupName,
    FeatureFlags flags = FeatureFlags.shipped,
    FollowStateResolver resolver = const FollowStateResolver(),
  }) {
    final availability = resolver.surfaceFor(
      profileExists: post != null,
      hiddenEitherWay: hiddenEitherWay,
    );
    if (!availability.isAvailable || post == null) {
      // The ordinary not-available rendering — identical whether the post was
      // deleted, hidden, or she was blocked. The caller cannot tell, and
      // neither can the screen.
      return const PostThreadModel(
        availability: SurfaceAvailability.notAvailable,
        comments: <CommentModel>[],
      );
    }

    return PostThreadModel(
      availability: availability,
      post: PostCardModel.from(
        post,
        viewerUid: viewerUid,
        groupName: groupName,
      ),
      comments: <CommentModel>[
        for (final c in comments)
          CommentModel(
            commentId: c.commentId,
            authorName: c.authorCard.name,
            body: c.body,
            isCoach: c.isCoach,
            pendingSync: c.pendingSync,
          ),
      ],
      // The prototype's composer offers a voice note first. It is deferred —
      // a whole content type with no moderation story is a safety gap, not a
      // missing feature (OQ-8) — so the row is flag-gated rather than deleted.
      offersVoiceNote: flags.isOn(Feature.communityVoiceNotes),
    );
  }

  final SurfaceAvailability availability;
  final PostCardModel? post;
  final List<CommentModel> comments;
  final bool offersVoiceNote;

  bool get isAvailable => availability.isAvailable && post != null;

  /// There is deliberately no "who liked this" here, and no method that could
  /// produce one: `likes` is `allow list: if false` in the rules.
  bool get showsLikeRoster => false;
}

/// What M08 offers.
enum SafetyAction {
  /// A woman moderator reads it. The one-hour promise is G7's and is only true
  /// once it has actually been sent.
  report,

  /// Instant, offline, and invisible to the woman blocked.
  block,

  /// Still a member, just quiet.
  muteGroup,
}

/// M08 — the report / block / mute sheet.
@immutable
class SafetySheetModel {
  const SafetySheetModel({
    required this.actions,
    required this.reportCopy,
    this.subjectName = '',
  });

  factory SafetySheetModel.from({
    required String subjectName,
    bool inGroup = false,
    bool isSelf = false,
    Report? existingReport,
  }) => SafetySheetModel(
    subjectName: subjectName,
    actions: <SafetyAction>[
      // Reporting herself is refused by the rules, so it is not offered; her
      // own post gets "delete" instead, which the sheet adds on its own.
      if (!isSelf) SafetyAction.report,
      // A room is not a woman: blocking a group id would put a group in her
      // blocked list, where only women belong.
      if (!isSelf && !inGroup) SafetyAction.block,
      if (inGroup) SafetyAction.muteGroup,
    ],
    reportCopy: existingReport == null
        ? null
        : CommunityReportCopy.stateFor(existingReport),
  );

  final List<SafetyAction> actions;
  final String subjectName;

  /// Null until she has actually filed one.
  final ReportCopyState? reportCopy;

  /// Whether the sheet may say a moderator is reading it.
  ///
  /// False for a queued report, always. The sentence the queued state needs is
  /// **absent from the dictionary**, so the screen renders nothing there rather
  /// than inventing English — see [CommunityReportCopy].
  bool get mayPromiseAnHour => reportCopy == ReportCopyState.sentHourStarted;

  /// Blocking and deleting are the documented exemption to "undo, not
  /// confirmation" — G10 §5 restates it so QA does not read a confirm as a
  /// violation.
  ///
  /// It is a **second step in this sheet**, never a Material dialog.
  /// `product_rules_test.dart` forbids `showDialog` and `AlertDialog` anywhere
  /// under `lib/features/`, and that guard is right: a dialog is the shape
  /// rule 9 is about. A two-step sheet gives the same deliberateness without
  /// the banned widget.
  bool get blockTakesASecondStep => true;

  /// Like, save, follow and publish raise nothing at all.
  bool get likeConfirms => false;
  bool get saveConfirms => false;
  bool get followConfirms => false;
  bool get publishConfirms => false;
}

/// One frame in the M13 viewer — one of a woman's live stories.
@immutable
class StoryFrameModel {
  const StoryFrameModel({
    required this.postId,
    this.blurred = true,
    this.expiringSoon = false,
    this.seen = false,
  });

  final String postId;

  /// Faces in it are blurred. Almost always true, and never assumed: it is the
  /// post's own `blurApplied`.
  final bool blurred;

  /// Under an hour left (§3.3). The ring dims on M01; here the segment does.
  final bool expiringSoon;

  /// **Local sqflite, zero writes.** Seen state never leaves the phone, which
  /// is why opening a story costs nothing and why nobody can be told who
  /// watched hers.
  final bool seen;
}

/// M13 — the stories viewer. One woman, in order, for twenty-four hours.
///
/// ## Two women cannot appear here either
///
/// The viewer is opened on one ring and keeps only the frames whose author is
/// the woman that ring belongs to, so a session is always one woman's day. That
/// is the same restraint M12 enforces through `FollowUpChain`, applied to the
/// one other surface that shows several pictures in a row.
///
/// ## An expired story is the ordinary not-available
///
/// `P0-COM-15`: a story is gone from the rail and from the feed once its TTL
/// passes. If it expires between the rail being drawn and the ring being
/// tapped, the viewer resolves to [SurfaceAvailability.notAvailable] — the same
/// rendering a blocked woman, a hidden profile and a deleted post produce. The
/// screen cannot tell them apart, and neither can she.
@immutable
class StoryViewerModel {
  const StoryViewerModel({
    required this.availability,
    required this.frames,
    required this.index,
    this.authorUid = '',
    this.authorName = '',
    this.verified = true,
    this.isMine = false,
    this.offersVideo = false,
    this.mediaAvailable = true,
  });

  /// Pure: the same inputs always produce the same screen. No clock of its own
  /// and no repository — `now` arrives as an argument so the TTL boundary is
  /// testable rather than a race.
  factory StoryViewerModel.from({
    required List<CommunityPost> stories,
    required String viewerUid,
    required DateTime now,
    String? openPostId,
    bool hiddenEitherWay = false,
    bool online = true,
    Set<String> seen = const <String>{},
    FeatureFlags flags = FeatureFlags.shipped,
    FollowStateResolver resolver = const FollowStateResolver(),
  }) {
    // Live stories only, oldest first. That is chronology, not a ranking:
    // there is no comparator here on likes, followers or anything else.
    final live = <CommunityPost>[
      for (final s in stories)
        if (s.kind == PostKind.story && !s.hasExpiredAt(now)) s,
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final availability = resolver.surfaceFor(
      profileExists: live.isNotEmpty,
      hiddenEitherWay: hiddenEitherWay,
    );
    if (!availability.isAvailable) {
      return const StoryViewerModel(
        availability: SurfaceAvailability.notAvailable,
        frames: <StoryFrameModel>[],
        index: 0,
      );
    }

    final opened = live.firstWhere(
      (s) => s.postId == openPostId,
      orElse: () => live.first,
    );
    // One woman's day. A second author has nowhere to go.
    final hers = <CommunityPost>[
      for (final s in live)
        if (s.authorUid == opened.authorUid) s,
    ];

    return StoryViewerModel(
      availability: availability,
      authorUid: opened.authorUid,
      authorName: opened.authorCard.name,
      verified: opened.authorCard.verified,
      isMine: opened.authorUid == viewerUid,
      index: hers.indexWhere((s) => s.postId == opened.postId),
      frames: <StoryFrameModel>[
        for (final s in hers)
          StoryFrameModel(
            postId: s.postId,
            blurred: s.blurApplied,
            expiringSoon:
                s.expiresAt != null &&
                s.expiresAt!.difference(now) < const Duration(hours: 1),
            seen: seen.contains(s.postId),
          ),
      ],
      // Asked, not assumed. A story may be a clip once video exists; until
      // then no playback affordance is offered anywhere.
      offersVideo: flags.isOn(Feature.communityVideo),
      // Community media is never cached for offline — it is other women's
      // bodies. Offline there is nothing to draw, and the screen says so.
      mediaAvailable: online,
    );
  }

  final SurfaceAvailability availability;
  final List<StoryFrameModel> frames;

  /// Which frame is on screen.
  final int index;

  /// One author, always. There is no second.
  final String authorUid;
  final String authorName;
  final bool verified;

  /// Hers. The reply bar is not offered on her own day.
  final bool isMine;

  /// False while `communityVideo` is off.
  final bool offersVideo;

  final bool mediaAvailable;

  bool get isAvailable => availability.isAvailable && frames.isNotEmpty;

  /// How many segments the progress strip draws.
  int get total => frames.length;

  StoryFrameModel? get current =>
      index >= 0 && index < frames.length ? frames[index] : null;

  /// A reply goes to her privately, so encouragement does not have to be
  /// performed in front of a group. Not offered on her own story.
  bool get offersReply => isAvailable && !isMine;

  /// **Always false.** Follower counts are off, and a story overlay would not
  /// be a place for one even when they are on.
  bool get showsFollowerCount => false;

  /// There is no "who watched this". Seen state is local to each phone, so no
  /// viewer roster exists to render.
  bool get showsViewerRoster => false;
}
