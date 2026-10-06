/// Where the day's state comes from, and where a log goes.
///
/// The interface is what the screens depend on; [InMemoryTodayRepository] is the
/// fake they are built and tested against until the Firestore implementation
/// lands. Keeping the screens on an interface is what lets T01–T08 be verified
/// without a network, an emulator or a signed-in account.
///
/// **Every method here is a commit, never a prompt.** There is no `confirm`
/// parameter and no `Future<bool>` gate anywhere in this file, because §2 rule 9
/// is undo rather than confirmation. The five-second window belongs to
/// [LogCommandBus], which holds the write and calls one of these methods only
/// once the window has closed.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../data/pending_answers.dart';
import '../../../domain/clock/app_clock.dart';
import '../../../domain/week/week_key.dart';
import 'today_day.dart';

/// The two notices T04 and T05 raise. Each is shown once per ISO week, which the
/// document key enforces structurally (plan G3 §1.2).
enum NoticeKind { quietWeek, tierSlip }

/// A session recalled from memory — T02's whole subject.
///
/// Note there are no set numbers on it. §2 rule 1: a prescribed value is never a
/// result, and a session recalled hours later copies last week's numbers rather
/// than recording new ones, so it can never set a personal best.
@immutable
class RecalledSession {
  const RecalledSession({required this.id, required this.title, this.minutes});

  /// Deterministic (spine C1), so a write replayed after reconnect collides with
  /// itself instead of logging a second session.
  final String id;

  final String title;

  /// Set for an activity that counts by time alone — a class, a walk.
  final int? minutes;
}

abstract class TodayRepository {
  /// The current day. Synchronous, because Today must render from cache on open
  /// rather than waiting for a network that may not be there.
  TodayDay get day;

  /// Whether "she has logged nothing" is a fact or only a silence.
  ///
  /// [day] answers out of memory whether anything has filled that memory or
  /// not, and `T06` turns its emptiness into the sentence "Day one". That
  /// sentence is wrong, briefly and confidently, for a woman signing in on a
  /// new handset while `CloudStore` is still pulling her year of training. See
  /// `lib/data/pending_answers.dart`.
  ///
  /// Concrete here rather than abstract because every implementation would
  /// write the same line: the question is about [day], which every one of them
  /// already answers.
  DataState get dataState => dataStateOf(holdsNothing: !day.arc.hasAnyLog);

  Stream<TodayDay> watch();

  /// Claims the walk her phone counted.
  Future<void> countWalk();

  /// Records a session she did without her phone.
  Future<void> logRecalledSession(RecalledSession session);

  /// Ticks one step of the first-week arc. Monotonic: a step never un-completes,
  /// so two devices cannot disagree destructively.
  Future<void> completeStep(FirstWeekStep step);

  /// Whether this week's notice has already been acknowledged.
  bool noticeSeen(NoticeKind kind, WeekKey week);

  /// Acknowledges it. Idempotent under replay — the week is part of the key.
  Future<void> markNoticeSeen(NoticeKind kind, WeekKey week);

  Future<void> dispose();
}

/// An in-memory [TodayRepository]. Real behaviour, no storage.
class InMemoryTodayRepository implements TodayRepository {
  /// Born on day one, holding nothing she did not do.
  ///
  /// The default used to be [defaultDay] — the prototype's Tuesday — so a woman
  /// who had just installed the app opened it on somebody else's week: a 32
  /// minute walk, week 3 of 8 of a programme she never chose, one session of
  /// three already ticked and a breakfast logged at 08:40. Every "withhold the
  /// figure rather than state it" guard elsewhere in this codebase was defeated
  /// by this one word.
  ///
  /// [defaultDay] is still here and unchanged, because the prototype
  /// screenshots and a dozen tests are drawn against it. It is now something a
  /// caller has to **ask** for by name rather than what a fresh install gets.
  ///
  /// A returning woman is not affected: `lib/app_state/local_persistence.dart`
  /// reads her snapshot before `runApp` and [restore] replaces this day
  /// wholesale. Day one is what she gets only when there is genuinely nothing
  /// stored.
  InMemoryTodayRepository({TodayDay? day, Set<String>? seenNotices})
    : _day = day ?? dayOne(),
      _seen = seenNotices ?? <String>{};

