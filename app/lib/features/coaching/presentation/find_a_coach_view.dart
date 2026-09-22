/// `H01` — find a coach.
///
/// Matches `6-v2/src/screens-coaching.mjs` → `H01`, with two corrections the
/// prototype needed:
///
///  1. **The prototype's rows navigate nowhere.** Its three `coachRow(...)`
///     calls carry no `go:` target, so the one directory in the product could
///     not open a coach. Every row here opens `H02`, and the literal screen id
///     is at the call site so the navigation graph can see the edge.
///  2. **The prototype's rows state the mockup's numbers.**
///     `'4.8 ★ (126) · from 1,800 EGP · replies in ~2h'` is one dictionary
///     string with three invented figures in it. Here the rating comes from her
///     review count and is withheld below five, the price is her own figure
///     joined to a dictionary word, and the reply time renders only for the
///     coach it is literally true of. A coach we have not measured makes no
///     claim about how fast she answers.
///
/// It is a list and not a swipe deck because choosing a coach is a decision:
/// specialty, price and how fast she replies are the three things that decide
/// it, and a deck hides exactly those.
///
/// ## There is still no sort control
///
/// The dictionary now carries `sort` — the bare word *"Sort"* — and that is the
/// only string it has for this. [DirectoryOrder] has four values (match, reply
/// speed, price up, price down) and **none of them is named** anywhere in
/// either ARB, so a control labelled "Sort" would open onto four unlabelled
/// options. One word is a control's title, not a control.
///
/// So the list keeps `DirectoryOrder.match`, which is the default and the only
/// one this screen can name by not naming it. The four option strings are the
/// outstanding dictionary work; a grep for `DirectoryOrder` is the live list.
library;

import '../../../theme/app_art.dart';

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/coach_directory.dart';
import 'coaching_money.dart';
import 'coaching_view_models.dart';
import 'coaching_widgets.dart';

class FindACoachView extends StatefulWidget {
  const FindACoachView({
    super.key,
    required this.model,
    this.onBack,
    this.onOpenCoach,
    this.onRetry,
    this.note,
  });

  final FindACoachViewModel model;

  /// Replaces the line under the title when what it says is not true here.
  ///
  /// The default promise — every coach on this screen is a woman whose
  /// certificates were checked — is the product's, and it holds the day a
  /// reviewer exists. In the test build nobody has checked anything, and a
  /// screen that made the promise anyway would be the worst kind of copy: true
  /// of the product, false of the rows underneath it.
  final String? note;

  final VoidCallback? onBack;

  /// Opens one coach's page. The router passes a callback that navigates to
  /// `H02`; the default below does the same thing by id.
  final ValueChanged<String>? onOpenCoach;

  final VoidCallback? onRetry;

  @override
  State<FindACoachView> createState() => _FindACoachViewState();
}

class _FindACoachViewState extends State<FindACoachView> {
  late FindACoachViewModel _model = widget.model;

