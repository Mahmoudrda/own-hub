/// The getting started tips on this phone: when the series starts, what she
/// has done that settles a tip, and the one offer of notifications at `C13`.
///
/// What to schedule is decided by the pure `TipPlan`
/// (`features/train/domain/getting_started_tips.dart`) inside
/// [NotificationSync]; this file only gathers the facts it reads and notes
/// the moments that change them. Nothing here touches the network.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/clock/app_clock.dart';
import '../domain/flags/feature_flags.dart';
import '../features/onboarding/domain/intake.dart';
import '../features/signup/presentation/role_view.dart';
import '../features/train/domain/getting_started_tips.dart';
import '../features/train/domain/training_reminders.dart';
import '../features/train/presentation/notification_explainer.dart';
import '../l10n/app_l10n.dart';
import '../routing/app_router.dart';
import '../routing/app_routes.dart';
import 'app_changes.dart';
import 'first_gym_guide_state.dart';
import 'notification_sync.dart';
import 'reminder_scheduler.dart';
import 'tip_anchors.dart';

abstract final class GettingStarted {
  /// Screens whose opening settles a tip. Each is kept as a marker.
  static const Set<String> markedScreens = {'R15', 'E05', 'P06', 'R02'};

  /// How long `C13` or Home is on screen before the offer slides up, so it
  /// does not cover the moment she lands.
  static const Duration offerDelay = Duration(milliseconds: 1200);

  /// Whether the series may run at all: its switch lives with the reminders
  /// on `A01`, so with them off there is no way to stop it and it stays off.
  static bool get allowed =>
      AppRouter.featureFlags.isOn(Feature.trainingReminders);

  /// Who is signed in. Replaceable so a test can be someone.
  @visibleForTesting
  static String? Function() currentUid = () => AppRouter.signedInUid;

  /// Keeps the day she first landed under her account, so a sign-out (which
  /// resets her reminders) does not start the series again when she is back.
  /// Nothing without an account or before she has landed.
  static void keepAnchor() {
    final uid = currentUid();
    final anchor = ReminderState.instance.tips.anchorAt;
    if (uid != null && anchor != null) {
      TipAnchors.instance.rememberIfAbsent(uid, anchor);
    }
  }

  /// What settles a tip, from what this phone holds.
  static TipFacts facts() {
    final state = ReminderState.instance;
    final marks = state.tipMarks;
    final intake = AppRouter.intakeRepository;
    return TipFacts(
      loggedASession:
          state.lastSessionAt != null ||
          AppRouter.trainRepository.sessions.any((s) => s.completed),
      openedVideos: marks.contains('R15'),
      loggedAPhotoMeal: marks.contains(kPhotoMealMark),
      // Allergies, or the scan switched off: the tip would open a screen she
      // cannot use, so it never comes. Not verified is left out on purpose:
      // the series only starts for a verified woman, and a launch can read her
      // as unverified for a moment while her claim is read again, which would
      // settle the tip for good.
      cannotScanMeals:
          !AppRouter.screenIsOn('E12') || AppRouter.eatConstraints.hasAllergies,
      openedRecipes: marks.contains('E05'),
      trainsAtHomeOnly:
          intake.placeAnswered && intake.read().place == TrainingPlace.home,
      sawGymGuide: FirstGymGuideState.instance.seen,
      openedMuscles: marks.contains('P06'),
      openedProgram: marks.contains('R02'),
    );
  }

  /// Every route the router generates passes through here.
  ///
  /// Called while a route is being built, so nothing here notifies anyone
  /// synchronously: the snapshot and the schedule follow a moment later.
  static void routeOpened(String id) {
    final state = ReminderState.instance;
    var settles = false;
    var anchored = false;
    if (markedScreens.contains(id) && state.tipMarks.add(id)) {
      settles = state.tips.due.isNotEmpty;
    }
    final landing = id == 'C13' || id == 'T01';
    if (landing && AppRouter.isVerified) {
      // A coach who does not train lands on her own side; the tips are about
      // the trainee app.
      final trains =
          id == 'T01' || AppRouter.lastSignupRole != SignupRole.coach;
      final uid = currentUid();
      if (trains && state.tips.anchorAt == null) {
        // An account that landed on this phone before keeps the day it first
        // did: an old one ends the series at once, and a recent one carries
        // on where it was. Only an account new here starts it.
        final kept = uid == null ? null : TipAnchors.instance.anchorFor(uid);
        state.tips = kept != null
            ? TipSeries(anchorAt: kept)
            : state.tips.anchoredAt(AppClock.now());
        anchored = true;
      }
      if (trains) keepAnchor();
      if (trains && id == 'C13' && !state.tipsOffered) {
        state.tipsOfferDue = true;
      }
      _offerWhenDue();
    }
    if (anchored || settles) _settleSoon();
  }

  /// A photographed meal was saved.
  static void notePhotoMeal() {
    final state = ReminderState.instance;
    if (state.tipMarks.add(kPhotoMealMark) && state.tips.due.isNotEmpty) {
      _settleSoon();
    }
  }

  /// Something that settles a tip changed outside a route (the first-gym
  /// guide was shown): the tips still to come are worked out again.
  static void settled() {
    if (ReminderState.instance.tips.due.isNotEmpty) _settleSoon();
  }

  static void _settleSoon() {
    scheduleMicrotask(() {
      AppChanges.bump();
      unawaited(
        NotificationSync.reapplyLast(
          AppRouter.reminderScheduler,
          now: AppClock.now(),
        ),
      );
    });
  }

  static bool _offering = false;

  /// "Want a few tips and your workout reminders?", once, on `C13` or the
  /// first Home after it, and only while the phone has not been allowed to
  /// show notifications. Never on a phone that cannot show them.
  static void _offerWhenDue() {
    final state = ReminderState.instance;
    if (!state.tipsOfferDue || state.tipsOffered || _offering) return;
    if (state.permitted) {
      // Already answered yes, from the reminders: nothing to ask.
      state
        ..tipsOfferDue = false
        ..tipsOffered = true;
      return;
    }
    if (!allowed) return;
    if (AppRouter.reminderScheduler is NoReminderScheduler) return;
    _offering = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        Future<void>.delayed(
          offerDelay,
          _offer,
        ).whenComplete(() => _offering = false),
      );
    });
  }

  static Future<void> _offer() async {
    final navigator = AppRouter.navigatorKey?.currentState;
    final context = navigator?.overlay?.context;
    if (navigator == null || context == null || !context.mounted) return;
    final state = ReminderState.instance;
    if (!state.tipsOfferDue || state.tipsOffered || state.permitted) return;
    // Only over the screen she landed on. Somewhere else, it waits for the
    // next Home.
    String? top;
    navigator.popUntil((route) {
      top = route.settings.name;
      return true;
    });
    if (top != appRoutes['C13']!.name && top != appRoutes['T01']!.name) {
      return;
    }
    final l10n = AppL10n.of(context);
    state
      ..tipsOfferDue = false
      ..tipsOffered = true;
    AppChanges.bump();
    final go = await showNotificationExplainer(context, tips: true);
    if (go != true) return;
    // Saying no to the phone blocks nothing: A01 and the reminders offer
    // keep the way in.
    final permission = await AppRouter.reminderScheduler.requestPermission();
    if (permission != ReminderPermission.granted) return;
    state.permissionGranted = true;
    AppChanges.bump();
    await NotificationSync.reapply(
      AppRouter.reminderScheduler,
      AppRouter.reminderText(l10n),
      now: AppClock.now(),
    );
  }
}
