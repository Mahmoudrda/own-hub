/// A finished session, set by set, with a way to correct a figure she typed
/// wrong.
///
/// Fixing a set rewrites it where it was logged and tells the caller, which
/// re-works the session's bests. Points are not touched: the correction goes
/// through no payment path. There is no "are you sure"; the change is made and
/// an Undo bar puts the old figure back.
library;

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../domain/set_history.dart';
import '../domain/train_repository.dart';
import '../domain/weight_label.dart';
import 'move_history_sheet.dart';

const double kEditMaxWeightKg = 300;
const int kEditMaxReps = 100;
const int kEditMaxHoldSeconds = 600;

/// The outcome after a correction, or null when a figure is outside what a
/// set can be: weight 0 to 300 kg in halves, reps 0 to 100, seconds 0 to 600.
///
/// Only the figures the set already has are changed; a bodyweight set stays
/// without a weight, and a hold stays a hold.
SetOutcome? correctedOutcome(
  SetOutcome old, {
  double? weightKg,
  int? reps,
  int? holdSeconds,
}) {
  double? kg = old.weightKg;
  if (old.weightKg != null) {
    if (weightKg == null || weightKg < 0 || weightKg > kEditMaxWeightKg) {
      return null;
    }
    kg = (weightKg * 2).round() / 2;
  }
  int? r = old.reps;
  if (old.reps != null) {
    if (reps == null || reps < 0 || reps > kEditMaxReps) return null;
    r = reps;
  }
  int? hold = old.holdSeconds;
  if (old.holdSeconds != null) {
    if (holdSeconds == null ||
        holdSeconds < 0 ||
        holdSeconds > kEditMaxHoldSeconds) {
      return null;
    }
    hold = holdSeconds;
  }
  return SetOutcome(weightKg: kg, reps: r, holdSeconds: hold);
}

class SessionEditView extends StatefulWidget {
  const SessionEditView({
    super.key,
    required this.sessionId,
    required this.repository,
    required this.nameFor,
    required this.onSessionEdited,
    this.title,
  });

  final String sessionId;
  final InMemoryTrainRepository repository;

  /// The move's name in her language.
  final String Function(String exerciseId) nameFor;

  /// Called after a set is rewritten, and again after Undo. The caller
  /// re-works that session's bests.
  final void Function(String sessionId) onSessionEdited;

  final String? title;

  @override
  State<SessionEditView> createState() => _SessionEditViewState();
}

class _SessionEditViewState extends State<SessionEditView> {
  final LogCommandBus _bus = LogCommandBus();

  @override
  void dispose() {
    _bus.dispose();
    super.dispose();
  }

  Future<void> _write(String exerciseId, LoggedSet set) async {
    await widget.repository.replaceSet(
      sessionId: widget.sessionId,
      exerciseId: exerciseId,
      set: set,
    );
    widget.onSessionEdited(widget.sessionId);
    // Her corrected set and the re-worked bests are saved from this.
    AppChanges.bump();
    if (mounted) setState(() {});
  }

