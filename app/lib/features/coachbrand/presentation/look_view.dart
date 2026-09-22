/// B05 — her look, and the colour the builder will not let her have.
///
/// `P0-PORT-06`: *"Every accepted theme passes all 14 role pairs at 4.5:1, and
/// 3:1 for display/headline and non-text. A failing seed is retried at
/// contrastLevel 0.5 then 1.0 and only refused if it still fails, with the
/// nearest passing seed offered."*
///
/// Every word of that is [ThemeValidator] and [PortfolioTheme.validated]. This
/// screen calls the constructor and draws the answer:
///
///   * [ThemeAccepted] — the theme changes, and nothing is said about it.
///   * [ThemeRefused] — the theme **does not change**, the note card turns from
///     sage to error and reads *"We will not let you pick text a client cannot
///     read."*, and [ThemeRefused.nearestPassingSeed] is marked in the row so
///     the answer to "you cannot have that" is a colour rather than a dead end.
///
/// The refusal is not a message the widget composes. `PortfolioTheme`'s
/// constructor is private, so a refused seed has no theme object to apply —
/// there is nothing here to forget to check.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../../today/presentation/today_cards.dart' show openScreen;
import '../domain/contrast.dart' show PortfolioTextStyle;
import '../domain/portfolio_theme.dart';
import '../domain/theme_validator.dart';

class LookView extends StatefulWidget {
  const LookView({
    super.key,
    required this.theme,
    this.seeds = kCuratedSeeds,
    this.validator = const ThemeValidator(),
    this.now,
    this.onThemeChanged,
    this.onPreview,
    this.onDone,
    this.onBack,
  });

  /// The theme as it stands. Validated by construction — there is no other kind.
  final PortfolioTheme theme;

  /// The swatch row. Six curated seeds by default; a caller may pass its own,
  /// which is how a custom colour reaches the same validation path.
  final List<String> seeds;

  final ThemeValidator validator;

  /// Injected so a validation stamp is deterministic in a test.
  final DateTime? now;

  final ValueChanged<PortfolioTheme>? onThemeChanged;
  final VoidCallback? onPreview;
  final VoidCallback? onDone;
  final VoidCallback? onBack;

  @override
  State<LookView> createState() => _LookViewState();
}

class _LookViewState extends State<LookView> {
  late PortfolioTheme _theme;

  /// The last refusal, if the last thing she tried was refused. Cleared by the
  /// next acceptance, because a stale refusal about a colour she is no longer
  /// using would be a statement about nothing.
  ThemeRefused? _refused;

  @override
  void initState() {
    super.initState();
    _theme = widget.theme;
  }

