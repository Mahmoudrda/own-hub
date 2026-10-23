// The six screens' state, decided with no widget in sight.
//
// `P0-COACH-01`…`P0-COACH-05`, `P0-COACH-09`, `P0-PAY-03`, `P0-PAY-05`,
// `P0-PAY-08`, and the repository fake's strictness.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coaching/domain/checkout_gate.dart';
import 'package:own_hub/features/coaching/domain/coach_directory.dart';
import 'package:own_hub/features/coaching/domain/coaching_repository.dart';
import 'package:own_hub/features/coaching/domain/marketplace_stage.dart';
import 'package:own_hub/features/coaching/domain/money.dart';
import 'package:own_hub/features/coaching/domain/payment_provider.dart';
import 'package:own_hub/features/coaching/domain/payment_state_machine.dart';
import 'package:own_hub/features/coaching/presentation/coaching_view_models.dart';

/// The marketplace and its payments child switched on.
///
/// Built from [FeatureFlags.allOff] so that a case asserting a dark
/// marketplace has to say so itself.
final FeatureFlags _on = FeatureFlags.allOff.with_({
  Feature.marketplace: true,
  Feature.payments: true,
});

/// The marketplace dark.
final FeatureFlags _off = FeatureFlags.allOff;

final _monthly = const CoachingOffer(
  id: 'monthly',
  coachUid: 'c1',
  name: 'Monthly coaching',
  period: OfferPeriod.monthly,
  price: Money.pounds(1800),
  lines: ['A plan built for your days and equipment'],
);

final _planOnly = const CoachingOffer(
  id: 'plan-only',
  coachUid: 'c1',
  name: 'Plan only',
  period: OfferPeriod.oneOff,
  price: Money.pounds(900),
);

final _unpriced = const CoachingOffer(
  id: 'unpriced',
  coachUid: 'c1',
  name: 'Monthly coaching',
  period: OfferPeriod.monthly,
);

DirectoryRow _row(
  String uid,
  String name, {
  int? pounds = 1800,
  bool accepting = true,
  int reviewCount = 0,
  double? ratingAverage,
}) => DirectoryRow(
  coachUid: uid,
  displayName: name,
  city: 'Giza',
  specialties: const [CoachingSpecialty.postpartum],
  languages: const [CoachingLanguage.arabic],
  acceptingClients: accepting,
  priceFrom: pounds == null ? null : Money.pounds(pounds),
  reviewCount: reviewCount,
  ratingAverage: ratingAverage,
);

/// A provider that counts calls and still never succeeds.
///
/// It cannot report a payment: it has no way to build a [PaymentRecord], which
/// is what makes "the gate ran first" provable without also building a fake
/// that could pay.
class _CountingProvider implements PaymentProvider {
  int checkoutCalls = 0;
  int priceCalls = 0;

  @override
  Future<Money?> priceOf({
    required String coachUid,
    required String offerId,
  }) async {
    priceCalls++;
    return null;
  }

  @override
  Future<CheckoutOutcome> startCheckout(CheckoutRequest request) async {
    checkoutCalls++;
    return const CheckoutOutcome.unavailable(
      PaymentUnavailableReason.notImplemented,
    );
  }

  @override
  Stream<PaymentView> watch(String providerTxnId) => Stream.value(
    const PaymentView.unavailable(PaymentUnavailableReason.notImplemented),
  );

  @override
  Future<CheckoutOutcome> reissue({
    required String expiredProviderTxnId,
    required String idempotencyKey,
  }) async => const CheckoutOutcome.unavailable(
    PaymentUnavailableReason.notImplemented,
  );

  @override
  Future<RefundOutcome> requestRefund({
    required String providerTxnId,
    required RefundReason reason,
  }) async =>
      const RefundOutcome.unavailable(PaymentUnavailableReason.notImplemented);
}

