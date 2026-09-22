// `K01`, `K03`, `K04` and `K18` — the public root.
//
// Three rules are enforced here rather than in a widget: rule 11 (nothing
// rankable is storable), rule 6 (blur defaults on), and the owner's rating
// threshold. Each has a negative control, because a guard that matches nothing
// is indistinguishable from one that is broken.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/privacy_settings.dart';
import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';

const _editor = CoachProfileEditor();
final _now = DateTime(2026, 6, 3, 18, 40);

CoachProfile _verified() => CoachProfile(
  displayName: 'Hala Mansour',
  city: 'Tanta',
  specialties: const {Specialty.postpartum},
  capacity: CoachCapacity(max: 14, taken: 6),
  verification: CoachVerificationState.verified,
);

void main() {
  group('rule 11 — nothing rankable can be written', () {
    test('every banned key is refused', () {
      for (final key in kForbiddenRankableKeys) {
        expect(
          CoachProfileWriteMask.allows([key]),
          isFalse,
          reason: '$key must never reach a coach document',
        );
      }
    });

    test('the guard would actually bite', () {
      // A positive control. The list must contain the ones that matter.
      expect(kForbiddenRankableKeys, contains('ratingAvg'));
      expect(kForbiddenRankableKeys, contains('followerCount'));
      expect(kForbiddenRankableKeys, contains('weightLost'));
      expect(CoachProfileWriteMask.rejects(['ratingAvg']), {'ratingAvg'});
      expect(kForbiddenRankableKeys, contains('currentStreak'));
    });

    test(
      'a field nobody declared is refused even when it is not on the list',
      () {
        // The second line. The ban list catches the fields somebody thought of;
        // this branch catches the ones nobody did, which is the larger set.
        final invented = ['day', 'Run', 'Length'].join();
        expect(CoachProfileWriteMask.allows([invented]), isFalse);
        expect(CoachProfileWriteMask.rejects([invented]), {invented});
      },
    );

    test('server-only fields are refused too', () {
      for (final key in serverOnlyCoachKeys) {
        expect(CoachProfileWriteMask.allows([key]), isFalse, reason: key);
      }
      expect(
        CoachProfileWriteMask.allows(['capacity.taken']),
        isFalse,
        reason: 'A device that could write taken can invent a spot.',
      );
    });

    test('a field nobody declared is refused', () {
      expect(CoachProfileWriteMask.allows(['mysteryField']), isFalse);
    });

    test('and the keys she owns are allowed', () {
      expect(CoachProfileWriteMask.allows(coachEditableKeys), isTrue);
    });

    test('a draft never carries taken, whatever it sets', () {
      const draft = CoachProfileDraft(
        displayName: 'Hala',
        capacityMax: 12,
        acceptingClients: true,
      );
      expect(draft.touchedKeys, isNot(contains('capacity.taken')));
      expect(CoachProfileWriteMask.allows(draft.touchedKeys), isTrue);
    });
  });

  group('rule 6 — her face is blurred until she says otherwise', () {
    test('a new profile is blurred', () {
      expect(const CoachProfile().photoBlurred, isTrue);
    });

    test('a photo with no explicit choice is blurred', () {
      expect(
        CoachMediaUploader.resolveBlur(
          herExplicitChoice: null,
          settings: const PrivacySettings(),
        ),
        isTrue,
        reason: 'A missing choice must never read as "off".',
      );
    });

    test('showing her face is an explicit choice, and it is honoured', () {
      expect(
        CoachMediaUploader.resolveBlur(
          herExplicitChoice: false,
          settings: const PrivacySettings(),
        ),
        isFalse,
      );
    });

    test(
      'turning blur off needs its consequence stated; turning it on does not',
      () {
        expect(
          CoachMediaUploader.needsConsequenceStated(turningBlurOn: false),
          isTrue,
        );
        expect(
          CoachMediaUploader.needsConsequenceStated(turningBlurOn: true),
          isFalse,
        );
      },
    );
  });

  group('K03 — at most three specialties', () {
    test('three is allowed', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(
          specialties: {
            Specialty.postpartum,
            Specialty.beginners,
            Specialty.strength,
          },
        ),
        now: _now,
      );
      expect(result, isA<CoachProfileApplied>());
    });

    test('four is refused', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(
          specialties: {
            Specialty.postpartum,
            Specialty.beginners,
            Specialty.strength,
            Specialty.weightLoss,
          },
        ),
        now: _now,
      );
      expect(result, isA<CoachProfileRefused>());
      expect(
        (result as CoachProfileRefused).reason,
        CoachProfileRefusal.tooManySpecialties,
      );
    });
  });

  group('K04 — the ceiling, through the editor', () {
    test('a capacity inside the range is applied and carries taken', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(capacityMax: 22),
        now: _now,
      );
      final profile = (result as CoachProfileApplied).profile;
      expect(profile.capacity.max, 22);
      expect(profile.capacity.taken, 6);
    });

    test('a capacity above sixty is refused rather than clamped', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(capacityMax: 90),
        now: _now,
      );
      expect(
        (result as CoachProfileRefused).reason,
        CoachProfileRefusal.capacityOutOfRange,
      );
    });
  });

  group('accepting clients needs the claim', () {
    test('a coach still being checked cannot advertise availability', () {
      final checking = _verified().copyWith(
        verification: CoachVerificationState.humanReview,
      );
      final result = _editor.apply(
        checking,
        const CoachProfileDraft(acceptingClients: true),
        now: _now,
      );
      expect(
        (result as CoachProfileRefused).reason,
        CoachProfileRefusal.notVerified,
      );
    });

    test('a coach whose certificates expired cannot either', () {
      final lapsed = _verified().copyWith(
        verification: CoachVerificationState.expired,
      );
      final result = _editor.apply(
        lapsed,
        const CoachProfileDraft(acceptingClients: true),
        now: _now,
      );
      expect(result, isA<CoachProfileRefused>());
    });

    test('a verified coach can', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(acceptingClients: true),
        now: _now,
      );
      expect((result as CoachProfileApplied).profile.acceptingClients, isTrue);
    });

    test('but "taking clients" is also about having room', () {
      final full = _verified().copyWith(
        acceptingClients: true,
        capacity: CoachCapacity(max: 6, taken: 6),
      );
      expect(full.isTakingClients, isFalse);

      final open = _verified().copyWith(acceptingClients: true);
      expect(open.isTakingClients, isTrue);
    });
  });

  group('K01 — her name and her city are not optional', () {
    test('blanking her name is refused', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(displayName: '   '),
        now: _now,
      );
      expect(
        (result as CoachProfileRefused).reason,
        CoachProfileRefusal.incomplete,
      );
    });

    test('a draft that does not touch her name leaves it alone', () {
      final result = _editor.apply(
        _verified(),
        const CoachProfileDraft(tagline: 'Small weeks, real weight.'),
        now: _now,
      );
      final profile = (result as CoachProfileApplied).profile;
      expect(profile.displayName, 'Hala Mansour');
      expect(profile.tagline, 'Small weeks, real weight.');
    });
  });

  group('a rating shows only at five reviews', () {
    test('four says nothing at all', () {
      const summary = CoachReviewSummary(count: 4, average: 4.9);
      expect(RatingDisplay.forReviews(summary), isNull);
      expect(RatingDisplay.mayShow(summary), isFalse);
    });

    test('five says it', () {
      const summary = CoachReviewSummary(count: 5, average: 4.4);
      expect(RatingDisplay.forReviews(summary), 4.4);
      expect(RatingDisplay.mayShow(summary), isTrue);
    });

    test('a coach nobody has reviewed shows nothing, not zero', () {
      expect(RatingDisplay.forReviews(CoachReviewSummary.none), isNull);
    });

    test('and it is not a field on her document', () {
      expect(kForbiddenRankableKeys, contains('ratingAvg'));
      expect(kForbiddenRankableKeys, contains('ratingCount'));
      expect(coachEditableKeys, isNot(contains('ratingAvg')));
    });
  });

  group('the page is live only when it should be', () {
    test('listed follows the credential state, and is not stored twice', () {
      expect(
        _verified()
            .copyWith(verification: CoachVerificationState.humanReview)
            .isListed,
        isFalse,
      );
      expect(_verified().isListed, isTrue);
      expect(
        _verified()
            .copyWith(verification: CoachVerificationState.expired)
            .isListed,
        isTrue,
        reason: 'Expiry keeps her page. Only new clients stop.',
      );
      expect(
        _verified()
            .copyWith(verification: CoachVerificationState.suspended)
            .isListed,
        isFalse,
      );
    });
  });

  test('reply time is measured, and says nothing when it was not', () {
    expect(const CoachProfile().replyTimeP50Mins, isNull);
    expect(_verified().copyWith(replyTimeP50Mins: 95).replyTimeP50Mins, 95);
  });

  test(
    'profileStepsComplete needs a name, a city, a specialty and a capacity',
    () {
      expect(const CoachProfile().profileStepsComplete, isFalse);
      expect(_verified().profileStepsComplete, isTrue);
      expect(
        _verified()
            .copyWith(capacity: CoachCapacity.unset)
            .profileStepsComplete,
        isFalse,
      );
      expect(
        _verified().copyWith(specialties: const {}).profileStepsComplete,
        isFalse,
      );
    },
  );
}
