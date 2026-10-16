// M03, M09, M11, M12 and M16 — the launch scope, and the deferred capabilities
// that are absent behind a flag rather than absent from the code.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/domain/follow_up_policy.dart';
import 'package:own_hub/features/community/presentation/create_view_model.dart';

const _me = AuthorCard(uid: 'me', name: 'Mona');
const _habiba = AuthorCard(uid: 'habiba', name: 'Habiba');
final _now = DateTime(2026, 7, 3);

/// Community on, at its launch scope: photos and text.
///
/// Built from [FeatureFlags.allOff] rather than from `FeatureFlags.shipped`,
/// so every absence asserted below is an absence this file asked for. Borrowing
/// the defaults would make each of these a test of today's switch positions.
final _communityOn = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.community: true,
  Feature.communityPosts: true,
});
final _videoOn = _communityOn.with_(<Feature, bool>{
  Feature.communityVideo: true,
});

CommunityPost _post({
  required String id,
  AuthorCard author = _me,
  String? parentPostId,
  String caption = 'First week done.',
}) => CommunityPost(
  postId: id,
  authorCard: author,
  kind: PostKind.photo,
  audienceKeys: AudienceKeys.forAuthor(author.uid),
  createdAt: _now,
  parentPostId: parentPostId,
  caption: caption,
);

