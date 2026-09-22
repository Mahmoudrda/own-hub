// D21: "she pays only once you accept" must be true on every path.
//
// The marketplace's CheckoutGate refuses a checkout from an un-accepted
// enquiry, but a rule enforced in one caller and not in the state machine
// holds only until a second caller arrives. These tests put it in the model.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/coached/domain/relationship.dart';

void main() {
  group('the only door into awaitingPayment is the coach accepting', () {
    test('a checkout cannot be created straight from an enquiry', () {
      expect(
        const RelationshipStateMachine().next(
          RelationshipState.enquiry,
          RelationshipEvent.checkoutCreated,
        ),
        isNull,
        reason:
            'this was buy-direct surviving in the model after the product '
            'removed it — she could pay before her coach had accepted her',
      );
    });

    test('the coach accepting still opens payment', () {
      expect(
        const RelationshipStateMachine().next(
          RelationshipState.enquiry,
          RelationshipEvent.coachAcceptedEnquiry,
        ),
        RelationshipState.awaitingPayment,
      );
    });

    test('no state other than enquiry+acceptance reaches awaitingPayment', () {
      // A positive control for the claim above: sweep every pair and assert
      // acceptance is the sole route in.
      for (final from in RelationshipState.values) {
        for (final event in RelationshipEvent.values) {
          final to = const RelationshipStateMachine().next(from, event);
          if (to == RelationshipState.awaitingPayment) {
            expect(
              event,
              RelationshipEvent.coachAcceptedEnquiry,
              reason: '$from + $event reached awaitingPayment',
            );
          }
        }
      }
    });
  });
}
