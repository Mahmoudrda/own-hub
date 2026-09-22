// M07, M10, M14 and M15.
//
// The profile's restraint is in what is missing, so most of these assert an
// absence — and each absence has a flag or a rule behind it.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/domain/follow_state.dart';
import 'package:own_hub/features/community/domain/follower_count.dart';
import 'package:own_hub/features/community/presentation/profile_view_model.dart';

const _habiba = AuthorCard(uid: 'habiba', name: 'Habiba');
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

PublicProfile _profile({
  int posts = 61,
  FollowerCount? followers = const FollowerCount(7331),
  FollowerCount? following = const FollowerCount(88),
}) => PublicProfile(
  uid: 'habiba',
  name: 'Habiba',
  bio: 'Training in a small flat, quietly.',
  joinedMonth: 'March',
  postCount: posts,
  followerCount: followers,
  followingCount: following,
);

CommunityPost _post(String id) => CommunityPost(
  postId: id,
  authorCard: _habiba,
  kind: PostKind.photo,
  audienceKeys: AudienceKeys.forAuthor('habiba'),
  createdAt: _now,
);

void main() {
  group('M07 — follower counts are off at launch', () {
    test('neither count renders while the flag is off', () {
      final model = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.followerLabel, isNull);
      expect(model.followingLabel, isNull);
      expect(model.showsFollowerCounts, isFalse);
    });

    test('the flag is consulted, not the absence hard-coded', () {
      // If this failed, switching community_show_follower_counts on later
      // would do nothing and somebody would have to find every place the
      // capability was quietly removed.
      final model = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn.with_(<Feature, bool>{
          Feature.communityFollowerCounts: true,
        }),
      );

      expect(model.followerLabel, '7,331');
      expect(model.followingLabel, '88');
    });

    test('her post count is hers and always shows', () {
      final model = ProfileScreenModel.from(
        profile: _profile(posts: 61),
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.postLabel, '61');
    });
  });

  group('M07 — not available means not available', () {
    test('a woman who is not discoverable', () {
      final model = ProfileScreenModel.from(
        profile: null,
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.isAvailable, isFalse);
      expect(model.followState, FollowState.unavailable);
      expect(model.tiles, isEmpty);
      expect(model.tabs, isEmpty);
    });

    test('and a woman who blocked her render identically', () {
      final hidden = ProfileScreenModel.from(
        profile: null,
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn,
      );
      final blocked = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'me',
        subjectUid: 'habiba',
        hiddenEitherWay: true,
        flags: _communityOn,
      );

      expect(blocked.availability, hidden.availability);
      expect(blocked.followState, hidden.followState);
      expect(blocked.name, hidden.name);
      expect(
        blocked.tiles,
        hidden.tiles,
        reason: 'G10 §5.1: identical to the blocked rendering, by design',
      );
    });

    test('a blocked profile offers no way to reach her', () {
      final model = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'me',
        subjectUid: 'habiba',
        hiddenEitherWay: true,
        flags: _communityOn,
      );

      expect(model.showsMessageButton, isFalse);
    });
  });

  group('M07 — tabs and her own page', () {
    test('the reels tab does not exist while video is deferred', () {
      final model = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.tabs, <ProfileTab>[ProfileTab.photos, ProfileTab.followUps]);
    });

    test('and appears when the flag is on', () {
      final model = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn.with_(<Feature, bool>{
          Feature.communityVideo: true,
        }),
      );

      expect(model.tabs, contains(ProfileTab.reels));
    });

    test('her own profile has no follow button', () {
      final model = ProfileScreenModel.from(
        profile: _profile(),
        viewerUid: 'habiba',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.isSelf, isTrue);
      expect(model.showsFollowButton, isFalse);
    });

    test('her own empty profile says what would appear there', () {
      final model = ProfileScreenModel.from(
        profile: _profile(posts: 0),
        viewerUid: 'habiba',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.showsOwnEmptyState, isTrue);
    });

    test('another woman s empty profile is not her onboarding', () {
      final model = ProfileScreenModel.from(
        profile: _profile(posts: 0),
        viewerUid: 'me',
        subjectUid: 'habiba',
        flags: _communityOn,
      );

      expect(model.showsOwnEmptyState, isFalse);
    });
  });

  group('M10 — explore', () {
    test('the chips are the topic enum, never free tags', () {
      final model = ExploreScreenModel.from(posts: const <CommunityPost>[]);

      expect(model.chips, CommunityTopic.values);
    });

    test('nothing matching offers the chip back', () {
      final model = ExploreScreenModel.from(
        posts: const <CommunityPost>[],
        selected: CommunityTopic.ramadan,
      );

      expect(model.isEmpty, isTrue);
      expect(model.canClearChip, isTrue);
    });

    test('a grid of tiles is not empty', () {
      final model = ExploreScreenModel.from(
        posts: <CommunityPost>[_post('a'), _post('b')],
      );

      expect(model.tiles.length, 2);
      expect(model.isEmpty, isFalse);
    });
  });

  group('M14 — people, not counters', () {
    ActivityItem item(ActivityKind kind, {bool followsMe = false, String? postId}) =>
        ActivityItem(
          id: '$kind',
          kind: kind,
          at: _now,
          actor: _habiba,
          postId: postId,
          followsMe: followsMe,
        );

    test('nothing on the screen is a number going up', () {
      final model = ActivityScreenModel.from(<ActivityItem>[
        item(ActivityKind.liked),
      ]);

      expect(model.showsCounters, isFalse);
    });

    test('the follow-up prompt is separated from the rows', () {
      final model = ActivityScreenModel.from(<ActivityItem>[
        item(ActivityKind.liked),
        ActivityItem(
          id: 'prompt',
          kind: ActivityKind.followUpPrompt,
          at: _now,
          postId: 'p-first',
        ),
      ]);

      expect(
        model.followUpPrompt,
        'p-first',
        reason: 'it is the engine of the follow-up feature and the only nudge',
      );
      expect(model.rows.length, 1);
    });

    test('only a follow row offers to follow back', () {
      final model = ActivityScreenModel.from(<ActivityItem>[
        item(ActivityKind.followed),
        item(ActivityKind.liked),
      ]);

      expect(model.rows.first.offersFollowBack, isTrue);
      expect(model.rows.last.offersFollowBack, isFalse);
    });

    test('a woman she already follows is not offered again', () {
      final model = ActivityScreenModel.from(<ActivityItem>[
        item(ActivityKind.followed, followsMe: true),
      ]);

      expect(model.rows.single.offersFollowBack, isFalse);
    });

    test('empty says what will fill it', () {
      expect(
        ActivityScreenModel.from(const <ActivityItem>[]).isEmpty,
        isTrue,
      );
    });
  });

  group('M15 — saved is private by construction', () {
    SavedPost saved(String id, {String? thumbUrl}) => SavedPost(
      postId: id,
      kind: PostKind.photo,
      authorUid: 'habiba',
      savedAt: _now,
      thumbUrl: thumbUrl,
    );

    test('only she can see it', () {
      final model = SavedScreenModel.from(<SavedPost>[
        saved('a', thumbUrl: 'cdn/a/grid'),
      ]);

      expect(model.isPrivate, isTrue);
      expect(model.tiles.single.available, isTrue);
    });

    test('a deleted post becomes the not-available tile', () {
      final model = SavedScreenModel.from(<SavedPost>[saved('a')]);

      expect(
        model.tiles.single.available,
        isFalse,
        reason:
            'P0-COM-18: the saved grid shows the not-available tile rather '
            'than a broken image',
      );
    });

    test('empty explains how to save', () {
      expect(SavedScreenModel.from(const <SavedPost>[]).isEmpty, isTrue);
    });
  });
}
