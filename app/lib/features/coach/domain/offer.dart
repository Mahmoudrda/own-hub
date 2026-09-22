/// `coaches/{coachUid}/offers/{offerId}` — her packages.
///
/// # One writer, enforced by the types
///
/// The owner's decision: **`K04` is the single writer of offers. `B06` and `K18`
/// read them.** G12 §7.2 says the same thing from the other side — G12 publishes
/// an `OfferRepository` to G13 as *"the **single** source of offers"* — and §9 Q5
/// records what happens without it: the portfolio embeds `{name, price, lines}`,
/// a price is edited in one place, and the two disagree silently on the screen
/// that takes money.
///
/// So the read and the write are **two interfaces**, not one. [OfferReader] is
/// what `K18`, `B06` and the public page are handed. [OfferWriter] exists, and
/// the only thing that may hold one is [PackagesEditor], which `K04` constructs.
/// A screen given an [OfferReader] cannot write an offer — not by convention, by
/// type — and `test/features/coach/offers_single_writer_test.dart` scans the
/// source to prove nothing else reaches for the writer.
///
/// # Free text is correct here, and wrong in `coach_credentials.dart`
///
/// An offer's name is *her words about her own package*. The dictionary already
/// says so: *"Write your own offers. Two is common, one is fine, and nothing
/// forces them to look alike."* A certificate is a claim about a third party and
/// is therefore an id. The two files disagree deliberately.
///
/// # The price is a number
///
/// G12 §6: `request.resource.data.price is number` — *"never free text"*.
/// [OfferDraft.validate] refuses anything else, and the amount is held in minor
/// units for the reason every money type is: a double cannot carry 1,800.00 and
/// 1,440.00 and their difference without eventually disagreeing with the
/// provider by a piastre.
///
/// # Authoring is not publishing
///
/// A coach whose certificates are still under review **may write every offer and
/// may publish none**. [PackagesEditor] takes her [CoachPublishingRights] and
/// stores anything she writes as unpublished until a human has cleared her, so
/// `K06`'s promise that she can start now is true without anything leaking onto
/// a page nobody has checked.
// `prefer_initializing_formals` asks for `required this._writer`, which Dart
// forbids outright: a named parameter cannot begin with an underscore. The only
// way to satisfy the lint is to make the field public — and `_writer` being
// unreachable is the entire single-writer guarantee this file exists for. A
// public `writer` would hand every holder of a [PackagesEditor] the ability to
// write an offer around the rights check directly above it. Same lint, same
// answer, same reasoning as `lib/domain/identity/user_roles.dart`.
// ignore_for_file: prefer_initializing_formals
library;

import 'package:meta/meta.dart';

import 'coach_verification.dart';

/// The only currency this product prices in. G12 §6 pins it in the rules.
const String coachOfferCurrency = 'EGP';

/// One package, as stored.
@immutable
class Offer {
  const Offer({
    required this.id,
    required this.name,
    required this.pricePiastres,
    required this.lines,
    required this.published,
    this.currency = coachOfferCurrency,
    this.updatedAt,
  });

  /// Deterministic per coach in production, so a replayed create collides with
  /// itself rather than making a second identical package (spine C1).
  final String id;

  /// Her words. "Monthly coaching", "A program, no check-ins".
  final String name;

  /// Minor units — piastres. 1,800 EGP is 180000.
  final int pricePiastres;

  /// What is in it, in her words. `K18` and `B06` render these.
  final List<String> lines;

  /// Whether a client can see it. False while she is being checked.
  final bool published;

  final String currency;
  final DateTime? updatedAt;

  /// Her share, in minor units.
  ///
  /// Eighty per cent, stated everywhere (`K04`, `K17`, `B06`). Integer
  /// arithmetic, rounding toward her rather than away: a half-piastre is not
  /// worth taking off a coach.
  int get sharePiastres => (pricePiastres * 4 + 4) ~/ 5;

