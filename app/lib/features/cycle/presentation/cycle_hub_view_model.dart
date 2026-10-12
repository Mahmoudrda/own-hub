/// What Y03 renders — including **Y11 and Y14, which are branches of it**.
///
/// HANDOFF rule 16, and plan §5: "Y11 and Y14 are states of the Y03 route, not
/// destinations; a navigation-graph test asserts no inbound edge to either."
/// That is the same arrangement `TodayView` uses for T06 and `EatView` for E09:
/// one route, and the branch chosen from the data.
///
/// [HubBranch] is where that decision lives. A widget reads the branch; it does
/// not re-derive it, and it cannot navigate to one.
///
/// ## Where the adaptation switch is applied, and where it is not
///
/// `SymptomSuggestionResolver.resolve` decides what today's symptoms warrant
/// from the check-in alone — it cannot see her settings, by design. This view
/// model then decides whether her settings let the result be *shown*:
///
///  * [GentlerOption] renders only when `adaptation.workoutSuggestions` is on.
///  * [Suppressed] renders **always**. It is never gated by a preference.
///
/// The second line is the one that matters. A woman who turned workout
/// suggestions off has not asked to be shown a workout on a day she logged
/// severe pain, and if suppression travelled through the same switch then
/// turning that switch off would turn suppression off with it — which is the
/// most dangerous defect this feature could ship.
library;

import 'package:meta/meta.dart';

import '../domain/cycle_document.dart';
import '../domain/day_suggestion.dart';
import '../domain/period_entry.dart';
import '../domain/symptom_context.dart';
import '../domain/symptom_suggestion_resolver.dart';
import '../domain/today_check_in.dart';

/// Which rendering of the Y03 route she is looking at.
enum HubBranch {
  /// Not set up. The hub is not reachable and T01 shows no cycle card.
  notSetUp,

  /// Y03 proper.
  today,

  /// **Y11** — severe symptoms. Medical guidance, a route to care, a rest row,
  /// and no workout anywhere on the screen.
  severe,

  /// **Y14** — symptom-only mode. No calendar tab, no estimate, no phase name.
  symptomsOnly,
}

/// Everything the hub needs for one render.
@immutable
class CycleHubSnapshot {
  const CycleHubSnapshot({
    required this.branch,
    required this.setupState,
    required this.suggestion,
    required this.symptoms,
    required this.showGentlerCard,
    required this.showMealSuggestions,
    required this.showCalendarTab,
    required this.showEstimates,
    required this.periodDay,
    this.workoutSuggestionsOn = false,
  });

  final HubBranch branch;
  final CycleSetupState setupState;

  /// Today's suggestion, from today's check-in and nothing else.
  final DaySuggestion suggestion;

  /// What she logged, for Y05's "What you logged" card.
  final SymptomContext symptoms;

  /// Whether the "A gentler option today" card may be drawn.
  ///
  /// False when `adaptation.workoutSuggestions` is off — and false on a severe
  /// day too, because there is no gentler option on a severe day at all.
  final bool showGentlerCard;

  /// Her answer to "Show workout suggestions" — the consent the card above is
  /// gated on.
  ///
  /// Carried separately because a screen has to be able to tell the two apart:
  /// "there is nothing to suggest today" is not the same state as "there is,
  /// and she has never been asked whether she wants it". Y14 asks; see
  /// `cycle_hub_view.dart`.
  final bool workoutSuggestionsOn;

  /// Whether the meal row may be drawn. Off on a severe day: Y11's note is
  /// "never a meal-based answer".
  final bool showMealSuggestions;

  /// Symptom-only mode has no calendar tab.
  final bool showCalendarTab;

  /// False in symptom-only mode and whenever a context flag removed
  /// forecasting.
  final bool showEstimates;

  /// "Period day 2", or **null** when there is no period to count from.
  ///
  /// Null in symptom-only mode always — there are no dates there to derive it
  /// from, which is why Y14 has no phase name and no estimate.
  final int? periodDay;

  /// True when no workout affordance may appear anywhere on the screen,
  /// including the Train entry row.
  ///
  /// Derived from the *type* rather than from a flag someone sets: it is true
  /// exactly when the suggestion is [Suppressed], and [Suppressed] has no
  /// workout field for a widget to reach even if this were wrong.
  bool get suppressesWorkout => suggestion is Suppressed;
}

class CycleHubViewModel {
  const CycleHubViewModel({this.resolver = const SymptomSuggestionResolver()});

  final SymptomSuggestionResolver resolver;

  /// Builds the hub.
  ///
  /// [checkIn] defaults to [TodayCheckIn.absent] rather than being nullable:
  /// "nothing logged today" is a value, and §3.3's first transition requires the
  /// reader never to fall back to yesterday's document. There is no parameter
  /// here that could carry yesterday's check-in.
  CycleHubSnapshot build({
    required CycleDocument? cycle,
    TodayCheckIn checkIn = TodayCheckIn.absent,
    List<PeriodEntry> periods = const <PeriodEntry>[],
    required DateTime today,
  }) {
    final setupState = resolveCycleSetupState(cycle);

    if (cycle == null) {
      return CycleHubSnapshot(
        branch: HubBranch.notSetUp,
        setupState: setupState,
        suggestion: const NoSuggestion(),
        symptoms: SymptomContext.none,
        showGentlerCard: false,
        showMealSuggestions: false,
        showCalendarTab: false,
        showEstimates: false,
        periodDay: null,
      );
    }

    // One parameter. See `symptom_suggestion_resolver.dart` — the date below is
    // used for the period-day *fact*, and is deliberately not reachable from
    // the call that produces the suggestion.
    final suggestion = resolver.resolve(checkIn);
    final isSevere = suggestion is Suppressed;
    final datesMode = cycle.mode == CycleMode.datesAndSymptoms;

    final branch = switch (true) {
      _ when isSevere => HubBranch.severe,
      _ when !datesMode => HubBranch.symptomsOnly,
      _ => HubBranch.today,
    };

    return CycleHubSnapshot(
      branch: branch,
      setupState: setupState,
      suggestion: suggestion,
      symptoms: SymptomContext.of(checkIn),
      // Gated by her setting — and never reached on a severe day, because a
      // severe day produces `Suppressed` and not `GentlerOption`.
      showGentlerCard:
          suggestion is GentlerOption && cycle.adaptation.workoutSuggestions,
      workoutSuggestionsOn: cycle.adaptation.workoutSuggestions,
      showMealSuggestions: !isSevere && cycle.adaptation.mealSuggestions,
      showCalendarTab: datesMode,
      showEstimates: ForecastPolicy.isEnabled(cycle),
      // Only computable in dates mode, and only from a period that actually
      // covers today. Y14 gets null, so "period day 2" is not a sentence it can
      // render.
      periodDay: datesMode ? _periodDayOn(periods, today) : null,
    );
  }

  int? _periodDayOn(List<PeriodEntry> periods, DateTime today) {
    for (final period in periods) {
      final day = period.dayNumberOn(today);
      if (day != null) return day;
    }
    return null;
  }
}
