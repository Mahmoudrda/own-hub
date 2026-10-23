/// "Your training": her split, her level and her goal, in one sheet.
///
/// Three rows of chips and a line saying what the plan will become, so a change
/// of split, level or goal on Home is one visit instead of a walk back through
/// setup. The split is 3, 4 or 5 days a week; the level pitches the same split
/// harder or easier; the goal only drives her food targets. The sheet changes
/// nothing itself: Apply hands the three answers to its callback, and the
/// caller writes them (the same merge setup makes), clears the tier she was
/// viewing and rebuilds Home.
///
/// The preview is the plan her answers would select, worked out the way Home
/// does it, so what it promises is what she gets.
library;

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../app_state/chosen_programme.dart';
import '../../../app_state/workout_library_state.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_sheet.dart';
import '../../onboarding/domain/intake.dart';
import '../../onboarding/domain/intake_repository.dart';
import '../../onboarding/domain/starting_program.dart';
import '../../onboarding/presentation/programme_cards.dart' show programCopyFor;
import '../domain/viewed_tier.dart';

/// The three answers the sheet gives back: her split's days a week, her goal
/// and her level.
typedef SplitChoice = void Function(
  int days,
  TrainingGoal goal,
  TrainingLevel level,
);

/// The older shape of the callback, from when the sheet asked where she trains.
/// The place is handed back as it was; the split's days are not carried. Use
/// [SplitChoice].
typedef TrainingChoice = void Function(
  TrainingPlace place,
  TrainingGoal goal,
  TrainingLevel level,
);

/// Writes what the sheet chose, the way setup does, and has Home and Train
/// follow it.
///
/// One merge of the fields that changed. The tier she was viewing and the plan
/// she picked earlier are let go, because a plan she picked at another split
/// would otherwise still "fit" and keep being followed, and a session opened
/// from the old plan no longer applies. A custom schedule of weekdays is let go
/// only when its count no longer matches the new days.
Future<void> applyTrainingChoice(
  IntakeRepository repository, {
  int? days,
  TrainingPlace? place,
  required TrainingGoal goal,
  required TrainingLevel level,
}) async {
  final now = repository.read();
  final moved = days != null && days != now.days;
  await repository.merge(
    place: place,
    goal: goal,
    level: level,
    days: moved ? days : null,
    weekdays: moved ? const {} : null,
  );
  ViewedTier.clear();
  ChosenProgramme.reset();
  WorkoutLibraryState.instance
    ..openedSlot = null
    ..chosenRowId = null;
  AppChanges.bump();
}

/// Opens the sheet over the current screen. Give [onApplySplit]; [onApply] is
/// the older callback and only hears her goal and level.
Future<void> showTrainingQuickSheet(
  BuildContext context, {
  required Intake current,
  TrainingChoice? onApply,
  SplitChoice? onApplySplit,
}) {
  return showAppSheet<void>(
    context: context,
    children: [
      Builder(
        builder: (sheetContext) => TrainingQuickSheet(
          current: current,
          onApply: onApply,
          onApplySplit: onApplySplit,
          onClose: () => Navigator.of(sheetContext).maybePop(),
        ),
      ),
    ],
  );
}

String _levelLabel(AppL10n l10n, TrainingLevel level) => switch (level) {
  TrainingLevel.beginner => l10n.beginner,
  TrainingLevel.intermediate => l10n.intermediate,
  TrainingLevel.advanced => l10n.advanced,
};

String _goalLabel(AppL10n l10n, TrainingGoal goal) => switch (goal) {
  TrainingGoal.stronger => l10n.getStronger,
  TrainingGoal.buildMuscle => l10n.buildMuscle,
  TrainingGoal.feelBetter => l10n.feelGoodAndMove,
  TrainingGoal.loseSteadily => l10n.loseSteadily,
  TrainingGoal.backIntoIt => l10n.getBackIntoIt,
};

/// Her split and level in one line, for the "Your training" row on Home:
/// "Split · 4 days · Intermediate".
String trainingSummaryLine(AppL10n l10n, Intake intake) =>
    '${l10n.split} · ${l10n.nDays('${splitDaysFor(intake.days)}')} · '
    '${_levelLabel(l10n, intake.level)}';

class TrainingQuickSheet extends StatefulWidget {
  const TrainingQuickSheet({
    super.key,
    required this.current,
    this.onApply,
    this.onApplySplit,
    this.onClose,
    this.catalogue,
  });

