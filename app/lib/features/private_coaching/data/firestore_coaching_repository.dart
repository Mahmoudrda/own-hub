/// The real [CoachingRepository]: Firestore for reads and chat lines, Cloud
/// Functions (europe-west3) for everything the server decides, and the
/// personal bucket for a coach's documents.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/approved_media.dart';
import '../domain/chat_message.dart';
import '../domain/chat_screen.dart';
import '../domain/coach_application.dart';
import '../domain/coach_money.dart';
import '../domain/coach_plan.dart';
import '../domain/coach_profile.dart';
import '../domain/coaching_contract.dart';
import '../domain/coaching_failure.dart';
import '../domain/parse.dart';
import '../domain/payments.dart';
import '../domain/portfolio_media.dart';
import '../domain/requests.dart';
import '../domain/session_link.dart';
import '../domain/subscription.dart';
import '../../signup/domain/legal_acceptance.dart' show kAppVersion;
import '../../train/domain/my_plan.dart';
import 'chat_repository.dart';
import 'coaching_repository.dart';
import 'firestore_plain.dart';
import 'strip_jpeg_metadata.dart';

/// How long a callable is waited for. The proof upload carries a picture.
const Duration kCoachingCallTimeout = Duration(seconds: 30);
const Duration kCoachingProofTimeout = Duration(seconds: 60);

/// The file ending for each type a coach may upload.
const Map<String, String> kCoachDocExtensions = <String, String>{
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'application/pdf': 'pdf',
};

/// `coach-docs/{uid}/{folder}/{token}.{ext}`: one level under the folder, the
/// shape the server and the storage rules accept.
String coachDocPath({
  required String uid,
  required CoachDocFolder folder,
  required String token,
  required String extension,
}) => 'coach-docs/$uid/${folder.name}/$token.$extension';

String _randomToken([Random? random]) {
  final r = random ?? Random.secure();
  const hex = '0123456789abcdef';
  return List<String>.generate(24, (_) => hex[r.nextInt(16)]).join();
}

