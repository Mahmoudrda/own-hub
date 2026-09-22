/// Every limit in G13 §1.3, and the seven surfaces the claim policy runs over.
///
/// Lengths are **grapheme clusters**, not UTF-16 units. "مرحبا" and a family
/// emoji both count the way a woman counts them, which is the only count a
/// character limit can honestly be about. The server re-checks with the same
/// rule.
///
/// ## The claim surfaces
///
/// G13 §5 specifies cover, ad, `numbers` and testimonial text. **The owner
/// extended it**: `about`, `method` and `faq` prose are checked too. Those
/// three are the longest free text on the page, so a rule that skipped them
/// would only be a rule about headlines — a coach who cannot promise "10 kg in
/// 30 days" in her cover can put the same sentence in paragraph two of "Who I
/// am" and reach the same woman.
///
/// Six surfaces are here (cover, about, method, faq, numbers, testimonials);
/// the seventh is the ad, checked by `AdCreative.claimViolations` because an ad
/// is not a block.
library;

import 'package:flutter/widgets.dart';

import 'marketing_claim_policy.dart';
import 'overlay_floor.dart';
import 'portfolio_block.dart';

/// What is wrong with a block.
enum BlockProblemKind {
  /// A string is longer than its limit.
  tooLong,

  /// More items than the type allows.
  tooMany,

  /// Fewer than the type needs — `method` with no steps.
  tooFew,

  /// A layout that needs a photograph has none.
  missingMedia,

  /// The darken slider is below the computed floor.
  overlayBelowFloor,

  /// Even 0.9 does not work. `text-over-photo` is refused; offer `photo-above`.
  layoutRefused,

  /// `MarketingClaimPolicy` rejected a span.
  claim,

  /// Not `https://`, or a scheme that can execute.
  invalidUrl,

  /// Over 8 KB encoded.
  payloadTooLarge,

  /// Over 12 media ids.
  tooManyMediaIds,
}

/// One problem, with enough detail for an editor to point at it.
@immutable
class BlockProblem {
  const BlockProblem({
    required this.blockId,
    required this.type,
    required this.kind,
    required this.field,
    this.index,
    this.limit,
    this.actual,
    this.claim,
  });

  final String blockId;
  final BlockType type;
  final BlockProblemKind kind;

  /// `headline`, `paragraphs`, `steps[1].body` — what to focus.
  final String field;

  /// Which item in a list, where the field is one.
  final int? index;

  final num? limit;
  final num? actual;

  /// Present when [kind] is [BlockProblemKind.claim] — the span to underline.
  final ClaimViolation? claim;

  @override
  String toString() =>
      'BlockProblem($blockId/${type.name}, ${kind.name}, $field'
      '${limit == null ? '' : ' $actual > $limit'})';
}

/// The verdict for one block, or for a whole page.
@immutable
class BlockValidation {
  const BlockValidation(this.problems);

  const BlockValidation.valid() : problems = const <BlockProblem>[];

  final List<BlockProblem> problems;

  bool get isValid => problems.isEmpty;

  List<BlockProblem> forBlock(String blockId) =>
      List.unmodifiable(problems.where((p) => p.blockId == blockId));

  bool get hasClaimProblem =>
      problems.any((p) => p.kind == BlockProblemKind.claim);

  @override
  String toString() =>
      isValid ? 'BlockValidation.valid()' : 'BlockValidation($problems)';
}

/// Grapheme clusters, the way a reader counts characters.
int graphemeLength(String value) => value.characters.length;

/// The limits, in one place.
@immutable
class BlockValidator {
  const BlockValidator({this.claims = const MarketingClaimPolicy()});

  final MarketingClaimPolicy claims;

