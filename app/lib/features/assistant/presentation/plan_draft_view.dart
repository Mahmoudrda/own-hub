/// `K26` — the plan draft, and the one thing it cannot do.
///
/// A draft is **held**. There is no control on this screen that publishes, no
/// state that means published, and no way to reach one: the coach's two choices
/// are to open it in her own planner — which is where G2's write happens, after
/// her tap — or to discard it. Both are callbacks out of this widget.
///
/// ## Every figure here is counted, not stated
///
/// The day count, the session count and the rest count come from
/// [PlanDraftScreen], which derives them from the structure of the draft.
/// `assistant_wire.dart` has no numeric field at all, so the model never stated
/// any of them and there is no arrangement in which it could. That is why they
/// are rendered as bare counts through `countLabel` rather than withheld:
/// withholding is for figures nobody authored, and these are facts about the
/// list on screen.
///
/// ## Three lines the design has that this screen does not
///
///  * **"Her avoid list was applied first: deep knee bends and high impact."**
///    True of the mockup's client. This screen is handed a draft, not an
///    assessment, so it cannot know which constraints were applied — and a
///    safety claim that is decorative is worse than none. `screenExercises`
///    is where the guarantee actually lives.
///  * **"Split · Upper / lower · 4 days"** and **"Assessment · Knee — no deep
///    bends"**: same reason.
///  * **"Week 1"** as a section heading. `week1` states a figure with no
///    placeholder form and is rendered nowhere in `lib/` today;
///    `baked_in_samples_test.dart` counts exactly that. The first week is shown
///    without being labelled, which loses nothing: the day numbers say it.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_split_row.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import 'assistant_widgets.dart';
import 'draft_view_model.dart';

class PlanDraftView extends StatelessWidget {
  const PlanDraftView({
    super.key,
    required this.screen,
    this.onClose,
    this.onBoundaries,
    this.onOpenInPlanner,
    this.onDiscard,
  });

  /// Built by [DraftViewModel.plan]. Nothing is computed here.
  final PlanDraftScreen screen;

  final VoidCallback? onClose;

  /// `X03`.
  final VoidCallback? onBoundaries;

  /// `W03`. The planner performs the write, after this tap. Not this screen.
  final VoidCallback? onOpenInPlanner;

  /// Also `W03`. No dialog, no "are you sure" — rule 9 across the whole tree.
  final VoidCallback? onDiscard;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.plan,
        leadingIcon: Icons.close,
        onBack: onClose,
        actions: [
          IconButton(
            tooltip: l10n.whatItCanAndCannotDo,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.info_outline),
            onPressed: onBoundaries,
          ),
        ],
      ),
      footer: [
        AppButton(l10n.openInMyPlanner, height: 54, onPressed: onOpenInPlanner),
        AppButton(
          l10n.discardTheDraft,
          variant: AppButtonVariant.text,
          height: 42,
          fontSize: 15,
          onPressed: onDiscard,
        ),
      ],
      children: [
        const AssistantHeldBadge(),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          gap: 6,
          children: [
            Text(l10n.draftedFromWhatYouAlreadyWrote, style: AppText.titleM),
            _Count(label: l10n.days, value: screen.dayCount),
            _Count(label: l10n.sessions, value: screen.sessionCount),
            _Count(label: l10n.restDay, value: screen.restCount),
          ],
        ),
        // The first week, which is all K26 shows above the fold. A day whose
        // moves all failed to resolve keeps its place in the list rather than
        // silently shortening a 30-day plan.
        for (final day in screen.firstWeek) _PlanDay(day: day),
        AssistantNotice(
          icon: Icons.warning_amber,
          text: l10n.nothingIsPublishedThisOpensAsA,
          variant: AppCardVariant.amber,
          tone: AppColors.amber,
        ),
      ],
    );
  }
}

/// A label and a count, from the structure of the draft.
class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => AppSplitRow(
    start: Text(
      label,
      style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
    ),
    // Western digits in both languages — P0-A11Y-01. Never NumberFormat.
    end: Text(countLabel(value), style: AppText.label),
  );
}

class _PlanDay extends StatelessWidget {
  const _PlanDay({required this.day});

  final PlanDayRow day;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // One ruled line per day, as a week is kept in a diary: seven boxes of
    // the same shape would read as a template, not a plan.
    final line = Padding(
      padding: const EdgeInsets.fromLTRB(2, 9, 2, 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 30,
            child: Text(
              countLabel(day.position + 1),
              style: AppText.label.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (day.isRest)
                  Text(l10n.restDay, style: AppText.bodyM)
                else
                  // Names, read from the pack. A move the pack does not know
                  // contributes no entry, so an empty training day renders as
                  // an empty day rather than as a day with an invented move in
                  // it.
                  for (final move in day.moves)
                    Text(move, style: AppText.bodyM),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        HandRule(seed: handSeed(['plan-day', day.position]), height: 3),
      ],
    );
  }
}
