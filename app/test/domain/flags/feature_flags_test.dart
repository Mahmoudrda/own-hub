// Feature flags exist so a feature can ship dark. These tests hold the two
// properties that make that safe: a sub-feature cannot outlive its parent, and
// an unset flag is OFF rather than accidentally on.
//
// `FeatureFlags.shipped` is read in exactly one group here — the first one,
// whose subject *is* the defaults. Everywhere else the world under test is
// built from `FeatureFlags.allOff` and the switches the case needs are turned
// on by name. A property of the type ("a child cannot outlive its parent")
// that borrows its precondition from today's defaults is not testing the
// property; it is testing the defaults, and it breaks the day they move.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';

void main() {
  group('the shipped defaults match what is actually built', () {
    test('Phase 1 and Phase 2 are on', () {
      for (final f in [
        Feature.signUp,
        Feature.verification,
        Feature.today,
        Feature.train,
        Feature.eat,
        Feature.progress,
        Feature.cycle,
        Feature.privacyCentre,
        Feature.adminConsole,
      ]) {
        expect(
          FeatureFlags.shipped.isOn(f),
          isTrue,
          reason: '${f.name} is built and tested; it should not be dark',
        );
      }
    });

    test("every Phase 3 feature is on, at the owner's instruction", () {
      for (final f in [
        Feature.community,
        Feature.coachApp,
        Feature.coachPlanning,
        Feature.coachPortfolio,
        Feature.coachedLife,
        Feature.marketplace,
        Feature.payments,
        Feature.assistant,
      ]) {
        expect(
          FeatureFlags.shipped.isOn(f),
          isTrue,
          reason:
              '${f.name} was switched on deliberately. This still guards '
              'against drift: a feature that goes dark by accident, rather '
              'than by decision, fails here.',
        );
      }
    });

    test("no account is required, at the owner's instruction, for testing", () {
      // Recorded so the position is a decision, not an accident — and so
      // switching it back on before a public release is a visible change to
      // this file. With it off, anyone who installs the app is inside.
      expect(FeatureFlags.shipped.isOn(Feature.accountRequired), isFalse);
    });

    test('the community scope is recorded, not decided later', () {
      // The owner has switched all four on. Recorded here so the position is
      // a decision rather than an accident -- and so that turning any of them
      // back off is a visible change to this file.
      //
      // TWO OF THESE HAVE NOTHING BEHIND THEM. `communityVideo` and
      // `communityVoiceNotes` render their controls, and the feature has no
      // capture, no blur export and no transcode. See the library doc on
      // `Feature` in `lib/domain/flags/feature_flags.dart`.
      const f = FeatureFlags.shipped;
      expect(f.isSetOn(Feature.communityPosts), isTrue);
      expect(f.isSetOn(Feature.communityVideo), isTrue);
      expect(f.isSetOn(Feature.communityVoiceNotes), isTrue);
      expect(f.isSetOn(Feature.communityFollowerCounts), isTrue);
    });
  });

  group('a sub-feature can never outlive its parent', () {
    test('community off hides every community sub-feature', () {
      // Even though posts are SET on, community being off makes them
      // unreachable. "Community is off but posting is on" is not a state
      // anyone means, so it is not a state this type can be in.
      final f = FeatureFlags.allOff.with_({Feature.communityPosts: true});
      expect(f.isSetOn(Feature.communityPosts), isTrue);
      expect(f.isOn(Feature.communityPosts), isFalse);
      expect(f.isOn(Feature.communityVideo), isFalse);
    });

    test('turning the parent on reveals exactly the intended children', () {
      // The launch scope, stated rather than borrowed: photos and text set
      // on, video, voice notes and follower counts left off.
      final launchScope = FeatureFlags.allOff.with_({
        Feature.communityPosts: true,
      });
      final f = launchScope.with_({Feature.community: true});
      expect(f.isOn(Feature.community), isTrue);
      expect(
        f.isOn(Feature.communityPosts),
        isTrue,
        reason: 'photos and text are the launch scope',
      );
      expect(
        f.isOn(Feature.communityVideo),
        isFalse,
        reason: 'video stays deferred until blur export is measured',
      );
      expect(f.isOn(Feature.communityVoiceNotes), isFalse);
      expect(
        f.isOn(Feature.communityFollowerCounts),
        isFalse,
        reason: 'nothing in this product ranks women',
      );
    });

    test('payments cannot be reached without the marketplace', () {
      final f = FeatureFlags.allOff.with_({Feature.payments: true});
      expect(f.isSetOn(Feature.payments), isTrue);
      expect(
        f.isOn(Feature.payments),
        isFalse,
        reason:
            'a payment screen with no marketplace around it is a checkout for '
            'nothing',
      );

      final both = f.with_({Feature.marketplace: true});
      expect(both.isOn(Feature.payments), isTrue);
    });

    test('every child declares a parent that is itself a real feature', () {
      // Guards against a typo making an orphan that is always reachable.
      for (final f in Feature.values) {
        final p = f.parent;
        if (p != null) {
          expect(Feature.values, contains(p), reason: '${f.name} parent');
          expect(p, isNot(f), reason: '${f.name} is its own parent');
        }
      }
    });

    test('the parent chain terminates', () {
      // A cycle would hang isOn(). Walk every chain with a bound.
      for (final f in Feature.values) {
        var steps = 0;
        for (Feature? c = f; c != null; c = c.parent) {
          steps++;
          expect(steps, lessThan(10), reason: 'cycle in ${f.name} parent chain');
        }
      }
    });
  });

  group('an unset flag is off', () {
    test('a flags object that mentions nothing enables nothing', () {
      const empty = FeatureFlags(<Feature, bool>{});
      for (final f in Feature.values) {
        expect(empty.isOn(f), isFalse, reason: f.name);
      }
    });

    test('allOff really is all off', () {
      expect(FeatureFlags.allOff.enabled, isEmpty);
    });

    test('an override does not disturb its neighbours', () {
      final base = FeatureFlags.allOff.with_({Feature.today: true});
      final f = base.with_({Feature.assistant: true});
      expect(f.isOn(Feature.assistant), isTrue);
      expect(f.isOn(Feature.community), isFalse);
      expect(f.isOn(Feature.today), isTrue);
    });
  });

  group('the set is coherent', () {
    test('enabled lists exactly the features isOn agrees with', () {
      final f = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.community: true,
        Feature.communityPosts: true,
        Feature.marketplace: true,
        Feature.payments: true,
      });
      for (final feature in Feature.values) {
        expect(
          f.enabled.contains(feature),
          f.isOn(feature),
          reason: feature.name,
        );
      }
    });

    test('flags are immutable — with_ returns a new object', () {
      final before = FeatureFlags.allOff;
      final after = before.with_({Feature.community: true});
      expect(before.isOn(Feature.community), isFalse);
      expect(after.isOn(Feature.community), isTrue);
    });
  });
}
