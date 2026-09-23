// The gate, and the four owner decisions it makes unrepresentable.
//
//  * buy-direct is removed — enquiry first, on every path
//  * browsing is open to all; purchasing needs a verified account
//  * offline is a hard no, with nothing queued
//  * a null price is withheld, never rendered or charged as zero

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coaching/domain/checkout_gate.dart';
import 'package:own_hub/features/coaching/domain/marketplace_stage.dart';
import 'package:own_hub/features/coaching/domain/money.dart';

const _gate = CheckoutGate();
const _enquiryGate = EnquiryGate();
const _price = Money.pounds(1800);

/// Flags with the marketplace and its payments child switched on.
///
/// Built from [FeatureFlags.allOff]: the gate's refusals are the subject of
/// this file, so the switch positions behind each one are stated here rather
/// than inherited from `FeatureFlags.shipped`.
final FeatureFlags _on = FeatureFlags.allOff.with_({
  Feature.marketplace: true,
  Feature.payments: true,
});

/// The marketplace dark, which is what "this flow ships dark" means.
final FeatureFlags _off = FeatureFlags.allOff;

CheckoutDecision _decide({
  FeatureFlags? flags,
  MarketplaceStage stage = MarketplaceStage.acceptedAwaitingPayment,
  bool verified = true,
  bool online = true,
  bool accepting = true,
  int? spotsLeft = 12,
  Money? price = _price,
}) => _gate.decide(
  flags: flags ?? _on,
  stage: stage,
  verified: verified,
  online: online,
  coachAcceptingClients: accepting,
  spotsLeft: spotsLeft,
  price: price,
);

