/// What the marketplace reads, and the one thing it writes.
///
/// The asymmetry is the shape of this interface. `H01`, `H02`, `H03`, `H05` and
/// `H06` are **reads**: a CDN pack, a published portfolio, a coach's own offer
/// documents, and the relationship document the client already has in cache.
/// The single write in the whole feature is [sendEnquiry], and it moves no
/// money and takes no place.
///
/// ## Three things this interface deliberately does not do
///
///  1. **It cannot mark anything paid.** There is no method that takes a
///     payment state, and no method that returns one. Money moves through
///     `payment_provider.dart` and lands through a signed webhook; this
///     interface never sees it.
///  2. **It cannot create a relationship at a price.** [sendEnquiry] takes her
///     words and a coach id. The price is copied server-side at acceptance,
///     from the coach's own offer document, which is what makes a later price
///     rise unable to reach an existing client.
///  3. **It cannot list relationships.** The client reaches her one
///     relationship through a deterministic id, so there is no query to write
///     and no collection-group read to forget to bound.
library;

import 'package:meta/meta.dart';

import 'coach_directory.dart';
import 'marketplace_stage.dart';
import 'money.dart';

/// One package, as the coach wrote it.
@immutable
class CoachingOffer {
  const CoachingOffer({
    required this.id,
    required this.coachUid,
    required this.name,
    required this.period,
    this.lines = const <String>[],
    this.price,
    this.published = true,
  });

  final String id;
  final String coachUid;

  /// "Monthly coaching". Her words, from her own offer document — not a tier
  /// name this product invented.
  final String name;

  final OfferPeriod period;

  /// What she gets weekly, in the coach's own words.
  final List<String> lines;

  /// The server's price, or **null when the seam could not supply it**.
  ///
  /// Null is not zero and not free. A screen given null renders the package
  /// without a figure and does not offer to buy it.
  final Money? price;

  final bool published;

  /// Whether a price may be stated for this package at all.
  bool get statesAPrice => price != null;
}

/// How often she pays.
///
/// This is load-bearing for display, not only for billing: the dictionary has
/// a word for "EGP a month" and no word for a bare currency, so a one-off
/// package currently has no honest way to render its figure. See
/// `presentation/coaching_money.dart`.
enum OfferPeriod { monthly, oneOff }

/// A block on a coach's page, in the order she put it there.
///
/// `H02` renders the list she built. Two coaches never look alike here, and
/// there is no hand-built layout to fall out of sync with the builder
/// (`P0-COACH-02`). A block she hid is **absent from this list** — not present
/// and skipped, which would leave a gap to render and a body to download.
@immutable
sealed class PortfolioBlock {
  const PortfolioBlock();
}

/// The cover image and her headline.
@immutable
final class CoverBlock extends PortfolioBlock {
  const CoverBlock({required this.headline, this.subline, this.imageRef});
  final String headline;
  final String? subline;
  final String? imageRef;
}

/// A paragraph she wrote.
@immutable
final class ProseBlock extends PortfolioBlock {
  const ProseBlock({required this.heading, required this.body});
  final String heading;
  final String body;
}

/// "How I work" — up to three numbered steps.
@immutable
final class MethodBlock extends PortfolioBlock {
  const MethodBlock({required this.steps});
  final List<String> steps;
}

/// "What I offer" — her packages, rendered from the same documents `H03` reads
/// so the price cannot be stale in one place and current in the other.
@immutable
final class OffersBlock extends PortfolioBlock {
  const OffersBlock({required this.offerIds});
  final List<String> offerIds;
}

/// "Client results" — consented, and only while consent is live.
@immutable
final class ResultsBlock extends PortfolioBlock {
  const ResultsBlock({required this.resultIds, this.consentNote});
  final List<String> resultIds;

  /// The sentence naming the woman who agreed, chose the pictures, and can
  /// withdraw them.
  final String? consentNote;
}

/// A block type this build does not know how to draw.
///
/// The builder is versioned separately from the app, so a coach on a newer
/// builder can publish a block an older app has no renderer for. Rendering
/// nothing is correct; crashing, or drawing an empty card with her heading on
/// it, is not.
@immutable
final class UnrenderableBlock extends PortfolioBlock {
  const UnrenderableBlock(this.kind);
  final String kind;
}

/// A coach's public page, as `H02` renders it.
@immutable
class CoachPage {
  const CoachPage({
    required this.row,
    required this.blocks,
    this.certificateLine,
    this.portfolioVersion,
  });

  /// The same row shape the directory uses, so the header on `H02` and the row
  /// on `H01` cannot disagree about her price or her rating.
  final DirectoryRow row;

