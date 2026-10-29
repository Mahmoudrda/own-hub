library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app_state/firebase_boot.dart';
import '../../private_coaching/data/firestore_coaching_repository.dart'
    show kCoachingCallTimeout, kCoachingProofTimeout;
import '../../private_coaching/data/firestore_plain.dart';
import '../../private_coaching/domain/parse.dart';
import '../../signup/domain/legal_acceptance.dart' show kAppBuild;
import '../domain/payment_models.dart';
import 'payments_repository.dart';

class FirestorePaymentsRepository implements PaymentsRepository {
  FirestorePaymentsRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _fs = firestore,
       _fn = functions;

  final FirebaseFirestore? _fs;
  final FirebaseFunctions? _fn;

  FirebaseFirestore get _db => _fs ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions => _fn ?? FirebaseBoot.functions;

  @override
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  PaymentFailure _failure(FirebaseFunctionsException e) => PaymentFailure(
    e.message ?? '',
    unreachable: const {
      'unavailable',
      'deadline-exceeded',
      'cancelled',
    }.contains(e.code),
  );

  Stream<T> _guard<T>(Stream<T> s) => s.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (e, st, sink) => sink.addError(
        PaymentFailure(
          '',
          unreachable: e is FirebaseException && e.code == 'unavailable',
        ),
        st,
      ),
    ),
  );

  Future<Map<String, Object?>> _call(
    String name,
    Map<String, Object?> payload, {
    Duration timeout = kCoachingCallTimeout,
  }) async {
    if ((uid ?? '').isEmpty) throw const PaymentFailure('signed_out');
    try {
      final r = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
          .call<Object?>(payload);
      return asMap(r.data) ?? const <String, Object?>{};
    } on FirebaseFunctionsException catch (e) {
      throw _failure(e);
    }
  }

  PaymentStatus _status(Map<String, Object?> d) {
    final s = PaymentStatus.fromWire(d['status']);
    if (s == null) throw const PaymentFailure('unreadable');
    return s;
  }

  Future<PaymentStatus> _statusCall(
    String name,
    Map<String, Object?> p,
  ) async => _status(await _call(name, p));

  List<String> _b64(List<Uint8List> images) => <String>[
    for (final i in images) base64Encode(i),
  ];

  // ------------------------------------------------------------------ reads

  @override
  Stream<Payment?> watchPayment(String id) => _guard(
    _db
        .collection('payments')
        .doc(id)
        .snapshots()
        .map(
          (s) =>
              s.exists ? Payment.fromMap(s.id, firestorePlain(s.data())) : null,
        ),
  );

  Stream<List<Payment>> _byField(String field) => _guard(
    _db
        .collection('payments')
        .where(field, isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (q) => <Payment>[
            for (final d in q.docs)
              ?Payment.fromMap(d.id, firestorePlain(d.data())),
          ],
        ),
  );

  @override
  Stream<List<Payment>> watchMyPaymentsAsClient() => _byField('clientUid');

  @override
  Stream<List<Payment>> watchMyPaymentsAsCoach() => _byField('coachUid');

  @override
  Stream<List<PaymentEvent>> watchEvents(String id) => _guard(
    _db
        .collection('payments')
        .doc(id)
        .collection('events')
        .orderBy('at')
        .snapshots()
        .map(
          (q) => <PaymentEvent>[
            for (final d in q.docs)
              PaymentEvent.fromMap(firestorePlain(d.data())),
          ],
        ),
  );

  @override
  Stream<CoachAddress?> watchMyAddress() => _guard(
    _db
        .collection('coachPaymentProfiles')
        .doc(uid)
        .snapshots()
        .map(
          (s) =>
              s.exists ? CoachAddress.fromMap(firestorePlain(s.data())) : null,
        ),
  );

  @override
  Stream<List<FeeStatement>> watchMyStatements() => _guard(
    _db
        .collection('feeStatements')
        .where('coachUid', isEqualTo: uid)
        .limit(24)
        .snapshots()
        .map((q) {
          final list = <FeeStatement>[
            for (final d in q.docs)
              ?FeeStatement.fromMap(d.id, firestorePlain(d.data())),
          ];
          list.sort(
            (a, b) =>
                (b.year * 100 + b.month).compareTo(a.year * 100 + a.month),
          );
          return list;
        }),
  );

  @override
  Future<bool?> paymentsEnabled() async {
    try {
      final s = await _db
          .collection('config')
          .doc('payments')
          .get()
          .timeout(const Duration(seconds: 8));
      return s.exists && s.data()?['enabled'] == true;
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------------------------------- client

  @override
  Future<Payment> createPayment({
    required String subId,
    required String idempotencyKey,
    String? topUpOf,
  }) async {
    final d = await _call(PaymentCallables.createPayment, {
      'subId': subId,
      'idempotencyKey': idempotencyKey,
      'topUpOf': ?topUpOf,
      'appBuild': kAppBuild,
    });
    final id = readStringOrNull(d['paymentId']);
    if (id == null) throw const PaymentFailure('unreadable');
    return Payment(
      id: id,
      clientUid: uid ?? '',
      coachUid: '',
      subId: subId,
      status: _status(d),
      amountPiasters: readInt(d['amountPiasters']),
      reference: readString(d['reference']),
      address: CoachAddress(
        address: readString(d['address']),
        accountName: readString(d['accountName']),
      ),
      createdAt: DateTime.now().toUtc(),
      expiresAt: readTime(d['expiresAt']),
    );
  }

  @override
  Future<void> cancelPayment(String paymentId) async {
    await _call(PaymentCallables.cancelPayment, {'paymentId': paymentId});
  }

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
    final d = await _call(PaymentCallables.submitProof, {
      'paymentId': paymentId,
      'idempotencyKey': idempotencyKey,
      'amountPiasters': amountPiasters,
      'images': _b64(images),
      'txnNumber': ?txnNumber,
      'senderHandle': ?senderHandle,
      if (paidAtClaimed != null)
        'paidAtClaimed': paidAtClaimed.toUtc().toIso8601String(),
      'phoneReading': phoneReading,
      if (otherPayerOk) 'otherPayerOk': true,
    }, timeout: kCoachingProofTimeout);
    final out = readString(d['outcome']);
    return ProofResult(
      status: _status(d),
      outcome: RiskOutcome.values.where((r) => r.name == out).firstOrNull,
      reasons: readStrings(d['reasons']),
      retry: readBool(d['retry']),
    );
  }

  @override
  Future<int> addEvidence({
    required String paymentId,
    required List<Uint8List> images,
    String? note,
  }) async {
    final d = await _call(PaymentCallables.addEvidence, {
      'paymentId': paymentId,
      'images': _b64(images),
      'note': ?note,
    }, timeout: kCoachingProofTimeout);
    return readInt(d['added']);
  }

  @override
  Future<PaymentStatus> clientAnswerReport(
    String paymentId, {
    required bool yes,
  }) => _statusCall(PaymentCallables.clientAnswerReport, {
    'paymentId': paymentId,
    'answer': yes ? 'yes' : 'no',
  });

  @override
  Future<PaymentStatus> clientRespondDifferentAmount(
    String paymentId, {
    required bool agree,
  }) => _statusCall(PaymentCallables.clientDifferentAmount, {
    'paymentId': paymentId,
    'decision': agree ? 'agree' : 'dispute',
  });

  // ------------------------------------------------------------------ coach

  @override
  Future<AddressChange> setAddress({
    required String address,
    required String accountName,
  }) async {
    final d = await _call(PaymentCallables.setAddress, {
      'address': address,
      'accountName': accountName,
    });
    return AddressChange(
      pending: readString(d['status']) == 'pending',
      effectiveAt: readTime(d['effectiveAt']),
    );
  }

  @override
  Future<PaymentStatus> coachConfirm(
    String paymentId, {
    int? receivedPiasters,
  }) => _statusCall(PaymentCallables.coachConfirm, {
    'paymentId': paymentId,
    'receivedPiasters': ?receivedPiasters,
  });

  @override
  Future<PaymentStatus> coachNotReceived({
    required String paymentId,
    required String reasonCode,
    required String note,
    required List<Uint8List> images,
  }) => _call(PaymentCallables.coachNotReceived, {
    'paymentId': paymentId,
    'reasonCode': reasonCode,
    'note': note,
    'searched': true,
    'images': _b64(images),
  }, timeout: kCoachingProofTimeout).then(_status);

  @override
  Future<PaymentStatus> coachDifferentAmount({
    required String paymentId,
    required int receivedPiasters,
    required bool acceptLower,
  }) => _statusCall(PaymentCallables.coachDifferentAmount, {
    'paymentId': paymentId,
    'receivedPiasters': receivedPiasters,
    'acceptLower': acceptLower,
  });

  @override
  Future<void> coachReport({
    String? subId,
    String? reference,
    required String txnNumber,
  }) async {
    await _call(PaymentCallables.coachReport, {
      'subId': ?subId,
      'reference': ?reference,
      'txnNumber': txnNumber,
    });
  }

  @override
  Future<void> setAutoConfirm(bool enabled) async {
    await _call(PaymentCallables.setAutoConfirm, {'enabled': enabled});
  }

  @override
  Future<PaymentStatus> requestRefund(String paymentId) =>
      _statusCall(PaymentCallables.requestRefund, {'paymentId': paymentId});

  @override
  Future<PaymentStatus> denyRefund(
    String paymentId, {
    required String reasonCode,
  }) => _statusCall(PaymentCallables.denyRefund, {
    'paymentId': paymentId,
    'reasonCode': reasonCode,
  });

  @override
  Future<PaymentStatus> recordRefund({
    required String paymentId,
    required String txnNumber,
    required int amountPiasters,
    required String kind,
    DateTime? paidAt,
  }) => _statusCall(PaymentCallables.recordRefund, {
    'paymentId': paymentId,
    'txnNumber': txnNumber,
    'amountPiasters': amountPiasters,
    'kind': kind,
    if (paidAt != null) 'paidAt': paidAt.toUtc().toIso8601String(),
  });

  @override
  Future<PaymentStatus> openServiceDispute(String paymentId, {String? note}) =>
      _statusCall(PaymentCallables.openServiceDispute, {
        'paymentId': paymentId,
        'note': ?note,
      });

  @override
  Future<void> recordFeePayment({
    required String statementId,
    required String txnNumber,
  }) async {
    await _call(PaymentCallables.recordFeePayment, {
      'statementId': statementId,
      'txnNumber': txnNumber,
    });
  }

  @override
  Future<Uint8List> partyImage({
    required String paymentId,
    required String path,
  }) async {
    final d = await _call(PaymentCallables.partyImage, {
      'paymentId': paymentId,
      'path': path,
    });
    final b = readString(d['imageB64']);
    if (b.isEmpty) throw const PaymentFailure('unreadable');
    return base64Decode(b);
  }
}
