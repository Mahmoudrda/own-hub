// `K02` — certificates, and `P0-CVER-05`.
//
// The load-bearing assertion is the first group: a coach cannot claim a
// credential she does not hold, because there is no text field to type one into
// and no id that resolves outside the catalogue.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_credentials.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';

const _coachUid = 'coach-42';
final _issued = DateTime(2025, 11, 4);
final _expires = DateTime(2028, 11, 4);
final _decidedAt = DateTime(2026, 2, 19, 9, 12);

ReviewerDecision _aWoman() => ReviewerDecision(
  reviewerId: 'rev-31',
  reviewedByWoman: true,
  decidedAt: _decidedAt,
);

CertificateDraft _draft({
  String credentialId = 'nasm_cpt',
  String? mediaRef,
  DateTime? expiresAt,
  CredentialCatalogue catalogue = CredentialCatalogue.dictionaryBacked,
}) {
  final draft = CertificateDraft.validate(
    catalogue: catalogue,
    credentialId: credentialId,
    coachUid: _coachUid,
    mediaRef: mediaRef ?? 'coach-docs/$_coachUid/a1b2c3',
    issuedAt: _issued,
    expiresAt: expiresAt,
  );
  return draft!;
}

void main() {
  group('a certificate is an id, never a sentence', () {
    test('the catalogue nobody wrote is empty, and says so', () {
      expect(CredentialCatalogue.unauthored.isAuthored, isFalse);
      expect(CredentialCatalogue.unauthored.count, 0);
    });

    test('only credentials the dictionary can name are offered', () {
      // One. Every other credential the dictionary mentions is inside a
      // composite sentence that cannot be reused as a name.
      expect(CredentialCatalogue.dictionaryBacked.count, 1);
      expect(CredentialCatalogue.dictionaryBacked.contains('nasm_cpt'), isTrue);
    });

    test('a credential outside the catalogue cannot be drafted', () {
      final typed = CertificateDraft.validate(
        catalogue: CredentialCatalogue.dictionaryBacked,
        credentialId: 'international_master_trainer_gold',
        coachUid: _coachUid,
        mediaRef: 'coach-docs/$_coachUid/x9',
        issuedAt: _issued,
      );
      expect(
        typed,
        isNull,
        reason:
            'A coach cannot claim a credential the platform never verified.',
      );
    });

    test('with an unauthored catalogue nothing at all can be drafted', () {
      expect(
        CertificateDraft.validate(
          catalogue: CredentialCatalogue.unauthored,
          credentialId: 'nasm_cpt',
          coachUid: _coachUid,
          mediaRef: 'coach-docs/$_coachUid/x9',
          issuedAt: _issued,
        ),
        isNull,
      );
    });

    test('the file must land in her own folder', () {
      expect(
        CertificateDraft.validate(
          catalogue: CredentialCatalogue.dictionaryBacked,
          credentialId: 'nasm_cpt',
          coachUid: _coachUid,
          mediaRef: 'coach-docs/someone-else/x9',
          issuedAt: _issued,
        ),
        isNull,
      );
      expect(
        CertificateDraft.validate(
          catalogue: CredentialCatalogue.dictionaryBacked,
          credentialId: 'nasm_cpt',
          coachUid: _coachUid,
          mediaRef: 'coach-public/$_coachUid/x9',
          issuedAt: _issued,
        ),
        isNull,
      );
    });

    test('an expiry before its issue date is a typo, not a credential', () {
      expect(
        CertificateDraft.validate(
          catalogue: CredentialCatalogue.dictionaryBacked,
          credentialId: 'nasm_cpt',
          coachUid: _coachUid,
          mediaRef: 'coach-docs/$_coachUid/x9',
          issuedAt: _issued,
          expiresAt: _issued.subtract(const Duration(days: 1)),
        ),
        isNull,
      );
    });
  });

  group('P0-CVER-05 — a certificate chosen with no signal', () {
    test('it is queued locally and never shown as uploaded', () {
      final queued = Certificate.fromDraft(_draft(), id: 'c1', online: false);

      expect(queued.state, CertificateState.localPending);
      expect(queued.state.hasLeftTheDevice, isFalse);
      expect(queued.state.counts, isFalse);
    });

    test('it uploads on reconnect, and only from localPending', () {
      const machine = CertificateStateMachine();
      final queued = Certificate.fromDraft(_draft(), id: 'c1', online: false);

      final uploaded = machine.transition(queued, const CertificateUploaded());
      expect(uploaded.state, CertificateState.uploaded);

      // Replay: the second delivery of the same event is inert, which is what
      // makes "exactly once" true rather than hoped for.
      final again = machine.transition(uploaded, const CertificateUploaded());
      expect(again.state, CertificateState.uploaded);
    });

    test('with signal it is uploaded immediately', () {
      final live = Certificate.fromDraft(_draft(), id: 'c1', online: true);
      expect(live.state, CertificateState.uploaded);
    });
  });

  group('only a human clears one', () {
    const machine = CertificateStateMachine();

    test('the automated lookup gets it as far as checking and no further', () {
      final uploaded = Certificate.fromDraft(_draft(), id: 'c1', online: true);
      final checking = machine.transition(
        uploaded,
        const CertificateLookupStarted(),
      );

      expect(checking.state, CertificateState.checking);
      expect(checking.state.counts, isFalse);
    });

    test('a woman reviewer clears it', () {
      final uploaded = Certificate.fromDraft(_draft(), id: 'c1', online: true);
      final cleared = machine.transition(
        uploaded,
        CertificateCleared(_aWoman()),
      );

      expect(cleared.state, CertificateState.verified);
      expect(cleared.decidedAt, _decidedAt);
      expect(cleared.state.counts, isTrue);
    });

    test('an inadmissible decision clears nothing', () {
      final uploaded = Certificate.fromDraft(_draft(), id: 'c1', online: true);
      final byAMan = machine.transition(
        uploaded,
        CertificateCleared(
          ReviewerDecision(
            reviewerId: 'rev-9',
            reviewedByWoman: false,
            decidedAt: _decidedAt,
          ),
        ),
      );
      expect(byAMan.state, CertificateState.uploaded);
    });

    test('a refusal carries a coarse code', () {
      final uploaded = Certificate.fromDraft(_draft(), id: 'c1', online: true);
      final refused = machine.transition(
        uploaded,
        CertificateRefused(
          _aWoman(),
          CoachVerificationFailReason.documentUnreadable,
        ),
      );

      expect(refused.state, CertificateState.rejected);
      expect(
        refused.failReason,
        CoachVerificationFailReason.documentUnreadable,
      );
    });

    test(
      'a queued certificate cannot be cleared before it has been uploaded',
      () {
        final queued = Certificate.fromDraft(_draft(), id: 'c1', online: false);
        expect(
          machine.transition(queued, CertificateCleared(_aWoman())).state,
          CertificateState.localPending,
        );
      },
    );
  });

  group('expiry is computed on read, never swept', () {
    test('a cleared certificate lapses when its date passes', () {
      final cleared = Certificate(
        id: 'c1',
        credentialId: 'nasm_cpt',
        mediaRef: 'coach-docs/$_coachUid/a1',
        issuedAt: _issued,
        expiresAt: _expires,
        state: CertificateState.verified,
      );

      expect(cleared.stateAt(DateTime(2027, 6, 1)), CertificateState.verified);
      expect(
        cleared.stateAt(DateTime(2029, 1, 1)),
        CertificateState.expired,
        reason: 'No scheduler ran. The read did it.',
      );
    });

    test('a certificate with no expiry never lapses', () {
      final forever = Certificate.fromDraft(
        _draft(),
        id: 'c1',
        online: true,
      ).copyWith(state: CertificateState.verified);

      expect(forever.stateAt(DateTime(2099, 1, 1)), CertificateState.verified);
    });
  });

  test(
    'she may delete an uploaded or rejected certificate, never one mid-review',
    () {
      expect(CertificateState.uploaded.isDeletable, isTrue);
      expect(CertificateState.rejected.isDeletable, isTrue);
      expect(CertificateState.checking.isDeletable, isFalse);
      expect(CertificateState.verified.isDeletable, isFalse);
      expect(CertificateState.localPending.isDeletable, isFalse);
    },
  );

  group('the standing of a whole set', () {
    final now = DateTime(2026, 5, 20);

    Certificate at(CertificateState state, {DateTime? expiresAt}) =>
        Certificate(
          id: '${state.name}-${expiresAt?.year ?? 0}',
          credentialId: 'nasm_cpt',
          mediaRef: 'coach-docs/$_coachUid/a',
          issuedAt: _issued,
          expiresAt: expiresAt,
          state: state,
        );

    test('a queued certificate does not count as submitted', () {
      final standing = CertificateStanding.of([
        at(CertificateState.localPending),
      ], now: now);

      expect(standing.queuedOnDevice, 1);
      expect(standing.hasSubmittedAny, isFalse);
      expect(standing.holdsAnyCleared, isFalse);
    });

    test('one cleared certificate holds the badge', () {
      final standing = CertificateStanding.of([
        at(CertificateState.verified),
        at(CertificateState.rejected),
      ], now: now);

      expect(standing.cleared, 1);
      expect(standing.refused, 1);
      expect(standing.holdsAnyCleared, isTrue);
      expect(standing.everythingLapsed, isFalse);
    });

    test('everythingLapsed is the precondition for AllCertificatesExpired', () {
      final past = DateTime(2026, 1, 1);
      final standing = CertificateStanding.of([
        at(CertificateState.verified, expiresAt: past),
        at(
          CertificateState.verified,
          expiresAt: past.add(const Duration(days: 2)),
        ),
      ], now: now);

      expect(standing.lapsed, 2);
      expect(standing.everythingLapsed, isTrue);
      expect(standing.holdsAnyCleared, isFalse);
    });

    test('an empty set has not lapsed — it has nothing', () {
      final standing = CertificateStanding.of(const [], now: now);
      expect(standing.everythingLapsed, isFalse);
      expect(standing.hasSubmittedAny, isFalse);
    });
  });
}
