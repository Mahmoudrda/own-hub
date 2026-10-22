/// The Dart half of `contracts/coaching_contract.json`.
///
/// Names stay close to the contract's. `test/contracts/coaching_contract_test.dart`
/// reads the JSON and fails when a limit, an enum value or a reason drifts, so
/// change the contract and this file together.
library;

import '../../../app_state/firebase_boot.dart' show kFunctionsRegion;
import 'parse.dart';

/// Every number the app uses, by the contract's key.
abstract final class CoachingLimits {
  static const int coachPriceMinEgp = 200;
  static const int coachPriceMaxEgp = 30000;
  static const int marginPercent = 15;
  static const int maxPackages = 6;
  static const List<int> durationDays = [28, 56, 84];
  static const int liveSessionsPerMonthMin = 2;
  static const int liveSessionsPerMonthMax = 12;
  static const List<int> sessionMinutes = [30, 45, 60];
  static const int checkInsPerWeekMax = 7;
  static const int includesMax = 8;
  static const int includeTextMax = 80;
  static const int packageTitleMax = 60;
  static const int packageDescriptionMax = 600;
  static const int maxActiveClientsDefault = 15;
  static const int maxActiveClientsMin = 1;
  static const int maxActiveClientsMax = 50;
  static const int requestAnswerHours = 72;
  static const int payByHours = 72;
  static const int proofAttempts = 3;
  static const int proofLongSidePx = 1600;
  static const int proofMaxBytes = 8000000;
  static const int nearImageHamming = 6;
  static const int nearImageWindow = 1000;
  static const int proofImageAlertDays = 7;
  static const int cancelWindowDays = 14;
  static const int payoutEligibleDays = 14;
  static const int refundWithinDays = 7;
  static const int endsSoonDays = 3;
  static const int messageMaxChars = 2000;
  static const int messagePageSize = 50;
  static const int pushThrottleMinutes = 3;
  static const int planMaxDays = 7;
  static const int planBodyMaxBytes = 60000;
  static const int planNameMax = 60;
  static const int noteMax = 500;
  static const int fullNameMax = 80;
  static const int displayNameMax = 40;
  static const int headlineMax = 120;
  static const int qualificationsMax = 1000;
  static const int approachTextMin = 50;
  static const int approachTextMax = 1500;
  static const int yearsExperienceMax = 50;
  static const int educationMin = 1;
  static const int educationMax = 6;
  static const int certificatesMin = 1;
  static const int certificatesMax = 10;
  static const int testimonialsMin = 2;
  static const int testimonialsMax = 10;
  static const int testimonialTextMax = 600;
  static const int transformationsMin = 1;
  static const int transformationsMax = 6;
  static const int specialtiesMin = 1;
  static const int specialtiesMax = 5;
  static const int uploadMaxBytes = 10000000;
  static const int matchResultsMax = 5;
  static const int reapplyAfterDays = 30;
  static const int mediaMaxItems = 30;
  static const int mediaPageSize = 25;
  static const int transformationWeeksMax = 104;
  static const int mediaNoteMax = 300;
  static const int mediaFeedbackTextMin = 10;
  static const int mediaFeedbackTextMax = 600;
  static const int mediaFromMax = 40;
  static const int mediaCaptionMax = 120;
  static const int mediaTermsVersion = 1;

