/// The setup walk, `O01` to `O05`: when it runs, and what her answers change.
///
/// The four questions were built, tested and then wired to nothing. Their only
/// door was `C16`, inside the switched-off sign-up flow, so on a real install
/// no woman was ever asked how many days a week she could train, how long she
/// had, what she owned or what the programme had to train around — and the app
/// imposed three sessions a week on every one of them, because
/// `WeeklyGoalService.setTarget` had no call site anywhere in the product.
///
/// This file is that call site, and the one place that knows the walk is over.
///
/// ## Why the walk sits ON TOP of Home rather than instead of it
///
/// `main.dart` opens the first-run stack as `[T01, O01]`: Home underneath,
/// question one on top, both built before the first frame and neither animated
/// in. Three things fall out of that and none of them needed inventing:
///
///  * **Leaving setup is a pop.** Finishing, skipping and closing all land her
///    on the screen she came from, which is Home on a first launch and `A02`
///    when she reopened the questions from her profile. One rule, two entry
///    points, no flag to carry and no route to remember.
///  * **There is no way back into setup by accident.** The `O` routes are gone
///    from the history the moment she leaves them, so a back gesture on Home
///    cannot walk her into question four.
///  * **Home is honest by the time she sees it.** Every routed screen is
///    wrapped in a `RedrawOnChange` on `AppChanges`, so the bump at the end of
///    [finish] reaches the Home already sitting underneath. Home is covered at
///    that instant, so the redraw happens on the first frame of the pop that
///    uncovers it rather than while it is buried — which is the same thing from
///    where she is standing, and five screens cheaper. See
///    `lib/app_state/app_changes.dart`.
///
/// ## What her answers actually reach
///
/// Her goal, place, equipment, days, minutes and life stage are written to
/// [IntakeRepository] by each step as she goes — that part already worked. What
/// did not exist was anything downstream reading them. [finish] closes the one
/// gap that changes what she sees every day: the **weekly session target**,
/// which is the number Home and Progress count her week against.
///
/// The other four answers are recorded and, today, consumed only by `O05`'s own
/// programme preview (`selectStartingProgram`). There is nowhere honest to send
/// them yet: the programme catalogue holds a single entry with no authored
/// content (`starting_program.dart`), so filtering a session by her equipment
/// or her life stage would mean inventing the content it filtered. That is
/// reported rather than faked.
library;

import 'package:flutter/widgets.dart';

import '../domain/flags/feature_flags.dart';
import '../domain/rewards/weekly_goal_service.dart';
import '../domain/clock/app_clock.dart';
import '../features/onboarding/domain/intake.dart';
import '../features/today/domain/today_day.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import 'app_changes.dart';
import 'rewards_state.dart';
import 'role_state.dart';

/// Every setup screen. The order she meets them in is [setupWalk].
const List<String> kSetupScreenIds = [
  'O01',
  'O02',
  'O06',
  'O03',
  'O07',
  'O04',
  'O05',
];

/// The questions she is asked, one a screen, in order.
///
/// The full walk is her goal, where she trains, what she has at home (only
/// when home is part of it), days a week, minutes a session and what to train
/// around. The short "Your week" ([OnboardingState.shortSetup]) is the last
/// three. `O05`, her week read back, follows either and is not a question.
List<String> setupWalk(Intake intake, {required bool short}) => short
    ? const ['O03', 'O07', 'O04']
    : [
        'O01',
        'O02',
        if (intake.place != TrainingPlace.ladiesGym) 'O06',
        'O03',
        'O07',
        'O04',
      ];

/// Where [screenId] sits in the walk she is on: "2 of 6", and the bar.
({int step, int total}) setupProgress(String screenId, Intake intake) {
  final walk = setupWalk(intake, short: OnboardingState.instance.shortSetup);
  final at = walk.indexOf(screenId);
  return (step: at < 0 ? 1 : at + 1, total: walk.length);
}

class OnboardingState {
  OnboardingState._();

