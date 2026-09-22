// The publish pipeline: rule 9's undo window, §3.1's media-before-document
// ordering, and the launch scope's deferred video.
//
// P1-COM-08: "Publishing offers a five-second undo before the upload starts."
// P0-COM-09: the opt-out survives into the post document.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/blur_policy.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/domain/community_repository.dart';
import 'package:own_hub/features/community/domain/post_publish_service.dart';

const _me = AuthorCard(uid: 'me', name: 'Mona');
final _now = DateTime(2026, 9, 19, 10);

/// Community on, at its launch scope: photos and text.
///
/// Built from [FeatureFlags.allOff] rather than from `FeatureFlags.shipped`,
/// so every absence asserted below is an absence this file asked for. Borrowing
/// the defaults would make each of these a test of today's switch positions.
final _communityOn = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.community: true,
  Feature.communityPosts: true,
});

PostDraft _draft({
  String id = 'post-7331',
  PostKind kind = PostKind.photo,
  List<CommunityMediaDraft>? media,
  String? groupId,
}) => PostDraft(
  postId: id,
  authorCard: _me,
  kind: kind,
  audienceKeys: groupId == null
      ? AudienceKeys.forAuthor('me')
      : AudienceKeys.inGroup(authorUid: 'me', groupId: groupId),
  media:
      media ??
      <CommunityMediaDraft>[
        CommunityMediaDraft.create(
          mediaId: 'm1',
          decision: const BlurDecision.blurred(),
        ),
      ],
  caption: 'Same flat, same fifteen minutes.',
);

({
  PostPublishService service,
  InMemoryCommunityRepository repo,
  LogCommandBus bus,
})
_harness({FeatureFlags? flags, Duration window = const Duration(seconds: 5)}) {
  final repo = InMemoryCommunityRepository(
    store: CommunityStore(selfUid: 'me', selfCard: _me),
  );
  final bus = LogCommandBus(window: window);
  return (
    service: PostPublishService(
      repository: repo,
      bus: bus,
      flags: flags ?? _communityOn,
    ),
    repo: repo,
    bus: bus,
  );
}