  /// Every limit by its contract key, for the parity test.
  static const Map<String, Object> all = <String, Object>{
    'coachPriceMinEgp': coachPriceMinEgp,
    'coachPriceMaxEgp': coachPriceMaxEgp,
    'marginPercent': marginPercent,
    'maxPackages': maxPackages,
    'durationDays': durationDays,
    'liveSessionsPerMonthMin': liveSessionsPerMonthMin,
    'liveSessionsPerMonthMax': liveSessionsPerMonthMax,
    'sessionMinutes': sessionMinutes,
    'checkInsPerWeekMax': checkInsPerWeekMax,
    'includesMax': includesMax,
    'includeTextMax': includeTextMax,
    'packageTitleMax': packageTitleMax,
    'packageDescriptionMax': packageDescriptionMax,
    'maxActiveClientsDefault': maxActiveClientsDefault,
    'maxActiveClientsMin': maxActiveClientsMin,
    'maxActiveClientsMax': maxActiveClientsMax,
    'requestAnswerHours': requestAnswerHours,
    'payByHours': payByHours,
    'proofAttempts': proofAttempts,
    'proofLongSidePx': proofLongSidePx,
    'proofMaxBytes': proofMaxBytes,
    'nearImageHamming': nearImageHamming,
    'nearImageWindow': nearImageWindow,
    'proofImageAlertDays': proofImageAlertDays,
    'cancelWindowDays': cancelWindowDays,
    'payoutEligibleDays': payoutEligibleDays,
    'refundWithinDays': refundWithinDays,
    'endsSoonDays': endsSoonDays,
    'messageMaxChars': messageMaxChars,
    'messagePageSize': messagePageSize,
    'pushThrottleMinutes': pushThrottleMinutes,
    'planMaxDays': planMaxDays,
    'planBodyMaxBytes': planBodyMaxBytes,
    'planNameMax': planNameMax,
    'noteMax': noteMax,
    'fullNameMax': fullNameMax,
    'displayNameMax': displayNameMax,
    'headlineMax': headlineMax,
    'qualificationsMax': qualificationsMax,
    'approachTextMin': approachTextMin,
    'approachTextMax': approachTextMax,
    'yearsExperienceMax': yearsExperienceMax,
    'educationMin': educationMin,
    'educationMax': educationMax,
    'certificatesMin': certificatesMin,
    'certificatesMax': certificatesMax,
    'testimonialsMin': testimonialsMin,
    'testimonialsMax': testimonialsMax,
    'testimonialTextMax': testimonialTextMax,
    'transformationsMin': transformationsMin,
    'transformationsMax': transformationsMax,
    'specialtiesMin': specialtiesMin,
    'specialtiesMax': specialtiesMax,
    'uploadMaxBytes': uploadMaxBytes,
    'matchResultsMax': matchResultsMax,
    'reapplyAfterDays': reapplyAfterDays,
    'mediaMaxItems': mediaMaxItems,
    'mediaPageSize': mediaPageSize,
    'transformationWeeksMax': transformationWeeksMax,
    'mediaNoteMax': mediaNoteMax,
    'mediaFeedbackTextMin': mediaFeedbackTextMin,
    'mediaFeedbackTextMax': mediaFeedbackTextMax,
    'mediaFromMax': mediaFromMax,
    'mediaCaptionMax': mediaCaptionMax,
    'mediaTermsVersion': mediaTermsVersion,
  };
}

