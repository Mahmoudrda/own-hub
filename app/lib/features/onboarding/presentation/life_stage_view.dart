/// O04 — Anything we should train around?
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O04`. The last question of
/// either walk, and the only safety-critical one.
///
/// # This is not a diagnosis, and the copy has to keep saying so
///
/// Her answer is *meant* to feed what the programme avoids. It never names a
/// condition, never infers one, and never tells her what is wrong with her. An
/// app that told an Egyptian woman what her knee pain was would be practising
/// medicine through a phone; an app that quietly stops programming jumps for
/// her is doing its job.
///
/// The screen records that she is pregnant; it does not decide what a pregnancy
/// programme may contain. That decision has no authored, clinically-reviewed
/// source yet (G2 §9 Q5), it belongs to `LifeStageSafetyFilter` on the server
/// (G2 §5), and it is applied *before* selection rather than as a warning
/// afterwards.
///
/// # And in this build it feeds nothing, so it promises nothing
///
/// `selectStartingProgram` does not read `intake.lifeStage` and the catalogue
/// holds one programme, so all four answers lead to `beginner_foundations`.
/// The three rows therefore carry no subtitle at all: what they used to say
/// about the training is held behind [lifeStageShapesTraining], which measures
/// the selector rather than trusting this comment. See the note in `build`.
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
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../domain/body_data.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import '../domain/starting_program.dart';
import 'about_you_block.dart';
import 'intake_option.dart';
import 'intake_step_scaffold.dart';
import '../../../app_state/onboarding_state.dart'
    show OnboardingState, setupProgress;
import '../../../ui/medical_disclaimer.dart';

class LifeStageView extends StatefulWidget {
  const LifeStageView({
    super.key,
    required this.repository,
    this.onContinue,
    this.onSkip,
    this.onBack,
    this.onClose,
    this.titleOverride,
    this.continueLabel,
    this.bodyData,
  });

  final IntakeRepository repository;

  /// Where the optional "About you" answers go. Null is [BodyDataStore.instance].
  final BodyDataStore? bodyData;

  /// See [IntakeStepScaffold.titleOverride].
  final String? titleOverride;

  /// See [IntakeStepScaffold.continueLabel].
  final String? continueLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onSkip;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  @override
  State<LifeStageView> createState() => _LifeStageViewState();
}

class _LifeStageViewState extends State<LifeStageView> {
  late LifeStage _lifeStage;
  final _aboutYou = GlobalKey<AboutYouBlockState>();

  @override
  void initState() {
    super.initState();
    // D3 again, and it matters most here: a woman who was pregnant at setup is
    // not pregnant forever. This answer has to be as easy to change as it was to
    // give, so the screen opens on what is stored.
    _lifeStage = widget.repository.read().lifeStage;
  }

  Future<void> _continue() async {
    // A number out of range keeps her here with the field marked.
    if (!(_aboutYou.currentState?.save() ?? true)) return;
    await widget.repository.merge(lifeStage: _lifeStage);
    if (!mounted) return;
    widget.onContinue?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    // NEITHER OF THESE THREE LINES MAY MAKE A CLINICAL CLAIM, AND NONE OF THEM
    // MAY DESCRIBE TRAINING THIS BUILD DOES NOT DO.
    //
    // Round one: the postpartum row read "Pelvic floor first, cleared from week
    // six". "Cleared" is a clinician's word and this screen is not a clinician;
    // six weeks is a convention, and it is wrong after a caesarean, with a
    // complication, or with diastasis. The pregnancy row read "Safe movements,
    // nothing on the belly", which asserts safety in the app's own voice about
    // a body it has never seen. Both were rewritten to describe the training
    // rather than her body, which was right as far as it went.
    //
    // Round four: they describe training that does not happen. `starting_
    // program.dart` says so in its own words — "Life stage is recorded here,
    // not filtered here ... this client-side selector therefore takes no
    // clinical decision at all" — `selectStartingProgram` never reads
    // `intake.lifeStage`, and the catalogue holds one programme. A pregnant
    // woman was told we would keep nothing on her belly and handed the same
    // eight-week beginner programme as everyone else. The old sentence was
    // false about medicine; the new one was false about us, on the only screen
    // in this product that asks about a pregnancy.
    //
    // So the three promises are shown only while [lifeStageShapesTraining] is
    // true, which is measured from the selector itself rather than asserted
    // here. It is false in this build, so the rows name the answer and nothing
    // else, and the note below says what does happen to it. The day a
    // postpartum programme is authored and the selector reads the field, these
    // sentences come back on their own.
    final shapesTraining = lifeStageShapesTraining();
    final options = lifeStageOptions(l10n);

    final at = setupProgress('O04', widget.repository.read());
    return IntakeStepScaffold(
      step: at.step,
      total: at.total,
      titleOverride: widget.titleOverride,
      continueLabel: widget.continueLabel,
      title: l10n.anythingWeShouldTrainAround,
      // "Only you and your coach ever see this" names a reader this release
      // does not have: the coach app ships dark, so there is no coach on the
      // other side of the sentence and no screen that could show her this. The
      // promise is the same either way, and it is the one that has to be exact
      // on the only screen in the product that asks about a pregnancy — so it
      // names whoever can actually read the answer and nobody else.
      // Before she has an account the answer has nowhere to go but this
      // phone, and the line says so.
      subtitle: OnboardingState.instance.beforeSignup
          ? l10n.onlyYouSeeThisItStaysOn
          : AppRouter.featureFlags.isOn(Feature.coachApp)
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
        // What actually happens to the answer, on the screen that asks for it.
        //
        // The heading is "Anything we should train around?", and with the three
        // promises off the rows a woman would otherwise be asked a question and
        // told nothing at all about why. This says the true thing: it is saved,
        // and it does not move her sessions yet. It disappears the moment the
        // promises above become true, so the screen never says both.
        //
        // Same sage card O03 ends on, so the two setup steps read as one piece.
        if (!shapesTraining)
          AppCard(
            variant: AppCardVariant.sage,
            borderRadius: AppRadius.md,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              Text(
                l10n.weSaveYourAnswerWithTheRest,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onTertiaryContainer,
                ),
              ),
            ],
          ),
        // Her goal may be to lose weight; food targets never are, in these two
        // stages. Said here, where she has just told us, not discovered later.
        if ((_lifeStage == LifeStage.pregnant ||
                _lifeStage == LifeStage.postpartum) &&
            widget.repository.read().goal == TrainingGoal.loseSteadily)
          AppCard(
            key: const ValueKey('life-stage-no-deficit'),
            variant: AppCardVariant.sage,
            borderRadius: AppRadius.md,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              Text(
                l10n.weDoNotSetWeightLossTargets_14owx,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onTertiaryContainer,
                ),
              ),
            ],
          ),
        AboutYouBlock(
          key: _aboutYou,
          store: widget.bodyData ?? BodyDataStore.instance,
        ),
        // The only screen that asks about a pregnancy says what the app is.
        const MedicalDisclaimer(caption: true),
      ],
    );
  }
}

/// The four answers to "Anything we should train around?", with the line each
/// one may carry.
///
/// The short "Your week" asks it on this same screen. The rule in the note
/// inside
/// [_LifeStageViewState.build] holds for both: a row promises nothing about
/// training while [lifeStageShapesTraining] is false.
List<(LifeStage, String, String)> lifeStageOptions(AppL10n l10n) {
  final shapesTraining = lifeStageShapesTraining();
  return <(LifeStage, String, String)>[
    (LifeStage.none, l10n.nothingRightNow, ''),
    (
      LifeStage.postpartum,
      l10n.afterABirth,
      shapesTraining ? l10n.pelvicFloorFirstOnceYourDoctorSays : '',
    ),
    (
      LifeStage.pregnant,
      l10n.pregnant,
      shapesTraining ? l10n.gentlerMovementsNothingOnTheBelly : '',
    ),
    (
      LifeStage.painInjury,
      l10n.aKneeBackOrShoulder,
      shapesTraining ? l10n.weAvoidWhatHurtsWeDoNot : '',
    ),
  ];
}
