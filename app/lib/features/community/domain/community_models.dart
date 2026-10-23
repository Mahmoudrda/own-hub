/// The documents G10 owns, as Dart types.
///
/// Shapes come from `SCHEMA-SPINE.md` §8 and `G10-community.md` §1, and the caps
/// come from `firestore.rules` — they are `static const` here so a test can
/// compare the domain against the deployed rules rather than against a comment.
///
/// ## Three absences, each load-bearing
///
///   * **No streak field.** Not `postStreak`, not `postingStreak`, not
///     `daysPosted`, not `activeDays`. Rule 3 / spine C6, and `noStreak()` is
///     AND-ed into every G10 write server-side. `P1-COM-04` greps for it.
///   * **No weight, anywhere.** `FollowUpCost` carries two integers and there is
///     no field in any type here that a scale figure could live in. Rule 11.
///   * **No roster.** There is no `likedBy`, no `members` list and no
///     `followerList`. `likes` is `allow list: if false` except when constrained
///     to her own posts, and `members` is `allow list: if false` outright — a
///     group of 4,210 women is not a list to scrape.
///
/// ## Why `authorCard` is denormalised onto every post
///
/// `users/{uid}` is `allow get: if isSelf(uid)` — a viewer **cannot** read
/// another woman's user document, ever. Without this snapshot the feed would be
/// 10 posts plus 10 profile reads, and those reads would be refused anyway. So
/// the name and avatar ride along on the post. `G10` §2.4 lists it as a
/// requirement rather than an optimisation.
///
/// ## Counts are read-only to the client
///
/// `counts.likes` and `counts.comments` are written by a Cloud Function and are
/// `Admin SDK only` in the rules, because a client-writable count is forgeable.
/// They appear here as plain ints with no setter and no `copyWith` that moves
/// them, so nothing in the app can invent one.
library;

import 'package:meta/meta.dart';

import 'audience_keys.dart';
import 'blur_policy.dart';
import 'follow_up_policy.dart';
import 'follower_count.dart';

// ------------------------------------------------------------------- caps --

/// `media.size() <= 10` in the rules.
const int kMaxPostMedia = 10;

/// `caption.size() <= 2200`.
const int kMaxCaptionLength = 2200;

/// `topics.size() <= 5`, and they are an enum rather than free tags.
const int kMaxPostTopics = 5;

/// `body.size() <= 1000` on a comment.
const int kMaxCommentLength = 1000;

/// `followingKeys[<=300]` on `followGraph/{uid}`.
const int kMaxFollowingKeys = 300;

/// `groupKeys[<=10]`.
const int kMaxGroupKeys = 10;

/// `hiddenAuthors[<=200]`.
const int kMaxHiddenAuthors = 200;

/// A story lives 24 hours, expired by a Firestore TTL policy and not a sweeper.
const Duration kStoryLifetime = Duration(hours: 24);

// ------------------------------------------------------------------ enums --

/// `posts.kind`, exactly the spine's four values.
///
/// **A text post is [photo] with empty media.** That is not a workaround: the
/// spine's enum has four values and a caption-only post is the same document
/// with nothing in `media[]`. [CommunityPost.isTextOnly] is the predicate, so no
/// screen has to know that.
///
/// [reel] exists because the schema has it. Nothing in this build produces one —
/// `Feature.communityVideo` is off and there is no capture or export path in the
/// app at all. The value is here so the type can read a document written later,
/// not so something can write one now.
enum PostKind {
  photo('photo'),
  reel('reel'),
  story('story'),
  best('best');

  const PostKind(this.wireName);

  final String wireName;
}

/// `posts.visibility`. She owns the first two; a moderator owns the last two.
enum PostVisibility {
  live('live'),

  /// Hers. She hid her own post and can unhide it.
  authorHidden('author_hidden'),

  /// A moderator's, via the Admin SDK, on a report that hides on sight.
  hiddenPending('hidden_pending'),

  /// A moderator's. The document survives, because moderation needs evidence.
  removed('removed');

  const PostVisibility(this.wireName);

  final String wireName;

  /// The feed query filters on this, so hiding takes effect everywhere at once
  /// on the next page load — no fan-out and no purge.
  bool get isVisibleInFeed => this == PostVisibility.live;
}

