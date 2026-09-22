/// `W04` — one day's session, tailored to this client.
///
/// ## The picker is filtered before it is built
///
/// `P0-ASMT-02`: a move her assessment rules out is **absent** from the list,
/// "not shown greyed out and not shown with a warning". This screen renders
/// whatever `moves` it is given, and `ExerciseCandidateFilter` has already run
/// over the candidates — so there is no branch here that could draw a disabled
/// row, because there is no disabled row to draw.
///
/// What the screen does owe her is the truth about the removal, which is
/// [SuppressedMovesNote]: every id taken out is named. Naming them is not an
/// error state.
///
/// ## There is no result field on this screen
///
/// §2.1 and C8. A prescribed move carries sets, a load and reps; what she
/// actually did lives in another library with no constructor that takes one of
/// these. There is nothing here to pre-fill, because the field does not exist.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../domain/plan/plan_draft.dart';
import '../domain/prescription.dart';
import 'coachplan_labels.dart';
import 'coachplan_widgets.dart';

class SessionEditorView extends StatefulWidget {
  const SessionEditorView({
    super.key,
    required this.dayKey,
    this.workout,
    this.suppressedExerciseIds = const <String>{},
    this.carryApproved = false,
    this.onTitleChanged,
    this.onNoteChanged,
    this.onSelectMinutes,
    this.onSelectRest,
    this.onToggleApproved,
    this.onOpenMove,
    this.onAddMove,
    this.onSave,
    this.onBack,
  });

  /// `yyyy-MM-dd`. The day this session belongs to, as the id it is.
  final String dayKey;

  final DraftWorkout? workout;

  /// Named, never silently dropped.
  final Set<String> suppressedExerciseIds;

  /// Whether her easier options travel with this session.
  final bool carryApproved;

  final ValueChanged<String>? onTitleChanged;
  final ValueChanged<String>? onNoteChanged;
  final ValueChanged<int>? onSelectMinutes;
  final ValueChanged<int>? onSelectRest;
  final ValueChanged<bool>? onToggleApproved;

  /// Given the `exerciseId` of the move tapped.
  final ValueChanged<String>? onOpenMove;

  final VoidCallback? onAddMove;
  final VoidCallback? onSave;
  final VoidCallback? onBack;

  @override
  State<SessionEditorView> createState() => _SessionEditorViewState();
}

class _SessionEditorViewState extends State<SessionEditorView> {
  late final TextEditingController _title;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.workout?.title ?? '');
    _note = TextEditingController(text: widget.workout?.note ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final session = widget.workout;
    final moves = session?.moves ?? const <PrescribedMove>[];
    final minutes = session?.minutes;
    final restSec = session?.restBetweenSetsSec;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: widget.dayKey, onBack: widget.onBack),
      body: AppScaffold(
        footer: [
          AppButton(l10n.save, height: 54, onPressed: widget.onSave),
          AppButton(
            l10n.addAnotherExercise,
            variant: AppButtonVariant.text,
            height: 44,
            fontSize: 15,
            onPressed: widget.onAddMove,
          ),
        ],
        children: [
          AppField(
            controller: _title,
            label: l10n.sessionName,
            onChanged: widget.onTitleChanged,
          ),
          for (var i = 0; i < moves.length; i++)
            PlannerRow(
              key: CoachPlanKeys.moveRow(moves[i].exerciseId),
              leading: RowLabel(countLabel(moves[i].order)),
              value: moveSummary(l10n, moves[i]),
              onTap: widget.onOpenMove == null
                  ? null
                  : () => widget.onOpenMove!(moves[i].exerciseId),
            ),
          // Absent above, named here. The screen states what it did rather
          // than quietly handing back a shorter session.
          if (widget.suppressedExerciseIds.isNotEmpty)
            SuppressedMovesNote(exerciseIds: widget.suppressedExerciseIds),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            gap: 8,
            children: [
              SectionHead(l10n.minutes),
              // The options G14 hard-bounds. Rendered as the numbers they
              // are: the dictionary has no "{n} min" form, so a unit is not
              // stated rather than stated wrongly.
              AppChipRow(
                items: [
                  for (final option in kSessionMinuteOptions)
                    countLabel(option),
                ],
                selected: minutes == null
                    ? const <int>{}
                    : <int>{
                        for (var i = 0; i < kSessionMinuteOptions.length; i++)
                          if (kSessionMinuteOptions[i] == minutes) i,
                      },
                onTap: widget.onSelectMinutes == null
                    ? null
                    : (i) => widget.onSelectMinutes!(kSessionMinuteOptions[i]),
              ),
            ],
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            gap: 8,
            children: [
              SectionHead(l10n.restBetweenSets),
              AppChipRow(
                items: [
                  for (final option in kRestBetweenSetsOptions)
                    countLabel(option),
                ],
                selected: restSec == null
                    ? const <int>{}
                    : <int>{
                        for (var i = 0; i < kRestBetweenSetsOptions.length; i++)
                          if (kRestBetweenSetsOptions[i] == restSec) i,
                      },
                onTap: widget.onSelectRest == null
                    ? null
                    : (i) => widget.onSelectRest!(kRestBetweenSetsOptions[i]),
              ),
            ],
          ),
          AppField(
            controller: _note,
            label: l10n.noteForHer,
            onChanged: widget.onNoteChanged,
          ),
          // Attached here, which is what lets her swap mid-session without
          // waiting for a reply.
          AppCard(
            variant: AppCardVariant.sage,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.addAnEasierOption, style: AppText.titleM),
                  ),
                  const SizedBox(width: 12),
                  AppToggle(
                    value: widget.carryApproved,
                    semanticLabel: l10n.addAnEasierOption,
                    onChanged: widget.onToggleApproved,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
