/// O05 — Your starting programme.
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O05`. The four questions come
/// back as a named programme with her days already set, so the answers visibly
/// paid for something. One primary button — start now — and the alternatives are
/// real choices rather than a dead end.
///
/// # The programme content does not exist yet
///
/// The card describes a programme nobody has authored (G2 §9 Q8). See
/// `../domain/starting_program.dart`: the catalogue is modelled as data with a
/// `TODO(owner)`, holds one entry, and contains no invented exercises, sets or
/// loads. This screen renders the copy the dictionary already has for that one
/// programme and renders **no card at all** for a programme it has no copy for,
/// rather than inventing a name for it.
///
/// # Before sign-up
///
/// With [beforeSignup] this is the end of the short "Your week": her answers,
/// the programme, and one way on, "Save my week and join". The note says what
/// is next in plain words: one check keeps Own Hub women only, then day one is
/// hers. There is no "start now" here, because nothing behind the gate opens
/// before the check.
///
/// # "Pick a different program" goes to the Workout library
///
/// Drawn only while the catalogue holds more than one programme. With one, the
/// button offered a choice that does not exist.
///
/// The design routes it to the workout library (`screens-onboarding.mjs:37`, `R11`, now Explore on `R01`), which the screen
/// inventory names **"Workout library"** — 124 videos with filters, not a
/// programme picker. G2 §9 Q4 flags this as an open question: there is no
/// programme-picker screen anywhere in the 161. Implemented as designed, wired
/// by the router, and reported rather than quietly repointed — repointing it at
/// `R02` would mean changing programme requires re-running setup, which is a
/// product decision and not one a screen should take on its own.
///
/// # Two fixed strings that should be about her
///
/// The headline ("Three days a week, 15 minutes, at home") and the week line
/// ("Your week: Monday, Tuesday and Thursday") are single dictionary entries, not
/// templates. A woman who chose four days and twenty minutes at the gym is shown
/// the same sentence. Rendered as the design and the dictionary have them, and
/// reported: making them true needs new parameterised strings in both languages,
/// which is a translation change and not a code change.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_preparation_steps.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/intake.dart';
import '../domain/intake_repository.dart';
import '../domain/starting_program.dart';
import 'her_answers.dart';

/// The copy for one programme. Held together so a programme can never render a
/// title from one entry and a description from another.
typedef _ProgramCopy = ({String title, String detail, String firstWeek});

class StartingProgramView extends StatelessWidget {
  const StartingProgramView({
    super.key,
    required this.repository,
    this.catalogue,
    this.onStartNow,
    this.onStartTomorrow,
    this.onPickDifferentProgram,
    this.beforeSignup = false,
    this.onSaveAndJoin,
    this.onSaveMyWeek,
    this.saveLabel,
    this.title,
    this.onBack,
    this.showSteps = false,
  });

  /// The end of the short "Your week", before she has an account.
  final bool beforeSignup;

  /// "Save my week and join": on to her number.
  final VoidCallback? onSaveAndJoin;

  /// "Save my week", the one way on when she built her week while a woman
  /// reviewer has her check. Non-null replaces the start buttons: day one is
  /// behind the gate until the check is done.
  final VoidCallback? onSaveMyWeek;

  /// The label on [onSaveMyWeek]'s button. "Save my changes" when she reopened
  /// her answers from her profile: she is changing a week, not starting one.
  final String? saveLabel;

  /// The bar title, when the screen has a bar (before sign-up it does).
  final String? title;

  /// Back to "Your week", when the screen has a bar.
  final VoidCallback? onBack;

  /// D39: before her programme appears, tick off what was done to choose it —
  /// her answers read, her equipment checked, her days and minutes matched,
  /// and, at home, a quiet session preferred. Each is a step
  /// [selectStartingProgram] really takes. Shown once per set of answers in a
  /// run of the app; the footer works throughout.
  final bool showSteps;

  final IntakeRepository repository;

  /// Injectable, so a test can prove the card comes from data. Null reads the
  /// bundled programmes ([kStartingProgramCatalogue]).
  final List<StartingProgram>? catalogue;

  /// `R03` — into day one, now.
  final VoidCallback? onStartNow;

  /// `T06` — Home, day one.
  final VoidCallback? onStartTomorrow;

  /// Explore on Train (`R01`). See the note at the top of this file.
  final VoidCallback? onPickDifferentProgram;

  // Her answers are read back by [herAnswersLine], shared with day-one Home.

  /// Dictionary copy for a programme id, or null when none has been written.
  ///
  /// A programme with no copy renders no card, which is visibly incomplete: the
  /// deliberate alternative to showing her an English id or an invented name.
  /// Every programme in the bundled file has an entry, and a test holds that.
  _ProgramCopy? _copyFor(AppL10n l10n, String programId, Intake intake) {
    // The plan's name and its first week, then where it is done: the file's ids
    // are `<plan>_<variant>`.
    _ProgramCopy plan(String title, String firstWeek, String detail) =>
        (title: title, detail: detail, firstWeek: firstWeek);
    final stronger = l10n.eachSessionIsAFullBodyWith;
    final feelGood = l10n.eachSessionIsAGentleFullBody;
    final steady = l10n.eachSessionIsASteadyCircuitWith;
    final atHome = l10n.atHomeQuietNothingToBuy;
    final withDumbbells = l10n.atHomeQuietWithYourDumbbells;
    final atGym = l10n.atTheGymWeightsAndMachines;
    switch (programId) {
      case 'stronger_home':
        return plan(l10n.getStronger, stronger, atHome);
      case 'stronger_weights':
        return plan(l10n.getStronger, stronger, withDumbbells);
      case 'stronger_gym':
        return plan(l10n.getStronger, stronger, atGym);
      case 'feel_better_home':
        return plan(l10n.feelGoodAndMove, feelGood, atHome);
      case 'feel_better_weights':
        return plan(l10n.feelGoodAndMove, feelGood, withDumbbells);
      case 'feel_better_gym':
        return plan(l10n.feelGoodAndMove, feelGood, atGym);
      case 'lose_steadily_home':
        return plan(l10n.loseSteadily, steady, atHome);
      case 'lose_steadily_weights':
        return plan(l10n.loseSteadily, steady, withDumbbells);
      case 'lose_steadily_gym':
        return plan(l10n.loseSteadily, steady, atGym);
      case 'beginner_foundations':
        return (
          title: l10n.beginnerFoundations,
          // "Quiet, no equipment" is a promise about training at home. A
          // woman who said she trains at a gym is not told it.
          detail: intake.place == TrainingPlace.home
              ? l10n.n8WeeksQuietNoEquipment
              : l10n.n8WeeksForBeginners,
          firstWeek: l10n.week1StartsWithFourMovesOn_9iwwr,
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final Intake intake = repository.read();
    final catalogue = this.catalogue ?? kStartingProgramCatalogue;
    final program = selectStartingProgram(intake, catalogue: catalogue);
    final copy = program == null
        ? null
        : _copyFor(l10n, program.programId, intake);
    final offersAnotherProgram =
        catalogue.length > 1 && AppRouter.screenIsOn('R01');

    return AppScaffold(
      appBar: title == null && onBack == null
          ? null
          : AppTopBar(title: title ?? '', onBack: onBack),
      footer: beforeSignup
          ? [AppButton(l10n.saveMyWeekAndJoin, onPressed: onSaveAndJoin)]
          : onSaveMyWeek != null
          ? [
              AppButton(
                saveLabel ?? l10n.saveMyWeek,
                key: const ValueKey('o05-save-my-week'),
                onPressed: onSaveMyWeek,
              ),
            ]
          : [
              AppButton(
                l10n.startDay1Now,
                icon: Icons.play_arrow,
                onPressed: onStartNow,
              ),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      l10n.iWillStartTomorrow,
                      variant: AppButtonVariant.text,
                      height: 44,
                      fontSize: 15,
                      onPressed: onStartTomorrow,
                    ),
                  ),
                  if (offersAnotherProgram) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppButton(
                        l10n.pickADifferentProgram,
                        variant: AppButtonVariant.text,
                        height: 44,
                        fontSize: 15,
                        onPressed: onPickDifferentProgram,
                      ),
                    ),
                  ],
                ],
              ),
            ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // "Your answers", never a count: the walk is five questions or
            // six, or three in the short "Your week".
            // While the one tick is on its way in, it says the same words.
            if (!(showSteps &&
                !_stepsShownFor.contains(_answersKey(intake)))) ...[
              Text(
                l10n.builtFromYourAnswers,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
            ],
            // Her answers read back, at section scale.
            Text(
              herAnswersLine(
                l10n,
                intake,
                placeAnswered: repository.placeAnswered,
              ),
              style: EditorialType.section.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
        if (copy != null)
          _StepsThenCard(
            show: showSteps,
            answers: _answersKey(intake),
            steps: [l10n.builtFromYourAnswers],
            card: AppCard(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // The programme is the page's one object, so its
                          // name is the one thing marked.
                          MarkerHighlight(
                            drawOn: true,
                            delay: HandTiming.medium,
                            child: Text(
                              copy.title,
                              textWidthBasis: TextWidthBasis.longestLine,
                              style: AppText.titleL,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            copy.detail,
                            style: AppText.bodyM.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.workspace_premium,
                      size: 28,
                      color: AppColors.primaryDim,
                    ),
                  ],
                ),
                // The prototype had a still here, labelled "coach demo still" in
                // a monospace face: a designer's annotation marking what goes in
                // the slot, like "logotype" on C01. There is no still to put in
                // it, and an empty media block with a play button on the last
                // screen of setup is a control that plays nothing, on the screen
                // that hands her into the app. It comes back with the asset.
                Text(
                  copy.firstWeek,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        // What happens next, before she taps: one check, then day one.
        if (beforeSignup)
          AppCard(
            variant: AppCardVariant.sage,
            borderRadius: AppRadius.md,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 24,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.oneQuickCheckKeepsOwnHubWomen,
                      style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

/// Her answers as one string, so the steps are shown once for each set of
/// answers rather than on every visit to the page.
String _answersKey(Intake intake) =>
    '${intake.goal.wireName}|${intake.place.wireName}|'
    '${intake.equipment.map((e) => e.wireName).join(',')}|'
    '${intake.days}|${intake.minutes}';

/// The answer sets the steps have already been shown for, this run.
final Set<String> _stepsShownFor = <String>{};

@visibleForTesting
void resetStartingProgramSteps() => _stepsShownFor.clear();

/// The steps, then the programme they chose.
class _StepsThenCard extends StatefulWidget {
  const _StepsThenCard({
    required this.show,
    required this.answers,
    required this.steps,
    required this.card,
  });

  final bool show;
  final String answers;
  final List<String> steps;
  final Widget card;

  @override
  State<_StepsThenCard> createState() => _StepsThenCardState();
}

class _StepsThenCardState extends State<_StepsThenCard> {
  late final bool _stepsDue =
      widget.show && !_stepsShownFor.contains(widget.answers);
  late bool _cardShown = !_stepsDue;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_stepsDue)
        AppPreparationSteps(
          key: const ValueKey('o05-steps'),
          labels: widget.steps,
          completed: widget.steps.length,
          onShown: () {
            _stepsShownFor.add(widget.answers);
            if (mounted) setState(() => _cardShown = true);
          },
        ),
      if (_cardShown) widget.card,
    ],
  );
}