  /// Her blocks, in her order. Hidden ones are not here.
  final List<PortfolioBlock> blocks;

  /// "NASM CPT · pre and postnatal · verified", when a human has checked it.
  /// Null means unchecked, and an unchecked coach does not get a badge.
  final String? certificateLine;

  final String? portfolioVersion;

  /// Her published packages, pulled from the offers block if she placed one.
  List<String> get offerIds => <String>[
    for (final block in blocks)
      if (block is OffersBlock) ...block.offerIds,
  ];
}

/// What she typed on `H04`.
@immutable
class EnquiryDraft {
  const EnquiryDraft({
    required this.coachUid,
    required this.clientUid,
    required this.herWords,
    this.situation = '',
  });

  final String coachUid;
  final String clientUid;

  /// Her own words. This is the only way her sentence reaches the coach's
  /// enquiry screen: a coach may not read the client's user document, so the
  /// text is denormalised onto the relationship at creation.
  final String herWords;

  /// A short facet line — "postpartum, home, 20 minutes" — assembled from the
  /// profile she has already filled in, so she is not asked twice.
  final String situation;

  /// The deterministic relationship id this draft will land on.
  ///
  /// Computed, not minted. An enquiry retried after a dropped connection lands
  /// on the same document instead of forking the thread.
  String get relId =>
      relationshipIdFor(coachUid: coachUid, clientUid: clientUid);
}

/// What sending produced.
@immutable
sealed class EnquirySendResult {
  const EnquirySendResult();

  /// It reached the server, or it is queued on her phone under its own id and
  /// will arrive exactly once.
  const factory EnquirySendResult.sent({
    required String relId,
    required bool queued,
  }) = EnquirySent;

  /// The server said no. Carries nothing that looks like a relationship,
  /// because none was created.
  const factory EnquirySendResult.rejected() = EnquiryRejected;
}

@immutable
final class EnquirySent extends EnquirySendResult {
  const EnquirySent({required this.relId, required this.queued});
  final String relId;

  /// True while it is on her phone waiting for signal. The bubble renders at
  /// full opacity with the sync glyph — never greyed out, and never a
  /// "failed to save" for something that will sync.
  final bool queued;
}

@immutable
final class EnquiryRejected extends EnquirySendResult {
  const EnquiryRejected();
}

/// `H05` — what the Coaching tab shows a woman who has a coach.
@immutable
class MyCoachSnapshot {
  const MyCoachSnapshot({
    required this.relId,
    required this.coachName,
    required this.stage,
    this.replyMinsP50,
    this.startedAt,
    this.endsAt,
    this.reviewDue = false,
    this.lastReviewAnswered = false,
    this.unreadMessages = 0,
  });

  final String relId;
  final String coachName;
  final MarketplaceStage stage;

  /// Measured, never typed. Null renders no claim.
  final int? replyMinsP50;

  final DateTime? startedAt;
  final DateTime? endsAt;

  /// The one thing waiting, if anything is.
  final bool reviewDue;
  final bool lastReviewAnswered;

  final int unreadMessages;
}

/// `H06` — what stays readable after it is over.
@immutable
class EndedCoachingSnapshot {
  const EndedCoachingSnapshot({
    required this.relId,
    required this.coachUid,
    required this.coachName,
    required this.endedAt,
    this.reviewCount = 0,
    this.messagesReadable = true,
    this.planReadable = true,
    this.sharingCleared = true,
  });

  final String relId;
  final String coachUid;
  final String coachName;
  final DateTime endedAt;
  final int reviewCount;

  /// History is fully readable; the composer is closed.
  final bool messagesReadable;
  final bool planReadable;

  /// Cleared by the `onRelationshipEnded` Function, not by a sentence on a
  /// screen. `H06` states it because it is true, and a test asserts it is true
  /// before the screen may state it.
  final bool sharingCleared;
}

/// The marketplace's reads, and its single write.
abstract class CoachingRepository {
  /// The directory, from the pack or the bounded fallback.
  ///
  /// Never throws. A failure is [DirectorySource.unavailable] with no rows, so
  /// "nothing loaded" and "nothing matched" are different answers rather than
  /// the same empty list.
  Future<DirectorySnapshot> directory();

  /// One coach's published page, or null when she has none.
  Future<CoachPage?> coachPage(String coachUid);

  /// Her published packages. Read from the coach's own offer documents, which
  /// is the same source the portfolio renders from.
  Future<List<CoachingOffer>> offers(String coachUid);

  /// Sends an enquiry. **The only write in this feature.**
  Future<EnquirySendResult> sendEnquiry(EnquiryDraft draft);

