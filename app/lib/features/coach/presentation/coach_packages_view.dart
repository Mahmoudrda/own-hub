/// `K04` — Your packages.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K04`.
///
/// # This screen is the single writer of offers
///
/// The owner's decision. `B06` and `K18` read them; nothing else writes one. The
/// mechanism is that **this is the only screen handed a [PackagesEditor]** —
/// every other coach screen is given an `OfferReader`, which has no write
/// method. G12 §9 Q5 records what the alternative costs: a price edited in one
/// place and stale in the other, on the screen that takes money.
///
/// The offers section is behind `Feature.payments`, which ships off. A price is
/// payment-related, and with the flag dark this screen is exactly the design's
/// `K04` — her capacity, the eighty per cent, and the note that she will write
/// her offers when she designs her page.
///
/// # The capacity is asked here so the number on her page is true
///
/// `K18` renders "12 of 20 taken" and `H02` renders "12 spots left". Both are
/// read from [CoachCapacity], which is answered here and nowhere else. A default
/// would make that number marketing.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_sage_note.dart';
import '../domain/coach_capacity.dart';
import '../domain/offer.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachPackagesView extends StatefulWidget {
  const CoachPackagesView({
    super.key,
    required this.model,
    this.editor,
    this.flags = FeatureFlags.shipped,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
    this.onEditOffer,
    this.onOffersChanged,
  });

  final CoachSetupViewModel model;

  /// The **only** write path for offers in this application.
  ///
  /// Null when `Feature.payments` is dark, which is why the section below is
  /// absent rather than disabled: there is nothing to disable.
  final PackagesEditor? editor;

  final FeatureFlags flags;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  /// Opens one offer for editing **on another screen**.
  ///
  /// There is no such screen in the designed set, so when this is null the
  /// package opens inline below the row instead. A host that has one keeps the
  /// old behaviour by passing this.
  final ValueChanged<String?>? onEditOffer;

  /// Called after [PackagesEditor] wrote one, so the host can redraw the rest
  /// of the app. The write has already happened through the editor — this is a
  /// notification, not a write path.
  final VoidCallback? onOffersChanged;

  @override
  State<CoachPackagesView> createState() => _CoachPackagesViewState();
}

class _CoachPackagesViewState extends State<CoachPackagesView> {
  late final TextEditingController _capacity;
  String _error = '';

  /// The package open in the inline editor: its id, or the empty string for one
  /// she has not written yet. Null when nothing is open.
  String? _openOfferId;

  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  final List<TextEditingController> _lines = <TextEditingController>[];