void main() {
  group('M03 — the launch scope is photos and text', () {
    test('nothing is offered while the whole feature is dark', () {
      // Community off, so every child is off too — said here rather than
      // inherited from whatever the defaults happen to be today.
      final model = CreateOptionsModel.from(flags: FeatureFlags.allOff);

      expect(model.options, isEmpty);
    });

    test('photo, text and a personal best are offered', () {
      final model = CreateOptionsModel.from(flags: _communityOn);

      expect(model.offers(CreateOption.photoOrPost), isTrue);
      expect(model.offers(CreateOption.personalBest), isTrue);
    });

    test('the reel tile is absent while video is deferred', () {
      final model = CreateOptionsModel.from(flags: _communityOn);

      expect(model.offers(CreateOption.reel), isFalse);
    });

    test('and appears the moment the flag is on', () {
      final model = CreateOptionsModel.from(flags: _videoOn);

      expect(
        model.offers(CreateOption.reel),
        isTrue,
        reason:
            'a hard-coded absence means switching communityVideo on does '
            'nothing and somebody has to find every place it was removed',
      );
    });

    test('the voice note row is absent, and flag-gated too', () {
      expect(
        CreateOptionsModel.from(flags: _communityOn)
            .offers(CreateOption.voiceNote),
        isFalse,
      );
      expect(
        CreateOptionsModel.from(
          flags: _communityOn.with_(<Feature, bool>{
            Feature.communityVoiceNotes: true,
          }),
        ).offers(CreateOption.voiceNote),
        isTrue,
      );
    });

    test('a follow-up is offered only once she has something to follow up', () {
      final none = CreateOptionsModel.from(flags: _communityOn);
      expect(none.offers(CreateOption.followUp), isFalse);
      expect(
        none.explainsFollowUpLater,
        isTrue,
        reason: 'a tile that cannot succeed is worse than an explanation',
      );

      final some = CreateOptionsModel.from(
        flags: _communityOn,
        hasParentPost: true,
      );
      expect(some.offers(CreateOption.followUp), isTrue);
    });

    test('blur is on before anything is chosen', () {
      expect(CreateOptionsModel.from(flags: _communityOn).blurOn, isTrue);
    });

    test('the personal best never carries a scale weight', () {
      expect(
        CreateOptionsModel.from(flags: _communityOn).bestCarriesScaleWeight,
        isFalse,
      );
    });
  });

  group('M09 and M16 — video is deferred, not deleted', () {
    test('reels renders its unavailable state, not an empty player', () {
      final model = ReelsScreenModel.from(flags: _communityOn);

      expect(model.available, isFalse);
      expect(model.isEmpty, isFalse, reason: 'not empty — unavailable');
    });

    test('with video on, an empty reels surface says so', () {
      final model = ReelsScreenModel.from(flags: _videoOn);

      expect(model.available, isTrue);
      expect(model.isEmpty, isTrue);
    });

    test('the camera offers no video mode while video is deferred', () {
      final model = RecordScreenModel.from(flags: _communityOn);

      expect(model.offersVideo, isFalse);
      expect(model.modes, <RecordMode>[RecordMode.story, RecordMode.post]);
    });

    test('and offers one when the flag is on', () {
      expect(RecordScreenModel.from(flags: _videoOn).offersVideo, isTrue);
    });

    test('blur sits on the camera rail as an ordinary control', () {
      expect(RecordScreenModel.from(flags: _communityOn).blurOn, isTrue);
    });
  });

  group('M11 — only her own posts can be followed up', () {
    test('another woman s post is never offered', () {
      final model = FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[
          _post(id: 'mine'),
          _post(id: 'hers', author: _habiba),
        ],
        viewerUid: 'me',
      );

      expect(model.candidates.map((c) => c.postId), <String>['mine']);
    });

    test('a follow-up cannot itself be followed up', () {
      final model = FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[
          _post(id: 'mine'),
          _post(id: 'already-a-followup', parentPostId: 'mine'),
        ],
        viewerUid: 'me',
      );

      expect(model.candidates.map((c) => c.postId), <String>['mine']);
    });

    test('nothing to follow up on yet', () {
      final model = FollowUpComposerModel.from(
        ownPosts: const <CommunityPost>[],
        viewerUid: 'me',
      );

      expect(model.isEmpty, isTrue);
      expect(model.canPost, isFalse);
    });

    test('posting needs a chosen parent', () {
      final model = FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[_post(id: 'mine')],
        viewerUid: 'me',
        selectedPostId: 'mine',
      );

      expect(model.canPost, isTrue);
      expect(model.candidates.single.selected, isTrue);
    });

    test('blur applies to both frames, including the old one', () {
      final model = FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[_post(id: 'mine')],
        viewerUid: 'me',
      );

      expect(model.blurBothFrames, isTrue);
    });

    test('the cost card is two integers, offered not required', () {
      final without = FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[_post(id: 'mine')],
        viewerUid: 'me',
      );
      expect(without.sessionsLabel, isNull);

      final with_ = FollowUpComposerModel.from(
        ownPosts: <CommunityPost>[_post(id: 'mine')],
        viewerUid: 'me',
        cost: const FollowUpCost(sessions: 61, countedWeeks: 19),
      );
      expect(with_.sessionsLabel, '61');
      expect(with_.countedWeeksLabel, '19');
      expect(with_.costCarriesWeight, isFalse);
    });
  });

  group('M12 — one woman, over time', () {
    FollowUpMoment moment(String id, int dayOffset, {FollowUpCost? cost}) =>
        FollowUpMoment(
          postId: id,
          authorUid: 'me',
          takenAt: _now.add(Duration(days: dayOffset)),
          cost: cost,
        );

    test('the strip runs parent, then follow-ups, ending in Now', () {
      final model = FollowUpThreadModel.from(
        FollowUpChain(
          authorUid: 'me',
          moments: <FollowUpMoment>[
            moment('week-1', 0),
            moment('week-4', 21),
            moment('now', 56),
          ],
        ),
      );

      expect(model.moments.map((m) => m.weeksIn), <int>[0, 3, 8]);
      expect(model.moments.last.isNow, isTrue);
      expect(model.moments.first.isNow, isFalse);
      expect(model.moments[1].weekLabel, '3');
    });

    test('there is exactly one author, and it is hers', () {
      final model = FollowUpThreadModel.from(
        FollowUpChain(
          authorUid: 'me',
          moments: <FollowUpMoment>[moment('a', 0), moment('b', 56)],
        ),
      );

      expect(model.authorUid, 'me');
      expect(model.hasSingleAuthor, isTrue);
    });

    test('a lone parent is a chain with nothing to compare to', () {
      final model = FollowUpThreadModel.from(
        FollowUpChain(
          authorUid: 'me',
          moments: <FollowUpMoment>[moment('only', 0)],
        ),
      );

      expect(model.moments.single.isNow, isFalse);
    });

    test('what it cost her comes from the latest moment', () {
      final model = FollowUpThreadModel.from(
        FollowUpChain(
          authorUid: 'me',
          moments: <FollowUpMoment>[
            moment('a', 0),
            moment(
              'b',
              56,
              cost: const FollowUpCost(sessions: 61, countedWeeks: 19),
            ),
          ],
        ),
      );

      expect(model.showsCost, isTrue);
      expect(model.sessionsLabel, '61');
      expect(model.countedWeeksLabel, '19');
    });
  });
}
