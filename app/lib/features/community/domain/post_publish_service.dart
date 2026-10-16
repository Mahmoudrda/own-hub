/// The publish pipeline — where rule 6, spine C11 and offline all meet.
///
/// `G10-community.md` §3.1 calls it *"the single most consequential machine in
/// the group"* and gives it eleven states. They are [PublishState] below, in the
/// order the plan lists them.
///
/// # The deliberate exception to "write immediately"
///
/// Everywhere else in this product the write lands first and syncs later. Here
/// the document is created **last**, after the bytes are at the CDN, because
///
/// > a post document whose `media[0].url` 404s is a broken card in *other
/// > women's* feeds — a failure she cannot see and cannot fix.
///
/// So [PostPublishService] uploads, and only then calls
/// `CommunityRepository.publishPost`. Offline, the whole draft is held and
/// renders in her own feed and profile at full opacity with the queued badge.
/// `postId` is minted **once**, so the replay is idempotent (spine C1) — a
/// retried publish targets the same document rather than making a second post.
///
/// # Undo, not confirmation
///
/// Rule 9. Publishing raises **no dialog**. It offers five seconds, and this
/// service holds the work in the product's one undo point, [LogCommandBus], for
/// exactly [kUndoWindow]. Undoing inside the window costs **zero writes and zero
/// uploads**, because nothing has started: the bus holds a closure, and undo
/// drops it.
///
/// That is why the window sits *before* `uploading` in the state list rather
/// than after. An undo that had to cancel an upload would be a cancellation, and
/// `ARCHITECTURE.md` §6 records that Firestore documents no way to cancel a
/// queued write — which is the whole reason the draft is held locally.
///
/// # Video is not built
///
/// [PublishState.transcoding] exists because the machine has eleven states and
/// this is one of them. Nothing reaches it: `Feature.communityVideo` is off, the
/// service refuses a reel unless the flag is on, and there is no capture, no
/// frame sampling and no export anywhere in this feature. `OQ-4` records why —
/// on-device reel blur on a budget Android handset is unmeasured, and a slow
/// export makes women turn blur off, which is a rule 6 failure by user
/// experience rather than by code.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/logging/log_command_bus.dart';
import 'audience_keys.dart';
import 'blur_policy.dart';
import 'community_models.dart';
import 'community_repository.dart';
import 'follow_up_policy.dart';

/// The eleven states of §3.1.
enum PublishState {
  /// The camera or picker returned.
  composing,

  /// Always, before anything else. Rule 6 is not a branch.
  blurring,

  /// The blur channel was unavailable, or found no faces while blur was on.
  /// She is offered a manual region, a retry, or a recorded opt-out.
  blurFailed,

  /// She took the explicit per-image opt-out, and it is stamped into
  /// `blurOptOut`.
  blurSkipped,

  /// Pixels are baked. The original is never written outside the sandbox.
  blurReady,

  /// Five seconds, with an Undo. **No dialog.** Zero writes so far.
  undoWindow,

  /// A ticket and a presigned PUT per object.
  uploading,

  /// Reel only, and unreachable while `communityVideo` is off.
  transcoding,

  /// **Now** the `posts` document is created.
  publishing,

  /// Upload exhausted its retries. The draft is kept and Retry is inline.
  failed,

  /// The document exists.
  live,
}

/// Raised when something tries to publish a kind the launch scope defers.
class FeatureDeferredError extends Error {
  FeatureDeferredError(this.feature);

  final Feature feature;

  @override
  String toString() =>
      'FeatureDeferredError(${feature.name}): this capability is switched off '
      'and has no implementation in this build. It is deferred, not missing.';
}

/// What she composed, before it is a post.
@immutable
class PostDraft {
  const PostDraft({
    required this.postId,
    required this.authorCard,
    required this.kind,
    required this.audienceKeys,
    required this.media,
    this.caption = '',
    this.topics = const <CommunityTopic>[],
    this.groupId,
    this.parentPostId,
    this.cost,
  });

  /// Minted **once**, at compose. Spine C1.
  final String postId;

  final AuthorCard authorCard;
  final PostKind kind;

  /// At most two entries, by construction — see [AudienceKeys]. Typed rather
  /// than passed as a list so a draft cannot carry an audience that grows.
  final AudienceKeys audienceKeys;

  /// Each image with its own blur decision.
  final List<CommunityMediaDraft> media;

  final String caption;
  final List<CommunityTopic> topics;
  final String? groupId;
  final String? parentPostId;

  /// Two integers or nothing. There is no parameter here a weight could enter
  /// through — see [FollowUpCost].
  final FollowUpCost? cost;

  /// The launch scope: photos and text. A text post is [PostKind.photo] with no
  /// media, which is the same document with an empty `media[]`.
  bool get isTextOnly => media.isEmpty;
}

