/// The page is an ordered list of blocks. This is the block.
///
/// G13's one accountable sentence starts here: *"the page is an ordered list of
/// blocks rendered from data, the client-facing profile renders that same list
/// through the same widget."* Every consequence follows from the envelope:
///
///   * **Order is the array index.** There is no `order` field, so there is
///     nothing for a reorder to drift from. A reorder is a permutation and
///     nothing else.
///   * **Hiding is one boolean**, and the payload is retained untouched.
///   * **A type may repeat** any number of times. A coach with two methods has
///     two `method` blocks; nothing complains.
///   * **`id` is never reused** within a portfolio, because analytics and the
///     publish diff key on it.
///
/// Adding a fifteenth type is a registry entry plus a widget — no route, no
/// screen, no migration. K11: a reader skips a type it does not know, so an old
/// build never crashes on a page built by a new one.
///
/// ## What is not here
///
/// No `consentState`, no `mediaIds` on a `results` block, no offer price, no
/// certificate name. Those are **ids**, resolved at read time against documents
/// that can change or vanish underneath a published page. That is the whole of
/// C10 in the data model: there is nothing to copy, so nothing gets copied.
library;

import 'dart:convert';

import 'package:meta/meta.dart';

/// At most 40 blocks in one portfolio (G13 §1.1). 40 × 8 KB is a 320 KB
/// ceiling against Firestore's 1 MiB document limit.
const int kMaxBlocks = 40;

/// At most 8 KB of payload per block.
const int kMaxPayloadBytes = 8 * 1024;

/// At most 12 media ids per block.
const int kMaxMediaIdsPerBlock = 12;

/// The fourteen types.
enum BlockType {
  cover,
  about,
  method,
  offers,
  results,
  testimonials,
  video,
  gallery,
  certificates,
  faq,
  availability,
  freebie,
  numbers,
  cta;

  static BlockType? tryParse(String value) {
    for (final t in BlockType.values) {
      if (t.name == value) return t;
    }
    return null;
  }

  /// Whether a coach may add more than one of these.
  ///
  /// B03 lists every type not currently capped out. Only `cover` is capped at
  /// one: two covers is not a page with two covers, it is a mistake.
  int get maxPerPortfolio => this == BlockType.cover ? 1 : kMaxBlocks;
}

/// Base for the fourteen payloads.
sealed class BlockPayload {
  const BlockPayload();

  /// The type this payload belongs to. Checked by [PortfolioBlock] so a
  /// `cover` block cannot carry a `faq` payload.
  BlockType get type;

  Map<String, Object?> toJson();

  /// The encoded size, against [kMaxPayloadBytes].
  int get byteLength => utf8.encode(jsonEncode(toJson())).length;
}

// ─────────────────────────────────────────────────────────── 1. cover

enum CoverLayout {
  textOverPhoto,
  photoAbove,
  noPhoto;

  static CoverLayout? tryParse(String value) {
    for (final v in CoverLayout.values) {
      if (v.name == value) return v;
    }
    return null;
  }
}

final class CoverPayload extends BlockPayload {
  const CoverPayload({
    required this.layout,
    this.mediaId,
    this.focalX = 0.5,
    this.focalY = 0.5,
    this.overlay = 0.0,
    this.headline = '',
    this.subline = '',
  });

  final CoverLayout layout;
  final String? mediaId;
  final double focalX;
  final double focalY;

  /// The scrim alpha. Clamped **below** by `OverlayFloor.minAlpha` and above at
  /// 0.9 — `BlockValidator` rejects anything under the computed floor.
  final double overlay;

  /// ≤64 graphemes.
  final String headline;

  /// ≤80 graphemes.
  final String subline;

  CoverPayload copyWith({
    CoverLayout? layout,
    String? mediaId,
    bool clearMedia = false,
    double? focalX,
    double? focalY,
    double? overlay,
    String? headline,
    String? subline,
  }) => CoverPayload(
    layout: layout ?? this.layout,
    mediaId: clearMedia ? null : (mediaId ?? this.mediaId),
    focalX: focalX ?? this.focalX,
    focalY: focalY ?? this.focalY,
    overlay: overlay ?? this.overlay,
    headline: headline ?? this.headline,
    subline: subline ?? this.subline,
  );

