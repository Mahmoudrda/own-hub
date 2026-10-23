/// A move's video in a sheet, with a "Use this move" button.
///
/// Shown while she chooses a move, in the picker and when she swaps one, so
/// she sees what the move looks like before it goes into her workout. The clip
/// is the same frame R15 uses, so the full-screen badge comes with it.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';
import '../data/exercise_media_store.dart';
import '../domain/exercise_library.dart';
import 'exercise_clip_frame.dart';
import 'exercise_clip_player.dart';
import 'exercise_labels.dart';

/// Opens the preview of [exercise] and answers true when she taps "Use this
/// move", false when she closes it.
Future<bool> showMovePreview(
  BuildContext context, {
  required LibraryExercise exercise,
  required ExerciseMediaStore media,
  ExerciseClipPlayerFactory? players,
  String? note,
}) async {
  final use = await showAppSheet<bool>(
    context: context,
    children: [
      MovePreview(
        exercise: exercise,
        media: media,
        players: players,
        note: note,
        onUse: () => Navigator.of(context).pop(true),
      ),
    ],
  );
  return use ?? false;
}

class MovePreview extends StatelessWidget {
  const MovePreview({
    super.key,
    required this.exercise,
    required this.media,
    required this.onUse,
    this.players,
    this.note,
  });

  final LibraryExercise exercise;
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory? players;

  /// A line under the name, such as why a swap is offered.
  final String? note;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final language = Localizations.localeOf(context).languageCode;
    final muscles = musclesLine(l10n, exercise.primaryMuscles);
    final kit = exercise.needsNothing
        ? l10n.noEquipment
        : equipmentLine(l10n, exercise.equipment);
    return Column(
      key: const ValueKey('move-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: [
        ExerciseClipFrame(
          exercise: exercise,
          media: media,
          players: players,
          tallest: 0.38,
          clipKey: const ValueKey('move-preview-clip'),
        ),
        Semantics(
          header: true,
          child: MoveName(exercise.name(language), style: AppText.titleL),
        ),
        if (note != null && note!.trim().isNotEmpty)
          Text(
            note!,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        if (muscles.isNotEmpty)
          _Fact(label: l10n.musclesWorked, value: muscles),
        if (kit.trim().isNotEmpty) _Fact(label: l10n.equipment, value: kit),
        AppButton(
          l10n.useThisMove,
          key: const ValueKey('move-preview-use'),
          icon: Icons.check,
          onPressed: onUse,
        ),
        AppButton(
          l10n.close,
          key: const ValueKey('move-preview-close'),
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label: ',
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        TextSpan(text: value, style: AppText.bodyM),
      ],
    ),
  );
}
