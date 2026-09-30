/// O04 — Anything we should train around?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O04`. The last of the four
/// questions, and the only safety-critical one.
///
/// # This is not a diagnosis, and the copy has to keep saying so
///
/// Her answer feeds what the programme **avoids**. It never names a condition,
/// never infers one, and never tells her what is wrong with her — the injury
/// option reads *"We avoid what hurts, we do not diagnose"*, and that sentence
/// is the boundary this screen is built on. An app that told an Egyptian woman
/// what her knee pain was would be practising medicine through a phone; an app
/// that quietly stops programming jumps for her is doing its job.
///
/// The same care applies to pregnancy and postpartum. The screen records that
/// she is pregnant; it does not decide what a pregnancy programme may contain.
/// That decision has no authored, clinically-reviewed source yet (G2 §9 Q5), it
/// belongs to `LifeStageSafetyFilter` on the server (G2 §5), and it is applied
/// *before* selection rather than as a warning afterwards.
///
/// # Private, and said so on the screen
///
/// *"Only you and your coach ever see this."* Her life stage never reaches the
/// community, a leaderboard or a feed — and §2 rule 11 means there is nothing to
/// rank her against in the first place.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import 'intake_option.dart';
import 'intake_step_scaffold.dart';

class LifeStageView extends StatefulWidget {
  const LifeStageView({
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
  State<LifeStageView> createState() => _LifeStageViewState();
}

class _LifeStageViewState extends State<LifeStageView> {
  late LifeStage _lifeStage;

  @override
  void initState() {
    super.initState();
    // D3 again, and it matters most here: a woman who was pregnant at setup is
    // not pregnant forever. This answer has to be as easy to change as it was to
    // give, so the screen opens on what is stored.
    _lifeStage = widget.repository.read().lifeStage;
  }

  Future<void> _continue() async {
    await widget.repository.merge(lifeStage: _lifeStage);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final options = <(LifeStage, String, String)>[
      (LifeStage.none, l10n.nothingRightNow, ''),
      // NEITHER OF THESE TWO LINES MAY MAKE A CLINICAL CLAIM.
      //
      // The postpartum row read "Pelvic floor first, cleared from week six".
      // "Cleared" is a clinician's word and this screen is not a clinician;
      // six weeks is a convention, and it is wrong after a caesarean, with a
      // complication, or with diastasis. Three rows below, the same list
      // carries the product's own rule: "We avoid what hurts, we do not
      // diagnose." So the row now says what the app does and leaves the timing
      // with the woman and her doctor, where it was always going to be.
      //
      // The pregnancy row read "Safe movements, nothing on the belly", which
      // asserts safety in the app's own voice about a body it has never seen.
      // It describes the movements instead.
      (
        LifeStage.postpartum,
        l10n.afterABirth,
        l10n.pelvicFloorFirstOnceYourDoctorSays,
      ),
      (
        LifeStage.pregnant,
        l10n.pregnant,
        l10n.gentlerMovementsNothingOnTheBelly,
      ),
      (
        LifeStage.painInjury,
        l10n.aKneeBackOrShoulder,
        l10n.weAvoidWhatHurtsWeDoNot,
      ),
    ];

    return IntakeStepScaffold(
      step: 4,
      title: l10n.anythingWeShouldTrainAround,
      // "Only you and your coach ever see this" names a reader this release
      // does not have: the coach app ships dark, so there is no coach on the
      // other side of the sentence and no screen that could show her this. The
      // promise is the same either way, and it is the one that has to be exact
      // on the only screen in the product that asks about a pregnancy — so it
      // names whoever can actually read the answer and nobody else.
      subtitle: AppRouter.featureFlags.isOn(Feature.coachApp)
          ? l10n.onlyYouAndYourCoachEverSee
          : l10n.onlyYouEverSeeThis,
      onContinue: _continue,
      onSkip: widget.onSkip,
      onBack: widget.onBack,
      onClose: widget.onClose,
      children: [
        for (final (stage, title, subtitle) in options)
          IntakeOption(
            title: title,
            subtitle: subtitle,
            selected: _lifeStage == stage,
            onTap: () => setState(() => _lifeStage = stage),
          ),
      ],
    );
  }
}