/// The contract's `enums` block, value for value, as wire strings.
abstract final class CoachingEnums {
  static const List<String> applicationStatus = <String>[
    'submitted',
    'needs_changes',
    'approved',
    'rejected',
  ];
  static const List<String> applicationDecision = <String>[
    'approve',
    'needs_changes',
    'reject',
  ];
  static const List<String> applicationSections = <String>[
    'personal',
    'education',
    'certificates',
    'specialties',
    'feedback',
    'transformations',
    'approach',
    'payout',
    'terms',
  ];
  static const List<String> sectionReasons = <String>[
    'missing',
    'unclear',
    'unverifiable',
    'not_allowed',
    'other',
  ];
  static const List<String> coachV = <String>['active', 'suspended'];
  static const List<String> specialties = <String>[
    'strength',
    'fatLoss',
    'muscleGain',
    'beginners',
    'homeTraining',
    'gymTraining',
    'mobility',
    'postnatalReturn',
    'healthyEating',
    'endurance',
  ];
  static const List<String> languages = <String>['ar', 'en'];
  static const List<String> trainsWhere = <String>['home', 'gym', 'online'];
  static const List<int> replyHours = [4, 12, 24, 48];
  static const List<String> coachRules = <String>[
    'accurateInfo',
    'clientPhotoConsent',
    'noOffPlatformPayment',
  ];
  static const List<String> testimonialSource = <String>[
    'whatsapp',
    'instagram',
    'inPerson',
    'other',
  ];
  static const List<String> governorates = <String>[
    'cairo',
    'giza',
    'alexandria',
    'qalyubia',
    'sharqia',
    'dakahlia',
    'gharbia',
    'monufia',
    'beheira',
    'kafrElSheikh',
    'damietta',
    'portSaid',
    'ismailia',
    'suez',
    'northSinai',
    'southSinai',
    'redSea',
    'matrouh',
    'faiyum',
    'beniSuef',
    'minya',
    'asyut',
    'sohag',
    'qena',
    'luxor',
    'aswan',
    'newValley',
  ];
  static const List<String> subscriptionStatus = <String>[
    'requested',
    'awaiting_payment',
    'payment_review',
    'active',
    'ended',
    'declined',
    'cancelled',
    'expired',
    'payment_failed',
    'ended_early',
  ];
  static const List<String> subscriptionOpen = <String>[
    'requested',
    'awaiting_payment',
    'payment_review',
    'active',
  ];
  static const List<String> requestDecision = <String>['accept', 'decline'];
  static const List<String> declineReasons = <String>[
    'full',
    'not_a_fit',
    'needs_doctor',
    'other',
  ];
  static const List<String> proofStatus = <String>[
    'pending',
    'approved',
    'rejected',
  ];
  static const List<String> proofDecision = <String>['approve', 'reject'];
  static const List<String> proofRejectReasons = <String>[
    'amount_wrong',
    'not_received',
    'unreadable',
    'wrong_account',
    'duplicate',
    'other',
  ];
  static const List<String> proofFlags = <String>[
    'duplicateReference',
    'sameImage',
    'nearImage',
    'amountDiffers',
    'paidBeforeAccept',
  ];
  static const List<String> cancellationState = <String>[
    'requested',
    'refunded',
    'declined',
  ];
  static const List<String> refundDecision = <String>['refund', 'decline'];
  static const List<String> ledgerStatus = <String>[
    'pending',
    'eligible',
    'paid',
    'reversed',
  ];
  static const List<String> payoutAccountState = <String>[
    'none',
    'confirmed',
    'pending',
    'rejected',
  ];
  static const List<String> relationshipStatus = <String>[
    'none',
    'active',
    'ended',
  ];
  static const List<String> messageTypeClient = <String>['text', 'recipe'];
  static const List<String> messageTypeServer = <String>[
    'workoutPlan',
    'mealPlan',
    'session',
    'system',
  ];
  static const List<String> systemMessageKinds = <String>[
    'started',
    'ended',
    'endsSoon',
    'planUpdated',
    'sessionConfirmed',
    'sessionDone',
    'hidden',
  ];
  static const List<String> planKind = <String>['workout', 'meal'];
  static const List<String> sessionStatus = <String>[
    'proposed',
    'confirmed',
    'declined',
    'done',
    'cancelled',
  ];
  static const List<String> sessionDecision = <String>['confirm', 'decline'];
  static const List<String> goals = <String>[
    'stronger',
    'buildMuscle',
    'loseSteadily',
    'feelBetter',
    'backIntoIt',
  ];
  static const List<String> levels = <String>[
    'beginner',
    'intermediate',
    'advanced',
  ];
  static const List<String> places = <String>['home', 'gym', 'both'];
  static const List<String> budgetBands = <String>[
    'under1500',
    'from1500to3000',
    'over3000',
  ];
  static const List<String> healthQuestions = <String>[
    'heart',
    'chestPain',
    'dizziness',
    'chronicCondition',
    'medication',
    'boneJoint',
    'supervisedOnly',
  ];
  static const List<String> mealSlots = <String>[
    'breakfast',
    'lunch',
    'dinner',
    'snack',
  ];
  static const List<String> mealItemKind = <String>['recipe', 'food', 'free'];
  static const List<String> reportSubjectKinds = <String>[
    'coachMessage',
    'coachProfile',
    'coachPlan',
  ];
  static const List<String> reportReasons = <String>[
    'harassment',
    'man_account',
    'nudity',
    'spam',
    'impersonation',
    'self_harm',
    'off_platform_payment',
    'unsafe_advice',
    'other',
  ];
  static const List<String> endReasons = <String>[
    'refund',
    'dispute',
    'coach_left',
    'client_left',
    'safety',
    'other',
  ];
  static const List<String> pushKinds = <String>[
    'coachDecision',
    'coachingRequest',
    'requestAnswered',
    'paymentApproved',
    'paymentRejected',
    'coachingStarted',
    'planShared',
    'newMessage',
    'sessionProposed',
    'endsSoon',
    'coachingEnded',
    'payoutRecorded',
    'portfolioDecision',
  ];
  static const List<String> reportDecision = <String>[
    'dismiss',
    'hide_message',
    'suspend_coach',
    'end_coaching',
  ];
  static const List<String> mediaKind = <String>[
    'transformation',
    'feedback',
    'photo',
  ];
  static const List<String> mediaStatus = <String>[
    'pending',
    'needsConsent',
    'approved',
    'rejected',
  ];
  static const List<String> mediaDecision = <String>['approve', 'reject'];
  static const List<String> mediaRejectReasons = <String>[
    'unclear',
    'not_allowed',
    'no_consent',
    'other',
  ];
  static const List<String> paymentState = <String>[
    'awaiting',
    'review',
    'rejected',
    'approved',
  ];

