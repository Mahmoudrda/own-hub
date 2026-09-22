/// What each marketplace screen renders, decided without a widget in sight.
///
/// Every rule that matters to a woman's money is settled here or in `domain/`,
/// and a screen's job is to draw the answer. That is why these are tested with
/// no `WidgetTester`: a rule proved through a widget is a rule that can be
/// broken by a layout change.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import '../domain/checkout_gate.dart';
import '../domain/coach_directory.dart';
import '../domain/coaching_repository.dart';
import '../domain/marketplace_stage.dart';
import '../domain/money.dart';
import '../domain/payment_provider.dart';
import '../domain/payment_state_machine.dart';

// ---------------------------------------------------------------------------
// H01 — find a coach
// ---------------------------------------------------------------------------

/// Why `H01` is showing no rows.
///
/// Three different answers, because they need three different sentences. A list
/// that renders "no coaches found" when the network failed is telling a woman
/// something false about the product.
enum DirectoryEmptiness {
  /// Rows to draw.
  notEmpty,

  /// Loaded, and her facets matched nobody. A real answer.
  nothingMatched,

  /// Neither the pack nor the fallback answered. Offer another attempt.
  couldNotLoad,
}

@immutable
class FindACoachViewModel {
  const FindACoachViewModel({
    required this.snapshot,
    this.query = const DirectoryQuery(),
  });

  final DirectorySnapshot snapshot;
  final DirectoryQuery query;

  /// The rows to draw, filtered and ordered locally. Zero Firestore reads.
  List<DirectoryRow> get rows => CoachDirectory.filter(snapshot.rows, query);

  DirectoryEmptiness get emptiness {
    if (snapshot.couldNotLoad) return DirectoryEmptiness.couldNotLoad;
    return rows.isEmpty
        ? DirectoryEmptiness.nothingMatched
        : DirectoryEmptiness.notEmpty;
  }

  /// True when the rows came from the bounded indexed query rather than the
  /// pack. The screen may offer "more" only in this case, because the pack is
  /// complete by construction.
  bool get isColdFallback => snapshot.source == DirectorySource.coldFallback;

  bool get hasMore => snapshot.hasMore;

  FindACoachViewModel withQuery(DirectoryQuery next) =>
      FindACoachViewModel(snapshot: snapshot, query: next);

  /// Toggles one specialty facet.
  FindACoachViewModel toggleSpecialty(CoachingSpecialty specialty) {
    final next = <CoachingSpecialty>{...query.specialties};
    if (!next.remove(specialty)) next.add(specialty);
    return withQuery(query.copyWith(specialties: next));
  }

  FindACoachViewModel toggleLanguage(CoachingLanguage language) {
    final next = <CoachingLanguage>{...query.languages};
    if (!next.remove(language)) next.add(language);
    return withQuery(query.copyWith(languages: next));
  }

  /// Applies or clears the "under N" price band.
  FindACoachViewModel togglePriceCeiling(Money ceiling) => withQuery(
    query.copyWith(maxPrice: query.maxPrice == null ? ceiling : null),
  );

  /// Loads from a repository. One fetch, then local filtering — the screen does
  /// not refetch when she types or taps a chip.
  static Future<FindACoachViewModel> load(
    CoachingRepository repository,
  ) async => FindACoachViewModel(snapshot: await repository.directory());
}

// ---------------------------------------------------------------------------
// H02 — a coach's profile
// ---------------------------------------------------------------------------

@immutable
class CoachProfileViewModel {
  const CoachProfileViewModel({
    required this.page,
    required this.offers,
    required this.stage,
    required this.flags,
    required this.verified,
  });

  /// Null when she has published nothing. The screen says so; it does not draw
  /// her name over an empty page.
  final CoachPage? page;

  final List<CoachingOffer> offers;
  final MarketplaceStage stage;
  final FeatureFlags flags;
  final bool verified;

  bool get hasPage => page != null;

  /// Her measured reply median, or null. Null renders **no claim**.
  int? get replyMinsP50 => page?.row.replyMinsP50;

  /// Her rating, already past the five-review floor, or null.
  double? get ratingToDisplay => page?.row.ratingToDisplay;

  int get reviewCount => page?.row.reviewCount ?? 0;

  /// Places left, or null when the pack does not carry it. Never rendered as a
  /// countdown and never invented: "12 spots left" is a capacity number or it
  /// is nothing.
  int? get spotsLeft => page?.row.spotsLeft;

  /// Browsing is open to everyone, so this is true for an unverified woman too.
  /// Only the two actions below are gated.
  bool get mayBrowse => flags.isOn(Feature.marketplace);