  @override
  void didUpdateWidget(FindACoachView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model != widget.model) _model = widget.model;
  }

  /// The facets on the chip row, in the prototype's order.
  ///
  /// The price band is now among them. `under2000Egp` bakes the mockup's 2,000
  /// into the sentence and is used nowhere; the chip renders the parameterised
  /// `Under {n} EGP` with [kDirectoryPriceBand], the band this product chose,
  /// so the figure on the chip and the ceiling the filter applies are the same
  /// value and cannot drift apart.
  static const List<CoachingSpecialty> _specialtyFacets =
      CoachingSpecialty.values;
  static const List<CoachingLanguage> _languageFacets = CoachingLanguage.values;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final rows = _model.rows;

    final facets = <_Facet>[
      for (final s in _specialtyFacets)
        _Facet(
          label: specialtyLabel(l10n, s),
          selected: _model.query.specialties.contains(s),
          apply: () => _model.toggleSpecialty(s),
        ),
      for (final lang in _languageFacets)
        _Facet(
          label: languageLabel(l10n, lang),
          selected: _model.query.languages.contains(lang),
          apply: () => _model.toggleLanguage(lang),
        ),
      // The band, from the one constant that also does the filtering.
      _Facet(
        label: l10n.underNEgp(kDirectoryPriceBand.amountText),
        selected: _model.query.maxPrice != null,
        apply: () => _model.togglePriceCeiling(kDirectoryPriceBand),
      ),
    ];

    // The directory is the section's front page, so its name is set on the
    // page at section size and underlined once by hand, rather than sitting
    // small in the bar.
    return AppScaffold(
      appBar: AppTopBar(
        onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: HandUnderline(
            level: HandLevel.signature,
            width: HandStroke.felt,
            drawOn: true,
            gap: 4,
            child: Text(l10n.coaching, style: EditorialType.section),
          ),
        ),
        CoachingNote(widget.note ?? l10n.everyCoachHereIsAVerifiedWoman),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final facet in facets)
              _FacetChip(
                label: facet.label,
                selected: facet.selected,
                onTap: () => setState(() => _model = facet.apply()),
              ),
          ],
        ),
        switch (_model.emptiness) {
          // Not "no coaches found". The network failed, and saying so is the
          // difference between a product with nobody in it and a phone with no
          // signal.
          DirectoryEmptiness.couldNotLoad => CoachingNotice(
            icon: Icons.cloud_off,
            text: l10n.waitingForSignal,
            action: l10n.tryAgain,
            onAction: widget.onRetry,
          ),
          DirectoryEmptiness.nothingMatched => AppEmptyState(
            icon: Icons.search,
            art: AppArt.dumbbells,
            title: l10n.coaches,
            body: l10n.beginnersPostpartumOrYourCity,
          ),
          DirectoryEmptiness.notEmpty => const SizedBox.shrink(),
        },
        for (final row in rows) _CoachRow(row: row, onOpen: _open),
        // Only the bounded fallback has a cursor; the pack is complete.
        if (_model.isColdFallback && _model.hasMore)
          AppButton(
            l10n.open,
            variant: AppButtonVariant.outlined,
            height: 46,
            fontSize: 15,
            onPressed: widget.onRetry,
          ),
      ],
    );
  }

  void _open(String coachUid) {
    final handler = widget.onOpenCoach;
    if (handler != null) {
      handler(coachUid);
      return;
    }
    goToScreen(context, 'H02');
  }
}

/// One chip: what it says, whether it is on, and what tapping it produces.
///
/// A record of the three rather than three parallel lists indexed by position,
/// which is how a chip ends up labelled with one facet and toggling another.
class _Facet {
  const _Facet({
    required this.label,
    required this.selected,
    required this.apply,
  });

  final String label;
  final bool selected;
  final FindACoachViewModel Function() apply;
}

class _FacetChip extends StatelessWidget {
  const _FacetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  // The product's own chip: a facet she has chosen is ringed in ink, the
  // rest are framed in pencil, the same as every other filter she sets.
  @override
  Widget build(BuildContext context) =>
      AppChip(label, selected: selected, onTap: onTap);
}

/// One coach.
///
/// Three facts and no invented fourth: what she does and where, her price if
/// she has published one, her rating if enough women have given her one, and
/// her reply time if it was measured.
class _CoachRow extends StatelessWidget {
  const _CoachRow({required this.row, required this.onOpen});

  final DirectoryRow row;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final what = <String>[
      for (final s in row.specialties.take(2)) specialtyLabel(l10n, s),
      if (row.city.isNotEmpty) row.city,
    ].join(' · ');

    // Her own price, joined to the dictionary's word. Null renders nothing —
    // a coach with no published price is not a coach who is free.
    final price = fromPriceLine(l10n, row.priceFrom);

    // "About 2 hours · measured, not typed" is shown only to the coach it is
    // actually true of. A median we did not measure is not rendered at all.
    final reply = statedLine(
      l10n.about2HoursMeasuredNotTyped,
      states: 120,
      hers: row.replyMinsP50,
    );

    final rating = ratingRow(row);

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      gap: 6,
      // The literal 'H02' lives in the router's own callback; this row reports
      // the coach and lets the caller decide where a coach opens.
      onTap: () => onOpen(row.coachUid),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachAvatar(row.displayName, diameter: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.displayName, style: AppText.titleM),
                  if (what.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      what,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
        if (rating != null || price != null || reply != null)
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ?rating,
              if (price != null)
                Text(
                  price,
                  style: AppText.label.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              if (reply != null)
                Text(
                  reply,
                  style: AppText.label.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
