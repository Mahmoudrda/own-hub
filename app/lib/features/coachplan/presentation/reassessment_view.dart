/// `K22` — a re-assessment. It records, and it **ends at draft**.
///
/// ## Saving this publishes nothing
///
/// HANDOFF 15 and `P1-RULE-21`. "Save and adjust her plan" is a **navigation**
/// to W03: the published version and every assignment are untouched, the
/// draft's status is still `draft`, and no callable was invoked. The domain
/// makes that structural — `PlanRevisionSuggestion.publishes` is a getter that
/// returns false and there is no field behind it — and this screen has no
/// publish control of any kind.
///
/// ## A referral is shown prominently, and never as an error
///
/// HANDOFF 14. It survives silence: a `refer` the new assessment simply does
/// not mention is carried forward, still suppressing, and can only be ended by
/// an explicit action carrying a reason. The card below is **amber**, the
/// colour this product uses for a caution that is not a failure. It is never
/// the error surface, it carries no failure glyph, and it blocks nothing.
library;

import 'package:flutter/material.dart';

import '../../../domain/safety/screening_item.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/assessment/assessment_form.dart';
import '../domain/assessment/assessment_record.dart';
import 'coachplan_labels.dart';
import 'coachplan_widgets.dart';

class ReassessmentView extends StatelessWidget {
  const ReassessmentView({
    super.key,
    required this.previous,
    required this.form,
    this.activeReferrals = const <ScreeningItem>[],
    this.onSaveAndAdjust,
    this.onSaveOnly,
    this.onOpenHistory,
    this.onBack,
  });

  /// The parent in the chain. Its baselines are the "at intake" column.
  final AssessmentRecord previous;

  /// Pre-filled from [previous]. Nothing is overwritten until she saves.
  final AssessmentForm form;

  /// Still suppressing. Rendered prominently, never as an error.
  final List<ScreeningItem> activeReferrals;

  /// Opens `W03`. Publishes nothing — see the library note.
  final VoidCallback? onSaveAndAdjust;

  final VoidCallback? onSaveOnly;
  final VoidCallback? onOpenHistory;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final measures = <String>{
      ...previous.baseline.keys,
      ...form.baseline.keys,
    }.toList()..sort();

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(
        title: l10n.assessment,
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.baseline,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.history),
            onPressed: onOpenHistory,
          ),
        ],
      ),
      body: AppScaffold(
        footer: [
          AppButton(
            l10n.saveAndAdjustHerPlan,
            height: 54,
            onPressed: onSaveAndAdjust,
          ),
          AppButton(
            l10n.saveOnly,
            variant: AppButtonVariant.text,
            height: 42,
            fontSize: 15,
            onPressed: onSaveOnly,
          ),
        ],
        children: [
          AppCard(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Text(l10n.filledInFromHerIntakeChangeWhat, style: AppText.bodyM),
            ],
          ),
          SectionHead(l10n.baseline),
          for (final id in measures)
            _CompareRow(
              key: Key('baseline:$id'),
              label: screeningItemLabel(l10n, id),
              before: previous.baseline[id],
              after: form.baseline[id],
            ),
          // Prominent, and amber. See the library note on what this is not.
          if (activeReferrals.isNotEmpty)
            AppCard(
              key: CoachPlanKeys.referralCard,
              variant: AppCardVariant.amber,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              gap: 8,
              children: [
                for (final item in activeReferrals)
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          screeningItemLabel(l10n, item.id),
                          style: AppText.titleM,
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppPill(
                        l10n.refer,
                        background: AppColors.surfaceLowest,
                        foreground: AppColors.amber,
                      ),
                    ],
                  ),
              ],
            ),
          AppSageNote(l10n.aReAssessmentNeverEditsAPublished),
        ],
      ),
    );
  }
}

/// One measure, at intake and now.
///
/// Neither column is a result of a prescribed value — a baseline is something
/// measured in a room with her coach, and the two never share a field.
class _CompareRow extends StatelessWidget {
  const _CompareRow({super.key, required this.label, this.before, this.after});

  final String label;
  final BaselineMeasure? before;
  final BaselineMeasure? after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final then = before;
    final nowValue = after;

    final intake = _Column(
      caption: l10n.atIntake,
      value: then == null ? '' : baselineLabel(then),
      colour: AppColors.onSurface,
    );
    final now = _Column(
      caption: l10n.now_65hr,
      value: nowValue == null ? '' : baselineLabel(nowValue),
      colour: AppColors.tertiary,
    );
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    // A line of a ruled table rather than a box per measure: then and now
    // read across, and a pencil rule closes each row.
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: stacked
                // At a large text size the measure's name sits above its two
                // figures; across one line they are wider than the phone.
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(label, style: AppText.titleS),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(child: intake),
                          const SizedBox(width: 12),
                          Flexible(child: now),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: Text(label, style: AppText.titleS)),
                      const SizedBox(width: 10),
                      intake,
                      const SizedBox(width: 12),
                      now,
                    ],
                  ),
          ),
        ),
        HandRule(seed: handSeed(['baseline-row', label]), height: 4),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.caption,
    required this.value,
    required this.colour,
  });

  final String caption;
  final String value;
  final Color colour;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        caption,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
      Text(value, style: AppText.titleS.copyWith(color: colour)),
    ],
  );
}