  /// Validates one block.
  ///
  /// [overlayFloor] is the decision from [OverlayFloor.minAlpha] for a
  /// `text-over-photo` cover. Passing null means "not computed" — the length
  /// and layout rules still run, but the overlay is not judged, which is the
  /// correct behaviour offline when the photo has not been decoded yet.
  BlockValidation validate(
    PortfolioBlock block, {
    OverlayDecision? overlayFloor,
  }) {
    final problems = <BlockProblem>[];
    final payload = block.payload;

    BlockProblem problem(
      BlockProblemKind kind,
      String field, {
      int? index,
      num? limit,
      num? actual,
      ClaimViolation? claim,
    }) => BlockProblem(
      blockId: block.id,
      type: block.type,
      kind: kind,
      field: field,
      index: index,
      limit: limit,
      actual: actual,
      claim: claim,
    );

    void length(String value, String field, int limit, {int? index}) {
      final n = graphemeLength(value);
      if (n > limit) {
        problems.add(
          problem(
            BlockProblemKind.tooLong,
            field,
            index: index,
            limit: limit,
            actual: n,
          ),
        );
      }
    }

    void prose(String value, String field, {int? index}) {
      for (final v in claims.check(value).violations) {
        problems.add(
          problem(BlockProblemKind.claim, field, index: index, claim: v),
        );
      }
    }

    void stat(String value, String field, {int? index}) {
      for (final v in claims.checkStat(value).violations) {
        problems.add(
          problem(BlockProblemKind.claim, field, index: index, claim: v),
        );
      }
    }

    void count(int n, String field, int limit) {
      if (n > limit) {
        problems.add(
          problem(BlockProblemKind.tooMany, field, limit: limit, actual: n),
        );
      }
    }

    switch (payload) {
      // ───────────────────────────────────────────────────────── cover
      case CoverPayload():
        length(payload.headline, 'headline', 64);
        length(payload.subline, 'subline', 80);
        prose(payload.headline, 'headline');
        prose(payload.subline, 'subline');

        if (payload.layout != CoverLayout.noPhoto &&
            (payload.mediaId == null || payload.mediaId!.isEmpty)) {
          problems.add(problem(BlockProblemKind.missingMedia, 'media'));
        }

        if (payload.layout == CoverLayout.textOverPhoto &&
            overlayFloor != null) {
          if (overlayFloor.refused) {
            problems.add(problem(BlockProblemKind.layoutRefused, 'layout'));
          } else if (payload.overlay < overlayFloor.minAlpha) {
            problems.add(
              problem(
                BlockProblemKind.overlayBelowFloor,
                'overlay',
                limit: overlayFloor.minAlpha,
                actual: payload.overlay,
              ),
            );
          }
        }

        if (payload.overlay > kMaxOverlayAlpha) {
          problems.add(
            problem(
              BlockProblemKind.tooLong,
              'overlay',
              limit: kMaxOverlayAlpha,
              actual: payload.overlay,
            ),
          );
        }

      // ───────────────────────────────────────────────────────── about
      case AboutPayload():
        count(payload.paragraphs.length, 'paragraphs', 4);
        for (var i = 0; i < payload.paragraphs.length; i++) {
          length(payload.paragraphs[i], 'paragraphs', 400, index: i);
          // The owner's extension: prose is checked here too.
          prose(payload.paragraphs[i], 'paragraphs', index: i);
        }

      // ──────────────────────────────────────────────────────── method
      case MethodPayload():
        if (payload.steps.isEmpty) {
          problems.add(
            problem(BlockProblemKind.tooFew, 'steps', limit: 1, actual: 0),
          );
        }
        count(payload.steps.length, 'steps', 8);
        for (var i = 0; i < payload.steps.length; i++) {
          final step = payload.steps[i];
          length(step.title, 'steps.title', 40, index: i);
          length(step.body, 'steps.body', 200, index: i);
          // The owner's extension.
          prose(step.title, 'steps.title', index: i);
          prose(step.body, 'steps.body', index: i);
        }

      // ──────────────────────────────────────────────────────── offers
      case OffersPayload():
        count(payload.offerIds.length, 'offerIds', 6);

      // ─────────────────────────────────────────────────────── results
      case ResultsPayload():
        count(payload.resultIds.length, 'resultIds', 12);

      // ────────────────────────────────────────────────── testimonials
      case TestimonialsPayload():
        count(payload.items.length, 'items', 8);
        for (var i = 0; i < payload.items.length; i++) {
          final item = payload.items[i];
          length(item.quote, 'items.quote', 240, index: i);
          length(item.attribution, 'items.attribution', 40, index: i);
          prose(item.quote, 'items.quote', index: i);
        }

      // ───────────────────────────────────────────────────────── video
      case VideoPayload():
        length(payload.caption, 'caption', 120);
        if (payload.mediaId.isEmpty) {
          problems.add(problem(BlockProblemKind.missingMedia, 'media'));
        }

      // ─────────────────────────────────────────────────────── gallery
      case GalleryPayload():
        count(payload.mediaIds.length, 'mediaIds', 12);

      // ────────────────────────────────────────────────── certificates
      case CertificatesPayload():
        // Nothing to length-check: there is no free text on this payload at
        // all, which is the rule. An unverified id is dropped at render.
        count(payload.certIds.length, 'certIds', 12);

      // ─────────────────────────────────────────────────────────── faq
      case FaqPayload():
        count(payload.items.length, 'items', 10);
        for (var i = 0; i < payload.items.length; i++) {
          final item = payload.items[i];
          length(item.question, 'items.q', 100, index: i);
          length(item.answer, 'items.a', 400, index: i);
          // The owner's extension.
          prose(item.question, 'items.q', index: i);
          prose(item.answer, 'items.a', index: i);
        }

      // ────────────────────────────────────────────────── availability
      case AvailabilityPayload():
        count(payload.hours.length, 'hours', 7);

      // ─────────────────────────────────────────────────────── freebie
      case FreebiePayload():
        length(payload.title, 'title', 60);
        length(payload.body, 'body', 200);
        prose(payload.title, 'title');
        prose(payload.body, 'body');

      // ─────────────────────────────────────────────────────── numbers
      case NumbersPayload():
        count(payload.stats.length, 'stats', 4);
        for (var i = 0; i < payload.stats.length; i++) {
          final s = payload.stats[i];
          length(s.value, 'stats.value', 12, index: i);
          length(s.label, 'stats.label', 32, index: i);
          // checkStat, so a ranking is refused as well as a claim.
          stat(s.value, 'stats.value', index: i);
          stat(s.label, 'stats.label', index: i);
        }

      // ─────────────────────────────────────────────────────────── cta
      case CtaPayload():
        length(payload.label, 'label', 24);
        prose(payload.label, 'label');
        final url = payload.url;
        if (payload.action == CtaAction.external) {
          if (url == null || !_isSafeHttpsUrl(url)) {
            problems.add(problem(BlockProblemKind.invalidUrl, 'url'));
          }
        } else if (url != null && !_isSafeHttpsUrl(url)) {
          problems.add(problem(BlockProblemKind.invalidUrl, 'url'));
        }
    }

    // Global caps, whatever the type.
    final ids = _mediaIdsOf(payload);
    if (ids.length > kMaxMediaIdsPerBlock) {
      problems.add(
        problem(
          BlockProblemKind.tooManyMediaIds,
          'mediaIds',
          limit: kMaxMediaIdsPerBlock,
          actual: ids.length,
        ),
      );
    }

    final bytes = payload.byteLength;
    if (bytes > kMaxPayloadBytes) {
      problems.add(
        problem(
          BlockProblemKind.payloadTooLarge,
          'payload',
          limit: kMaxPayloadBytes,
          actual: bytes,
        ),
      );
    }

    return BlockValidation(List.unmodifiable(problems));
  }