  @override
  BlockType get type => BlockType.cover;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'layout': layout.name,
    if (mediaId != null) 'media': mediaId,
    'focal': <String, Object?>{'x': focalX, 'y': focalY},
    'overlay': overlay,
    'headline': headline,
    'subline': subline,
  };
}

// ─────────────────────────────────────────────────────────── 2. about

final class AboutPayload extends BlockPayload {
  const AboutPayload({
    this.paragraphs = const <String>[],
    this.portraitMediaId,
  });

  /// ≤4 paragraphs, each ≤400 graphemes. `MarketingClaimPolicy` runs over every
  /// one of them — the owner's extension beyond G13 §5.
  final List<String> paragraphs;

  final String? portraitMediaId;

  @override
  BlockType get type => BlockType.about;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'paragraphs': paragraphs,
    if (portraitMediaId != null) 'portrait': portraitMediaId,
  };
}

// ─────────────────────────────────────────────────────────── 3. method

@immutable
class MethodStep {
  const MethodStep({required this.title, required this.body});

  /// ≤40 graphemes.
  final String title;

  /// ≤200 graphemes.
  final String body;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'body': body,
  };
}

final class MethodPayload extends BlockPayload {
  const MethodPayload({
    this.steps = const <MethodStep>[],
    this.numbered = true,
  });

  /// 1–8 steps.
  final List<MethodStep> steps;
  final bool numbered;

  @override
  BlockType get type => BlockType.method;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'steps': [for (final s in steps) s.toJson()],
    'numbered': numbered,
  };
}

// ─────────────────────────────────────────────────────────── 4. offers

enum OffersDisplay { cards, list }

final class OffersPayload extends BlockPayload {
  const OffersPayload({
    this.offerIds = const <String>[],
    this.display = OffersDisplay.cards,
    this.showSpotsLeft = true,
  });

  /// ≤6 ids. **Ids only.** The price lives on K04's offer document; the
  /// immutable `snapshot` is written by the publish Function, never by the app,
  /// and is absent from a draft by construction — this class has no field for
  /// it, so B06 cannot write one even by accident.
  final List<String> offerIds;

  final OffersDisplay display;

  /// Read from the coach root at render, never copied.
  final bool showSpotsLeft;

  @override
  BlockType get type => BlockType.offers;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'offerIds': offerIds,
    'display': display.name,
    'showSpotsLeft': showSpotsLeft,
  };
}

// ─────────────────────────────────────────────────────────── 5. results

enum ResultsDisplay { strip, stack }

final class ResultsPayload extends BlockPayload {
  const ResultsPayload({
    this.resultIds = const <String>[],
    this.display = ResultsDisplay.strip,
    this.showNumbers = true,
  });

  /// ≤12 ids. **Ids only — no media, no quote, no consent flag. C10.**
  ///
  /// There is no field on this class that could hold a client's photograph or
  /// her sentence, which is why a withdrawal three months after publication
  /// still takes effect on the published version: the published version never
  /// held anything.
  final List<String> resultIds;

  final ResultsDisplay display;
  final bool showNumbers;

  @override
  BlockType get type => BlockType.results;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'resultIds': resultIds,
    'display': display.name,
    'showNumbers': showNumbers,
  };
}

// ─────────────────────────────────────────────────────── 6. testimonials

@immutable
class Testimonial {
  const Testimonial({
    required this.quote,
    this.attribution = '',
    this.resultId,
  });

  /// ≤240 graphemes.
  final String quote;

  /// ≤40 graphemes. A full name is another person's data (G13 §10 Q7).
  final String attribution;

  /// When present, this item is consent-gated **exactly like a result**.
  final String? resultId;

  Map<String, Object?> toJson() => <String, Object?>{
    'quote': quote,
    'attribution': attribution,
    if (resultId != null) 'resultId': resultId,
  };
}

final class TestimonialsPayload extends BlockPayload {
  const TestimonialsPayload({this.items = const <Testimonial>[]});

