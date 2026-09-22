/// B09 — the ad designer, and the one action this product refuses outright.
///
/// `P0-ADS-02`: *"Export offline; then export after the client withdraws.
/// Offline export is refused with the reason stated. After withdrawal the
/// export is refused and the ad shows stale."*
///
/// The decision is [AdExportPolicy.decide], called at build with the live
/// result and the current time — never a stored flag, never a value taken at
/// save. A refusal disables **Save to media**, so the irreversible act is
/// unreachable rather than warned about. Everything else on the screen still
/// works: she can change format, change photo and edit words while it is
/// refused, because none of those puts a file outside the app.
///
/// Offline is checked first, before anything else, exactly as the policy orders
/// it: offline a `null` result is indistinguishable from a withdrawn one, and
/// refusing first is what stops this screen reasoning about a document it could
/// not read.
///
/// ## A rejected claim is shown as rejected
///
/// `P0-ADS-03`: *"the claim rules are enforced not just displayed."* The banner
/// the mockup draws — *"No weight-loss promises and no timelines. We check
/// every ad against the same rules before it runs."* — is the **description**;
/// [MarketingClaimPolicy] is the enforcement. When a span fails, the banner
/// turns from amber to error, the offending words are printed under it, and the
/// export button is disabled by the same decision that draws them.
///
/// ## What this screen cannot say yet
///
/// The dictionary has no line for *"we check her consent before it leaves the
/// app"*, and `Waiting for signal` would name the network — the sentence the
/// policy comment explicitly refuses, because it invites her to try again at
/// the café. So the refusal is drawn as a disabled control and no reason is
/// stated. Reported, and it is the most important missing string in this group.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/ad_creative.dart';
import '../domain/consent.dart';
import '../domain/contrast.dart';
import '../domain/marketing_claim_policy.dart';
import '../domain/portfolio_theme.dart';
import 'photo_scrim.dart';

/// The ad's darkening. The old gradient reached 0.68 at the bottom edge and
/// the words sit in the lower half; a flat scrim a touch lighter than that
/// keeps them readable without blacking out the photograph.
const double _kAdScrimAlpha = 0.6;

class AdDesignerView extends StatelessWidget {
  const AdDesignerView({
    super.key,
    required this.ad,
    required this.theme,
    required this.now,
    this.online = true,
    this.result,
    this.claims = const MarketingClaimPolicy(),
    this.onFormat,
    this.onChangePhoto,
    this.onEditWords,
    this.onExport,
    this.onBack,
  });

  final AdCreative ad;

  /// Her look. All three sizes inherit it, which is what "3 sizes, one look"
  /// means — the creative is composed from data, never a stored bitmap.
  final PortfolioTheme theme;

  final DateTime now;

  /// Whether there is signal. Offline the consent document cannot be read at
  /// all, which is why export is refused rather than queued.
  final bool online;

  /// The live result this creative shows, fetched now. Null when the creative
  /// shows none — or when we could not read one.
  final ClientResult? result;

  final MarketingClaimPolicy claims;

  final ValueChanged<AdFormat>? onFormat;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onEditWords;
  final VoidCallback? onExport;
  final VoidCallback? onBack;

  /// The check that runs at the moment of export, every time.
  AdExportDecision get exportDecision => AdExportPolicy.decide(
    ad: ad,
    online: online,
    now: now,
    result: result,
    policy: claims,
  );

  /// Whether the creative may draw the client's picture right now.
  ///
  /// Same predicate as the export gate, and for the same reason: an in-app
  /// render that composes from live data is already correct the moment she
  /// withdraws, while a file that has left is not.
  bool get _mayShowResult {
    final id = ad.resultId;
    if (id == null) return true;
    if (!online) return false;
    final live = result;
    return live != null &&
        live.resultId == id &&
        ResultVisibility.isPublishable(live, now);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final violations = ad.claimViolations(claims).violations;
    final decision = exportDecision;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.designAnAd,
        onBack: onBack,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppButton(
              l10n.saveToMedia,
              height: 38,
              fontSize: 15,
              // Refused is refused: there is no control to press, rather than a
              // control that presses and then explains.
              onPressed: decision.isAllowed ? onExport : null,
            ),
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          AppChipRow(
            items: [l10n.feed, l10n.story, l10n.reelCover],
            selected: <int>{AdFormat.values.indexOf(ad.format)},
            onTap: (i) => onFormat?.call(AdFormat.values[i]),
          ),
          _creative(),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              AppChip(l10n.yourColours, selected: true, height: 34),
              AppChip(
                l10n.changePhoto,
                icon: Icons.photo_camera,
                height: 34,
                onTap: onChangePhoto,
              ),
              AppChip(
                l10n.editWords,
                icon: Icons.edit,
                height: 34,
                onTap: onEditWords,
              ),
            ],
          ),
          AppCard(
            variant: violations.isEmpty
                ? AppCardVariant.amber
                : AppCardVariant.error,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            gap: 6,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    violations.isEmpty ? Icons.warning : Icons.error_outline,
                    size: 21,
                    color: violations.isEmpty
                        ? AppColors.amber
                        : AppColors.error,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      l10n.noWeightLossPromisesAndNoTimelines,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
              // The words that failed, marked. Her own text, in the error
              // colour — the dictionary has no sentence to say about them.
              if (violations.isNotEmpty)
                Text(
                  violations.map((v) => v.span).join(' · '),
                  style: AppText.label.copyWith(
                    color: AppColors.error,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _creative() {
    final scheme = theme.scheme();
    final radii = theme.radii;
    final size = switch (ad.format) {
      AdFormat.feed => const Size(260, 260),
      AdFormat.story => const Size(200, 300),
      AdFormat.reelCover => const Size(200, 300),
    };

    return Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            // A withdrawn result takes its photograph with it, here and now —
            // the render composes from live data, so there is nothing stale to
            // draw.
            if (_mayShowResult)
              AppMedia(
                width: size.width,
                height: size.height,
                kind: AppMediaKind.photo,
                showPlayButton: false,
                borderRadius: radii.md,
              )
            else
              // No picture to show: her own surface, framed in her outline
              // and drawn to the same edge the photograph would have had.
              HandSurface(
                seed: handSeed(['media', size.width, size.height, null]),
                fill: scheme.surfaceContainer,
                frame: scheme.outline,
                radius: handTightRadius(radii.md),
                looseCorner: handLooseRadius(radii.md),
                child: SizedBox(width: size.width, height: size.height),
              ),
            Positioned.fill(
              child: PhotoScrim(
                alpha: _kAdScrimAlpha,
                width: size.width,
                height: size.height,
                borderRadius: radii.md,
              ),
            ),
            PositionedDirectional(
              start: 16,
              end: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Her words, in her type pairing. Never localised.
                  Text(
                    ad.headline,
                    style: theme
                        .styleFor(PortfolioTextStyle.headline)
                        .copyWith(color: Colors.white),
                  ),
                  if (ad.body.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      ad.body,
                      style: theme
                          .styleFor(PortfolioTextStyle.bodyM)
                          .copyWith(color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                  if (ad.ctaLabel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    // Her call to action, as a small printed block rather
                    // than a pill.
                    HandSurface(
                      seed: handSeed(['ad-cta', ad.ctaLabel]),
                      fill: Colors.white,
                      radius: 4,
                      looseCorner: 12,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        ad.ctaLabel,
                        style: theme
                            .styleFor(PortfolioTextStyle.titleS)
                            .copyWith(color: AppColors.onSurface),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
