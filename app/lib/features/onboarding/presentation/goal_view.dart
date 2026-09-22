/// O01 — What do you want most?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O01`, the first of four setup
/// questions.
///
/// The subtitle is the promise the whole flow rests on: *"Pick one. It changes
/// the program, not the app."* Her goal must never rearrange the interface —
/// a woman who picks "lose weight steadily" gets different training, not a
/// different app with a scale bolted to it (§2 rule 11). So this screen writes
/// one enum and nothing else.
///
/// "Get stronger" is preselected, which is what makes `Skip` safe: skipping is a
/// real answer rather than an empty one.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_option.dart';
import 'intake_step_scaffold.dart';

class GoalView extends StatefulWidget {
  const GoalView({
    super.key,
    required this.repository,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onClose,
  });

  final IntakeRepository repository;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  State<GoalView> createState() => _GoalViewState();
}

class _GoalViewState extends State<GoalView> {
  late TrainingGoal _goal;

  @override
  void initState() {
    super.initState();
    // Her existing answer, not a fresh default. D3 puts this same screen behind
    // an edit control in My Profile, where opening it on "Get stronger" when she
    // chose something else would be a lie about what is stored.
    _goal = widget.repository.read().goal;
  }

  Future<void> _continue() async {
    await widget.repository.merge(goal: _goal);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final options = <(TrainingGoal, String, String)>[
      (TrainingGoal.stronger, l10n.getStronger, l10n.buildUpLiftABitMoreEach),
      (
        TrainingGoal.feelBetter,
        l10n.feelBetterInMyBody,
        l10n.energySleepLessBackPain,
      ),
      (
        TrainingGoal.loseSteadily,
        l10n.loseWeightSteadily,
        l10n.slowlyWithoutCuttingFoodYouLove,
      ),
      (TrainingGoal.backIntoIt, l10n.getBackIntoIt, l10n.afterABreakABirthOrAn),
    ];

    return IntakeStepScaffold(
      step: 1,
      title: l10n.whatDoYouWantMost,
      subtitle: l10n.pickOneItChangesTheProgramNot,
      onContinue: _continue,
      // Skip writes nothing. The preselected default stands, which is exactly
      // what a skipped question means.
      onSkip: widget.onSkip,
      onBack: widget.onBack,
      onClose: widget.onClose,
      children: [
        for (final (goal, title, subtitle) in options)
          IntakeOption(
            title: title,
            subtitle: subtitle,
            selected: _goal == goal,
            onTap: () => setState(() => _goal = goal),
          ),
      ],
    );
  }
}
