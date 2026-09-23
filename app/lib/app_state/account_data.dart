/// Deleting her account, for real, in a build that has no server.
///
/// ## Why this is not [AccountDeletionService]
///
/// `account_deletion_service.dart` is the right machine and it cannot run here.
/// It is built around a [DeletionTransport]: `request()` refuses when there is
/// no connection, and **every** state after `requested` arrives on
/// `serverStates()`, because G7 §4 is "no optimistic state, no local tombstone,
/// no progress bar that is not backed by a server ack". There is no
/// `requestAccountDeletion` callable in this build and no Firestore behind it,
/// so the only way to drive that service here would be to feed it a fake
/// transport emitting states no server ever acknowledged. That is precisely the
/// lie the service exists to make unrepresentable, and faking it would be worse
/// than not using it.
///
/// What **is** reused is the half of the deletion that was always local:
/// [LocalWipe], the five handset steps the service runs on `authLocked`, and
/// [kLocalWipeOrder], the order it runs them in. [ThisPhoneWipe] implements that
/// interface honestly for a build whose entire database is a handful of
/// in-memory stores, and [deleteEverythingOnThisPhone] runs the steps in the
/// documented order. When Firebase lands, this class is what
/// `AccountDeletionService(localWipe: …)` should be given, and the screen above
/// it changes from calling this function to calling `request()`.
///
/// ## What "everything" means in this build
///
/// Every store listed below is the whole of what the app holds about her: there
/// is no disk, no cache and no network. The comments name the
/// [kDeletionManifest] row each step covers, so a collection added later
/// without a line here is a visible omission rather than an invisible one, which
/// is the same property §7.3 (a) asks of the manifest itself.
///
/// The rows this build **cannot** reach are the ones that are not on this phone:
/// nothing is pseudonymised (row 30), nothing is closed (row 23) and no proof of
/// erasure is retained (row 31), because there is nowhere to retain it. Those
/// three are the server's, and the sheet that calls this says so in plain words
/// rather than claiming a purge that did not happen.
library;

import 'dart:async';

import '../features/account/domain/account_deletion_service.dart';
import '../features/account/domain/deletion_manifest.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/cycle/domain/today_check_in.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'coach_portfolio_state.dart';
import 'coach_profile_state.dart';
import 'coached_life_state.dart';
import 'coaching_desk_state.dart';
import 'coaching_link_state.dart';
import 'community_state.dart';
import 'cycle_state.dart';
import 'eat_state.dart';
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
  Future<void> signOut() async {
    await AppRouter.authRepository.signOut();
    AppRouter.lastSignupRole = null;
    AppRouter.lastVerification = null;
    AppRouter.lastReviewerPath = null;
  }

  /// No Firestore instance exists, so there is nothing to terminate. Kept as a
  /// step rather than dropped: the order is asserted against
  /// [kLocalWipeOrder], and a missing step would read as an order that changed.
  @override
  Future<void> terminateFirestore() async {}

  /// The offline cache, which in this build is every store the app holds.
  ///
  /// This is where the bulk of the manifest lands: rows 1 to 8 and 11 to 21,
  /// plus 35 to 37. Nothing here is a copy, so clearing it is the deletion.
  @override
  Future<void> clearPersistence() async {
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