class FirestoreCoachingRepository implements ChatThreadRepository {
  FirestoreCoachingRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
    String? Function()? uidProvider,
  }) : _firestoreOverride = firestore,
       _functionsOverride = functions,
       _storageOverride = storage,
       _uidProvider =
           uidProvider ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final FirebaseFirestore? _firestoreOverride;
  final FirebaseFunctions? _functionsOverride;
  final FirebaseStorage? _storageOverride;
  final String? Function() _uidProvider;

  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _functionsOverride ?? FirebaseBoot.functions;
  FirebaseStorage get _storage =>
      _storageOverride ?? FirebaseBoot.personalMedia;

  @override
  String? get uid => _uidProvider();

  String _requireUid() {
    final id = uid;
    if (id == null || id.isEmpty) {
      throw const CoachingFailure(CoachingRefusal.signedOut);
    }
    return id;
  }

  // ---------------------------------------------------------------- helpers

  CoachingFailure _failureOf(Object error) {
    if (error is CoachingFailure) return error;
    if (error is FirebaseFunctionsException) {
      return CoachingFailure.fromCallable(error.code, error.message);
    }
    if (error is FirebaseException) {
      return CoachingFailure.fromStore(error.code);
    }
    return const CoachingFailure(CoachingRefusal.unknown);
  }

  Stream<T> _guard<T>(Stream<T> source) => source.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (error, stack, sink) =>
          sink.addError(_failureOf(error), stack),
    ),
  );

  Stream<List<T>> _list<T>(
    Query<Map<String, dynamic>> query,
    T? Function(String id, Object? data) parse,
  ) => _guard(
    query.snapshots().map(
      (snap) => <T>[
        for (final doc in snap.docs) ?parse(doc.id, firestorePlain(doc.data())),
      ],
    ),
  );

  Stream<T?> _one<T>(
    DocumentReference<Map<String, dynamic>> ref,
    T? Function(String id, Object? data) parse,
  ) => _guard(
    ref.snapshots().map(
      (snap) =>
          snap.exists ? parse(snap.id, firestorePlain(snap.data())) : null,
    ),
  );

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> payload, {
    Duration timeout = kCoachingCallTimeout,
  }) async {
    _requireUid();
    try {
      final result = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
          .call<Object?>(payload);
      return asMap(result.data) ?? const <String, Object?>{};
    } on FirebaseFunctionsException catch (error) {
      throw CoachingFailure.fromCallable(error.code, error.message);
    }
  }

  /// A callable that answered with a shape we cannot read.
  CoachingFailure get _unreadable =>
      const CoachingFailure(CoachingRefusal.unknown);

  // ---------------------------------------------------------------- coaches

  @override
  Stream<List<CoachProfile>> watchPublishedCoaches() => _list(
    _db.collection('coaches').where('published', isEqualTo: true),
    CoachProfile.fromMap,
  );

  @override
  Stream<CoachProfile?> watchCoach(String coachUid) =>
      _one(_db.collection('coaches').doc(coachUid), CoachProfile.fromMap);

  @override
  Stream<List<CoachPackage>> watchPackages(
    String coachUid, {
    bool onlyActive = true,
  }) {
    final base = _db.collection('coaches').doc(coachUid).collection('packages');
    final query = onlyActive ? base.where('active', isEqualTo: true) : base;
    return _list(query, CoachPackage.fromMap).map(
      (packages) => packages
        ..sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
        }),
    );
  }

  @override
  Stream<List<ApprovedMedia>> watchApprovedMedia(String coachUid) =>
      _list(
        _db
            .collection('coaches')
            .doc(coachUid)
            .collection('media')
            .where('status', isEqualTo: 'approved'),
        ApprovedMedia.fromMap,
      ).map(
        (items) => <ApprovedMedia>[...items]
          ..sort(
            (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          ),
      );

  // --------------------------------------------------------- subscriptions

  Stream<List<Subscription>> _subscriptions(
    String field, {
    bool openOnly = false,
  }) {
    final id = uid;
    if (id == null) return Stream.value(const <Subscription>[]);
    var query = _db.collection('subscriptions').where(field, isEqualTo: id);
    // The rules let a coach read a subscription only while it is open, and
    // a list must say so in its query.
    if (openOnly) {
      query = query.where('status', whereIn: CoachingEnums.subscriptionOpen);
    }
    return _list(query, Subscription.fromMap).map(
      (subs) => subs
        ..sort(
          (a, b) => (b.statusAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.statusAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        ),
    );
  }

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsClient() =>
      _subscriptions('clientUid');

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsCoach() =>
      _subscriptions('coachUid', openOnly: true);

  @override
  Stream<Subscription?> watchSubscription(String subId) =>
      _one(_db.collection('subscriptions').doc(subId), Subscription.fromMap);

  @override
  Stream<List<LiveSession>> watchSessions(String subId) =>
      _list(
        _db.collection('subscriptions').doc(subId).collection('sessions'),
        LiveSession.fromMap,
      ).map(
        (sessions) => sessions
          ..sort(
            (a, b) => (a.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  b.startsAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
          ),
      );

  @override
  Stream<List<Relationship>> watchMyRelationships() {
    final id = uid;
    if (id == null) return Stream.value(const <Relationship>[]);
    final asClient = _list(
      _db.collection('relationships').where('clientUid', isEqualTo: id),
      Relationship.fromMap,
    );
    final asCoach = _list(
      _db.collection('relationships').where('coachUid', isEqualTo: id),
      Relationship.fromMap,
    );
    return _merge(asClient, asCoach);
  }

  /// The latest of two list streams, joined, once both have spoken.
  Stream<List<T>> _merge<T>(Stream<List<T>> a, Stream<List<T>> b) {
    late StreamController<List<T>> controller;
    StreamSubscription<List<T>>? subA;
    StreamSubscription<List<T>>? subB;
    List<T>? lastA;
    List<T>? lastB;
    void emit() {
      if (lastA != null && lastB != null) {
        controller.add(<T>[...lastA!, ...lastB!]);
      }
    }

    controller = StreamController<List<T>>(
      onListen: () {
        subA = a.listen((v) {
          lastA = v;
          emit();
        }, onError: controller.addError);
        subB = b.listen((v) {
          lastB = v;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controller.stream;
  }

  // ------------------------------------------------------------------ chat

  CollectionReference<Map<String, dynamic>> _messages(String relId) =>
      _db.collection('relationships').doc(relId).collection('messages');

  @override
  Stream<List<ChatMessage>> watchMessages(String relId) => _guard(
    _messages(relId)
        .orderBy('createdAt', descending: true)
        .limit(CoachingLimits.messagePageSize)
        // Metadata changes carry no read cost; they let a line move from the
        // clock to one tick when the server confirms it.
        .snapshots(includeMetadataChanges: true)
        .map(
          (snap) => <ChatMessage>[
            for (final doc in snap.docs)
              ?ChatMessage.fromMap(
                doc.id,
                firestorePlain(doc.data()),
                pending: doc.metadata.hasPendingWrites,
              ),
          ],
        ),
  );

  @override
  Future<List<ChatMessage>> olderMessages(String relId, DateTime before) async {
    try {
      final snap = await _messages(relId)
          .orderBy('createdAt', descending: true)
          .startAfter(<Object?>[Timestamp.fromDate(before)])
          .limit(CoachingLimits.messagePageSize)
          .get();
      return <ChatMessage>[
        for (final doc in snap.docs)
          ?ChatMessage.fromMap(doc.id, firestorePlain(doc.data())),
      ];
    } catch (error) {
      throw _failureOf(error);
    }
  }

  @override
  Stream<DateTime?> watchReadAt(String relId) {
    final id = uid;
    if (id == null) return Stream.value(null);
    return _guard(
      _db
          .collection('relationships')
          .doc(relId)
          .collection('reads')
          .doc(id)
          .snapshots()
          .map((snap) => readTime(firestorePlain(snap.data()?['at']))),
    );
  }

  @override
  Stream<DateTime?> watchOtherReadAt(String relId, String otherUid) => _guard(
    _db
        .collection('relationships')
        .doc(relId)
        .collection('reads')
        .doc(otherUid)
        .snapshots()
        .map((snap) => readTime(firestorePlain(snap.data()?['at']))),
  );

  Future<void> _addLine(String relId, Map<String, Object?> fields) async {
    try {
      await _messages(relId).add(<String, Object?>{
        ...fields,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw _failureOf(error);
    }
  }

  @override
  Future<void> sendText(String relId, String text) async {
    final me = _requireUid();
    final problem = ChatMessage.problemWith(text);
    if (problem != null) {
      throw const CoachingFailure(CoachingRefusal.badRequest);
    }
    final trimmed = text.trim();
    final screened = ChatScreen.screen(trimmed);
    if (screened != null) throw CoachingFailure.screened(screened);
    await _addLine(relId, ChatMessage.textFields(me, trimmed));
  }

  @override
  Future<void> sendRecipe(String relId, String recipeId) async {
    final me = _requireUid();
    if (recipeId.trim().isEmpty) {
      throw const CoachingFailure(CoachingRefusal.badRequest);
    }
    await _addLine(relId, ChatMessage.recipeFields(me, recipeId));
  }

  @override
  Future<void> markRead(String relId) async {
    final me = _requireUid();
    try {
      await _db
          .collection('relationships')
          .doc(relId)
          .collection('reads')
          .doc(me)
          .set(<String, Object?>{'at': FieldValue.serverTimestamp()});
    } catch (error) {
      throw _failureOf(error);
    }
  }

  @override
  Future<bool> chatRulesAccepted() async {
    final me = _requireUid();
    try {
      final snap = await _db
          .collection('users')
          .doc(me)
          .collection('consents')
          .doc('chat-rules-v1')
          .get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> acceptChatRules({
    required String rulesText,
    required String locale,
  }) async {
    await _call(
      CoachingCallables.acceptChatRules,
      CoachingRequests.acceptChatRules(
        rulesText: rulesText,
        locale: locale,
        appVersion: kAppVersion,
      ),
    );
  }

  @override
  Future<void> markThreadRead(String relId) async {
    try {
      await _call(CoachingCallables.markThreadRead, <String, Object?>{
        'relId': relId,
      });
    } on CoachingFailure {
      // The callable is the cheap path; the plain marker still tells her
      // coach the chat was seen.
      await markRead(relId);
    }
  }

  @override
  Future<void> reportMessage({
    required String relId,
    required ChatMessage message,
    required String reason,
    String note = '',
    required String locale,
  }) async {
    final me = _requireUid();
    if (relId.isEmpty ||
        message.id.isEmpty ||
        message.senderUid.isEmpty ||
        message.senderUid == me ||
        !CoachingEnums.reportReasons.contains(reason) ||
        note.trim().length > 1000) {
      throw const CoachingFailure(CoachingRefusal.badRequest);
    }
    try {
      await _db.collection('reports').add(<String, Object?>{
        'reporterUid': me,
        'subjectUid': message.senderUid,
        'subjectKind': 'coachMessage',
        'subjectRef': 'relationships/$relId/messages/${message.id}',
        'reason': reason,
        'note': note.trim(),
        'state': 'submitted',
        'createdAt': FieldValue.serverTimestamp(),
        'locale': locale,
        'appVersion': kAppVersion,
      });
    } catch (error) {
      throw _failureOf(error);
    }
  }

  @override
  Future<void> reportCoachProfile({
    required String coachUid,
    required String reason,
    String note = '',
    required String locale,
  }) async {
    final me = _requireUid();
    if (coachUid.isEmpty ||
        coachUid == me ||
        !CoachingEnums.reportReasons.contains(reason) ||
        note.trim().length > 1000) {
      throw const CoachingFailure(CoachingRefusal.badRequest);
    }
    try {
      await _db.collection('reports').add(<String, Object?>{
        'reporterUid': me,
        'subjectUid': coachUid,
        'subjectKind': 'coachProfile',
        'subjectRef': 'coaches/$coachUid',
        'reason': reason,
        'note': note.trim(),
        'state': 'submitted',
        'createdAt': FieldValue.serverTimestamp(),
        'locale': locale,
        'appVersion': kAppVersion,
      });
    } catch (error) {
      throw _failureOf(error);
    }
  }

  // ---------------------------------------------------------- plans, money

  @override
  Stream<List<CoachPlan>> watchCoachPlansForClient(String clientUid) {
    final id = uid;
    if (id == null || clientUid.isEmpty) {
      return Stream.value(const <CoachPlan>[]);
    }
    return _list(
      _db
          .collection('plans')
          .doc(clientUid)
          .collection('coachPlans')
          .where('coachUid', isEqualTo: id),
      CoachPlan.fromMap,
    );
  }

  @override
  Stream<List<CoachPlan>> watchMyCoachPlans() {
    final id = uid;
    if (id == null) return Stream.value(const <CoachPlan>[]);
    return _list(
      _db.collection('plans').doc(id).collection('coachPlans'),
      CoachPlan.fromMap,
    );
  }

  @override
  Stream<ReceivingAccounts?> watchReceivingAccounts() => _one(
    _db.collection('coachingConfig').doc('receivingAccounts'),
    (id, data) => ReceivingAccounts.fromMap(data),
  );

  @override
  Stream<SellerDetails?> watchSellerDetails() => _one(
    _db.collection('coachingConfig').doc('seller'),
    (id, data) => SellerDetails.fromMap(data),
  );

  @override
  Stream<Receipt?> watchMyReceipt(String subId) =>
      _one(_db.collection('receipts').doc(subId), Receipt.fromMap);

  @override
  Stream<CoachApplication?> watchMyApplication() {
    final id = uid;
    if (id == null) return Stream.value(null);
    return _one(
      _db.collection('coachApplications').doc(id),
      (_, data) => CoachApplication.fromMap(data),
    );
  }

  @override
  Stream<CoachPrivateSummary?> watchCoachPrivate() {
    final id = uid;
    if (id == null) return Stream.value(null);
    return _one(
      _db.collection('coachPrivate').doc(id),
      (_, data) => CoachPrivateSummary.fromMap(data),
    );
  }

  @override
  Stream<Map<String, int>> watchMyPackagePrices() {
    final id = uid;
    if (id == null) return Stream.value(const <String, int>{});
    return _guard(
      _db
          .collection('coachPrivate')
          .doc(id)
          .collection('prices')
          .snapshots()
          .map((snap) {
            final out = <String, int>{};
            for (final doc in snap.docs) {
              final price = readInt(doc.data()['coachPriceEgp']);
              if (price > 0) out[doc.id] = price;
            }
            return out;
          }),
    );
  }

  @override
  Stream<List<LedgerEntry>> watchLedger() {
    final id = uid;
    if (id == null) return Stream.value(const <LedgerEntry>[]);
    return _list(
      _db.collection('coachPrivate').doc(id).collection('ledger'),
      LedgerEntry.fromMap,
    );
  }

  @override
  Stream<List<Payout>> watchPayouts() {
    final id = uid;
    if (id == null) return Stream.value(const <Payout>[]);
    return _list(
      _db.collection('coachPrivate').doc(id).collection('payouts'),
      Payout.fromMap,
    );
  }

  @override
  Stream<List<CoachDraft>> watchDrafts() {
    final id = uid;
    if (id == null) return Stream.value(const <CoachDraft>[]);
    return _list(
      _db.collection('coaches').doc(id).collection('drafts'),
      CoachDraft.fromMap,
    );
  }

  // ------------------------------------------------------------- callables

  @override
  Future<({ApplicationStatus status, int round})> submitCoachApplication(
    CoachApplication application, {
    required String locale,
  }) async {
    final data = await _call(
      CoachingCallables.submitCoachApplication,
      application.toRequest(locale: locale),
    );
    final status = ApplicationStatus.fromWire(data['status']);
    if (status == null) throw _unreadable;
    return (status: status, round: readInt(data['round']));
  }

  @override
  Future<void> updateCoachProfile({
    String? headline,
    String? approachText,
    String? photoPath,
    bool? acceptingClients,
    bool? autoAccept,
    int? maxActiveClients,
  }) async {
    await _call(
      CoachingCallables.updateCoachProfile,
      CoachingRequests.updateProfile(
        headline: headline,
        approachText: approachText,
        photoPath: photoPath,
        acceptingClients: acceptingClients,
        autoAccept: autoAccept,
        maxActiveClients: maxActiveClients,
      ),
    );
  }

  @override
  Future<PayoutAccountState?> requestPayoutAccountChange(
    CoachPayoutAccount account,
  ) async {
    final data = await _call(
      CoachingCallables.requestPayoutAccountChange,
      CoachingRequests.payoutChange(account),
    );
    return PayoutAccountState.fromWire(data['state']);
  }

  @override
  Future<({String packageId, int priceFinalEgp, int youReceiveEgp})>
  saveCoachPackage(PackageDraft draft) async {
    final data = await _call(
      CoachingCallables.saveCoachPackage,
      draft.toRequest(),
    );
    final id = readStringOrNull(data['packageId']);
    if (id == null) throw _unreadable;
    return (
      packageId: id,
      priceFinalEgp: readInt(data['priceFinalEgp']),
      youReceiveEgp: readInt(data['youReceiveEgp']),
    );
  }

  @override
  Future<({String subId, SubscriptionStatus status})> requestCoaching({
    required String coachUid,
    required String packageId,
    required Intake intake,
    required Map<String, Object?> consent,
    required String locale,
    String clientName = '',
  }) async {
    final data = await _call(
      CoachingCallables.requestCoaching,
      CoachingRequests.requestCoaching(
        coachUid: coachUid,
        packageId: packageId,
        intake: intake,
        consent: consent,
        locale: locale,
        clientName: clientName,
      ),
    );
    final subId = readStringOrNull(data['subId']);
    final status = SubscriptionStatus.fromWire(data['status']);
    if (subId == null || status == null) throw _unreadable;
    return (subId: subId, status: status);
  }

  @override
  Future<SubscriptionStatus> respondCoachingRequest({
    required String subId,
    required bool accept,
    CoachDeclineReason? declineReason,
  }) async {
    final data = await _call(
      CoachingCallables.respondCoachingRequest,
      CoachingRequests.respond(
        subId: subId,
        accept: accept,
        declineReason: declineReason,
      ),
    );
    return SubscriptionStatus.fromWire(data['status']) ?? (throw _unreadable);
  }

  @override
  Future<SubscriptionStatus> cancelCoachingRequest(String subId) async {
    final data = await _call(
      CoachingCallables.cancelCoachingRequest,
      CoachingRequests.cancelRequest(subId),
    );
    return SubscriptionStatus.fromWire(data['status']) ?? (throw _unreadable);
  }

  @override
  Future<SubscriptionStatus> endMyCoaching(
    String subId, {
    String? reason,
  }) async {
    final data = await _call(
      CoachingCallables.endMyCoaching,
      CoachingRequests.endMine(subId, reason),
    );
    return SubscriptionStatus.fromWire(data['status']) ?? (throw _unreadable);
  }

  @override
  Future<({String proofId, ProofStatus status})> submitPaymentProof({
    required String subId,
    required PaymentProofForm form,
    required String locale,
  }) async {
    final data = await _call(
      CoachingCallables.submitPaymentProof,
      form.toRequest(subId: subId, locale: locale),
      timeout: kCoachingProofTimeout,
    );
    final proofId = readStringOrNull(data['proofId']);
    final status = ProofStatus.fromWire(data['status']);
    if (proofId == null || status == null) throw _unreadable;
    return (proofId: proofId, status: status);
  }

  @override
  Future<({CancellationState state, int refundEgp})> requestCancellation({
    required String subId,
    String? reason,
  }) async {
    final data = await _call(
      CoachingCallables.requestCancellation,
      CoachingRequests.cancellation(subId, reason),
    );
    final state = CancellationState.fromWire(data['state']);
    if (state == null) throw _unreadable;
    return (state: state, refundEgp: readInt(data['refundEgp']));
  }

  @override
  Future<({String planId, int revision})> publishCoachPlan({
    required String subId,
    required String name,
    MyPlan? workout,
    MealPlanBody? meal,
    String? planId,
  }) async {
    if ((workout == null) == (meal == null)) {
      throw const CoachingFailure(CoachingRefusal.badRequest);
    }
    final data = await _call(
      CoachingCallables.publishCoachPlan,
      publishPlanRequest(
        subId: subId,
        name: name,
        workout: workout,
        meal: meal,
        planId: planId,
      ),
    );
    final id = readStringOrNull(data['planId']);
    if (id == null) throw _unreadable;
    return (planId: id, revision: readInt(data['revision'], 1));
  }

  @override
  Future<String> scheduleLiveSession({
    required String subId,
    required DateTime startsAt,
    required int minutes,
    required String link,
  }) async {
    if (!sessionLinkAllowed(link)) {
      throw const CoachingFailure(CoachingRefusal.sessionLinkInvalid);
    }
    final data = await _call(
      CoachingCallables.scheduleLiveSession,
      CoachingRequests.scheduleSession(
        subId: subId,
        startsAt: startsAt,
        minutes: minutes,
        link: link,
      ),
    );
    return readStringOrNull(data['sessionId']) ?? (throw _unreadable);
  }

  @override
  Future<SessionStatus> respondLiveSession({
    required String subId,
    required String sessionId,
    required bool confirm,
  }) async {
    final data = await _call(
      CoachingCallables.respondLiveSession,
      CoachingRequests.respondSession(
        subId: subId,
        sessionId: sessionId,
        confirm: confirm,
      ),
    );
    return SessionStatus.fromWire(data['status']) ?? (throw _unreadable);
  }

  @override
  Future<({SessionStatus status, int sessionsUsed})> markSessionDone({
    required String subId,
    required String sessionId,
  }) async {
    final data = await _call(
      CoachingCallables.markSessionDone,
      CoachingRequests.markDone(subId, sessionId),
    );
    final status = SessionStatus.fromWire(data['status']);
    if (status == null) throw _unreadable;
    return (status: status, sessionsUsed: readInt(data['sessionsUsed']));
  }

  @override
  Future<void> recordSignupRole(String role) async {
    await _call(
      CoachingCallables.recordSignupRole,
      CoachingRequests.signupRole(role),
    );
  }

  // ---------------------------------------------------------------- drafts

  @override
  Future<String> saveDraft(CoachDraft draft) async {
    final me = _requireUid();
    final drafts = _db.collection('coaches').doc(me).collection('drafts');
    final ref = draft.id.isEmpty ? drafts.doc() : drafts.doc(draft.id);
    try {
      await ref.set(<String, Object?>{
        ...draft.toWrite(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw _failureOf(error);
    }
    return ref.id;
  }

  @override
  Future<void> deleteDraft(String draftId) async {
    final me = _requireUid();
    try {
      await _db
          .collection('coaches')
          .doc(me)
          .collection('drafts')
          .doc(draftId)
          .delete();
    } catch (error) {
      throw _failureOf(error);
    }
  }

  // --------------------------------------------------------------- uploads

  @override
  Stream<List<PortfolioMedia>> watchMyPortfolioMedia() {
    final id = uid;
    if (id == null) return Stream.value(const <PortfolioMedia>[]);
    return _list(
      _db.collection('coaches').doc(id).collection('media'),
      PortfolioMedia.fromMap,
    ).map(
      (items) => <PortfolioMedia>[...items]
        ..sort(
          (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
        ),
    );
  }

  @override
  Future<String> addPortfolioMedia(MediaDraft draft) async {
    final data = await _call(PortfolioMediaCallables.add, draft.toRequest());
    return readString(data['mediaId'] ?? data['id']);
  }

  @override
  Future<void> removePortfolioMedia(String mediaId) async {
    await _call(PortfolioMediaCallables.remove, <String, Object?>{
      'mediaId': mediaId,
    });
  }

  @override
  Future<void> confirmMediaConsent(String mediaId, String consentPath) async {
    await _call(PortfolioMediaCallables.confirmConsent, <String, Object?>{
      'mediaId': mediaId,
      'consentPath': consentPath,
    });
  }

  @override
  Future<String> uploadCoachDoc(
    CoachDocFolder folder,
    Uint8List bytes,
    String contentType,
  ) async {
    final me = _requireUid();
    final extension = kCoachDocExtensions[contentType];
    if (extension == null ||
        bytes.isEmpty ||
        bytes.length > CoachingLimits.uploadMaxBytes) {
      throw const CoachingFailure(CoachingRefusal.imageInvalid);
    }
    final path = coachDocPath(
      uid: me,
      folder: folder,
      token: _randomToken(),
      extension: extension,
    );
    try {
      await _storage
          .ref(path)
          .putData(
            contentType == 'image/jpeg' ? stripJpegMetadata(bytes) : bytes,
            SettableMetadata(contentType: contentType),
          );
    } on FirebaseException catch (error) {
      throw CoachingFailure.fromStore(error.code);
    }
    return path;
  }
}
