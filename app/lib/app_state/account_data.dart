/// Deleting her account, for real: on the server and on this phone.
///
/// ## Two halves, one order
///
/// [deleteAccount] is what A02's "Your data" sheet runs. With an account
/// signed in and Firebase up, it drives [AccountDeletionService] over the
/// real transport (`CallableDeletionTransport`, the `delete_account`
/// callable). The server purges every row of the deletion manifest, closes
/// the ID registry entry, pseudonymises reports, keeps a record that the
/// deletion happened, and deletes her Firebase Auth user last. The service
/// runs the handset half, [ThisPhoneWipe], when the server acknowledges
/// `authLocked`, in [kLocalWipeOrder]. Progress is only what the server
/// acknowledged (G7 §4): no optimistic state, no local tombstone.
///
/// With no account (or no Firebase), the phone is the whole of her data and
/// [deleteEverythingOnThisPhone] runs the same five steps on its own.
///
/// ## What survives, said on the sheet
///
/// Three rows survive on purpose and the sheet names them: the registry entry
/// for her ID card, closed so it cannot open another account (row 23); reports
/// with her uid replaced (row 30); and the record that the deletion happened
/// (row 31).
///
/// ## The handset steps
///
/// Every store listed below, plus the one document they are written to on the
/// handset, is the whole of what this PHONE holds about her. The comments name
/// the [kDeletionManifest] row each step covers, so a collection added later
/// without a line here is a visible omission rather than an invisible one.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../features/account/data/callable_deletion_transport.dart';
import '../features/account/domain/account_deletion_service.dart';
import '../features/account/domain/deletion_manifest.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/account/domain/health_backup.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../features/train/data/exercise_library_sync.dart'
    show kExerciseLibraryCacheKeys;
import '../features/train/data/workout_sync.dart' show kWorkoutCacheKeys;
import '../features/eat/data/recipe_sync.dart';
import '../features/train/domain/training_reminders.dart';
import 'first_gym_guide_state.dart';
import '../features/signup/domain/legal_acceptance.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'chosen_programme.dart';
import 'community_foods_state.dart';
import 'exercise_library_state.dart';
import 'workout_library_state.dart';
import 'cloud_store.dart';
import 'coach_portfolio_state.dart';
import 'coach_profile_state.dart';
import 'coached_life_state.dart';
import 'coaching_desk_state.dart';
import 'coaching_link_state.dart';
import 'community_state.dart';
import 'analytics_consent.dart';
import 'crash_consent.dart';
import 'first_run_moments.dart';
import 'kitten_setting.dart';
import 'custom_workout_state.dart';
import 'cycle_state.dart';
import 'eat_state.dart';
import 'meal_scan_state.dart';
import 'firebase_boot.dart';
import 'home_widget_sync.dart';
import 'install_id.dart';
import 'pledge.dart';
import 'coach_invite_state.dart';
import 'rewards_state.dart';
import 'role_state.dart';
import 'training_streak_state.dart';
import 'local_persistence.dart';
import 'snapshot_owner.dart';
import 'getting_started.dart';
import 'guest_session.dart';
import '../features/onboarding/domain/body_data.dart';
import 'onboarding_state.dart';
import 'tip_anchors.dart';
import 'workout_session_state.dart';
import 'follow_up_state.dart';

/// The five handset steps, done against the stores this build actually has.
///
/// Each method keeps the name the service gave it, so the order below reads the
/// same as `kLocalWipeOrder` and a future Firebase implementation replaces the
/// bodies rather than the shape.
class ThisPhoneWipe implements LocalWipe {
  const ThisPhoneWipe({this.keepsOwner = false, this.keepsSignUp = false});

  /// True when the wipe is for a different account signing in on this phone:
  /// the new account's owner record must survive it. Deleting an account
  /// leaves this false and forgets the owner with everything else.
  final bool keepsOwner;

