// P0-COM-03 — "Community, day one is a state not a route."
//
// Two halves. The routing half is that M17 is in firstRunStates and therefore
// absent from appDestinations, so nothing can navigate to it. The rendering
// half is that the Community tab picks one of four states, M17 among them.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/community_tab_state.dart';
import 'package:own_hub/routing/app_router.dart';

void main() {
  group('M17 is not a destination', () {
    test('it is a first-run state', () {
      expect(
        firstRunStates,
        contains('M17'),
        reason: 'HANDOFF 16: first-run screens are states, not destinations',
      );
    });

    test('so nothing can route to it', () {
      expect(
        appDestinations.containsKey('M17'),
        isFalse,
        reason:
            'P0-COM-03: back from the day-one state must exit the tab. If M17 '
            'were a destination something could push it, and back would return '
            'to an empty feed.',
      );
      expect(screenIdForRoute('/community/m17'), isNull);
    });

    test('the other community screens ARE destinations', () {
      // A negative control for the assertion above: if every community id were
      // missing from appDestinations, the M17 check would pass for the wrong
      // reason.
      for (final id in <String>['M01', 'M02', 'M04', 'M07', 'M15']) {
        expect(
          appDestinations.containsKey(id),
          isTrue,
          reason: '$id is a real screen and must be routable',
        );
      }
    });
  });

  group('the tab picks one of four renderings', () {
    test('day one — she follows nobody and joined nothing', () {
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 0,
          groupKeyCount: 0,
          firstPagePostCount: 0,
        ),
        CommunityTabState.dayOne,
      );
    });

    test('joined, but nobody has posted yet', () {
      // A different message and a different smallest action: post the first
      // thing, rather than join a group.
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 0,
          groupKeyCount: 2,
          firstPagePostCount: 0,
        ),
        CommunityTabState.joinedOnly,
      );
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 3,
          groupKeyCount: 0,
          firstPagePostCount: 0,
        ),
        CommunityTabState.joinedOnly,
      );
    });

    test('ready, once there is anything to read', () {
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 3,
          groupKeyCount: 1,
          firstPagePostCount: 7,
        ),
        CommunityTabState.ready,
      );
    });

    test('offline and cold is a state, not an error', () {
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 3,
          groupKeyCount: 1,
          firstPagePostCount: 0,
          online: false,
        ),
        CommunityTabState.offlineCold,
      );
    });

    test('a cached page still reads, with no signal', () {
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 3,
          groupKeyCount: 0,
          firstPagePostCount: 4,
          online: false,
          hasCachedPage: true,
        ),
        CommunityTabState.ready,
        reason:
            'G8 offline contract: the last cached page renders at full '
            'fidelity rather than as a failure',
      );
    });

    test('offline beats day one', () {
      // A woman with no signal AND no follows is offline-cold. Offering her
      // "join a group" would be an empty state that lies about what is
      // possible right now.
      expect(
        CommunityTabState.resolve(
          followingKeyCount: 0,
          groupKeyCount: 0,
          firstPagePostCount: 0,
          online: false,
        ),
        CommunityTabState.offlineCold,
      );
    });

    test('two of the four are onboarding surfaces', () {
      // HANDOFF 17: the empty state IS the onboarding. There is no tour.
      expect(CommunityTabState.dayOne.isEmptyState, isTrue);
      expect(CommunityTabState.joinedOnly.isEmptyState, isTrue);
      expect(CommunityTabState.ready.isEmptyState, isFalse);
      expect(CommunityTabState.offlineCold.isEmptyState, isFalse);
    });
  });
}