  /// ≤8.
  final List<Testimonial> items;

  @override
  BlockType get type => BlockType.testimonials;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'items': [for (final i in items) i.toJson()],
  };
}

// ─────────────────────────────────────────────────────────── 7. video

final class VideoPayload extends BlockPayload {
  const VideoPayload({
    required this.mediaId,
    this.posterMediaId,
    this.caption = '',
  });

  final String mediaId;
  final String? posterMediaId;

  /// ≤120 graphemes.
  final String caption;

  /// A constant, not a setting. Low-data mode and G4's `VideoPolicy` own
  /// playback; a portfolio block that could autoplay would be a second policy.
  bool get autoplay => false;

  @override
  BlockType get type => BlockType.video;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'media': mediaId,
    if (posterMediaId != null) 'poster': posterMediaId,
    'caption': caption,
    'autoplay': false,
  };
}

// ────────────────────────────────────────────────────────── 8. gallery

enum GalleryLayout { grid, carousel }

enum GalleryAspect {
  square('1:1'),
  portrait('4:5');

  const GalleryAspect(this.label);
  final String label;
}

final class GalleryPayload extends BlockPayload {
  const GalleryPayload({
    this.mediaIds = const <String>[],
    this.layout = GalleryLayout.grid,
    this.aspect = GalleryAspect.square,
  });

  /// ≤12 ids.
  final List<String> mediaIds;
  final GalleryLayout layout;
  final GalleryAspect aspect;

  @override
  BlockType get type => BlockType.gallery;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'mediaIds': mediaIds,
    'layout': layout.name,
    'aspect': aspect.label,
  };
}

// ─────────────────────────────────────────────────────── 9. certificates

final class CertificatesPayload extends BlockPayload {
  const CertificatesPayload({
    this.certIds = const <String>[],
    this.showCheckedDate = true,
  });

  /// Ids into `coaches/{coachUid}.verifiedCerts`, owned by K04.
  ///
  /// **No free text.** There is no `name` or `body` field on this payload, so a
  /// coach cannot type a certificate she does not hold. An id whose certificate
  /// is not `verified` is dropped at render, which means a revocation takes
  /// effect on an already-published page without republishing it.
  final List<String> certIds;

  final bool showCheckedDate;

  @override
  BlockType get type => BlockType.certificates;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'certIds': certIds,
    'showCheckedDate': showCheckedDate,
  };
}

// ─────────────────────────────────────────────────────────── 10. faq

@immutable
class FaqItem {
  const FaqItem({required this.question, required this.answer});

  /// ≤100 graphemes.
  final String question;

  /// ≤400 graphemes.
  final String answer;

  Map<String, Object?> toJson() => <String, Object?>{
    'q': question,
    'a': answer,
  };
}

final class FaqPayload extends BlockPayload {
  const FaqPayload({this.items = const <FaqItem>[]});

  /// ≤10.
  final List<FaqItem> items;

  @override
  BlockType get type => BlockType.faq;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'items': [for (final i in items) i.toJson()],
  };
}

// ────────────────────────────────────────────────────── 11. availability

@immutable
class AvailabilityRow {
  const AvailabilityRow({
    required this.day,
    required this.from,
    required this.to,
  });

  /// 0–6.
  final int day;

  /// `HH:mm`.
  final String from;
  final String to;

  Map<String, Object?> toJson() => <String, Object?>{
    'day': day,
    'from': from,
    'to': to,
  };
}

final class AvailabilityPayload extends BlockPayload {
  const AvailabilityPayload({
    this.showSpotsLeft = true,
    this.showReplyWindow = true,
    this.hours = const <AvailabilityRow>[],
    this.tz = 'Africa/Cairo',
  });

  /// Both are **read** from the coach root at render, never copied — so a coach
  /// who fills her last place does not have a page advertising a spot.
  final bool showSpotsLeft;
  final bool showReplyWindow;

  /// ≤7 rows.
  final List<AvailabilityRow> hours;
  final String tz;