  /// Her current coaching, or null when she has none.
  Future<MyCoachSnapshot?> myCoach();

  /// A relationship that is over.
  Future<EndedCoachingSnapshot?> endedCoaching(String relId);
}

/// An in-memory implementation, for tests and for building screens before
/// there is a Firebase project.
///
/// Strict where the real one is strict, because a fake that accepts anything
/// lets a screen pass its tests and then fail in production:
///
///  * a second enquiry to the same coach **collapses onto the same relationship
///    id** rather than creating a second thread;
///  * offline, [sendEnquiry] returns `queued: true` — an enquiry is a message
///    and messages queue — while there is **no method here at all** that could
///    queue a purchase;
///  * [directory] honours [DirectorySource.coldFallback]'s page size, so a test
///    cannot pass over an unbounded list the real query could never return;
///  * a coach with no published page returns null rather than an empty page,
///    so `H02` renders "nothing to show" rather than her name over a void.
class InMemoryCoachingRepository implements CoachingRepository {
  InMemoryCoachingRepository({
    this.clientUid = 'client',
    List<DirectoryRow> rows = const <DirectoryRow>[],
    Map<String, CoachPage> pages = const <String, CoachPage>{},
    Map<String, List<CoachingOffer>> offersByCoach =
        const <String, List<CoachingOffer>>{},
    this.source = DirectorySource.pack,
    this.online = true,
    this.rejectEnquiries = false,
    MyCoachSnapshot? myCoachSnapshot,
    Map<String, EndedCoachingSnapshot> ended =
        const <String, EndedCoachingSnapshot>{},
  }) : _rows = List<DirectoryRow>.unmodifiable(rows),
       _pages = Map<String, CoachPage>.unmodifiable(pages),
       _offers = Map<String, List<CoachingOffer>>.unmodifiable(offersByCoach),
       _myCoach = myCoachSnapshot,
       _ended = Map<String, EndedCoachingSnapshot>.unmodifiable(ended);

  final String clientUid;
  final List<DirectoryRow> _rows;
  final Map<String, CoachPage> _pages;
  final Map<String, List<CoachingOffer>> _offers;
  final Map<String, EndedCoachingSnapshot> _ended;

  /// Which delivery path the test is exercising.
  DirectorySource source;

  /// Connectivity. Affects enquiries only; there is nothing here a purchase
  /// could use.
  bool online;

  /// For `P2-ERR-H06`.
  bool rejectEnquiries;

  MyCoachSnapshot? _myCoach;

  /// Every enquiry that reached "the server", keyed by relationship id.
  ///
  /// A map rather than a list, on purpose: a test asserts that sending twice
  /// leaves **one** entry, which is `P0-COACH-05` and spine C1 in one line.
  final Map<String, EnquiryDraft> enquiries = <String, EnquiryDraft>{};

  /// How many times the directory was fetched. A test asserts `H01` does not
  /// refetch on every keystroke.
  int directoryFetches = 0;

  @override
  Future<DirectorySnapshot> directory() async {
    directoryFetches++;
    switch (source) {
      case DirectorySource.pack:
        return DirectorySnapshot(rows: _rows, source: DirectorySource.pack);
      case DirectorySource.coldFallback:
        final page = _rows.where((r) => r.acceptingClients).toList();
        return DirectorySnapshot(
          rows: page.take(kColdFallbackPageSize).toList(),
          source: DirectorySource.coldFallback,
          hasMore: page.length > kColdFallbackPageSize,
        );
      case DirectorySource.unavailable:
        return const DirectorySnapshot.unavailable();
    }
  }

  @override
  Future<CoachPage?> coachPage(String coachUid) async => _pages[coachUid];

  @override
  Future<List<CoachingOffer>> offers(String coachUid) async =>
      (_offers[coachUid] ?? const <CoachingOffer>[])
          .where((o) => o.published)
          .toList();

  @override
  Future<EnquirySendResult> sendEnquiry(EnquiryDraft draft) async {
    if (rejectEnquiries) return const EnquirySendResult.rejected();
    // Deterministic id: a retry collapses onto itself instead of forking the
    // thread, so an offline send that arrives twice is still one enquiry.
    enquiries[draft.relId] = draft;
    return EnquirySendResult.sent(relId: draft.relId, queued: !online);
  }

  @override
  Future<MyCoachSnapshot?> myCoach() async => _myCoach;

  /// Moves the fake forward the way a server would.
  void applyServerCoachingChange(MyCoachSnapshot? next) => _myCoach = next;

  @override
  Future<EndedCoachingSnapshot?> endedCoaching(String relId) async =>
      _ended[relId];
}