  static const Map<String, List<Object>> all = <String, List<Object>>{
    'applicationStatus': applicationStatus,
    'applicationDecision': applicationDecision,
    'applicationSections': applicationSections,
    'sectionReasons': sectionReasons,
    'coachV': coachV,
    'specialties': specialties,
    'languages': languages,
    'trainsWhere': trainsWhere,
    'replyHours': replyHours,
    'coachRules': coachRules,
    'testimonialSource': testimonialSource,
    'governorates': governorates,
    'subscriptionStatus': subscriptionStatus,
    'subscriptionOpen': subscriptionOpen,
    'requestDecision': requestDecision,
    'declineReasons': declineReasons,
    'proofStatus': proofStatus,
    'proofDecision': proofDecision,
    'proofRejectReasons': proofRejectReasons,
    'proofFlags': proofFlags,
    'cancellationState': cancellationState,
    'refundDecision': refundDecision,
    'ledgerStatus': ledgerStatus,
    'payoutAccountState': payoutAccountState,
    'relationshipStatus': relationshipStatus,
    'messageTypeClient': messageTypeClient,
    'messageTypeServer': messageTypeServer,
    'systemMessageKinds': systemMessageKinds,
    'planKind': planKind,
    'sessionStatus': sessionStatus,
    'sessionDecision': sessionDecision,
    'goals': goals,
    'levels': levels,
    'places': places,
    'budgetBands': budgetBands,
    'healthQuestions': healthQuestions,
    'mealSlots': mealSlots,
    'mealItemKind': mealItemKind,
    'reportSubjectKinds': reportSubjectKinds,
    'reportReasons': reportReasons,
    'endReasons': endReasons,
    'pushKinds': pushKinds,
    'reportDecision': reportDecision,
    'paymentState': paymentState,
    'mediaKind': mediaKind,
    'mediaStatus': mediaStatus,
    'mediaDecision': mediaDecision,
    'mediaRejectReasons': mediaRejectReasons,
  };
}

/// The contract's `rails`: how an account and a transfer reference look.
abstract final class CoachingRails {
  static const List<String> names = <String>['instapay', 'vodafoneCash'];
  static const Map<String, String> accountPattern = <String, String>{
    'instapay': r'^[a-z0-9._-]{3,40}@instapay$',
    'vodafoneCash': r'^010[0-9]{8}$',
  };
  static const Map<String, String> referencePattern = <String, String>{
    'instapay': r'^[A-Za-z0-9-]{6,40}$',
    'vodafoneCash': r'^[A-Za-z0-9-]{6,40}$',
  };
}

/// Callable names, identical to the server's.
abstract final class CoachingCallables {
  static const String submitCoachApplication = 'submit_coach_application';
  static const String listCoachApplications = 'list_coach_applications';
  static const String decideCoachApplication = 'decide_coach_application';
  static const String suspendCoach = 'suspend_coach';
  static const String updateCoachProfile = 'update_coach_profile';
  static const String requestPayoutAccountChange =
      'request_payout_account_change';
  static const String confirmPayoutAccount = 'confirm_payout_account';
  static const String saveCoachPackage = 'save_coach_package';
  static const String requestCoaching = 'request_coaching';
  static const String respondCoachingRequest = 'respond_coaching_request';
  static const String endMyCoaching = 'end_my_coaching';
  static const String cancelCoachingRequest = 'cancel_coaching_request';
  static const String markThreadRead = 'mark_thread_read';
  static const String addPortfolioMedia = 'add_portfolio_media';
  static const String removePortfolioMedia = 'remove_portfolio_media';
  static const String confirmPortfolioConsent = 'confirm_portfolio_consent';
  static const String listPortfolioMedia = 'list_portfolio_media';
  static const String decidePortfolioMedia = 'decide_portfolio_media';
  static const String submitPaymentProof = 'submit_payment_proof';
  static const String listPaymentProofs = 'list_payment_proofs';
  static const String decidePaymentProof = 'decide_payment_proof';
  static const String requestCancellation = 'request_cancellation';
  static const String listRefundRequests = 'list_refund_requests';
  static const String recordRefund = 'record_refund';
  static const String endCoaching = 'end_coaching';
  static const String listPayoutsOwed = 'list_payouts_owed';
  static const String recordCoachPayout = 'record_coach_payout';
  static const String getReceivingAccounts = 'get_receiving_accounts';
  static const String setReceivingAccounts = 'set_receiving_accounts';
  static const String setSellerDetails = 'set_seller_details';
  static const String publishCoachPlan = 'publish_coach_plan';
  static const String scheduleLiveSession = 'schedule_live_session';
  static const String respondLiveSession = 'respond_live_session';
  static const String markSessionDone = 'mark_session_done';
  static const String recordSignupRole = 'record_signup_role';
  static const String listCoachingReports = 'list_coaching_reports';
  static const String decideCoachingReport = 'decide_coaching_report';
  static const List<String> all = <String>[
    submitCoachApplication,
    listCoachApplications,
    decideCoachApplication,
    suspendCoach,
    updateCoachProfile,
    requestPayoutAccountChange,
    confirmPayoutAccount,
    saveCoachPackage,
    requestCoaching,
    respondCoachingRequest,
    endMyCoaching,
    cancelCoachingRequest,
    submitPaymentProof,
    listPaymentProofs,
    decidePaymentProof,
    requestCancellation,
    listRefundRequests,
    recordRefund,
    endCoaching,
    listPayoutsOwed,
    recordCoachPayout,
    getReceivingAccounts,
    setReceivingAccounts,
    setSellerDetails,
    publishCoachPlan,
    scheduleLiveSession,
    respondLiveSession,
    markSessionDone,
    recordSignupRole,
    listCoachingReports,
    decideCoachingReport,
    markThreadRead,
    addPortfolioMedia,
    removePortfolioMedia,
    confirmPortfolioConsent,
    listPortfolioMedia,
    decidePortfolioMedia,
  ];
}

