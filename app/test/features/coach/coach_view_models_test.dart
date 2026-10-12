// The coach screens' behaviour, tested without pumping a frame.
//
// The group that matters most is the last one: **money is withheld rather than
// invented.** Two independent gates have to open before any figure is drawn —
// `Feature.payments`, and a statement the seam actually supplied — and there is
// no third path that produces a number.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_credentials.dart';
import 'package:own_hub/features/coach/domain/coach_desk.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_repository.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/payments.dart';
import 'package:own_hub/features/coach/presentation/coach_view_models.dart';

final _now = DateTime(2026, 9, 8, 19, 30);

/// Payments on. Its parent is `marketplace`, so both have to move — which is
/// itself the flag hierarchy working.
///
/// Built from [FeatureFlags.allOff], not from `FeatureFlags.shipped`: a helper
/// that starts from the defaults makes every "the flag is dark" case below a
/// statement about today's switch positions rather than about this screen.
final FeatureFlags _paymentsOn = FeatureFlags.allOff.with_({
  Feature.marketplace: true,
  Feature.payments: true,
});

/// Payments dark. The default for the builders below, said out loud.
final FeatureFlags _paymentsOff = FeatureFlags.allOff;

/// A statement no provider produced. Only a test may build one, and only to
/// prove the screens would draw it if a provider ever did.
EarningsStatement _statement() => EarningsStatement(
  monthKey: '2026-09',
  grossPiastres: 930000,
  sharePiastres: 744000,
  lines: const [],
  asOf: _now,
  payoutState: PayoutState.accruing,
);

DeskQueueItem _item(int n, {DeskReason reason = DeskReason.checkIn}) =>
    DeskQueueItem(
      relId: 'coach-42_client-$n',
      displayName: 'Client $n',
      reason: reason,
      waitingSince: _now.subtract(Duration(hours: n)),
    );