  /// The whole page. [overlayFloors] is keyed by block id.
  BlockValidation validateAll(
    Iterable<PortfolioBlock> blocks, {
    Map<String, OverlayDecision> overlayFloors = const {},
  }) {
    final problems = <BlockProblem>[];
    for (final block in blocks) {
      problems.addAll(
        validate(block, overlayFloor: overlayFloors[block.id]).problems,
      );
    }
    return BlockValidation(List.unmodifiable(problems));
  }

  /// Every media id a payload references, so the cap is one rule not fourteen.
  static List<String> _mediaIdsOf(BlockPayload payload) => switch (payload) {
    CoverPayload(:final mediaId) => [?mediaId],
    AboutPayload(:final portraitMediaId) => [?portraitMediaId],
    VideoPayload(:final mediaId, :final posterMediaId) => [
      mediaId,
      ?posterMediaId,
    ],
    GalleryPayload(:final mediaIds) => mediaIds,
    FreebiePayload(:final mediaId) => [?mediaId],
    _ => const <String>[],
  };

  /// `https://` with a host, and nothing that can execute.
  ///
  /// The host allowlist itself is the owner's (G13 §10 Q7) and is not decided
  /// here; this is the scheme half, which is not a judgement call.
  static bool _isSafeHttpsUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return false;
    if (uri.scheme.toLowerCase() != 'https') return false;
    return uri.host.isNotEmpty;
  }
}