void main() {
  group('H01 — find a coach', () {
    test('a failed load and an empty result are different answers', () {
      const failed = FindACoachViewModel(
        snapshot: DirectorySnapshot.unavailable(),
      );
      expect(failed.emptiness, DirectoryEmptiness.couldNotLoad);

      final matchedNothing = FindACoachViewModel(
        snapshot: DirectorySnapshot(
          rows: [_row('c1', 'Nourhan')],
          source: DirectorySource.pack,
        ),
        query: const DirectoryQuery(specialties: {CoachingSpecialty.pregnancy}),
      );
      expect(matchedNothing.emptiness, DirectoryEmptiness.nothingMatched);
    });

    test('toggling a facet is additive and reversible', () {
      final model = FindACoachViewModel(
        snapshot: DirectorySnapshot(
          rows: [_row('c1', 'Nourhan')],
          source: DirectorySource.pack,
        ),
      );
      final on = model.toggleSpecialty(CoachingSpecialty.postpartum);
      expect(on.query.specialties, {CoachingSpecialty.postpartum});
      final off = on.toggleSpecialty(CoachingSpecialty.postpartum);
      expect(off.query.specialties, isEmpty);
    });

    test('only the cold fallback may offer more', () {
      const pack = FindACoachViewModel(
        snapshot: DirectorySnapshot(
          rows: <DirectoryRow>[],
          source: DirectorySource.pack,
          hasMore: true,
        ),
      );
      expect(pack.isColdFallback, isFalse);

      const cold = FindACoachViewModel(
        snapshot: DirectorySnapshot(
          rows: <DirectoryRow>[],
          source: DirectorySource.coldFallback,
          hasMore: true,
        ),
      );
      expect(cold.isColdFallback && cold.hasMore, isTrue);
    });

    test('one fetch, then local filtering', () async {
      // `H01` costs zero Firestore reads by construction. It must also not
      // refetch on every chip tap.
      final repository = InMemoryCoachingRepository(
        rows: [_row('c1', 'Nourhan'), _row('c2', 'Mariam')],
      );
      var model = await FindACoachViewModel.load(repository);
      model = model.toggleSpecialty(CoachingSpecialty.postpartum);
      model = model.toggleLanguage(CoachingLanguage.arabic);
      expect(model.rows, isNotEmpty);
      expect(repository.directoryFetches, 1);
    });
  });

  group('H02 — a coach profile', () {
    CoachProfileViewModel model({
      MarketplaceStage stage = MarketplaceStage.browsing,
      bool verified = true,
      bool accepting = true,
      CoachPage? page,
    }) => CoachProfileViewModel(
      page:
          page ??
          CoachPage(
            row: _row('c1', 'Nourhan', accepting: accepting),
            blocks: const [
              CoverBlock(headline: 'Back to lifting, after birth'),
              OffersBlock(offerIds: ['monthly']),
            ],
          ),
      offers: [_monthly],
      stage: stage,
      flags: _on,
      verified: verified,
    );

    test('browsing is open to an unverified woman', () {
      final m = model(verified: false);
      expect(m.mayBrowse, isTrue);
      expect(m.maySeePackages, isTrue, reason: 'reading a price is not buying');
      expect(m.mayEnquire, isFalse, reason: 'starting a relationship is gated');
    });

    test('an unpublished coach renders nothing rather than an empty page', () {
      final m = CoachProfileViewModel(
        page: null,
        offers: const [],
        stage: MarketplaceStage.browsing,
        flags: _on,
        verified: true,
      );
      expect(m.hasPage, isFalse);
      expect(m.maySeePackages, isFalse);
    });

    test('an unmeasured reply time makes no claim', () {
      expect(model().replyMinsP50, isNull);
    });

    test('a rating below five reviews is withheld', () {
      final four = CoachProfileViewModel(
        page: CoachPage(
          row: _row('c1', 'Nourhan', reviewCount: 4, ratingAverage: 2.5),
          blocks: const [],
        ),
        offers: const [],
        stage: MarketplaceStage.browsing,
        flags: _on,
        verified: true,
      );
      expect(four.ratingToDisplay, isNull);
      expect(four.reviewCount, 4);
    });

    test('a hidden block is absent, not present and skipped', () {
      // `P0-COACH-02`: there is no gap to render and no body downloaded.
      final m = model();
      expect(m.page!.blocks, hasLength(2));
      expect(m.page!.blocks.whereType<ResultsBlock>(), isEmpty);
    });

    test('offer ids come from the block she placed', () {
      expect(model().page!.offerIds, ['monthly']);
    });
  });

  group('H03 — packages and checkout', () {
    PackagesViewModel model({
      List<CoachingOffer>? offers,
      MarketplaceStage stage = MarketplaceStage.acceptedAwaitingPayment,
      bool verified = true,
      bool online = true,
      bool accepting = true,
      int? spotsLeft = 12,
      String? selectedOfferId,
      PaymentView? payment,
    }) => PackagesViewModel.resolve(
      coachUid: 'c1',
      coachName: 'Nourhan El-Sayed',
      offers: offers ?? [_monthly, _planOnly],
      stage: stage,
      flags: _on,
      verified: verified,
      online: online,
      coachAcceptingClients: accepting,
      spotsLeft: spotsLeft,
      selectedOfferId: selectedOfferId,
      payment: payment,
    );

    test('the first package is selected so nothing renders unpriced', () {
      final m = model();
      expect(m.selected!.id, 'monthly');
      expect(m.mayPay, isTrue);
      expect(m.clearedPrice, const Money.pounds(1800));
    });

    test('P0-PAY-08 — offline draws no rails and says why', () {
      final m = model(online: false);
      expect(m.mayPay, isFalse);
      expect(m.refusal, CheckoutRefusal.offline);
      expect(
        m.rails,
        isEmpty,
        reason: 'a rail she cannot use is an invitation to try',
      );
      expect(
        m.paymentState,
        isNull,
        reason: 'nothing optimistic, nothing pending, nothing queued',
      );
    });

    test('without an accepted enquiry there is no purchase at all', () {
      final m = model(stage: MarketplaceStage.browsing);
      expect(m.mayPay, isFalse);
      expect(m.refusal, CheckoutRefusal.noAcceptedEnquiry);
      expect(m.clearedPrice, isNull);
    });

    test('an unpriced package refuses rather than charging zero', () {
      final m = model(offers: [_unpriced]);
      expect(m.refusal, CheckoutRefusal.priceUnknown);
      expect(m.clearedPrice, isNull);
      expect(m.selected!.statesAPrice, isFalse);
    });

    test('P0-PAY-02 — all three rails are offered, every time', () {
      expect(model().rails, [
        PaymentRail.card,
        PaymentRail.mobileWallet,
        PaymentRail.fawry,
      ]);
    });

    test('P0-PAY-05 — a failure invites another attempt', () {
      final failed = _failedPayment();
      final m = model(payment: PaymentView.record(failed));
      expect(m.paymentState, PaymentState.failed);
      expect(m.invitesAnotherAttempt, isTrue);
    });

    test('P0-PAY-03 — a Fawry code is surfaced while it is live', () {
      final fawry = _fawryAwaiting();
      final m = model(payment: PaymentView.record(fawry));
      expect(m.fawryReference, '7719 4402');
      expect(m.paymentState, PaymentState.awaitingProvider);
    });

    test('a seam that cannot answer renders no state and no figure', () {
      final m = model(
        payment: const PaymentView.unavailable(
          PaymentUnavailableReason.providerUnavailable,
        ),
      );
      expect(m.paymentState, isNull);
      expect(
        m.paymentUnavailable,
        PaymentUnavailableReason.providerUnavailable,
      );
    });

    test('paying may confirm, and it is not a dialog', () {
      // Rule 9's carve-out, honoured as an inline step. The guard test proves
      // no `showDialog` exists in this feature.
      expect(model().payingMayConfirm, isTrue);
    });
  });

  group('CheckoutRunner — the gate runs first, always', () {
    Future<CheckoutAttempt> run(
      _CountingProvider provider, {
      MarketplaceStage stage = MarketplaceStage.acceptedAwaitingPayment,
      bool online = true,
      bool verified = true,
      CoachingOffer? offer,
    }) => CheckoutRunner(provider: provider).start(
      relId: 'c1__client-93',
      coachUid: 'c1',
      offer: offer ?? _monthly,
      rail: PaymentRail.card,
      idempotencyKey: 'idem-1',
      flags: _on,
      stage: stage,
      verified: verified,
      online: online,
      coachAcceptingClients: true,
      spotsLeft: 12,
    );

    test('offline never reaches the provider', () async {
      final provider = _CountingProvider();
      final attempt = await run(provider, online: false);
      expect(attempt, isA<CheckoutAttemptRefused>());
      expect(
        (attempt as CheckoutAttemptRefused).reason,
        CheckoutRefusal.offline,
      );
      expect(
        provider.checkoutCalls,
        0,
        reason:
            'an offline call that fails looks like a flaky rail; an offline '
            'call that is never made looks like what it is',
      );
    });

    test('browsing never reaches the provider', () async {
      final provider = _CountingProvider();
      await run(provider, stage: MarketplaceStage.browsing);
      expect(provider.checkoutCalls, 0);
    });

    test('unverified never reaches the provider', () async {
      final provider = _CountingProvider();
      await run(provider, verified: false);
      expect(provider.checkoutCalls, 0);
    });

    test(
      'an allowed attempt reaches the provider, and still fails today',
      () async {
        final provider = _CountingProvider();
        final attempt = await run(provider);
        expect(provider.checkoutCalls, 1);
        expect(attempt, isA<CheckoutAttemptProvider>());
        expect(
          (attempt as CheckoutAttemptProvider).outcome,
          isA<CheckoutUnavailable>(),
          reason: 'there is no contracted rail, and the seam says so',
        );
      },
    );
  });

  group('H04 — the enquiry', () {
    EnquiryViewModel model({
      String text = 'Can you work with a knee that clicks?',
      MarketplaceStage stage = MarketplaceStage.browsing,
      bool verified = true,
      bool accepting = true,
      EnquiryPhase phase = EnquiryPhase.composing,
    }) => EnquiryViewModel(
      coachUid: 'c1',
      coachName: 'Nourhan El-Sayed',
      clientUid: 'client-93',
      stage: stage,
      flags: _on,
      verified: verified,
      coachAcceptingClients: accepting,
      text: text,
      phase: phase,
    );

    test('P0-COACH-05 — no money moves, and none can', () {
      expect(model().moneyMoved, isFalse);
      expect(model().relId, 'c1__client-93');
    });

    test('an empty message cannot be sent', () {
      expect(model(text: '   ').maySend, isFalse);
      expect(model(text: '   ').refusal, EnquiryRefusal.empty);
    });

    test('an unverified woman is refused with the right reason', () {
      expect(model(verified: false).refusal, EnquiryRefusal.notVerified);
    });

    test('a queued send is not a failure', () {
      final queued = model().withResult(
        const EnquirySendResult.sent(relId: 'c1__client-93', queued: true),
      );
      expect(queued.phase, EnquiryPhase.queued);
      expect(queued.maySend, isFalse);
    });

    test('a rejection is distinguishable from a queue', () {
      final rejected = model().withResult(const EnquirySendResult.rejected());
      expect(rejected.phase, EnquiryPhase.rejected);
    });

    test('the draft carries her words, trimmed', () {
      final draft = model(text: '  I train at home.  ').draft;
      expect(draft.herWords, 'I train at home.');
      expect(draft.relId, 'c1__client-93');
    });
  });

  group('H05 — my coach', () {
    MyCoachSnapshot snapshot({
      MarketplaceStage stage = MarketplaceStage.coached,
      bool reviewDue = false,
      int unread = 0,
      bool lastReviewAnswered = false,
      int? replyMins,
    }) => MyCoachSnapshot(
      relId: 'c1__client-93',
      coachName: 'Nourhan El-Sayed',
      stage: stage,
      reviewDue: reviewDue,
      unreadMessages: unread,
      lastReviewAnswered: lastReviewAnswered,
      replyMinsP50: replyMins,
    );

    test('no coach renders the invitation, not an error', () {
      const m = MyCoachViewModel(snapshot: null);
      expect(m.hasCoach, isFalse);
      expect(m.waiting, MyCoachWaiting.nothing);
    });

    test('one thing waiting at a time, in priority order', () {
      expect(
        MyCoachViewModel(
          snapshot: snapshot(
            reviewDue: true,
            unread: 3,
            lastReviewAnswered: true,
          ),
        ).waiting,
        MyCoachWaiting.reviewDue,
      );
      expect(
        MyCoachViewModel(
          snapshot: snapshot(unread: 3, lastReviewAnswered: true),
        ).waiting,
        MyCoachWaiting.unreadMessages,
      );
      expect(
        MyCoachViewModel(snapshot: snapshot(lastReviewAnswered: true)).waiting,
        MyCoachWaiting.lastReviewAnswered,
      );
      expect(
        MyCoachViewModel(snapshot: snapshot()).waiting,
        MyCoachWaiting.nothing,
      );
    });

    test('an unmeasured reply time makes no claim', () {
      expect(MyCoachViewModel(snapshot: snapshot()).showsReplyTime, isFalse);
      expect(
        MyCoachViewModel(snapshot: snapshot(replyMins: 120)).showsReplyTime,
        isTrue,
      );
    });

    test('mid-purchase is not "you have a coach"', () {
      final paying = MyCoachViewModel(
        snapshot: snapshot(stage: MarketplaceStage.paying),
      );
      expect(paying.isLive, isFalse);
      expect(paying.awaitingPayment, isTrue);
    });

    test('an ended relationship is not live', () {
      expect(
        MyCoachViewModel(
          snapshot: snapshot(stage: MarketplaceStage.coachingEnded),
        ).isLive,
        isFalse,
      );
    });
  });

  group('H06 — coaching ended', () {
    CoachingEndedViewModel model({
      bool sharingCleared = true,
      bool messagesReadable = true,
      bool planReadable = true,
    }) => CoachingEndedViewModel(
      snapshot: EndedCoachingSnapshot(
        relId: 'c1__client-93',
        coachUid: 'c1',
        coachName: 'Nourhan El-Sayed',
        endedAt: DateTime(2026, 10, 7),
        reviewCount: 4,
        sharingCleared: sharingCleared,
        messagesReadable: messagesReadable,
        planReadable: planReadable,
      ),
      flags: _on,
    );

    test('P0-COACH-08 — history stays readable and the composer is closed', () {
      expect(model().historyReadable, isTrue);
      expect(model().composerClosed, isTrue);
    });

    test('the sharing sentence is only said when it is true', () {
      expect(model().maySaySharingCleared, isTrue);
      expect(model(sharingCleared: false).maySaySharingCleared, isFalse);
    });

    test('P0-COACH-09 — working with her again starts an enquiry', () {
      // Not a checkout. A renewal still needs her to accept.
      expect(model().mayWorkTogetherAgain, isTrue);
      expect(model().stageAfterEnding.mayEnquire, isTrue);
      expect(model().stageAfterEnding.maySeePurchasableOffer, isFalse);
    });

    test('a dark marketplace hides the renewal', () {
      final dark = CoachingEndedViewModel(
        snapshot: model().snapshot,
        flags: _off,
      );
      expect(dark.mayWorkTogetherAgain, isFalse);
    });

    test('ending may confirm, and it is not a dialog', () {
      expect(model().endingMayConfirm, isTrue);
    });
  });

  group('the repository fake is strict where the real one is', () {
    test('a second enquiry collapses onto the same relationship', () async {
      // `P0-COACH-05` plus spine C1: an offline send that arrives twice is
      // still one enquiry, because the id is computed rather than minted.
      final repository = InMemoryCoachingRepository();
      const draft = EnquiryDraft(
        coachUid: 'c1',
        clientUid: 'client-93',
        herWords: 'Hello',
      );
      await repository.sendEnquiry(draft);
      await repository.sendEnquiry(draft);
      expect(repository.enquiries, hasLength(1));
      expect(repository.enquiries.keys.single, 'c1__client-93');
    });

    test('offline, an enquiry queues rather than failing', () async {
      final repository = InMemoryCoachingRepository(online: false);
      final result = await repository.sendEnquiry(
        const EnquiryDraft(
          coachUid: 'c1',
          clientUid: 'client-93',
          herWords: 'Hello',
        ),
      );
      expect(result, isA<EnquirySent>());
      expect((result as EnquirySent).queued, isTrue);
    });

    test(
      'a rejection creates nothing that looks like a relationship',
      () async {
        final repository = InMemoryCoachingRepository(rejectEnquiries: true);
        final result = await repository.sendEnquiry(
          const EnquiryDraft(
            coachUid: 'c1',
            clientUid: 'client-93',
            herWords: 'Hello',
          ),
        );
        expect(result, isA<EnquiryRejected>());
        expect(repository.enquiries, isEmpty);
      },
    );

    test('the cold fallback is bounded to its page size', () async {
      final repository = InMemoryCoachingRepository(
        rows: [for (var i = 0; i < 40; i++) _row('c$i', 'Coach $i')],
        source: DirectorySource.coldFallback,
      );
      final snapshot = await repository.directory();
      expect(snapshot.rows, hasLength(kColdFallbackPageSize));
      expect(snapshot.hasMore, isTrue);
      expect(snapshot.source, DirectorySource.coldFallback);
    });

    test('an unpublished offer is not returned', () async {
      final repository = InMemoryCoachingRepository(
        offersByCoach: {
          'c1': [
            _monthly,
            const CoachingOffer(
              id: 'draft',
              coachUid: 'c1',
              name: 'Draft',
              period: OfferPeriod.monthly,
              published: false,
            ),
          ],
        },
      );
      final offers = await repository.offers('c1');
      expect(offers.map((o) => o.id), ['monthly']);
    });

    test('there is no method that could queue a purchase', () async {
      // The strongest statement the fake can make about offline buying: the
      // repository has no payment surface at all, so there is nothing to
      // queue and nothing to replay.
      final repository = InMemoryCoachingRepository(online: false);
      expect(repository.enquiries, isEmpty);
      expect(await repository.myCoach(), isNull);
    });
  });
}

