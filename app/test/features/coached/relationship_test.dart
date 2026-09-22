// The lifecycle, and the two things that cannot happen in it:
//
//   * no event in the table is a message, so a message cannot reach a
//     transition at all; and
//   * the only door into `active` is the coach publishing.
//
// Also P0-PAY-08's client half — buying offline is a hard no — because the
// button that reaches it ("Work with Sara again") is on G16, which this feature
// owns.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coached/domain/coach_projection.dart';
import 'package:own_hub/features/coached/domain/message_repository.dart';
import 'package:own_hub/features/coached/domain/purchase_gate.dart';
import 'package:own_hub/features/coached/domain/relationship.dart';
import 'package:own_hub/features/coached/domain/sharing.dart';

const _ref = RelationshipRef(coachUid: 'c7k9farida', clientUid: 'u3m2rania');
const _machine = RelationshipStateMachine();

void main() {
  group('a message cannot reach a transition', () {
    test('no event in the table is a message', () {
      final names = RelationshipEvent.values.map((e) => e.name.toLowerCase());
      for (final name in names) {
        expect(
          RegExp('(message|chat|voice|reply|said)').hasMatch(name),
          isFalse,
          reason: '$name looks like a message could raise it',
        );
      }
    });

    test('the only door into active is the publish', () {
      for (final from in RelationshipState.values) {
        for (final event in RelationshipEvent.values) {
          final next = _machine.next(from, event);
          if (next == RelationshipState.active) {
            expect(
              event,
              RelationshipEvent.coachPublishedPlan,
              reason:
                  '${from.name} + ${event.name} reached active. Only an '
                  'explicit publish may.',
            );
          }
        }
      }
    });

    test('an illegal transition is null, not a silent no-op', () {
      // Returning the current state would make "the publish did nothing"
      // indistinguishable from "the publish was not allowed".
      expect(
        _machine.next(
          RelationshipState.enquiry,
          RelationshipEvent.coachPublishedPlan,
        ),
        isNull,
      );
      expect(
        _machine.next(
          RelationshipState.ended,
          RelationshipEvent.coachPublishedPlan,
        ),
        isNull,
      );
    });
  });

  group('the happy path', () {
    test('enquiry → payment → acceptance → intake → preparing → active', () {
      var state = RelationshipState.enquiry;
      for (final event in const [
        RelationshipEvent.coachAcceptedEnquiry,
        RelationshipEvent.paymentPaid,
        RelationshipEvent.coachAccepted,
        RelationshipEvent.intakeSubmitted,
        RelationshipEvent.coachPublishedPlan,
      ]) {
        final next = _machine.next(state, event);
        expect(next, isNotNull, reason: '${state.name} + ${event.name}');
        state = next!;
      }
      expect(state, RelationshipState.active);
    });

    test(
      'awaitingPayment is not live — nothing is shared before money lands',
      () {
        expect(RelationshipState.awaitingPayment.isLive, isFalse);
        expect(RelationshipState.intake.isLive, isTrue);
        expect(RelationshipState.preparing.isLive, isTrue);
        expect(RelationshipState.ended.isLive, isFalse);
      },
    );

    test('a failed payment charges nothing and returns her to the enquiry', () {
      expect(
        _machine.next(
          RelationshipState.awaitingPayment,
          RelationshipEvent.paymentFailed,
        ),
        RelationshipState.enquiry,
      );
    });

    test('a coach who never replies refunds rather than stalls', () {
      expect(
        _machine.next(
          RelationshipState.awaitingAcceptance,
          RelationshipEvent.acceptanceWindowElapsed,
        ),
        RelationshipState.refunding,
      );
      expect(
        _machine.next(
          RelationshipState.refunding,
          RelationshipEvent.refundSettled,
        ),
        RelationshipState.refunded,
      );
    });
  });

  group('ending', () {
    test('either party may end early, from any live state', () {
      for (final state in RelationshipState.values.where((s) => s.isLive)) {
        expect(
          _machine.next(state, RelationshipEvent.endedEarly),
          RelationshipState.ended,
          reason: 'she may stop from ${state.name}',
        );
      }
    });

    test('ended is terminal — renewal is a new engagement, not a revival', () {
      for (final event in RelationshipEvent.values) {
        expect(
          _machine.next(RelationshipState.ended, event),
          isNull,
          reason: '${event.name} resurrected an ended relationship',
        );
      }
    });

    test('ending a relationship that is not live throws', () {
      final writer = CoachProjectionWriter(store: CoachProjectionStore());
      expect(
        () => EndCoaching(
          projections: writer,
        ).end(const Relationship(ref: _ref, state: RelationshipState.refunded)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('P0-PAY-08 — buying offline is a hard no', () {
    test('offline refuses, with nothing created and nothing queued', () {
      final attempt = const CoachingPurchaseGate().attempt(online: false);

      expect(attempt, isA<PurchaseRefusedOffline>());
      expect(attempt.mayProceed, isFalse);
      // The refusal carries no order, no amount and no timestamp, because
      // nothing was created to carry.
      expect(attempt.toString(), 'PurchaseRefusedOffline');
    });

    test('there is no third variant for a pending purchase', () {
      // A queued purchase would have to be a state. The sealed type has two
      // and the source has no other subclass.
      final source = File('lib/features/coached/domain/purchase_gate.dart')
          .readAsStringSync();
      final subclasses = RegExp(r'final class (\w+) extends PurchaseAttempt')
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();

      expect(subclasses, ['PurchaseAllowed', 'PurchaseRefusedOffline']);
      for (final banned in ['pending', 'queued', 'optimistic', 'retryLater']) {
        expect(source.toLowerCase().contains('class $banned'), isFalse);
      }
    });

    test('the gate takes connectivity and nothing else', () {
      final source = File('lib/features/coached/domain/purchase_gate.dart')
          .readAsStringSync();
      final signature = RegExp(r'PurchaseAttempt attempt\(\{([^}]*)\}\)')
          .firstMatch(source)!
          .group(1)!;
      expect(signature.trim(), 'required bool online');
    });

    test('online, the checkout may open', () {
      expect(
        const CoachingPurchaseGate().attempt(online: true).mayProceed,
        isTrue,
      );
    });
  });

  group('negative controls', () {
    test(
      'suspension is reachable from a live state and not from a dead one',
      () {
        expect(
          _machine.next(RelationshipState.active, RelationshipEvent.suspended),
          RelationshipState.suspended,
        );
        expect(
          _machine.next(
            RelationshipState.refunded,
            RelationshipEvent.suspended,
          ),
          isNull,
        );
      },
    );

    test(
      'a relationship carries its agreed price, not the coach\'s current one',
      () {
        const rel = Relationship(
          ref: _ref,
          state: RelationshipState.active,
          priceEGP: 1450,
        );
        // copyWith cannot move it — a later price rise must not reach her.
        final renamed = rel.copyWith(state: RelationshipState.endingSoon);
        expect(renamed.priceEGP, 1450);
      },
    );

    test('a new relationship starts with every switch off', () {
      const rel = Relationship(ref: _ref, state: RelationshipState.intake);
      expect(rel.sharing, SharingSwitches.off);
    });
  });
}