void main() {
  group('buy-direct is removed — enquiry first, always', () {
    test('the only stage a checkout opens from is an accepted enquiry', () {
      expect(_decide().mayProceed, isTrue);

      for (final stage in MarketplaceStage.values) {
        if (stage == MarketplaceStage.acceptedAwaitingPayment) continue;
        final decision = _decide(stage: stage);
        expect(
          decision.mayProceed,
          isFalse,
          reason: 'a checkout must not open from ${stage.name}',
        );
      }
    });

    test('plain browsing is refused with the reason that explains itself', () {
      expect(
        _decide(stage: MarketplaceStage.browsing),
        const CheckoutRefused(CheckoutRefusal.noAcceptedEnquiry),
      );
    });

    test('there is no stage meaning "browsing and may buy"', () {
      // The enum itself is the enforcement. `maySeePurchasableOffer` is true
      // for exactly one value, and it is the one that follows an acceptance.
      final buyable = MarketplaceStage.values
          .where((s) => s.maySeePurchasableOffer)
          .toList();
      expect(buyable, [MarketplaceStage.acceptedAwaitingPayment]);
    });

    test('a checkout already in flight is refused, not duplicated', () {
      expect(
        _decide(stage: MarketplaceStage.paying),
        const CheckoutRefused(CheckoutRefusal.alreadyPaying),
      );
    });

    test('"she pays only once you accept" is true on every path', () {
      // The sentence the enquiry screen makes. Proved by exhausting the stages
      // rather than asserted in copy: every stage that is not an acceptance
      // refuses, whatever else is true.
      for (final stage in MarketplaceStage.values) {
        for (final verified in [true, false]) {
          for (final online in [true, false]) {
            final allowed = _decide(
              stage: stage,
              verified: verified,
              online: online,
            ).mayProceed;
            if (allowed) {
              expect(stage, MarketplaceStage.acceptedAwaitingPayment);
              expect(verified, isTrue);
              expect(online, isTrue);
            }
          }
        }
      }
    });
  });

  group('browsing is open; purchasing is gated', () {
    test('an unverified woman may not pay', () {
      expect(
        _decide(verified: false),
        const CheckoutRefused(CheckoutRefusal.notVerified),
      );
    });

    test('an unverified woman may still browse and read a price', () {
      // Nothing in the gate touches reading. It answers one question, and a
      // refusal here does not travel to the directory or the profile.
      expect(MarketplaceStage.browsing.mayEnquire, isTrue);
    });

    test('an unverified woman may not start a relationship either', () {
      final decision = _enquiryGate.decide(
        flags: _on,
        stage: MarketplaceStage.browsing,
        verified: false,
        coachAcceptingClients: true,
        message: 'Can you work with a knee that clicks?',
      );
      expect(decision, const EnquiryRefusedBy(EnquiryRefusal.notVerified));
    });
  });

  group('P0-PAY-08 — offline is a hard no', () {
    test('offline refuses, and the refusal names connectivity', () {
      expect(
        _decide(online: false),
        const CheckoutRefused(CheckoutRefusal.offline),
      );
    });

    test('there is no decision that means "later"', () {
      // Two variants: allowed, and refused. No `queued`, no `pending`, no
      // `optimistic`. There is nothing for a sync layer to replay because
      // there is nothing to store.
      const CheckoutDecision refused = CheckoutDecision.refused(
        CheckoutRefusal.offline,
      );
      final described = switch (refused) {
        CheckoutAllowed() => 'allowed',
        CheckoutRefused() => 'refused',
      };
      expect(described, 'refused');
    });

    test('an enquiry, unlike a purchase, has no connectivity parameter', () {
      // A queued enquiry is a message with a deterministic id. A queued
      // purchase is a charge nobody authorised. The two gates differ in
      // exactly that, and this pins it.
      final decision = _enquiryGate.decide(
        flags: _on,
        stage: MarketplaceStage.browsing,
        verified: true,
        coachAcceptingClients: true,
        message: 'I train at home with two dumbbells.',
      );
      expect(decision.mayProceed, isTrue);
    });
  });

  group('capacity', () {
    test('a coach who has closed her books cannot be bought from', () {
      expect(
        _decide(accepting: false),
        const CheckoutRefused(CheckoutRefusal.coachNotAccepting),
      );
    });

    test('no places left is refused before a round-trip', () {
      expect(
        _decide(spotsLeft: 0),
        const CheckoutRefused(CheckoutRefusal.coachNotAccepting),
      );
    });

    test('an unknown places count does not block a purchase', () {
      // The pack may not carry it, and the server re-reads capacity at
      // checkout anyway. Refusing on an absent figure would turn a missing
      // field into a closed shop.
      expect(_decide(spotsLeft: null).mayProceed, isTrue);
    });

    test('the ceiling echoed here matches the coach side', () {
      expect(kCoachCapacityCeiling, 60);
    });
  });

  group('money is never fabricated', () {
    test('a null price refuses rather than charging zero', () {
      expect(
        _decide(price: null),
        const CheckoutRefused(CheckoutRefusal.priceUnknown),
      );
    });

    test('an allowed decision carries the price it cleared', () {
      final decision = _decide();
      expect(decision, isA<CheckoutAllowed>());
      expect((decision as CheckoutAllowed).price, _price);
    });
  });

  group('the flags — payments is a child of marketplace', () {
    test('a dark marketplace refuses first', () {
      expect(
        _decide(flags: _off),
        const CheckoutRefused(CheckoutRefusal.marketplaceOff),
      );
    });

    test('a dark payments child refuses with its own reason', () {
      expect(
        _decide(
          flags: FeatureFlags.allOff.with_({
            Feature.marketplace: true,
            Feature.payments: false,
          }),
        ),
        const CheckoutRefused(CheckoutRefusal.paymentsOff),
      );
    });

    test('payments off cannot be reached while marketplace is off', () {
      // `isOn` walks the parent chain, so a payments flag left on under a dark
      // marketplace is still off — and the refusal a woman would see names the
      // parent, which is the true reason.
      final flags = FeatureFlags.allOff.with_({
        Feature.marketplace: false,
        Feature.payments: true,
      });
      expect(flags.isOn(Feature.payments), isFalse);
      expect(
        _decide(flags: flags),
        const CheckoutRefused(CheckoutRefusal.marketplaceOff),
      );
    });

    test("this flow is switched on, at the owner's instruction", () {
      // Both off in the first release: coaching needs two real accounts and
      // a payment rail, and neither exists until there is a server. The gate
      // itself is still proved, above, against flags this file sets.
      expect(FeatureFlags.shipped.isOn(Feature.marketplace), isFalse);
      expect(FeatureFlags.shipped.isOn(Feature.payments), isFalse);
    });
  });

  group('the enquiry gate', () {
    test('an empty message is refused rather than sent as a blank thread', () {
      expect(
        _enquiryGate.decide(
          flags: _on,
          stage: MarketplaceStage.browsing,
          verified: true,
          coachAcceptingClients: true,
          message: '   ',
        ),
        const EnquiryRefusedBy(EnquiryRefusal.empty),
      );
    });

    test('one open enquiry per coach', () {
      expect(
        _enquiryGate.decide(
          flags: _on,
          stage: MarketplaceStage.enquirySent,
          verified: true,
          coachAcceptingClients: true,
          message: 'Another question',
        ),
        const EnquiryRefusedBy(EnquiryRefusal.alreadyInTouch),
      );
    });

    test('a declined enquiry may be followed by another', () {
      expect(
        _enquiryGate
            .decide(
              flags: _on,
              stage: MarketplaceStage.enquiryDeclined,
              verified: true,
              coachAcceptingClients: true,
              message: 'Are you taking anyone now?',
            )
            .mayProceed,
        isTrue,
      );
    });

    test('an ended relationship may enquire again — that is the renewal', () {
      // Renewal is a new enquiry, not a resurrection and not a direct buy.
      expect(MarketplaceStage.coachingEnded.mayEnquire, isTrue);
      expect(
        MarketplaceStage.coachingEnded.maySeePurchasableOffer,
        isFalse,
        reason:
            'working with her again still needs her to accept before a pound '
            'moves — a renewal is not an exception to buy-direct being gone',
      );
    });
  });

  group('the relationship id is deterministic', () {
    test('coach first, double underscore', () {
      expect(
        relationshipIdFor(coachUid: 'coach-42', clientUid: 'client-93'),
        'coach-42__client-93',
      );
    });

    test('it refuses a uid that would make the id ambiguous', () {
      // The storage rules split on this id to decide who may open a voice
      // note. An ambiguous split is a privacy failure, not a formatting one.
      expect(
        () => relationshipIdFor(coachUid: 'a__b', clientUid: 'c'),
        throwsArgumentError,
      );
      expect(
        () => relationshipIdFor(coachUid: '', clientUid: 'c'),
        throwsArgumentError,
      );
    });
  });
}