/// M10's chips. An enum, never free tags — a free tag is a search surface and a
/// harassment vector nobody owns.
enum CommunityTopic {
  postpartum('postpartum'),
  quiet('quiet'),
  ramadan('ramadan'),
  beginner('beginner'),
  walking('walking');

  const CommunityTopic(this.wireName);

  final String wireName;
}

// ------------------------------------------------------------------ posts --

/// The name and face that ride along on every post and comment.
@immutable
class AuthorCard {
  const AuthorCard({
    required this.uid,
    required this.name,
    this.avatarRef,
    this.verified = true,
  });

  final String uid;
  final String name;

  /// A CDN reference, not bytes, and never a captured image. Null renders the
  /// initial, which is what `AppAvatar` already does everywhere else.
  final String? avatarRef;

  /// Every woman in the room is ID-verified; this is here because the card is a
  /// snapshot and a snapshot has to carry what it claims.
  final bool verified;

  @override
  bool operator ==(Object other) =>
      other is AuthorCard && other.uid == uid && other.name == name;

  @override
  int get hashCode => Object.hash(uid, name);
}

/// One object in `posts.media[]`.
@immutable
class PostMedia {
  const PostMedia({
    required this.mediaId,
    required this.url,
    required this.thumbUrl,
    required this.width,
    required this.height,
    this.durationMs,
    this.posterUrl,
  });

  /// The id the blur decision was recorded against.
  final String mediaId;

  /// A public, content-addressed, immutable CDN URL —
  /// `cdn/<postId>/<sha256>/<variant>`, `max-age=31536000, immutable`.
  ///
  /// Public rather than signed because a per-request signature collapses the
  /// edge cache the $0-egress line depends on. `OQ-3` records the honest limit:
  /// a public immutable URL is a capability URL.
  final String url;

  /// The 320w variant, produced **on device**, so there is no server
  /// image-transform bill.
  final String thumbUrl;

  final int width;
  final int height;

  /// Unused at launch: `Feature.communityVideo` is off and nothing here records
  /// video. Present so the type can read a document written after it is on.
  final int? durationMs;

  /// Likewise. A reel's poster frame.
  final String? posterUrl;
}

/// `posts/{postId}`.
///
/// Written **once**, to one document, whatever the author's follower count.
/// That is spine C9, and [audienceKeys] is the field that makes it work: at most
/// two entries, never a function of an audience size.
@immutable
class CommunityPost {
  CommunityPost({
    required this.postId,
    required this.authorCard,
    required this.kind,
    required this.audienceKeys,
    required this.createdAt,
    this.media = const <PostMedia>[],
    this.caption = '',
    this.topics = const <CommunityTopic>[],
    this.groupId,
    this.parentPostId,
    this.cost,
    this.blurApplied = true,
    this.blurOptOut,
    this.visibility = PostVisibility.live,
    this.expiresAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.followUpCount = 0,
    this.latestFollowUpAt,
    this.likedByMe = false,
    this.savedByMe = false,
    this.pendingUpload = false,
    this.schemaV = 1,
  }) {
    // The fake is strict where the rules are strict. A draft that would be
    // refused server-side must not be constructible here, or a screen passes
    // its tests and fails on a phone (PHASE1-QA-VERDICT's standing note).
    if (media.length > kMaxPostMedia) {
      throw ArgumentError.value(
        media.length,
        'media',
        'at most $kMaxPostMedia objects — the rules refuse more',
      );
    }
    if (caption.length > kMaxCaptionLength) {
      throw ArgumentError.value(
        caption.length,
        'caption',
        'at most $kMaxCaptionLength characters',
      );
    }
    if (topics.length > kMaxPostTopics) {
      throw ArgumentError.value(
        topics.length,
        'topics',
        'at most $kMaxPostTopics topics',
      );
    }
    if (kind == PostKind.story && expiresAt == null) {
      throw ArgumentError.value(
        expiresAt,
        'expiresAt',
        'a story expires 24 hours after it was created — the rules pin '
            'expiresAt to createdAt + 24h, and a story without one would never '
            'be collected by the TTL policy',
      );
    }
    if (kind != PostKind.story && expiresAt != null) {
      throw ArgumentError.value(expiresAt, 'expiresAt', 'only a story expires');
    }
    if (!blurApplied && blurOptOut == null) {
      throw ArgumentError.value(
        blurApplied,
        'blurApplied',
        'an unblurred post must carry a recorded opt-out (rule 6, spine C11)',
      );
    }
  }

