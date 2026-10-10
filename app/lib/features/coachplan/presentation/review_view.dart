/// `W09` — reading her week back to her, and answering it.
///
/// ## Two buttons, because they are two acts
///
/// OQ-10 named the defect in the mockup: one control reading "Save feedback and
/// publish changes" tells a coach that answering a review publishes her
/// unpublished edits, which would break r2 the moment she has any. The owner
/// split it.
///
///  * **Save feedback** is always offered, and publishes nothing — online or
///    offline, dirty draft or clean one.
///  * **Publish changes** is offered *only* when the draft holds unpublished
///    edits, and it is a **navigation to W08**. Nothing on this screen
///    publishes: `ReviewScreenActions.publishesHere` is false, and the screen
///    renders the actions that type lists rather than deciding for itself.
///
/// Each carries its own label, and `saveFeedbackAndPublishChanges` — the
/// retired single-button string — is used nowhere. The two controls were built
/// first and labelled once the dictionary had two sentences for two acts;
/// borrowing the combined one would have restored the defect the split
/// removed.
///
/// Absent, not disabled, when the draft is clean: a control that cannot do
/// anything is a question the coach has to answer before she can ignore it.
///
/// ## Unlogged is not skipped, and a missing rollup is not zero
///
/// `P2-ERR-W09`. Days with no food log are counted as *logged days out of
/// seven*, which is a statement about what is known. When the rollup cannot be
/// read the rows are **absent**: zeroes there read as failure, and this screen
/// is where a woman's week gets described back to her.
library;

import 'package:flutter/material.dart';

import '../../../domain/rewards/stated_figure.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_field.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/review/review_feedback_service.dart';
import 'coachplan_widgets.dart';

class ReviewView extends StatelessWidget {
  const ReviewView({
    super.key,
    required this.summary,
    required this.actions,
    this.clientName = '',
    this.clientWords,
    this.reply = '',
    this.onReplyChanged,
    this.onSaveFeedback,
    this.onOpenPublish,
    this.onAdjustWorkouts,
    this.onAdjustMeals,
    this.onRecordVoice,
    this.onSend,
    this.onBack,
  });

  final WeekReviewSummary summary;

  /// What this screen offers, and what it cannot do whatever it offers.
  final ReviewScreenActions actions;

  final String clientName;

  /// Her own words from the check-in, when she left any.
  final String? clientWords;

  /// What the coach has typed back so far. Held by the host, exactly as `W04`
  /// holds a session title, so leaving the screen and coming back shows it.
  final String reply;

  /// Supplied by a host that can store her answer. Without it the reply row
  /// stays the prototype's mic-and-send strip, which writes nothing.
  final ValueChanged<String>? onReplyChanged;

  final VoidCallback? onSaveFeedback;

  /// Opens `W08`. Never a publish from here.
  final VoidCallback? onOpenPublish;

  final VoidCallback? onAdjustWorkouts;
  final VoidCallback? onAdjustMeals;
  final VoidCallback? onRecordVoice;
  final VoidCallback? onSend;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final words = clientWords;

    // The dictionary's only sentence about unlogged days states two of them.
    // `statedLine` shows it to the coach it is literally true for and to
    // nobody else — the codebase's own answer to a baked-in figure.
    final notLoggedLine = summary.rollupAvailable
        ? statedLine(
            l10n.twoDaysWithNoMealAddedAre,
            states: 2,
            hers: summary.daysNotLogged,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppTopBar(title: clientName, onBack: onBack),
      body: AppScaffold(
        footer: [for (final action in actions.actions) _button(l10n, action)],
        children: [
          AppCard(
            gap: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SectionHead(l10n.herWeek),
              ),
              // Absent rather than zero when G11's rollup could not be read.
              //
              // TODO(l10n): the plan asks this screen to *state* that the
              // rollup is missing. No dictionary string says so, so the rows
              // are withheld instead of being drawn as zeroes.
              if (summary.rollupAvailable) ...[
                LabelledValue(
                  label: l10n.workouts,
                  value: l10n.countOfTotal(
                    '${summary.sessionsLogged}',
                    '${summary.sessionsPlanned}',
                  ),
                ),
                LabelledValue(
                  label: l10n.mealAdded,
                  value: l10n.loggedOfTotalNotedDays(
                    '${summary.mealDaysLogged}',
                    '${summary.daysInWeek}',
                  ),
                ),
              ],
            ],
          ),
          if (words != null && words.isNotEmpty)
            AppCard(
              variant: AppCardVariant.filled,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [Text(words, style: AppText.bodyM)],
            ),
          if (notLoggedLine != null)
            Text(
              notLoggedLine,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          // Her answer, in her own words. A review is answered with words or a
          // voice note and never with neither, so this is the half that
          // exists: there is no recorder in this build.
          if (onReplyChanged != null)
            _ReplyField(
              key: const Key('W09.reply'),
              label: l10n.message,
              initial: reply,
              onChanged: onReplyChanged!,
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: l10n.voice,
                    color: AppColors.onPrimaryContainer,
                    icon: const Icon(Icons.mic),
                    onPressed: onRecordVoice,
                  ),
                  Expanded(
                    child: Text(
                      l10n.holdToReplyByVoice,
                      style: AppText.bodyM.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.send,
                    color: AppColors.primaryDim,
                    icon: const Icon(Icons.send),
                    onPressed: onSend,
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.adjustWorkouts,
                  variant: AppButtonVariant.tonal,
                  height: 44,
                  fontSize: 14,
                  onPressed: onAdjustWorkouts,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  l10n.adjustMeals,
                  variant: AppButtonVariant.outlined,
                  height: 44,
                  fontSize: 14,
                  onPressed: onAdjustMeals,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One control per action, in the order the domain lists them.
  ///
  /// The two labels are **"Save feedback"** and **"Publish changes"**, each
  /// naming its own act. `saveFeedbackAndPublishChanges` is still not used and
  /// must not be: it is the single-button copy OQ-10 retired, and putting it on
  /// either of these controls would tell a coach that answering a review
  /// publishes her unpublished edits — the exact claim the split exists to
  /// stop, restored with two buttons instead of one.
  Widget _button(AppL10n l10n, CoachReviewAction action) => switch (action) {
    CoachReviewAction.saveFeedback => AppButton(
      l10n.saveFeedback,
      key: CoachPlanKeys.saveFeedback,
      height: 54,
      icon: Icons.check,
      // Always enabled. Recording her answer is never gated on the draft.
      onPressed: onSaveFeedback,
    ),
    CoachReviewAction.publishChanges => AppButton(
      l10n.publishChanges,
      key: CoachPlanKeys.publishChanges,
      variant: AppButtonVariant.outlined,
      height: 46,
      fontSize: 15,
      icon: Icons.open_in_new,
      // A navigation to W08, which is the one screen that publishes.
      onPressed: onOpenPublish,
    ),
  };
}

/// The coach's answer, with the controller a `StatelessWidget` cannot hold.
class _ReplyField extends StatefulWidget {
  const _ReplyField({
    super.key,
    required this.label,
    required this.initial,
    required this.onChanged,
  });

  final String label;
  final String initial;
  final ValueChanged<String> onChanged;

  @override
  State<_ReplyField> createState() => _ReplyFieldState();
}

class _ReplyFieldState extends State<_ReplyField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppField(
    controller: _controller,
    label: widget.label,
    onChanged: widget.onChanged,
  );
}
