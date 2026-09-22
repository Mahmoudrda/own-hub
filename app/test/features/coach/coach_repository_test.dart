// The fake, and the ways it is deliberately strict.
//
// A lenient fake lets a screen pass its tests and then fail in production, which
// is the failure `InMemoryCycleRepository` and `InMemoryMealRepository` were
// both written to avoid. This one enforces the specialty cap, the capacity
// ceiling, the certificate delete rule and the read budget.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/client_view.dart';
import 'package:own_hub/features/coach/domain/coach_capacity.dart';
import 'package:own_hub/features/coach/domain/coach_credentials.dart';
import 'package:own_hub/features/coach/domain/coach_desk.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_repository.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/enquiry.dart';

const _coachUid = 'coach-1';
final _issued = DateTime(2025, 11, 4);

CertificateDraft _draft({String credentialId = 'nasm_cpt'}) =>
    CertificateDraft.validate(
      catalogue: CredentialCatalogue.dictionaryBacked,
      credentialId: credentialId,
      coachUid: _coachUid,
      mediaRef: 'coach-docs/$_coachUid/a1',
      issuedAt: _issued,
    )!;

void main() {
  group('P0-CSCALE-01 — the read budget', () {
    test('a profile read and a desk read are one each', () async {
      final repository = InMemoryCoachRepository();
      repository.resetReadCount();

      repository.profile;
      repository.desk;
      expect(repository.documentReads, 2);
    });

    test('reading the unbilled copies costs nothing, for assertions only', () {
      final repository = InMemoryCoachRepository();
      repository.resetReadCount();

      repository.profileUnbilled;
      repository.deskUnbilled;
      expect(repository.documentReads, 0);
    });

    test('a list of certificates is billed per document returned', () async {
      // The correction RECONCILIATION.md row 9 records: a range read is not
      // one read.
      final repository = InMemoryCoachRepository();
      await repository.addCertificate(_draft(), online: true);
      repository.resetReadCount();

      await repository.certificates();
      expect(repository.documentReads, 1);
    });

    test(
      'a client-view read is billed, and there is no other way in',
      () async {
        final repository = InMemoryCoachRepository();
        repository.projection.put(
          const ClientView(relId: 'coach-1_client-9', displayName: 'Rania'),
        );
        repository.resetReadCount();

        final view = await repository.forRelationship('coach-1_client-9');
        expect(view.displayName, 'Rania');
        expect(repository.documentReads, 1);
      },
    );
  });

  group('saving a profile enforces what the rules enforce', () {
    test(
      'a fourth specialty is refused by the fake, not only by the server',
      () async {
        final repository = InMemoryCoachRepository(
          profile: InMemoryCoachRepository.working(),
        );

        final result = await repository.saveProfile(
          const CoachProfileDraft(
            specialties: {
              Specialty.postpartum,
              Specialty.beginners,
              Specialty.strength,
              Specialty.pregnancy,
            },
          ),
        );

        expect(
          (result as CoachProfileRefused).reason,
          CoachProfileRefusal.tooManySpecialties,
        );
        expect(repository.profileUnbilled.specialties, hasLength(2));
      },
    );

    test('a capacity above the ceiling is refused', () async {
      final repository = InMemoryCoachRepository(
        profile: InMemoryCoachRepository.working(),
      );
      final result = await repository.saveProfile(
        const CoachProfileDraft(capacityMax: 90),
      );
      expect(result, isA<CoachProfileRefused>());
    });

    test('an accepted draft reaches the stream', () async {
      final repository = InMemoryCoachRepository(
        profile: InMemoryCoachRepository.working(),
      );
      final seen = <String>[];
      final sub = repository.watchProfile().listen((p) => seen.add(p.city));

      await repository.saveProfile(const CoachProfileDraft(city: 'Damanhur'));
      await Future<void>.delayed(Duration.zero);

      expect(seen, ['Damanhur']);
      await sub.cancel();
      await repository.dispose();
    });

    test('a device cannot write taken, however it phrases the draft', () async {
      final repository = InMemoryCoachRepository(
        profile: InMemoryCoachRepository.working(),
      );
      final before = repository.profileUnbilled.capacity.taken;

      await repository.saveProfile(const CoachProfileDraft(capacityMax: 30));
      expect(repository.profileUnbilled.capacity.max, 30);
      expect(repository.profileUnbilled.capacity.taken, before);
    });
  });

  group('certificates', () {
    test('the id is deterministic, so a replayed upload collapses', () async {
      final repository = InMemoryCoachRepository();

      await repository.addCertificate(_draft(), online: false);
      await repository.addCertificate(_draft(), online: true);

      final held = await repository.certificates();
      expect(held, hasLength(1));
      expect(held.single.state, CertificateState.uploaded);
    });

    test('with no signal it is queued and never shown as uploaded', () async {
      final repository = InMemoryCoachRepository();
      await repository.addCertificate(_draft(), online: false);

      final held = await repository.certificates();
      expect(held.single.state, CertificateState.localPending);
      expect(held.single.state.hasLeftTheDevice, isFalse);
    });

    test('she may delete an uploaded one', () async {
      final repository = InMemoryCoachRepository();
      final certificate = await repository.addCertificate(
        _draft(),
        online: true,
      );
      expect(await repository.removeCertificate(certificate.id), isTrue);
      expect(await repository.certificates(), isEmpty);
    });

    test('she may not delete one mid-review', () async {
      final repository = InMemoryCoachRepository();
      final certificate = await repository.addCertificate(
        _draft(),
        online: true,
      );
      repository.applyCertificateEvent(
        certificate.id,
        const CertificateLookupStarted(),
      );

      expect(
        await repository.removeCertificate(certificate.id),
        isFalse,
        reason: 'Never mid-review — the rules say so and the fake agrees.',
      );
    });

    test(
      'deleting something that is not there is false, not a crash',
      () async {
        final repository = InMemoryCoachRepository();
        expect(await repository.removeCertificate('nothing'), isFalse);
      },
    );
  });

  group('an enquiry commits its status and its capacity together', () {
    test('both land, or neither does', () async {
      final repository = InMemoryCoachRepository(
        profile: InMemoryCoachRepository.working(),
      );
      final enquiry = Enquiry(
        relId: relationshipId(coachUid: _coachUid, clientUid: 'client-9'),
        coachUid: _coachUid,
        clientUid: 'client-9',
        status: EnquiryStatus.enquiry,
        enquiredAt: DateTime(2026, 8, 2, 7, 18),
      );
      repository.seedEnquiry(enquiry);

      final applied = const EnquiryTransition().accept(
        enquiry: enquiry,
        capacity: repository.profileUnbilled.capacity,
        verification: CoachVerificationState.verified,
      ) as EnquiryApplied;

      await repository.commitEnquiry(applied);

      expect(repository.profileUnbilled.capacity.taken, 8);
      expect(
        (await repository.enquiry(enquiry.relId))!.status,
        EnquiryStatus.accepted,
      );
    });

    test('an enquiry nobody seeded costs no read', () async {
      final repository = InMemoryCoachRepository();
      repository.resetReadCount();

      expect(await repository.enquiry('coach-1_nobody'), isNull);
      expect(repository.documentReads, 0);
    });
  });

  group('the desk is never written by a device', () {
    test('there is no save method; the Function rebuilds it', () async {
      final repository = InMemoryCoachRepository();
      final seen = <int>[];
      final sub = repository.watchDesk().listen(
        (d) => seen.add(d.waitingCount),
      );

      repository.rebuildDesk(
        CoachDesk(
          queue: [
            DeskQueueItem(
              relId: 'r',
              displayName: 'Rania',
              reason: DeskReason.newEnquiry,
              waitingSince: DateTime(2026, 9, 8, 6),
            ),
          ],
          overflowCount: 4,
          verification: CoachVerificationState.verified,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(seen, [5]);
      await sub.cancel();
      await repository.dispose();
    });
  });

  group('the seeded coaches are not the prototype\'s coach', () {
    test('a coach mid-setup holds no claim', () {
      final profile = InMemoryCoachRepository.settingUp();
      expect(profile.verification, CoachVerificationState.setupIncomplete);
      expect(profile.capacity.isSet, isFalse);
      expect(profile.isListed, isFalse);
      expect(profile.photoBlurred, isTrue);
    });

    test(
      'a working coach has a roster unlike the mockup\'s twelve of twenty',
      () {
        final profile = InMemoryCoachRepository.working();
        expect(profile.capacity, CoachCapacity(max: 14, taken: 7));
        expect(profile.isTakingClients, isTrue);
        expect(profile.replyTimeP50Mins, 95);
      },
    );
  });
}
