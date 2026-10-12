// Blocking, driven through the REAL app: see her, block her, and assert she is
// gone from every surface that was showing her.
//
// # The defect this exists for
//
// `FollowGraph.hiddenAuthors` is the list the feed, Explore, the groups and a
// woman's page all filter on. It was **read in five places and written in
// none**: `InMemoryBlockService` recorded the block, `M08` closed, the sheet
// had said what blocking does, and her posts carried on appearing everywhere.
// Two hundred and fifty community tests and a full safety suite stayed green,
// because every one of them asserted the record rather than the effect.
//
// So nothing here asserts that a block was written. Each case asserts that her
// words are no longer on the screen, which is the only claim a woman can check.
//
// # The woman in this test
//
// "Nada" exists for the length of one test and is created by the test, the way
// a tester's own content is. Nothing is seeded into the shipped app: the feed
// still starts empty, and `baked_in_samples_test` still holds.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/community_state.dart';
import 'package:own_hub/app_state/pledge.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/safety.dart';
import 'package:own_hub/features/community/domain/audience_keys.dart';
import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/presentation/profile_view.dart'
    as member;
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

const _nada = 'nada';
const _herPost = 'Walked the corniche before sunrise';
const _herGroupPost = 'First week back after the baby';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _open(WidgetTester tester, String screenId) async {
  _phone(tester);
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  await _goTo(tester, screenId);
}

Future<void> _goTo(WidgetTester tester, String screenId) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[screenId]!.name);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Another woman, with a post on her page and a post in a room, and the follow
/// that puts both in front of the tester.
Future<void> _seedNada() async {
  final store = AppRouter.communityStore;
  const card = AuthorCard(uid: _nada, name: 'Nada');
  final now = DateTime.now();

  store.profiles[_nada] = const PublicProfile(uid: _nada, name: 'Nada');
  store.posts.add(
    CommunityPost(
      postId: 'p-nada-page',
      authorCard: card,
      kind: PostKind.photo,
      audienceKeys: AudienceKeys.forAuthor(_nada),
      createdAt: now,
      caption: _herPost,
    ),
  );
  store.posts.add(
    CommunityPost(
      postId: 'p-nada-group',
      authorCard: card,
      kind: PostKind.photo,
      audienceKeys: AudienceKeys.inGroup(
        authorUid: _nada,
        groupId: 'g-postpartum',
      ),
      createdAt: now,
      groupId: 'g-postpartum',
      caption: _herGroupPost,
    ),
  );

  // Her posts reach the feed because the tester follows her. This is the real
  // write, through the real repository.
  await CommunityState.instance.toggleFollow(_nada);
}

/// Blocks her the way a woman does: the three dots on her post, then the block
/// row, which takes a second tap on purpose.
Future<void> _blockHerFromHerPost(WidgetTester tester) async {
  await _tap(tester, find.byIcon(Icons.more_vert));
  expect(
    find.text('She disappears from your feed and cannot message you'),
    findsOneWidget,
    reason: 'M08 should be open, on the row that blocks',
  );
  await _tap(
    tester,
    find.text('She disappears from your feed and cannot message you'),
  );
  await _tap(
    tester,
    find.text('She disappears from your feed and cannot message you'),
  );
}

void main() {
  final saved = AppRouter.featureFlags;

  void reset() {
    CommunityState.instance.reset();
    AppRouter.blockService.reset();
    AppRouter.communityOpenPostId = null;
    AppRouter.communityOpenGroupId = null;
    AppRouter.communityOpenProfileUid = AppRouter.communityStore.selfUid;
    AppRouter.communitySafetyUid = '';
    AppRouter.communitySafetySubject = '';
    AppRouter.communitySafetyInGroup = false;
  }

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    reset();
    // She agreed to the rules (C16) before the feed.
    PledgeState.instance.agree();
  });

  tearDown(() {
    reset();
    PledgeState.instance.reset();
    AppRouter.featureFlags = saved;
  });

  group('blocking a woman hides her', () {
    testWidgets('her post leaves the feed, and the graph is why', (
      tester,
    ) async {
      await _seedNada();
      await _open(tester, 'M01');

      expect(find.textContaining(_herPost), findsWidgets);
      expect(AppRouter.communityStore.graph.hides(_nada), isFalse);

      await _blockHerFromHerPost(tester);

      // The record and the effect, in that order. The record alone is what
      // used to be true.
      expect(AppRouter.blockService.isBlocked(_nada), isTrue);
      expect(AppRouter.communityStore.graph.hides(_nada), isTrue);

      await tester.pumpAndSettle();
      expect(find.textContaining(_herPost), findsNothing);
    });

    testWidgets('and leaves Explore with it', (tester) async {
      await _seedNada();
      await _open(tester, 'M10');
      expect(find.text(_herPost), findsOneWidget);

      await AppRouter.blockService.block(_nada, BlockSource.post);
      await _goTo(tester, 'M10');

      expect(find.text(_herPost), findsNothing);
    });

    testWidgets('and leaves the room she posted it in', (tester) async {
      await _seedNada();
      AppRouter.communityOpenGroupId = 'g-postpartum';
      await _open(tester, 'M05');
      expect(find.textContaining(_herGroupPost), findsWidgets);

      await AppRouter.blockService.block(_nada, BlockSource.post);
      await _goTo(tester, 'M05');

      expect(find.textContaining(_herGroupPost), findsNothing);
    });

    testWidgets('and her own page has nothing left on it', (tester) async {
      await _seedNada();
      AppRouter.communityOpenProfileUid = _nada;
      await _open(tester, 'M07');
      expect(find.byType(member.ProfileView), findsOneWidget);
      expect(find.textContaining(_herPost), findsWidgets);

      await AppRouter.blockService.block(_nada, BlockSource.profile);
      await _goTo(tester, 'M07');

      expect(find.textContaining(_herPost), findsNothing);
    });
  });

  group('unblocking gives her back', () {
    testWidgets('from the safety centre, and the feed shows her again', (
      tester,
    ) async {
      await _seedNada();
      await AppRouter.blockService.block(_nada, BlockSource.post);
      expect(AppRouter.communityStore.graph.hides(_nada), isTrue);

      await _open(tester, 'A04');
      expect(find.text('Blocked: 1'), findsOneWidget);

      await _tap(tester, find.text('Blocked members'));
      expect(find.text('Nada'), findsOneWidget);
      await _tap(tester, find.text('Unblock'));

      expect(AppRouter.blockService.isBlocked(_nada), isFalse);
      expect(AppRouter.communityStore.graph.hides(_nada), isFalse);

      // Close the sheet and go back to the feed she left.
      await _tap(tester, find.text('Blocked members').last);
      await _goTo(tester, 'M01');
      expect(find.textContaining(_herPost), findsWidgets);
    });
  });

  group('what blocking must never do', () {
    testWidgets('it does not take the tester\'s own posts away', (
      tester,
    ) async {
      await _seedNada();
      await AppRouter.blockService.block(_nada, BlockSource.post);

      // The exclusion list is one woman long, and it is hers.
      expect(AppRouter.communityStore.graph.hiddenAuthors, [_nada]);
      expect(
        AppRouter.communityStore.graph.hides(AppRouter.communityStore.selfUid),
        isFalse,
      );
    });

    testWidgets('and blocking herself is refused before anything hides', (
      tester,
    ) async {
      await expectLater(
        AppRouter.blockService.block(
          AppRouter.communityStore.selfUid,
          BlockSource.post,
        ),
        throwsStateError,
      );
      expect(AppRouter.communityStore.graph.hiddenAuthors, isEmpty);
    });
  });
}
