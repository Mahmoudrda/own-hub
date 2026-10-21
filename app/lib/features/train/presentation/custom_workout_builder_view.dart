/// Building a workout of her own: a name, the moves, their order and their
/// load, then "Start now" or "Save".
///
/// Nothing here is a result. Start now opens today's session with these moves
/// on R03's own Start; Save keeps the workout under "My workouts" and, once she
/// is signed in, in her account.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/honest_notice.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/custom_workout.dart';
import '../domain/train_repository.dart';
import 'authored_workout.dart';
import 'move_editor.dart';
import 'train_widgets.dart';

class CustomWorkoutBuilderView extends StatefulWidget {
  const CustomWorkoutBuilderView({
    super.key,
    required this.onPickMoves,
    required this.onSave,
    required this.onStartNow,
    this.initialName = '',
    this.initialMoves = const <PlannedMove>[],
    this.editing = false,
    this.onBack,
    this.undoBus,
  });

  /// Opens the catalogue and answers the moves she added, already prescribed.
  final Future<List<PlannedMove>?> Function() onPickMoves;

  /// Keeps the workout. [name] is what she typed, possibly empty. Answers
  /// false when it could not be kept (she already keeps the most she can), and
  /// the "saved" note is then not shown.
  final bool? Function(String name, List<PlannedMove> moves) onSave;

  final void Function(String name, List<PlannedMove> moves) onStartNow;

  final String initialName;
  final List<PlannedMove> initialMoves;

  /// True when changing a workout she already saved.
  final bool editing;

  final VoidCallback? onBack;
  final LogCommandBus? undoBus;

  @override
  State<CustomWorkoutBuilderView> createState() =>
      _CustomWorkoutBuilderViewState();
}

class _CustomWorkoutBuilderViewState extends State<CustomWorkoutBuilderView> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );
  late List<PlannedMove> _moves = [...widget.initialMoves];
  late final String _startedWith = _signature(widget.initialMoves);
  int? _open;
  final LogCommandBus _ownBus = LogCommandBus();

  LogCommandBus get _bus => widget.undoBus ?? _ownBus;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static String _signature(List<PlannedMove> moves) =>
      moves.map((m) => '${m.exerciseId}:${m.prescriptionLabel}').join('|');

  /// Moves or a name she has changed and not yet kept.
  bool get _dirty =>
      _signature(_moves) != _startedWith ||
      cleanWorkoutName(_name.text) != cleanWorkoutName(widget.initialName);

  /// Back with unsaved work asks first, in the app's own sheet.
  Future<void> _back() async {
    if (!_dirty) {
      _leave();
      return;
    }
    final l10n = AppL10n.of(context);
    final discard = await showAppSheet<bool>(
      context: context,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.leaveWithoutSaving, style: AppText.titleL),
            const SizedBox(height: 4),
            Text(
              l10n.yourChangesToThisWorkoutWillBe,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            AppButton(
              l10n.keepEditing,
              key: const ValueKey('build-keep-editing'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 10),
            AppButton(
              l10n.discardChanges,
              key: const ValueKey('build-discard'),
              variant: AppButtonVariant.outlined,
              height: 48,
              fontSize: 15,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ],
    );
    if (discard == true && mounted) _leave();
  }

  void _leave() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).pop();
    }
  }

  String get _language => Localizations.localeOf(context).languageCode;

  void _edit(int i, CustomMove next) {
    setState(() {
      _moves = [..._moves]
        ..[i] = plannedMoveFromCustom(
          AppL10n.of(context),
          _language,
          next,
          like: _moves[i],
        );
    });
  }

  void _shift(int i, int by) {
    final j = i + by;
    if (j < 0 || j >= _moves.length) return;
    setState(() {
      final next = [..._moves];
      final moved = next.removeAt(i);
      next.insert(j, moved);
      _moves = next;
      _open = j;
    });
  }

  void _remove(int i) {
    final removed = _moves[i];
    setState(() {
      _moves = [..._moves]..removeAt(i);
      _open = null;
    });
    final l10n = AppL10n.of(context);
    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.removedName(removed.name),
        commit: () async {},
      ),
    );
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: l10n.undo,
      onUndo: () {
        if (!mounted) return;
        setState(() {
          final back = [..._moves];
          back.insert(i.clamp(0, back.length), removed);
          _moves = back;
        });
      },
    );
  }

  Future<void> _add() async {
    final added = await widget.onPickMoves();
    if (!mounted || added == null || added.isEmpty) return;
    setState(() {
      _moves = [..._moves, ...added].take(kMaxCustomMoves).toList();
      _open = _moves.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final empty = _moves.isEmpty;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: AppScaffold(
        appBar: AppTopBar(
          title: widget.editing ? l10n.editYourWorkout : l10n.buildYourWorkout,
          onBack: () => unawaited(_back()),
        ),
        footer: [
          AppButton(
            l10n.startNow,
            key: const ValueKey('build-start'),
            icon: Icons.play_arrow,
            onPressed: empty
                ? null
                : () => widget.onStartNow(_name.text, [..._moves]),
          ),
          AppButton(
            l10n.save,
            key: const ValueKey('build-save'),
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: empty
                ? null
                : () {
                    final messenger = ScaffoldMessenger.maybeOf(context);
                    final kept = widget.onSave(_name.text, [..._moves]);
                    // Refused (the cap): the caller has said so and she stays
                    // here. "Saved" is for a save that happened.
                    if (kept == false) return;
                    showHonestNoticeOn(messenger, l10n.savedToYourWorkouts);
                  },
          ),
        ],
        children: [
          AppField(
            key: const ValueKey('build-name'),
            controller: _name,
            label: l10n.workoutName,
            hint: l10n.myWorkout,
            textInputAction: TextInputAction.done,
          ),
          for (var i = 0; i < _moves.length; i++) ...[
            MoveRow(
              name: _moves[i].name,
              detail: _moves[i].prescriptionLabel,
              current: _open == i,
              onTap: () => setState(() => _open = _open == i ? null : i),
            ),
            if (_open == i)
              MoveEditor(
                key: ValueKey('build-editor-$i'),
                move: customMoveOf(_moves[i]),
                showWeight:
                    _moves[i].needsEquipment ||
                    _moves[i].sets.any((PrescribedSet s) => s.weightKg != null),
                onChanged: (next) => _edit(i, next),
                onEarlier: i > 0 ? () => _shift(i, -1) : null,
                onLater: i < _moves.length - 1 ? () => _shift(i, 1) : null,
                onRemove: () => _remove(i),
              ),
          ],
          if (empty)
            Text(
              l10n.addAtLeastOneMove,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          AppButton(
            l10n.addAMove,
            key: const ValueKey('build-add'),
            icon: Icons.add,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: _moves.length >= kMaxCustomMoves ? null : _add,
          ),
          if (_moves.isNotEmpty)
            Text(
              l10n.minutesMinutesMovesMoves(
                countLabel(estimateMinutes(_moves)),
                countLabel(_moves.length),
              ),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}
