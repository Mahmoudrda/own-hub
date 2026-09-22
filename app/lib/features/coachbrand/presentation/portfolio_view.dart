/// The one renderer. B10 previews with it; G11's H02 renders with it.
///
/// G13 §7.1: *"`PortfolioView(portfolio, mode)` — a widget, not a spec. It
/// renders the block list and nothing else: no app bar, no follow button, no
/// footer."* G11 owns the chrome around it — back, share, favourite, the
/// avatar row, follow, rating, the footer CTAs and the enquiry event.
///
/// **There is one of these.** `P0-PORT-05` asks for a code search that finds no
/// second coach-profile layout, and `portfolio_view_test.dart` is that search
/// as an assertion. The value of one renderer is not tidiness: it is that
/// "preview shows exactly what a client sees" is true by construction rather
/// than by two teams keeping two widget trees in step.
///
/// ## Consent is resolved by the caller, at read time
///
/// This widget never asks whether a result is consented. It asks
/// [PublishedPortfolio] what to draw, and that object resolved the ids against
/// live documents at the moment of the read. So the rule has one home and the
/// renderer cannot drift from it — and offline, where consent cannot be
/// checked, the results block says so instead of guessing.
///
/// ## Block content is never localised
///
/// Her headline, her paragraphs, her step names are user content and pass
/// through untouched. The *chrome* — a label, an empty state, the offline line
/// — goes through `AppL10n`. A string that has not been minted is omitted and
/// reported, never invented in English.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_media.dart';
import '../../../ui/hand/hand.dart';
import '../domain/contrast.dart';
import '../domain/portfolio_block.dart';
import '../domain/portfolio_theme.dart';
import '../domain/published_portfolio_reader.dart';
import 'photo_scrim.dart';

/// Whether this is a client's read or the coach previewing it.
///
/// The tree is identical either way. The mode exists so a preview can be told
/// apart in a test and in analytics, **not** so it can render differently: the
/// moment it changes what is drawn, "exactly what a client sees" stops being
/// true.
enum PortfolioViewMode { render, preview }

/// The block list, rendered from data.
class PortfolioView extends StatelessWidget {
  const PortfolioView({
    super.key,
    required this.portfolio,
    this.mode = PortfolioViewMode.render,
  });

  final PublishedPortfolio portfolio;
  final PortfolioViewMode mode;

  @override
  Widget build(BuildContext context) {
    final theme = portfolio.page.theme;
    final scheme = theme.scheme(brightness: Theme.brightnessOf(context));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final block in portfolio.blocks)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: PortfolioBlockView(
              block: block,
              portfolio: portfolio,
              theme: theme,
              scheme: scheme,
            ),
          ),
      ],
    );
  }
}

/// One block. A registry entry plus this switch is the whole of adding a type.
class PortfolioBlockView extends StatelessWidget {
  const PortfolioBlockView({
    super.key,
    required this.block,
    required this.portfolio,
    required this.theme,
    required this.scheme,
  });

  final PortfolioBlock block;
  final PublishedPortfolio portfolio;
  final PortfolioTheme theme;
  final ColorScheme scheme;

  TextStyle _style(PortfolioTextStyle style, Color colour) =>
      theme.styleFor(style).copyWith(color: colour);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final radii = theme.radii;
    final payload = block.payload;

