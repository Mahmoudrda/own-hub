/// The link between a woman and a coach — who is listed, who asked whom, and
/// who ended up working together.
///
/// One object holds all three because they are one fact seen from three sides:
/// `H01` lists the coaches whose pages are published, `H02`/`H03` render one of
/// them, `H04` writes the only thing the marketplace can write, and `K07`/`K09`
/// — the coach's desk, built next — read the same enquiries back. Splitting
/// them would put the enquiry in one place and the relationship it becomes in
/// another, which is the defect the deterministic relationship id exists to
/// prevent.
///
/// ## Nobody is invented
///
/// The directory is **empty until she publishes a page**. There is no authored
/// coach pack anywhere in this codebase — `InMemoryCoachingRepository` ships
/// with no rows, and nothing else in `lib/` constructs a `DirectoryRow` — so a
/// seeded Nourhan with a rating and a price would be this file telling a woman
/// a mockup's figures as facts about a stranger she is deciding whether to pay.
/// [publishCoach] is the only way a row appears, its every field is copied from
/// the coach's own documents, and `ratingAverage`, `reviewCount` and
/// `certificatesCheckedAt` are left at nothing, because nobody has rated her
/// and nobody has checked her papers.
///
/// ## Enquiry first, still
///
/// [CheckoutGate] opens a checkout from one stage only:
/// `acceptedAwaitingPayment`. That is not relaxed here. She enquires, the coach
/// accepts, and only then can she pay — on this phone as on a server. The
/// accept is [acceptEnquiry], which is the coach's act and belongs on `K09`;
/// while no account is required the tester is both women, so `H03` may offer it
/// **for her own coach page only**, labelled as a test.
///
/// ## The test rail
///
/// [paymentProvider] is a [TestPaymentProvider] while `Feature.accountRequired`
/// is off and [UnavailablePaymentProvider] otherwise. It moves no money, the
/// ledger still decides every state, and the screens that use it say in words
/// that it is a test. See `coaching_test_payments.dart`.
library;

import '../features/coach/domain/coach_capacity.dart';
import '../features/coach/domain/coach_desk.dart';
import '../features/coach/domain/coach_profile.dart';
import '../features/coach/domain/enquiry.dart' as coach;
import '../features/coach/domain/offer.dart' as coach;
import '../features/coachbrand/domain/portfolio.dart' as brand;
import '../features/coachbrand/domain/portfolio_block.dart' as brand;
import '../features/coaching/domain/coach_directory.dart';
import '../features/coaching/domain/coaching_repository.dart';
import '../features/coaching/domain/marketplace_stage.dart';
import '../features/coaching/domain/money.dart';
import '../features/coaching/domain/payment_provider.dart';
import '../features/coaching/domain/payment_state_machine.dart';
import '../features/coaching/presentation/coaching_view_models.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'coaching_test_payments.dart';

/// One coach as the marketplace holds her: her row, her page and her packages.
class PublishedCoach {
  PublishedCoach({required this.row, required this.page, required this.offers});

  final DirectoryRow row;
  final CoachPage page;
  final List<CoachingOffer> offers;

  String get coachUid => row.coachUid;
}

class CoachingLinkState implements CoachingRepository {
  CoachingLinkState._();

  static final CoachingLinkState instance = CoachingLinkState._();

  /// True only in a build that is not going to a store: the only time a
  /// test rail may exist. See `AppRouter.testingAidsAllowed`.
  static bool get isTestMode => AppRouter.testingAidsAllowed;

  /// The woman using the app. The same uid the router calls `_selfUid`; the
  /// relationship id is derived from it and from the coach, so the two halves
  /// agree without either querying for the other.
  static const String clientUid = 'me';

  /// Every coach with a published page, by uid.
  final Map<String, PublishedCoach> _published = <String, PublishedCoach>{};

  /// Every enquiry that reached "the server", keyed by relationship id.
  ///
  /// A map rather than a list, on purpose: sending twice leaves **one** entry,
  /// because the id is computed rather than minted.
  final Map<String, EnquiryDraft> enquiries = <String, EnquiryDraft>{};

  /// Where she stands with each coach, by coach uid.
  final Map<String, MarketplaceStage> _stages = <String, MarketplaceStage>{};

  /// Every payment the test rail settled, by relationship id.
  final Map<String, PaymentRecord> payments = <String, PaymentRecord>{};

  MyCoachSnapshot? _myCoach;

