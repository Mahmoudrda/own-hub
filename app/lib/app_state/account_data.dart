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
import '../features/eat/data/recipe_sync.dart';
import '../features/train/domain/training_reminders.dart';
import '../features/signup/domain/legal_acceptance.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'cloud_store.dart';
import 'coach_portfolio_state.dart';
import 'coach_profile_state.dart';
import 'coached_life_state.dart';
import 'coaching_desk_state.dart';
import 'coaching_link_state.dart';
import 'community_state.dart';
import 'crash_consent.dart';
import 'cycle_state.dart';
import 'eat_state.dart';
import 'firebase_boot.dart';
import 'install_id.dart';
import 'pledge.dart';
import 'coach_invite_state.dart';
import 'role_state.dart';
import 'local_persistence.dart';
import 'onboarding_state.dart';
import 'workout_session_state.dart';

/// The five handset steps, done against the stores this build actually has.
///
/// Each method keeps the name the service gave it, so the order below reads the
/// same as `kLocalWipeOrder` and a future Firebase implementation replaces the
/// bodies rather than the shape.
class ThisPhoneWipe implements LocalWipe {
  const ThisPhoneWipe();

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
    AppRouter.lastSignupRole = null;
    RoleState.instance.reset();
    AppRouter.lastReviewerPath = null;
    await AppRouter.authRepository.signOut();
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

    // The legal acceptance waiting to reach the server, if any. It belongs to
    // the account being deleted.
    unawaited(PendingLegalAcceptance.erase().catchError((Object _) {}));

    // This installation's random id. A new account on this handset gets a
    // new one, so nothing links the two.
    unawaited(InstallId.erase().catchError((Object _) {}));

    // The recipe library her signed-in session fetched, and when it last
    // checked. Public content, but kept on this phone because of her
    // account, so a deleted account leaves neither behind.
    for (final key in kRecipeCacheKeys) {
      unawaited(
        PreferencesSnapshotStorage(key: key).erase().catchError((Object _) {}),
      );
    }

    // Rows 5, 13, 14 — her meals, her eating preferences, her meal plans.
    EatAppState.instance.reset();
    AppRouter.mealRepository.store.reset();

    // Row 4 — her sessions, and the sets inside them.
    WorkoutSessionState.instance.reset();
    AppRouter.trainRepository.reset();

    // Rows 2, 6, 32 — her weeks, her bests, her points. The ledger shares the
    // bests map by reference, so both are reset and neither is replaced.
    AppRouter.progressStore.reset();
    AppRouter.personalBestLedger.reset();

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
    // privacy and notification switches.
    AppRouter.intakeRepository.reset();
    OnboardingState.instance.cycleRowDismissed = false;
    // Her agreement to the community's rules. The server's copy goes with
    // users/{uid}/consents.
    PledgeState.instance.reset();
    // Her training reminders: the days she chose, and the ones the phone
    // has scheduled.
    ReminderState.instance.reset();
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
      AppRouter.dietaryRepository.read() == DietaryProfile.unasked;
}
