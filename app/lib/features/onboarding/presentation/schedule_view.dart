/// O03 — How many days a week?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O03`.
///
/// # This screen defines the rewards system
///
/// Her answer here becomes the **weekly goal** — the number of sessions that
/// makes a week count. The design note calls it "the screen that defines the
/// whole rewards system", and the sage note explains the rest-week rule here,
/// once, *before she can ever fail it*.
///
/// # Weeks, not days (§2 rule 3)
///
/// "Days a week" is a **quantity per week**. It is not a streak, not a run of
/// consecutive days, and not a set of weekdays she must hit. Nothing on this
/// screen counts days, and [Intake] has no type that could hold such a count —
/// `lib/domain/week/week_key.dart` is the only unit of time this product counts
/// progress in. The research behind the product is explicit that visible daily
/// failure erodes the motivation it is built to create, so a day counter added
/// here would not be a feature; it would be the defect.
///
/// The chips keep Western numerals in Arabic (`P0-A11Y-01`). They are rendered
/// from the integers in [Intake.allowedDays] and [Intake.allowedMinutes] rather
/// than from translated strings, so "3" cannot become "٣" on one screen and stay
/// "3" on the next.
///
/// # Two short answers, one screen
///
/// Days a week and minutes a session sit together: both are a single tap on an
/// answer that is already chosen, and two screens for them made setup longer
/// than it needed to be. What to train around is the next screen (`O04`).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_option.dart' show IntakeAnswerGroup;
import 'intake_step_scaffold.dart';
import '../../../app_state/onboarding_state.dart' show setupProgress;

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

  @override
  void initState() {
    super.initState();
    final intake = widget.repository.read();
    _days = intake.days;
    _minutes = intake.minutes;
  }

  Future<void> _continue() async {
    await widget.repository.merge(days: _days, minutes: _minutes);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

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
            items: [for (final d in Intake.allowedDays) '$d'],
            selected: {Intake.allowedDays.indexOf(_days)},
            onTap: (i) => setState(() => _days = Intake.allowedDays[i]),
          ),
        ),
        IntakeAnswerGroup(
          label: l10n.minutesASession,
          child: AppChipRow(
            items: [for (final m in Intake.allowedMinutes) l10n.nMin('$m')],
            selected: {Intake.allowedMinutes.indexOf(_minutes)},
            onTap: (i) => setState(() => _minutes = Intake.allowedMinutes[i]),
          ),
        ),
        // The rest-week rule, stated before she can fail it. Sage, because it is
        // restorative: a missed week costs her nothing once she has banked one.
        //
        // It used to open "Three sessions a week is your goal", under chips
        // offering two, three, four and five. The sentence was true of the
        // default and of nobody who changed it, on the screen whose whole
        // subject is that the number is hers. The rule is the same for every
        // number, so the sentence now states the rule and leaves the number to
        // the chips she just tapped.
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
