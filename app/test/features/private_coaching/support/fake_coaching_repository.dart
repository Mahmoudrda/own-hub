import 'dart:async';
import 'dart:typed_data';

import 'package:own_hub/features/private_coaching/data/chat_repository.dart';
import 'package:own_hub/features/private_coaching/data/coaching_repository.dart';
import 'package:own_hub/features/private_coaching/data/firestore_coaching_repository.dart'
    show coachDocPath, kCoachDocExtensions;
import 'package:own_hub/features/private_coaching/domain/approved_media.dart';
import 'package:own_hub/features/private_coaching/domain/chat_message.dart';
import 'package:own_hub/features/private_coaching/domain/chat_screen.dart';
import 'package:own_hub/features/private_coaching/domain/coach_application.dart';
import 'package:own_hub/features/private_coaching/domain/coach_money.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coach_profile.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_failure.dart';
import 'package:own_hub/features/private_coaching/domain/payments.dart';
import 'package:own_hub/features/private_coaching/domain/portfolio_media.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';

/// A value that replays its latest state to each new listener.
class Feed<T> {
  Feed(this._value);

  T _value;
  final StreamController<T> _changes = StreamController<T>.broadcast(
    sync: true,
  );

  T get value => _value;

  set value(T next) {
    _value = next;
    _changes.add(next);
  }

  void fail(Object error) => _changes.addError(error);

  Stream<T> watch() => Stream<T>.multi((controller) {
    controller.add(_value);
    final sub = _changes.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = sub.cancel;
  });
}

/// In memory and deterministic. Every call is recorded in [calls]; set
/// [failWith] to make the named call throw.
class FakeCoachingRepository implements ChatThreadRepository {
  FakeCoachingRepository({this.uid = 'me'});

  @override
  String? uid;

  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  final Map<String, CoachingFailure> failWith = <String, CoachingFailure>{};
  int _ids = 0;

  final coaches = Feed<List<CoachProfile>>(const <CoachProfile>[]);
  final packages = <String, Feed<List<CoachPackage>>>{};
  final clientSubs = Feed<List<Subscription>>(const <Subscription>[]);
  final coachSubs = Feed<List<Subscription>>(const <Subscription>[]);
  final relationships = Feed<List<Relationship>>(const <Relationship>[]);
  final messages = <String, Feed<List<ChatMessage>>>{};
  final readAt = <String, Feed<DateTime?>>{};
  final plans = Feed<List<CoachPlan>>(const <CoachPlan>[]);
  final sessions = <String, Feed<List<LiveSession>>>{};
  final receiving = Feed<ReceivingAccounts?>(null);
  final seller = Feed<SellerDetails?>(null);
  final application = Feed<CoachApplication?>(null);
  final coachPrivate = Feed<CoachPrivateSummary?>(null);
  final ledger = Feed<List<LedgerEntry>>(const <LedgerEntry>[]);
  final payouts = Feed<List<Payout>>(const <Payout>[]);
  final drafts = Feed<List<CoachDraft>>(const <CoachDraft>[]);
  final olderPages = <String, List<ChatMessage>>{};
  final otherReadAt = <String, Feed<DateTime?>>{};
  final myMedia = Feed<List<PortfolioMedia>>(const <PortfolioMedia>[]);
  final approvedMedia = <String, Feed<List<ApprovedMedia>>>{};
  final packagePrices = Feed<Map<String, int>>(const <String, int>{});

  Feed<List<T>> _feedOf<T>(Map<String, Feed<List<T>>> map, String key) =>
      map.putIfAbsent(key, () => Feed<List<T>>(<T>[]));

  void _record(String name, [Map<String, Object?> args = const {}]) {
    calls.add((name, args));
    final failure = failWith[name];
    if (failure != null) throw failure;
  }

  String _next(String prefix) => '$prefix${++_ids}';

  List<String> get callNames => <String>[for (final c in calls) c.$1];

  @override
  Stream<List<CoachProfile>> watchPublishedCoaches() => coaches.watch();

  @override
  Stream<CoachProfile?> watchCoach(String coachUid) => coaches.watch().map(
    (list) => list.where((c) => c.uid == coachUid).firstOrNull,
  );

  @override
  Stream<List<CoachPackage>> watchPackages(
    String coachUid, {
    bool onlyActive = true,
  }) => _feedOf(packages, coachUid).watch().map(
    (l) => <CoachPackage>[
      for (final p in l)
        if (!onlyActive || p.active) p,
    ],
  );

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsClient() =>
      clientSubs.watch();

  @override
  Stream<List<Subscription>> watchMySubscriptionsAsCoach() =>
      coachSubs.watch().map(
        (l) => <Subscription>[
          for (final s in l)
            if (s.isOpen) s,
        ],
      );

  @override
  Stream<Subscription?> watchSubscription(String subId) =>
      clientSubs.watch().map(
        (l) => <Subscription>[
          ...l,
          ...coachSubs.value,
        ].where((s) => s.id == subId).firstOrNull,
      );

