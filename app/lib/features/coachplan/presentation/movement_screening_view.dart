/// `K23` — step 2 of the assessment. **`refer` is a real answer.**
///
/// ## Three outcomes, and none of them is a failure
///
/// A screen that offers only pass and fail pushes a coach into pretending she
/// is qualified to rule something out. So the row offers *pass · modify ·
/// refer*, and `refer` is drawn exactly like the other two: a chosen chip, in
/// the same colour, with no warning glyph and no error surface. It suppresses
/// tagged exercises and it never blocks publishing — HANDOFF 14, and the
/// `ScreeningOutcome` enum deliberately has no `error` or `failed` value for a
/// screen to read.
///
/// What *is* marked is an item nobody has answered yet (`P2-ERR-K23`), and it
/// is marked amber because it is the coach's own unfinished work rather than
/// anything about the woman in front of her.
///
/// ## One document, written once, at the end
///
/// This is the step that saves. Everything K21 collected is still in memory
/// until the button below is pressed.
library;

import 'package:flutter/material.dart';

import '../../../domain/safety/screening_item.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/assessment/assessment_form.dart';
import 'coachplan_labels.dart';
import 'coachplan_widgets.dart';

class MovementScreeningView extends StatelessWidget {
  const MovementScreeningView({
    super.key,
    required this.form,
    this.onSetOutcome,
    this.onSave,
    this.onSaveOnly,
    this.onBack,
  });

  final AssessmentForm form;

  /// The coach's answer for one item.
  final void Function(String screeningId, ScreeningOutcome outcome)?
  onSetOutcome;

  /// Writes the whole assessment — both steps, one document.
  final VoidCallback? onSave;

  final VoidCallback? onSaveOnly;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final baseline = form.baseline.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: l10n.assessment, onBack: onBack),
      body: AppScaffold(
        footer: [
          AppButton(
            l10n.saveAssessment,
            height: 54,
            // Every item answered, or there is nothing to save: a partial
            // source of constraints is worse than none.
            onPressed: form.canSave ? onSave : null,
          ),
          AppButton(
            l10n.saveOnly,
            variant: AppButtonVariant.text,
            height: 42,
            fontSize: 15,
            onPressed: form.canSave ? onSaveOnly : null,
          ),
        ],
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.movementScreening, style: AppText.titleM),
                    const SizedBox(height: 3),
                    Text(
                      l10n.step2Of2,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // The step the line beside it prints, jotted in the margin.
              const HandFigure('2', size: 26),
            ],
          ),
          for (final item in form.screening) _itemCard(l10n, item),
          if (baseline.isNotEmpty) ...[
            SectionHead(l10n.baseline),
            AppCard(
              gap: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              children: [
                for (final entry in baseline)
                  LabelledValue(
                    label: screeningItemLabel(l10n, entry.key),
                    value: baselineLabel(entry.value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemCard(AppL10n l10n, ScreeningItem item) {
    final hint = screeningItemHint(l10n, item.id);
    final unanswered = item.outcome == ScreeningOutcome.unset;

    return AppCard(
      key: Key('screening:${item.id}'),
      // Amber names the row nobody has answered. `refer` never reaches this
      // branch — an answered item is an answered item, whichever answer it is.
      variant: unanswered ? AppCardVariant.amber : AppCardVariant.outlined,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      gap: 8,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(screeningItemLabel(l10n, item.id), style: AppText.titleS),
            if (hint != null) ...[
              const SizedBox(height: 2),
              Text(
                hint,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        AppChipRow(
          items: [
            for (final outcome in kOfferedOutcomes)
              screeningOutcomeName(l10n, outcome) ?? outcome.name,
          ],
          selected: <int>{
            for (var i = 0; i < kOfferedOutcomes.length; i++)
              if (kOfferedOutcomes[i] == item.outcome) i,
          },
          onTap: onSetOutcome == null
              ? null
              : (i) => onSetOutcome!(item.id, kOfferedOutcomes[i]),
        ),
      ],
    );
  }
}
