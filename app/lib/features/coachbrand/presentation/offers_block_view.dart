/// B06 — what she offers. **This screen reads offers; it does not write them.**
///
/// G13 §10 Q1 recorded the defect — *"offers are authored in three unreconciled
/// places"* — and the owner settled it: `lib/features/coach/` (K04) is the
/// single writer of `coaches/{coachUid}/offers/{offerId}`. So what B06 edits is
/// the **block**: which offer ids appear on her page, how they are laid out,
/// and whether spots-left is shown. Every one of those is a field on
/// [OffersPayload], which has no price, no title and no snapshot to write.
///
/// [CoachOffersPort] has no `upsert`, `save`, `create`, `update` or `delete` —
/// not "has one B06 does not call", **has none** — so there is nothing on this
/// screen's surface that could author an offer even by accident. The row that
/// leads to K04 is navigation, and navigation is not a write path.
///
/// ## The price is formatted here, never stored formatted
///
/// [OfferSummary] carries minor units and a currency code. A stored
/// `"1,800 EGP"` renders Eastern digits under an Arabic locale, and
/// `NumberFormat` does the same thing on purpose — P0-A11Y-01 wants Western
/// digits in both languages, so the grouping is done by hand.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../domain/offers_port.dart';
import '../domain/portfolio_block.dart';

class OffersBlockView extends StatelessWidget {
  const OffersBlockView({
    super.key,
    required this.payload,
    required this.offers,
    this.spotsLeft,
    this.onChanged,
    this.onAuthorOffers,
    this.onDone,
    this.onClose,
  });

  /// The block. Ids and display options — the only thing this screen writes.
  final OffersPayload payload;

  /// K04's offers, resolved through the read-only port.
  final List<OfferSummary> offers;

  /// Read from the coach root at render, never copied onto the page. Null when
  /// she has not set a capacity, and the row then states no figure.
  final int? spotsLeft;

  final ValueChanged<OffersPayload>? onChanged;

  /// K04. Navigation, not a write path.
  final VoidCallback? onAuthorOffers;

  final VoidCallback? onDone;
  final VoidCallback? onClose;

  bool _isOn(String offerId) => payload.offerIds.contains(offerId);

  void _toggle(String offerId) {
    final next = [...payload.offerIds];
    if (next.remove(offerId)) {
      _emit(next);
      return;
    }
    // Six is the cap in `BlockValidator` and in the rules. Refusing here means
    // the seventh tap does nothing rather than producing a block that cannot
    // be published.
    if (next.length >= kMaxOfferIdsPerBlock) return;
    next.add(offerId);
    _emit(next);
  }

  void _emit(List<String> offerIds) => onChanged?.call(
    OffersPayload(
      offerIds: offerIds,
      display: payload.display,
      showSpotsLeft: payload.showSpotsLeft,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.whatIOffer,
        onBack: onClose,
        leadingIcon: Icons.close,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.done_54ca1,
              height: 38,
              fontSize: 15,
              onPressed: onDone,
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          Text(
            l10n.writeYourOwnOffersTwoIsCommon,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          for (final offer in offers)
            _OfferCard(
              offer: offer,
              selected: _isOn(offer.offerId),
              onTap: () => _toggle(offer.offerId),
            ),
          AppCard(
            variant: AppCardVariant.filled,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            onTap: () => openScreen(context, 'K04', onAuthorOffers),
            children: [
              Row(
                children: [
                  const Icon(Icons.add, size: 22, color: AppColors.primaryDim),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.addAnotherOffer,
                      style: AppText.titleS.copyWith(
                        color: AppColors.primaryDim,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          AppCard(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.clientsAtOnce,
                          style: AppText.titleM.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.shownOnYourPageAsSpotsLeft,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Her own capacity, from the coach root — never the mockup's
                  // twenty. Absent when she has not set one.
                  if (spotsLeft != null) ...[
                    Text(
                      '$spotsLeft',
                      style: AppText.titleL.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  AppToggle(
                    value: payload.showSpotsLeft,
                    semanticLabel: l10n.shownOnYourPageAsSpotsLeft,
                    onChanged: onChanged == null
                        ? null
                        : (value) => onChanged!.call(
                            OffersPayload(
                              offerIds: payload.offerIds,
                              display: payload.display,
                              showSpotsLeft: value,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
          AppSageNote(l10n.youKeep80OfEveryPriceYou),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.onTap,
  });

  final OfferSummary offer;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      onTap: onTap,
      gap: 10,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Her own name for the package. User content, never localised.
                  Text(
                    offer.title,
                    style: AppText.titleM.copyWith(color: AppColors.onSurface),
                  ),
                  if (offer.summary.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      offer.summary,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (offer.priceMinor != null)
              Text(
                formatOfferPrice(offer.priceMinor!, offer.currency),
                style: AppText.titleM.copyWith(color: AppColors.primary),
              ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              size: 22,
              color: selected ? AppColors.primary : AppColors.outline,
            ),
          ],
        ),
        if (offer.lines.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in offer.lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check,
                        size: 18,
                        color: AppColors.tertiary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          line,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Minor units into `1,800 EGP`, with Western digits in both languages.
///
/// By hand rather than through `NumberFormat`, which renders Eastern digits
/// under an Arabic locale. P0-A11Y-01.
String formatOfferPrice(int minor, String currency) {
  final major = (minor ~/ 100).toString();
  final out = StringBuffer();
  for (var i = 0; i < major.length; i++) {
    if (i > 0 && (major.length - i) % 3 == 0) out.write(',');
    out.write(major[i]);
  }
  return '$out $currency';
}