  /// The day T01 is drawn against in `6-v2/src/screens-today.mjs`: one session
  /// logged of three, a walk waiting to be counted, breakfast already logged.
  ///
  /// **Not what a real install gets** — see the constructor. Asked for by name
  /// by the tests and the gallery that are drawn against the prototype.
  ///
  /// The prototype's figures live **here**, in the fake, alongside the
  /// `sessionsLogged: 1` and the 08:40 that were already here — not in the
  /// dictionary. A number frozen into `app_en.arb` is told to every woman in
  /// both languages and cannot be replaced by anything she does; a number in
  /// this class is replaced wholesale the day the Firestore implementation
  /// lands, and the screens above it are already reading it as data.
  static TodayDay defaultDay({DateTime? date}) {
    final on = date ?? DateTime(2026, 9, 15, 9, 41);
    return TodayDay(
      date: on,
      state: DayState.nothingDone,
      arc: const FirstWeekArc(
        hasAnyLog: true,
        completed: {FirstWeekStep.logSet, FirstWeekStep.logMeal},
      ),
      week: const WeekProgress(sessionsLogged: 1, sessionsTarget: 3),
      walkToCount: true,
      walkMinutes: 32,
      mealLoggedAt: DateTime(on.year, on.month, on.day, 8, 40),
      plates: const [
        PlateSuggestion(foodId: 'ful_baladi', kcal: 410),
        PlateSuggestion(foodId: 'eggs_and_tea', kcal: 290),
      ],
      programWeek: 3,
      programTotalWeeks: 8,
    );
  }

  /// Day one: nothing logged, so T01 renders T06.
  ///
  /// The date defaults to **now**, not to the prototype's frozen Tuesday. Home's
  /// masthead names the day off this date, so a frozen one told a woman opening
  /// the app on a Thursday that it was Tuesday.
  static TodayDay dayOne({DateTime? date}) {
    final on = date ?? AppClock.now();
    return TodayDay(
      date: on,
      state: DayState.dayOne,
      arc: const FirstWeekArc(),
      week: const WeekProgress(sessionsLogged: 0, sessionsTarget: 3),
    );
  }

  TodayDay _day;
  final Set<String> _seen;

  /// Session ids already counted into the week above.
  final Set<String> _creditedSessions = <String>{};
  final StreamController<TodayDay> _days =
      StreamController<TodayDay>.broadcast();

  @override
  TodayDay get day => _day;

  @override
  DataState get dataState => dataStateOf(holdsNothing: !_day.arc.hasAnyLog);

  @override
  Stream<TodayDay> watch() => _days.stream;

  void _emit(TodayDay next) {
    _day = next;
    if (!_days.isClosed) _days.add(next);
  }

  @override
  Future<void> countWalk() async {
    _emit(
      _day.copyWith(
        walkToCount: false,
        arc: _day.arc.started,
        state: _day.state == DayState.dayOne ? DayState.inProgress : _day.state,
      ),
    );
  }

  @override
  Future<void> logRecalledSession(RecalledSession session) async {
    // Deduped by the deterministic session id, in the same set [recordSession]
    // uses, because these two methods do one job between them and a session may
    // reach Today down either path.
    //
    // The comment below used to promise this and the code did not do it:
    // `session.id` was documented as deterministic *for exactly this reason*
    // and never read. Measured on T02 — three taps on the same duration chip
    // logged the same `recalled-<date>-time30` three times, Home said "This
    // week, 3 of 3" and Progress said "1 of 3", because Progress credits
    // through `WorkoutSessionState.creditSession`, which does dedupe. Counted
    // weeks, banked rest weeks and tier standing all come off Progress, so Home
    // was promising a week the reward system was never going to honour.
    //
    // The day state still moves even on a replay: she did do the session, and
    // T02 arriving twice must not leave Home saying nothing is logged.
    final firstCredit = _creditedSessions.add(session.id);
    _emit(
      _day.copyWith(
        state: DayState.recalled,
        arc: _day.arc.started,
        week: firstCredit
            ? WeekProgress(
                // Optimistic week credit: the authoritative increment is a
                // Cloud Function on the session document and is late by design
                // when she is offline. The id is what makes the two agree once
                // the server catches up (plan G3 §4).
                sessionsLogged: _day.week.sessionsLogged + 1,
                sessionsTarget: _day.week.sessionsTarget,
                repairedByRestWeek: _day.week.repairedByRestWeek,
              )
            : _day.week,
      ),
    );
  }

