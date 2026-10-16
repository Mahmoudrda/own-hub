/// R04 — Exercise video.
///
/// Matches `6-v2/src/screens-train.mjs` → `R04`. Opens *over* the day so closing
/// it returns her to the list. Three cues, not a paragraph, and the quieter
/// alternative is offered before she has to ask for it.
///
/// **The footage is the exercise library's.** When the library holds the move
/// ([clip]), it plays inside the page's own frame, the same way R15 plays it.
/// A move the library does not hold has no clip, so nothing opens this screen
/// for it; opened on its own it still renders [AppMedia]'s placeholder and
/// asks a [WorkoutVideoRepository] for the asset.
///
/// The duration pill has no dictionary key, and correctly so — "0:24" is a value,
/// not copy. It is formatted by [clockLabel], which keeps Western digits in
/// Arabic as `P0-A11Y-01` requires.
library;

import 'dart:async';
import 'dart:io';

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
import '../data/exercise_media_store.dart';
import '../domain/clock_label.dart';
import '../domain/exercise_library.dart';
import '../domain/train_repository.dart';
import 'exercise_clip_frame.dart';
import 'exercise_clip_player.dart';
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
    this.clip,
    this.media = const NoExerciseMedia(),
    this.players,
    this.canSwap = true,
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

  /// The library's row for [move], when it holds one: its clip plays here.
  final LibraryExercise? clip;
  final ExerciseMediaStore media;

  /// Makes the player. Null draws the poster alone, as tests do.
  final ExerciseClipPlayerFactory? players;

  /// False when there is no swap to offer for the move she is on.
  final bool canSwap;

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
        if (AppRouter.screenIsOn('R05') && canSwap)
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
        if (clip case final library?)
          ExerciseClipFrame(
            exercise: library,
            media: media,
            players: players,
            tallest: 0.4,
          )
        else if (source != null)
          AppMedia(
            height: 200,
            showPlayButton: false,
            child: _SourceClip(source: source, players: players),
          )
        else
          const AppMedia(height: 200),
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
                clockLabel(
                  clip == null
                      ? duration
                      : Duration(
                          milliseconds: (clip!.clips.first.seconds * 1000)
                              .round(),
                        ),
                ),
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

/// A clip from the video repository's own source, muted and looping inside the
/// frame. Draws a plain surface until the clip opens, and keeps it if the clip
/// cannot be played, so the page never shows a broken player.
class _SourceClip extends StatefulWidget {
  const _SourceClip({required this.source, this.players});

  final Uri source;
  final ExerciseClipPlayerFactory? players;

  @override
  State<_SourceClip> createState() => _SourceClipState();
}

class _SourceClipState extends State<_SourceClip> {
  ExerciseClipPlayer? _player;
  bool _ready = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final generation = ++_generation;
    if (widget.source.scheme != 'file') return;
    final player = (widget.players ?? VideoPlayerClipPlayer.new)();
    final opened = await player.open(File(widget.source.toFilePath()));
    if (!mounted || generation != _generation || !opened) {
      unawaited(player.dispose());
      return;
    }
    _player = player;
    if (!handMotionOff(context)) await player.play();
    if (mounted && generation == _generation) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    if (!_ready || player == null) {
      return const ColoredBox(color: AppColors.surfaceContainer);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: 100 * player.aspectRatio,
        height: 100,
        child: player.view(),
      ),
    );
  }
}