  final Map<String, EndedCoachingSnapshot> _ended =
      <String, EndedCoachingSnapshot>{};

  late final TestPaymentProvider _testRail = TestPaymentProvider(
    priceFor: (coachUid, offerId) {
      for (final offer in offersFor(coachUid)) {
        if (offer.id == offerId) return offer.price;
      }
      return null;
    },
  );

  /// The rail `H03` checks out through.
  ///
  /// The refusing provider whenever an account is required, so the test rail
  /// cannot survive into a build where a real woman's card is involved.
  PaymentProvider get paymentProvider =>
      isTestMode ? _testRail : const UnavailablePaymentProvider();

  // ───────────────────────────────────────────────────── who is listed

  /// Publishes [page] as [coachUid]'s public page and lists her in `H01`.
  ///
  /// Called by the publish path in `coach_portfolio_state.dart` and by nothing
  /// else: a coach appears in the directory when her page goes live, and never
  /// because somebody added a row.
  void publishCoach({
    required CoachProfile profile,
    required String coachUid,
    required brand.Portfolio page,
    required List<coach.Offer> offers,
    bool verified = false,
  }) {
    final rows = <CoachingOffer>[
      for (final offer in offers)
        CoachingOffer(
          id: offer.id,
          coachUid: coachUid,
          name: offer.name,
          // Every offer this product can author is a monthly package: `K04`
          // asks for a price a month and the dictionary has a word for that
          // and none for a bare currency.
          period: OfferPeriod.monthly,
          lines: offer.lines,
          price: Money.piastres(offer.pricePiastres),
        ),
    ];

    final row = _rowFor(profile: profile, coachUid: coachUid, offers: rows);
    _published[coachUid] = PublishedCoach(
      row: row,
      page: CoachPage(
        row: row,
        blocks: <PortfolioBlock>[
          for (final block in page.visibleBlocks) _asMarketplaceBlock(block),
        ],
        // Null means unchecked, and an unchecked coach gets no badge. Nobody
        // has read a certificate in this build — not even a test coach's.
        certificateLine: null,
        portfolioVersion: brand.PortfolioVersionIds.snapshot(page.version),
      ),
      offers: rows,
    );
    AppChanges.bump();
  }

  /// She took her page down. The row goes with it; the relationship does not.
  void unpublishCoach(String coachUid) {
    _published.remove(coachUid);
    AppChanges.bump();
  }

  bool isPublished(String coachUid) => _published.containsKey(coachUid);

  /// Her own coach profile, as this build knows it: one woman holds both roles.
  bool isSelf(String coachUid) =>
      coachUid == AppRouter.coachRepository.coachUid;

  DirectoryRow _rowFor({
    required CoachProfile profile,
    required String coachUid,
    required List<CoachingOffer> offers,
  }) {
    Money? cheapest;
    for (final offer in offers) {
      final price = offer.price;
      if (price == null) continue;
      if (cheapest == null || price <= cheapest) cheapest = price;
    }
    return DirectoryRow(
      coachUid: coachUid,
      displayName: profile.displayName,
      city: profile.city,
      specialties: <CoachingSpecialty>[
        for (final specialty in profile.specialties)
          if (_facetFor(specialty) case final CoachingSpecialty facet) facet,
      ],
      languages: <CoachingLanguage>[
        for (final language in profile.languages)
          switch (language) {
            CoachLanguage.arabic => CoachingLanguage.arabic,
            CoachLanguage.english => CoachingLanguage.english,
          },
      ],
      acceptingClients: profile.acceptingClients && profile.capacity.hasRoom,
      priceFrom: cheapest,
      // Nobody has rated her, so there is no average and no count. The
      // five-review floor never comes into it.
      replyMinsP50: profile.replyTimeP50Mins,
      spotsLeft: profile.capacity.isSet ? profile.capacity.spotsLeft : null,
      certificatesCheckedAt: null,
    );
  }

  /// The coach side's fifth specialty has **no facet**, deliberately.
  ///
  /// `coach_directory.dart` states it: a searchable "weight loss" column is a
  /// weight field with a nicer name. A coach who describes herself only that
  /// way is still listed, still findable by name, city, language and price, and
  /// still renders her own words on her own page — she is simply not
  /// filterable by that facet.
  CoachingSpecialty? _facetFor(Specialty specialty) => switch (specialty) {
    Specialty.postpartum => CoachingSpecialty.postpartum,
    Specialty.beginners => CoachingSpecialty.beginners,
    Specialty.strength => CoachingSpecialty.strength,
    Specialty.pregnancy => CoachingSpecialty.pregnancy,
    Specialty.weightLoss => null,
  };