  /// "Message before you decide" — the entry to `H04`.
  EnquiryDecision get enquiryDecision => const EnquiryGate().decide(
    flags: flags,
    stage: stage,
    verified: verified,
    coachAcceptingClients: page?.row.acceptingClients ?? false,
    // The gate's emptiness check is about the composer, not this button, so a
    // placeholder keeps the button's answer about the coach rather than about
    // a box she has not opened yet.
    message: '-',
  );

  bool get mayEnquire => enquiryDecision.mayProceed;

  /// "See her packages" — the entry to `H03`.
  ///
  /// Open to everyone who may browse, including the unverified and including a
  /// woman with no accepted enquiry. Reading a price is not buying, and hiding
  /// the price until she has committed to something is the pattern this
  /// product is built against.
  bool get maySeePackages => mayBrowse && offers.isNotEmpty;
}

// ---------------------------------------------------------------------------
// H03 — packages, and the checkout behind them
// ---------------------------------------------------------------------------

/// Every rail is offered every time, including after a failure.
const List<PaymentRail> kRailsOffered = <PaymentRail>[
  PaymentRail.card,
  PaymentRail.mobileWallet,
  PaymentRail.fawry,
];

@immutable
class PackagesViewModel {
  const PackagesViewModel({
    required this.coachUid,
    required this.coachName,
    required this.offers,
    required this.stage,
    required this.flags,
    required this.verified,
    required this.online,
    required this.decision,
    this.selectedOfferId,
    this.payment,
  });

  /// Builds the screen's state from the facts, applying [CheckoutGate] once.
  factory PackagesViewModel.resolve({
    required String coachUid,
    required String coachName,
    required List<CoachingOffer> offers,
    required MarketplaceStage stage,
    required FeatureFlags flags,
    required bool verified,
    required bool online,
    required bool coachAcceptingClients,
    int? spotsLeft,
    String? selectedOfferId,
    PaymentView? payment,
  }) {
    final selected = _select(offers, selectedOfferId);
    final decision = const CheckoutGate().decide(
      flags: flags,
      stage: stage,
      verified: verified,
      online: online,
      coachAcceptingClients: coachAcceptingClients,
      spotsLeft: spotsLeft,
      price: selected?.price,
    );
    return PackagesViewModel(
      coachUid: coachUid,
      coachName: coachName,
      offers: offers,
      stage: stage,
      flags: flags,
      verified: verified,
      online: online,
      decision: decision,
      selectedOfferId: selected?.id,
      payment: payment,
    );
  }

  final String coachUid;
  final String coachName;
  final List<CoachingOffer> offers;
  final MarketplaceStage stage;
  final FeatureFlags flags;
  final bool verified;
  final bool online;

  /// The gate's answer, computed once and rendered everywhere.
  final CheckoutDecision decision;

  final String? selectedOfferId;

  /// What the seam knows about a payment already in flight. Null until one is.
  final PaymentView? payment;

  CoachingOffer? get selected => _select(offers, selectedOfferId);

  /// The figure the gate cleared, or null. **Never a zero.**
  Money? get clearedPrice =>
      decision is CheckoutAllowed ? (decision as CheckoutAllowed).price : null;

  bool get mayPay => decision.mayProceed;

  CheckoutRefusal? get refusal =>
      decision is CheckoutRefused ? (decision as CheckoutRefused).reason : null;

  /// The rails to draw. All three, or none.
  List<PaymentRail> get rails => mayPay ? kRailsOffered : const <PaymentRail>[];

  /// The state of a payment in flight, or null when there is none or the seam
  /// cannot say. Null renders nothing about money.
  PaymentState? get paymentState => switch (payment) {
    PaymentKnown(:final record) => record.state,
    _ => null,
  };

  /// True when the seam refused to answer. The screen explains; it does not
  /// spin, and it does not show a figure.
  PaymentUnavailableReason? get paymentUnavailable => switch (payment) {
    PaymentUnknown(:final reason) => reason,
    _ => null,
  };

  /// The Fawry code, when there is one to read out.
  String? get fawryReference => switch (payment) {
    PaymentKnown(:final record) => record.reference,
    _ => null,
  };

  /// True when the screen should offer another attempt: a decline or an
  /// expired code, never a dead end.
  bool get invitesAnotherAttempt =>
      paymentState?.invitesAnotherAttempt ?? false;