  /// A client UUID minted **once** at compose (spine C1), so a retried publish
  /// targets the same document instead of making a second post.
  final String postId;

  final AuthorCard authorCard;

  String get authorUid => authorCard.uid;

  final PostKind kind;

  /// At most two keys. See [AudienceKeys].
  final AudienceKeys audienceKeys;

  final DateTime createdAt;
  final List<PostMedia> media;
  final String caption;
  final List<CommunityTopic> topics;
  final String? groupId;

  /// Set on a follow-up. A follow-up has no existence apart from its parent.
  final String? parentPostId;

  /// Two integers or nothing. See [FollowUpCost].
  final FollowUpCost? cost;

  final bool blurApplied;
  final BlurOptOut? blurOptOut;
  final PostVisibility visibility;

  /// Non-null only for a story.
  final DateTime? expiresAt;

  /// **Function-written.** The client never sets these; they are recomputed
  /// absolutely by a coalesced Cloud Task, which is why a lost update self-heals
  /// and a replay cannot double-count.
  final int likeCount;
  final int commentCount;
  final int followUpCount;
  final DateTime? latestFollowUpAt;

  /// Her own like, read from `posts/{id}/likes/{herUid}` — a point get, never a
  /// roster. There is no way to ask who *else* liked this.
  final bool likedByMe;

  /// From `users/{uid}/saved/{postId}`. Private by construction.
  final bool savedByMe;

  /// Composed offline and waiting for its media to upload. Renders in her own
  /// feed and profile at full opacity with the queued badge; no post document
  /// exists for anyone else yet (`P0-COM-12`).
  final bool pendingUpload;

  final int schemaV;

  /// A caption-only post. The launch scope is photos and text.
  bool get isTextOnly => media.isEmpty;

  /// A follow-up belongs to a parent and is never standalone.
  bool get isFollowUp => parentPostId != null;

  /// Whether a story has passed its TTL. The document is deleted by Firestore's
  /// TTL policy; this is what the rail uses so an expired story never draws
  /// while the deletion propagates (`P0-COM-15`).
  bool hasExpiredAt(DateTime now) {
    final expiry = expiresAt;
    return expiry != null && !now.isBefore(expiry);
  }

  /// Copies with the fields a *viewer's* own state changes. Deliberately narrow:
  /// there is no `copyWith` that can move `likeCount`, `authorCard` or
  /// `visibility`, because none of those is the client's to write.
  CommunityPost withViewerState({
    bool? likedByMe,
    bool? savedByMe,
    bool? pendingUpload,
  }) => CommunityPost(
    postId: postId,
    authorCard: authorCard,
    kind: kind,
    audienceKeys: audienceKeys,
    createdAt: createdAt,
    media: media,
    caption: caption,
    topics: topics,
    groupId: groupId,
    parentPostId: parentPostId,
    cost: cost,
    blurApplied: blurApplied,
    blurOptOut: blurOptOut,
    visibility: visibility,
    expiresAt: expiresAt,
    likeCount: likeCount,
    commentCount: commentCount,
    followUpCount: followUpCount,
    latestFollowUpAt: latestFollowUpAt,
    likedByMe: likedByMe ?? this.likedByMe,
    savedByMe: savedByMe ?? this.savedByMe,
    // Viewer state too, in the strict sense: a queued post is badged in
    // HER feed and does not exist at all in anyone else's.
    pendingUpload: pendingUpload ?? this.pendingUpload,
    schemaV: schemaV,
  );

  @override
  String toString() => 'CommunityPost($postId, ${kind.wireName})';
}

