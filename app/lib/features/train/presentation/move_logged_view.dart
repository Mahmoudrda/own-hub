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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/hand/hand.dart';
import '../domain/train_repository.dart';
import 'set_labels.dart';
import 'train_widgets.dart';

/// How long "Finish now" waits for the second tap before it stands down.
const Duration kFinishHereArmed = Duration(seconds: 4);

class MoveLoggedView extends StatefulWidget {
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
    this.title,
    this.sets,
    this.editableSets,
    this.onEditSet,
  });

  /// The sets she logged for the move at an index, read once anything still
  /// in its undo window has been written. Null leaves the rows untappable.
  final Future<List<LoggedSet>> Function(int moveIndex)? editableSets;

  /// Opens R08 on one logged set, to change it.
  final void Function(int moveIndex, LoggedSet set)? onEditSet;

  /// The session's own name. Null falls back to the bundled session's, which
  /// is the only one this screen was ever drawn for.
  final String? title;

  /// Sets of today's session behind her, for the bar under the title.
  final ({int done, int total})? sets;

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

  /// How many **moves** are struck off. Everything before this index is done,
  /// the one at it is next.
  ///
  /// The router used to pass `loggedSetCount` here — a count of sets, rendered
  /// as moves — so a woman who had logged two moves of three sets each read
  /// "6 of 5" above a list of five, with every row struck through and no row
  /// marked as next.
  final int loggedCount;

  @override
  State<MoveLoggedView> createState() => _MoveLoggedViewState();
}

class _MoveLoggedViewState extends State<MoveLoggedView> {
  /// True for [kFinishHereArmed] after the first tap on "Finish here".
  bool _finishArmed = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  /// Ending the session cannot be taken back, and the button sits under the
  /// most-tapped one on the page. So the first tap says what it will do and
  /// how much is left, in place, and only a second tap ends it.
  void _finishHere(int movesLeft) {
    final finish = widget.onFinishHere;
    if (finish == null) return;
    if (movesLeft <= 0 || _finishArmed) {
      _disarm?.cancel();
      setState(() => _finishArmed = false);
      finish();
      return;
    }
    setState(() => _finishArmed = true);
    _disarm?.cancel();
    _disarm = Timer(kFinishHereArmed, () {
      if (mounted) setState(() => _finishArmed = false);
    });
  }

  Future<void> _edit(int index) async {
    final read = widget.editableSets;
    final onEdit = widget.onEditSet;
    if (read == null || onEdit == null) return;
    final logged = await read(index);
    if (!mounted || logged.isEmpty) return;
    if (logged.length == 1) {
      onEdit(index, logged.single);
      return;
    }
    final l10n = AppL10n.of(context);
    final chosen = await showAppSheet<LoggedSet>(
      context: context,
      gap: 8,
      children: [
        Text(l10n.whichSet, style: AppText.titleL),
        for (final set in logged)
          Builder(
            builder: (sheet) => AppListItem(
              title: setSavedLabel(
                l10n,
                setNumber: set.prescribed.order,
                weightKg: set.outcome?.weightKg,
                reps: set.outcome?.reps,
                holdSeconds: set.outcome?.holdSeconds,
              ),
              trailing: const Icon(
                Icons.edit_outlined,
                size: 20,
                color: AppColors.onSurfaceVariant,
              ),
              onTap: () => Navigator.of(sheet).pop(set),
            ),
          ),
      ],
    );
    if (chosen == null || !mounted) return;
    onEdit(index, chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final moves = widget.moves;
    final loggedCount = widget.loggedCount;
    final handle = widget.handle;

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

    // The move she goes back to, or null when that was the last one.
    final nextMove = (loggedCount >= 0 && loggedCount < list.length)
        ? list[loggedCount]
        : null;

    final movesLeft = list.length - loggedCount;
    final canEdit = widget.editableSets != null && widget.onEditSet != null;

    return AppScaffold(
      appBar: TrainTopBar(
        title: widget.title ?? l10n.legsAndGlutes,
        onClose: widget.onClose,
        closeIcon: Icons.arrow_back,
        sets: widget.sets,
        actions: [
          if (widget.onPause != null)
            IconButton(
              onPressed: widget.onPause,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              tooltip: l10n.pause,
              icon: const Icon(Icons.pause),
            ),
        ],
      ),
      footer: [
        AppButton(
          // The move that is actually next, named off the same list the rows
          // below are drawn from. It was the fixed `nextMoveStepBackLunge` —
          // "Next move · step-back lunge" — which it said with a goblet squat
          // coming up, and said again on the last move when nothing was next.
          nextMove == null
              ? l10n.finishWorkout
              : l10n.nextMoveMove(nextMove.name),
          icon: Icons.play_arrow,
          onPressed: widget.onNextMove,
        ),
        AppButton(
          _finishArmed
              ? l10n.finishNowCountMovesLeft(countLabel(movesLeft))
              : l10n.finishHere,
          key: const ValueKey('r13-finish-here'),
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: widget.onFinishHere == null
              ? null
              : () => _finishHere(movesLeft),
        ),
      ],
      children: [
        AppLiveUndoBar(
          // As on R09: the handle carries what was actually logged, and the
          // fallback is only this screen's standalone preview. Undo is drawn
          // only while the window is open.
          handle: handle,
          message:
              handle?.describe ?? l10n.moveSavedSetsSets(l10n.gobletSquat, 3),
          undoLabel: l10n.undo,
          onUndo: widget.onUndo,
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
            // A move she logged opens its sets to change one, whenever she
            // likes: the five seconds are for Undo, not for corrections.
            onTap: canEdit && i < loggedCount ? () => _edit(i) : null,
          ),
        if (canEdit && loggedCount > 0)
          Text(
            l10n.tapAMoveYouLoggedToChange,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }
}
