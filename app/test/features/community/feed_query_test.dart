// Rule 11's query half, and the feed's cost model.
//
// "Every factory takes an Ordering enum with exactly one value, newestFirst"
// (G10 §5). The storage half is the index exemptions, checked in
// firestore_indexes_test.dart; this is the Dart half.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/community_models.dart';
import 'package:own_hub/features/community/domain/feed_query.dart';

void main() {
  group('there is one ordering, and it is not negotiable', () {
    test('the enum has exactly one value', () {
      expect(
        FeedOrdering.values.length,
        1,
        reason:
            'a second value is the change a reviewer has to approve. There is '
            'no legitimate one: not likes, not followers, not relevance.',
      );
      expect(FeedOrdering.values.single, FeedOrdering.newestFirst);
    });

    test('every query a factory builds uses it', () {
      const feed = FeedQueryFactory();
      const explore = ExploreQueryFactory();
      final now = DateTime(2026, 9, 19);

      final queries = <FeedQuery>[
        ...feed.page(keys: <String>['a:w-1']),
        ...feed.stories(keys: <String>['a:w-1'], now: now),
        feed.group('quiet-flats'),
        feed.profile('habiba'),
        feed.followUps('post-7331'),
        feed.ownParents('me'),
        explore.grid(),
        explore.grid(topic: CommunityTopic.postpartum),
      ];

      expect(queries, isNotEmpty);
      for (final q in queries) {
        expect(q.ordering, FeedOrdering.newestFirst, reason: '$q');
      }
    });

    test('every query carries a limit', () {
      // The scalability gate's first line is "no unbounded collection scan".
      const feed = FeedQueryFactory();
      const explore = ExploreQueryFactory();

      final queries = <FeedQuery>[
        ...feed.page(keys: <String>['a:w-1']),
        feed.group('g'),
        feed.profile('habiba'),
        feed.followUps('p'),
        explore.grid(),
      ];

      for (final q in queries) {
        expect(q.limit, greaterThan(0), reason: '$q has no limit');
      }
    });
  });

  group('the feed page', () {
    const factory = FeedQueryFactory();

    test('no keys means no queries and no reads', () {
      expect(
        factory.page(keys: const <String>[]),
        isEmpty,
        reason:
            'day one issues no query at all — an empty arrayContainsAny is '
            'both an error and a read she should not be charged for',
      );
    });

    test('one chunk for a woman with an ordinary following list', () {
      final queries = factory.page(
        keys: <String>[for (var i = 0; i < 19; i++) 'a:w-$i'],
      );

      expect(queries.length, 1);
      expect(queries.single.limit, kFeedPageSize);
      expect(queries.single.visibility, PostVisibility.live);
    });

    test('four chunks for 95 women and 6 groups', () {
      final queries = factory.page(
        keys: <String>[
          for (var i = 0; i < 95; i++) 'a:w-$i',
          for (var i = 0; i < 6; i++) 'g:g-$i',
        ],
      );

      expect(queries.length, 4);
      // §2.1: ten reads per chunk per page.
      expect(queries.fold<int>(0, (n, q) => n + q.limit), 40);
    });

    test('the chunk count is capped', () {
      // A woman cannot issue an unbounded number of queries however many women
      // she follows. followingKeys is capped at 300 anyway; this is the belt.
      final queries = factory.page(
        keys: <String>[for (var i = 0; i < 600; i++) 'a:w-$i'],
      );

      expect(queries.length, lessThanOrEqualTo(kMaxFeedChunks));
    });

    test('the cursor is carried into every chunk', () {
      final cursor = DateTime(2026, 9, 18, 21);
      final queries = factory.page(
        keys: <String>[for (var i = 0; i < 61; i++) 'a:w-$i'],
        startAfter: cursor,
      );

      expect(queries.length, 3);
      for (final q in queries) {
        expect(q.startAfter, cursor);
      }
    });

    test('the stories rail asks only for unexpired stories', () {
      final now = DateTime(2026, 9, 19, 10);
      final queries = factory.stories(keys: <String>['a:w-1'], now: now);

      expect(queries.single.kind, PostKind.story);
      expect(queries.single.expiringAfter, now);
    });
  });

  group('explore', () {
    const factory = ExploreQueryFactory();

    test('a blank search issues nothing', () {
      expect(factory.searchProfiles('   '), isNull);
    });

    test('a name search is a bounded prefix range', () {
      final search = factory.searchProfiles('Hab')!;

      expect(search.prefix, 'hab');
      expect(search.upperBound, 'hac');
      expect(
        search.limit,
        lessThanOrEqualTo(30),
        reason: 'the rules refuse a publicProfiles list above limit 30',
      );
    });

    test('the grid narrows by one chip, never by a score', () {
      final q = factory.grid(topic: CommunityTopic.quiet);

      expect(q.topic, CommunityTopic.quiet);
      expect(q.ordering, FeedOrdering.newestFirst);
    });
  });
}