  /// True when the wipe runs because a different account just signed in, so
  /// what the woman signing in did on the way there is hers and stays: the
  /// terms she accepted at `C06` (waiting to reach the server, read by `C07`'s
  /// reconcile), this installation's id her check is tied to, and the week she
  /// built before signing up. Her language is never erased. Only
  /// [SnapshotOwner] sets it.
  ///
  /// Her week is kept only when [OnboardingState.weekBuiltSignedOut] says it
  /// was built since the last sign-out. Sign-out leaves the previous woman's
  /// answers on the phone, her life stage among them, and those are not the
  /// next woman's to inherit.
  final bool keepsSignUp;

  /// Manifest row 29, as far as it reaches here. There is no Auth record to
  /// delete, so signing out is the whole of it, and it goes first for the
  /// reason the service gives: a session still alive can write back into what
  /// is about to be cleared.
  @override
  ///
  /// Every source of "she is verified" goes first (R2): the claim, the session
  /// result, the server state and this phone's memory of them. Left standing,
  /// the gate stayed open for the rest of the session after her account was
  /// gone.
  ///
  /// The fields are cleared synchronously inside the call; only the removal
  /// of the stored keys is left to finish on its own, on the same terms as
  /// the snapshot erase below: her deletion is never hostage to a platform
  /// call.
  Future<void> signOut() async {
    unawaited(AppRouter.forgetVerification());
    GuestSession.instance.exploring = false;
    AppRouter.lastSignupRole = null;
    RoleState.instance.reset();
    AppRouter.lastReviewerPath = null;
    // The day she first landed, kept by account before the reminders below
    // are reset, so signing back in does not start her tips again.
    GettingStarted.keepAnchor();
    await AppRouter.authRepository.signOut();
    unawaited(AppRouter.pushRegistrar.forget().catchError((Object _) {}));
    ReminderState.instance.reset();
    unawaited(AppRouter.reminderScheduler.cancel().catchError((Object _) {}));
    // The Home Screen and Lock Screen widgets go back to "Open Own Hub to
    // start". Not awaited, on the same terms as the snapshot erase below.
    unawaited(HomeWidgetSync.instance.clear());
  }

  /// Stops the sync, then stops Firestore and empties what it kept on disk.
  ///
  /// There IS a Firestore instance now (`lib/app_state/cloud_store.dart`), and
  /// two things it holds have to go. The first is the mutation queue: offline
  /// persistence is a durable queue, so a write she made a moment before
  /// deleting her account would otherwise leave the phone AFTER the deletion
  /// and recreate the documents the server just purged. The second is the read
  /// cache, which is a copy of her documents sitting on the handset.
  /// `terminate()` then `clearPersistence()` is the order the SDK requires —
  /// the cache cannot be cleared while the client is running.
  ///
  /// Guarded by [FirebaseBoot.isReady], which is false in every widget test and
  /// on a phone where Firebase never came up. Deleting her data must not be
  /// hostage to a backend she may not even have reached.
  @override
  Future<void> terminateFirestore() async {
    CloudStore.instance.stop();
    if (!FirebaseBoot.isReady) return;
    try {
      await FirebaseFirestore.instance.terminate();
      await FirebaseFirestore.instance.clearPersistence();
    } catch (_) {
      // A client that will not shut down is not a reason to leave her stores
      // full. The steps below are the ones she can see.
    }
  }

