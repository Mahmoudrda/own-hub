// Rule 11 — displayed, never ranked — and the two numbers that are not the same.
//
// The lift figures below are deliberately unlike the prototype's "12 kg x 10":
// a test written on the mockup's own sample cannot tell a projection from a
// constant. PHASE1-FIXES.md §8 is the precedent — five assertions passed
// byte-identically before and after a real defect, because the default fixture
// was the sample.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/account/domain/public_profile_projection.dart';

void main() {
  const bests = [
    PublicBest(exerciseId: 'goblet_squat', loadKg: 23, reps: 6),
    PublicBest(exerciseId: 'hip_thrust', loadKg: 41, reps: 8),
  ];

  group('profileVisible governs whether she appears at all', () {
    test('off by default, so a new account is not published', () {
      final profile = PublicProfileProjection.build(
        settings: PrivacySettings.initial,
        firstName: 'Nadia',
        verified: true,
        bests: bests,
      );

      expect(profile.visible, isFalse);
      expect(
        profile.firstName,
        isNull,
        reason:
            'hidden is ABSENT, not blanked — a profile rendered with her name '
            'removed would still confirm the account exists',
      );
      expect(profile.bests, isEmpty);
    });

    test('on, she appears with the allowlisted fields', () {
      const settings = PrivacySettings(profileVisible: true, showBests: true);

      final profile = PublicProfileProjection.build(
        settings: settings,
        firstName: 'Nadia',
        verified: true,
        groups: const ['home_workouts'],
        bests: bests,
      );

      expect(profile.visible, isTrue);
      expect(profile.firstName, 'Nadia');
      expect(profile.verified, isTrue);
      expect(profile.groups, ['home_workouts']);
      expect(profile.bests, hasLength(2));
    });
  });

  group('showBests is independent of profileVisible', () {
    test('visible with bests off publishes her, without her numbers', () {
      const settings = PrivacySettings(profileVisible: true);

      final profile = PublicProfileProjection.build(
        settings: settings,
        firstName: 'Nadia',
        bests: bests,
      );

      expect(profile.visible, isTrue);
      expect(profile.firstName, 'Nadia');
      expect(
        profile.bests,
        isEmpty,
        reason:
            'emptied at projection time rather than filtered at render time, '
            'so a screen cannot accidentally read past it',
      );
    });

    test('bests on but profile hidden publishes nothing', () {
      const settings = PrivacySettings(showBests: true);

      final profile = PublicProfileProjection.build(
        settings: settings,
        firstName: 'Nadia',
        bests: bests,
      );

      expect(profile.visible, isFalse);
      expect(profile.bests, isEmpty);
    });

    test('each switch changes only its own half of the projection', () {
      const both = PrivacySettings(profileVisible: true, showBests: true);
      const visibleOnly = PrivacySettings(profileVisible: true);

      final withBests = PublicProfileProjection.build(
        settings: both,
        firstName: 'Nadia',
        bests: bests,
      );
      final withoutBests = PublicProfileProjection.build(
        settings: visibleOnly,
        firstName: 'Nadia',
        bests: bests,
      );

      // One field differs. Nothing else moved.
      expect(withBests.firstName, withoutBests.firstName);
      expect(withBests.visible, withoutBests.visible);
      expect(withBests.bests, hasLength(2));
      expect(withoutBests.bests, isEmpty);
    });
  });

  group('rule 11 — her body is not in the type', () {
    test('a published best carries a lift, never a scale weight', () {
      // The distinction the whole rule depends on: `loadKg` is what she lifted
      // and is exactly what A03's "numbers only, never weight from a scale" is
      // offering. There is no field on PublicBest or PublicProfile that could
      // carry measurements.weightKg or measurements.body.
      const best = PublicBest(exerciseId: 'goblet_squat', loadKg: 23, reps: 6);

      expect(best.loadKg, 23);
      expect(best.reps, 6);
      expect(best.exerciseId, 'goblet_squat');
    });

    test('the projection cannot be asked to publish a measurement', () {
      // `build` is the allowlist. Publishing her weight would take a new
      // parameter, a new field and a new line — all three visible in a diff,
      // rather than one strip step somebody forgot.
      const settings = PrivacySettings(profileVisible: true, showBests: true);

      final profile = PublicProfileProjection.build(
        settings: settings,
        firstName: 'Nadia',
        verified: true,
        groups: const ['home_workouts'],
        bests: bests,
      );

      // Everything published, enumerated. If this list ever grows, it grows
      // deliberately.
      expect(profile.firstName, isNotNull);
      expect(profile.verified, isTrue);
      expect(profile.groups, hasLength(1));
      expect(profile.bests, hasLength(2));
      expect(profile.visible, isTrue);
    });

    test('published lists cannot be mutated by a consumer', () {
      const settings = PrivacySettings(profileVisible: true, showBests: true);

      final profile = PublicProfileProjection.build(
        settings: settings,
        bests: bests,
        groups: const ['home_workouts'],
      );

      expect(
        () => profile.bests.add(
          const PublicBest(exerciseId: 'x', loadKg: 1, reps: 1),
        ),
        throwsUnsupportedError,
      );
      expect(() => profile.groups.add('another'), throwsUnsupportedError);
    });
  });
}