  /// Her answers now. The chips open on these.
  final Intake current;

  /// Older callback: called with her place (unchanged), goal and level when she
  /// taps Apply and [onApplySplit] is not given.
  final TrainingChoice? onApply;

  /// Called with the split's days, her goal and her level when she taps Apply.
  final SplitChoice? onApplySplit;

  /// Called after Apply and on Cancel. The caller closes the sheet.
  final VoidCallback? onClose;

  /// The programmes the preview chooses from. The bundled catalogue when null.
  final List<StartingProgram>? catalogue;

  /// The goals in the order the chips show them.
  static const List<TrainingGoal> goalOrder = [
    TrainingGoal.stronger,
    TrainingGoal.buildMuscle,
    TrainingGoal.feelBetter,
    TrainingGoal.loseSteadily,
    TrainingGoal.backIntoIt,
  ];

  @override
  State<TrainingQuickSheet> createState() => _TrainingQuickSheetState();
}

class _TrainingQuickSheetState extends State<TrainingQuickSheet> {
  late int _days;
  late TrainingGoal _goal;
  late TrainingLevel _level;

  @override
  void initState() {
    super.initState();
    // A custom week of another size sits on the split nearest it.
    _days = splitDaysFor(widget.current.days);
    _goal = widget.current.goal;
    _level = widget.current.level;
  }

  bool get _changed =>
      _days != splitDaysFor(widget.current.days) ||
      _goal != widget.current.goal ||
      _level != widget.current.level;

  void _apply() {
    final onSplit = widget.onApplySplit;
    if (onSplit != null) {
      onSplit(_days, _goal, _level);
    } else {
      widget.onApply?.call(widget.current.place, _goal, _level);
    }
    widget.onClose?.call();
  }

  /// One line on what she will be given.
  String? _preview(AppL10n l10n) {
    if (!_changed) return l10n.samePlanAsNow;
    final pending = widget.current.copyWith(
      days: _days,
      goal: _goal,
      level: _level,
    );
    final chosen = selectStartingProgram(pending, catalogue: widget.catalogue);
    if (chosen == null) return null;
    final copy = programCopyFor(
      l10n,
      chosen.programId,
      pending,
      programme: chosen,
    );
    if (copy == null) return null;
    return l10n.yourPlanWillBePlan(
      '${copy.title} · ${copy.minutes} · ${_levelLabel(l10n, _level)}',
    );
  }

  Widget _row(String label, Widget chips) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppText.titleS),
        const SizedBox(height: 8),
        chips,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final preview = _preview(l10n);
    const days = kSplitDays;
    const goals = TrainingQuickSheet.goalOrder;
    const levels = TrainingLevel.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(l10n.yourTraining, style: AppText.titleL),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.changeTheseAndYourPlanChangesWith,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        _row(
          l10n.split,
          AppChipRow(
            key: const ValueKey('quick-split'),
            items: [for (final d in days) l10n.nDays('$d')],
            selected: {days.indexOf(_days)},
            height: 48,
            onTap: (i) => setState(() => _days = days[i]),
          ),
        ),
        _row(
          l10n.level,
          AppChipRow(
            key: const ValueKey('quick-level'),
            items: [for (final l in levels) _levelLabel(l10n, l)],
            selected: {levels.indexOf(_level)},
            height: 48,
            onTap: (i) => setState(() => _level = levels[i]),
          ),
        ),
        _row(
          l10n.goal,
          AppChipRow(
            key: const ValueKey('quick-goal'),
            items: [for (final g in goals) _goalLabel(l10n, g)],
            selected: {goals.indexOf(_goal)},
            grow: false,
            height: 48,
            onTap: (i) => setState(() => _goal = goals[i]),
          ),
        ),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Semantics(
              liveRegion: true,
              child: Text(
                preview,
                key: const ValueKey('quick-preview'),
                style: AppText.body,
              ),
            ),
          ),
        AppButton(
          l10n.apply,
          key: const ValueKey('quick-apply'),
          onPressed: _changed ? _apply : null,
        ),
        const SizedBox(height: 4),
        AppButton(
          l10n.cancel,
          key: const ValueKey('quick-cancel'),
          variant: AppButtonVariant.text,
          onPressed: widget.onClose,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
