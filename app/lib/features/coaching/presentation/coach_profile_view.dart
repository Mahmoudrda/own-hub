/// `H02` — a coach's profile.
///
/// Matches `6-v2/src/screens-coaching.mjs` → `H02`.
///
/// ## It renders the page she built, not a template
///
/// The body is `page.blocks` in her order. There is no hand-built layout here
/// to fall out of sync with the builder, and two coaches do not look alike
/// (`P0-COACH-02`). A block she hid is **absent from the list** — it is not
/// present-and-skipped, so there is no gap and nothing downloaded. A block type
/// this build has no renderer for draws nothing rather than an empty card with
/// her heading on it.
///
/// ## Credentials above claims
///
/// The certificates line sits above her sales copy, because a woman deciding
/// whether to pay a stranger reads the check first. It renders only when a
/// human has actually checked them; an unchecked coach gets no badge rather
/// than a grey one.
///
/// ## Two claims this screen refuses to invent
///
///  * **Her reply time.** Measured, never typed — a 30-day rolling median
///    written by a Cloud Function. Null renders no claim at all.
///  * **Her rating.** Shown at five reviews or more, as an icon and a figure
///    built from real values. The dictionary's `'4.8 ★ (126)'` is not used
///    anywhere: it is the mockup's number, and it would be told to every coach.
///
/// ## Browsing is open; the two actions are gated
///
/// An unverified woman reads all of this. "Message before you decide" needs a
/// verified account, because it starts a relationship. "See her packages" does
/// not, because reading a price is not buying.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/checkout_gate.dart';
import '../domain/coaching_repository.dart';
import 'coaching_money.dart';
import 'coaching_view_models.dart';
import 'coaching_widgets.dart';

class CoachProfileView extends StatelessWidget {
  const CoachProfileView({
    super.key,
    required this.model,
    this.onBack,
    this.onSeePackages,
    this.onMessageFirst,
  });

  final CoachProfileViewModel model;
  final VoidCallback? onBack;
  final VoidCallback? onSeePackages;
  final VoidCallback? onMessageFirst;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final page = model.page;

    if (page == null) {
      // She has published nothing. Her name over an empty page would suggest
      // she had, and a spinner would suggest it was coming.
      return AppScaffold(
        appBar: AppTopBar(
          title: l10n.coaches,
          onBack: () => goToScreen(context, 'H01', onBack),
        ),
        // Her page is not written yet: say so plainly, and send her on —
        // a note in the margin with an arrow down to the directory.
        children: [
          const SizedBox(height: 8),
          Text(l10n.nothingHasBeenWrittenYet, style: EditorialType.section),
          const HandRule(seed: 83, height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SizedBox(width: 18),
              Flexible(child: HandNote(l10n.lookAroundFirst, size: 19)),
              const SizedBox(width: 4),
              const HandArrow(
                width: 40,
                height: 46,
                from: Offset(0.1, 0.1),
                to: Offset(0.55, 0.98),
                bend: 0.3,
                seed: 29,
                drawOn: true,
              ),
            ],
          ),
          AppButton(
            l10n.lookAround,
            onPressed: () => goToScreen(context, 'H01', onBack),
          ),
        ],
      );
    }

    final row = page.row;
    final rating = ratingRow(row);
    final reply = statedLine(
      l10n.about2HoursMeasuredNotTyped,
      states: 120,
      hers: row.replyMinsP50,
    );
    final spots = row.spotsLeft;

    final footer = <Widget>[
      if (model.maySeePackages)
        AppButton(
          l10n.seeHerPackages,
          height: 54,
          onPressed: () => goToScreen(context, 'H03', onSeePackages),
        ),
      if (model.mayEnquire)
        AppButton(
          l10n.messageBeforeYouDecide,
          variant: AppButtonVariant.outlined,
          height: 46,
          fontSize: 15,
          onPressed: () => goToScreen(context, 'H04', onMessageFirst),
        )
      else if (model.enquiryDecision is EnquiryRefusedBy)
        _EnquiryRefusalLine(
          reason: (model.enquiryDecision as EnquiryRefusedBy).reason,
        ),
    ];

    return AppScaffold(
      appBar: AppTopBar(
        title: row.displayName,
        onBack: () => goToScreen(context, 'H01', onBack),
      ),
      footer: footer,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachAvatar(row.displayName, diameter: 50),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Her name in marker: the one mark on a page that is
                  // otherwise hers to lay out.
                  MarkerHighlight(
                    child: Text(row.displayName, style: AppText.titleM),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ?rating,
                      if (reply != null)
                        Text(
                          reply,
                          style: AppText.label.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      // A real capacity number or nothing. "12 spots left" as a
                      // fixed string is urgency theatre; this is her own count
                      // and it disappears when we do not have it. The word is
                      // now "Spots left", which is what the number means — the
                      // bare "Spots" could have been read as her total.
                      if (spots != null)
                        Text(
                          '$spots ${l10n.spotsLeft}',
                          style: AppText.label.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),

        // Credentials before claims.
        if (page.certificateLine != null)
          AppCard(
            variant: AppCardVariant.sage,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user,
                    size: 20,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      page.certificateLine!,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),

        // Her page, her order.
        for (final block in page.blocks)
          ..._renderBlock(context, l10n, block, model.offers),
      ],
    );
  }

  /// One block. Returns an empty list for anything this build cannot draw.
  List<Widget> _renderBlock(
    BuildContext context,
    AppL10n l10n,
    PortfolioBlock block,
    List<CoachingOffer> offers,
  ) => switch (block) {
    CoverBlock(:final headline, :final subline) => [
      Text(headline, style: AppText.headline),
      if (subline != null) CoachingNote(subline),
    ],
    ProseBlock(:final heading, :final body) => [
      CoachingSectionHead(heading),
      Text(body, style: AppText.body.copyWith(color: AppColors.onSurface)),
    ],
    MethodBlock(:final steps) => [
      CoachingSectionHead(l10n.howIWork),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            Expanded(
              child: _MethodStep(index: i + 1, title: steps[i]),
            ),
          ],
        ],
      ),
    ],
    OffersBlock(:final offerIds) => [
      CoachingSectionHead(l10n.whatIOffer),
      for (final id in offerIds)
        ...offers.where((o) => o.id == id).map((o) => _OfferRow(offer: o)),
    ],
    ResultsBlock(:final consentNote) => [
      CoachingSectionHead(l10n.clientResults),
      // The consent sentence is hers, and it names the woman who agreed. When
      // there is none, nothing is said on her behalf.
      if (consentNote != null) CoachingNote(consentNote),
    ],
    // A block type from a newer builder. Nothing is drawn, and nothing breaks.
    UnrenderableBlock() => const <Widget>[],
  };
}