  /// The adapter between the builder's fourteen block types and the five the
  /// marketplace draws. A type `H02` has no renderer for is
  /// [UnrenderableBlock], which draws nothing — never a crash and never an
  /// empty card with her heading on it.
  PortfolioBlock _asMarketplaceBlock(brand.PortfolioBlock block) =>
      switch (block.payload) {
        brand.CoverPayload(:final headline, :final subline, :final mediaId) =>
          CoverBlock(
            headline: headline,
            subline: subline.isEmpty ? null : subline,
            imageRef: mediaId,
          ),
        brand.AboutPayload(:final paragraphs) => ProseBlock(
          heading: '',
          body: paragraphs.join('\n\n'),
        ),
        brand.MethodPayload(:final steps) => MethodBlock(
          steps: <String>[
            for (final step in steps)
              step.body.isEmpty ? step.title : '${step.title} — ${step.body}',
          ],
        ),
        brand.OffersPayload(:final offerIds) => OffersBlock(offerIds: offerIds),
        // Ids only, and consent is re-checked at every read. Nobody has
        // consented, so this resolves to nothing — which is the truth, not a
        // placeholder for a woman who withdrew.
        brand.ResultsPayload(:final resultIds) => ResultsBlock(
          resultIds: resultIds,
        ),
        brand.FaqPayload(:final items) => ProseBlock(
          heading: '',
          body: <String>[
            for (final item in items) '${item.question}\n${item.answer}',
          ].join('\n\n'),
        ),
        _ => UnrenderableBlock(block.type.name),
      };

  // ───────────────────────────────────────────── synchronous reads (routes)

  /// The directory, as `H01` renders it.
  ///
  /// [DirectorySource.pack] even when it is empty: the pack loaded and holds
  /// nobody, which is a different sentence from "we could not reach the
  /// server" and `H01` draws the two differently.
  DirectorySnapshot get snapshot => DirectorySnapshot(
    rows: <DirectoryRow>[for (final coach in _published.values) coach.row],
    source: DirectorySource.pack,
  );

  CoachPage? pageFor(String coachUid) => _published[coachUid]?.page;

  List<CoachingOffer> offersFor(String coachUid) =>
      _published[coachUid]?.offers ?? const <CoachingOffer>[];

  String coachNameFor(String coachUid) =>
      _published[coachUid]?.row.displayName ?? '';

  bool acceptingClients(String coachUid) =>
      _published[coachUid]?.row.hasPlaces ?? false;

  int? spotsLeftFor(String coachUid) => _published[coachUid]?.row.spotsLeft;

  /// Her stage with [coachUid]. Never null: browsing is the honest answer when
  /// no relationship exists, and an absent relationship is not an error.
  MarketplaceStage stageWith(String coachUid) =>
      _stages[coachUid] ?? MarketplaceStage.browsing;

  MyCoachSnapshot? get myCoachSnapshot => _myCoach;

  String relIdWith(String coachUid) =>
      relationshipIdFor(coachUid: coachUid, clientUid: clientUid);

  /// The same id, or null when no coach is open.
  ///
  /// [relationshipIdFor] throws on an empty uid — deliberately, because an id
  /// with a missing party is the bug the double underscore exists to make
  /// impossible. A route builder runs before she has tapped a row, so it asks
  /// this instead.
  String? relIdOrNull(String coachUid) =>
      coachUid.isEmpty ? null : relIdWith(coachUid);

  /// Whether she has been through the check, as this build knows it.
  ///
  /// True while no account is required, because nothing can check her and
  /// refusing her would put every marketplace action out of reach of the
  /// person testing it. `H03` and `H04` say, in words, that this is a test
  /// build and that nobody verified anything.
  bool get verified => isTestMode || AppRouter.lastVerification != null;

  /// Whether `H03` may offer the coach's own accept as a test control.
  ///
  /// Only her own coach page, only while no account is required, and only
  /// while an enquiry is actually waiting on a decision.
  bool mayTestAccept(String coachUid) =>
      isTestMode &&
      isSelf(coachUid) &&
      stageWith(coachUid) == MarketplaceStage.enquirySent;

  // ───────────────────────────────────────────────────────── the writes

