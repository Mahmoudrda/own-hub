/// R04 — Exercise video.
///
/// Matches `6-v2/src/screens-train.mjs` → `R04`. Opens *over* the day so closing
/// it returns her to the list. Three cues, not a paragraph, and the quieter
/// alternative is offered before she has to ask for it.
///
/// **The video does not exist.** None of the 124 demo loops have been produced,
/// so this renders [AppMedia]'s placeholder and asks a [WorkoutVideoRepository]
/// for the asset rather than reaching for a URL of its own. When the loops are
/// published the repository returns one and the screen does not change.
///
/// The duration pill has no dictionary key, and correctly so — "0:24" is a value,
/// not copy. It is formatted by [clockLabel], which keeps Western digits in
/// Arabic as `P0-A11Y-01` requires.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_media.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/clock_label.dart';
import '../domain/train_repository.dart';
import 'train_widgets.dart';

class ExerciseVideoView extends StatelessWidget {
  const ExerciseVideoView({
    super.key,
    this.onClose,
    this.onBackToWorkout,
    this.onSwap,
    this.move,
    this.duration = const Duration(seconds: 24),
    this.videos = const UnreleasedVideoRepository(),
  });

  final VoidCallback? onClose;
  final VoidCallback? onBackToWorkout;
  final VoidCallback? onSwap;

  /// The move being demonstrated. Injectable; defaults to the design's.
  final PlannedMove? move;

  /// How long the demo loop runs.
  final Duration duration;

  /// Where the footage would come from. Returns null for every asset today.
  final WorkoutVideoRepository videos;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // The move she tapped, or the one move in the dictionary with authored
    // cues when this screen is opened on its own.
    //
    // The fallback used to be what every woman saw: `R03` discarded the move
    // she tapped (`onOpenMove: (_) => goTo(context, 'R04')`), so tapping "Dead
    // bug" opened a goblet squat. The router now carries the move, and this
    // stays what it says it is — a preview.
    final shown =
        move ??
        PlannedMove(
          exerciseId: 'goblet_squat',
          name: l10n.gobletSquat,
          prescriptionLabel: l10n.n31012KgSuggested,
          cues: [
            l10n.heelsFlatKneesOutOverYourToes,
            l10n.chestUpWeightHeldAtYourChest,
            l10n.standUpStrongSqueezeAtTheTop,
          ],
          sets: const [],
        );

    final assetId = shown.videoAssetId;
    final source = assetId == null ? null : videos.urlFor(assetId);

    return AppScaffold(
      // Closes rather than goes back: this sits over the day, so the cross
      // returns her to the move list she opened it from.
      appBar: TrainTopBar(onClose: onClose),
      footer: [
        AppButton(l10n.backToTheWorkout, onPressed: onBackToWorkout),
        if (AppRouter.screenIsOn('R05'))
          AppButton(
            l10n.swapThisMove,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: onSwap,
          ),
      ],
      children: [
        // `source` is null until the library is produced, so the placeholder is
        // what she actually sees — and it looks deliberate rather than broken.
        AppMedia(height: 200, showPlayButton: source == null),
        Row(
          children: [
            // The move's name is the page's subject, so it takes the one
            // swipe of marker; the cues below stay plain print.
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: MarkerHighlight(
                  child: Text(shown.name, style: AppText.titleL),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Flexible: a Row gives non-flex children unbounded width, so at the
            // largest text size an unconstrained pill overflows the row.
            Flexible(
              child: AppPill(
                clockLabel(duration),
                background: AppColors.surfaceContainer,
                foreground: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(l10n.quiet),
            AppChip(l10n.noJumping),
            AppChip(l10n.legs),
          ],
        ),
        for (final cue in shown.cues)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check, size: 20, color: AppColors.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cue,
                  style: AppText.bodyM.copyWith(height: 22 / 15),
                ),
              ),
            ],
          ),
        AppSageNote(l10n.kneesSoreSwapItForAGlute),
      ],
    );
  }
}