class _MethodStep extends StatelessWidget {
  const _MethodStep({required this.index, required this.title});

  final int index;
  final String title;

  // A sheet of paper per step, framed in pencil, with its number circled
  // in ink the way she would number a method in her own notes.
  @override
  Widget build(BuildContext context) => HandSurface(
    seed: handSeed(['method-step', index, title]),
    fill: AppColors.surfaceLowest,
    frame: AppColors.outline.withValues(alpha: 0.55),
    frameWidth: 1.05,
    radius: 5,
    looseCorner: 13,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HandCircled(
          seed: index,
          level: HandLevel.crafted,
          width: 1.2,
          color: AppColors.primaryDim,
          inflate: EdgeInsets.zero,
          child: SizedBox.square(
            dimension: 24,
            child: Center(
              // A step number, not a figure about her: "1" really is the
              // first step.
              child: Text(
                '$index',
                style: AppText.label.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(title, style: AppText.label.copyWith(color: AppColors.onSurface)),
      ],
    ),
  );
}

/// A package as it appears on her page.
///
/// The price comes from the same offer document `H03` reads, so the figure
/// here and the figure at checkout cannot disagree — G12's own recorded worry
/// about a price edited in one place and stale in the other, on the screen that
/// takes money.
class _OfferRow extends StatelessWidget {
  const _OfferRow({required this.offer});

  final CoachingOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final price = priceLine(l10n, price: offer.price, period: offer.period);

    return AppCard(
      onTap: () => goToScreen(context, 'H03'),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(offer.name, style: AppText.titleM),
                  if (offer.lines.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    CoachingNote(offer.lines.first),
                  ],
                ],
              ),
            ),
            // Null renders nothing. A package with no stated price is not free.
            if (price != null) ...[
              const SizedBox(width: 12),
              Text(price, style: AppText.titleM),
            ],
          ],
        ),
      ],
    );
  }
}

/// Why the message button is not offered.
class _EnquiryRefusalLine extends StatelessWidget {
  const _EnquiryRefusalLine({required this.reason});

  final EnquiryRefusal reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final text = switch (reason) {
      // Browsing is open; starting a relationship is not.
      EnquiryRefusal.notVerified => l10n.browseMessageWhenYouAreVerified,
      // She already has this thread open, or is already working with her.
      EnquiryRefusal.alreadyInTouch => l10n.awaitingReply,
      // Her books are closed. Said plainly — it is about the coach's capacity
      // and not about this woman, and it is the same sentence `H03` uses when
      // the checkout gate refuses for the same reason.
      EnquiryRefusal.coachNotAccepting => l10n.sheIsNotTakingClientsRightNow,
      EnquiryRefusal.marketplaceOff => null,
      EnquiryRefusal.empty => null,
    };
    if (text == null) return const SizedBox.shrink();
    return CoachingNotice(icon: Icons.info_outline, text: text);
  }
}