  /// `H04`. The only write the marketplace has, and it moves no money.
  ///
  /// Also mirrors the enquiry onto the coach's own repository, because the two
  /// women are the same woman here and her desk should show what she just
  /// sent. The coach desk is built on top of this.
  EnquirySendResult send(EnquiryDraft draft) {
    if (draft.herWords.trim().isEmpty) {
      return const EnquirySendResult.rejected();
    }
    enquiries[draft.relId] = draft;
    _stages[draft.coachUid] = MarketplaceStage.enquirySent;
    _mirrorToCoachDesk(draft);
    AppChanges.bump();
    return EnquirySendResult.sent(relId: draft.relId, queued: false);
  }

  void _mirrorToCoachDesk(EnquiryDraft draft) {
    final repository = AppRouter.coachRepository;
    if (draft.coachUid != repository.coachUid) return;
    final at = DateTime.now();
    repository.seedEnquiry(
      coach.Enquiry(
        relId: draft.relId,
        coachUid: draft.coachUid,
        clientUid: draft.clientUid,
        status: coach.EnquiryStatus.enquiry,
        enquiredAt: at,
        // Her own words, denormalised onto the relationship at creation — a
        // coach may not read the client's user document, so this is the only
        // way the sentence reaches `K09`.
        herWords: draft.herWords,
        situation: draft.situation,
      ),
    );
    final desk = repository.deskUnbilled;
    if (desk.queue.any((item) => item.relId == draft.relId)) return;
    repository.rebuildDesk(
      CoachDesk(
        queue: <DeskQueueItem>[
          ...desk.queue,
          DeskQueueItem(
            relId: draft.relId,
            // No name is carried on an enquiry draft and none is invented: the
            // row draws an empty initial rather than somebody's name.
            displayName: '',
            reason: DeskReason.newEnquiry,
            waitingSince: at,
          ),
        ],
        overflowCount: desk.overflowCount,
        verification: desk.verification,
        firstWeek: desk.firstWeek,
        earnings: desk.earnings,
        builtAt: at,
      ),
    );
  }

  /// The coach's accept. `K09`'s button, when `K09` is wired.
  ///
  /// Moves the stage to the one stage a checkout may open from, and takes one
  /// of her places — the increment and the status change travel together,
  /// which is what stops a coach being oversold.
  void acceptEnquiry(String relId) {
    final draft = enquiries[relId];
    if (draft == null) return;
    if (stageWith(draft.coachUid) != MarketplaceStage.enquirySent) return;
    _stages[draft.coachUid] = MarketplaceStage.acceptedAwaitingPayment;
    _setCoachEnquiryStatus(relId, coach.EnquiryStatus.accepted);
    AppChanges.bump();
  }

  /// The coach's decline. The thread stays readable; she may enquire elsewhere.
  void declineEnquiry(String relId) {
    final draft = enquiries[relId];
    if (draft == null) return;
    _stages[draft.coachUid] = MarketplaceStage.enquiryDeclined;
    _setCoachEnquiryStatus(relId, coach.EnquiryStatus.declined);
    _clearDeskRow(relId);
    AppChanges.bump();
  }

  void _setCoachEnquiryStatus(String relId, coach.EnquiryStatus status) {
    final repository = AppRouter.coachRepository;
    repository.enquiry(relId).then((existing) {
      if (existing == null) return;
      repository.commitEnquiry(
        coach.EnquiryApplied(
          enquiry: coach.Enquiry(
            relId: existing.relId,
            coachUid: existing.coachUid,
            clientUid: existing.clientUid,
            status: status,
            enquiredAt: existing.enquiredAt,
            displayName: existing.displayName,
            situation: existing.situation,
            herWords: existing.herWords,
            joinedAt: existing.joinedAt,
            authorisationId: existing.authorisationId,
          ),
          capacity: repository.profileUnbilled.capacity,
        ),
      );
    });
  }

  void _clearDeskRow(String relId) {
    final repository = AppRouter.coachRepository;
    final desk = repository.deskUnbilled;
    if (!desk.queue.any((item) => item.relId == relId)) return;
    repository.rebuildDesk(
      CoachDesk(
        queue: <DeskQueueItem>[
          for (final item in desk.queue)
            if (item.relId != relId) item,
        ],
        overflowCount: desk.overflowCount,
        verification: desk.verification,
        firstWeek: desk.firstWeek,
        earnings: desk.earnings,
        builtAt: DateTime.now(),
      ),
    );
  }