/// Fixed ids and shapes.
abstract final class CoachingIds {
  static const String paymentCodePattern = r'^OH[0-9A-HJKMNP-TV-Z]{6}$';
  static const String paymentCodeAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const List<String> sessionLinkHosts = <String>[
    'meet.google.com',
    'zoom.us',
    '*.zoom.us',
    'teams.microsoft.com',
    'teams.live.com',
  ];
  static const String region = kFunctionsRegion;

  /// `{coachUid}__{clientUid}`
  static String relationshipId(String coachUid, String clientUid) =>
      '${coachUid}__$clientUid';
}

/// Why a coaching call or write did not go through. The app words each one.
enum CoachingRefusal {
  coachAppClosed('coach_app_closed'),
  notVerified('not_verified'),
  notACoach('not_a_coach'),
  badRequest('bad_request'),
  certificateNotUploaded('certificate_not_uploaded'),
  tooManyCertificates('too_many_certificates'),
  mediaNotFound('media_not_found'),
  tooManyMedia('too_many_media'),
  inviteInvalid('invite_invalid'),
  inviteExpired('invite_expired'),
  inviteOwn('invite_own'),
  alreadyACoach('already_a_coach'),
  applicationOpen('application_open'),
  applicationIncomplete('application_incomplete'),
  fileNotUploaded('file_not_uploaded'),
  applicationNotFound('application_not_found'),
  coachSuspended('coach_suspended'),
  coachUnavailable('coach_unavailable'),
  packageNotFound('package_not_found'),
  tooManyPackages('too_many_packages'),
  priceOutOfRange('price_out_of_range'),
  alreadyRequested('already_requested'),
  requestNotFound('request_not_found'),
  wrongStatus('wrong_status'),
  pastPayBy('past_pay_by'),
  referenceUsed('reference_used'),
  proofNotFound('proof_not_found'),
  attemptsExhausted('attempts_exhausted'),
  imageInvalid('image_invalid'),
  cancelWindowClosed('cancel_window_closed'),
  payoutAccountPending('payout_account_pending'),
  nothingOwed('nothing_owed'),
  accountsNotSet('accounts_not_set'),
  sellerNotSet('seller_not_set'),
  planInvalid('plan_invalid'),
  planTooLarge('plan_too_large'),
  sessionLinkInvalid('session_link_invalid'),
  sessionNotFound('session_not_found'),
  sessionNotStarted('session_not_started'),
  reportNotFound('report_not_found'),
  staffIsSubject('staff_is_subject'),

  /// Local: the text failed the chat screen before it was sent.
  messageBlocked('message_blocked'),

  /// Local: no connection, or the server did not answer in time.
  unreachable('unreachable'),

  /// Local: nobody is signed in.
  signedOut('signed_out'),

  /// A reason this build does not know.
  unknown('unknown');

  const CoachingRefusal(this.code);

  final String code;

