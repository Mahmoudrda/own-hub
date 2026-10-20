/// O03 — How many days a week, and for how long?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O03`, grown for the owner's
/// 18 October brief: session lengths from 15 to 75+ minutes or any length from
/// 10 to 180, one to seven days, a custom schedule of weekdays, and a level.
///
/// # This screen defines the rewards system
///
/// Her answer here becomes the **weekly goal** — the number of sessions that
/// makes a week count, 1 to 7. The design note calls it "the screen that defines
/// the whole rewards system", and the sage note explains the rest-week rule
/// here, once, *before she can ever fail it*.
///
/// # Weeks, not days (§2 rule 3)
///
/// "Days a week" is a **quantity per week**. It is not a streak and not a run of
/// consecutive days. The custom schedule only says which weekdays she prefers:
/// the rest are recovery, and nothing here counts days that went by.
///
/// The chips keep Western numerals in Arabic (`P0-A11Y-01`). They are rendered
/// from integers rather than from translated strings, so "3" cannot become "٣"
/// on one screen and stay "3" on the next.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../../train/domain/viewed_tier.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_option.dart' show IntakeAnswerGroup;
import 'intake_step_scaffold.dart';
import '../../../app_state/onboarding_state.dart' show setupProgress;

/// The label of the first days chip: it stands for two sessions a week.
const String _oneToTwo = '1-2';

class ScheduleView extends StatefulWidget {
  const ScheduleView({
    super.key,
    required this.repository,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onClose,
    this.titleOverride,
    this.continueLabel,
  });

  final IntakeRepository repository;

  /// See [IntakeStepScaffold.titleOverride].
  final String? titleOverride;