  static final OnboardingState instance = OnboardingState._();

  /// True when the walk was entered from the end of sign-up (`C16`), set
  /// there before `O01` opens, and cleared when she leaves the walk.
  bool enteredFromSignup = false;

  /// True while she is building her week before she has an account.
  ///
  /// Set by "Skip the tour and join" on `C01`, and by "Join Own Hub" and
  /// "Make it mine" in the tour (`C04`), each of which opens the short setup
  /// (`O03` with her life stage on it, then `O05`) ahead of the number and
  /// the check. Never set by the tour itself: looking around starts nothing. `O05` then ends in "Save my week and join" rather than in a
  /// workout the gate would refuse. Cleared once her code is accepted, and on
  /// sign-out.
  ///
  /// [isDue] does not read it. Finishing that short setup marks it done, so
  /// after verification the walk is not owed again.
  bool beforeSignup = false;

  /// True when `C13` sent a woman who had not built her week into the short
  /// setup after her check. Same two screens as [beforeSignup], ending in
  /// "Start day 1 now" over Home. Cleared whenever she leaves setup.
  bool shortSetupAfterSignup = false;

  /// True when she opened the short "Your week" from `C14` while a woman
  /// reviewer has her check. `O05` then ends in "Save my week" and goes back
  /// to `C14`: day one is behind the gate. Cleared whenever she leaves setup.
  bool whileWaiting = false;

  /// True once she said "Not now" to "Track my cycle" on day-one Home.
  ///
  /// Kept on the phone beside her setup answers (`app_snapshot.dart`) and
  /// cleared with them when she deletes everything.
  bool cycleRowDismissed = false;

  /// Whether `O03` is the one-screen "Your week", life stage included.
  bool get shortSetup => beforeSignup || shortSetupAfterSignup;

  /// Pure, and holds nothing: the goal it decides is assigned by [finish].
  static const WeeklyGoalService _goals = WeeklyGoalService();

  /// True while the four questions are still owed to her.
  ///
  /// With no account required, whenever setup is not done. With an account
  /// required, only once she is verified: before that `C16` hands her to
  /// `O01` at the end of registration. A verified woman whose setup is not
  /// done is one who came back on a new phone with the health backup off
  /// (N2): her life stage did not travel, so she is asked again at launch
  /// rather than given the standard programme.
  ///
  /// Never for a woman who only coaches (R1-P17): the four questions set up a
  /// trainee's week, and she opens on her own side instead.
  bool get isDue =>
      !AppRouter.intakeRepository.setupDone &&
      !(AppRouter.featureFlags.isOn(Feature.coachApp) &&
          RoleState.instance.coachOnly) &&
      (!AppRouter.featureFlags.isOn(Feature.accountRequired) ||
          AppRouter.isVerified);

  /// Records that the walk is over and applies what she answered.
  ///
  /// Called on every way out of setup, including the ones that answer nothing.
  /// Skipping is a designed path: every question preselects a valid answer, so
  /// a woman who closed at step one has a complete intake and the same right
  /// not to be asked again.
  ///
  /// Idempotent, which is what lets `A02`'s "Your training" row run the very
  /// same walk a month later: it re-applies whatever is stored rather than
  /// doing anything a second time.
  void finish() {
    shortSetupAfterSignup = false;
    whileWaiting = false;
    AppRouter.intakeRepository.markSetupDone();
    _applyWeeklyTarget(AppRouter.intakeRepository.read().days);
    AppChanges.bump();
  }