PaymentRecord _failedPayment() {
  const ledger = PaymentLedger();
  final created = PaymentRecord.created(
    providerTxnId: 'pmb-771',
    relId: 'c1__client-93',
    engagementId: 'e1',
    rail: PaymentRail.card,
    priced: const Money.pounds(1800),
    createdAt: DateTime(2026, 9, 16, 19, 5),
  );
  final opened = ledger
      .apply(created, ProviderOpened(at: DateTime(2026, 9, 16, 19, 5)))
      .record;
  return ledger
      .apply(
        opened,
        WebhookFailed(at: DateTime(2026, 9, 16, 19, 6), code: 'do_not_honour'),
      )
      .record;
}

PaymentRecord _fawryAwaiting() {
  const ledger = PaymentLedger();
  final created = PaymentRecord.created(
    providerTxnId: 'pmb-772',
    relId: 'c1__client-93',
    engagementId: 'e1',
    rail: PaymentRail.fawry,
    priced: const Money.pounds(1800),
    createdAt: DateTime(2026, 9, 16, 19, 5),
  );
  return ledger
      .apply(
        created,
        ProviderOpened(
          at: DateTime(2026, 9, 16, 19, 5),
          reference: '7719 4402',
          expiresAt: DateTime(2026, 9, 18, 19, 5),
        ),
      )
      .record;
}