  /// See [IntakeStepScaffold.continueLabel].
  final String? continueLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  State<ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<ScheduleView> {
  late int _days;
  late int _minutes;
  late bool _customMinutes;
  late TrainingLevel _level;
  late Set<int> _weekdays;
  late bool _customSchedule;

  /// Once she picks a level herself, her days and minutes stop moving it.
  late bool _levelChosen;

  @override
  void initState() {
    super.initState();
    final intake = widget.repository.read();
    _days = intake.days;
    _minutes = intake.minutes;
    _customMinutes =
        intake.minutesCustom || !Intake.allowedMinutes.contains(intake.minutes);
    _level = intake.level;
    _weekdays = {...intake.weekdays};
    _customSchedule = _weekdays.isNotEmpty;
    _levelChosen =
        intake.level !=
        TrainingLevel.suggestedFor(days: intake.days, minutes: intake.minutes);
  }

  TrainingLevel get _suggested =>
      TrainingLevel.suggestedFor(days: _days, minutes: _minutes);

  void _answersMoved() {
    if (!_levelChosen) _level = _suggested;
  }

  void _setDays(int days) => setState(() {
    _days = days;
    _weekdays = {};
    _customSchedule = false;
    _answersMoved();
  });

  void _toggleCustomSchedule() => setState(() {
    _customSchedule = !_customSchedule;
    _weekdays = _customSchedule ? Intake.spreadWeekdays(_days) : {};
    _answersMoved();
  });

  void _toggleWeekday(int weekday) => setState(() {
    final next = {..._weekdays};
    if (!next.remove(weekday)) next.add(weekday);
    // A week with no training day at all is not a goal.
    if (next.isEmpty) return;
    _weekdays = next;
    _days = next.length;
    _answersMoved();
  });

  void _setMinutes(int minutes, {required bool custom}) => setState(() {
    _minutes = minutes.clamp(Intake.minCustomMinutes, Intake.maxCustomMinutes);
    _customMinutes = custom;
    _answersMoved();
  });

  Future<void> _continue() async {
    await widget.repository.merge(
      days: _days,
      minutes: _minutes,
      minutesCustom: _customMinutes,
      level: _level,
      weekdays: _weekdays,
    );
    // Her level may have changed, so the tier tabs open on it again.
    ViewedTier.clear();
    if (!mounted) return;
    widget.onContinue?.call();
  }

  String _dayLabel(AppL10n l10n, int weekday) => switch (weekday) {
    DateTime.monday => l10n.mon,
    DateTime.tuesday => l10n.tue,
    DateTime.wednesday => l10n.wed,
    DateTime.thursday => l10n.thu,
    DateTime.friday => l10n.fri,
    DateTime.saturday => l10n.sat,
    _ => l10n.sun,
  };

  String _levelLabel(AppL10n l10n, TrainingLevel level) => switch (level) {
    TrainingLevel.beginner => l10n.beginner,
    TrainingLevel.intermediate => l10n.intermediate,
    TrainingLevel.advanced => l10n.advanced,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final presetDays = Intake.allowedDays;
    final presetMinutes = Intake.allowedMinutes;
    final customChip = presetMinutes.length;
    final at = setupProgress('O03', widget.repository.read());
    return IntakeStepScaffold(
      step: at.step,
      total: at.total,
      title: l10n.howManyDaysAndForHowLong,
      subtitle: l10n.beHonestThisBecomesYourWeeklyGoal,
      onContinue: _continue,
      onSkip: widget.onSkip,
      onBack: widget.onBack,
      onClose: widget.onClose,
      titleOverride: widget.titleOverride,
      continueLabel: widget.continueLabel,
      children: [
        IntakeAnswerGroup(
          label: l10n.daysAWeek,
          child: AppChipRow(
            items: [for (final d in presetDays) d == 2 ? _oneToTwo : '$d'],
            selected: _customSchedule
                ? const {}
                : {if (presetDays.contains(_days)) presetDays.indexOf(_days)},
            onTap: (i) => _setDays(presetDays[i]),
          ),
        ),
        AppChipRow(
          items: [l10n.customSchedule],
          selected: {if (_customSchedule) 0},
          onTap: (_) => _toggleCustomSchedule(),
          grow: false,
        ),
        if (_customSchedule)
          IntakeAnswerGroup(
            label: l10n.yourTrainingDays,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.tapADayToSwitchItBetween,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in Intake.weekdayOrder)
                      AppChip(
                        _dayLabel(l10n, d),
                        key: ValueKey('o03-weekday-$d'),
                        selected: _weekdays.contains(d),
                        icon: _weekdays.contains(d) ? Icons.check : null,
                        onTap: () => _toggleWeekday(d),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.trainingTrainingRecoveryRecovery(
                    '${_weekdays.length}',
                    '${7 - _weekdays.length}',
                  ),
                  key: const ValueKey('o03-schedule-summary'),
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        IntakeAnswerGroup(
          label: l10n.minutesASession,
          child: AppChipRow(
            items: [
              for (final m in presetMinutes)
                l10n.nMin(m == presetMinutes.last ? '$m+' : '$m'),
              l10n.custom,
            ],
            selected: {
              if (_customMinutes)
                customChip
              else if (presetMinutes.contains(_minutes))
                presetMinutes.indexOf(_minutes),
            },
            onTap: (i) {
              if (i == customChip) {
                _setMinutes(_minutes, custom: true);
              } else {
                _setMinutes(presetMinutes[i], custom: false);
              }
            },
          ),
        ),
        if (_customMinutes)
          _MinutesStepper(
            minutes: _minutes,
            onChanged: (m) => _setMinutes(m, custom: true),
          ),
        IntakeAnswerGroup(
          label: l10n.level,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppChipRow(
                items: [
                  for (final level in TrainingLevel.values)
                    _levelLabel(l10n, level),
                ],
                selected: {TrainingLevel.values.indexOf(_level)},
                onTap: (i) => setState(() {
                  _level = TrainingLevel.values[i];
                  _levelChosen = _level != _suggested;
                }),
              ),
              if (_level == _suggested && _suggested != TrainingLevel.beginner)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.suggestedFromYourWeek,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // The rest-week rule, stated before she can fail it. Sage, because it is
        // restorative: a missed week costs her nothing once she has banked one.
        //
        // The rule is the same for every number, so the sentence states the
        // rule and leaves the number to the chips she just tapped.
        AppCard(
          variant: AppCardVariant.sage,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          children: [
            Text(
              l10n.hitYourGoalAndTheWeekCounts,
              style: AppText.bodyM.copyWith(
                color: AppColors.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A session length from 10 to 180 minutes: minus and plus 5, and a slider for
/// the minutes in between.
class _MinutesStepper extends StatelessWidget {
  const _MinutesStepper({required this.minutes, required this.onChanged});

  final int minutes;
  final ValueChanged<int> onChanged;

  static const int _step = 5;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('o03-minutes-less'),
              tooltip: l10n.fewerMinutes,
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: minutes > Intake.minCustomMinutes
                  ? () => onChanged(minutes - _step)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 120,
              child: Text(
                l10n.nMin('$minutes'),
                key: const ValueKey('o03-minutes-value'),
                textAlign: TextAlign.center,
                style: AppText.titleM,
              ),
            ),
            IconButton(
              key: const ValueKey('o03-minutes-more'),
              tooltip: l10n.moreMinutes,
              iconSize: 28,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: minutes < Intake.maxCustomMinutes
                  ? () => onChanged(minutes + _step)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Slider(
          key: const ValueKey('o03-minutes-slider'),
          min: Intake.minCustomMinutes.toDouble(),
          max: Intake.maxCustomMinutes.toDouble(),
          divisions: Intake.maxCustomMinutes - Intake.minCustomMinutes,
          value: minutes.toDouble(),
          label: l10n.nMin('$minutes'),
          onChanged: (v) => onChanged(v.round()),
        ),
        Text(
          l10n.pickAnyLengthFromMinToMax(
            '${Intake.minCustomMinutes}',
            '${Intake.maxCustomMinutes}',
          ),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