void main() {
  group('CoachSetupViewModel — what each step needs before it may advance', () {
    CoachSetupViewModel fresh() =>
        CoachSetupViewModel(profile: const CoachProfile());

    test('K08 needs a name and a city', () {
      final model = fresh();
      expect(model.canAdvanceFrom(CoachSetupStep.about), isFalse);

      model.displayName = 'Hala Mansour';
      expect(model.canAdvanceFrom(CoachSetupStep.about), isFalse);

      model.city = 'Tanta';
      expect(model.canAdvanceFrom(CoachSetupStep.about), isTrue);
    });

    test('K01, K10, K11 and K12 never hold her up', () {
      for (final step in [
        CoachSetupStep.photo,
        CoachSetupStep.howYouCoach,
        CoachSetupStep.results,
        CoachSetupStep.reviews,
      ]) {
        expect(fresh().canAdvanceFrom(step), isTrue, reason: step.name);
      }
    });

    test('K13 needs her agreement', () {
      final model = fresh();
      expect(model.canAdvanceFrom(CoachSetupStep.rules), isFalse);
      model.rulesAgreed = true;
      expect(model.canAdvanceFrom(CoachSetupStep.rules), isTrue);
    });

    test('K02 does not trap her — the check simply cannot start', () {
      // Trapping her on the certificates screen teaches her nothing.
      // `SetupCompleted` is what actually requires one.
      expect(fresh().canAdvanceFrom(CoachSetupStep.certificates), isTrue);
    });

    test('K03 needs at least one specialty, and caps at three', () {
      final model = fresh();
      expect(model.canAdvanceFrom(CoachSetupStep.specialties), isFalse);

      expect(model.toggleSpecialty(Specialty.postpartum), isTrue);
      expect(model.toggleSpecialty(Specialty.beginners), isTrue);
      expect(model.toggleSpecialty(Specialty.strength), isTrue);
      expect(
        model.toggleSpecialty(Specialty.weightLoss),
        isFalse,
        reason: 'the fourth is refused, and the screen is told so',
      );
      expect(model.specialties, hasLength(3));
      expect(model.canAdvanceFrom(CoachSetupStep.specialties), isTrue);
    });

    test('turning one off makes room for another', () {
      final model = fresh();
      for (final s in [
        Specialty.postpartum,
        Specialty.beginners,
        Specialty.strength,
      ]) {
        model.toggleSpecialty(s);
      }
      expect(model.toggleSpecialty(Specialty.beginners), isTrue);
      expect(model.toggleSpecialty(Specialty.pregnancy), isTrue);
      expect(model.specialties, hasLength(3));
    });

    test('K04 needs a capacity, and nothing answers it for her', () {
      final model = fresh();
      expect(model.capacityMax, isNull);
      expect(model.canAdvanceFrom(CoachSetupStep.packages), isFalse);

      model.capacityMax = 14;
      expect(model.canAdvanceFrom(CoachSetupStep.packages), isTrue);
    });

    test('K05 cannot be completed while there is no payment rail', () {
      final model = fresh();
      expect(
        model.canAdvanceFrom(CoachSetupStep.payout),
        isFalse,
        reason:
            'The seam has no implementation. Advancing here would submit her '
            'application with no way to pay her.',
      );
    });

    test('the draft it produces never carries a server-only field', () {
      final model = fresh()
        ..displayName = 'Hala Mansour'
        ..city = 'Tanta'
        ..capacityMax = 14;

      expect(CoachProfileWriteMask.allows(model.toDraft().touchedKeys), isTrue);
    });

    test('blur is on when she arrives', () {
      expect(fresh().photoBlurred, isTrue);
    });

    test('the setup event reads real state, not a button she tapped', () {
      final model = fresh()..capacityMax = 14;
      final event = model.toSetupEvent(now: _now);

      expect(event.hasCapacity, isTrue);
      expect(event.hasCertificate, isFalse);
      expect(event.hasPayoutMethod, isFalse);
      expect(event.isComplete, isFalse);
    });

    test('a certificate queued on the device does not count as submitted', () {
      final draft = CertificateDraft.validate(
        catalogue: CredentialCatalogue.dictionaryBacked,
        credentialId: 'nasm_cpt',
        coachUid: 'coach-42',
        mediaRef: 'coach-docs/coach-42/a1',
        issuedAt: DateTime(2025, 11, 4),
      )!;

      final model = fresh()..capacityMax = 14;
      model.addCertificate(
        Certificate.fromDraft(draft, id: 'c1', online: false),
      );
      expect(model.toSetupEvent(now: _now).hasCertificate, isFalse);

      model.addCertificate(
        Certificate.fromDraft(draft, id: 'c1', online: true),
      );
      expect(model.toSetupEvent(now: _now).hasCertificate, isTrue);
      expect(model.certificates, hasLength(1), reason: 'same id, replaced');
    });
  });

  group('CoachTodayViewModel — one route, three renderings', () {
    CoachTodayViewModel build({
      required int taken,
      required CoachVerificationState verification,
      List<DeskQueueItem> queue = const <DeskQueueItem>[],
      int overflow = 0,
      EarningsState earnings = const EarningsState.unavailable(
        PaymentUnavailableReason.notImplemented,
      ),
      FeatureFlags? flags,
    }) => CoachTodayViewModel.from(
      profile: CoachProfile(
        // Sixty, so the forty-client case below is expressible. A capacity
        // whose `taken` exceeds its `max` is refused by the type, which is
        // the point — and which this helper was getting wrong.
        capacity: CoachCapacity(max: 60, taken: taken),
        verification: verification,
      ),
      desk: CoachDesk(
        queue: queue,
        overflowCount: overflow,
        verification: verification,
        earnings: earnings,
      ),
      now: _now,
      flags: flags ?? _paymentsOff,
    );

    test('an empty roster and a pending check is day one, with the card', () {
      final model = build(
        taken: 0,
        verification: CoachVerificationState.humanReview,
      );
      expect(model.state, CoachTodayState.dayOneUnverified);
      expect(model.isDayOne, isTrue);
      expect(model.showsVerificationCard, isTrue);
      expect(model.rights.isAuthoringWhileUnpublished, isTrue);
    });

    test('an empty roster and a cleared coach is day one, without it', () {
      final model = build(
        taken: 0,
        verification: CoachVerificationState.verified,
      );
      expect(model.state, CoachTodayState.dayOneVerified);
      expect(model.showsVerificationCard, isFalse);
    });

    test('one client and it is K07', () {
      final model = build(
        taken: 1,
        verification: CoachVerificationState.verified,
      );
      expect(model.state, CoachTodayState.working);
      expect(model.isDayOne, isFalse);
    });

    test('the overflow counts toward what is waiting', () {
      final model = build(
        taken: 40,
        verification: CoachVerificationState.verified,
        queue: [for (var i = 1; i <= 30; i++) _item(i)],
        overflow: 9,
      );
      expect(model.rows, hasLength(30));
      expect(model.overflowCount, 9);
      expect(model.waitingCount, 39);
      expect(model.hasWork, isTrue);
    });

    test('a quiet evening has no work and is still K07', () {
      final model = build(
        taken: 11,
        verification: CoachVerificationState.verified,
      );
      expect(model.hasWork, isFalse);
      expect(model.state, CoachTodayState.working);
    });

    test('enquiries are separable from the rest of the queue', () {
      final model = build(
        taken: 3,
        verification: CoachVerificationState.verified,
        queue: [
          _item(1),
          _item(2, reason: DeskReason.newEnquiry),
        ],
      );
      expect(model.enquiries, hasLength(1));
    });

    test('the oldest wait is measured, not stated', () {
      final model = build(
        taken: 3,
        verification: CoachVerificationState.verified,
        queue: [_item(6)],
      );
      expect(model.oldestWait, const Duration(hours: 6));
    });

    test('with nobody waiting there is no wait to report', () {
      expect(
        build(
          taken: 3,
          verification: CoachVerificationState.verified,
        ).oldestWait,
        isNull,
      );
    });

    group('money is withheld rather than invented', () {
      test('no statement and the flag off: nothing', () {
        final model = build(
          taken: 3,
          verification: CoachVerificationState.verified,
        );
        expect(model.canShowMoney, isFalse);
        expect(model.statement, isNull);
      });

      test('a statement but the flag off: still nothing', () {
        final model = build(
          taken: 3,
          verification: CoachVerificationState.verified,
          earnings: EarningsState.statement(_statement()),
        );
        expect(
          model.canShowMoney,
          isFalse,
          reason: 'Feature.payments ships dark, and dark means dark.',
        );
      });

      test('the flag on but no statement: still nothing', () {
        final model = build(
          taken: 3,
          verification: CoachVerificationState.verified,
          flags: _paymentsOn,
        );
        expect(
          model.canShowMoney,
          isFalse,
          reason: 'A flag does not conjure a figure. A zero is a claim.',
        );
      });

      test('both, and only then, a figure exists', () {
        final model = build(
          taken: 3,
          verification: CoachVerificationState.verified,
          earnings: EarningsState.statement(_statement()),
          flags: _paymentsOn,
        );
        expect(model.canShowMoney, isTrue);
        expect(model.statement!.grossPiastres, 930000);
      });
    });
  });

  group('CoachEarningsViewModel — K17', () {
    test('with no rail it shows nothing and names the reason', () {
      final model = CoachEarningsViewModel.from(
        earnings: const EarningsState.unavailable(
          PaymentUnavailableReason.notImplemented,
        ),
        payout: const PayoutMethodState.unavailable(
          PaymentUnavailableReason.notImplemented,
        ),
        flags: _paymentsOn,
      );

      expect(model.canShowMoney, isFalse);
      expect(model.statement, isNull);
      expect(model.unavailableReason, PaymentUnavailableReason.notImplemented);
      expect(model.knowsDestination, isFalse);
    });

    test('with the flag dark the reason is the flag, not the provider', () {
      final model = CoachEarningsViewModel.from(
        earnings: EarningsState.statement(_statement()),
        payout: const PayoutMethodState.none(),
        flags: _paymentsOff,
      );

      expect(model.canShowMoney, isFalse);
      expect(model.statement, isNull);
      expect(model.unavailableReason, PaymentUnavailableReason.featureOff);
      expect(
        model.payoutUnavailableReason,
        PaymentUnavailableReason.featureOff,
      );
    });

    test('"she has not set one" is not the same as "we cannot tell"', () {
      final model = CoachEarningsViewModel.from(
        earnings: const EarningsState.unavailable(
          PaymentUnavailableReason.noPayoutMethod,
        ),
        payout: const PayoutMethodState.none(),
        flags: _paymentsOn,
      );

      expect(
        model.payoutUnavailableReason,
        isNull,
        reason: 'The rail answered. The answer was "none".',
      );
      expect(model.knowsDestination, isFalse);
    });

    test('a known destination is reported', () {
      final model = CoachEarningsViewModel.from(
        earnings: EarningsState.statement(_statement()),
        payout: PayoutMethodState.set(
          PayoutDestination(
            kind: PayoutKind.mobileWallet,
            holderName: 'Hala Mansour',
            maskedTail: 'xx71',
            updatedAt: _now,
          ),
        ),
        flags: _paymentsOn,
      );

      expect(model.canShowMoney, isTrue);
      expect(model.knowsDestination, isTrue);
      expect(model.destination!.maskedTail, 'xx71');
    });
  });

  group('CoachPublicProfileViewModel — K18', () {
    CoachPublicProfileViewModel build({
      CoachVerificationState verification = CoachVerificationState.verified,
      int? replyTime,
      CoachReviewSummary reviews = CoachReviewSummary.none,
      List<Certificate> certificates = const <Certificate>[],
    }) {
      final repository = InMemoryCoachRepository();
      return CoachPublicProfileViewModel.from(
        profile: CoachProfile(
          displayName: 'Hala Mansour',
          city: 'Tanta',
          capacity: CoachCapacity(max: 14, taken: 6),
          verification: verification,
          replyTimeP50Mins: replyTime,
        ),
        offers: repository,
        certificates: certificates,
        now: _now,
        reviews: reviews,
      );
    }

    test('a reply time nobody measured makes no claim', () {
      expect(build().showsReplyTime, isFalse);
      expect(build().replyTimeMinutes, isNull);
      expect(build(replyTime: 95).showsReplyTime, isTrue);
    });

    test('a rating under five reviews is not shown', () {
      expect(
        build(reviews: const CoachReviewSummary(count: 4, average: 5.0))
            .showsRating,
        isFalse,
      );
      expect(
        build(reviews: const CoachReviewSummary(count: 5, average: 4.2)).rating,
        4.2,
      );
    });

    test('the badge follows a cleared certificate, not a submitted one', () {
      final uploaded = Certificate(
        id: 'c1',
        credentialId: 'nasm_cpt',
        mediaRef: 'coach-docs/coach-42/a',
        issuedAt: DateTime(2025, 11, 4),
        state: CertificateState.uploaded,
      );
      expect(build(certificates: [uploaded]).showsVerifiedBadge, isFalse);
      expect(
        build(
          certificates: [uploaded.copyWith(state: CertificateState.verified)],
        ).showsVerifiedBadge,
        isTrue,
      );
    });

    test('a coach under review sees her page and is told it is not live', () {
      final model = build(verification: CoachVerificationState.humanReview);
      expect(model.isLive, isFalse);
      expect(model.rights.mayAuthor, isTrue);
      expect(model.rights.mayPublish, isFalse);
    });

    test('an expired coach keeps her page', () {
      expect(
        build(verification: CoachVerificationState.expired).isLive,
        isTrue,
      );
    });

    test('it reads offers and has no way to write one', () {
      final model = build();
      expect(model.offers, isEmpty);
      expect(model.publishedOffers, isEmpty);
    });
  });
}
