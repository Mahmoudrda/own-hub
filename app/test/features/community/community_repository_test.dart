// The repository and the strictness of its fake.
//
// Carries the executable form of P0-COM-01, 02, 10, 11, 12, 13, 15, 18 and
// P1-COM-09. Figures are deliberately unlike the prototype's 412/96/4,210 — a
// fixture that reuses the mockup's numbers cannot tell a real value from a
// leftover sample.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/domain/community_repository.dart';

const _me = AuthorCard(uid: 'me', name: 'Mona');
const _habiba = AuthorCard(uid: 'habiba', name: 'Habiba');
const _nada = AuthorCard(uid: 'nada', name: 'Nada');
const _stranger = AuthorCard(uid: 'stranger', name: 'Someone');

final _now = DateTime(2026, 9, 19, 10);

PostMedia _media(String id) => PostMedia(
  mediaId: id,
  url: 'cdn/$id/feed',
  thumbUrl: 'cdn/$id/grid',
  width: 1080,
  height: 1080,
);

CommunityPost _post({
  required String id,
  required AuthorCard author,
  String? groupId,
  DateTime? at,
  PostKind kind = PostKind.photo,
  DateTime? expiresAt,
  String? parentPostId,
  List<PostMedia> media = const <PostMedia>[],
}) => CommunityPost(
  postId: id,
  authorCard: author,
  kind: kind,
  audienceKeys: groupId == null
      ? AudienceKeys.forAuthor(author.uid)
      : AudienceKeys.inGroup(authorUid: author.uid, groupId: groupId),
  createdAt: at ?? _now,
  groupId: groupId,
  expiresAt: expiresAt,
  parentPostId: parentPostId,
  media: media,
);

CommunityStore _store({
  List<CommunityPost>? posts,
  FollowGraph? graph,
  Map<String, List<String>>? followers,
  List<SavedPost>? saved,
  Map<String, List<CommunityComment>>? comments,
}) => CommunityStore(
  selfUid: 'me',
  selfCard: _me,
  posts: posts,
  graph:
      graph ??
      FollowGraph(
        followingKeys: <String>['a:habiba'],
        groupKeys: <String>['g:beginners'],
      ),
  followers: followers,
  saved: saved,
  comments: comments,
);

