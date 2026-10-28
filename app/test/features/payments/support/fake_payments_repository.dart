import 'dart:async';
import 'dart:typed_data';

import 'package:own_hub/features/payments/data/payments_repository.dart';
import 'package:own_hub/features/payments/domain/payment_models.dart';

/// In-memory payments for widget tests. Records every call by name.
class FakePaymentsRepository implements PaymentsRepository {
  FakePaymentsRepository({this.uid = 'me'});

  @override
  String? uid;

  final List<(String, Map<String, Object?>)> calls =
      <(String, Map<String, Object?>)>[];
  PaymentFailure? failNext;
  PaymentStatus nextStatus = PaymentStatus.proofSubmitted;
  ProofResult nextProof = const ProofResult(
    status: PaymentStatus.proofSubmitted,
    outcome: RiskOutcome.green,
  );
  bool? enabled = true;

  /// What [partyImage] returns.
  Uint8List partyImageBytes = Uint8List(0);

  /// When set, submitProof waits for it (an answer still on its way).
  Completer<void>? hold;

  final _payments = StreamController<List<Payment>>.broadcast(sync: true);
  List<Payment> all = <Payment>[];
  CoachAddress? address;
  AddressChange nextAddressChange = const AddressChange(pending: false);
  List<FeeStatement> statements = <FeeStatement>[];
  List<PaymentEvent> events = <PaymentEvent>[];

  void setPayments(List<Payment> list) {
    all = list;
    _payments.add(list);
  }

  List<String> get names => [for (final c in calls) c.$1];

  void _record(String name, Map<String, Object?> args) {
    calls.add((name, args));
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  PaymentStatus _status(String name, Map<String, Object?> args) {
    _record(name, args);
    return nextStatus;
  }

  Stream<List<Payment>> _list(bool Function(Payment) keep) {
    late final StreamController<List<Payment>> c;
    StreamSubscription<List<Payment>>? sub;
    c = StreamController<List<Payment>>(
      onListen: () {
        sub = _payments.stream.listen((l) => c.add(l.where(keep).toList()));
        scheduleMicrotask(() {
          if (c.hasListener && !c.isClosed) c.add(all.where(keep).toList());
        });
      },
      onCancel: () {
        unawaited(sub?.cancel());
      },
    );
    return c.stream;
  }

  @override
  Stream<Payment?> watchPayment(String id) =>
      _list((p) => p.id == id).map((l) => l.isEmpty ? null : l.first);
  @override
  Stream<List<Payment>> watchMyPaymentsAsClient() =>
      _list((p) => p.clientUid == uid);
  @override
  Stream<List<Payment>> watchMyPaymentsAsCoach() =>
      _list((p) => p.coachUid == uid);
  @override
  Stream<List<PaymentEvent>> watchEvents(String id) =>
      Stream<List<PaymentEvent>>.value(events);
  @override
  Stream<CoachAddress?> watchMyAddress() =>
      Stream<CoachAddress?>.value(address);
  @override
  Stream<List<FeeStatement>> watchMyStatements() =>
      Stream<List<FeeStatement>>.value(statements);

  @override
  Future<bool?> paymentsEnabled() async => enabled;

  @override
  Future<Payment> createPayment({
    required String subId,
    required String idempotencyKey,
    String? topUpOf,
  }) async {
    _record('createPayment', {
      'subId': subId,
      'key': idempotencyKey,
      'topUpOf': topUpOf,
    });
    return Payment(
      id: 'p1',
      clientUid: uid ?? '',
      coachUid: 'coach',
      subId: subId,
      status: PaymentStatus.awaitingPayment,
      amountPiasters: 50037,
      reference: 'OH-4821',
      address: const CoachAddress(
        address: 'rahma.m@instapay',
        accountName: 'Rahma M.',
      ),
      createdAt: DateTime.now().toUtc(),
      expiresAt: DateTime.now().toUtc().add(const Duration(hours: 24)),
    );
  }

  @override
  Future<void> cancelPayment(String paymentId) async =>
      _record('cancelPayment', {'id': paymentId});

  @override
  Future<ProofResult> submitProof({
    required String paymentId,
    required String idempotencyKey,
    required int amountPiasters,
    required List<Uint8List> images,
    String? txnNumber,
    String? senderHandle,
    DateTime? paidAtClaimed,
    Map<String, Object?> phoneReading = const <String, Object?>{},
    bool otherPayerOk = false,
  }) async {
    _record('submitProof', {
      'paymentId': paymentId,
      'key': idempotencyKey,
      'amount': amountPiasters,
      'images': images.length,
      'txn': txnNumber,
      'handle': senderHandle,
      'paidAt': paidAtClaimed,
      'reading': phoneReading,
      'other': otherPayerOk,
    });
    await hold?.future;
    return nextProof;
  }

  @override
  Future<int> addEvidence({
    required String paymentId,
    required List<Uint8List> images,
    String? note,
  }) async {
    _record('addEvidence', {'paymentId': paymentId, 'images': images.length});
    return images.length;
  }

  @override
  Future<PaymentStatus> clientAnswerReport(
    String paymentId, {
    required bool yes,
  }) async => _status('clientAnswerReport', {'id': paymentId, 'yes': yes});

  @override
  Future<PaymentStatus> clientRespondDifferentAmount(
    String paymentId, {
    required bool agree,
  }) async => _status('clientRespondDifferentAmount', {
    'id': paymentId,
    'agree': agree,
  });

  @override
  Future<AddressChange> setAddress({
    required String address,
    required String accountName,
  }) async {
    _record('setAddress', {'address': address, 'name': accountName});
    return nextAddressChange;
  }

  @override
  Future<PaymentStatus> coachConfirm(
    String paymentId, {
    int? receivedPiasters,
  }) async =>
      _status('coachConfirm', {'id': paymentId, 'received': receivedPiasters});

  @override
  Future<PaymentStatus> coachNotReceived({
    required String paymentId,
    required String reasonCode,
    required String note,
    required List<Uint8List> images,
  }) async => _status('coachNotReceived', {
    'id': paymentId,
    'reason': reasonCode,
    'note': note,
    'images': images.length,
  });

  @override
  Future<PaymentStatus> coachDifferentAmount({
    required String paymentId,
    required int receivedPiasters,
    required bool acceptLower,
  }) async => _status('coachDifferentAmount', {
    'id': paymentId,
    'received': receivedPiasters,
    'acceptLower': acceptLower,
  });

  @override
  Future<void> coachReport({
    String? subId,
    String? reference,
    required String txnNumber,
  }) async => _record('coachReport', {
    'subId': subId,
    'reference': reference,
    'txn': txnNumber,
  });

  @override
  Future<void> setAutoConfirm(bool enabled) async =>
      _record('setAutoConfirm', {'enabled': enabled});

  @override
  Future<PaymentStatus> requestRefund(String paymentId) async =>
      _status('requestRefund', {'id': paymentId});

  @override
  Future<PaymentStatus> denyRefund(
    String paymentId, {
    required String reasonCode,
  }) async => _status('denyRefund', {'id': paymentId, 'reason': reasonCode});

  @override
  Future<PaymentStatus> recordRefund({
    required String paymentId,
    required String txnNumber,
    required int amountPiasters,
    required String kind,
    DateTime? paidAt,
  }) async => _status('recordRefund', {
    'id': paymentId,
    'txn': txnNumber,
    'amount': amountPiasters,
    'kind': kind,
    'paidAt': paidAt,
  });

  @override
  Future<PaymentStatus> openServiceDispute(
    String paymentId, {
    String? note,
  }) async => _status('openServiceDispute', {'id': paymentId, 'note': note});

  @override
  Future<void> recordFeePayment({
    required String statementId,
    required String txnNumber,
  }) async =>
      _record('recordFeePayment', {'id': statementId, 'txn': txnNumber});

  @override
  Future<Uint8List> partyImage({
    required String paymentId,
    required String path,
  }) async {
    _record('partyImage', {'id': paymentId, 'path': path});
    return partyImageBytes;
  }
}

/// A scripted phone re-authentication.
class FakePhoneReauth implements PhoneReauth {
  final List<String> calls = <String>[];
  PaymentFailure? failNext;