/// `posts/{postId}/comments/{commentId}`.
@immutable
class CommunityComment {
  CommunityComment({
    required this.commentId,
    required this.authorCard,
    required this.postAuthorUid,
    required this.body,
    required this.createdAt,
    this.isCoach = false,
    this.pendingSync = false,
  }) {
    if (body.length > kMaxCommentLength) {
      throw ArgumentError.value(
        body.length,
        'body',
        'at most $kMaxCommentLength characters',
      );
    }
  }

  /// Minted once from `DocIds` (spine C1), so an offline replay collides with
  /// itself rather than posting the comment twice.
  final String commentId;

  final AuthorCard authorCard;

  /// Denormalised so the rules can check `notBlockedBy(postAuthorUid)` on
  /// create, and so M14 can find "comments on my posts" with one constrained
  /// collection-group query and zero notification documents.
  final String postAuthorUid;

  final String body;
  final DateTime createdAt;

  /// M02 labels coaches inside comments so advice is attributable. Read from
  /// G11's relationships at render time, never copied onto the document.
  final bool isCoach;

  /// Written offline. Shows at full opacity with the queued glyph — never a
  /// spinner and never a failure message (`P0-COM-11`).
  final bool pendingSync;
}

// ----------------------------------------------------------------- groups --

/// `groups/{groupId}`. Curated content, joinable by any verified woman.
@immutable
class CommunityGroup {
  const CommunityGroup({
    required this.groupId,
    required this.name,
    required this.memberCount,
    this.blurb = '',
    this.topics = const <CommunityTopic>[],
    this.postsToday = 0,
    this.joined = false,
    this.mutedUntil,
  });

  final String groupId;
  final String name;

  /// Displayed, never ranked. The index exemption on `groups.memberCount` is
  /// what makes "order groups by size" unexecutable in the deployed project;
  /// this is just an int, and there is no comparator on it here.
  final int memberCount;

  final String blurb;
  final List<CommunityTopic> topics;
  final int postsToday;
  final bool joined;

  /// M08's "mute for a week". Still a member — her posts still count for the
  /// challenge — but the group's posts drop out of her feed until this lapses.
  final DateTime? mutedUntil;

  bool isMutedAt(DateTime now) {
    final until = mutedUntil;
    return until != null && now.isBefore(until);
  }
}

/// `groups/{gid}/challenges/{cid}` — a shared total, never a leaderboard.
///
/// Everyone who does her part finishes. There is no last place, and nothing here
/// compares one woman's contribution with another's: [womenFinished] is a count
/// of women who are done, not an ordering of them.
@immutable
class GroupChallenge {
  const GroupChallenge({
    required this.challengeId,
    required this.groupId,
    required this.target,
    required this.total,
    required this.perWoman,
    required this.endsAt,
    this.womenFinished = 0,
    this.womenTaking = 0,
    this.myDone = 0,
  });

  final String challengeId;
  final String groupId;

  /// "200 sessions together" — the shared goal.
  final int target;

  /// What the group has done so far. Function-written, sharded above 1,000
  /// members so a join storm cannot make one document hot.
  final int total;

  /// What one woman's part is. Four sessions, say.
  final int perWoman;

  final DateTime endsAt;
  final int womenFinished;
  final int womenTaking;

  /// Her own part. Credited from session completions — "there is nothing extra
  /// to log", and it stores that a session happened, never a weight.
  final int myDone;

  /// 0..1, for the bar. Clamped, because a group that overshoots its target is
  /// a success and not a layout bug.
  double get fraction => target == 0 ? 0 : (total / target).clamp(0.0, 1.0);

  bool get myPartDone => myDone >= perWoman;

  int daysLeftFrom(DateTime now) {
    final days = endsAt.difference(now).inDays;
    return days < 0 ? 0 : days;
  }
}

// --------------------------------------------------------------- profiles --

