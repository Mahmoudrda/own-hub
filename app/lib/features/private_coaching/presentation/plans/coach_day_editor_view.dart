/// One day of a coach's plan: its name, its moves with sets and reps (or a
/// hold), the order, a move's clip, and more moves from the catalogue.
///
/// It reads and writes the editor's own [CoachPlanEditState], never her
/// personal plan.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app_state/app_changes.dart';
import '../../../../domain/format/number_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_field.dart';
import '../../../../ui/app_scaffold.dart';
import '../../../train/data/exercise_media_store.dart';
import '../../../train/domain/custom_workout.dart';
import '../../../train/domain/exercise_library.dart';
import '../../../train/domain/my_plan.dart';
import '../../../train/domain/workout_library.dart' show AuthoredMove;
import '../../../train/presentation/exercise_clip_player.dart';
import '../../../train/presentation/exercise_demo_view.dart';
import 'coach_plan_logic.dart';

class CoachDayEditorView extends StatefulWidget {
  const CoachDayEditorView({
    super.key,
    required this.state,
    required this.dayIndex,
    required this.pickExercises,
    this.exerciseFor,
    this.media = const NoExerciseMedia(),
    this.players,
    this.onBack,
  });

  final CoachPlanEditState state;
  final int dayIndex;

  /// Opens the catalogue and answers the moves ticked, or null.
  final Future<List<LibraryExercise>?> Function() pickExercises;

  /// The library's row for a move id, for its clip.
  final LibraryExercise? Function(String id)? exerciseFor;
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory? players;
  final VoidCallback? onBack;

  @override
  State<CoachDayEditorView> createState() => _CoachDayEditorViewState();
}

class _CoachDayEditorViewState extends State<CoachDayEditorView> {
  late final TextEditingController _name;

  MyPlan get _plan => widget.state.current ?? const MyPlan.blank();

