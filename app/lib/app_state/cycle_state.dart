/// My cycle's session state, and the one place it reaches Home.
///
/// The cycle feature's documents live in `AppRouter.cycleRepository` and
/// `AppRouter.periodRepository`. What they cannot hold lives here:
///
///  * **Home's cycle card.** `TodayDay.showCycleCard` belongs to Today, and it
///    was never set, so the card never appeared for anyone. It now follows her
///    own "Show the cycle card on Home" switch (Y02 and Y12), and the switch is
///    on once she has set My cycle up — the same default Y02 pre-ticks — until
///    she turns it off.
///  * **Her check-ins this session**, by day. Y10 draws energy around period
///    starts from them; a single "today" value could only ever draw one bar.
///  * **What she decided about today's gentler option** ("Keep mine", or rest),
///    so the card stops asking once she has answered.
///  * **The month Y08 shows.**
///
/// In memory while the app is running, and written to the phone with
/// everything else — see `local_persistence.dart`. Call [changed] after any
/// write so open screens redraw; that is also the signal the snapshot is
/// saved on.
library;

import 'dart:async';

import '../features/cycle/domain/cycle_document.dart';
import '../features/cycle/domain/day_suggestion.dart';
import '../features/cycle/domain/symptom_context.dart';
import '../features/cycle/domain/symptom_suggestion_resolver.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';

class CycleAppState {
  CycleAppState._();

  static final CycleAppState instance = CycleAppState._();

  /// Her check-ins this session, keyed `yyyy-MM-dd`. Never prefilled.
  final Map<String, TodayCheckIn> _checkIns = <String, TodayCheckIn>{};

  /// The day she answered today's gentler option, or null.
  String? _decidedOn;

  /// True once she has set the Home switch herself, on Y02 or Y12. Until then
  /// setting up turns the card on, which is what Y02 pre-ticks.
  bool _homeCardChosen = false;

  /// Months back (negative) or forward from the current one, for Y08.
  int _monthOffset = 0;

  static String _today() => AppRouter.dayId(DateTime.now());

  /// Every check-in she has saved, today's included.
  Map<String, TodayCheckIn> get checkIns => <String, TodayCheckIn>{
    ..._checkIns,
    if (AppRouter.todayCheckIn != TodayCheckIn.absent)
      _today(): AppRouter.todayCheckIn,
  };

  /// The days Y08 marks as checked in.
  Set<String> get checkInDays => checkIns.keys.toSet();

  /// Whether she has already answered today's gentler option.
  bool get decidedToday => _decidedOn == _today();

  /// What she logged today, as the reason the resolver gives — the list Y05
  /// and Y06 read out. Empty when nothing was logged.
  List<LoggedSymptom> get todaysReason =>
      const SymptomSuggestionResolver().resolve(AppRouter.todayCheckIn).reason;

  /// True when today's check-in produced a gentler option.
  bool get gentlerOffered =>
      const SymptomSuggestionResolver().resolve(AppRouter.todayCheckIn)
          is GentlerOption;

  /// The month Y08 is showing.
  ({int year, int month}) shownMonth([DateTime? now]) {
    final at = now ?? DateTime.now();
    final shown = DateTime(at.year, at.month + _monthOffset);
    return (year: shown.year, month: shown.month);
  }

  /// Home follows her switch, and nothing else.
  void syncHome() {
    final cycle = AppRouter.cycleRepository.current;
    AppRouter.todayRepository.setShowCycleCard(
      cycle != null && cycle.adaptation.homeCard,
    );
  }

  /// Redraw every open screen from the new state.
  void changed() {
    syncHome();
    AppChanges.bump();
  }

  /// Y01 finished: My cycle exists. The Home card comes on unless she has
  /// already said otherwise.
  Future<void> afterSetUp() async {
    final repository = AppRouter.cycleRepository;
    final cycle = repository.current;
    if (cycle != null && !_homeCardChosen && !cycle.adaptation.homeCard) {
      await repository.setAdaptation(cycle.adaptation.copyWith(homeCard: true));
    }
    changed();
  }

  /// Y02 saved her preferences, the Home switch among them.
  void preferencesSaved() {
    _homeCardChosen = true;
    changed();
  }

  /// A Y12 switch changed.
  void adaptationChanged() {
    _homeCardChosen = true;
    changed();
  }

  /// Y10's "Offer an easier workout when I log low energy".
  Future<void> setEasierWhenLowEnergy(bool on) async {
    final repository = AppRouter.cycleRepository;
    final cycle = repository.current;
    if (cycle == null) return;
    await repository.setAdaptation(
      cycle.adaptation.copyWith(easierWhenLowEnergy: on),
    );
    changed();
  }

  /// Y12's "Symptom-only mode". Her length and periods are kept, so switching
  /// back later loses nothing.
  Future<void> switchToSymptomsOnly() async {
    final repository = AppRouter.cycleRepository;
    final cycle = repository.current;
    await repository.completeSetup(
      mode: CycleMode.symptomsOnly,
      contextFlags: cycle?.contextFlags ?? const <CycleContextFlag>{},
    );
    changed();
  }

  /// Y04 saved. A new check-in is a new question, so any earlier answer to
  /// the gentler option no longer applies.
  void saveCheckIn(TodayCheckIn checkIn) {
    AppRouter.todayCheckIn = checkIn;
    _checkIns[_today()] = checkIn;
    _decidedOn = null;
    changed();
  }

  /// "Keep mine", "Keep my workout" or "Rest today" on the gentler option.
  void decideToday() {
    _decidedOn = _today();
    changed();
  }

  /// Y12 deleted her cycle data. Check-ins are Today's and stay (G9 §3.5).
  void purged() {
    _homeCardChosen = false;
    _monthOffset = 0;
    changed();
  }

  void previousMonth() {
    _monthOffset--;
    AppChanges.bump();
  }

  void nextMonth() {
    _monthOffset++;
    AppChanges.bump();
  }

  /// The check-ins she has saved, without today's — the map as it is stored.
  ///
  /// [checkIns] folds in `AppRouter.todayCheckIn` for the screens; this is the
  /// raw map the storage layer writes. See
  /// `lib/app_state/local_persistence.dart`.
  Map<String, TodayCheckIn> get savedCheckIns =>
      Map<String, TodayCheckIn>.unmodifiable(_checkIns);

  /// The day she answered today's gentler option, or null.
  String? get decidedOn => _decidedOn;

  /// Whether she has set the Home switch herself.
  bool get homeCardChosen => _homeCardChosen;

  /// Puts back what this state held when the app was last closed.
  ///
  /// The month offset is not restored: it is where Y08 was scrolled to, not
  /// something she recorded, and opening on this month is the right place to
  /// start. The mirror of [reset], except that this one writes nothing to the
  /// cycle repository — the storage layer restores that document itself.
  void restore({
    Map<String, TodayCheckIn> checkIns = const <String, TodayCheckIn>{},
    String? decidedOn,
    bool homeCardChosen = false,
  }) {
    _checkIns
      ..clear()
      ..addAll(checkIns);
    _decidedOn = decidedOn;
    _homeCardChosen = homeCardChosen;
    _monthOffset = 0;
  }

  /// For tests: a woman who has never opened My cycle.
  void reset() {
    _checkIns.clear();
    _decidedOn = null;
    _homeCardChosen = false;
    _monthOffset = 0;
    AppRouter.todayCheckIn = TodayCheckIn.absent;
    unawaited(AppRouter.cycleRepository.purge());
    AppRouter.todayRepository.setShowCycleCard(false);
  }
}
