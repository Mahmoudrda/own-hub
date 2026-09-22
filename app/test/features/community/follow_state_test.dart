// P0-COM-13 — "Nothing anywhere tells A she has been blocked."
//
// The strongest form of that guarantee is not a rule about copy; it is that the
// information never reaches a screen. A blocked woman and a woman who turned her
// profile off produce the SAME value here, so a view cannot render them
// differently even by accident.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/community/domain/follow_state.dart';

const _resolver = FollowStateResolver();

FollowState _state({
  String viewer = 'me',
  String other = 'habiba',
  bool isFollowing = false,
  bool hiddenEitherWay = false,
  bool profileDiscoverable = true,
  bool pendingLocal = false,
}) => _resolver.resolve(
  viewerUid: viewer,
  otherUid: other,
  isFollowing: isFollowing,
  hiddenEitherWay: hiddenEitherWay,
  profileDiscoverable: profileDiscoverable,
  pendingLocal: pendingLocal,
);

void main() {
  group('there is no such thing as a blocked rendering', () {
    test('no state is named after blocking', () {
      final names = FollowState.values.map((v) => v.name).join(' ');

      expect(
        RegExp('block', caseSensitive: false).hasMatch(names),
        isFalse,
        reason:
            'G10 §6.1: every blocked surface renders the ordinary "not '
            'available", never "you are blocked". A value named blocked is a '
            'value a screen can branch on.',
      );
    });

    test('a block and a hidden profile are the same value', () {
      final blocked = _state(hiddenEitherWay: true);
      final hidden = _state(profileDiscoverable: false);

      expect(blocked, FollowState.unavailable);
      expect(hidden, FollowState.unavailable);
      expect(
        blocked,
        hidden,
        reason:
            'the collapse IS the guarantee. A distinguishable blocked state — '
            'even a different icon — is a side channel that tells a woman who '
            'blocked her.',
      );
    });

    test('being blocked outranks following', () {
      // She followed her before the block. The button must not keep reading
      // "Following", which would be a working relationship she does not have.
      expect(
        _state(isFollowing: true, hiddenEitherWay: true),
        FollowState.unavailable,
      );
    });

    test('being blocked outranks a pending offline follow', () {
      expect(
        _state(pendingLocal: true, hiddenEitherWay: true),
        FollowState.unavailable,
      );
    });

    test('the whole surface collapses the same way', () {
      expect(
        _resolver.surfaceFor(profileExists: false),
        SurfaceAvailability.notAvailable,
      );
      expect(
        _resolver.surfaceFor(profileExists: true, hiddenEitherWay: true),
        SurfaceAvailability.notAvailable,
      );
      expect(
        _resolver.surfaceFor(profileExists: true),
        SurfaceAvailability.available,
      );
    });

    test('she cannot be contacted, and no reason comes back', () {
      // mayContact returns a bare bool. A Result carrying "because you are
      // blocked" would be exactly the leak this file prevents.
      expect(_resolver.mayContact(hiddenEitherWay: true), isFalse);
      expect(_resolver.mayContact(hiddenEitherWay: false), isTrue);
    });
  });

  group('the four ordinary renderings', () {
    test('her own profile gets no button at all', () {
      expect(_state(viewer: 'me', other: 'me'), FollowState.self);
    });

    test('not following, following, and queued offline', () {
      expect(_state(), FollowState.notFollowing);
      expect(_state(isFollowing: true), FollowState.following);
      expect(_state(pendingLocal: true), FollowState.pendingLocal);
    });

    test('self wins over everything, including a block', () {
      // She cannot block herself, so this is defensive — but a "not available"
      // on her own profile would be a strange and alarming thing to ship.
      expect(
        _state(viewer: 'me', other: 'me', hiddenEitherWay: true),
        FollowState.self,
      );
    });

    test('there are exactly five renderings', () {
      // G10 §3.8 names five. A sixth would be someone adding a state the
      // guarantee above did not anticipate.
      expect(FollowState.values.length, 5);
    });
  });
}
