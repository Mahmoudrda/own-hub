/// R13 — Move logged.
///
/// Matches `6-v2/src/screens-train.mjs` → `R13`. Logging a whole move in one tap
/// returns her to the list with that move struck through and the next one live.
///
/// **The session does not end.** That is the entire reason this screen exists:
/// before it, the same tap declared the whole workout finished with three moves
/// untrained. A woman who trains with the phone on the floor logs a move at a
/// time, and the list is where she comes back to.
///
/// The bar at the top carries the five-second undo, identical to R09's — and
/// identical online and offline. There is no spinner, no error and no "will sync
/// later", because the log is already hers either way.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/hand/hand.dart';
import '../domain/train_repository.dart';
import 'train_widgets.dart';

class MoveLoggedView extends StatelessWidget {
  const MoveLoggedView({
    super.key,
    this.onClose,
    this.onPause,
    this.onNextMove,
    this.onFinishHere,
    this.onUndo,
    this.handle,
    this.moves,
    this.loggedCount = 2,
  });

  final VoidCallback? onClose;
  final VoidCallback? onPause;

  /// Back to R07 for the next move. The session continues.
  final VoidCallback? onNextMove;

  /// Ends it early — R10. "Ten minutes counts": what she logged still counts
  /// toward her week.
  final VoidCallback? onFinishHere;

  final VoidCallback? onUndo;
  final LogHandle? handle;

  final List<PlannedMove>? moves;

  /// How many moves are struck off. Everything before this index is done, the
  /// one at it is next.
  final int loggedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final list =
        moves ??
        [
          PlannedMove(
            exerciseId: 'glute_bridge',
            name: l10n.gluteBridge,
            prescriptionLabel: l10n.n312Bodyweight,
            sets: const [],
          ),
          PlannedMove(
            exerciseId: 'goblet_squat',
            name: l10n.gobletSquat,
            prescriptionLabel: l10n.n31212Kg,
            sets: const [],
          ),
          PlannedMove(
            exerciseId: 'step_back_lunge',
            name: l10n.stepBackLunge,
            prescriptionLabel: l10n.n310EachSide,
            sets: const [],
          ),
          PlannedMove(
            exerciseId: 'hip_thrust_hold',
            name: l10n.hipThrustHold,
            prescriptionLabel: l10n.n330Seconds,
            sets: const [],
          ),
          PlannedMove(
            exerciseId: 'dead_bug',
            name: l10n.deadBug,
            prescriptionLabel: l10n.n38EachSide,
            sets: const [],
          ),
        ];

    return AppScaffold(
      appBar: TrainTopBar(
        title: l10n.legsAndGlutes,
        onClose: onClose,
        closeIcon: Icons.arrow_back,
        actions: [
          IconButton(
            onPressed: onPause,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.pause),
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.nextMoveStepBackLunge,
          icon: Icons.play_arrow,
          onPressed: onNextMove,
        ),
        AppButton(
          l10n.finishHere,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: onFinishHere,
        ),
      ],
      children: [
        AppUndoBar(
          // As on R09: the handle carries what was actually logged, and the
          // fallback is only this screen's standalone preview.
          message:
              handle?.describe ?? l10n.moveSavedSetsSets(l10n.gobletSquat, 3),
          undoLabel: l10n.undo,
          onUndo: handle == null
              ? null
              : () {
                  if (handle!.undo()) onUndo?.call();
                },
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Her count, against the moves this workout actually has.
            //
            // This was the fixed `n2Of5MovesDone` — "2 of 5 moves done" — read
            // to a woman three moves into a six-move session, directly above
            // the list that drew all six. Both now come off the same list.
            //
            // Circled where she stands in the list — the one mark here. The
            // session is still running, so there is no tick yet.
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, top: 4),
              child: HandCircled(
                level: HandLevel.crafted,
                width: 1.2,
                color: AppColors.primaryDim,
                child: Text(
                  l10n.countOfTotal(
                    countLabel(loggedCount),
                    countLabel(list.length),
                  ),
                  style: AppText.titleL,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.quietNoEquipmentFloor,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        for (var i = 0; i < list.length; i++)
          MoveRow(
            name: list[i].name,
            detail: list[i].prescriptionLabel,
            done: i < loggedCount,
            current: i == loggedCount,
          ),
      ],
    );
  }
}
