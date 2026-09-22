/// B10 — preview as a client. The same widget H02 uses, over the same data.
///
/// `P0-PORT-05`: *"Both use the same PortfolioView over the same document. The
/// hidden block appears in neither. A code search finds no second
/// coach-profile layout."* So this screen is chrome and nothing else: an
/// [PortfolioView] in `preview` mode, and two buttons over it. It draws no
/// block of its own, and the moment it did, *"preview shows exactly what a
/// client sees"* would stop being true by construction and start being true by
/// two people keeping two trees in step.
///
/// ## A withdrawn result is absent, not hidden
///
/// The preview asks [PublishedPortfolio] what to draw, and that object resolved
/// the ids against **live documents at the moment of the read**. A woman who
/// withdrew at 14:00 is gone from the 14:01 preview of a page published in
/// March, because the page never held anything of hers to remove.
///
/// Offline the results block says it is waiting for signal rather than drawing
/// a cached copy — it cannot check consent, so it does not guess. That is
/// [PortfolioView]'s branch, not this screen's.
library;

import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../domain/published_portfolio_reader.dart';
import 'portfolio_view.dart';

class PreviewView extends StatelessWidget {
  const PreviewView({
    super.key,
    required this.portfolio,
    this.onBackToEditing,
    this.onPublish,
  });

  /// Resolved by the caller, at read time. This screen does not resolve
  /// anything and has no clock.
  final PublishedPortfolio portfolio;

  final VoidCallback? onBackToEditing;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Inside the scroll view, not over it: an overlay
                    // would sit on top of her portfolio as she scrolls.
                    const ScreenArtStrip(size: 84),
                    const SizedBox(height: 12),
                    if (portfolio.blocks.isEmpty)
                      // Nothing written yet: say so, and point her at where
                      // most pages begin — the button below takes her there.
                      _EmptyPreview(l10n: AppL10n.of(context))
                    else
                      PortfolioView(
                        portfolio: portfolio,
                        // The tree is identical either way. The mode exists so a
                        // preview can be told apart in a test and in analytics,
                        // not so it can render differently.
                        mode: PortfolioViewMode.preview,
                      ),
                  ],
                ),
              ),
            ),
            if (portfolio.blocks.isEmpty)
              PositionedDirectional(
                start: 16,
                end: 16,
                bottom: 22 + 48 + 6,
                child: _StartHereNote(l10n: l10n),
              ),
            PositionedDirectional(
              start: 16,
              end: 16,
              bottom: 22,
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      l10n.backToEditing,
                      height: 48,
                      fontSize: 15,
                      variant: AppButtonVariant.outlined,
                      onPressed: onBackToEditing,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: AppButton(
                      l10n.publish,
                      height: 48,
                      fontSize: 15,
                      onPressed: onPublish,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Her preview before she has written anything: the fact, in print.
class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        HandUnderline(
          level: HandLevel.expressive,
          drawOn: true,
          child: Text(l10n.yourPageIsEmpty, style: EditorialType.section),
        ),
      ],
    );
  }
}

/// The note in the margin over the buttons, with a short arrow that lands on
/// "Back to editing" — where a page starts.
class _StartHereNote extends StatelessWidget {
  const _StartHereNote({required this.l10n});

  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 30),
        const HandArrow(
          width: 36,
          height: 44,
          from: Offset(0.9, 0.05),
          to: Offset(0.3, 0.95),
          bend: -0.3,
          seed: 27,
          drawOn: true,
          delay: Duration(milliseconds: 400),
        ),
        const SizedBox(width: 4),
        Flexible(child: HandNote(l10n.startWithACover, size: 19)),
      ],
    );
  }
}
