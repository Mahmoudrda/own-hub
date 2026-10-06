/// Y03 — My cycle today, and the two renderings that are **states of this same
/// route**: Y11 (severe) and Y14 (symptom-only).
///
/// HANDOFF rule 16 and plan §5: "Y11 and Y14 are states of the Y03 route, not
/// destinations." So there is one widget with three branches, chosen by
/// [CycleHubViewModel] from the data — exactly as `TodayView` renders T06 and
/// `EatView` renders E09. Nothing can navigate to "the severe screen"; she
/// arrives there by logging severe symptoms, which is the only way it is true.
///
/// ## What Y11 does not contain
///
/// No workout. No gentler option. No meal row. Not because this widget checks a
/// flag before drawing them, but because on a severe day the suggestion is
/// [Suppressed], and [Suppressed] carries no workout, alternative or session
/// field for anything here to read. The `_severe` branch below could not render
/// a session if it tried.
///
/// The Train entry row is absent for the same reason — `P0-CYC-06` names it
/// explicitly: "No workout, no gentler option and no meal-based answer appears
/// anywhere on the screen, **including the Train entry row**."
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_toggle.dart';
import '../../../ui/hand/hand.dart';
import '../domain/cycle_document.dart';
import '../domain/day_suggestion.dart';
import '../domain/period_entry.dart';
import '../domain/symptom_context.dart';
import '../domain/today_check_in.dart';
import 'cycle_hub_view_model.dart';
import 'cycle_widgets.dart';
import 'symptom_labels.dart';
import '../../../ui/medical_disclaimer.dart';

class CycleHubView extends StatelessWidget {
  const CycleHubView({
    super.key,
    required this.cycle,
    this.checkIn = TodayCheckIn.absent,
    this.periods = const <PeriodEntry>[],
    this.now,
    this.viewModel = const CycleHubViewModel(),
    this.onSettings,
    this.onBack,
    this.onCheckIn,
    this.onViewOption,
    this.onKeepMine,
    this.onOpenMeals,
    this.onFindCare,
    this.onReadGuidance,
    this.onRest,
    this.onAddDates,
    this.onSetUp,
    this.onSelectTab,
    this.onSelectCycleTab,
    this.onSetWorkoutSuggestions,
    this.gentlerDecided = false,
  });

  final CycleDocument? cycle;
  final TodayCheckIn checkIn;
  final List<PeriodEntry> periods;
  final DateTime? now;
  final CycleHubViewModel viewModel;

  final VoidCallback? onSettings;
  final VoidCallback? onBack;
  final VoidCallback? onCheckIn;
  final VoidCallback? onViewOption;
  final VoidCallback? onKeepMine;
  final VoidCallback? onOpenMeals;

  /// Y11's route to care. See [_severe] — the fallback cannot render yet.
  final VoidCallback? onFindCare;
  final VoidCallback? onReadGuidance;
  final VoidCallback? onRest;

  /// Y14's "Add period dates", which switches her to dates mode via Y02.
  final VoidCallback? onAddDates;

  final ValueChanged<String>? onSelectTab;

  /// Y01. Where the `notSetUp` branch sends a woman who has not set up yet.
  final VoidCallback? onSetUp;

  final ValueChanged<CycleTab>? onSelectCycleTab;

  /// Y14's "Show workout suggestions". Writes `adaptation.workoutSuggestions`,
  /// the same field Y02 and Y12 write — see [_askToAdapt].
  final ValueChanged<bool>? onSetWorkoutSuggestions;