  @override
  void initState() {
    super.initState();
    final i = widget.dayIndex;
    _name = TextEditingController(
      text: i < _plan.days.length
          ? _plan.days[i].session.titleEn.isEmpty
                ? _plan.days[i].session.titleAr
                : _plan.days[i].session.titleEn
          : '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _back() {
    final back = widget.onBack;
    if (back != null) {
      back();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _save(MyPlan next) => widget.state.save(next);

  Future<void> _add() async {
    final picked = await widget.pickExercises();
    if (!mounted || picked == null || picked.isEmpty) return;
    _save(addMoves(_plan, widget.dayIndex, picked));
  }

  void _watch(String id) {
    final e = widget.exerciseFor?.call(id);
    if (e == null) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (route) => ExerciseDemoView(
            exercise: e,
            media: widget.media,
            players: widget.players,
            onClose: () => Navigator.of(route).maybePop(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return ListenableBuilder(
      listenable: AppChanges.instance,
      builder: (context, _) {
        final plan = _plan;
        final i = widget.dayIndex;
        if (i >= plan.days.length) {
          return AppScaffold(
            appBar: AppTopBar(title: l10n.edit, onBack: _back),
            children: const [],
          );
        }
        final session = plan.days[i].session;
        return AppScaffold(
          appBar: AppTopBar(title: session.title(lang), onBack: _back),
          footer: [
            AppButton(
              l10n.addMoves,
              key: const ValueKey('day-add-moves'),
              icon: Icons.add,
              onPressed: session.moves.length >= kMaxCustomMoves ? null : _add,
            ),
          ],
          children: [
            AppField(
              key: const ValueKey('day-name'),
              controller: _name,
              label: l10n.dayName,
              inputFormatters: [
                LengthLimitingTextInputFormatter(kMaxCustomNameLength),
              ],
              onChanged: (v) => _save(renameDay(_plan, i, v)),
            ),
            for (var m = 0; m < session.moves.length; m++)
              _MoveCard(
                key: ValueKey('day-move-$m'),
                move: session.moves[m],
                index: m,
                count: session.moves.length,
                language: lang,
                canWatch:
                    widget.exerciseFor?.call(session.moves[m].exerciseId) !=
                    null,
                onWatch: () => _watch(session.moves[m].exerciseId),
                onChange: ({sets, reps, hold}) => _save(
                  changeMove(
                    _plan,
                    i,
                    m,
                    sets: sets,
                    reps: reps,
                    holdSeconds: hold,
                  ),
                ),
                onShift: (to) => _save(shiftMove(_plan, i, m, to)),
                onRemove: () => _save(removeMove(_plan, i, m)),
              ),
          ],
        );
      },
    );
  }
}

class _MoveCard extends StatelessWidget {
  const _MoveCard({
    super.key,
    required this.move,
    required this.index,
    required this.count,
    required this.language,
    required this.canWatch,
    required this.onWatch,
    required this.onChange,
    required this.onShift,
    required this.onRemove,
  });

  final AuthoredMove move;
  final int index;
  final int count;
  final String language;
  final bool canWatch;
  final VoidCallback onWatch;
  final void Function({int? sets, int? reps, int? hold}) onChange;
  final ValueChanged<int> onShift;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final name = language == 'ar' && move.nameAr.isNotEmpty
        ? move.nameAr
        : move.nameEn;
    final timed = move.holdSeconds != null;
    return AppCard(
      variant: AppCardVariant.outlined,
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      gap: 6,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(name, style: AppText.titleM),
              ),
            ),
            if (canWatch)
              IconButton(
                key: ValueKey('move-watch-$index'),
                tooltip: l10n.watchTheClip,
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                onPressed: onWatch,
                icon: const Icon(Icons.play_circle_outline, size: 24),
              ),
          ],
        ),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Stepper(
              keyPrefix: 'move-sets-$index',
              label: l10n.sets,
              value: countLabel(move.sets),
              onMinus: move.sets <= kMinSets
                  ? null
                  : () => onChange(sets: move.sets - 1),
              onPlus: move.sets >= kMaxSets
                  ? null
                  : () => onChange(sets: move.sets + 1),
            ),
            if (timed)
              _Stepper(
                keyPrefix: 'move-hold-$index',
                label: l10n.holdInSeconds,
                value: countLabel(move.holdSeconds ?? 0),
                onMinus: (move.holdSeconds ?? 0) <= kMinHoldSeconds
                    ? null
                    : () => onChange(
                        hold: (move.holdSeconds ?? 30) - kHoldStepSeconds,
                      ),
                onPlus: (move.holdSeconds ?? 0) >= kMaxHoldSeconds
                    ? null
                    : () => onChange(
                        hold: (move.holdSeconds ?? 30) + kHoldStepSeconds,
                      ),
              )
            else
              _Stepper(
                keyPrefix: 'move-reps-$index',
                label: l10n.reps,
                value: countLabel(move.reps ?? 0),
                onMinus: (move.reps ?? 0) <= kMinReps
                    ? null
                    : () => onChange(reps: (move.reps ?? 10) - 1),
                onPlus: (move.reps ?? 0) >= kMaxReps
                    ? null
                    : () => onChange(reps: (move.reps ?? 10) + 1),
              ),
          ],
        ),
        Row(
          children: [
            IconButton(
              key: ValueKey('move-up-$index'),
              tooltip: l10n.moveEarlier,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: index == 0 ? null : () => onShift(index - 1),
              icon: const Icon(Icons.arrow_upward, size: 22),
            ),
            IconButton(
              key: ValueKey('move-down-$index'),
              tooltip: l10n.moveLater,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: index >= count - 1 ? null : () => onShift(index + 1),
              icon: const Icon(Icons.arrow_downward, size: 22),
            ),
            const Spacer(),
            IconButton(
              key: ValueKey('move-remove-$index'),
              tooltip: l10n.remove,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: count < 2 ? null : onRemove,
              icon: const Icon(Icons.delete_outline, size: 22),
            ),
          ],
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.keyPrefix,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });

  final String keyPrefix;
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$label $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              label,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
          IconButton(
            key: ValueKey('$keyPrefix-minus'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onMinus,
            icon: const Icon(Icons.remove, size: 22),
          ),
          ExcludeSemantics(child: Text(value, style: AppText.titleM)),
          IconButton(
            key: ValueKey('$keyPrefix-plus'),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: onPlus,
            icon: const Icon(Icons.add, size: 22),
          ),
        ],
      ),
    );
  }
}
