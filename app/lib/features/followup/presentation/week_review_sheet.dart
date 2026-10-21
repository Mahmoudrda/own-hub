/// The Friday week review: three quick questions, then what Own Hub would
/// change, if anything. Nothing changes until she taps "Use this".
library;

import 'package:flutter/material.dart';

import '../../../app_state/app_changes.dart';
import '../../../app_state/follow_up_state.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_chip_row.dart';
import '../../../ui/app_sheet.dart';
import '../../onboarding/domain/intake.dart';
import '../../onboarding/domain/intake_repository.dart';
import '../domain/follow_up_plan.dart';

/// Opens the week review for the week that began on [weekStartKey].
Future<void> showWeekReviewSheet(
  BuildContext context, {
  required String weekStartKey,
  required IntakeRepository repository,
  FollowUpState? state,
  String? summary,
  bool safetyFirst = false,
}) {
  return showAppSheet<void>(
    context: context,
    children: [
      WeekReviewBody(
        weekStartKey: weekStartKey,
        repository: repository,
        state: state,
        summary: summary,
        safetyFirst: safetyFirst,
      ),
    ],
  );
}

class WeekReviewBody extends StatefulWidget {
  const WeekReviewBody({
    super.key,
    required this.weekStartKey,
    required this.repository,
    this.state,
    this.summary,
    this.safetyFirst = false,
  });

  /// Pregnant, postpartum, or training around pain or an injury: no weight
  /// loss focus is offered.
  final bool safetyFirst;

  /// Her week in positive numbers, shown above the suggestions.
  final String? summary;

  final String weekStartKey;
  final IntakeRepository repository;
  final FollowUpState? state;

  @override
  State<WeekReviewBody> createState() => _WeekReviewBodyState();
}

class _WeekReviewBodyState extends State<WeekReviewBody> {
  int? _felt;
  int? _fit;
  int? _focus;
  WeekSuggestion? _suggestion;
  final Set<String> _applied = <String>{};

  FollowUpState get _state => widget.state ?? FollowUpState.instance;

  bool get _complete => _felt != null && _fit != null && _focus != null;

  void _save() {
    if (!_complete) return;
    final answer = WeekReviewAnswer(
      felt: WeekFelt.values[_felt!],
      fit: PlanFit.values[_fit!],
      focus: WeekFocus.values[_focus!],
    );
    final intake = widget.repository.read();
    final suggestion = FollowUpPlan.suggest(
      answer,
      days: intake.days,
      minutes: intake.minutes,
      goal: intake.goal,
    );
    setState(() => _suggestion = suggestion);
    _state.answerWeek(widget.weekStartKey, answer);
  }

  Future<void> _use(String row) async {
    final s = _suggestion;
    if (s == null) return;
    setState(() => _applied.add(row));
    switch (row) {
      case 'days':
        await widget.repository.merge(
          days: s.days,
          weekdays: _weekdaysFor(s.days!),
        );
      case 'minutes':
        await widget.repository.merge(minutes: s.minutes);
      case 'goal':
        await widget.repository.merge(goal: s.goal);
    }
    AppChanges.bump();
  }

  /// Her chosen weekdays, kept as close to hers as the new number allows: the
  /// last one goes, or the first free one is added. Null when she has not
  /// chosen weekdays, so a flexible week stays flexible.
  Set<int>? _weekdaysFor(int days) {
    final chosen = widget.repository.read().weekdays;
    if (chosen.isEmpty) return null;
    final order = Intake.weekdayOrder;
    final kept = [
      for (final d in order)
        if (chosen.contains(d)) d,
    ];
    while (kept.length > days) {
      kept.removeLast();
    }
    for (final d in order) {
      if (kept.length >= days) break;
      if (!kept.contains(d)) kept.add(d);
    }
    return kept.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final suggestion = _suggestion;
    return Column(
      key: const ValueKey('week-review-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.yourWeek, style: AppText.titleL),
        const SizedBox(height: 14),
        if (suggestion == null)
          ..._questions(context, l10n)
        else
          ..._suggestions(context, l10n, suggestion),
        const SizedBox(height: 16),
      ],
    );
  }

  List<Widget> _questions(BuildContext context, AppL10n l10n) => [
    _ask(
      l10n.howDidThisWeekFeel,
      [l10n.goodWeek, l10n.okayWeek, l10n.hardWeek],
      _felt,
      (i) => setState(() => _felt = i),
      'week-review-felt',
      1,
    ),
    _ask(
      l10n.didThePlanFitYourTime,
      [l10n.tooMuch, l10n.aboutRight, l10n.tooLittle],
      _fit,
      (i) => setState(() => _fit = i),
      'week-review-fit',
      2,
    ),
    _ask(
      l10n.nextWeeksFocus,
      [l10n.strength, l10n.feelGood, if (!widget.safetyFirst) l10n.steadyLoss],
      _focus,
      (i) => setState(() => _focus = i),
      'week-review-focus',
      3,
    ),
    AppButton(
      l10n.save,
      key: const ValueKey('week-review-save'),
      onPressed: _complete ? _save : null,
    ),
  ];

  Widget _ask(
    String question,
    List<String> items,
    int? chosen,
    ValueChanged<int> onTap,
    String key,
    int step,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          AppL10n.of(context).currentOfTotal('$step', '3'),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        Text(question, style: AppText.titleS),
        const SizedBox(height: 8),
        AppChipRow(
          key: ValueKey(key),
          items: items,
          selected: {?chosen},
          height: 48,
          onTap: onTap,
        ),
      ],
    ),
  );

  List<Widget> _suggestions(
    BuildContext context,
    AppL10n l10n,
    WeekSuggestion s,
  ) {
    final rows = <(String, String)>[
      if (s.days != null) ('days', l10n.daysAWeekDays('${s.days}')),
      if (s.minutes != null)
        ('minutes', l10n.sessionLengthMinutesMin('${s.minutes}')),
      if (s.goal != null) ('goal', l10n.focusGoal(_goalLabel(l10n, s.goal!))),
    ];
    final summary = widget.summary;
    return [
      if (summary != null && summary.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            summary,
            key: const ValueKey('week-review-summary'),
            style: AppText.titleS,
          ),
        ),
      if (rows.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            l10n.yourPlanStaysAsItIsSee,
            key: const ValueKey('week-review-nothing'),
            style: AppText.body,
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            l10n.hereIsWhatWeSuggestNothingChanges,
            style: AppText.body,
          ),
        ),
      for (final (id, text) in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(text, style: AppText.titleS),
              const SizedBox(height: 8),
              if (_applied.contains(id))
                Text(
                  l10n.done_54ca1,
                  key: ValueKey('week-review-done-$id'),
                  style: AppText.body.copyWith(color: AppColors.primaryDim),
                )
              else
                AppButton(
                  l10n.useThis,
                  key: ValueKey('week-review-use-$id'),
                  variant: AppButtonVariant.tonal,
                  onPressed: () => _use(id),
                ),
            ],
          ),
        ),
      AppButton(
        rows.isEmpty ? l10n.done_54ca1 : l10n.keepMyPlan,
        key: const ValueKey('week-review-keep'),
        variant: AppButtonVariant.text,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    ];
  }

  static String _goalLabel(AppL10n l10n, TrainingGoal goal) => switch (goal) {
    TrainingGoal.stronger => l10n.getStronger,
    TrainingGoal.feelBetter => l10n.feelGoodAndMove,
    TrainingGoal.loseSteadily => l10n.loseSteadily,
    TrainingGoal.backIntoIt => l10n.getBackIntoIt,
  };
}