/// `publicProfiles/{uid}` — **only** women whose `privacy.profileVisible` is on.
///
/// The projection Function *deletes* the document when she turns it off, which
/// is what makes `allow list` safe for Explore: rules cannot inspect a `where`
/// clause, so a non-discoverable woman must not be in the collection at all.
///
/// Her absence therefore renders the ordinary not-available state — the same one
/// a blocked surface renders, by design, so the two are indistinguishable.
@immutable
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.name,
    this.bio = '',
    this.avatarRef,
    this.verified = true,
    this.joinedMonth,
    this.postCount = 0,
    this.followerCount,
    this.followingCount,
    this.storyUntil,
  });

  final String uid;
  final String name;
  final String bio;
  final String? avatarRef;
  final bool verified;

  /// "joined March". A month, never a precise join date.
  final String? joinedMonth;

  final int postCount;

  /// Null when it has not been read. Hidden at launch in any case —
  /// `Feature.communityFollowerCounts` is off, and the type cannot be ranked
  /// whether it is shown or not.
  final FollowerCount? followerCount;
  final FollowerCount? followingCount;

  /// Set while she has a live story, so her avatar draws a ring.
  final DateTime? storyUntil;
}

/// `users/{uid}/saved/{postId}` — private, and denormalised so the grid costs
/// no post reads.
@immutable
class SavedPost {
  const SavedPost({
    required this.postId,
    required this.kind,
    required this.authorUid,
    required this.savedAt,
    this.thumbUrl,
  });

  /// **Also the document id**, so saving twice converges on one document.
  final String postId;

  final PostKind kind;
  final String authorUid;
  final DateTime savedAt;

  /// Denormalised. Null once the post is deleted, which is what makes M15 show
  /// the not-available tile rather than a broken image (`P0-COM-18`).
  final String? thumbUrl;

  bool get isStillAvailable => thumbUrl != null;
}

/// `followGraph/{uid}` — the reader's own key set.
///
/// Written when **she** follows or joins: O(1) per her own action, never per her
/// audience. This is the document whose existence makes fan-out-on-write
/// unnecessary.
@immutable
class FollowGraph {
  FollowGraph({
    this.followingKeys = const <String>[],
    this.groupKeys = const <String>[],
    this.hiddenAuthors = const <String>[],
    this.updatedAt,
  }) {
    if (followingKeys.length > kMaxFollowingKeys) {
      throw ArgumentError.value(followingKeys.length, 'followingKeys');
    }
    if (groupKeys.length > kMaxGroupKeys) {
      throw ArgumentError.value(groupKeys.length, 'groupKeys');
    }
    if (hiddenAuthors.length > kMaxHiddenAuthors) {
      throw ArgumentError.value(hiddenAuthors.length, 'hiddenAuthors');
    }
  }

  /// `a:{uid}` for each woman she follows.
  final List<String> followingKeys;

  /// `g:{groupId}` for each group she is in and has not muted.
  final List<String> groupKeys;

  /// Blocks in **both** directions, Function-maintained.
  ///
  /// **Never surfaced in any UI**, which is what keeps "she cannot learn she was
  /// blocked" true through the product. A screen that rendered this list would
  /// tell a woman who had blocked her. There is deliberately no view model in
  /// this feature that reads it for display — only the feed filter does.
  final List<String> hiddenAuthors;

  final DateTime? updatedAt;

  /// Everything the feed query pages over. Order is insertion order, which is
  /// not a ranking: the posts are merged by `createdAt` afterwards.
  List<String> get audienceKeys => <String>[...followingKeys, ...groupKeys];

  bool get isEmpty => followingKeys.isEmpty && groupKeys.isEmpty;

  bool hides(String authorUid) => hiddenAuthors.contains(authorUid);
}

// --------------------------------------------------------------- activity --

/// What M14 renders. Assembled from three constrained reads at open, which is
/// why Activity costs **zero writes**.
///
/// The obvious build writes a notification document per like — a write on the
/// hottest path in the product, and the fan-out mistake wearing a different hat.
enum ActivityKind { liked, commented, followed, groupMilestone, followUpPrompt }

@immutable
class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.at,
    this.actor,
    this.postId,
    this.thumbUrl,
    this.groupId,
    this.commentBody,
    this.followsMe = false,
  });

  final String id;
  final ActivityKind kind;
  final DateTime at;

  /// The woman who did it. Null for a group milestone and for the prompt —
  /// "every line is a woman who did something, or a thing you can act on".
  final AuthorCard? actor;

  final String? postId;
  final String? thumbUrl;
  final String? groupId;
  final String? commentBody;

  /// Whether she already follows back, so the row offers the right action.
  final bool followsMe;
}
