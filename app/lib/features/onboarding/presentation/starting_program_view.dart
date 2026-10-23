/// O05 — Your starting programme.
///
/// Matches `6-v2/src/screens-onboarding.mjs` → `O05`. The four questions come
/// back as a named programme with her days already set, so the answers visibly
/// paid for something. One primary button — start now — and the alternatives are
/// real choices rather than a dead end.
///
/// # Three splits and her own
///
/// The coach's 3, 4 and 5 day splits are the only plans (see
/// `../domain/starting_program.dart`). They are drawn in the order of their
/// days, the one that suits her days is tagged, each has Choose and Customize,
/// and a fourth card, Build my own workout, starts from nothing. The screen
/// renders **no card at all** for a programme it has no copy for, rather than
/// inventing a name for it.
///
/// Choosing a split other than the suggested one also sets her days a week to
/// its days, because the split is what she will train; a custom schedule of
/// other weekdays is let go only when the count differs. Going on with the
/// suggested one leaves her answers as she gave them.
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

import '../../../app_state/chosen_programme.dart';
import '../../../app_state/first_run_moments.dart';
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
import 'tick_promise_view.dart';
import 'programme_cards.dart';

class StartingProgramView extends StatefulWidget {
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
    this.onChoose,
    this.onBuildOwn,
    this.onCustomizeSplit,
    this.promiseFirst = false,
  });

  /// Draw the promise tick after the primary button and before moving on.
  /// Set only on the first walk, never on a profile edit or a plan change.
  final bool promiseFirst;

  /// Told which programme she is going with, just before any button that
  /// moves her on. Not told when she only looks.
  final ValueChanged<StartingProgram>? onChoose;

  /// "Build my own workout": on to building one instead of following a
  /// programme. Null draws no card.
  final VoidCallback? onBuildOwn;

  /// Customize on a split's card, with the id of the split at her level: on to
  /// editing it. Null draws no Customize button.
  final ValueChanged<String>? onCustomizeSplit;

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

  @override
  State<StartingProgramView> createState() => _StartingProgramViewState();
}

class _StartingProgramViewState extends State<StartingProgramView> {
  /// The programme she tapped, until she taps another. Null is the best fit.
  StartingProgram? _picked;

  /// Records the programme she is going with, then does what the button does.
  void _go(StartingProgram? chosen, VoidCallback? then, {bool align = false}) {
    if (chosen != null) {
      if (align || _picked != null) alignDaysToSplit(widget.repository, chosen);
      widget.onChoose?.call(chosen);
    }
    then?.call();
  }

  /// The primary button: the tick she draws to promise herself the plan, once,
  /// then on.
  void _goPromised(StartingProgram? chosen, VoidCallback? then) {
    if (chosen != null) {
      if (_picked != null) alignDaysToSplit(widget.repository, chosen);
      widget.onChoose?.call(chosen);
    }
    if (!widget.promiseFirst || !FirstRunMoments.instance.tickDue) {
      then?.call();
      return;
    }
    FirstRunMoments.instance.markTickSeen();
    final navigator = Navigator.of(context);
    late final Route<void> route;
    route = MaterialPageRoute<void>(
      builder: (_) => TickPromiseView(
        onDone: () {
          if (route.isCurrent) {
            navigator.pop();
          } else if (route.isActive) {
            navigator.removeRoute(route);
          }
          then?.call();
        },
      ),
    );
    navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = widget;
    final Intake intake = view.repository.read();
    final catalogue = view.catalogue ?? kStartingProgramCatalogue;
    final programs = [
      for (final program in topStartingPrograms(intake, catalogue: catalogue))
        if (programCopyFor(
              l10n,
              program.programId,
              intake,
              programme: program,
            ) !=
            null)
          program,
    ];
    final selected = programs.contains(_picked)
        ? _picked!
        : ChosenProgramme.among(programs);
    final offersAnotherProgram =
        catalogue.length > 1 && AppRouter.screenIsOn('R01');

    return AppScaffold(
      appBar: view.title == null && view.onBack == null
          ? null
          : AppTopBar(title: view.title ?? '', onBack: view.onBack),
      footer: view.beforeSignup
          ? [
              AppButton(
                l10n.saveMyWeekAndJoin,
                onPressed: () => _goPromised(selected, view.onSaveAndJoin),
              ),
            ]
          : view.onSaveMyWeek != null
          ? [
              AppButton(
                view.saveLabel ?? l10n.saveMyWeek,
                key: const ValueKey('o05-save-my-week'),
                onPressed: () => _go(selected, view.onSaveMyWeek),
              ),
            ]
          : [
              AppButton(
                l10n.startDay1Now,
                icon: Icons.play_arrow,
                onPressed: () => _goPromised(selected, view.onStartNow),
              ),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      l10n.iWillStartTomorrow,
                      variant: AppButtonVariant.text,
                      height: 44,
                      fontSize: 15,
                      onPressed: () =>
                          _goPromised(selected, view.onStartTomorrow),
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
                        onPressed: view.onPickDifferentProgram,
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
            if (!(view.showSteps &&
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
                placeAnswered: view.repository.placeAnswered,
              ),
              style: EditorialType.section.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ],
        ),
        if (selected != null)
          _StepsThenCard(
            show: view.showSteps,
            answers: _answersKey(intake),
            steps: [l10n.builtFromYourAnswers],
            // The prototype had a still on the programme, labelled "coach demo
            // still": a designer's annotation marking what goes in the slot.
            // There is no still to put in it, and an empty media block with a
            // play button on the last screen of setup is a control that plays
            // nothing. It comes back with the asset.
            card: ProgrammeChoiceList(
              programs: programs,
              intake: intake,
              selected: selected,
              placeAnswered: view.repository.placeAnswered,
              onSelect: (program) => setState(() => _picked = program),
              onCustomize:
                  view.onCustomizeSplit == null || view.onSaveMyWeek != null
                  ? null
                  : (program) => _go(
                      program,
                      () => view.onCustomizeSplit!(program.programId),
                      align: true,
                    ),
              onBuildOwn: view.onSaveMyWeek == null ? view.onBuildOwn : null,
            ),
          ),
        // What happens next, before she taps: one check, then day one.
        if (view.beforeSignup)
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
        // Room under the last card and link, so they scroll clear of the
        // pinned button.
        const SizedBox(height: 24),
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