  /// Paying may confirm — one of the two carve-outs from rule 9 (the other is
  /// ending coaching). It is destructive, it logs nothing and it cannot be
  /// undone, which is the same argument block and account deletion already won.
  ///
  /// **Confirmation here is a step in this model, not a dialog.** Rule 9's
  /// executable guard bans `showDialog` and `AlertDialog` in every feature
  /// folder, and it is right to: a dialog is a modal interruption whose text
  /// lives in a widget. The carve-out is honoured as an inline confirm step the
  /// screen draws, which is testable and translatable.
  bool get payingMayConfirm => true;

  static CoachingOffer? _select(List<CoachingOffer> offers, String? id) {
    if (offers.isEmpty) return null;
    for (final offer in offers) {
      if (offer.id == id) return offer;
    }
    return offers.first;
  }
}

/// What one attempt to open a checkout produced.
@immutable
sealed class CheckoutAttempt {
  const CheckoutAttempt();

  /// The gate said no, and the provider was never called.
  const factory CheckoutAttempt.refused(CheckoutRefusal reason) =
      CheckoutAttemptRefused;

  /// The gate said yes and the provider answered.
  const factory CheckoutAttempt.provider(CheckoutOutcome outcome) =
      CheckoutAttemptProvider;
}

@immutable
final class CheckoutAttemptRefused extends CheckoutAttempt {
  const CheckoutAttemptRefused(this.reason);
  final CheckoutRefusal reason;
}

@immutable
final class CheckoutAttemptProvider extends CheckoutAttempt {
  const CheckoutAttemptProvider(this.outcome);
  final CheckoutOutcome outcome;
}

/// Opens a checkout, and refuses to before the gate has agreed.
///
/// The gate runs **first and always**. A provider is never asked to price or
/// open anything for a woman who is offline, unverified, or has no accepted
/// enquiry — which matters beyond correctness: an offline call that fails looks
/// like a flaky rail, and an offline call that is never made looks like what it
/// is.
class CheckoutRunner {
  const CheckoutRunner({
    required this.provider,
    this.gate = const CheckoutGate(),
  });

  final PaymentProvider provider;
  final CheckoutGate gate;

  Future<CheckoutAttempt> start({
    required String relId,
    required String coachUid,
    required CoachingOffer offer,
    required PaymentRail rail,
    required String idempotencyKey,
    required FeatureFlags flags,
    required MarketplaceStage stage,
    required bool verified,
    required bool online,
    required bool coachAcceptingClients,
    int? spotsLeft,
  }) async {
    // The price is the server's. The gate is given what the seam last said, and
    // the seam is asked again inside the callable; neither reads a client-held
    // figure, and `CheckoutRequest` has no field one could travel in.
    final decision = gate.decide(
      flags: flags,
      stage: stage,
      verified: verified,
      online: online,
      coachAcceptingClients: coachAcceptingClients,
      spotsLeft: spotsLeft,
      price: offer.price,
    );
    if (decision is CheckoutRefused) {
      return CheckoutAttempt.refused(decision.reason);
    }
    final outcome = await provider.startCheckout(
      CheckoutRequest(
        relId: relId,
        offerId: offer.id,
        rail: rail,
        idempotencyKey: idempotencyKey,
      ),
    );
    return CheckoutAttempt.provider(outcome);
  }
}

// ---------------------------------------------------------------------------
// H04 — the enquiry
// ---------------------------------------------------------------------------

/// Where `H04` has got to.
enum EnquiryPhase {
  /// She is typing.
  composing,

  /// It reached the server.
  sent,

  /// It is on her phone under its own id, and will arrive exactly once.
  queued,

  /// The server refused it. Nothing half-created, and an inline retry.
  rejected,
}

@immutable
class EnquiryViewModel {
  const EnquiryViewModel({
    required this.coachUid,
    required this.coachName,
    required this.clientUid,
    required this.stage,
    required this.flags,
    required this.verified,
    required this.coachAcceptingClients,
    this.text = '',
    this.phase = EnquiryPhase.composing,
  });

  final String coachUid;
  final String coachName;
  final String clientUid;
  final MarketplaceStage stage;
  final FeatureFlags flags;
  final bool verified;
  final bool coachAcceptingClients;
  final String text;
  final EnquiryPhase phase;

  EnquiryDecision get decision => const EnquiryGate().decide(
    flags: flags,
    stage: stage,
    verified: verified,
    coachAcceptingClients: coachAcceptingClients,
    message: text,
  );

  bool get maySend => phase == EnquiryPhase.composing && decision.mayProceed;

  EnquiryRefusal? get refusal => decision is EnquiryRefusedBy
      ? (decision as EnquiryRefusedBy).reason
      : null;

  /// The relationship this enquiry will land on, computed rather than minted.
  String get relId =>
      relationshipIdFor(coachUid: coachUid, clientUid: clientUid);

