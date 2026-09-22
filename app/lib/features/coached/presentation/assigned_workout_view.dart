/// G06 — the session her coach assigned.
///
/// Matches `6-v2/src/screens-coached.mjs` → `G06`. Its design note: *"Every set
/// shows what Sara prescribed next to what she actually did, and untouched sets
/// are never pre-filled or counted."*
///
/// ## The column that is empty on purpose
///
/// [PrescribedActualRow] draws the prescription and the outcome side by side.
/// An unlogged set shows an em dash in grey — not the prescribed number in
/// grey, and not a zero. They are different fields in the domain
/// (`PrescribedSet` and `SetOutcome`) and they are different columns here, so
/// there is no widget that could copy one into the other by accident.
///
/// ## Three ways out, none of which needs a reply
///
/// Swap, ask, skip — and **finishing early is always available** from the
/// timer screen next door. `StopSessionUseCase`'s client-side equivalent,
/// `AssignedSessionController.stop`, takes no coach and sends no message, so
/// "coach approval is never required to stop" is true of the code rather than
/// of the copy.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_big_button.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import 'coached_widgets.dart';

/// One set as this screen renders it.
@immutable
class SetLine {
  const SetLine({
    required this.label,
    required this.prescribed,
    this.actual,
    this.current = false,
  });

  /// "Set 2".
  final String label;

  /// "12 kg × 12".
  final String prescribed;

  /// What she did, or **null when she has not logged it**.
  final String? actual;

  final bool current;

  bool get done => actual != null;
}

class AssignedWorkoutView extends StatelessWidget {
  const AssignedWorkoutView({
    super.key,
    this.onClose,
    this.onPause,
    this.onCompleteSet,
    this.onSwap,
    this.onAsk,
    this.onSkip,
    this.moveTitle,
    this.moveName,
    this.coachNote,
    this.sets,
    this.completeLabel,
  });

  final VoidCallback? onClose;
  final VoidCallback? onPause;

  /// Logs the current set and starts the rest timer. One tap, then undo —
  /// never a confirmation.
  final VoidCallback? onCompleteSet;

  final VoidCallback? onSwap;
  final VoidCallback? onAsk;
  final VoidCallback? onSkip;

  /// "Move 2 of 5".
  final String? moveTitle;

  /// "Goblet squat".
  final String? moveName;

  /// Her coach's words about this move. **Null when the coach wrote none** —
  /// the card is absent rather than empty, because an empty quotation mark
  /// implies she said something.
  final String? coachNote;

  final List<SetLine>? sets;

  /// The footer action. Defaults to the set-free "Log one set".
  final String? completeLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // No sets means no rows. The prototype filled this with "12 kg × 12" three
    // times over; a woman whose coach prescribed something else would have
    // read another client's numbers as her own prescription. An empty column
    // is the honest rendering of a session we have not been given.
    final lines = sets ?? const <SetLine>[];
    // Same for the note. The card is absent rather than carrying the mockup's
    // sentence, exactly as [coachNote] already documents.
    final note = coachNote;

    return AppScaffold(
      appBar: AppTopBar(
        title: moveTitle ?? l10n.move2Of5,
        onBack: onClose,
        leadingIcon: Icons.close,
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
        AppBigButton(
          // "Complete set 2" names a set only the mockup has. Without a set
          // list there is no set two, so the button names the action.
          completeLabel ?? l10n.logOneSet,
          subtitle: l10n.restTimerStartsItself,
          onPressed: onCompleteSet,
        ),
      ],
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(moveName ?? l10n.gobletSquat, style: AppText.headline),
                  const SizedBox(height: 2),
                  Text(
                    l10n.fromCoachSara,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 12),
              AppPill(l10n.herNote, icon: Icons.info_outline),
            ],
          ],
        ),
        if (note != null)
          AppCard(
            variant: AppCardVariant.sage,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                note,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PrescribedActualRow(
              label: line.label,
              prescribed: line.prescribed,
              actual: line.actual,
              prescribedLabel: l10n.prescribed,
              actualLabel: l10n.youDid,
              notYetLabel: l10n.notYet,
              done: line.done,
              current: line.current,
            ),
          ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.swapExercise,
                variant: AppButtonVariant.outlined,
                height: 44,
                fontSize: 14,
                onPressed: onSwap,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: AppButton(
                l10n.askAboutThis,
                variant: AppButtonVariant.outlined,
                height: 44,
                fontSize: 14,
                onPressed: onAsk,
              ),
            ),
            const SizedBox(width: 6),
            // Skipping needs nobody's approval, so it sits here rather than
            // behind the "ask" button.
            Expanded(
              child: AppButton(
                l10n.skip,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 14,
                onPressed: onSkip,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
