// M01, M02, M08 and M17, tested without pumping a frame.
//
// Figures are deliberately unlike the prototype's 412 / 96 / 27, so a real
// value is distinguishable from a leftover sample.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/domain/community_repository.dart';
import 'package:own_hub/features/community/domain/community_tab_state.dart';
import 'package:own_hub/features/community/domain/follow_state.dart';
import 'package:own_hub/features/community/domain/report_copy.dart';
import 'package:own_hub/features/community/presentation/feed_view_model.dart';

const _me = AuthorCard(uid: 'me', name: 'Mona');
const _habiba = AuthorCard(uid: 'habiba', name: 'Habiba');
final _now = DateTime(2026, 9, 19, 10);

/// Community on, at its launch scope: photos and text.
///
/// Built from [FeatureFlags.allOff], so a test that asserts a deferred
/// capability is absent is asserting its own precondition rather than today's
/// value of `FeatureFlags.shipped`.
final _communityOn = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.community: true,
  Feature.communityPosts: true,
});

CommunityPost _post({
  String id = 'p-7331',
  AuthorCard author = _habiba,
  int likes = 0,
  int comments = 0,
  String caption = '',
  bool blurApplied = true,
  bool pendingUpload = false,
  List<PostMedia> media = const <PostMedia>[],
  PostKind kind = PostKind.photo,
  DateTime? expiresAt,
}) => CommunityPost(
  postId: id,
  authorCard: author,
  kind: kind,
  audienceKeys: AudienceKeys.forAuthor(author.uid),
  createdAt: _now,
  likeCount: likes,
  commentCount: comments,
  caption: caption,
  blurApplied: blurApplied,
  pendingUpload: pendingUpload,
  media: media,
  expiresAt: expiresAt,
);

FeedScreenModel _feed({
  List<CommunityPost> posts = const <CommunityPost>[],
  FollowGraph? graph,
  List<CommunityPost> stories = const <CommunityPost>[],
  List<CommunityGroup> suggested = const <CommunityGroup>[],
  bool online = true,
  bool hasCachedPage = false,
}) => FeedScreenModel.from(
  graph:
      graph ??
      FollowGraph(
        followingKeys: <String>['a:habiba'],
        groupKeys: <String>['g:beginners'],
      ),
  page: FeedPage(posts: posts),
  viewerUid: 'me',
  now: _now,
  stories: stories,
  suggestedGroups: suggested,
  online: online,
  hasCachedPage: hasCachedPage,
);

