// Implements the "everything earned is kept" half of TEST-CASES.csv
// P0-WEEK-03 ("A tier slips, shown once").
//
// This is the test that makes T05's promise checkable. The sheet says "Kept, all
// of it" and lists what she keeps; the reason that is true is that unlocks read
// the monotonic earnedTier and never the display label. A one-character change
// to unlock_policy.dart would break the promise silently on a screen whose whole
// purpose is to reassure, and no screenshot could show it.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/unlock_policy.dart';

/// Invented for this test. No unlock list is authored — see D6.
const UnlockPolicy _policy = UnlockPolicy(<Unlock>[
  Unlock(id: 'quiet_mode', opensAt: Tier.showingUp),
  Unlock(id: 'week_plan', opensAt: Tier.regular),
  Unlock(id: 'custom_split', opensAt: Tier.strong),
]);

void main() {
  group('P0-WEEK-03 — a slipped label closes nothing', () {
    // She earned Regular and her label has slipped to Showing up.
    const slipped = TierStanding(
      earned: Tier.regular,
      display: Tier.showingUp,
      slipped: true,
    );

    test('everything the earned tier opened is still open', () {
      expect(_policy.isUnlocked('quiet_mode', slipped), isTrue);
      expect(
        _policy.isUnlocked('week_plan', slipped),
        isTrue,
        reason:
            'week_plan opens at Regular, which she earned. If this reads the '
            'display tier it returns false and T05 becomes a lie.',
      );
    });

    test('a tier she never reached is still shut', () {
      expect(_policy.isUnlocked('custom_split', slipped), isFalse);
    });

    test('the kept list is everything at or below the earned tier', () {
      final opened = _policy.openedFor(slipped).map((u) => u.id).toList();
      expect(opened, ['quiet_mode', 'week_plan']);
    });

    test('slipping changes nothing about what is open', () {
      const held = TierStanding(earned: Tier.regular, display: Tier.regular);

      for (final id in ['quiet_mode', 'week_plan', 'custom_split']) {
        expect(
          _policy.isUnlocked(id, slipped),
          _policy.isUnlocked(id, held),
          reason: '$id changed when only the label moved',
        );
      }
    });
  });

  group('it fails closed', () {
    test('an unknown feature is not unlocked', () {
      const standing = TierStanding(
        earned: Tier.unshakeable,
        display: Tier.unshakeable,
      );
      expect(
        _policy.isUnlocked('a_feature_nobody_assigned_a_tier', standing),
        isFalse,
        reason:
            'a feature that should be open and is not gets reported; one that '
            'should be shut and is open is a promise quietly broken',
      );
    });

    test('an unknown tier unlocks nothing', () {
      // The shipped case: no ladder is authored, so there is no earned tier.
      expect(_policy.isUnlocked('quiet_mode', TierStanding.unknown), isFalse);
      expect(_policy.openedFor(TierStanding.unknown), isEmpty);
    });

    test('the shipped unlock list is empty', () {
      expect(UnlockPolicy.unauthored.isAuthored, isFalse);
      const anyTier = TierStanding(
        earned: Tier.unshakeable,
        display: Tier.unshakeable,
      );
      expect(
        UnlockPolicy.unauthored.isUnlocked('quiet_mode', anyTier),
        isFalse,
      );
    });
  });
}