  /// The offline cache, which in this build is every store the app holds and
  /// the one document they are written to.
  ///
  /// This is where the bulk of the manifest lands: rows 1 to 8 and 11 to 21,
  /// plus 35 to 37. Nothing here is a copy, so clearing it is the deletion.
  @override
  Future<void> clearPersistence() async {
    // The snapshot on the handset, FIRST — and it is first for the same reason
    // signing out is: what is still on the phone can put back what is about to
    // be cleared. Without this line the stores below would be emptied, the
    // document on the phone would not, and everything she deleted would be
    // back the next time she opened the app.
    //
    // Not awaited, and that is deliberate. The half that has to happen in
    // order — cancelling the write that was already scheduled — happens
    // synchronously inside `erase`, before its first await. The removal itself
    // is a platform call, and her deletion must not be hostage to one: a store
    // that is slow, wedged or missing must still leave every store below empty
    // and the sheet still has to close and say so.
    unawaited(LocalPersistence.instance.erase());
    if (!keepsOwner) unawaited(SnapshotOwner.instance.forget());

    // The widgets' copy of her week in the App Group, for the same reason:
    // left behind, her count would stay on the Home Screen after the account
    // it belongs to is gone.
    unawaited(HomeWidgetSync.instance.clear());

    // The record of which of her documents the server has already accepted, for
    // the same reason and on the same terms. Left behind, a new account on this
    // handset would inherit a ledger claiming her documents were already
    // uploaded — and would never upload them.
    unawaited(CloudStore.instance.forget());

    // Her health backup choice. A new account on this handset starts from
    // the default, which is off: her health data stays on the phone.
    unawaited(HealthBackupPreference.instance.erase());

    // Her crash-report choice, back to off, and any report still waiting on
    // this phone deleted. A new account on this handset is asked again.
    unawaited(CrashConsent.instance.erase().catchError((Object _) {}));

    // Her usage-statistics choice, back to off, collection stopped and the
    // analytics instance id on this phone reset. Before the kitten below, so
    // putting the kitten back to its default is not itself counted.
    unawaited(AnalyticsConsent.instance.erase().catchError((Object _) {}));

    // Whether the kitten moves, back to the default.
    unawaited(KittenSetting.instance.erase());

    // The legal acceptance waiting to reach the server, if any. It belongs to
    // the account being deleted. On a change of account it is the one the
    // woman signing in gave at C06, and erasing it would race C07's reconcile
    // and ask her to agree a second time.
    if (!keepsSignUp) {
      unawaited(PendingLegalAcceptance.erase().catchError((Object _) {}));
    }

    // This installation's random id. A new account on this handset gets a
    // new one, so nothing links the two. On a change of account it is the one
    // her own check is running under, so it stays.
    if (!keepsSignUp) {
      unawaited(InstallId.erase().catchError((Object _) {}));
    }

    // The getting started tips each account has already been through, so a
    // woman signing back in is not walked through them again. Kept on a change
    // of account; deleting hers forgets them.
    if (!keepsOwner) {
      unawaited(TipAnchors.instance.erase().catchError((Object _) {}));
      // The deep breath and the promise tick are first-time moments of a
      // phone's owner; a deleted account leaves neither flag behind.
      unawaited(FirstRunMoments.instance.erase().catchError((Object _) {}));
    }

    // The recipe library her signed-in session fetched, and when it last
    // checked. Public content, but kept on this phone because of her
    // account, so a deleted account leaves neither behind.
    for (final key in kRecipeCacheKeys) {
      unawaited(
        PreferencesSnapshotStorage(key: key).erase().catchError((Object _) {}),
      );
    }
    // The workout library the same way, and the session she had chosen.
    for (final key in kWorkoutCacheKeys) {
      unawaited(
        PreferencesSnapshotStorage(key: key).erase().catchError((Object _) {}),
      );
    }
    WorkoutLibraryState.instance.chosenRowId = null;
    ChosenProgramme.reset();
    // Her own workouts, the ones she deleted and today's edits. The server
    // copies are the `splits` rows of the deletion manifest.
    CustomWorkoutState.instance.reset();
    // The exercise library: its cached catalogue, the clips kept on the phone
    // and the move she last opened. None of it is hers, and all of it goes.
    for (final key in kExerciseLibraryCacheKeys) {
      unawaited(
        PreferencesSnapshotStorage(key: key).erase().catchError((Object _) {}),
      );
    }
    unawaited(
      ExerciseLibraryState.instance.media.eraseAll().catchError((Object _) {}),
    );
    ExerciseLibraryState.instance.openExerciseId = null;
    // The shared foods cached on this phone and her choice to share hers.
    unawaited(CommunityFoodsState.instance.erase().catchError((Object _) {}));

    // Rows 5, 13, 14 — her meals, her eating preferences, her meal plans.
    EatAppState.instance.reset();
    AppRouter.mealRepository.store.reset();
    // The phone's memory that she agreed to meal photos, and any scan still
    // waiting to be checked. The record itself is on the server, under her
    // account, and goes with it.
    unawaited(MealScanState.instance.erase().catchError((Object _) {}));

    // Row 4 — her sessions, and the sets inside them.
    WorkoutSessionState.instance.reset();
    AppRouter.trainRepository.reset();

    // Rows 2, 6, 32 — her weeks, her bests, her points. The ledger shares the
    // bests map by reference, so both are reset and neither is replaced.
    AppRouter.progressStore.reset();
    AppRouter.personalBestLedger.reset();
    // The awards already paid and today's cap (D41), and her training streak
    // with its sessions per day (D37). Both live only on this phone.
    RewardsState.instance.reset();
    TrainingStreakState.instance.reset();
    // Her day-after answers, week reviews and follow-up settings. Phone only.
    FollowUpState.instance.reset();

    // Rows 35, 36 — her cycle document and every period date. `CycleState`
    // already purges the repository; it also takes Today's cycle row down.
    CycleAppState.instance.reset();

    // The community half: her posts, her comments, her saved tiles, her
    // activity and her graph. Covered by `posts/**` and `followGraph/{uid}` in
    // the rules rather than by a `users/{uid}` row.
    CommunityState.instance.reset();

    // Rows 16, 17, 18 — her blocks, and the exclusion list they maintain.
    AppRouter.blockService.reset();

    // Row 19 — the reports she filed. See `InMemoryReportService.reset` for
    // why a local delete is the only honest answer to row 30 here.
    AppRouter.reportService.reset();

    // Row 15 — her inbox.
    AppRouter.notificationsRepository.reset();

    // Row 1 — the maps on `users/{uid}`: her setup answers, her allergies, her
    // privacy and notification switches. The answers the woman signing in
    // gave before signing up are hers, and stay with the weekly target they
    // set.
    final keepsWeek =
        keepsSignUp && OnboardingState.instance.weekBuiltSignedOut;
    if (!keepsWeek) {
      AppRouter.intakeRepository.reset();
      BodyDataStore.instance.reset();
    }
    if (!keepsSignUp) OnboardingState.instance.weekBuiltSignedOut = false;
    // What she tried as a guest goes with the week it belonged to.
    if (!keepsWeek) GuestSession.instance.reset();
    OnboardingState.instance.cycleRowDismissed = false;
    // Her agreement to the community's rules. The server's copy goes with
    // users/{uid}/consents.
    PledgeState.instance.reset();
    // Her training reminders: the days she chose, and the ones the phone
    // has scheduled.
    ReminderState.instance.reset();
    unawaited(AppRouter.pushRegistrar.forget().catchError((Object _) {}));
    FirstGymGuideState.instance.reset();
    unawaited(AppRouter.reminderScheduler.cancel().catchError((Object _) {}));
    AppRouter.dietaryRepository.reset();
    AppRouter.privacyRepository.reset();

    // Today's own copy of her week. Not a manifest row of its own: it is a
    // projection of rows 2 and 4, and it has to go with them or Home renders a
    // session she no longer has.
    AppRouter.todayRepository.reset();
    AppRouter.todayCheckIn = TodayCheckIn.absent;

    // The coach side. She holds both roles in this build, so her portfolio, her
    // clients, her enquiries and her coached life are hers too.
    CoachProfileState.instance.reset();
    // Her roles and the code her coach sent: both kept on this phone.
    RoleState.instance.reset();
    CoachInviteState.instance.reset();
    CoachPortfolioState.instance.reset();
    CoachingLinkState.instance.reset();
    CoachingDeskState.instance.reset();
    CoachedLifeState.instance.reset();

    _forgetWhereSheWas();

    // Her weekly target follows her answers, as finishing setup made it.
    if (keepsWeek && AppRouter.intakeRepository.setupDone) {
      OnboardingState.instance.reapplyWeeklyTarget();
    }
  }