  /// A meal she logged in Eat, so Today's meal card shows what she actually
  /// had rather than the guess it opened with. Called by the Eat wiring.
  void recordMeal({required DateTime at, List<PlateSuggestion>? plates}) {
    _emit(
      _day.copyWith(
        mealLoggedAt: at,
        plates: plates,
        arc: _day.arc.withStep(FirstWeekStep.logMeal).started,
        state: _day.state == DayState.dayOne ? DayState.inProgress : _day.state,
      ),
    );
  }

  /// Credits one finished session to Today's own copy of the week.
  ///
  /// Deduped by session id: Home keeps this copy so it can render offline,
  /// and a replay of the same session must not make her week look bigger than
  /// it is. The authoritative count is the week document in Progress.
  void recordSession(String sessionId) {
    if (!_creditedSessions.add(sessionId)) return;
    _emit(
      _day.copyWith(
        state: DayState.done,
        arc: _day.arc.withStep(FirstWeekStep.logSet).started,
        week: WeekProgress(
          sessionsLogged: _day.week.sessionsLogged + 1,
          sessionsTarget: _day.week.sessionsTarget,
          repairedByRestWeek: _day.week.repairedByRestWeek,
        ),
      ),
    );
  }

  /// Whether Today carries the My cycle row — true once she has set My cycle
  /// up. Called by the cycle wiring.
  void setShowCycleCard(bool show) {
    if (_day.showCycleCard == show) return;
    _emit(_day.copyWith(showCycleCard: show));
  }

  @override
  Future<void> completeStep(FirstWeekStep step) async {
    _emit(_day.copyWith(arc: _day.arc.withStep(step)));
  }

  String _key(NoticeKind kind, WeekKey week) => '${kind.name}-${week.id}';

  @override
  bool noticeSeen(NoticeKind kind, WeekKey week) =>
      _seen.contains(_key(kind, week));

  @override
  Future<void> markNoticeSeen(NoticeKind kind, WeekKey week) async {
    _seen.add(_key(kind, week));
  }

  /// The notices she has already been shown, as the snapshot keeps them.
  ///
  /// Unmodifiable: this is a window for the code that writes her day to the
  /// phone, not a second way in. See `lib/app_state/local_persistence.dart`.
  Set<String> get seenNotices => Set<String>.unmodifiable(_seen);

  /// The sessions already counted into the week above, as the snapshot keeps
  /// them. Restoring these is what stops a finished session being credited a
  /// second time the next time the app opens.
  Set<String> get creditedSessions =>
      Set<String>.unmodifiable(_creditedSessions);

  /// Puts back the day this repository held when the app was last closed.
  ///
  /// The mirror of [reset]: same three pieces of memory, filled instead of
  /// emptied. It emits, so a screen already listening draws her day rather than
  /// the fake's.
  void restore({
    required TodayDay day,
    Iterable<String> seenNotices = const <String>[],
    Iterable<String> creditedSessions = const <String>[],
  }) {
    _seen
      ..clear()
      ..addAll(seenNotices);
    _creditedSessions
      ..clear()
      ..addAll(creditedSessions);
    _emit(day);
  }

  /// Back to the day this repository was born with, holding nothing she did.
  ///
  /// Account deletion calls it (`lib/app_state/account_data.dart`). It is not a
  /// screen reset: `_seen` and `_creditedSessions` are the two places Today
  /// remembers her across a rebuild, and a deletion that left either behind
  /// would credit a session she no longer has.
  void reset({TodayDay? day}) {
    _seen.clear();
    _creditedSessions.clear();
    // Day one, for the same reason the constructor starts there: a woman who
    // has just deleted everything must not be handed the prototype's week back.
    _emit(day ?? dayOne());
  }

  @override
  Future<void> dispose() => _days.close();
}