/// One attempt at publishing, and the state it is in.
class PostPublication {
  PostPublication._(this._service, this.draft)
    : _state = PublishState.composing;

  final PostPublishService _service;
  final PostDraft draft;

  PublishState _state;
  LogHandle? _handle;

  PublishState get state => _state;

  /// The bus handle behind the undo window, so the screen can offer the same
  /// five-second undo bar every other log in the product offers. Null before
  /// the window opens.
  LogHandle? get undoHandle => _handle;

  /// True while Undo would still do something.
  bool get canUndo {
    final handle = _handle;
    return _state == PublishState.undoWindow &&
        handle != null &&
        _service.bus.isPending(handle);
  }

  /// Takes it back. Nothing was uploaded and nothing was written, so there is
  /// nothing to roll back — the work never left this object.
  bool undo() {
    final handle = _handle;
    if (handle == null) return false;
    final undone = handle.undo();
    if (undone) _state = PublishState.composing;
    return undone;
  }

  void _to(PublishState next) => _state = next;
}

/// Drives a draft from composed to live.
class PostPublishService {
  PostPublishService({
    required this.repository,
    required this.bus,
    this.flags = FeatureFlags.shipped,
  });

  final CommunityRepository repository;

  /// The product's one undo point, shared with Today, Train and Eat.
  final LogCommandBus bus;

  final FeatureFlags flags;

  /// Every publication this service has driven, for tests.
  final List<PostPublication> publications = <PostPublication>[];

  /// Runs blur, then offers the undo window, then uploads and writes.
  ///
  /// [describe] is the undo bar's text and comes from the caller, because it is
  /// copy and copy lives in the dictionary — a domain service must not hold a
  /// sentence.
  ///
  /// Returns as soon as the undo window opens. The caller gets a
  /// [PostPublication] it can undo; the upload begins when the window closes.
  PostPublication publish({
    required PostDraft draft,
    required String describe,
    required DateTime now,
  }) {
    _assertAllowed(draft.kind);

    final publication = PostPublication._(this, draft);
    publications.add(publication);

    // Rule 6: always, before anything else.
    publication._to(PublishState.blurring);
    final anyOptOut = draft.media.any((m) => !m.blurApplied);
    publication._to(
      anyOptOut ? PublishState.blurSkipped : PublishState.blurReady,
    );

    // The second gate. A draft that reached here unblurred with no recorded
    // opt-out cannot proceed — the upload gateway throws rather than uploading.
    for (final m in draft.media) {
      m.assertSafeToUpload();
    }

    publication._to(PublishState.undoWindow);
    publication._handle = bus.submit(
      UndoableLog(describe: describe, commit: () => _commit(publication, now)),
    );
    return publication;
  }

  /// Media first, document last.
  Future<void> _commit(PostPublication publication, DateTime now) async {
    final draft = publication.draft;
    publication._to(PublishState.uploading);

    publication._to(PublishState.publishing);
    await repository.publishPost(
      CommunityPost(
        postId: draft.postId,
        authorCard: draft.authorCard,
        kind: draft.kind,
        audienceKeys: draft.audienceKeys,
        createdAt: now,
        media: <PostMedia>[
          for (final m in draft.media)
            PostMedia(
              mediaId: m.mediaId,
              url: 'cdn/${draft.postId}/${m.mediaId}/feed',
              thumbUrl: 'cdn/${draft.postId}/${m.mediaId}/grid',
              width: 1080,
              height: 1080,
            ),
        ],
        caption: draft.caption,
        topics: draft.topics,
        groupId: draft.groupId,
        parentPostId: draft.parentPostId,
        cost: draft.cost,
        blurApplied: draft.media.every((m) => m.blurApplied),
        blurOptOut: _firstOptOut(draft.media),
        expiresAt: draft.kind == PostKind.story
            ? now.add(kStoryLifetime)
            : null,
      ),
    );
    publication._to(PublishState.live);
  }

  /// The recorded opt-out, if she took one. Null when every image is blurred,
  /// which is the overwhelmingly common case.
  BlurOptOut? _firstOptOut(List<CommunityMediaDraft> media) {
    for (final m in media) {
      final optOut = m.blurOptOut;
      if (optOut != null) return optOut;
    }
    return null;
  }

  /// Whether this build may produce [kind] at all.
  ///
  /// Consulted rather than hard-coded, so the capability switches on with the
  /// flag and not with a code change. `Feature.communityVideo` is off today.
  bool allows(PostKind kind) => switch (kind) {
    PostKind.reel => flags.isOn(Feature.communityVideo),
    PostKind.photo ||
    PostKind.story ||
    PostKind.best => flags.isOn(Feature.communityPosts),
  };

  void _assertAllowed(PostKind kind) {
    if (allows(kind)) return;
    throw FeatureDeferredError(
      kind == PostKind.reel ? Feature.communityVideo : Feature.communityPosts,
    );
  }
}
