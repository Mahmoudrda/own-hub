// The seam refuses honestly, and cannot be made to lie by using it.
//
// `UnavailablePaymentProvider` is the only implementation of `PaymentProvider`
// that ships. These tests pin the two things that make that safe: it never
// reports success, and the shapes it returns have no success to report.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/coaching/domain/money.dart';
import 'package:own_hub/features/coaching/domain/payment_provider.dart';
import 'package:own_hub/features/coaching/domain/payment_state_machine.dart';

const _request = CheckoutRequest(
  relId: 'coach-42__client-93',
  offerId: 'monthly',
  rail: PaymentRail.card,
  idempotencyKey: 'idem-1',
);

void main() {
  group('the only provider that ships refuses, and says why', () {
    test('every method refuses, for every reason', () async {
      for (final reason in PaymentUnavailableReason.values) {
        final provider = UnavailablePaymentProvider(reason: reason);

        expect(
          await provider.priceOf(coachUid: 'coach-42', offerId: 'monthly'),
          isNull,
          reason: 'a price it cannot supply is withheld, never zero',
        );

        final checkout = await provider.startCheckout(_request);
        expect(checkout, isA<CheckoutUnavailable>());
        expect((checkout as CheckoutUnavailable).reason, reason);

        final reissued = await provider.reissue(
          expiredProviderTxnId: 'pmb-771',
          idempotencyKey: 'idem-2',
        );
        expect(reissued, isA<CheckoutUnavailable>());

        final refund = await provider.requestRefund(
          providerTxnId: 'pmb-771',
          reason: RefundReason.coachSilent,
        );
        expect(refund, isA<RefundUnavailable>());
        expect((refund as RefundUnavailable).reason, reason);

        final views = await provider.watch('pmb-771').toList();
        expect(views, hasLength(1));
        expect(views.single, isA<PaymentUnknown>());
      }
    });

    test('it never emits a payment record of any state', () async {
      // The strongest form of the claim: not "it does not emit a paid record",
      // but "it emits no record at all". There is nothing for a screen to read
      // a figure out of.
      final provider = const UnavailablePaymentProvider();
      final views = await provider.watch('pmb-771').toList();
      for (final view in views) {
        expect(view, isNot(isA<PaymentKnown>()));
      }
    });

    test('a null price is withheld, not a zero', () async {
      // `H03` renders nothing about money for a null price and does not offer
      // a purchase. A zero would be a claim about her coach's fee.
      final price = await const UnavailablePaymentProvider().priceOf(
        coachUid: 'coach-42',
        offerId: 'monthly',
      );
      expect(price, isNull);
    });

    test('the two named refusals carry the reason a screen needs', () {
      expect(
        UnavailablePaymentProvider.offline.reason,
        PaymentUnavailableReason.offline,
      );
      expect(
        UnavailablePaymentProvider.featureOff.reason,
        PaymentUnavailableReason.featureOff,
      );
      expect(
        const UnavailablePaymentProvider().reason,
        PaymentUnavailableReason.notImplemented,
        reason: 'today\'s honest default is "nobody has built this yet"',
      );
    });
  });

  group('the shapes have no success to report', () {
    test('a checkout outcome cannot mean paid', () {
      // Two variants and no third. This is the property that makes "a redirect
      // is not a receipt" structural rather than a convention: the code path
      // that opens the provider page has nowhere to put a success.
      const outcomes = <CheckoutOutcome>[
        CheckoutOutcome.unavailable(PaymentUnavailableReason.offline),
      ];
      for (final outcome in outcomes) {
        expect(outcome, isA<CheckoutUnavailable>());
      }

      // Exhaustively: the sealed hierarchy has exactly the two subtypes, and a
      // switch over it must be total with only those two arms.
      const CheckoutOutcome refused = CheckoutOutcome.unavailable(
        PaymentUnavailableReason.notImplemented,
      );
      final described = switch (refused) {
        CheckoutUnavailable() => 'unavailable',
        CheckoutStarted() => 'started',
      };
      expect(described, 'unavailable');
    });

    test('a refund outcome cannot mean refunded', () {
      // Settling is a webhook, not a return value. A method that could return
      // "refunded" is a method a screen could use to tell a woman her money is
      // back before it is. The switch below is exhaustive over the sealed
      // hierarchy with three arms, and "refunded" is not one of them.
      final RefundOutcome outcome = RefundOutcome.requested(
        RefundQuote.full(
          gross: const Money.pounds(1800),
          reason: RefundReason.coachSilent,
        ),
      );
      final described = switch (outcome) {
        RefundUnavailable() => 'unavailable',
        RefundNotAllowed() => 'refused',
        RefundRequestedOk() => 'requested',
      };
      expect(described, 'requested');
      expect((outcome as RefundRequestedOk).quote.amountBack.amountText, '1,800');
    });

    test('a checkout request carries no amount', () {
      // `P0-PAY-09` at the type level: there is nothing on this object for a
      // tampered client to halve.
      expect(_request.toString(), isNot(contains('1800')));
      expect(_request.toString(), isNot(contains('EGP')));
    });
  });
}
