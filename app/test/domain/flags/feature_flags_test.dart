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
  group('the shipped defaults are the first release, not a wish', () {
    test('what she gets on day one is on', () {
      // Everything in this list works with no server behind it, which is why
      // it can ship first.
      for (final f in [
        Feature.today,
        Feature.train,
        Feature.eat,
        Feature.progress,
        Feature.cycle,
        Feature.privacyCentre,
      ]) {
        expect(
          FeatureFlags.shipped.isOn(f),
          isTrue,
          reason: '${f.name} is built, tested, and needs nothing but a phone',
        );
      }
    });

    test('everything that needs a back end is off', () {
      // Not taste, and not sequencing for its own sake: each of these makes a
      // promise the build cannot keep on its own. An account needs somewhere
      // to live, verification needs a provider, the community needs a
      // moderator and a queue, coaching needs two real accounts and money,
      // the assistant needs a model behind a Function.
      for (final f in [
        Feature.accountRequired,
        Feature.signUp,
        Feature.verification,
        Feature.community,
        Feature.communityPosts,
        Feature.communityVideo,
        Feature.communityVoiceNotes,
        Feature.communityFollowerCounts,
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
          isFalse,
          reason:
              '${f.name} would ship a promise this build cannot keep. '
              'Turning it on is a decision about the second release, and it '
              'is a visible change to this file.',
        );
      }
    });

    test('the console is not part of the product', () {
      // It is for the people who run Own Hub. It is also compiled out of a
      // release build entirely, which `release_readiness_test.dart` holds.
      expect(FeatureFlags.shipped.isOn(Feature.adminConsole), isFalse);
    });

    test('no account is required, because there are no accounts yet', () {
      // Recorded so the position is a decision rather than an accident. Note
      // what changed with it: this flag is no longer what separates a testing
      // build from a real one, because the first release ships with it off.
      // `AppRouter.testingAidsAllowed` is the separation now.
      expect(FeatureFlags.shipped.isOn(Feature.accountRequired), isFalse);
    });

    test('the exploring shape still turns everything on', () {
      // The crawler, the journeys and the sweep use this, so a screen that is
      // dark in the first release is still opened and still proved.
      final all = FeatureFlags.everything;
      for (final f in Feature.values) {
        if (f == Feature.accountRequired) continue;
        expect(all.isOn(f), isTrue, reason: '${f.name} must still be walkable');
      }
      expect(all.isOn(Feature.accountRequired), isFalse);
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