  @override
  void initState() {
    super.initState();
    _capacity = TextEditingController(
      text: widget.model.capacityMax?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _capacity.dispose();
    _name.dispose();
    _price.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  /// Opens the inline editor on [offer], or on a blank package when it is null.
  void _open(Offer? offer) {
    _name.text = offer?.name ?? '';
    // Whole pounds, which is how every price in Egypt is written. The stored
    // value is piastres and the conversion happens here and nowhere else.
    _price.text = offer == null ? '' : '${offer.pricePiastres ~/ 100}';
    for (final line in _lines) {
      line.dispose();
    }
    _lines
      ..clear()
      ..addAll([
        for (final line in offer?.lines ?? const <String>[])
          TextEditingController(text: line),
      ]);
    setState(() => _openOfferId = offer?.id ?? '');
  }

  /// The next id, mirroring the deterministic ids production mints.
  String _nextOfferId(PackagesEditor editor) {
    var highest = 0;
    for (final offer in editor.offers) {
      final n = int.tryParse(offer.id.replaceFirst('offer-', ''));
      if (n != null && n > highest) highest = n;
    }
    return 'offer-${highest + 1}';
  }

  Future<void> _save(PackagesEditor editor) async {
    final id = _openOfferId;
    if (id == null) return;
    // Western digits only, for the reason the capacity field gives above.
    final pounds = int.tryParse(_price.text.trim());
    final result = OfferDraft.validate(
      id: id.isEmpty ? _nextOfferId(editor) : id,
      name: _name.text,
      pricePiastres: pounds == null ? 0 : pounds * 100,
      lines: <String>[
        for (final line in _lines)
          if (line.text.trim().isNotEmpty) line.text.trim(),
      ],
    );
    final draft = result.draft;
    if (draft == null) {
      // The one refusal a woman can act on here is a blank name; the others
      // cannot be reached from these two fields.
      setState(() {});
      return;
    }
    await editor.save(draft);
    if (!mounted) return;
    setState(() => _openOfferId = null);
    widget.onOffersChanged?.call();
  }

  void _onCapacityChanged(String raw) {
    // Western digits only. `int.tryParse` accepts exactly those, which is the
    // behaviour this product wants in both languages — and is why nothing here
    // reaches for `NumberFormat`, whose Arabic locale would both render and
    // expect Eastern digits.
    final parsed = int.tryParse(raw.trim());
    final l10n = AppL10n.of(context);
    setState(() {
      if (parsed == null ||
          parsed < CoachCapacity.floor ||
          parsed > CoachCapacity.ceiling) {
        widget.model.capacityMax = null;
        _error = raw.trim().isEmpty ? '' : _rangeHint(l10n);
      } else {
        widget.model.capacityMax = parsed;
        _error = '';
      }
    });
  }

  /// The allowed range, in Western digits, joined by her own language's word.
  String _rangeHint(AppL10n l10n) =>
      l10n.fromToTo('${CoachCapacity.floor}', '${CoachCapacity.ceiling}');

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;
    final editor = widget.editor;
    final showsOffers = widget.flags.isOn(Feature.payments) && editor != null;

    return CoachSetupScaffold(
      step: CoachSetupStep.packages,
      title: l10n.howManyClientsCanYouTake,
      subtitle: l10n.yourPricesLiveOnYourPageWhere,
      onBack: () => goToScreen(context, 'K10', widget.onBack),
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: model.canAdvanceFrom(CoachSetupStep.packages)
          ? () => goToScreen(context, 'K11', widget.onContinue)
          : null,
      children: [
        AppField(
          controller: _capacity,
          label: l10n.clientsAtOnce,
          keyboardType: TextInputType.number,
          errorText: _error,
          helper: l10n.shownOnYourPageAsSpotsLeft,
          onChanged: _onCapacityChanged,
        ),
        AppCard(
          variant: AppCardVariant.sage,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.payments,
                  size: 22,
                  color: AppColors.primaryDim,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.youKeep80, style: AppText.titleM),
                      const SizedBox(height: 2),
                      Text(
                        l10n.ofEveryPriceYouSetOnYour,
                        style: AppText.bodyM.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),

        // The single write path, when there is a rail for it to price against.
        if (showsOffers) ...[
          Text(l10n.packages, style: AppText.titleM),
          for (final offer in editor.offers)
            AppListItem(
              title: offer.name,
              // Her own figure, joined to the dictionary's word. Never a
              // sample price.
              subtitle: '${offer.pricePiastres ~/ 100} ${l10n.egpAMonth}',
              trailing: const Icon(
                Icons.chevron_right,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () => widget.onEditOffer == null
                  ? _open(offer)
                  : widget.onEditOffer!(offer.id),
            ),
          if (_openOfferId != null) ..._editor(l10n, editor),
          AppListItem(
            variant: AppCardVariant.filled,
            leading: const Icon(
              Icons.add,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.addAnotherOffer,
            subtitle: l10n.youKeep80OfEveryPriceYou,
            onTap: () => widget.onEditOffer == null
                ? _open(null)
                : widget.onEditOffer!(null),
          ),
        ],

        AppSageNote(
          showsOffers
              ? l10n.yourPriceChangeAppliesToNewClients
              : l10n.youWillWriteYourOffersWhenYou,
        ),
      ],
    );
  }

  /// The package she has open: what it is called, what it costs, what is in it.
  ///
  /// It is a card under the row rather than a screen because the designed set
  /// has no screen for it, and a row that opened nothing was the alternative.
  List<Widget> _editor(AppL10n l10n, PackagesEditor editor) => <Widget>[
    AppCard(
      variant: AppCardVariant.outlined,
      children: [
        AppField(
          controller: _name,
          label: l10n.name,
          hint: l10n.whatItIsCalledWhatIsIn,
          onChanged: (_) => setState(() {}),
        ),
        AppField(
          controller: _price,
          label: l10n.priceAMonth,
          helper: l10n.egpAMonth,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
        ),
        for (final line in _lines)
          AppField(
            controller: line,
            label: l10n.whatIOffer,
            onChanged: (_) => setState(() {}),
          ),
        AppListItem(
          variant: AppCardVariant.filled,
          leading: const Icon(Icons.add, size: 22, color: AppColors.primaryDim),
          title: l10n.addALine,
          onTap: () => setState(() => _lines.add(TextEditingController())),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.save,
                height: 46,
                fontSize: 15,
                // A package with no name is refused by `OfferDraft.validate`,
                // so the button is simply not active until she has written one.
                onPressed: _name.text.trim().isEmpty
                    ? null
                    : () => _save(editor),
              ),
            ),
            const SizedBox(width: 10),
            AppButton(
              l10n.close,
              variant: AppButtonVariant.text,
              height: 46,
              fontSize: 15,
              onPressed: () => setState(() => _openOfferId = null),
            ),
          ],
        ),
      ],
    ),
  ];
}