  /// Manifest row 33. The measurements live in the progress store here and are
  /// already cleared above; this step is what a Firebase build wires to
  /// `MeasurementsRepository.purgeLocal()`, and it is kept so that the
  /// on-device rows are not silently folded into the cache clear.
  @override
  Future<void> purgeLocalMeasurements() async {
    AppRouter.progressStore.measurements.clear();
  }

  /// Manifest row 34. There is no encrypted photo store in this build and no
  /// key to destroy, because there is no camera and nothing has ever been
  /// captured. When one exists, this is the step that destroys its key.
  @override
  Future<void> destroyPhotoStoreKey() async {}

  /// Every static that points at something she made.
  ///
  /// These are not documents, they are the router's memory of which post,
  /// which group and which coach she last opened. Left behind, they aim
  /// screens at ids that no longer exist.
  void _forgetWhereSheWas() {
    AppRouter.communityOpenPostId = null;
    AppRouter.communityOpenGroupId = null;
    AppRouter.communityOpenProfileUid = AppRouter.communityStore.selfUid;
    AppRouter.communityFollowUpParentId = null;
    AppRouter.communityTopic = null;
    AppRouter.communitySavedFilter = 0;
    AppRouter.communityProfileTab = 0;
    AppRouter.communitySafetySubject = '';
    AppRouter.communitySafetyUid = '';
    AppRouter.communitySafetyInGroup = false;
    AppRouter.marketplaceOpenCoachUid = '';
    AppRouter.marketplaceSelectedOfferId = null;
    AppRouter.coachOpenRelId = '';
    AppRouter.coachPlanOpenDayKey = null;
    AppRouter.coachPlanWeekIndex = 0;
    AppRouter.coachPlanOpenSplit = null;
    AppRouter.lastSwappedFor = null;
    AppRouter.lastRecallOutcome = null;
  }
}