  /// `H03`. Opens a checkout through the rail and, when the ledger says it is
  /// paid, makes her that coach's client.
  ///
  /// The gate runs first and always, inside [CheckoutRunner]: a provider is
  /// never asked to price or open anything for a woman the gate refused.
  /// Returns the settled record, or null when the gate or the rail said no.
  Future<PaymentRecord?> pay({
    required String coachUid,
    required CoachingOffer offer,
    required PaymentRail rail,
  }) async {
    final relId = relIdWith(coachUid);
    final attempt = await CheckoutRunner(provider: paymentProvider).start(
      relId: relId,
      coachUid: coachUid,
      offer: offer,
      rail: rail,
      // One key per attempt at one package, so a retried tap lands on the same
      // record instead of a second charge.
      idempotencyKey: '$relId:${offer.id}',
      flags: AppRouter.featureFlags,
      stage: stageWith(coachUid),
      verified: verified,
      online: true,
      coachAcceptingClients: acceptingClients(coachUid),
      spotsLeft: spotsLeftFor(coachUid),
    );
    if (attempt is! CheckoutAttemptProvider) return null;
    final outcome = attempt.outcome;
    if (outcome is! CheckoutStarted) return null;

    final record = _testRail.recordFor(outcome.checkout.providerTxnId);
    if (record == null || !record.state.unlocksCoaching) {
      _stages[coachUid] = MarketplaceStage.paying;
      AppChanges.bump();
      return record;
    }

    payments[relId] = record;
    _stages[coachUid] = MarketplaceStage.coached;
    _myCoach = MyCoachSnapshot(
      relId: relId,
      coachName: coachNameFor(coachUid),
      stage: MarketplaceStage.coached,
      // Measured, never typed. Null renders no claim about her coach.
      replyMinsP50: _published[coachUid]?.row.replyMinsP50,
      startedAt: DateTime.now(),
    );
    _takeAPlace(coachUid);
    AppChanges.bump();
    return record;
  }

  /// One of her places is taken. The coach root is the authority for the
  /// figure `H02` and `K18` both render, so it is changed there and read back.
  void _takeAPlace(String coachUid) {
    final repository = AppRouter.coachRepository;
    if (coachUid != repository.coachUid) return;
    final profile = repository.profileUnbilled;
    if (!profile.capacity.hasRoom) return;
    final next = profile.copyWith(
      capacity: CoachCapacity(
        max: profile.capacity.max,
        taken: profile.capacity.taken + 1,
      ),
    );
    repository.applyServerProfileChange(next);
    // Her row carries the figure too, so it is rebuilt from the same profile
    // rather than edited in two places.
    final published = _published[coachUid];
    if (published == null) return;
    final row = _rowFor(
      profile: next,
      coachUid: coachUid,
      offers: published.offers,
    );
    _published[coachUid] = PublishedCoach(
      row: row,
      page: CoachPage(
        row: row,
        blocks: published.page.blocks,
        certificateLine: published.page.certificateLine,
        portfolioVersion: published.page.portfolioVersion,
      ),
      offers: published.offers,
    );
  }

  /// It is over. History stays readable; renewal starts a new enquiry.
  void endCoaching(String relId) {
    final snapshot = _myCoach;
    if (snapshot == null || snapshot.relId != relId) return;
    final coachUid = relId.split('__').first;
    _stages[coachUid] = MarketplaceStage.coachingEnded;
    _ended[relId] = EndedCoachingSnapshot(
      relId: relId,
      coachUid: coachUid,
      coachName: snapshot.coachName,
      endedAt: DateTime.now(),
    );
    _myCoach = null;
    AppChanges.bump();
  }

  // ───────────────────────────────────────── CoachingRepository (async)

  @override
  Future<DirectorySnapshot> directory() async => snapshot;

  @override
  Future<CoachPage?> coachPage(String coachUid) async => pageFor(coachUid);

  @override
  Future<List<CoachingOffer>> offers(String coachUid) async =>
      offersFor(coachUid);

  @override
  Future<EnquirySendResult> sendEnquiry(EnquiryDraft draft) async =>
      send(draft);

  @override
  Future<MyCoachSnapshot?> myCoach() async => _myCoach;

  @override
  Future<EndedCoachingSnapshot?> endedCoaching(String relId) async =>
      _ended[relId];

  // ──────────────────────────────────────────────────────────── tests

  /// Back to a woman who has never looked for a coach.
  void reset() {
    _published.clear();
    enquiries.clear();
    _stages.clear();
    payments.clear();
    _testRail.records.clear();
    _ended.clear();
    _myCoach = null;
  }
}