    return switch (payload) {
      CoverPayload() => _cover(payload, radii),
      AboutPayload() => _paragraphs(payload.paragraphs),
      MethodPayload() => _method(context, payload, radii),
      OffersPayload() => _offers(payload, radii),
      ResultsPayload() => _results(payload, l10n, radii),
      TestimonialsPayload() => _testimonials(payload, radii),
      VideoPayload() => _video(payload, radii),
      GalleryPayload() => _gallery(payload, radii),
      CertificatesPayload() => _certificates(payload, radii),
      FaqPayload() => _faq(payload),
      AvailabilityPayload() => _availability(payload, l10n, radii),
      FreebiePayload() => _freebie(payload, radii),
      NumbersPayload() => _numbers(payload),
      CtaPayload() => _cta(payload, radii),
    };
  }

  // ───────────────────────────────────────────────────────────── blocks

  Widget _cover(CoverPayload payload, PortfolioRadii radii) {
    // Her headline is the page's subject, so it carries the page's one hand
    // mark: underlined once, in her own colour, as the page arrives.
    Widget signed(Text headline, Color ink) => HandUnderline(
      color: ink,
      level: HandLevel.signature,
      width: HandStroke.felt,
      drawOn: true,
      gap: 4,
      child: headline,
    );

    final headline = signed(
      Text(
        payload.headline,
        style: _style(PortfolioTextStyle.display, scheme.onSurface),
      ),
      scheme.primary,
    );
    final subline = payload.subline.isEmpty
        ? null
        : Text(
            payload.subline,
            style: _style(PortfolioTextStyle.bodyM, scheme.onSurfaceVariant),
          );

    if (payload.layout == CoverLayout.noPhoto) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          headline,
          if (subline != null) ...[const SizedBox(height: 6), subline],
        ],
      );
    }

    final photoHeight = payload.layout == CoverLayout.textOverPhoto
        ? 230.0
        : 180.0;
    final photo = AppMedia(
      height: photoHeight,
      kind: AppMediaKind.photo,
      showPlayButton: false,
      borderRadius: radii.md,
    );

    if (payload.layout == CoverLayout.photoAbove) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          photo,
          const SizedBox(height: 12),
          headline,
          if (subline != null) ...[const SizedBox(height: 6), subline],
        ],
      );
    }

    // text-over-photo. The scrim is the coach's `overlay`, which
    // `BlockValidator` has already refused to let fall below the computed
    // floor — so the widget draws it rather than deciding it.
    return Stack(
      children: [
        photo,
        Positioned.fill(
          child: PhotoScrim(
            alpha: payload.overlay,
            height: photoHeight,
            borderRadius: radii.md,
          ),
        ),
        PositionedDirectional(
          start: 16,
          end: 16,
          bottom: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              signed(
                Text(
                  payload.headline,
                  style: _style(PortfolioTextStyle.display, Colors.white),
                ),
                Colors.white,
              ),
              if (payload.subline.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  payload.subline,
                  style: _style(
                    PortfolioTextStyle.bodyM,
                    Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _paragraphs(List<String> paragraphs) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final paragraph in paragraphs)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            paragraph,
            style: _style(PortfolioTextStyle.body, scheme.onSurface),
          ),
        ),
    ],
  );

  Widget _method(
    BuildContext context,
    MethodPayload payload,
    PortfolioRadii radii,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < payload.steps.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (payload.numbered) ...[
                // The step's number, ringed by hand in her colour rather
                // than set in a filled disc.
                SizedBox.square(
                  dimension: 30,
                  child: CustomPaint(
                    painter: LoopPainter(
                      seed: handSeed(['method-step', i]),
                      color: scheme.primary,
                      width: HandStroke.fine,
                      level: HandLevel.crafted,
                      inflate: EdgeInsets.zero,
                      textDirection: Directionality.of(context),
                    ),
                    child: Center(
                      child: Text(
                        // Western digits inside Arabic text, per P0-A11Y-01.
                        '${i + 1}',
                        style: _style(
                          PortfolioTextStyle.titleS,
                          scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payload.steps[i].title,
                      style: _style(
                        PortfolioTextStyle.titleS,
                        scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      payload.steps[i].body,
                      style: _style(
                        PortfolioTextStyle.bodyM,
                        scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _offers(OffersPayload payload, PortfolioRadii radii) {
    final offers = portfolio.offersFor(payload);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final offer in offers)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _panel(
              radii,
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          offer.title,
                          style: _style(
                            PortfolioTextStyle.titleM,
                            scheme.onSurface,
                          ),
                        ),
                        if (offer.summary.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            offer.summary,
                            style: _style(
                              PortfolioTextStyle.bodyM,
                              scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // The price is K04's data, formatted here rather than
                  // stored formatted — a baked "1,800 EGP" renders Eastern
                  // digits under an Arabic locale.
                  if (offer.priceMinor != null)
                    Text(
                      _price(offer.priceMinor!, offer.currency),
                      style: _style(PortfolioTextStyle.titleM, scheme.primary),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _results(ResultsPayload payload, AppL10n l10n, PortfolioRadii radii) {
    final render = portfolio.resultsFor(payload);

    if (render is ResultsWaitingForSignal) {
      // G13 §4: it cannot check consent, so it does not guess. The dictionary
      // has no "results appear when you're online" line; `waitingForSignal`
      // is the nearest minted string that is true, and the parameterised one
      // is reported as missing rather than invented here.
      return Text(
        l10n.waitingForSignal,
        style: _style(PortfolioTextStyle.bodyM, scheme.onSurfaceVariant),
      );
    }

    final ids = (render as ResultsVisible).resultIds;
    // An empty results block draws nothing at all — never a placeholder where
    // a woman who withdrew used to be.
    if (ids.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final _ in ids)
          AppMedia(
            width: payload.display == ResultsDisplay.strip ? 104 : null,
            height: payload.display == ResultsDisplay.strip ? 104 : 180,
            kind: AppMediaKind.photo,
            showPlayButton: false,
            borderRadius: radii.sm,
          ),
      ],
    );
  }

  Widget _testimonials(TestimonialsPayload payload, PortfolioRadii radii) {
    final items = portfolio.testimonialsFor(payload);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: _panel(
              radii,
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.quote,
                    style: _style(PortfolioTextStyle.body, scheme.onSurface),
                  ),
                  if (item.attribution.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.attribution,
                      style: _style(
                        PortfolioTextStyle.label,
                        scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _video(VideoPayload payload, PortfolioRadii radii) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppMedia(height: 200, borderRadius: radii.md),
      if (payload.caption.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          payload.caption,
          style: _style(PortfolioTextStyle.bodyM, scheme.onSurfaceVariant),
        ),
      ],
    ],
  );

  Widget _gallery(GalleryPayload payload, PortfolioRadii radii) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final _ in payload.mediaIds)
        AppMedia(
          width: 108,
          height: payload.aspect == GalleryAspect.square ? 108 : 135,
          kind: AppMediaKind.photo,
          showPlayButton: false,
          borderRadius: radii.xs,
        ),
    ],
  );

  Widget _certificates(CertificatesPayload payload, PortfolioRadii radii) {
    // Ids only, and only the currently-verified ones. The name comes from
    // K04's record at render, so a revocation takes effect without the coach
    // republishing — and there is no free-text field for her to have typed.
    final verified = portfolio.certificatesFor(payload);
    if (verified.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final _ in verified)
          Icon(Icons.verified_user, size: 22, color: scheme.tertiary),
      ],
    );
  }

  Widget _faq(FaqPayload payload) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final item in payload.items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.question,
                style: _style(PortfolioTextStyle.titleS, scheme.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                item.answer,
                style: _style(
                  PortfolioTextStyle.bodyM,
                  scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Widget _availability(
    AvailabilityPayload payload,
    AppL10n l10n,
    PortfolioRadii radii,
  ) => _panel(
    radii,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in payload.hours)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              // Western digits, both languages, and the word between them
              // is her language's word.
              l10n.fromToTo(row.from, row.to),
              style: _style(PortfolioTextStyle.bodyM, scheme.onSurfaceVariant),
            ),
          ),
      ],
    ),
  );

  Widget _freebie(FreebiePayload payload, PortfolioRadii radii) => _panel(
    radii,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          payload.title,
          style: _style(PortfolioTextStyle.titleM, scheme.onSurface),
        ),
        if (payload.body.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            payload.body,
            style: _style(PortfolioTextStyle.bodyM, scheme.onSurfaceVariant),
          ),
        ],
      ],
    ),
  );

  // A Wrap, not a Row: at the largest text size three figures do not fit one
  // line, and a figure pushed off the edge is worse than one on a second line.
  Widget _numbers(NumbersPayload payload) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    spacing: 16,
    runSpacing: 10,
    children: [
      for (final stat in payload.stats)
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              stat.value,
              style: _style(PortfolioTextStyle.titleL, scheme.onSurface),
            ),
            Text(
              stat.label,
              style: _style(PortfolioTextStyle.bodyM, scheme.onSurfaceVariant),
            ),
          ],
        ),
    ],
  );

  // Her button, printed as a block in her colour: the page is cut, not
  // moulded, so it takes her corners rather than a pill.
  Widget _cta(CtaPayload payload, PortfolioRadii radii) => HandSurface(
    seed: handSeed(['portfolio-cta', payload.label]),
    fill: scheme.primary,
    radius: _tight(radii),
    looseCorner: _loose(radii),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Center(
        child: Text(
          payload.label,
          style: _style(PortfolioTextStyle.titleM, scheme.onPrimary),
        ),
      ),
    ),
  );

  // ───────────────────────────────────────────────────────────── shared

  /// A surface panel. Its boundary uses `outline`, never `outlineVariant`:
  /// `contrast.dart` validates the former at 3.0:1 and the latter cannot reach
  /// it for any seed, so a meaningful edge has to be drawn with `outline`.
  Widget _panel(PortfolioRadii radii, Widget child) => HandSurface(
    seed: handSeed(['portfolio-panel', block.id]),
    fill: scheme.surfaceContainer,
    frame: scheme.outline,
    radius: _tight(radii),
    looseCorner: _loose(radii),
    padding: const EdgeInsets.all(14),
    child: child,
  );

  // Her corner choice still reads: the house corners (6 tight, 16 loose) are
  // scaled by it, so `sharp` is crisper and `round` softer, as B05 promised.
  static double _tight(PortfolioRadii radii) => radii.xs * 0.75;
  static double _loose(PortfolioRadii radii) => radii.md;

  static String _price(int minor, String currency) {
    final major = minor ~/ 100;
    final digits = major.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '$out $currency';
  }
}