void main() {
  group('M17 is a branch of M01, not a screen you navigate to', () {
    test('day one renders inside the Community tab', () {
      final model = _feed(graph: FollowGraph());

      expect(model.state, CommunityTabState.dayOne);
      expect(model.showsDayOne, isTrue);
      expect(model.posts, isEmpty);
    });

    test('day one offers three groups, and nothing else does', () {
      final groups = <CommunityGroup>[
        for (var i = 0; i < 6; i++)
          CommunityGroup(groupId: 'g-$i', name: 'Group $i', memberCount: 88),
      ];

      final dayOne = _feed(graph: FollowGraph(), suggested: groups);
      expect(
        dayOne.suggestedGroups.length,
        3,
        reason: 'HANDOFF 17: an empty state offers ONE smallest action',
      );

      final joined = _feed(suggested: groups);
      expect(joined.suggestedGroups, isEmpty);
    });

    test('joined but silent is a different state from day one', () {
      final model = _feed();

      expect(model.state, CommunityTabState.joinedOnly);
      expect(model.showsJoinedButSilent, isTrue);
      expect(model.showsDayOne, isFalse);
    });

    test('offline with no cache is a state, not a failure', () {
      final model = _feed(online: false);

      expect(model.showsOfflineCold, isTrue);
    });

    test('a cached page still reads with no signal', () {
      final model = _feed(
        posts: <CommunityPost>[_post()],
        online: false,
        hasCachedPage: true,
      );

      expect(model.state, CommunityTabState.ready);
    });
  });

  group('a post card carries her real figures', () {
    test('counts come from the document, not from the dictionary', () {
      final card = PostCardModel.from(
        _post(likes: 7331, comments: 19),
        viewerUid: 'me',
      );

      expect(card.likeLabel, '7,331');
      expect(card.commentLabel, '19');
    });

    test('a text post is a post with no media', () {
      final card = PostCardModel.from(
        _post(caption: 'First week done.'),
        viewerUid: 'me',
      );

      expect(card.isTextOnly, isTrue);
      expect(card.hasMedia, isFalse);
      expect(card.caption, 'First week done.');
    });

    test('no card ever shows a follower count', () {
      final card = PostCardModel.from(_post(), viewerUid: 'me');

      expect(card.showsFollowerCount, isFalse);
    });

    test('her own post is marked hers and offers no follow button', () {
      final card = PostCardModel.from(_post(author: _me), viewerUid: 'me');

      expect(card.isMine, isTrue);
      expect(card.followState, FollowState.self);
      expect(card.showsFollowButton, isFalse);
    });

    test('a blocked author collapses to not available', () {
      final card = PostCardModel.from(
        _post(),
        viewerUid: 'me',
        hiddenEitherWay: true,
      );

      expect(card.followState, FollowState.unavailable);
      expect(card.showsFollowButton, isFalse);
    });

    test('a queued post is badged, never dimmed', () {
      final card = PostCardModel.from(
        _post(author: _me, pendingUpload: true),
        viewerUid: 'me',
      );

      expect(card.pendingUpload, isTrue);
    });
  });

  group('the stories rail', () {
    test('hers comes first', () {
      final model = _feed(
        posts: <CommunityPost>[_post()],
        stories: <CommunityPost>[
          _post(
            id: 's-habiba',
            kind: PostKind.story,
            expiresAt: _now.add(const Duration(hours: 5)),
          ),
          _post(
            id: 's-mine',
            author: _me,
            kind: PostKind.story,
            expiresAt: _now.add(const Duration(hours: 5)),
          ),
        ],
      );

      expect(model.rail.first.isMine, isTrue);
      expect(model.showsRail, isTrue);
    });

    test('a story under an hour old dims its ring', () {
      final model = _feed(
        posts: <CommunityPost>[_post()],
        stories: <CommunityPost>[
          _post(
            id: 's-1',
            kind: PostKind.story,
            expiresAt: _now.add(const Duration(minutes: 20)),
          ),
        ],
      );

      expect(model.rail.single.expiringSoon, isTrue);
    });
  });

  group('M02 — a post and its comments', () {
    test('a missing post renders the ordinary not-available state', () {
      final model = PostThreadModel.from(post: null, viewerUid: 'me');

      expect(model.isAvailable, isFalse);
      expect(model.availability, SurfaceAvailability.notAvailable);
    });

    test('a blocked post renders identically to a deleted one', () {
      final deleted = PostThreadModel.from(post: null, viewerUid: 'me');
      final blocked = PostThreadModel.from(
        post: _post(),
        viewerUid: 'me',
        hiddenEitherWay: true,
      );

      expect(blocked.availability, deleted.availability);
      expect(blocked.post, isNull);
      expect(
        blocked.comments,
        isEmpty,
        reason:
            'nothing may distinguish a block from any other reason a post is '
            'not there',
      );
    });

    test('coaches are labelled inside comments', () {
      final model = PostThreadModel.from(
        post: _post(),
        viewerUid: 'me',
        comments: <CommunityComment>[
          CommunityComment(
            commentId: 'c-1',
            authorCard: _habiba,
            postAuthorUid: 'habiba',
            body: 'Week five adds the standing moves.',
            createdAt: _now,
            isCoach: true,
          ),
        ],
      );

      expect(model.comments.single.isCoach, isTrue);
    });

    test('a queued comment keeps its glyph until it lands', () {
      final model = PostThreadModel.from(
        post: _post(),
        viewerUid: 'me',
        comments: <CommunityComment>[
          CommunityComment(
            commentId: 'c-1',
            authorCard: _me,
            postAuthorUid: 'habiba',
            body: 'kind words',
            createdAt: _now,
            pendingSync: true,
          ),
        ],
      );

      expect(model.comments.single.pendingSync, isTrue);
    });

    test('there is no who-liked-this list', () {
      final model = PostThreadModel.from(post: _post(), viewerUid: 'me');

      expect(model.showsLikeRoster, isFalse);
    });

    test('the voice note composer is deferred, behind its flag', () {
      final off = PostThreadModel.from(
        post: _post(),
        viewerUid: 'me',
        flags: _communityOn,
      );
      expect(off.offersVoiceNote, isFalse);

      // Consulted, not hard-coded: switching the flag on reveals the row.
      final on = PostThreadModel.from(
        post: _post(),
        viewerUid: 'me',
        flags: _communityOn.with_(<Feature, bool>{
          Feature.communityVoiceNotes: true,
        }),
      );
      expect(on.offersVoiceNote, isTrue);
    });
  });

  group('M08 — report, block, mute', () {
    test('mute is offered only inside a group', () {
      expect(
        SafetySheetModel.from(subjectName: 'Habiba').actions,
        <SafetyAction>[SafetyAction.report, SafetyAction.block],
      );
      expect(
        SafetySheetModel.from(subjectName: 'Habiba', inGroup: true).actions,
        contains(SafetyAction.muteGroup),
      );
    });

    test('a queued report may NOT claim a moderator is reading it', () {
      final queued = SafetySheetModel.from(
        subjectName: 'Habiba',
        existingReport: const Report(
          id: 'r-1',
          subjectUid: 'habiba',
          reason: ReportReason.harassment,
          state: ReportState.queuedLocal,
        ),
      );

      expect(queued.reportCopy, ReportCopyState.queuedNotSent);
      expect(
        queued.mayPromiseAnHour,
        isFalse,
        reason:
            'P0-COM-14: it is never rendered as "a moderator is reading it". '
            'Offline there is no server stamp, so the hour has not started.',
      );
    });

    test('a sent report may', () {
      final sent = SafetySheetModel.from(
        subjectName: 'Habiba',
        existingReport: Report(
          id: 'r-1',
          subjectUid: 'habiba',
          reason: ReportReason.harassment,
          state: ReportState.submitted,
          createdAt: _now,
        ),
      );

      expect(sent.reportCopy, ReportCopyState.sentHourStarted);
      expect(sent.mayPromiseAnHour, isTrue);
    });

    test('nothing reversible raises a confirmation', () {
      final sheet = SafetySheetModel.from(subjectName: 'Habiba');

      expect(sheet.likeConfirms, isFalse);
      expect(sheet.saveConfirms, isFalse);
      expect(sheet.followConfirms, isFalse);
      expect(sheet.publishConfirms, isFalse);
    });

    test('blocking takes a second step, which is not a dialog', () {
      // G7's documented exemption for destructive non-logging actions. It is a
      // second step in the SHEET — product_rules_test forbids showDialog and
      // AlertDialog anywhere under lib/features, and that guard is right.
      final sheet = SafetySheetModel.from(subjectName: 'Habiba');

      expect(sheet.blockTakesASecondStep, isTrue);
    });
  });
}
