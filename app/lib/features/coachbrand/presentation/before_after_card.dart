/// A client's result: one photo before, one after, side by side.
///
/// The app draws it, the same way on every coach's page, so no coach designs
/// one: no arrows, no captions in her own type, no "-20 kg" stamped across a
/// body. What is on it comes from the client ([ClientResult]): her two photos
/// and, when she gives them, the months they were taken. Between them the card
/// states only how far apart they are, which is a fact about the dates and not
/// a claim about a body.
///
/// [faceHidden] is the client's choice and is on unless she turned it off. The
/// card covers the top of each photo with a heavy blur while it is on. That is
/// how the card is drawn, not how a face is protected: the photo itself has to
/// be blurred before it leaves her phone (`MediaBlurPolicy`), and nothing is
/// published from this feature until that pipeline exists.
///
/// With no photos it draws two quiet placeholders, which is what `K11` shows a
/// new coach: the shape her clients' results will take, with nothing invented
/// in it.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/hand/hand.dart';

class BeforeAfterCard extends StatelessWidget {
  const BeforeAfterCard({
    super.key,
    this.before,
    this.after,
    this.beforeWhen,
    this.afterWhen,
    this.apart,
    this.faceHidden = true,
  });

  /// Her photos. Null draws the placeholder.
  final ImageProvider? before;
  final ImageProvider? after;

  /// "March 2026", when she gave the month.
  final String? beforeWhen;
  final String? afterWhen;

  /// "26 weeks apart", worked out from her two dates by the caller.
  final String? apart;

  /// The client's choice. On unless she chose to show her face.
  final bool faceHidden;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return HandSurface(
      seed: handSeed(['before-after', beforeWhen, afterWhen]),
      fill: AppColors.surfaceLowest,
      frame: AppColors.outline,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Side(
                  label: l10n.before,
                  when: beforeWhen,
                  photo: before,
                  faceHidden: faceHidden,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Side(
                  label: l10n.after,
                  when: afterWhen,
                  photo: after,
                  faceHidden: faceHidden,
                ),
              ),
            ],
          ),
          if (apart != null) ...[
            const SizedBox(height: 10),
            Center(child: AppPill(apart!)),
          ],
        ],
      ),
    );
  }
}

class _Side extends StatelessWidget {
  const _Side({
    required this.label,
    required this.photo,
    required this.faceHidden,
    this.when,
  });

  final String label;
  final String? when;
  final ImageProvider? photo;
  final bool faceHidden;

  @override
  Widget build(BuildContext context) {
    final image = photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppText.titleS),
        if (when != null)
          Text(
            when!,
            style: AppText.label.copyWith(color: AppColors.onSurfaceVariant),
          ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: image == null
              ? const AppMedia(
                  kind: AppMediaKind.photo,
                  showPlayButton: false,
                  height: double.infinity,
                )
              : ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: image, fit: BoxFit.cover),
                      if (faceHidden)
                        Align(
                          alignment: Alignment.topCenter,
                          child: FractionallySizedBox(
                            heightFactor: 0.3,
                            widthFactor: 1,
                            child: ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 18,
                                  sigmaY: 18,
                                ),
                                child: const ColoredBox(
                                  color: Color(0x14000000),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