  /// Reasons that exist only in the app. Everything else is the server's.
  static const Set<CoachingRefusal> localOnly = <CoachingRefusal>{
    messageBlocked,
    unreachable,
    signedOut,
    unknown,
  };

  /// Unknown or missing codes become [unknown]; this never throws.
  static CoachingRefusal fromCode(String? code) {
    if (code == null) return unknown;
    for (final value in values) {
      if (value.code == code) return value;
    }
    return unknown;
  }
}

/// Where a payment stands on a subscription.
enum PaymentStage with WireEnum {
  awaiting('awaiting'),
  review('review'),
  rejected('rejected'),
  approved('approved');

  const PaymentStage(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static PaymentStage? fromWire(Object? value) => enumFromWire(values, value);
}

/// Where a coach application stands.
enum ApplicationStatus with WireEnum {
  submitted('submitted'),
  needsChanges('needs_changes'),
  approved('approved'),
  rejected('rejected');

  const ApplicationStatus(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static ApplicationStatus? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// Where a subscription stands.
enum SubscriptionStatus with WireEnum {
  requested('requested'),
  awaitingPayment('awaiting_payment'),
  paymentReview('payment_review'),
  active('active'),
  ended('ended'),
  declined('declined'),
  cancelled('cancelled'),
  expired('expired'),
  paymentFailed('payment_failed'),
  endedEarly('ended_early');

  const SubscriptionStatus(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static SubscriptionStatus? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// Where a live session stands.
enum SessionStatus with WireEnum {
  proposed('proposed'),
  confirmed('confirmed'),
  declined('declined'),
  done('done'),
  cancelled('cancelled');

  const SessionStatus(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static SessionStatus? fromWire(Object? value) => enumFromWire(values, value);
}

/// Where a payment proof stands.
enum ProofStatus with WireEnum {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const ProofStatus(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static ProofStatus? fromWire(Object? value) => enumFromWire(values, value);
}

/// Where a coach ledger line stands.
enum LedgerStatus with WireEnum {
  pending('pending'),
  eligible('eligible'),
  paid('paid'),
  reversed('reversed');

  const LedgerStatus(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static LedgerStatus? fromWire(Object? value) => enumFromWire(values, value);
}

/// Whether a coach and a client are connected.
enum RelationshipStatus with WireEnum {
  none('none'),
  active('active'),
  ended('ended');

  const RelationshipStatus(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static RelationshipStatus? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// What a coach plan holds.
enum PlanKind with WireEnum {
  workout('workout'),
  meal('meal');

  const PlanKind(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static PlanKind? fromWire(Object? value) => enumFromWire(values, value);
}

/// Whether a payout account is confirmed.
enum PayoutAccountState with WireEnum {
  none('none'),
  confirmed('confirmed'),
  pending('pending'),
  rejected('rejected');

  const PayoutAccountState(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static PayoutAccountState? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// Where a cancellation request stands.
enum CancellationState with WireEnum {
  requested('requested'),
  refunded('refunded'),
  declined('declined');

  const CancellationState(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static CancellationState? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// What a system line in the chat says.
enum SystemMessageKind with WireEnum {
  started('started'),
  ended('ended'),
  endsSoon('endsSoon'),
  planUpdated('planUpdated'),
  sessionConfirmed('sessionConfirmed'),
  sessionDone('sessionDone'),
  hidden('hidden');

  const SystemMessageKind(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static SystemMessageKind? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// Why a coach declined a request.
enum CoachDeclineReason with WireEnum {
  full('full'),
  notAFit('not_a_fit'),
  needsDoctor('needs_doctor'),
  other('other');

  const CoachDeclineReason(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static CoachDeclineReason? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// Why staff rejected a payment proof.
enum ProofRejectReason with WireEnum {
  amountWrong('amount_wrong'),
  notReceived('not_received'),
  unreadable('unreadable'),
  wrongAccount('wrong_account'),
  duplicate('duplicate'),
  other('other');

  const ProofRejectReason(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static ProofRejectReason? fromWire(Object? value) =>
      enumFromWire(values, value);
}

/// What staff are told to look at in a proof.
enum ProofFlag with WireEnum {
  duplicateReference('duplicateReference'),
  sameImage('sameImage'),
  nearImage('nearImage'),
  amountDiffers('amountDiffers'),
  paidBeforeAccept('paidBeforeAccept');

  const ProofFlag(this.wire);

  @override
  final String wire;

  /// Null for a name this build does not know.
  static ProofFlag? fromWire(Object? value) => enumFromWire(values, value);
}
