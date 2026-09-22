/// B04 — the cover editor, and the one slider that can make a page unreadable.
///
/// `P0-PORT-07`: *"The slider stops at the minimum alpha that reaches 4.5:1
/// against the headline and the disabled region is visible. Replacing the photo
/// recomputes the floor and raises the current value if it is now too low. If
/// even 0.9 fails the layout is refused and photo-above is offered."*
///
/// All three of those sentences are [OverlayFloor], not this widget. The screen
/// receives an [OverlayDecision] — computed on device from the region under the
/// text box — and does three things with it: clamps the slider's minimum,
/// paints the region below the floor as unavailable, and, when the decision is
/// [OverlayDecision.refusedLayout], stops offering `text-over-photo` at all.
///
/// ## A rejected claim is shown as rejected
///
/// [MarketingClaimPolicy] runs over the headline and the subline. A violation
/// puts the field into its error state and prints **the offending span** — her
/// own words, the ones that failed — beneath it. The dictionary has no "this is
/// not allowed" line for block prose, so the screen marks the words rather than
/// inventing a sentence about them.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart' show AppCardVariant, handCardLook;
import '../../../ui/app_field.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/marketing_claim_policy.dart';
import '../domain/overlay_floor.dart';
import '../domain/portfolio_block.dart';
import 'photo_scrim.dart';

class CoverEditorView extends StatefulWidget {
  const CoverEditorView({
    super.key,
    required this.payload,
    this.overlayFloor,
    this.claims = const MarketingClaimPolicy(),
    this.onChanged,
    this.onChangePhoto,
    this.onDone,
    this.onClose,
  });

  final CoverPayload payload;

  /// The decision for the region under the text box. Null means "not computed"
  /// — offline, before the photo has been decoded — and the slider is then left
  /// unclamped rather than clamped to a guess.
  final OverlayDecision? overlayFloor;

  final MarketingClaimPolicy claims;

  final ValueChanged<CoverPayload>? onChanged;
  final VoidCallback? onChangePhoto;
  final VoidCallback? onDone;
  final VoidCallback? onClose;

  @override
  State<CoverEditorView> createState() => _CoverEditorViewState();
}

class _CoverEditorViewState extends State<CoverEditorView> {
  late CoverPayload _payload;
  late final TextEditingController _headline;
  late final TextEditingController _subline;

  @override
  void initState() {
    super.initState();
    _payload = widget.payload;
    _headline = TextEditingController(text: _payload.headline);
    _subline = TextEditingController(text: _payload.subline);
  }

  @override
  void dispose() {
    _headline.dispose();
    _subline.dispose();
    super.dispose();
  }

  /// The floor as a number the slider can hold, or zero when nothing has been
  /// computed. A refused layout reports [kMaxOverlayAlpha], which is why the
  /// refusal is checked before the clamp anywhere it matters.
  double get _floor => widget.overlayFloor?.minAlpha ?? 0;

  bool get _layoutRefused => widget.overlayFloor?.refused ?? false;

  void _update(CoverPayload next) {
    setState(() => _payload = next);
    widget.onChanged?.call(next);
  }

  void _setLayout(CoverLayout layout) {
    if (layout == CoverLayout.textOverPhoto && _layoutRefused) return;
    var next = _payload.copyWith(layout: layout);
    if (layout == CoverLayout.textOverPhoto) {
      // P0-PORT-07: raise, never lower. She is allowed to be stricter than the
      // validator; she is not allowed to be looser.
      final decision = widget.overlayFloor;
      if (decision != null) {
        next = next.copyWith(
          overlay: OverlayFloor.raiseToFloor(next.overlay, decision),
        );
      }
    }
    _update(next);
  }

  List<ClaimViolation> _violations(String text) =>
      widget.claims.check(text).violations;