  EnquiryDraft get draft => EnquiryDraft(
    coachUid: coachUid,
    clientUid: clientUid,
    herWords: text.trim(),
  );

  EnquiryViewModel withText(String next) => _copy(text: next);

  EnquiryViewModel withResult(EnquirySendResult result) => switch (result) {
    EnquirySent(:final queued) => _copy(
      phase: queued ? EnquiryPhase.queued : EnquiryPhase.sent,
    ),
    EnquiryRejected() => _copy(phase: EnquiryPhase.rejected),
  };

  /// **No money has moved, and none can move from here.** Stated as a property
  /// so a screen can assert it rather than claim it in copy.
  bool get moneyMoved => false;

  EnquiryViewModel _copy({String? text, EnquiryPhase? phase}) =>
      EnquiryViewModel(
        coachUid: coachUid,
        coachName: coachName,
        clientUid: clientUid,
        stage: stage,
        flags: flags,
        verified: verified,
        coachAcceptingClients: coachAcceptingClients,
        text: text ?? this.text,
        phase: phase ?? this.phase,
      );
}

// ---------------------------------------------------------------------------
// H05 — my coach
// ---------------------------------------------------------------------------

/// The one thing waiting, if anything is.
///
/// `H05`'s whole design is "one thing waiting at a time". An ordered enum makes
/// that structural: the screen renders [MyCoachWaiting] and cannot accidentally
/// draw three amber cards at once.
enum MyCoachWaiting { reviewDue, unreadMessages, lastReviewAnswered, nothing }

@immutable
class MyCoachViewModel {
  const MyCoachViewModel({required this.snapshot});

  /// Null when she has no coach. `H05` then renders `H01`'s invitation — the
  /// empty state is the onboarding, and there is no tour.
  final MyCoachSnapshot? snapshot;

  bool get hasCoach => snapshot != null;

  /// Only while the relationship is actually live. A refunded or ended
  /// relationship shows history, never a plan.
  bool get isLive => switch (snapshot?.stage) {
    MarketplaceStage.coached => true,
    _ => false,
  };

  /// True only when we measured it. Null renders no claim about her coach.
  bool get showsReplyTime => snapshot?.replyMinsP50 != null;

  int? get replyMinsP50 => snapshot?.replyMinsP50;

  MyCoachWaiting get waiting {
    final s = snapshot;
    if (s == null) return MyCoachWaiting.nothing;
    if (s.reviewDue) return MyCoachWaiting.reviewDue;
    if (s.unreadMessages > 0) return MyCoachWaiting.unreadMessages;
    if (s.lastReviewAnswered) return MyCoachWaiting.lastReviewAnswered;
    return MyCoachWaiting.nothing;
  }

  /// Whether she is mid-purchase and the screen should say so rather than
  /// pretend the coaching has started.
  bool get awaitingPayment =>
      snapshot?.stage == MarketplaceStage.paying ||
      snapshot?.stage == MarketplaceStage.acceptedAwaitingPayment;
}

// ---------------------------------------------------------------------------
// H06 — coaching ended
// ---------------------------------------------------------------------------

@immutable
class CoachingEndedViewModel {
  const CoachingEndedViewModel({required this.snapshot, required this.flags});

  final EndedCoachingSnapshot snapshot;
  final FeatureFlags flags;

  /// Everything she did is still here to read.
  bool get historyReadable =>
      snapshot.messagesReadable && snapshot.planReadable;

  /// The composer is closed. Stated by the model so a widget test asserts the
  /// rule rather than the absence of a text field.
  bool get composerClosed => true;

  /// Cycle sharing switched itself off. The screen may only say this when it
  /// is true, which is why it is read from the snapshot rather than written
  /// into the copy.
  bool get maySaySharingCleared => snapshot.sharingCleared;

  /// **"Work with her again" starts an enquiry, not a checkout.**
  ///
  /// Buy-direct is removed, and a renewal is not an exception to that: a new
  /// engagement still needs the coach to accept before a single pound moves.
  /// So the button's destination is `H04`, and this getter exists so a test can
  /// assert the destination rather than trust the router.
  MarketplaceStage get stageAfterEnding => MarketplaceStage.coachingEnded;

  bool get mayWorkTogetherAgain =>
      flags.isOn(Feature.marketplace) && stageAfterEnding.mayEnquire;

  /// Ending coaching may confirm — the second of rule 9's two carve-outs.
  /// Same posture as paying: an inline confirm step, never a dialog.
  bool get endingMayConfirm => true;
}