/// Deletes everything this build holds about her, in [kLocalWipeOrder].
///
/// Returns when the app is back to the state it boots in. It notifies once, at
/// the end, so every open screen redraws from empty rather than from a store
/// that is half cleared.
Future<void> deleteEverythingOnThisPhone({
  LocalWipe wipe = const ThisPhoneWipe(),
}) async {
  // The order is the service's, not a new one. Sign out first, because a live
  // session can write back into what is about to be cleared; the key last,
  // because wiping ciphertext while leaving the key is not deletion.
  await wipe.signOut();
  await wipe.terminateFirestore();
  await wipe.clearPersistence();
  await wipe.purgeLocalMeasurements();
  await wipe.destroyPhotoStoreKey();
  AppChanges.bump();
}

/// Deletes her account: on the server when there is one, and always on this
/// phone once the server has it.
///
/// * No account, or no Firebase: this phone is the whole of it, so it is
///   cleared and the answer is [AccountDeletionResult.done].
/// * The server reports `done`: the service has already wiped this phone on
///   `authLocked`; the stores are cleared once more and redrawn. `done`.
/// * No connection, or App Check refuses this copy of the app: nothing was
///   deleted anywhere and nothing here is touched.
/// * The server has it and did not finish: its sweeper will. This phone is
///   cleared now, and she is told it will finish, never that it is done.
Future<AccountDeletionResult> deleteAccount({
  DeletionTransport? transport,
  LocalWipe wipe = const ThisPhoneWipe(),
  Future<void> Function() quiesce = quiesceCloudWrites,
}) async {
  final signedIn = AppRouter.signedInUid != null;
  final realTransport =
      transport ??
      (FirebaseBoot.isReady && signedIn
          ? CallableDeletionTransport(
              isOnline: () =>
                  FirebaseBoot.isReady && AppRouter.signedInUid != null,
            )
          : null);
  if (realTransport == null) {
    await deleteEverythingOnThisPhone(wipe: wipe);
    return AccountDeletionResult.done;
  }

  // N9: offline there is nothing to stop and nothing will be deleted, so the
  // phone is left exactly as it is.
  if (!realTransport.online) return AccountDeletionResult.offline;
  // N9: before the server purges, no write may still be able to leave this
  // phone. A queued Firestore write that synced after the purge would
  // recreate users/{uid}. So the sync stops and the offline queue is
  // cleared first. (The server also sweeps a second time.)
  await quiesce();

  final service = AccountDeletionService(
    transport: realTransport,
    localWipe: wipe,
  );
  final finished = service.states.firstWhere(
    (state) =>
        state == DeletionState.done || state == DeletionState.failedRetryable,
  );
  // Awaited only on the accepted path; elsewhere its "no element" on
  // dispose must not surface as an unhandled error.
  finished.ignore();
  try {
    final outcome = await service.request();
    if (outcome == DeletionOutcome.refusedOffline) {
      return AccountDeletionResult.offline;
    }
    final last = await finished.timeout(const Duration(seconds: 30));
    // Once more, in full: the stores the service's wipe reached are cleared
    // already, and this redraws every screen from empty.
    await deleteEverythingOnThisPhone(wipe: wipe);
    return last == DeletionState.done
        ? AccountDeletionResult.done
        : AccountDeletionResult.unfinished;
  } on DeletionOffline {
    return AccountDeletionResult.offline;
  } on DeletionAppCannotReach {
    return AccountDeletionResult.appCannotReach;
  } on DeletionSignInAgain {
    return AccountDeletionResult.signInAgain;
  } catch (_) {
    // The server has the request (DeletionUnfinished, or a journal that did
    // not reach `done` in time). Her account is locked there and the sweeper
    // finishes it, so this phone is cleared now.
    await deleteEverythingOnThisPhone(wipe: wipe);
    return AccountDeletionResult.unfinished;
  } finally {
    unawaited(service.dispose());
  }
}