  /// True once she has answered today's gentler option — "Keep mine", "Keep
  /// my workout" or rest. The card stops asking; a new check-in asks again.
  final bool gentlerDecided;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final snapshot = viewModel.build(
      cycle: cycle,
      checkIn: checkIn,
      periods: periods,
      today: now ?? AppClock.now(),
    );

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CycleNavBar(
        screenId: 'Y03',
        onSelectTab: onSelectTab,
      ),
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.cycleSettings,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.settings),
            onPressed: onSettings,
          ),
        ],
      ),
      body: AppScaffold(
        // Before she has set anything up the hub is a title page: the
        // drawing, what this is, and one action within thumb reach.
        scrollable: snapshot.branch != HubBranch.notSetUp,
        footer: snapshot.branch == HubBranch.notSetUp
            ? [
                AppButton(
                  l10n.trackPeriodsAndSymptoms,
                  icon: Icons.self_improvement,
                  onPressed: onSetUp,
                ),
              ]
            : const [],
        children: [
          ...switch (snapshot.branch) {
            HubBranch.notSetUp => _notSetUp(context, l10n),
            HubBranch.severe => _severe(context, l10n, snapshot),
            HubBranch.symptomsOnly => _symptomsOnly(context, l10n, snapshot),
            HubBranch.today => _today(context, l10n, snapshot),
          },
          // What the app is not, under her cycle (APL-12). Not on the title
          // page, which does not scroll; setup (Y01) says it there.
          if (snapshot.branch != HubBranch.notSetUp) const MedicalDisclaimer(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Y03 ----

  List<Widget> _today(
    BuildContext context,
    AppL10n l10n,
    CycleHubSnapshot snapshot,
  ) {
    final suggestion = snapshot.suggestion;

    return [
      CycleTabs(
        active: CycleTab.today,
        showCalendar: snapshot.showCalendarTab,
        onSelect: onSelectCycleTab,
      ),
      if (snapshot.periodDay != null) _periodDay(l10n, snapshot.periodDay!),
      AppButton(
        l10n.howAreYouFeeling,
        height: 48,
        icon: Icons.mood,
        onPressed: onCheckIn,
      ),
      if (snapshot.showGentlerCard &&
          suggestion is GentlerOption &&
          !gentlerDecided)
        _gentlerCard(l10n, suggestion),
      if (snapshot.showMealSuggestions)
        AppListItem(
          variant: AppCardVariant.filled,
          leading: const Icon(
            Icons.restaurant,
            size: 22,
            color: AppColors.primaryDim,
          ),
          // "Meals for today", not the mockup's "Lentil soup and toast · 20
          // min · vegetarian": no ranker has chosen a dish (G9 OQ-6), so Y07
          // opens with no options, and a row naming one here was a
          // suggestion nothing had made.
          title: l10n.mealsForToday,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: onOpenMeals,
        ),
    ];
  }

  /// Her day, set on the page and circled once in rose ink — the way she would
  /// ring it in a paper diary. The one mark on Y03, and never red: a period
  /// day is an ordinary day, not an alert.
  Widget _periodDay(AppL10n l10n, int day) {
    return Padding(
      // Room for the loop, which runs a little outside the words.
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 0, 10),
      child: Wrap(
        spacing: 28,
        runSpacing: 18,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // The day number is hers, counted from the period she logged — not
          // the mockup's "Period day 2". `PHASE1-FIXES.md` #13 records four
          // screens that stated the prototype's numbers as her facts.
          HandCircled(
            seed: handSeed(['period-day', day]),
            color: AppColors.primaryDim,
            level: HandLevel.expressive,
            inflate: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            drawOn: true,
            child: Text(
              _periodDayLabel(l10n, day),
              textWidthBasis: TextWidthBasis.longestLine,
              style: EditorialType.section,
            ),
          ),
          AppPill(
            l10n.loggedByYou,
            background: AppColors.surfaceContainer,
            foreground: AppColors.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  /// "Period day {day}" — the sentence, on every day.
  ///
  /// `periodDay2` bakes the mockup's day two in, so while that was the only
  /// form the dictionary had, this rendered the bare number on every other day
  /// rather than say "2" to a woman on day 4. `periodDayDay` is the
  /// placeholder form `PHASE2-ACCEPTANCE.md` §1 asked for, and with it the
  /// sentence is true whatever the number is.
  ///
  /// `countLabel`, never `NumberFormat`: `P0-A11Y-01` requires Western digits
  /// in Arabic, and `intl` emits Eastern ones under `ar`.
  String _periodDayLabel(AppL10n l10n, int day) =>
      l10n.periodDayDay(countLabel(day));

  Widget _gentlerCard(AppL10n l10n, GentlerOption option) {
    return AppCard(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(l10n.aGentlerOptionToday, style: AppText.titleM),
            ),
            const SizedBox(width: 8),
            // "App suggestion", never "coach-approved" — G2 publishes no
            // `workout.easierOption`, so a coach has approved nothing (OQ-4).
            AppPill(
              option.alternative.provenance ==
                          SessionProvenance.appSuggestion ||
                      !AppRouter.featureFlags.isOn(Feature.coachedLife)
                  ? l10n.appSuggestion
                  : l10n.fromYourCoachUnchanged,
              background: AppColors.surfaceContainer,
              foreground: AppColors.onSurfaceVariant,
            ),
          ],
        ),
        // What she actually logged — the same sentence Y06 reads out. The
        // dictionary's "You logged low energy and mild cramps" is the
        // mockup's pair, and was told to every woman whatever she logged.
        Text(
          loggedSymptomsSentence(l10n, option.reason),
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        Row(
          children: [
            Expanded(
              child: AppButton(
                l10n.viewOption,
                variant: AppButtonVariant.tonal,
                height: 44,
                fontSize: 15,
                onPressed: onViewOption,
              ),
            ),
            const SizedBox(width: 8),
            AppButton(
              l10n.keepMine,
              variant: AppButtonVariant.outlined,
              height: 44,
              fontSize: 15,
              onPressed: onKeepMine,
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- Y11 ----

  List<Widget> _severe(
    BuildContext context,
    AppL10n l10n,
    CycleHubSnapshot snapshot,
  ) {
    final suppressed = snapshot.suggestion as Suppressed;

    return [
      CycleTabs(
        active: CycleTab.today,
        showCalendar: snapshot.showCalendarTab,
        onSelect: onSelectCycleTab,
      ),
      AppCard(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (snapshot.periodDay != null)
                Flexible(
                  child: Text(
                    _periodDayLabel(l10n, snapshot.periodDay!),
                    style: AppText.titleL,
                  ),
                ),
              const SizedBox(width: 8),
              // Names the symptom that actually suppressed the day.
              //
              // `severeCrampsLogged` is a fixed string, and it was the only
              // thing this pill could say while heavy bleeding was unreachable
              // from Y04. Now that it is reachable, a woman who logged no
              // cramps at all would have been told "Severe cramps logged" —
              // the mockup's fact stated as hers, which is the defect
              // `PHASE1-FIXES.md` #13 records. So the pill reads the reason.
              Flexible(
                child: AppPill(
                  suppressed.reason.contains(LoggedSymptom.severeCramps)
                      ? l10n.severeCrampsLogged
                      : loggedSymptomLabel(l10n, LoggedSymptom.heavyBleeding),
                  background: AppColors.errorContainer,
                  foreground: AppColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
      AppCard(
        variant: AppCardVariant.error,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.support_agent, size: 26, color: AppColors.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.thisNeedsMoreThanAWorkoutChange,
                  style: AppText.titleM,
                ),
              ),
            ],
          ),
          Text(
            l10n.severeOrUnusualPainDeservesMedicalAdvice,
            style: AppText.bodyM,
          ),
          // The route to care. There is no maps intent: this comment claimed
          // one was wired, and what the router actually hands `onFindCare` is
          // `showHonestNotice(weDoNotHaveACareDirectory)`. Nothing in `lib/`
          // opens a map.
          //
          // The missing piece is CONTENT, not capability. `CareDirectory
          // .bundled` needs a clinically reviewed Egyptian list (OQ-11), and
          // `P0-CYC-07`/`P0-CYC-08` cannot pass until one is authored. The
          // button is drawn and says what is missing, rather than being hidden,
          // because a woman reaching this card in severe pain should not be
          // shown a screen that is quietly one option shorter.
          AppButton(
            l10n.findCareNearYou,
            height: 48,
            fontSize: 15,
            onPressed: onFindCare,
          ),
          if (suppressed.careRoute.hasFallback)
            // Unreachable today, deliberately. Rendering an empty list here
            // would read as "there is no care", which is worse than the
            // honest absence of the fallback.
            const SizedBox.shrink(),
          AppButton(
            l10n.readNhsGuidanceOnPeriodPain,
            variant: AppButtonVariant.outlined,
            height: 44,
            fontSize: 15,
            onPressed: onReadGuidance,
          ),
        ],
      ),
      Text(
        l10n.weAreNotSuggestingAWorkoutToday,
        style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
      ),
      // The rest row carries **no subtitle**.
      //
      // The design's line is "Marked as planned rest, it costs you nothing",
      // and `DECISIONS.md` D5a requires a capped
      // `WeeklyGoalService.markPlannedRest(date)` to make it true. That method
      // exists nowhere: G6 publishes no such API, and resting here currently
      // costs her the week's adherence. G9 OQ-7: "A false promise on the
      // severe-symptom screen is the worst place in the product to have one."
      //
      // So the row offers rest and says nothing about what it costs, until
      // something can make the sentence true.
      AppListItem(
        leading: const Icon(
          Icons.self_improvement,
          size: 22,
          color: AppColors.onSurfaceVariant,
        ),
        title: l10n.restToday,
        trailing: const Icon(
          Icons.chevron_right,
          size: 22,
          color: AppColors.onSurfaceVariant,
        ),
        onTap: onRest,
      ),
    ];
  }

  // ---------------------------------------------------------------- Y14 ----

  /// Y03 reached with no `cycle/current` document.
  ///
  /// **This rendered `SizedBox.shrink()`**: a title, a settings gear, and an
  /// entirely empty screen between them. §3.1's `notSetUp` makes My cycle
  /// invisible *everywhere else* — which is why Home's row is gated on it — but
  /// that is not the same as a blank screen being an acceptable destination.
  /// My profile links here unconditionally, so a woman who skipped setup got
  /// the "running, responsive and completely empty" page `main.dart` records as
  /// having shipped once already.
  ///
  /// No test caught it, and none could have: all 115 cycle tests supply a
  /// cycle, because a null one was understood as "this screen is not shown".
  /// A screenshot caught it in one look.
  ///
  /// Every string here already exists — Y01's own heading, its subtitle and its
  /// first option — so the empty state says what the feature is and offers the
  /// single action that makes it true, without inventing copy.
  List<Widget> _notSetUp(BuildContext context, AppL10n l10n) {
    return [
      const SizedBox(height: 18),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: HandUnderline(
          level: HandLevel.expressive,
          drawOn: true,
          child: Text(l10n.makeItWorkForYou, style: EditorialType.section),
        ),
      ),
      Text(
        l10n.youChooseWhatToLogYouCan,
        style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
      ),
      // Written in the margin, pointing back at the line above: what she
      // logs here is hers alone. True for every woman — cycle data is
      // private by default and never shown to a coach.
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HandArrow(
            width: 44,
            height: 30,
            from: Offset(0.1, 0.95),
            to: Offset(0.85, 0.1),
            bend: -0.3,
            seed: 19,
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: HandNote(l10n.private, size: 18, decorative: true),
          ),
        ],
      ),
      const AppSpacer(),
    ];
  }

  /// Y14 offered **no gentler option at all**.
  ///
  /// A woman in symptom-only mode could check in as having no energy and
  /// moderate cramps, and this branch would draw her planned session and the
  /// line "Nothing changes until you tell us how you feel" — which she just
  /// had. Symptom-only is the path chosen by a woman who does not want to log
  /// dates, and nothing about that choice says she wants less help on a bad
  /// day: §2.4's rule is that suggestions follow the symptoms she logged, and
  /// those are the only thing this mode collects.
  ///
  /// So the card is the same card `_today` draws, from the same
  /// [GentlerOption], reaching the same Y06 and the same "Why this
  /// suggestion?" — there is no second adaptation model here and could not be:
  /// the branch reads [CycleHubSnapshot.suggestion] and cannot produce one.
  ///
  /// ## Where the consent for it is given
  ///
  /// `showGentlerCard` is gated on `adaptation.workoutSuggestions`, and a new
  /// document has every adaptation off (`CycleRepository.completeSetup` writes
  /// `CycleAdaptation.allOff` and takes no parameter that could write anything
  /// else). On the dates path Y02 asks the question — its switches render
  /// pre-ticked and saving answers it. **The symptom-only path never passes
  /// Y02**: Y01 sends her straight here. So the consent could not be given at
  /// all on this path, short of finding it in Y12's settings, and the card
  /// would have stayed hidden however she felt.
  ///
  /// Y14 therefore asks the question Y02 would have, with the same row and the
  /// same words, at the one place this path reaches. It is off until she turns
  /// it on — nothing adapts unasked — and the row goes once she has answered.
  List<Widget> _symptomsOnly(
    BuildContext context,
    AppL10n l10n,
    CycleHubSnapshot snapshot,
  ) {
    final suggestion = snapshot.suggestion;

    return [
      CycleTabs(
        active: CycleTab.today,
        // False here, always. Y14 has no calendar tab.
        showCalendar: snapshot.showCalendarTab,
        onSelect: onSelectCycleTab,
      ),
      // With no day to circle, the check-in is what guides the page, so its
      // heading is the one thing set large and underlined once.
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          HandUnderline(
            level: HandLevel.expressive,
            drawOn: true,
            gap: 4,
            // Hugs its longest line, so a wrapped heading is underlined
            // rather than ruled across the whole column.
            child: Text(
              l10n.yourCheckInGuidesToday,
              textWidthBasis: TextWidthBasis.longestLine,
              style: EditorialType.section,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.symptomOnlyModeNoDatesNoEstimates,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
      AppButton(l10n.howAreYouFeeling, icon: Icons.mood, onPressed: onCheckIn),
      // The same card, the same buttons and the same Y06 behind them as the
      // dates path gets. See the note above this method.
      if (snapshot.showGentlerCard &&
          suggestion is GentlerOption &&
          !gentlerDecided)
        _gentlerCard(l10n, suggestion),
      // Y02's question, asked where this path can actually reach it. Once she
      // has answered it, the gate is open and the row stops taking up space.
      if (!snapshot.workoutSuggestionsOn)
        _askToAdapt(l10n, snapshot.workoutSuggestionsOn),
      AppCard(
        children: [
          Text(l10n.yourPlannedWorkout, style: AppText.titleM),
          AppListItem(
            variant: AppCardVariant.filled,
            leading: const Icon(
              Icons.fitness_center,
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: l10n.fullBodyStrength35Min_1jwg4,
            // The credit belongs to whoever wrote the session. With no
            // coaching in this build nobody did, so the row names the
            // session and claims nothing about its author.
            subtitle: AppRouter.featureFlags.isOn(Feature.coachedLife)
                ? l10n.fromYourCoachUnchanged
                : '',
          ),
          Text(
            l10n.nothingChangesUntilYouTellUsHow,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
      AppListItem(
        leading: const Icon(
          Icons.calendar_month,
          size: 22,
          color: AppColors.primaryDim,
        ),
        title: l10n.addPeriodDates,
        subtitle: l10n.onlyIfYouWantEstimatesLater,
        trailing: const Icon(
          Icons.chevron_right,
          size: 22,
          color: AppColors.onSurfaceVariant,
        ),
        onTap: onAddDates,
      ),
      AppSageNote(l10n.irregularCyclesHormonalContraceptionAndPerimenop),
    ];
  }

  /// "Show workout suggestions" — Y02's row, on the path that never sees Y02.
  ///
  /// The same title and the same switch component Y02 and Y12 use, so this is
  /// recognisably the one setting and not a second one. Off until she turns it
  /// on: the product does not adapt her training without being asked, and this
  /// is the asking.
  Widget _askToAdapt(AppL10n l10n, bool value) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      children: [
        CycleSwitchRow(
          title: l10n.showWorkoutSuggestions,
          trailing: AppToggle(
            value: value,
            semanticLabel: l10n.showWorkoutSuggestions,
            onChanged: (on) => onSetWorkoutSuggestions?.call(on),
          ),
        ),
      ],
    );
  }
}