  /// Her days a week become the weekly session target. Her number, unclamped.
  ///
  /// This used to take `min(days, kMaxSessionsTarget)` in the open, because the
  /// two specs disagreed: `Intake.allowedDays` offered 2, 3, 4 and 5 while the
  /// cap was 4. The clamp was honest about itself and still wrong for her — she
  /// tapped 5, O05 read "Days a week: 5" back to her, and she was measured
  /// against 4 for ever after.
  ///
  /// The conflict is settled by the question, not by the cap: O03 no longer
  /// offers a 5, so every chip she can tap is a target `WeeklyGoalService` will
  /// accept and her answer reaches the goal whole. The service is still the
  /// only thing that decides, and a caller asking for seven is still refused
  /// rather than clamped — which is why this reads `decision.accepted` instead
  /// of assuming the write landed.
  void _applyWeeklyTarget(int days) {
    final decision = _goals.setTarget(AppRouter.progressStore.goal, days);
    if (!decision.accepted) return;
    AppRouter.progressStore.goal = decision.goal;
    // The week she is in follows her answer too. With no week document yet,
    // the new target is this week's. A lower target than the week started
    // with can count it there and then, and that pays the week once (D41); a
    // higher one waits for next week, because a week that has begun keeps the
    // target it started with.
    RewardsState.instance.retargetCurrentWeek(
      decision.goal.sessionsTarget,
      progress: AppRouter.progressStore,
    );
    // The target this week is actually measured against: the week document's
    // when there is one, so Home, R10 and the week's credit agree.
    final weekTarget =
        AppRouter.weekFromStore(AppClock.now())?.sessionsTarget ??
        decision.goal.sessionsTarget;

    // Home keeps its own copy of the week so it can draw offline, and that copy
    // is what "This week, 0 of 3" is read from. Updated through the repository's
    // own `restore`, carrying its two sets of memory back in untouched, because
    // nothing else in Today may be disturbed by a setup answer.
    final today = AppRouter.todayRepository;
    // With a week document, Today reads both numbers from it — one source.
    if (AppRouter.weekFromStore(AppClock.now()) != null) {
      today.refresh();
      return;
    }
    final day = today.day;
    if (day.week.sessionsTarget == weekTarget) return;
    today.restore(
      day: day.copyWith(
        week: WeekProgress(
          sessionsLogged: day.week.sessionsLogged,
          sessionsTarget: weekTarget,
          repairedByRestWeek: day.week.repairedByRestWeek,
        ),
      ),
      seenNotices: today.seenNotices,
      creditedSessions: today.creditedSessions,
    );
  }

  /// Leaves the walk, whichever step she is on, and lands her where she came
  /// from.
  ///
  /// Pops rather than pushing Home, so a woman who opened the questions from
  /// her profile goes back to her profile and a woman on her first launch goes
  /// back to Home. `route.isFirst` is the floor: the navigator is never emptied,
  /// whatever the history turns out to hold.
  ///
  /// Except after sign-up. There the screen she came from is `C16`, the
  /// pledge, with the whole sign-up stack under it; popping back to it would
  /// leave her on a screen she has already agreed to. So a walk entered from
  /// sign-up ([enteredFromSignup]) leaves to Home instead, with that stack
  /// cleared.
  void leaveSetup(BuildContext context) {
    if (enteredFromSignup) {
      leaveSetupToHome(context);
      return;
    }
    finish();
    final setupRoutes = {for (final id in kSetupScreenIds) appRoutes[id]!.name};
    Navigator.of(context).popUntil(
      (route) =>
          route.isFirst || !setupRoutes.contains(route.settings.name ?? ''),
    );
  }

  /// Leaves the walk for Home, with everything underneath cleared, and then
  /// opens [then] over Home if given.
  ///
  /// The way out of setup at the end of sign-up: the sign-up screens and the
  /// pledge are behind her, so nothing of them may stay in the history for a
  /// back gesture to find. "Start now" lands as `[T01, R03]`, so finishing
  /// day one goes back to Home rather than to the pledge.
  void leaveSetupToHome(
    BuildContext context, {
    String home = 'T01',
    String? then,
  }) {
    finish();
    enteredFromSignup = false;
    final navigator = Navigator.of(context);
    navigator.pushNamedAndRemoveUntil(appRoutes[home]!.name, (_) => false);
    if (then != null) navigator.pushNamed(appRoutes[then]!.name);
  }
}