  /// One entry point for all three knobs, so a corner change is validated by
  /// the same call a colour change is.
  void _choose({String? seed, PortfolioType? type, PortfolioCorners? corners}) {
    final choice = PortfolioTheme.validated(
      seed: seed ?? _theme.seed,
      type: type ?? _theme.type,
      corners: corners ?? _theme.corners,
      validator: widget.validator,
      now: widget.now,
    );

    switch (choice) {
      case ThemeAccepted(:final theme):
        setState(() {
          _theme = theme;
          _refused = null;
        });
        widget.onThemeChanged?.call(theme);
      case ThemeRefused():
        // Nothing is applied. There is no theme object to apply.
        setState(() => _refused = choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final refused = _refused;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.yourLook,
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: () => openScreen(context, 'B10', widget.onPreview),
            icon: const Icon(Icons.visibility),
            color: AppColors.onSurface,
            tooltip: l10n.preview,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.done_54ca1,
              height: 38,
              fontSize: 15,
              onPressed: widget.onDone,
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.thisIsYoursNotOurs,
                style: AppText.titleM.copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.colourTypeAndShapeChangeEverySection,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          _head(l10n.colour),
          _SwatchRow(
            seeds: widget.seeds,
            selected: _theme.seed,
            suggested: refused?.nearestPassingSeed,
            nameOf: (seed) => seedLabel(l10n, seed),
            onTap: (seed) => _choose(seed: seed),
          ),
          _head(l10n.type),
          Row(
            children: [
              for (final type in PortfolioType.values) ...[
                if (type != PortfolioType.values.first)
                  const SizedBox(width: 8),
                Expanded(
                  child: _TypeCard(
                    sample: l10n.aa,
                    // The sample is set in the pairing it is a sample of, so
                    // the three cards read differently from each other and the
                    // choice can be made by eye rather than by the words
                    // underneath.
                    sampleStyle: _sampleStyle(type),
                    label: _typeLabel(l10n, type),
                    selected: _theme.type == type,
                    onTap: () => _choose(type: type),
                  ),
                ),
              ],
            ],
          ),
          _head(l10n.corners),
          Row(
            children: [
              for (final corners in PortfolioCorners.values) ...[
                if (corners != PortfolioCorners.values.first)
                  const SizedBox(width: 8),
                Expanded(
                  child: _CornersCard(
                    corners: corners,
                    label: _cornersLabel(l10n, corners),
                    selected: _theme.corners == corners,
                    onTap: () => _choose(corners: corners),
                  ),
                ),
              ],
            ],
          ),
          AppCard(
            // Sage while it is a promise; error the moment it has been kept.
            variant: refused == null
                ? AppCardVariant.sage
                : AppCardVariant.error,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    refused == null ? Icons.visibility : Icons.error_outline,
                    size: 22,
                    color: refused == null
                        ? AppColors.primaryDim
                        : AppColors.error,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.contrastIsCheckedForYou,
                          style: AppText.titleM.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.weWillNotLetYouPickText,
                          style: AppText.bodyM.copyWith(
                            color: refused == null
                                ? AppColors.onSurfaceVariant
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _head(String text) => Text(
    text,
    style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
  );

  /// "Aa" in the pairing [type] would give her, on her current colour.
  ///
  /// Built through the same private constructor everything else goes through,
  /// so a sample can only ever be drawn in a pairing that passed. The ink stays
  /// `onSurface`: the sample is about the letterforms, and setting it in the
  /// seed would put an unvalidated colour on an unvalidated background.
  TextStyle _sampleStyle(PortfolioType type) {
    final choice = PortfolioTheme.validated(
      seed: _theme.seed,
      type: type,
      corners: _theme.corners,
      validator: widget.validator,
      now: widget.now,
    );
    final theme = choice is ThemeAccepted ? choice.theme : _theme;
    return theme
        .styleFor(PortfolioTextStyle.titleL)
        .copyWith(color: AppColors.onSurface);
  }

  static String _typeLabel(AppL10n l10n, PortfolioType type) => switch (type) {
    PortfolioType.calm => l10n.calmAndPlain,
    PortfolioType.strong => l10n.strongAndWide,
    PortfolioType.soft => l10n.softAndRound,
  };

  static String _cornersLabel(AppL10n l10n, PortfolioCorners corners) =>
      switch (corners) {
        PortfolioCorners.sharp => l10n.sharp,
        PortfolioCorners.soft => l10n.soft,
        PortfolioCorners.round => l10n.round,
      };
}

/// The name a swatch is announced by.
///
/// A circle of colour has nothing to read, so without this the six palettes are
/// six identical unlabelled buttons to a screen reader. The curated seeds are
/// named; anything else is announced by its own `#RRGGBB`, which is the only
/// true thing there is to say about a colour nobody has named.
String seedLabel(AppL10n l10n, String seed) {
  final index = kCuratedSeeds.indexWhere(
    (curated) => curated.toUpperCase() == seed.toUpperCase(),
  );
  return switch (index) {
    0 => l10n.rose,
    1 => l10n.sage,
    2 => l10n.amber,
    3 => l10n.blue,
    4 => l10n.purple,
    5 => l10n.teal,
    _ => seed.toUpperCase(),
  };
}

/// The colours, with the refused one left unselected and the suggestion marked.
class _SwatchRow extends StatelessWidget {
  const _SwatchRow({
    required this.seeds,
    required this.selected,
    required this.suggested,
    required this.nameOf,
    required this.onTap,
  });

  final List<String> seeds;
  final String selected;

  /// [ThemeRefused.nearestPassingSeed] — the colour offered instead.
  final String? suggested;

  /// What each swatch is announced by. See [seedLabel].
  final String Function(String seed) nameOf;

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final seed in seeds)
          _Swatch(
            seed: seed,
            label: nameOf(seed),
            selected: _same(seed, selected),
            suggested: suggested != null && _same(seed, suggested!),
            onTap: () => onTap(seed),
          ),
      ],
    );
  }

  /// `#b4526e` and `#B4526E` are one colour; the validator normalises to upper
  /// case, so a comparison that did not would lose the selected ring.
  static bool _same(String a, String b) => a.toUpperCase() == b.toUpperCase();
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.seed,
    required this.label,
    required this.selected,
    required this.suggested,
    required this.onTap,
  });

  final String seed;

  /// What it is announced by, since a circle has nothing to read.
  final String label;

  final bool selected;
  final bool suggested;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = parseSeed(seed);

    // Named and said to be chosen, not only ringed: the ring is the whole
    // answer on this screen, and a ring is invisible to a screen reader.
    return Semantics(label: label, selected: selected, child: _circle(colour));
  }

  Widget _circle(Color? colour) {
    // The swatch itself stays an exact circle: it is a sample of a colour,
    // and a sample drawn by hand would be a less accurate one.
    return HandPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.full),
      builder: (context, pressed) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: colour ?? AppColors.surfaceContainer,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected
                ? AppColors.onSurface
                : suggested
                ? AppColors.primary
                : AppColors.outline,
            width: selected || suggested ? 3 : 1,
          ),
        ),
        // A malformed seed has no colour to draw, so it draws the absence
        // rather than a black circle that looks like a choice.
        child: colour == null
            ? const Icon(
                Icons.block,
                size: 18,
                color: AppColors.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.sample,
    required this.sampleStyle,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String sample;

  /// The pairing this card is offering, so the sample is drawn in it.
  final TextStyle sampleStyle;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ChoiceCard(
      selected: selected,
      onTap: onTap,
      label: label,
      child: Text(sample, style: sampleStyle),
    );
  }
}

class _CornersCard extends StatelessWidget {
  const _CornersCard({
    required this.corners,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PortfolioCorners corners;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radii = PortfolioRadii(corners);

    return _ChoiceCard(
      selected: selected,
      onTap: onTap,
      label: label,
      // Drawn exact, not by hand: it is a sample of her corner radius, and a
      // wobbling edge would misstate the one thing it is there to show.
      child: Container(
        width: 42,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(radii.lg),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.onTap,
    required this.label,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final look = handCardLook(
      selected ? AppCardVariant.selected : AppCardVariant.outlined,
    );

    // Ringed in ink when chosen, the way she would mark her pick on paper —
    // and said to be chosen, so the ring is not the only place the answer
    // lives.
    return Semantics(
      selected: selected,
      child: HandSurface(
        seed: handSeed(['look-choice', label]),
        fill: look.fill,
        frame: look.frame,
        frameWidth: look.frameWidth,
        level: look.level,
        radius: 5,
        looseCorner: 14,
        onTap: onTap,
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            child,
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppText.nav.copyWith(
                color: AppColors.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