  Offer copyWith({
    String? name,
    int? pricePiastres,
    List<String>? lines,
    bool? published,
    DateTime? updatedAt,
  }) => Offer(
    id: id,
    name: name ?? this.name,
    pricePiastres: pricePiastres ?? this.pricePiastres,
    lines: lines ?? this.lines,
    published: published ?? this.published,
    currency: currency,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Why an offer could not be written.
enum OfferRefusal {
  /// She left the name blank. `K04` asks for what it is called.
  unnamed,

  /// Negative, or not expressible as minor units.
  priceOutOfRange,

  /// More than the six a profile can carry (G12 §2, `offers limit 20`, and the
  /// design's own "m ≤ 6").
  tooManyOffers,

  /// She is suspended. Every other state may author.
  mayNotAuthor,
}

/// What `K04` sends.
@immutable
class OfferDraft {
  const OfferDraft._({
    required this.id,
    required this.name,
    required this.pricePiastres,
    required this.lines,
  });

  /// Builds a draft, or returns null with the reason.
  ///
  /// The price arrives as minor units already. There is no overload taking a
  /// string, and that absence is the rule: a screen that parsed "1,800" into a
  /// price would be the free-text path G12 §6 forbids.
  static ({OfferDraft? draft, OfferRefusal? refusal}) validate({
    required String id,
    required String name,
    required int pricePiastres,
    List<String> lines = const <String>[],
  }) {
    if (name.trim().isEmpty) {
      return (draft: null, refusal: OfferRefusal.unnamed);
    }
    if (pricePiastres < 0) {
      return (draft: null, refusal: OfferRefusal.priceOutOfRange);
    }
    return (
      draft: OfferDraft._(
        id: id,
        name: name.trim(),
        pricePiastres: pricePiastres,
        lines: lines,
      ),
      refusal: null,
    );
  }

  final String id;
  final String name;
  final int pricePiastres;
  final List<String> lines;
}

/// Reading offers. What `K18`, `B06` and the public page are given.
///
/// There is no write method here, and that is the whole design.
abstract class OfferReader {
  /// Everything she has written, published or not. Her own screens see drafts.
  List<Offer> allOffers();

  /// What a client sees. Published only.
  List<Offer> publicOffers();

  Offer? offerById(String id);
}

/// Writing offers. **Only [PackagesEditor] may hold one.**
abstract class OfferWriter {
  Future<void> writeOffer(Offer offer);
  Future<void> deleteOffer(String offerId);
}

/// The outcome of a `K04` save.
@immutable
sealed class OfferSave {
  const OfferSave();
  const factory OfferSave.saved(Offer offer) = OfferSaved;
  const factory OfferSave.refused(OfferRefusal reason) = OfferSaveRefused;
}

class OfferSaved extends OfferSave {
  const OfferSaved(this.offer);
  final Offer offer;
}

class OfferSaveRefused extends OfferSave {
  const OfferSaveRefused(this.reason);
  final OfferRefusal reason;
}

/// The single write path for offers, and the reason `K04` owns them.
///
/// Constructed by `K04`'s view model. Every other screen in this feature is
/// handed an [OfferReader] and therefore physically cannot write one.
class PackagesEditor {
  const PackagesEditor({
    required OfferReader reader,
    required OfferWriter writer,
    required this.rights,
  }) : _reader = reader,
       _writer = writer;

  /// The design's own ceiling: `K18` lists "m ≤ 6" packages, and a profile with
  /// more than six offers stops being a decision and becomes a menu.
  static const int maxOffers = 6;

  final OfferReader _reader;
  final OfferWriter _writer;

  /// What her credential state lets her do. Authoring is open to everyone but a
  /// suspended coach; publishing is open only to a coach a human has cleared.
  final CoachPublishingRights rights;

  /// Everything she has written, published or not.
  ///
  /// A read-through so `K04` does not have to be handed the reader *and* the
  /// editor and keep the two in step. It widens nothing: the writer stays
  /// private, and this returns the same list any [OfferReader] would.
  List<Offer> get offers => _reader.allOffers();

  Future<OfferSave> save(OfferDraft draft, {DateTime? now}) async {
    if (!rights.mayAuthor) {
      return const OfferSave.refused(OfferRefusal.mayNotAuthor);
    }

    final existing = _reader.offerById(draft.id);
    if (existing == null && _reader.allOffers().length >= maxOffers) {
      return const OfferSave.refused(OfferRefusal.tooManyOffers);
    }

    final offer = Offer(
      id: draft.id,
      name: draft.name,
      pricePiastres: draft.pricePiastres,
      lines: draft.lines,
      // The rule that makes K06 honest: she writes it now, and nobody sees it
      // until her certificates clear. Not a flag she can set — a fact about her
      // account, applied here.
      published: rights.mayPublish && (existing?.published ?? false),
      updatedAt: now ?? DateTime.now(),
    );
    await _writer.writeOffer(offer);
    return OfferSave.saved(offer);
  }

  /// Makes an offer visible to clients.
  ///
  /// Refuses while she is being checked. `K18` shows the offer and states that
  /// it is not live yet, rather than hiding it — she wrote it, it is hers.
  Future<OfferSave> publish(String offerId, {DateTime? now}) async {
    final offer = _reader.offerById(offerId);
    if (offer == null) {
      return const OfferSave.refused(OfferRefusal.unnamed);
    }
    if (!rights.mayPublish) {
      return const OfferSave.refused(OfferRefusal.mayNotAuthor);
    }
    final next = offer.copyWith(
      published: true,
      updatedAt: now ?? DateTime.now(),
    );
    await _writer.writeOffer(next);
    return OfferSave.saved(next);
  }

  Future<void> remove(String offerId) => _writer.deleteOffer(offerId);
}
