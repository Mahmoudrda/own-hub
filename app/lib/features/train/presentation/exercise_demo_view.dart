/// R15 — Exercise demo.
///
/// One move, shown the way the owner filmed it: the whole clip, never cropped,
/// inside the page's own media frame. No player chrome: no controls bar, no
/// scrubber, no full screen. The poster is there at once, the clip takes its
/// place when it is ready and loops without sound, and a tap pauses it under
/// the same ringed play mark the app draws everywhere else. Under Reduce
/// Motion it waits for that tap.
///
/// The first time she opens a move the clip is fetched; after that it is on
/// her phone and plays with no signal (D42). If it cannot be fetched she is
/// told it needs a connection once, and offered to try again.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import 'exercise_clip_frame.dart';
import 'exercise_clip_player.dart';
import 'exercise_labels.dart';
import 'train_widgets.dart';

class ExerciseDemoView extends StatefulWidget {
  const ExerciseDemoView({
    super.key,
    this.exercise,
    this.media = const NoExerciseMedia(),
    this.players,
    this.onClose,
    this.onOpenLibrary,
  });

  /// Null when there is nothing she may be shown: the empty state.
  final LibraryExercise? exercise;
  final ExerciseMediaStore media;

  /// Makes the player. Null draws the poster alone, as tests do.
  final ExerciseClipPlayerFactory? players;

  final VoidCallback? onClose;
  final VoidCallback? onOpenLibrary;

  @override
  State<ExerciseDemoView> createState() => _ExerciseDemoViewState();
}

class _ExerciseDemoViewState extends State<ExerciseDemoView> {
  int _angle = 0;

  @override
  void didUpdateWidget(ExerciseDemoView old) {
    super.didUpdateWidget(old);
    if (old.exercise?.id != widget.exercise?.id) _angle = 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final exercise = widget.exercise;

    if (exercise == null) {
      return AppScaffold(
        appBar: TrainTopBar(
          onClose: widget.onClose,
          closeIcon: Icons.arrow_back,
        ),
        children: [
          AppEmptyState(
            icon: Icons.play_circle_outline,
            title: l10n.chooseAMoveFromTheLibrary,
            body: l10n.seeHowEveryMoveIsDone,
          ),
          AppButton(
            l10n.openTheExerciseLibrary,
            variant: AppButtonVariant.outlined,
            onPressed: widget.onOpenLibrary,
          ),
        ],
      );
    }

    final language = Localizations.localeOf(context).languageCode;
    final setup = exercise.setup(language);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);

    Widget fact(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label.copyWith(color: AppColors.primaryDim)),
        const SizedBox(height: 2),
        Text(value, style: AppText.bodyM),
      ],
    );

    return AppScaffold(
      // The clip is the picture on this page; header art above it would be a
      // second one.
      showArt: false,
      appBar: TrainTopBar(onClose: widget.onClose, closeIcon: Icons.arrow_back),
      children: [
        ExerciseClipFrame(
          clipKey: const ValueKey('r15-clip'),
          exercise: exercise,
          media: widget.media,
          players: widget.players,
          angle: _angle,
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MarkerHighlight(
            child: MoveName(exercise.name(language), style: AppText.titleL),
          ),
        ),
        if (exercise.clips.length > 1)
          AppChipRow(
            key: const ValueKey('r15-angles'),
            grow: false,
            items: [for (final c in exercise.clips) angleLabel(l10n, c.angle)],
            selected: {_angle},
            onTap: (i) {
              if (i == _angle) return;
              setState(() => _angle = i);
            },
          ),
        fact(l10n.musclesWorked, musclesLine(l10n, exercise.primaryMuscles)),
        if (exercise.secondaryMuscles.isNotEmpty)
          fact(l10n.alsoWorks, musclesLine(l10n, exercise.secondaryMuscles)),
        if (equipmentLine(l10n, exercise.equipment).trim().isNotEmpty)
          fact(l10n.equipment, equipmentLine(l10n, exercise.equipment)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            AppChip(placeLabel(l10n, exercise.place)),
            AppChip(levelLabel(l10n, exercise.level)),
            if (exercise.quiet) AppChip(l10n.quiet),
            if (exercise.floorOnly) AppChip(l10n.floorOnly),
          ],
        ),
        if (setup != null) ...[
          Text(
            l10n.howToSetUp,
            style: AppText.label.copyWith(color: AppColors.primaryDim),
          ),
          Text(setup, style: quiet),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}