void main() {
  group('P0-COM-02 / P1-COM-09 — publishing writes ONE document', () {
    test('one document for a woman nobody follows', () async {
      final repo = InMemoryCommunityRepository(store: _store());

      await repo.publishPost(
        _post(id: 'post-7331', author: _me, media: <PostMedia>[_media('m1')]),
      );

      expect(repo.documentWrites, <String>['posts/post-7331']);
    });

    test('and exactly one for a woman with 5,003 followers', () async {
      // The case seeds five thousand. The point is that the number cannot
      // appear in the write count, because no code path iterates it.
      final followers = <String, List<String>>{
        'me': <String>[for (var i = 0; i < 5003; i++) 'follower-$i'],
      };
      final repo = InMemoryCommunityRepository(
        store: _store(followers: followers),
      );

      expect(repo.followerCountOf('me').value, 5003);

      await repo.publishPost(
        _post(id: 'post-7331', author: _me, media: <PostMedia>[_media('m1')]),
      );

      expect(
        repo.documentWrites.length,
        1,
        reason:
            'spine C9: fan-out on read, never on write. The same count must '
            'hold for 0 followers and for 5,003.',
      );
    });

    test('no per-follower or timeline collection is ever written', () {
      final repo = InMemoryCommunityRepository(store: _store());

      // The forbidden design would show up here as a path. There is no such
      // collection declared anywhere, and the default deny means a fan-out
      // write has nowhere to land.
      final forbidden = RegExp(
        'timeline|inbox|fanout|feedItems|followerFeed',
        caseSensitive: false,
      );
      for (final path in repo.documentWrites) {
        expect(forbidden.hasMatch(path), isFalse, reason: path);
      }
    });

    test('media reaches the CDN BEFORE the document is created', () async {
      // §3.1's deliberate exception to "write immediately": a post document
      // whose media 404s is a broken card in other women's feeds.
      final repo = InMemoryCommunityRepository(store: _store());

      await repo.publishPost(
        _post(
          id: 'post-7331',
          author: _me,
          media: <PostMedia>[_media('m1'), _media('m2')],
        ),
      );

      expect(repo.events, <String>[
        'media:cdn/m1/feed',
        'media:cdn/m2/feed',
        'doc:posts/post-7331',
      ]);
    });

    test('a retried publish targets the same document', () async {
      // postId is minted once (spine C1), so the replay is idempotent.
      final repo = InMemoryCommunityRepository(store: _store());
      final post = _post(id: 'post-7331', author: _me);

      await repo.publishPost(post);
      await repo.publishPost(post);

      final feed = await repo.feed();
      expect(
        feed.posts.where((p) => p.postId == 'post-7331').length,
        1,
        reason: 'a retry must not create a second post',
      );
    });
  });

  group('P0-COM-01 — the feed is groups and follows, and nothing else', () {
    test(
      'her groups and the women she follows appear; nobody else does',
      () async {
        final repo = InMemoryCommunityRepository(
          store: _store(
            posts: <CommunityPost>[
              _post(id: 'p-followed', author: _habiba),
              _post(id: 'p-group', author: _nada, groupId: 'beginners'),
              _post(id: 'p-stranger', author: _stranger),
            ],
          ),
        );

        final page = await repo.feed();

        expect(
          page.posts.map((p) => p.postId),
          containsAll(<String>['p-followed', 'p-group']),
        );
        expect(
          page.posts.map((p) => p.postId),
          isNot(contains('p-stranger')),
          reason: 'there is no public timeline anywhere in the tab',
        );
      },
    );

    test('her own post is always hers to see', () async {
      // She does not follow herself. Without an explicit rule her post would
      // drop out of her own feed the instant it published, so P0-COM-12's
      // "her own feed shows it" would hold only while it was still queued.
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[_post(id: 'p-mine', author: _me)],
        ),
      );

      expect(
        (await repo.feed()).posts.map((p) => p.postId),
        contains('p-mine'),
      );
    });

    test('newest first, and by nothing else', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[
            _post(id: 'older', author: _habiba, at: DateTime(2026, 9, 17, 8)),
            _post(id: 'newer', author: _habiba, at: DateTime(2026, 9, 19, 9)),
          ],
        ),
      );

      final page = await repo.feed();

      expect(page.posts.map((p) => p.postId), <String>['newer', 'older']);
    });

    test('a hidden post never reaches the feed', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[
            CommunityPost(
              postId: 'p-hidden',
              authorCard: _habiba,
              kind: PostKind.photo,
              audienceKeys: AudienceKeys.forAuthor('habiba'),
              createdAt: _now,
              visibility: PostVisibility.removed,
            ),
          ],
        ),
      );

      expect((await repo.feed()).posts, isEmpty);
    });

    test('stories belong on the rail, not in the feed body', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[
            _post(
              id: 'p-story',
              author: _habiba,
              kind: PostKind.story,
              expiresAt: _now.add(const Duration(hours: 6)),
            ),
          ],
        ),
      );

      expect((await repo.feed()).posts, isEmpty);
      expect((await repo.stories(now: _now)).length, 1);
    });
  });

  group('P0-COM-10 — like offline, then reconnect', () {
    test('liking twice offline leaves exactly one like', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[_post(id: 'p-19', author: _habiba)],
        ),
      );

      repo.goOffline();
      await repo.like('p-19');
      await repo.like('p-19');

      expect(
        repo.queuedWriteCount,
        1,
        reason:
            'the queue is keyed by document path, and a like\'s id is her uid '
            '— so the replay IS the same write',
      );

      await repo.goOnline();

      expect(repo.likeDocCount('p-19'), 1);
    });

    test('the like document is named after her, not after the event', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[_post(id: 'p-19', author: _habiba)],
        ),
      );

      await repo.like('p-19');

      expect(repo.documentWrites, <String>['posts/p-19/likes/me']);
    });
  });

  group('P0-COM-11 — comment offline', () {
    test('it shows at once, syncs once, and loses the badge', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[_post(id: 'p-19', author: _habiba)],
        ),
      );

      repo.goOffline();
      await repo.comment(
        postId: 'p-19',
        commentId: 'c-88',
        body: 'This is the exact thing I needed.',
      );

      var comments = await repo.comments('p-19');
      expect(comments.length, 1);
      expect(
        comments.single.pendingSync,
        isTrue,
        reason: 'full opacity with the queued glyph — never a spinner',
      );

      await repo.goOnline();

      comments = await repo.comments('p-19');
      expect(comments.length, 1, reason: 'no duplicate appears');
      expect(
        comments.single.pendingSync,
        isFalse,
        reason:
            'the optimistic copy is replaced when it lands. Leaving the glyph '
            'on reads as a comment stuck forever.',
      );
    });

    test('a comment above the rules cap is refused here too', () async {
      final repo = InMemoryCommunityRepository(store: _store());

      expect(
        () => repo.comment(
          postId: 'p-19',
          commentId: 'c-1',
          body: 'x' * (kMaxCommentLength + 1),
        ),
        throwsArgumentError,
        reason:
            'a fake that accepts what the server refuses lets a screen pass '
            'its tests and fail on a phone',
      );
    });
  });

  group('P0-COM-12 — publishing offline holds the media locally', () {
    test('no document exists for anyone else until she reconnects', () async {
      final repo = InMemoryCommunityRepository(store: _store());
      repo.goOffline();

      await repo.publishPost(
        _post(id: 'post-61', author: _me, media: <PostMedia>[_media('m1')]),
      );

      expect(
        repo.documentWrites,
        isEmpty,
        reason:
            'nothing may point at a missing object in another woman\'s feed',
      );
      expect(repo.mediaObjectUploads, isEmpty);

      final mine = await repo.feed();
      final queued = mine.posts.singleWhere((p) => p.postId == 'post-61');
      expect(
        queued.pendingUpload,
        isTrue,
        reason: 'her own feed shows it badged as waiting',
      );

      await repo.goOnline();

      expect(repo.documentWrites, <String>['posts/post-61']);
      expect(repo.mediaObjectUploads, <String>['cdn/m1/feed']);
    });
  });

  group('P0-COM-13 — what a blocked woman can and cannot see', () {
    InMemoryCommunityRepository blocked() => InMemoryCommunityRepository(
      store: _store(
        posts: <CommunityPost>[_post(id: 'p-nada', author: _nada)],
        graph: FollowGraph(
          followingKeys: <String>['a:habiba', 'a:nada'],
          hiddenAuthors: <String>['nada'],
        ),
      ),
    );

    test('her posts are filtered out of the feed', () async {
      expect((await blocked().feed()).posts, isEmpty);
    });

    test('her post and her profile read as not available', () async {
      final repo = blocked();

      expect(await repo.post('p-nada'), isNull);
      expect(await repo.profile('nada'), isNull);
    });

    test('commenting, liking and following are refused', () async {
      final repo = blocked();

      await expectLater(repo.like('p-nada'), throwsStateError);
      await expectLater(repo.follow('nada'), throwsStateError);
      await expectLater(
        repo.comment(postId: 'p-nada', commentId: 'c-1', body: 'hello'),
        throwsStateError,
      );
    });

    test('nothing that comes back says the word blocked', () async {
      // The refusal must read as the ordinary "not available". A message
      // naming a block is the side channel P0-COM-13 forbids.
      final repo = blocked();

      try {
        await repo.follow('nada');
        fail('expected a refusal');
      } on StateError catch (e) {
        expect(
          RegExp('block', caseSensitive: false).hasMatch(e.message),
          isFalse,
          reason: 'she must not be able to learn she was blocked',
        );
      }
    });

    test(
      'an unblocked woman is unaffected — the guard is not vacuous',
      () async {
        final repo = InMemoryCommunityRepository(
          store: _store(
            posts: <CommunityPost>[_post(id: 'p-habiba', author: _habiba)],
          ),
        );

        expect(await repo.post('p-habiba'), isNotNull);
        await expectLater(repo.like('p-habiba'), completes);
      },
    );
  });

  group('P0-COM-15 — a story expires after 24 hours', () {
    test('it leaves the rail once its TTL passes', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[
            _post(
              id: 'story-live',
              author: _habiba,
              kind: PostKind.story,
              expiresAt: _now.add(const Duration(hours: 3)),
            ),
            _post(
              id: 'story-gone',
              author: _habiba,
              kind: PostKind.story,
              expiresAt: _now.subtract(const Duration(minutes: 1)),
            ),
          ],
        ),
      );

      final rail = await repo.stories(now: _now);

      expect(rail.map((p) => p.postId), <String>['story-live']);
    });

    test('a story cannot be created without an expiry', () {
      expect(
        () => CommunityPost(
          postId: 's',
          authorCard: _habiba,
          kind: PostKind.story,
          audienceKeys: AudienceKeys.forAuthor('habiba'),
          createdAt: _now,
        ),
        throwsArgumentError,
        reason:
            'a story with no expiresAt would never be collected by the TTL '
            'policy, and there is no sweeper to catch it',
      );
    });

    test('and only a story has one', () {
      expect(
        () => CommunityPost(
          postId: 'p',
          authorCard: _habiba,
          kind: PostKind.photo,
          audienceKeys: AudienceKeys.forAuthor('habiba'),
          createdAt: _now,
          expiresAt: _now.add(const Duration(hours: 24)),
        ),
        throwsArgumentError,
      );
    });
  });

  group('P0-COM-18 — removing a post removes it everywhere', () {
    test('feed, comments, follow-ups, saved tile and media', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          saved: <SavedPost>[
            SavedPost(
              postId: 'post-61',
              kind: PostKind.photo,
              authorUid: 'me',
              savedAt: _now,
              thumbUrl: 'cdn/m1/grid',
            ),
          ],
          comments: <String, List<CommunityComment>>{
            'post-61': <CommunityComment>[
              CommunityComment(
                commentId: 'c-1',
                authorCard: _habiba,
                postAuthorUid: 'me',
                body: 'lovely',
                createdAt: _now,
              ),
            ],
          },
        ),
      );

      await repo.publishPost(
        _post(id: 'post-61', author: _me, media: <PostMedia>[_media('m1')]),
      );
      await repo.publishPost(
        _post(id: 'post-61-followup', author: _me, parentPostId: 'post-61'),
      );
      expect(repo.mediaObjectUploads, isNotEmpty);

      await repo.deletePost('post-61');

      expect(await repo.post('post-61'), isNull);
      expect(await repo.comments('post-61'), isEmpty);
      expect(
        (await repo.feed()).posts.map((p) => p.postId),
        isNot(contains('post-61-followup')),
        reason: 'a follow-up has no existence apart from its parent',
      );
      expect(
        repo.mediaObjectUploads,
        isEmpty,
        reason: 'the R2 objects go and the CDN is purged for those URLs',
      );

      final saved = await repo.saved();
      expect(
        saved.single.isStillAvailable,
        isFalse,
        reason:
            'the saved grid shows the not-available tile rather than a broken '
            'image',
      );
    });
  });

  group('the fake refuses what the rules refuse', () {
    test('a post carrying more than two audience keys cannot be published', () {
      // Unreachable through AudienceKeys, which is the point — but the
      // boundary the server sees asserts it anyway.
      final repo = InMemoryCommunityRepository(store: _store());
      final post = _post(id: 'p', author: _me, groupId: 'beginners');

      expect(post.audienceKeys.size, lessThanOrEqualTo(2));
      expect(() => repo.publishPost(post), returnsNormally);
    });

    test('only her own post is hers to hide', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          posts: <CommunityPost>[_post(id: 'p-habiba', author: _habiba)],
        ),
      );

      await expectLater(repo.hideOwnPost('p-habiba'), throwsStateError);
    });
  });

  group('the feed page reports what it cost', () {
    test('ten reads per chunk per page', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(
          graph: FollowGraph(
            followingKeys: <String>[for (var i = 0; i < 61; i++) 'a:w-$i'],
          ),
        ),
      );

      final page = await repo.feed();

      expect(page.queriesIssued.length, 3, reason: '61 keys / 30 = 3 chunks');
      expect(page.documentReads, 30);
    });

    test('day one issues no query at all', () async {
      final repo = InMemoryCommunityRepository(
        store: _store(graph: FollowGraph()),
      );

      final page = await repo.feed();

      expect(page.queriesIssued, isEmpty);
      expect(page.documentReads, 0);
      expect(page.posts, isEmpty);
    });
  });
}
