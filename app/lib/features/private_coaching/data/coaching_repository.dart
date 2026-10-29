/// Everything the app reads and does for private coaching, behind one door.
///
/// The real one is `FirestoreCoachingRepository`; tests use an in-memory
/// fake. Streams that fail emit a [CoachingFailure] as an error.
library;

import 'dart:typed_data';

import '../../train/domain/my_plan.dart';
import '../domain/approved_media.dart';
import '../domain/chat_message.dart';
import '../domain/coach_application.dart';
import '../domain/coach_money.dart';
import '../domain/coach_plan.dart';
import '../domain/coach_profile.dart';
import '../domain/coaching_contract.dart';
import '../domain/payments.dart';
import '../domain/portfolio_media.dart';
import '../domain/subscription.dart';

/// Where a coach's file goes under `coach-docs/{uid}/`. The server checks each
/// path named in an application against these folders.
enum CoachDocFolder {
  photo,
  education,
  certificates,
  testimonials,
  transformations,
  gallery,
  agreement,
}

abstract class CoachingRepository {
  /// The signed-in member, or null.
  String? get uid;

  // ---- Reads: coaches and packages

  /// Published coaches.
  Stream<List<CoachProfile>> watchPublishedCoaches();

  Stream<CoachProfile?> watchCoach(String coachUid);

  /// A coach's packages. Clients see the active ones; a coach asks for all of
  /// hers with `onlyActive: false`.
  Stream<List<CoachPackage>> watchPackages(
    String coachUid, {
    bool onlyActive = true,
  });

  /// A coach's approved photos and results, newest first.
  Stream<List<ApprovedMedia>> watchApprovedMedia(String coachUid);

  // ---- Reads: subscriptions

  Stream<List<Subscription>> watchMySubscriptionsAsClient();

  /// Open subscriptions only: the rules close a subscription to the coach
  /// once it ends. Her history of ended clients is the ledger.
  Stream<List<Subscription>> watchMySubscriptionsAsCoach();

  Stream<Subscription?> watchSubscription(String subId);

  Stream<List<LiveSession>> watchSessions(String subId);

  /// Relationships where she is the coach or the client.
  Stream<List<Relationship>> watchMyRelationships();

  // ---- Reads: chat

  /// The newest [CoachingLimits.messagePageSize] lines, newest first.
  Stream<List<ChatMessage>> watchMessages(String relId);

  /// The page of lines before [before], newest first. Empty at the start.
  Future<List<ChatMessage>> olderMessages(String relId, DateTime before);

  /// When she last read this chat.
  Stream<DateTime?> watchReadAt(String relId);

  // ---- Reads: plans, money, application

  Stream<List<CoachPlan>> watchMyCoachPlans();

  /// The plans she (as the coach) shared with [clientUid]: only her own, and
  /// only while the coaching is active.
  Stream<List<CoachPlan>> watchCoachPlansForClient(String clientUid);

  Stream<ReceivingAccounts?> watchReceivingAccounts();

  Stream<SellerDetails?> watchSellerDetails();

  Stream<Receipt?> watchMyReceipt(String subId);

  Stream<CoachApplication?> watchMyApplication();

  Stream<CoachPrivateSummary?> watchCoachPrivate();

  /// Her own price for each package, by package id (what she typed, before
  /// Own Hub's share). Only she can read it.
  Stream<Map<String, int>> watchMyPackagePrices();

  Stream<List<LedgerEntry>> watchLedger();

  Stream<List<Payout>> watchPayouts();

  Stream<List<CoachDraft>> watchDrafts();

  // ---- Member and coach callables

  Future<({ApplicationStatus status, int round})> submitCoachApplication(
    CoachApplication application, {
    required String locale,
  });

  /// Only the fields that are not null are sent.
  Future<void> updateCoachProfile({
    String? headline,
    String? approachText,
    String? photoPath,
    bool? acceptingClients,
    bool? autoAccept,
    int? maxActiveClients,
  });

  Future<PayoutAccountState?> requestPayoutAccountChange(
    CoachPayoutAccount account,
  );

  Future<({String packageId, int priceFinalEgp, int youReceiveEgp})>
  saveCoachPackage(PackageDraft draft);

  Future<({String subId, SubscriptionStatus status})> requestCoaching({
    required String coachUid,
    required String packageId,
    required Intake intake,
    required Map<String, Object?> consent,
    required String locale,
    String clientName = '',
    String? inviteCode,
  });

  Future<SubscriptionStatus> respondCoachingRequest({
    required String subId,
    required bool accept,
    CoachDeclineReason? declineReason,
  });

  Future<SubscriptionStatus> cancelCoachingRequest(String subId);

  /// Either side ends a coaching that costs nothing: a request becomes
  /// cancelled, a running coaching ended early.
  Future<SubscriptionStatus> endMyCoaching(String subId, {String? reason});

  Future<({String proofId, ProofStatus status})> submitPaymentProof({
    required String subId,
    required PaymentProofForm form,
    required String locale,
  });

  Future<({CancellationState state, int refundEgp})> requestCancellation({
    required String subId,
    String? reason,
  });

  Future<({String planId, int revision})> publishCoachPlan({
    required String subId,
    required String name,
    MyPlan? workout,
    MealPlanBody? meal,
    String? planId,
    String? startsOn,
  });

  Future<String> scheduleLiveSession({
    required String subId,
    required DateTime startsAt,
    required int minutes,
    required String link,
  });

  Future<SessionStatus> respondLiveSession({
    required String subId,
    required String sessionId,
    required bool confirm,
  });

  Future<({SessionStatus status, int sessionsUsed})> markSessionDone({
    required String subId,
    required String sessionId,
  });

  /// `coach` or `both`, only when she holds the coach claim.
  Future<void> recordSignupRole(String role);

  /// An approved coach accepts Coach Agreement v2.
  Future<void> acceptCoachTerms({required String locale});

  /// Her signed copy is in the bucket at [path]; Own Hub checks it.
  Future<void> submitCoachAgreement(String path);

  // ---- Direct writes (the rules fix the keys)

  /// Sends a text line. Screened first: a refused text throws
  /// `CoachingFailure.screened` and nothing is written.
  Future<void> sendText(String relId, String text);

  Future<void> sendRecipe(String relId, String recipeId);

  Future<void> markRead(String relId);

  /// Reports a coach's public profile: one write to `reports/{id}`. [reason]
  /// is one of `CoachingEnums.reportReasons`; [note] is optional.
  Future<void> reportCoachProfile({
    required String coachUid,
    required String reason,
    String note = '',
    required String locale,
  });

  /// Saves a draft; returns its id (new when [CoachDraft.id] is empty).
  Future<String> saveDraft(CoachDraft draft);

  Future<void> deleteDraft(String draftId);

  // ---- Portfolio photos and results (the coach's own)

  /// Her media items, newest first, whatever their status.
  Stream<List<PortfolioMedia>> watchMyPortfolioMedia();

  /// Adds an item; it waits for Own Hub's check. Returns its id.
  Future<String> addPortfolioMedia(MediaDraft draft);

  Future<void> removePortfolioMedia(String mediaId);

  /// She confirms her client agreed in writing, for an item that came from
  /// her application.
  Future<void> confirmMediaConsent(String mediaId, String consentPath);

  /// Uploads a file to `coach-docs/{uid}/{folder}/{random}.{ext}` in the
  /// personal bucket and returns the path.
  Future<String> uploadCoachDoc(
    CoachDocFolder folder,
    Uint8List bytes,
    String contentType,
  );
}