/// Stops every client write before `delete_account` runs (N9): the cloud
/// sync, then Firestore itself, then its offline queue and cache.
///
/// If the call then fails for want of a connection, nothing was deleted and
/// her data is still on this phone; the sync starts again at the next launch.
Future<void> quiesceCloudWrites() async {
  CloudStore.instance.stop();
  if (!FirebaseBoot.isReady) return;
  try {
    await FirebaseFirestore.instance.terminate();
    await FirebaseFirestore.instance.clearPersistence();
  } catch (_) {
    // A client that will not shut down must not block her deletion; the
    // server's second sweep covers a late write.
  }
}

/// The one thing a screen may say afterwards, and the reason it may.
///
/// True when nothing she made is left in any store this build holds. The sheet
/// does not consult it, because the wipe above is synchronous in effect and a
/// screen that re-checked would be describing a second read rather than the
/// deletion. The journey test consults it, which is where the claim belongs.
bool get nothingOfHersRemains {
  final store = AppRouter.communityStore;
  return store.posts.isEmpty &&
      store.saved.isEmpty &&
      store.activity.isEmpty &&
      store.graph.hiddenAuthors.isEmpty &&
      store.graph.followingKeys.isEmpty &&
      AppRouter.mealRepository.store.days.isEmpty &&
      AppRouter.progressStore.weeks.isEmpty &&
      AppRouter.progressStore.bests.isEmpty &&
      AppRouter.progressStore.measurements.isEmpty &&
      AppRouter.trainRepository.flushes.isEmpty &&
      AppRouter.cycleRepository.current == null &&
      AppRouter.cycleRepository.store.periods.isEmpty &&
      AppRouter.blockService.blocks().isEmpty &&
      AppRouter.reportService.reports().isEmpty &&
      AppRouter.dietaryRepository.read() == DietaryProfile.unasked &&
      RewardsState.instance.awardIds.isEmpty &&
      !TrainingStreakState.instance.touched &&
      !FollowUpState.instance.touched;
}
