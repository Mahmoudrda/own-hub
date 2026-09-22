/// A media placeholder, matching `media()` in `6-v2/src/kit.mjs`.
///
/// The prototype has no real footage, so it draws a block toned with pencil
/// hatching — the way a layout marks where a picture will go — with a play
/// button ringed in ink. That is not a stand-in to be deleted later: until the 124 workout
/// videos exist, this is what the app genuinely has to show, and it should look
/// deliberate rather than broken. When a real thumbnail is available it goes in
/// [child] and the placeholder never renders.
///
/// Video is the product's largest content cost and its delivery is settled:
/// Cloudflare R2 behind a CDN with public, content-addressed immutable URLs. A
/// widget that quietly reached for Firebase Storage instead would be a ~$708/month
/// mistake, which is why loading belongs in the data layer and not here.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'app_card.dart' show handLooseRadius, handTightRadius;
import 'hand/hand.dart';

enum AppMediaKind { video, photo }

class AppMedia extends StatelessWidget {
  const AppMedia({
    super.key,
    this.width,
    this.height = 180,
    this.kind = AppMediaKind.video,
    this.borderRadius = AppRadius.md,
    this.showPlayButton = true,
    this.badge,
    this.child,
  });

  final double? width;
  final double height;
  final AppMediaKind kind;
  final double borderRadius;
  final bool showPlayButton;

  /// A short overlay label — a duration, a count.
  final String? badge;

  /// The real image or player, once there is one.
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final tint = kind == AppMediaKind.photo
        ? AppColors.surfaceHigh
        : AppColors.secondaryContainer;
    final seed = handSeed(['media', width, height, badge]);

    return SizedBox(
      width: width,
      height: height,
      child: HandSurface(
        seed: seed,
        fill: tint,
        // Tone from hatching, never from a gradient.
        hatch: child == null ? AppColors.secondary : null,
        radius: handTightRadius(borderRadius),
        looseCorner: handLooseRadius(borderRadius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(handTightRadius(borderRadius)),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (child != null) Positioned.fill(child: child!),
              if (child == null && showPlayButton)
                CustomPaint(
                  foregroundPainter: LoopPainter(
                    seed: seed,
                    color: AppColors.primary,
                    width: HandStroke.pen,
                    level: HandLevel.expressive,
                    inflate: const EdgeInsets.all(3),
                    textDirection: Directionality.of(context),
                  ),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceLowest,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              if (badge != null)
                PositionedDirectional(
                  end: 10,
                  bottom: 8,
                  child: Container(
                    height: 26,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLowest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge!,
                      style: AppText.label.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
