// `P0-CVER-01` to `P0-CVER-04`, and the rule the whole coach side rests on:
// **no machine ever clears a coach.**
//
// The first group is the important one. It does not test a path; it tests the
// absence of every path — for each of the eight states, every event a machine
// can raise is applied and asserted not to reach `verified`. A new automated
// event added tomorrow fails here by existing, which is the only way a rule
// phrased as "never" can be defended.
//
// Figures and ids throughout are deliberately unlike the prototype's.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coach/domain/coach_verification.dart';

final _at = DateTime(2026, 4, 7, 11, 3);

ReviewerDecision _aWoman({String id = 'rev-77'}) =>
    ReviewerDecision(reviewerId: id, reviewedByWoman: true, decidedAt: _at);

ReviewerDecision _notAWoman() => ReviewerDecision(
  reviewerId: 'rev-78',
  reviewedByWoman: false,
  decidedAt: _at,
);

ReviewerDecision _anonymous() =>
    ReviewerDecision(reviewerId: '   ', reviewedByWoman: true, decidedAt: _at);

/// Everything a machine can raise. Deliberately a list rather than a filter on
/// the event hierarchy: a new automated event has to be added here to pass the
/// suite, which is a moment somebody reads this comment.
const List<CoachVerificationEvent> _machineEvents = [
  SetupCompleted(
    hasCertificate: true,
    hasPayoutMethod: true,
    hasCapacity: true,
  ),
  LookupStarted(),
  LookupFinding(allCertificatesRecognised: true),
  LookupFinding(allCertificatesRecognised: false),
  CertificateReplaced(),
  AllCertificatesExpired(),
  CertificateRenewed(),
];