  void _check() {
    final f = failNext;
    if (f != null) {
      failNext = null;
      throw f;
    }
  }

  @override
  Future<void> sendCode() async {
    calls.add('sendCode');
    _check();
  }

  @override
  Future<void> confirm(String code) async {
    calls.add('confirm:$code');
    _check();
  }
}

/// A payment as the server writes it, with sensible defaults.
Payment payment({
  String id = 'p1',
  PaymentStatus status = PaymentStatus.awaitingPayment,
  String subId = 'sub1',
  String clientUid = 'me',
  RiskOutcome? outcome,
  DateTime? expiresAt,
  DateTime? createdAt,
  DateTime? lateUntil,
  DateTime? accessUntil,
  String disputeKind = '',
  String hint = '',
  bool acceptLower = false,
  int differentAmountPiasters = 0,
  String coachReportTxn = '',
  bool coachReportAnswered = false,
  String coachUid = 'coach',
  int amountPiasters = 50037,
  String reference = 'OH-4821',
  String txnNumber = '',
  DateTime? submittedAt,
  DateTime? paidAtClaimed,
  List<String> screenshotPaths = const <String>[],
  bool autoConfirmed = false,
  DateTime? confirmedAt,
  DateTime? refundRequestedAt,
  DateTime? refundCoachDueAt,
  DateTime? refundRecordedAt,
  int? receivedPiasters,
  DateTime? statusAt,
  DateTime? disputeDecidedAt,
  List<String> disputeKinds = const <String>[],
  String disputeStaffDecision = '',
  int refundOwedPiasters = 0,
  DateTime? refundOwedDueAt,
}) => Payment(
  id: id,
  clientUid: clientUid,
  coachUid: coachUid,
  status: status,
  subId: subId,
  amountPiasters: amountPiasters,
  reference: reference,
  address: const CoachAddress(
    address: 'rahma.m@instapay',
    accountName: 'Rahma M.',
  ),
  createdAt: createdAt ?? DateTime.now().toUtc(),
  expiresAt: expiresAt ?? DateTime.now().toUtc().add(const Duration(hours: 23)),
  lateUntil: lateUntil ?? DateTime.now().toUtc().add(const Duration(days: 6)),
  outcome: outcome,
  accessUntil: accessUntil,
  disputeKind: disputeKind,
  hint: hint,
  acceptLower: acceptLower,
  differentAmountPiasters: differentAmountPiasters,
  coachReportTxn: coachReportTxn,
  coachReportAnswered: coachReportAnswered,
  txnNumber: txnNumber,
  submittedAt: submittedAt,
  paidAtClaimed: paidAtClaimed,
  screenshotPaths: screenshotPaths,
  autoConfirmed: autoConfirmed,
  confirmedAt: confirmedAt,
  refundRequestedAt: refundRequestedAt,
  refundCoachDueAt: refundCoachDueAt,
  refundRecordedAt: refundRecordedAt,
  receivedPiasters: receivedPiasters,
  statusAt: statusAt,
  disputeDecidedAt: disputeDecidedAt,
  disputeKinds: disputeKinds,
  disputeStaffDecision: disputeStaffDecision,
  refundOwedPiasters: refundOwedPiasters,
  refundOwedDueAt: refundOwedDueAt,
);