  @override
  BlockType get type => BlockType.availability;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'showSpotsLeft': showSpotsLeft,
    'showReplyWindow': showReplyWindow,
    'hours': [for (final h in hours) h.toJson()],
    'tz': tz,
  };
}

// ─────────────────────────────────────────────────────── 12. freebie

enum FreebieDelivery {
  inappMessage('inapp-message'),
  download('download');

  const FreebieDelivery(this.wire);
  final String wire;
}

final class FreebiePayload extends BlockPayload {
  const FreebiePayload({
    this.title = '',
    this.body = '',
    this.mediaId,
    this.deliver = FreebieDelivery.inappMessage,
    this.assetId,
  });

  /// ≤60 graphemes.
  final String title;

  /// ≤200 graphemes.
  final String body;

  final String? mediaId;

  /// **There is no email or phone capture field on this payload**, and that is
  /// the point of it. PDPL and spine §6: a lead magnet that harvests a phone
  /// number is the standard shape of this feature elsewhere, and this product
  /// does not have one. Delivery is in-app, to a woman already here.
  final FreebieDelivery deliver;

  final String? assetId;

  @override
  BlockType get type => BlockType.freebie;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'title': title,
    'body': body,
    if (mediaId != null) 'media': mediaId,
    'deliver': deliver.wire,
    if (assetId != null) 'assetId': assetId,
  };
}

// ─────────────────────────────────────────────────────── 13. numbers

enum StatSource { manual, derived }

@immutable
class NumberStat {
  const NumberStat({
    required this.value,
    required this.label,
    this.source = StatSource.manual,
  });

  /// ≤12 graphemes.
  final String value;

  /// ≤32 graphemes. `MarketingClaimPolicy.checkStat` runs over both, so a
  /// weight-loss figure, a timeline or a ranking is refused here.
  final String label;

  final StatSource source;

  Map<String, Object?> toJson() => <String, Object?>{
    'value': value,
    'label': label,
    'source': source.name,
  };
}

final class NumbersPayload extends BlockPayload {
  const NumbersPayload({this.stats = const <NumberStat>[]});

  /// ≤4.
  final List<NumberStat> stats;

  @override
  BlockType get type => BlockType.numbers;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'stats': [for (final s in stats) s.toJson()],
  };
}

// ─────────────────────────────────────────────────────────── 14. cta

enum CtaAction { message, offer, freebie, external }

final class CtaPayload extends BlockPayload {
  const CtaPayload({
    this.label = '',
    this.action = CtaAction.message,
    this.offerId,
    this.url,
  });

  /// ≤24 graphemes.
  final String label;
  final CtaAction action;
  final String? offerId;

  /// `https://` only. No `javascript:`, no `data:`, and the host must be on the
  /// moderation allowlist (G13 §10 Q7 — the allowlist itself is the owner's).
  final String? url;

  @override
  BlockType get type => BlockType.cta;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    'label': label,
    'action': action.name,
    if (offerId != null) 'offerId': offerId,
    if (url != null) 'url': url,
  };
}

// ────────────────────────────────────────────────────────── the envelope

/// One block on the page.
@immutable
class PortfolioBlock {
  PortfolioBlock({required this.id, required this.payload, this.visible = true})
    : type = payload.type;

  /// `nanoid(8)`-shaped, stable across reorder. Analytics and the publish diff
  /// key on it, so it is never reused within one portfolio.
  final String id;

  final BlockType type;

  /// False hides the block. **The payload is retained untouched**, which is why
  /// the eye is not a delete and why un-hiding restores her words exactly.
  final bool visible;

  final BlockPayload payload;

  PortfolioBlock copyWith({bool? visible, BlockPayload? payload}) =>
      PortfolioBlock(
        id: id,
        visible: visible ?? this.visible,
        payload: payload ?? this.payload,
      );

  /// Hidden and shown, as the eye on B02 does it.
  PortfolioBlock get hidden => copyWith(visible: false);
  PortfolioBlock get shown => copyWith(visible: true);

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'type': type.name,
    'visible': visible,
    'payload': payload.toJson(),
  };

  @override
  String toString() =>
      'PortfolioBlock($id, ${type.name}${visible ? '' : ', hidden'})';
}