  Future<void> _edit(String exerciseId, LoggedSet old) async {
    final outcome = await showEditSetSheet(
      context,
      old: old.outcome!,
      moveName: widget.nameFor(exerciseId),
    );
    if (outcome == null || !mounted) return;
    final l10n = AppL10n.of(context);
    final updated = old.recording(outcome);
    await _write(exerciseId, updated);
    if (!mounted) return;
    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.setNIsNowSet(
          '${old.prescribed.order}',
          outcomeLabel(l10n, outcome),
        ),
        commit: () async {},
      ),
    );
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: l10n.undo,
      onUndo: () => _write(exerciseId, old),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final session = widget.repository.sessionById(widget.sessionId);
    final moves = session == null
        ? const <({String exerciseId, List<LoggedSet> sets})>[]
        : loggedMovesOf(widget.repository, session);
    return AppScaffold(
      appBar: AppTopBar(
        title: widget.title ?? l10n.workout,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      children: [
        Text(
          l10n.fixingATypoUpdatesYourBestsPoints,
          key: const ValueKey('session-edit-note'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        for (final move in moves) ...[
          Semantics(
            header: true,
            child: Text(widget.nameFor(move.exerciseId), style: AppText.titleS),
          ),
          for (final set in move.sets)
            _SetRow(
              key: ValueKey(
                'edit-row-${move.exerciseId}-${set.prescribed.order}',
              ),
              set: set,
              onEdit: () => _edit(move.exerciseId, set),
            ),
        ],
      ],
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({super.key, required this.set, required this.onEdit});

  final LoggedSet set;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final n = '${set.prescribed.order}';
    final figure = outcomeLabel(l10n, set.outcome!);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Row(
        children: [
          Expanded(
            child: Text('${l10n.setN(n)} · $figure', style: AppText.bodyM),
          ),
          Semantics(
            label: '${l10n.edit} ${l10n.setN(n)}, $figure',
            excludeSemantics: true,
            button: true,
            child: TextButton(
              key: ValueKey('edit-set-${set.prescribed.order}'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: onEdit,
              child: Text(l10n.edit),
            ),
          ),
        ],
      ),
    );
  }
}

/// Asks for the corrected figures. Null when she closes it or changes nothing
/// that is valid.
Future<SetOutcome?> showEditSetSheet(
  BuildContext context, {
  required SetOutcome old,
  required String moveName,
}) {
  return showAppSheet<SetOutcome>(
    context: context,
    children: [_EditSetForm(old: old, moveName: moveName)],
  );
}

class _EditSetForm extends StatefulWidget {
  const _EditSetForm({required this.old, required this.moveName});

  final SetOutcome old;
  final String moveName;

  @override
  State<_EditSetForm> createState() => _EditSetFormState();
}

class _EditSetFormState extends State<_EditSetForm> {
  late final TextEditingController _kg = TextEditingController(
    text: widget.old.weightKg == null ? '' : weightLabel(widget.old.weightKg!),
  );
  late final TextEditingController _reps = TextEditingController(
    text: '${widget.old.reps ?? ''}',
  );
  late final TextEditingController _secs = TextEditingController(
    text: '${widget.old.holdSeconds ?? ''}',
  );
  bool _tried = false;

  @override
  void dispose() {
    _kg.dispose();
    _reps.dispose();
    _secs.dispose();
    super.dispose();
  }

  double? get _kgValue => double.tryParse(_kg.text.trim().replaceAll(',', '.'));
  int? get _repsValue => int.tryParse(_reps.text.trim());
  int? get _secsValue => int.tryParse(_secs.text.trim());

  SetOutcome? get _result => correctedOutcome(
    widget.old,
    weightKg: _kgValue,
    reps: _repsValue,
    holdSeconds: _secsValue,
  );

  void _save() {
    final result = _result;
    if (result == null) {
      setState(() => _tried = true);
      return;
    }
    Navigator.of(context).pop(result);
  }

  Widget _field(
    Key key,
    TextEditingController controller,
    String label,
    String error, {
    required bool bad,
    bool decimal = false,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        errorText: _tried && bad ? error : null,
        constraints: const BoxConstraints(minHeight: 48),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final old = widget.old;
    // Each figure is judged by the same ranges as the whole set.
    final kgBad =
        old.weightKg != null &&
        correctedOutcome(
              SetOutcome(weightKg: old.weightKg),
              weightKg: _kgValue,
            ) ==
            null;
    final repsBad =
        old.reps != null &&
        correctedOutcome(SetOutcome(reps: old.reps), reps: _repsValue) == null;
    final secsBad =
        old.holdSeconds != null &&
        correctedOutcome(
              SetOutcome(holdSeconds: old.holdSeconds),
              holdSeconds: _secsValue,
            ) ==
            null;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.fixThisSet, style: AppText.titleL),
          Text(
            widget.moveName,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (old.weightKg != null) ...[
            _field(
              const ValueKey('edit-weight'),
              _kg,
              l10n.weightKg_4v662,
              l10n.weightMustBe0ToMaxKg(weightLabel(kEditMaxWeightKg)),
              bad: kgBad,
              decimal: true,
            ),
            const SizedBox(height: 12),
          ],
          if (old.reps != null) ...[
            _field(
              const ValueKey('edit-reps'),
              _reps,
              l10n.reps,
              l10n.repsMustBe0ToMax(countLabel(kEditMaxReps)),
              bad: repsBad,
            ),
            const SizedBox(height: 12),
          ],
          if (old.holdSeconds != null) ...[
            _field(
              const ValueKey('edit-seconds'),
              _secs,
              l10n.seconds,
              l10n.secondsMustBe0ToMax(countLabel(kEditMaxHoldSeconds)),
              bad: secsBad,
            ),
            const SizedBox(height: 12),
          ],
          AppButton(
            l10n.save,
            key: const ValueKey('edit-save'),
            onPressed: _save,
          ),
          AppButton(
            l10n.cancel,
            key: const ValueKey('edit-cancel'),
            variant: AppButtonVariant.text,
            height: 48,
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