void main() {
  const machine = CoachVerificationStateMachine();

  group('coach verification is never automated', () {
    test('no event a machine can raise ever reaches verified', () {
      // `changed` is the load-bearing half. An event that does not apply
      // returns the state it was given, so applying `LookupStarted` to a coach
      // who is already verified reports `verified` — correctly, and as a no-op.
      // What must never exist is a machine event that *moves* her there.
      final reached = <String>[];
      for (final from in CoachVerificationState.values) {
        for (final event in _machineEvents) {
          final outcome = machine.transition(from, event);
          if (outcome.changed &&
              outcome.state == CoachVerificationState.verified) {
            reached.add('${from.name} --${event.runtimeType}--> verified');
          }
        }
      }
      expect(
        reached,
        isEmpty,
        reason:
            'A certificate is cleared by a woman reading a document. Any '
            'transition from a machine event to verified would mint the coachV '
            'claim with nobody in the loop: ${reached.join(', ')}',
      );
    });

    test('no event a machine can raise ever mints the claim', () {
      for (final from in CoachVerificationState.values) {
        for (final event in _machineEvents) {
          expect(
            machine.transition(from, event).mintsCoachClaim,
            isFalse,
            reason: '${from.name} / ${event.runtimeType} minted coachV',
          );
        }
      }
    });

    test('a clean automated lookup buys her a reviewer, not a badge', () {
      final outcome = machine.transition(
        CoachVerificationState.docsChecking,
        const LookupFinding(allCertificatesRecognised: true),
      );

      expect(outcome.state, CoachVerificationState.humanReview);
      expect(outcome.mintsCoachClaim, isFalse);
    });

    test(
      'a dirty lookup lands in the same place, so the branch cannot drift',
      () {
        // Both findings go to human_review on purpose: if this ever grows a
        // second destination, the coach side has changed posture and the diff
        // should be impossible to miss.
        expect(
          machine
              .transition(
                CoachVerificationState.docsChecking,
                const LookupFinding(allCertificatesRecognised: false),
              )
              .state,
          CoachVerificationState.humanReview,
        );
      },
    );

    test('only a woman reviewer may clear her — D8', () {
      final byAMan = machine.transition(
        CoachVerificationState.humanReview,
        ReviewerPass(_notAWoman()),
      );
      expect(byAMan.state, CoachVerificationState.humanReview);
      expect(byAMan.changed, isFalse);
      expect(byAMan.mintsCoachClaim, isFalse);
    });

    test('an unnamed decision is not a human decision', () {
      // "A human decided" with nobody named is the shape an automated decision
      // takes when it is trying to look like a human one.
      final outcome = machine.transition(
        CoachVerificationState.humanReview,
        ReviewerPass(_anonymous()),
      );
      expect(outcome.state, CoachVerificationState.humanReview);
      expect(outcome.changed, isFalse);
    });

    test('a woman reviewer clears her, mints the claim and ticks K25', () {
      final outcome = machine.transition(
        CoachVerificationState.humanReview,
        ReviewerPass(_aWoman()),
      );

      expect(outcome.state, CoachVerificationState.verified);
      expect(outcome.mintsCoachClaim, isTrue);
      expect(outcome.clearsCertificatesStep, isTrue);
      expect(outcome.pageIsLive, isTrue);
    });
  });

  group(
    'P0-CVER-01 — she cannot take a client before her certificates clear',
    () {
      test('every waiting state refuses a client', () {
        for (final state in [
          CoachVerificationState.setupIncomplete,
          CoachVerificationState.submitted,
          CoachVerificationState.docsChecking,
          CoachVerificationState.humanReview,
          CoachVerificationState.rejected,
          CoachVerificationState.expired,
          CoachVerificationState.suspended,
        ]) {
          expect(state.mayAcceptClients, isFalse, reason: state.name);
          expect(state.holdsCoachClaim, isFalse, reason: state.name);
          expect(state.mayAdvertiseAvailability, isFalse, reason: state.name);
        }
        expect(CoachVerificationState.verified.mayAcceptClients, isTrue);
      });

      test('she may author everything and publish nothing', () {
        for (final state in [
          CoachVerificationState.submitted,
          CoachVerificationState.docsChecking,
          CoachVerificationState.humanReview,
        ]) {
          final rights = CoachPublishingRights.forState(state);
          expect(rights.mayAuthor, isTrue, reason: state.name);
          expect(rights.mayPublish, isFalse, reason: state.name);
          expect(
            rights.isAuthoringWhileUnpublished,
            isTrue,
            reason: state.name,
          );
        }
      });

      test('a suspended coach may not even author', () {
        final rights = CoachPublishingRights.forState(
          CoachVerificationState.suspended,
        );
        expect(rights.mayAuthor, isFalse);
        expect(rights.mayPublish, isFalse);
        expect(rights.pageIsLive, isFalse);
      });
    },
  );

  group('P0-CVER-03 — a rejected certificate is not a dead end', () {
    test('the reason is a coarse code', () {
      final outcome = machine.transition(
        CoachVerificationState.humanReview,
        ReviewerFail(
          _aWoman(),
          CoachVerificationFailReason.issuingBodyNotRecognised,
        ),
      );

      expect(outcome.state, CoachVerificationState.rejected);
      expect(
        outcome.failReason,
        CoachVerificationFailReason.issuingBodyNotRecognised,
      );
      expect(
        CoachVerificationFailReason.values.length,
        5,
        reason:
            'The fail vocabulary is closed. Widening it is how raw provider '
            'text arrives wearing an enum name.',
      );
    });

    test('replace and resubmit stays open', () {
      final again = machine.transition(
        CoachVerificationState.rejected,
        const CertificateReplaced(),
      );
      expect(again.state, CoachVerificationState.submitted);
      expect(again.replacementAttempts, 1);
    });

    test('three replacements, then suspended rather than looped forever', () {
      final third = machine.transition(
        CoachVerificationState.rejected,
        const CertificateReplaced(),
        replacementAttempts: CoachVerificationStateMachine.replacementCeiling,
      );
      expect(third.state, CoachVerificationState.suspended);
    });
  });

  group('P0-CVER-04 — her paperwork never punishes her client', () {
    test('expiry revokes the claim and keeps the page live', () {
      final outcome = machine.transition(
        CoachVerificationState.verified,
        const AllCertificatesExpired(),
      );

      expect(outcome.state, CoachVerificationState.expired);
      expect(outcome.revokesCoachClaim, isTrue);
      expect(
        outcome.pageIsLive,
        isTrue,
        reason: 'Her page stays up. Only new clients stop.',
      );
      expect(outcome.state.mayAcceptClients, isFalse);
      expect(outcome.state.mayAdvertiseAvailability, isFalse);
    });

    test('a renewal goes back through a human, not around one', () {
      final renewed = machine.transition(
        CoachVerificationState.expired,
        const CertificateRenewed(),
      );
      expect(renewed.state, CoachVerificationState.submitted);
      expect(renewed.mintsCoachClaim, isFalse);
    });
  });

  group('negative controls — an event that does not apply changes nothing', () {
    test('setup with a piece missing does not submit her', () {
      for (final event in [
        const SetupCompleted(
          hasCertificate: false,
          hasPayoutMethod: true,
          hasCapacity: true,
        ),
        const SetupCompleted(
          hasCertificate: true,
          hasPayoutMethod: false,
          hasCapacity: true,
        ),
        const SetupCompleted(
          hasCertificate: true,
          hasPayoutMethod: true,
          hasCapacity: false,
        ),
      ]) {
        final outcome = machine.transition(
          CoachVerificationState.setupIncomplete,
          event,
        );
        expect(outcome.state, CoachVerificationState.setupIncomplete);
        expect(outcome.changed, isFalse);
      }
    });

    test('a replayed event is inert rather than fatal', () {
      final once = machine.transition(
        CoachVerificationState.submitted,
        const LookupStarted(),
      );
      final twice = machine.transition(once.state, const LookupStarted());
      expect(twice.state, CoachVerificationState.docsChecking);
      expect(twice.changed, isFalse);
    });

    test('a reviewer cannot un-suspend her from here', () {
      final outcome = machine.transition(
        CoachVerificationState.suspended,
        ReviewerPass(_aWoman()),
      );
      expect(outcome.state, CoachVerificationState.suspended);
      expect(outcome.changed, isFalse);
    });

    test('a safety action revokes the claim from a verified coach', () {
      final outcome = machine.transition(
        CoachVerificationState.verified,
        const SafetyActionTaken(),
      );
      expect(outcome.state, CoachVerificationState.suspended);
      expect(outcome.revokesCoachClaim, isTrue);
      expect(outcome.pageIsLive, isFalse);
    });
  });
}