  @override
  Stream<List<LiveSession>> watchSessions(String subId) =>
      _feedOf(sessions, subId).watch();

  @override
  Stream<List<Relationship>> watchMyRelationships() => relationships.watch();

  @override
  Stream<List<ChatMessage>> watchMessages(String relId) =>
      _feedOf(messages, relId).watch();

  @override
  Future<List<ChatMessage>> olderMessages(String relId, DateTime before) async {
    _record('olderMessages', {'relId': relId});
    return <ChatMessage>[
      for (final m in olderPages[relId] ?? const <ChatMessage>[])
        if (m.createdAt != null && m.createdAt!.isBefore(before)) m,
    ];
  }

  Feed<DateTime?> _readFeed(String relId) =>
      readAt.putIfAbsent(relId, () => Feed<DateTime?>(null));

  @override
  Stream<DateTime?> watchReadAt(String relId) => _readFeed(relId).watch();

  @override
  Stream<List<CoachPlan>> watchMyCoachPlans() => plans.watch();

  @override
  Stream<List<CoachPlan>> watchCoachPlansForClient(String clientUid) =>
      plans.watch().map(
        (l) => [
          for (final p in l)
            if (p.coachUid == uid) p,
        ],
      );

  @override
  Stream<ReceivingAccounts?> watchReceivingAccounts() => receiving.watch();

  @override
  Stream<SellerDetails?> watchSellerDetails() => seller.watch();

  @override
  Stream<Receipt?> watchMyReceipt(String subId) => Stream.value(null);

  @override
  Stream<CoachApplication?> watchMyApplication() => application.watch();

  @override
  Stream<CoachPrivateSummary?> watchCoachPrivate() => coachPrivate.watch();

  @override
  Stream<Map<String, int>> watchMyPackagePrices() => packagePrices.watch();

  @override
  Stream<List<LedgerEntry>> watchLedger() => ledger.watch();

  @override
  Stream<List<Payout>> watchPayouts() => payouts.watch();

  @override
  Stream<List<CoachDraft>> watchDrafts() => drafts.watch();

  @override
  Future<({ApplicationStatus status, int round})> submitCoachApplication(
    CoachApplication app, {
    required String locale,
  }) async {
    _record('submitCoachApplication', app.toRequest(locale: locale));
    return (status: ApplicationStatus.submitted, round: 1);
  }

  @override
  Future<void> updateCoachProfile({
    String? headline,
    String? approachText,
    String? photoPath,
    bool? acceptingClients,
    bool? autoAccept,
    int? maxActiveClients,
  }) async => _record('updateCoachProfile');

  @override
  Future<PayoutAccountState?> requestPayoutAccountChange(
    CoachPayoutAccount account,
  ) async {
    _record('requestPayoutAccountChange', account.toMap());
    return PayoutAccountState.pending;
  }

  @override
  Future<({String packageId, int priceFinalEgp, int youReceiveEgp})>
  saveCoachPackage(PackageDraft draft) async {
    _record('saveCoachPackage', draft.toRequest());
    return (
      packageId: draft.packageId ?? _next('pkg'),
      priceFinalEgp: draft.priceFinalEgp,
      youReceiveEgp: draft.youReceiveEgp,
    );
  }

  @override
  Future<({String subId, SubscriptionStatus status})> requestCoaching({
    required String coachUid,
    required String packageId,
    required Intake intake,
    required String locale,
    String clientName = '',
  }) async {
    _record('requestCoaching', {
      'coachUid': coachUid,
      'packageId': packageId,
      'clientName': clientName,
    });
    final id = _next('sub');
    clientSubs.value = <Subscription>[
      Subscription(
        id: id,
        coachUid: coachUid,
        clientUid: uid!,
        status: SubscriptionStatus.requested,
        packageId: packageId,
        intake: intake,
      ),
      ...clientSubs.value,
    ];
    return (subId: id, status: SubscriptionStatus.requested);
  }

  @override
  Future<SubscriptionStatus> respondCoachingRequest({
    required String subId,
    required bool accept,
    CoachDeclineReason? declineReason,
  }) async {
    _record('respondCoachingRequest', {'subId': subId, 'accept': accept});
    return accept
        ? SubscriptionStatus.awaitingPayment
        : SubscriptionStatus.declined;
  }

  @override
  Future<SubscriptionStatus> cancelCoachingRequest(String subId) async {
    _record('cancelCoachingRequest', {'subId': subId});
    return SubscriptionStatus.cancelled;
  }

  @override
  Future<SubscriptionStatus> endMyCoaching(
    String subId, {
    String? reason,
  }) async {
    _record('endMyCoaching', {'subId': subId, 'reason': reason});
    return SubscriptionStatus.endedEarly;
  }

  @override
  Future<({String proofId, ProofStatus status})> submitPaymentProof({
    required String subId,
    required PaymentProofForm form,
    required String locale,
  }) async {
    _record('submitPaymentProof', {'subId': subId});
    return (proofId: _next('proof'), status: ProofStatus.pending);
  }