  /// The words that failed, joined. Her own text — the screen marks what is
  /// wrong rather than describing it, because the dictionary has no line for
  /// the description.
  String _spans(List<ClaimViolation> violations) =>
      violations.map((v) => v.span).join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final headlineClaims = _violations(_payload.headline);
    final sublineClaims = _violations(_payload.subline);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.cover,
        onBack: widget.onClose,
        leadingIcon: Icons.close,
        actions: [
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
          _preview(l10n),
          Text(
            l10n.layout,
            style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
          ),
          Row(
            children: [
              for (final layout in CoverLayout.values) ...[
                if (layout != CoverLayout.values.first)
                  const SizedBox(width: 8),
                Expanded(
                  child: _LayoutTile(
                    layout: layout,
                    label: _layoutLabel(l10n, layout),
                    selected: _payload.layout == layout,
                    // The one case where the builder says no. `photo-above` is
                    // still offered, which is the whole point of refusing.
                    enabled:
                        !(layout == CoverLayout.textOverPhoto &&
                            _layoutRefused),
                    onTap: () => _setLayout(layout),
                  ),
                ),
              ],
            ],
          ),
          AppField(
            controller: _headline,
            label: l10n.headline,
            errorText: _spans(headlineClaims),
            onChanged: (value) => _update(_payload.copyWith(headline: value)),
          ),
          AppField(
            controller: _subline,
            label: l10n.oneLineUnderIt,
            errorText: _spans(sublineClaims),
            onChanged: (value) => _update(_payload.copyWith(subline: value)),
          ),
          if (_payload.layout == CoverLayout.textOverPhoto && !_layoutRefused)
            _darkenRow(l10n),
        ],
      ),
    );
  }

  Widget _preview(AppL10n l10n) {
    final photo = AppMedia(
      height: 150,
      kind: AppMediaKind.photo,
      showPlayButton: false,
      borderRadius: AppRadius.md,
    );

    if (_payload.layout == CoverLayout.noPhoto) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _payload.headline,
            style: AppText.headline.copyWith(color: AppColors.onSurface),
          ),
          if (_payload.subline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _payload.subline,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ],
      );
    }

    return Stack(
      children: [
        photo,
        if (_payload.layout == CoverLayout.textOverPhoto)
          Positioned.fill(
            child: PhotoScrim(
              alpha: _payload.overlay,
              height: 150,
              borderRadius: AppRadius.md,
            ),
          ),
        if (_payload.layout == CoverLayout.textOverPhoto)
          PositionedDirectional(
            start: 14,
            end: 14,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _payload.headline,
                  style: AppText.titleL.copyWith(color: Colors.white),
                ),
                if (_payload.subline.isNotEmpty)
                  Text(
                    _payload.subline,
                    style: AppText.bodyM.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
              ],
            ),
          ),
        // A small printed tab on the photo's corner, not a pill.
        PositionedDirectional(
          end: 9,
          top: 9,
          child: HandSurface(
            seed: handSeed(['cover-change-photo']),
            fill: AppColors.surfaceLowest,
            frame: AppColors.outline.withValues(alpha: 0.55),
            frameWidth: 1.05,
            radius: 4,
            looseCorner: 12,
            onTap: widget.onChangePhoto,
            semanticsButton: true,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_camera,
                  size: 15,
                  color: AppColors.onSurface,
                ),
                const SizedBox(width: 5),
                Text(
                  l10n.change,
                  style: AppText.label.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkenRow(AppL10n l10n) {
    final value = _payload.overlay.clamp(_floor, kMaxOverlayAlpha);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.darkenThePhoto,
                style: AppText.titleS.copyWith(color: AppColors.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.soTheWordsStayReadable,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 140,
          child: Slider(
            // The floor **is** the minimum: there is no disabled region to drag
            // into, because the control cannot express a value below it.
            min: _floor,
            max: kMaxOverlayAlpha,
            value: value,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.surfaceHigh,
            onChanged: (next) => _update(_payload.copyWith(overlay: next)),
          ),
        ),
      ],
    );
  }

  static String _layoutLabel(AppL10n l10n, CoverLayout layout) =>
      switch (layout) {
        CoverLayout.textOverPhoto => l10n.textOverPhoto,
        CoverLayout.photoAbove => l10n.photoAbove,
        CoverLayout.noPhoto => l10n.noPhoto,
      };
}

class _LayoutTile extends StatelessWidget {
  const _LayoutTile({
    required this.layout,
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final CoverLayout layout;
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = handCardLook(
      selected ? AppCardVariant.selected : AppCardVariant.outlined,
    );
    final hasPhoto = layout != CoverLayout.noPhoto;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: HandSurface(
        seed: handSeed(['cover-layout', layout.name]),
        fill: look.fill,
        frame: look.frame,
        frameWidth: look.frameWidth,
        level: look.level,
        radius: 5,
        looseCorner: 14,
        onTap: enabled ? onTap : null,
        pressable: true,
        padding: const EdgeInsets.all(9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // A thumbnail of the layout: the photo marked in pencil hatching,
            // the way a page plan marks where a picture goes, and the
            // headline as one stroke of ink.
            SizedBox(
              height: 34,
              child: HandSurface(
                seed: handSeed(['cover-layout-thumb', layout.name]),
                fill: hasPhoto
                    ? AppColors.primarySoft
                    : AppColors.surfaceContainer,
                hatch: hasPhoto ? AppColors.secondary : null,
                level: HandLevel.structural,
                radius: 3,
                looseCorner: 8,
                child: Align(
                  alignment: layout == CoverLayout.photoAbove
                      ? Alignment.bottomCenter
                      : Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 0.7,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: HandRule(
                        seed: layout.index + 3,
                        ink: true,
                        height: 5,
                        color: AppColors.primary.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
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