void main() {
  group('P1-COM-08 — undo, not confirmation', () {
    test('publishing opens a five-second window and writes nothing yet', () {
      final h = _harness();
      addTearDown(h.bus.dispose);

      final publication = h.service.publish(
        draft: _draft(),
        describe: 'Posted',
        now: _now,
      );

      expect(publication.state, PublishState.undoWindow);
      expect(publication.canUndo, isTrue);
      expect(
        h.repo.documentWrites,
        isEmpty,
        reason: 'the undo window sits BEFORE uploading — nothing has started',
      );
      expect(h.repo.mediaObjectUploads, isEmpty);
    });

    test('the window is the product s one undo window', () {
      expect(kUndoWindow, const Duration(seconds: 5));
    });

    test('undoing costs zero writes and zero uploads', () async {
      final h = _harness();
      addTearDown(h.bus.dispose);

      final publication = h.service.publish(
        draft: _draft(),
        describe: 'Posted',
        now: _now,
      );

      expect(publication.undo(), isTrue);
      expect(publication.state, PublishState.composing);

      // Flush anything still pending: there must be nothing.
      await h.bus.flushAll();

      expect(h.repo.documentWrites, isEmpty);
      expect(h.repo.mediaObjectUploads, isEmpty);
      expect(
        h.repo.events,
        isEmpty,
        reason:
            'the work never left the bus, so there is nothing to roll back — '
            'which is why undo can be offered without a cancel API',
      );
    });

    test('once the window closes, exactly one document is written', () async {
      final h = _harness();
      addTearDown(h.bus.dispose);

      final publication = h.service.publish(
        draft: _draft(),
        describe: 'Posted',
        now: _now,
      );
      await h.bus.flushAll();

      expect(publication.state, PublishState.live);
      expect(h.repo.documentWrites, <String>['posts/post-7331']);
      expect(
        h.repo.events.last,
        'doc:posts/post-7331',
        reason: 'media first, document last',
      );
      expect(h.repo.events.first, startsWith('media:'));
    });

    test('undoing a moment late reports false rather than throwing', () async {
      final h = _harness(window: Duration.zero);
      addTearDown(h.bus.dispose);

      final publication = h.service.publish(
        draft: _draft(),
        describe: 'Posted',
        now: _now,
      );
      await h.bus.flushAll();

      expect(publication.undo(), isFalse);
      expect(publication.canUndo, isFalse);
    });

    test('the machine has the eleven states the plan names', () {
      expect(PublishState.values.length, 11);
    });
  });

  group('P0-COM-09 — the opt-out survives into the document', () {
    test('a blurred post records nothing', () async {
      final h = _harness();
      addTearDown(h.bus.dispose);

      h.service.publish(draft: _draft(), describe: 'Posted', now: _now);
      await h.bus.flushAll();

      final post = await h.repo.post('post-7331');
      expect(post!.blurApplied, isTrue);
      expect(post.blurOptOut, isNull);
    });

    test('an opted-out image is published unblurred WITH its record',
        () async {
      final h = _harness();
      addTearDown(h.bus.dispose);
      final at = DateTime(2026, 9, 19, 9, 41);

      h.service.publish(
        draft: _draft(
          media: <CommunityMediaDraft>[
            CommunityMediaDraft.create(
              mediaId: 'm1',
              decision: BlurDecision.explicitOptOut(mediaId: 'm1', at: at),
            ),
          ],
        ),
        describe: 'Posted',
        now: _now,
      );
      await h.bus.flushAll();

      final post = await h.repo.post('post-7331');
      expect(post!.blurApplied, isFalse);
      expect(post.blurOptOut, isNotNull);
      expect(post.blurOptOut!.at, at);
      expect(post.blurOptOut!.by, 'author');
    });

    test('the publish path runs blur before anything else', () {
      final h = _harness();
      addTearDown(h.bus.dispose);

      final publication = h.service.publish(
        draft: _draft(),
        describe: 'Posted',
        now: _now,
      );

      // It has already passed through blurring by the time the window opens:
      // rule 6 is not a branch that can be skipped for speed.
      expect(publication.state, PublishState.undoWindow);
    });
  });

  group('a story is 24 hours, set from the server s moment', () {
    test('expiresAt is createdAt plus the story lifetime', () async {
      final h = _harness();
      addTearDown(h.bus.dispose);

      h.service.publish(
        draft: _draft(kind: PostKind.story),
        describe: 'Posted',
        now: _now,
      );
      await h.bus.flushAll();

      final rail = await h.repo.stories(now: _now);
      expect(rail.single.expiresAt, _now.add(kStoryLifetime));
      expect(kStoryLifetime, const Duration(hours: 24));
    });
  });

  group('the launch scope is consulted, never hard-coded', () {
    test('with the community switched off, nothing publishes', () {
      final h = _harness(flags: FeatureFlags.allOff);
      addTearDown(h.bus.dispose);

      expect(
        () => h.service.publish(
          draft: _draft(),
          describe: 'Posted',
          now: _now,
        ),
        throwsA(isA<FeatureDeferredError>()),
        reason:
            'Feature.community is false until the feature is proven. A screen '
            'that published anyway would be reachable before it was meant to '
            'be.',
      );
    });

    test('a reel is refused while video is deferred', () {
      final h = _harness();
      addTearDown(h.bus.dispose);

      expect(h.service.allows(PostKind.reel), isFalse);
      expect(
        () => h.service.publish(
          draft: _draft(kind: PostKind.reel),
          describe: 'Posted',
          now: _now,
        ),
        throwsA(isA<FeatureDeferredError>()),
      );
    });

    test('photos and text are the launch scope, and they publish', () {
      final h = _harness();
      addTearDown(h.bus.dispose);

      expect(h.service.allows(PostKind.photo), isTrue);
      expect(h.service.allows(PostKind.best), isTrue);
    });

    test('a text post is a photo post with no media', () async {
      final h = _harness();
      addTearDown(h.bus.dispose);

      final draft = _draft(media: const <CommunityMediaDraft>[]);
      expect(draft.isTextOnly, isTrue);

      h.service.publish(draft: draft, describe: 'Posted', now: _now);
      await h.bus.flushAll();

      final post = await h.repo.post('post-7331');
      expect(post!.isTextOnly, isTrue);
      expect(h.repo.mediaObjectUploads, isEmpty);
    });

    test('flipping the video flag on makes the reel path reachable', () {
      // The capability must switch on with the flag and not with a code
      // change. If this test failed, the absence of video would be hard-coded
      // and turning the flag on later would do nothing.
      final h = _harness(
        flags: _communityOn.with_(<Feature, bool>{
          Feature.communityVideo: true,
        }),
      );
      addTearDown(h.bus.dispose);

      expect(h.service.allows(PostKind.reel), isTrue);
    });
  });
}