  @override
  Future<({CancellationState state, int refundEgp})> requestCancellation({
    required String subId,
    String? reason,
  }) async {
    _record('requestCancellation', {'subId': subId});
    return (state: CancellationState.requested, refundEgp: 0);
  }

  @override
  Future<({String planId, int revision})> publishCoachPlan({
    required String subId,
    required String name,
    MyPlan? workout,
    MealPlanBody? meal,
    String? planId,
  }) async {
    _record('publishCoachPlan', {'subId': subId, 'name': name});
    return (planId: planId ?? _next('plan'), revision: 1);
  }

  @override
  Future<String> scheduleLiveSession({
    required String subId,
    required DateTime startsAt,
    required int minutes,
    required String link,
  }) async {
    _record('scheduleLiveSession', {'subId': subId, 'link': link});
    return _next('session');
  }

  @override
  Future<SessionStatus> respondLiveSession({
    required String subId,
    required String sessionId,
    required bool confirm,
  }) async {
    _record('respondLiveSession', {'sessionId': sessionId});
    return confirm ? SessionStatus.confirmed : SessionStatus.declined;
  }

  @override
  Future<({SessionStatus status, int sessionsUsed})> markSessionDone({
    required String subId,
    required String sessionId,
  }) async {
    _record('markSessionDone', {'sessionId': sessionId});
    return (status: SessionStatus.done, sessionsUsed: 1);
  }

  @override
  Future<void> recordSignupRole(String role) async =>
      _record('recordSignupRole', {'role': role});

  @override
  Future<void> sendText(String relId, String text) async {
    _record('sendText', {'relId': relId});
    if (ChatMessage.problemWith(text) != null) {
      throw const CoachingFailure(CoachingRefusal.badRequest);
    }
    final screened = ChatScreen.screen(text.trim());
    if (screened != null) throw CoachingFailure.screened(screened);
    final feed = _feedOf(messages, relId);
    feed.value = <ChatMessage>[
      ChatMessage(
        id: _next('msg'),
        senderUid: uid!,
        type: MessageType.text,
        text: text.trim(),
        createdAt: DateTime.utc(2026, 10, 24, 12),
      ),
      ...feed.value,
    ];
  }

  @override
  Future<void> sendRecipe(String relId, String recipeId) async =>
      _record('sendRecipe', {'relId': relId, 'recipeId': recipeId});

  @override
  Future<void> markRead(String relId) async {
    _record('markRead', {'relId': relId});
    _readFeed(relId).value = DateTime.utc(2026, 10, 24, 13);
  }

  @override
  Stream<DateTime?> watchOtherReadAt(String relId, String otherUid) =>
      otherReadAt.putIfAbsent(relId, () => Feed<DateTime?>(null)).watch();

  @override
  Future<void> markThreadRead(String relId) async {
    _record('markThreadRead', {'relId': relId});
    _readFeed(relId).value = DateTime.utc(2026, 10, 24, 13);
  }

  @override
  Future<void> reportMessage({
    required String relId,
    required ChatMessage message,
    required String reason,
    String note = '',
    required String locale,
  }) async => _record('reportMessage', {
    'relId': relId,
    'messageId': message.id,
    'reason': reason,
  });

  @override
  Future<void> reportCoachProfile({
    required String coachUid,
    required String reason,
    String note = '',
    required String locale,
  }) async =>
      _record('reportCoachProfile', {'coachUid': coachUid, 'reason': reason});

  @override
  Stream<List<ApprovedMedia>> watchApprovedMedia(String coachUid) =>
      _feedOf(approvedMedia, coachUid).watch();

  @override
  Stream<List<PortfolioMedia>> watchMyPortfolioMedia() => myMedia.watch();

  @override
  Future<String> addPortfolioMedia(MediaDraft draft) async {
    _record('addPortfolioMedia', draft.toRequest());
    return _next('media');
  }

  @override
  Future<void> removePortfolioMedia(String mediaId) async =>
      _record('removePortfolioMedia', {'mediaId': mediaId});

  @override
  Future<void> confirmMediaConsent(String mediaId) async =>
      _record('confirmMediaConsent', {'mediaId': mediaId});

  @override
  Future<String> saveDraft(CoachDraft draft) async {
    _record('saveDraft');
    return draft.id.isEmpty ? _next('draft') : draft.id;
  }

  @override
  Future<void> deleteDraft(String draftId) async =>
      _record('deleteDraft', {'id': draftId});

  @override
  Future<String> uploadCoachDoc(
    CoachDocFolder folder,
    Uint8List bytes,
    String contentType,
  ) async {
    _record('uploadCoachDoc', {'folder': folder.name});
    return coachDocPath(
      uid: uid!,
      folder: folder,
      token: 'token${++_ids}',
      extension: kCoachDocExtensions[contentType] ?? 'bin',
    );
  }
}
