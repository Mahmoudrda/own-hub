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
///  * **Home is honest the instant she finishes.** Every routed screen is
///    wrapped in a `ListenableBuilder` on `AppChanges`, so the bump at the end
///    of [finish] redraws the Home already sitting underneath with her own
///    weekly target on it.
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
import '../features/today/domain/today_day.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import 'app_changes.dart';

/// The five setup screens, in the order she meets them.
const List<String> kSetupScreenIds = ['O01', 'O02', 'O03', 'O04', 'O05'];

class OnboardingState {
  OnboardingState._();

  static final OnboardingState instance = OnboardingState._();

  /// Pure, and holds nothing: the goal it decides is assigned by [finish].
  static const WeeklyGoalService _goals = WeeklyGoalService();

  /// True while the four questions are still owed to her.
  ///
  /// Only ever true where there is no sign-up to ask them inside. With an
  /// account required, `C16` hands her to `O01` at the end of registration and
  /// a second walk stacked on Home would be the same questions twice.
  bool get isDue =>
      !AppRouter.featureFlags.isOn(Feature.accountRequired) &&
      !AppRouter.intakeRepository.setupDone;

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

    // Home keeps its own copy of the week so it can draw offline, and that copy
    // is what "This week, 0 of 3" is read from. Updated through the repository's
    // own `restore`, carrying its two sets of memory back in untouched, because
    // nothing else in Today may be disturbed by a setup answer.
    final today = AppRouter.todayRepository;
    final day = today.day;
    if (day.week.sessionsTarget == decision.goal.sessionsTarget) return;
    today.restore(
      day: day.copyWith(
        week: WeekProgress(
          sessionsLogged: day.week.sessionsLogged,
          sessionsTarget: decision.goal.sessionsTarget,
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
  void leaveSetup(BuildContext context) {
    finish();
    final setupRoutes = {for (final id in kSetupScreenIds) appRoutes[id]!.name};
    Navigator.of(context).popUntil(
      (route) =>
          route.isFirst || !setupRoutes.contains(route.settings.name ?? ''),
    );
  }
}
