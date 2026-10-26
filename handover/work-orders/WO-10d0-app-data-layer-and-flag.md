# WO-10d0: InstaPay app data layer and the feature flag
Depends on: server WO-10a (rules), WO-10b (callables). Compare names first (INDEX-10-app.md contract).
Size: L
Reads first: `app/lib/domain/flags/feature_flags.dart` lines 135-143, 305-312, 354-375, 378-405, 493-497; `app/lib/features/private_coaching/domain/parse.dart` lines 1-60; `app/lib/features/private_coaching/data/firestore_coaching_repository.dart` lines 60-160 and 770-790; `app/test/features/private_coaching/support/fake_coaching_repository.dart` lines 28-75; `handover/work-orders/INDEX-10-app.md`

## Why
Every payment screen needs the same things: a switch that can be turned off in an emergency, a typed view of a payment, one door to the server, and a fake for tests. Building them once keeps the nine screen orders small. This feature is separate from the old coaching repository on purpose: the old interface has many implementers (fakes, chat), and the old `submit_payment_proof` and `record_refund` shapes must not be stretched.

## Final result
No screen changes. The code adds: `Feature.instapayPayments` (shipped ON, child of `marketplace`, server may turn it off); `Payment`, `PaymentStatus`, `PaymentEvent`, `CoachAddress`, `FeeStatement`; `InstapayRepository` with a Firestore implementation and an in-memory fake; `PaymentFailure`; `egpText`; a phone-side store for her saved sender handle and for idempotency keys; the constants `PayScreens`.

## Files to edit or create
| path | create or edit | what changes in one line |
|---|---|---|
| app/lib/domain/flags/feature_flags.dart | edit | add the enum value, its parent, its shipped line, its `gatesNoScreen` reason |
| app/lib/features/instapay/domain/instapay_models.dart | create | the typed payment, statuses, events, coach address, statement, `egpText` |
| app/lib/features/instapay/data/instapay_repository.dart | create | callable names, `PaymentFailure`, abstract `InstapayRepository`, `PayScreens` |
| app/lib/features/instapay/data/firestore_instapay_repository.dart | create | real implementation |
| app/lib/features/instapay/data/instapay_local_store.dart | create | sender handle and idempotency key on the phone |
| app/test/features/instapay/support/fake_instapay_repository.dart | create | in-memory fake recording calls |
| app/test/features/instapay/instapay_models_test.dart | create | parse and money tests |
| app/test/domain/flags/feature_flags_test.dart | edit | one test: the flag is on and has a live parent |

## Steps
1. File `app/lib/domain/flags/feature_flags.dart`. Anchor: the line `payments,` in the enum (about line 142, below the doc comment "Taking money."). Add directly after it:
```dart

  /// InstaPay payments between a client and her coach (spec
  /// `docs/plan/INSTAPAY-PAYMENTS-SPEC.md`). Own Hub never holds the money.
  /// Its parent is [marketplace], NOT [payments]: [payments] ships off, and a
  /// child of it could never open. The server switch `config/payments.enabled`
  /// is the emergency off button and arrives through `meta/features`.
  instapayPayments,
```
2. Same file. Anchor: `payments => marketplace,` (about line 311). Add below it: `instapayPayments => marketplace,`
3. Same file. Anchor: `Feature.payments: false,` in `FeatureFlags.shipped` (about line 495). Add below it: `Feature.instapayPayments: true,`. Do NOT change `serverMayTurnOff` (the flag is absent from its exclusion set, so the server may turn it off, which is wanted). Do NOT change `serverMayTurnOn`.
4. Same file. Anchor: `static const Map<Feature, String> gatesNoScreen = {` (about line 382). Add as the first entry: `Feature.instapayPayments: 'Checked by the payment entry points: the pay card on H05 and the Payments row on K18. Its screens are pushed, not routed.',`
5. File `app/lib/features/instapay/domain/instapay_models.dart` (create). Full content:
```dart
/// A payment between a client and her coach, as the server keeps it.
/// Read only: every change goes through a callable.
library;

import '../../private_coaching/domain/parse.dart';

enum PaymentStatus {
  awaitingPayment('awaiting_payment'),
  proofSubmitted('proof_submitted'),
  confirmed('confirmed'),
  expired('expired'),
  cancelled('cancelled'),
  coachNotReceived('coach_not_received'),
  inReview('in_review'),
  resolvedPaid('resolved_paid'),
  resolvedUnpaid('resolved_unpaid'),
  differentAmount('different_amount'),
  refundRequested('refund_requested'),
  refunded('refunded'),
  refundDenied('refund_denied'),
  serviceDispute('service_dispute');

  const PaymentStatus(this.wire);
  final String wire;

  static PaymentStatus? fromWire(Object? v) {
    for (final s in values) {
      if (s.wire == v) return s;
    }
    return null;
  }

  /// A package is active only in these two (spec section 3).
  bool get activatesPackage => this == confirmed || this == resolvedPaid;
}

enum RiskOutcome { green, amber, red }

class CoachAddress {
  const CoachAddress({this.address = '', this.accountName = ''});
  final String address;
  final String accountName;
  bool get isEmpty => address.isEmpty;
}

class PaymentEvent {
  const PaymentEvent({this.at, this.by = '', this.from = '', this.to = '', this.note = ''});
  final DateTime? at;
  final String by;
  final String from;
  final String to;
  final String note;

  factory PaymentEvent.fromMap(Object? raw) {
    final m = asMap(raw) ?? const <String, Object?>{};
    return PaymentEvent(
      at: readTime(m['at']),
      by: readString(m['by']),
      from: readString(m['from']),
      to: readString(m['to']),
      note: readString(m['note']),
    );
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.clientUid,
    required this.coachUid,
    required this.status,
    this.packageId = '',
    this.amountPiasters = 0,
    this.reference = '',
    this.address = const CoachAddress(),
    this.createdAt,
    this.expiresAt,
    this.accessUntil,
    this.riskOutcome,
    this.reasons = const <String>[],
    this.txnNumber = '',
    this.submittedAt,
    this.notReceivedReason = '',
    this.differentAmountPiasters = 0,
    this.feePiasters = 0,
    this.refundAmountPiasters = 0,
  });

  final String id;
  final String clientUid;
  final String coachUid;
  final PaymentStatus status;
  final String packageId;
  final int amountPiasters;
  final String reference;
  final CoachAddress address;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? accessUntil;
  final RiskOutcome? riskOutcome;
  final List<String> reasons;
  final String txnNumber;
  final DateTime? submittedAt;
  final String notReceivedReason;
  final int differentAmountPiasters;
  final int feePiasters;
  final int refundAmountPiasters;

  /// Whole pounds when there are no piasters, else two decimals.
  String amountText({bool arabic = false}) => egpText(amountPiasters, arabic: arabic);

  /// Time left to pay; zero once past. [now] is the phone clock, a display only.
  Duration timeLeft(DateTime now) {
    final end = expiresAt;
    if (end == null || !end.isAfter(now)) return Duration.zero;
    return end.difference(now);
  }

  static Payment? fromMap(String id, Object? raw) {
    final m = asMap(raw);
    final status = PaymentStatus.fromWire(m?['status']);
    if (m == null || id.isEmpty || status == null) return null;
    final proof = asMap(m['proof']) ?? const <String, Object?>{};
    final dec = asMap(m['coachDecision']) ?? const <String, Object?>{};
    final snap = asMap(m['addressSnapshot']) ?? const <String, Object?>{};
    final refund = asMap(m['refund']) ?? const <String, Object?>{};
    final risk = readString(m['riskOutcome']);
    return Payment(
      id: id,
      clientUid: readString(m['clientUid']),
      coachUid: readString(m['coachUid']),
      status: status,
      packageId: readString(m['packageId']),
      amountPiasters: readInt(m['amountPiasters']),
      reference: readString(m['reference']),
      address: CoachAddress(
        address: readString(snap['address']),
        accountName: readString(snap['accountName']),
      ),
      createdAt: readTime(m['createdAt']),
      expiresAt: readTime(m['expiresAt']),
      accessUntil: readTime(m['accessUntil']),
      riskOutcome: RiskOutcome.values.where((r) => r.name == risk).firstOrNull,
      reasons: readStrings(m['reasons']),
      txnNumber: readString(proof['txnNumber']),
      submittedAt: readTime(proof['submittedAt']),
      notReceivedReason: readString(dec['reasonCode']),
      differentAmountPiasters: readInt(dec['differentAmountPiasters']),
      feePiasters: readInt(m['feePiasters']),
      refundAmountPiasters: readInt(refund['amountPiasters']),
    );
  }
}

class FeeStatement {
  const FeeStatement({
    required this.id,
    this.month = '',
    this.totalFeePiasters = 0,
    this.paymentCount = 0,
    this.paid = false,
  });
  final String id;
  final String month;
  final int totalFeePiasters;
  final int paymentCount;
  final bool paid;

  static FeeStatement? fromMap(String id, Object? raw) {
    final m = asMap(raw);
    if (m == null || id.isEmpty) return null;
    return FeeStatement(
      id: id,
      month: readString(m['month']),
      totalFeePiasters: readInt(m['totalFeePiasters']),
      paymentCount: readMaps(m['lines']).length,
      paid: readString(m['status']) == 'paid',
    );
  }
}

/// "500.37 EGP" / "500.37 جنيه"; whole pounds drop the decimals. Western digits.
String egpText(int piasters, {bool arabic = false}) {
  final pounds = piasters ~/ 100;
  final rest = piasters % 100;
  final number = rest == 0 ? '$pounds' : '$pounds.${rest.toString().padLeft(2, '0')}';
  return arabic ? '$number جنيه' : '$number EGP';
}
```
UNVERIFIED: `firstOrNull` needs Dart 3 (pubspec says sdk ^3.13.3, so it exists). `asMap`, `readMaps` come from `parse.dart` (verified names: `readString`, `readInt`, `readTime`, `readStrings`, `readMaps`; `asMap` is used in `payments.dart` line 1-20 of that file via `import 'parse.dart'`). Run `grep -n "Json? asMap\|asMap(" app/lib/features/private_coaching/domain/parse.dart`.
6. File `app/lib/features/instapay/data/instapay_repository.dart` (create). Full content:
```dart
library;

import 'dart:typed_data';

import '../domain/instapay_models.dart';

/// Screen names for tests, analytics-free logs and the budget list.
class PayScreens {
  static const pay1 = 'PAY1';
  static const pay2 = 'PAY2';
  static const pay3 = 'PAY3';
  static const pay4 = 'PAY4';
  static const pay5 = 'PAY5';
  static const pay6 = 'PAY6';
  static const pay7 = 'PAY7';
  static const pay8 = 'PAY8';
  static const pay9 = 'PAY9';
  static const pay10 = 'PAY10';
}

/// Callable names. The ONLY place they are written (INDEX-10-app.md, Q1-Q3).
class InstapayCallables {
  static const createPayment = 'create_payment';
  static const submitProof = 'submit_payment_proof';
  static const coachConfirm = 'coach_confirm_payment';
  static const coachNotReceived = 'coach_mark_not_received';
  static const coachDifferentAmount = 'coach_mark_different_amount';
  static const coachReport = 'coach_report_payment';
  static const clientConfirmReport = 'client_confirm_coach_report';
  static const setAddress = 'set_coach_instapay_address';
  static const requestRefund = 'request_refund';
  static const recordRefund = 'record_refund';
  static const openServiceDispute = 'open_service_dispute';
  static const markFeePaid = 'mark_fee_statement_paid';
  static const setAutoConfirm = 'set_auto_confirm';
}

/// A refusal. [reason] is the server's reason code (the HttpsError message),
/// empty when unknown. [unreachable] means no signal: the screen may queue.
class PaymentFailure implements Exception {
  const PaymentFailure(this.reason, {this.unreachable = false});
  final String reason;
  final bool unreachable;
  @override
  String toString() => 'PaymentFailure($reason, unreachable: $unreachable)';
}

class ProofResult {
  const ProofResult({required this.status, this.outcome, this.reasons = const <String>[]});
  final PaymentStatus status;
  final RiskOutcome? outcome;
  final List<String> reasons;
}

abstract class InstapayRepository {
  String? get uid;

  Stream<Payment?> watchPayment(String paymentId);
  Stream<List<Payment>> watchMyPaymentsAsClient();
  Stream<List<Payment>> watchMyPaymentsAsCoach();
  Stream<List<PaymentEvent>> watchEvents(String paymentId);
  Stream<CoachAddress?> watchMyAddress();
  Stream<List<FeeStatement>> watchMyStatements();

  Future<Payment> createPayment({required String subId, required String packageId, required String idempotencyKey, required String locale});

  /// Uploads each image, then calls the server. Paths are
  /// `payment-proofs/{paymentId}/{idempotencyKey}-{n}.jpg`.
  Future<ProofResult> submitProof({
    required String paymentId,
    required String idempotencyKey,
    required String txnNumber,
    required DateTime paidAtClaimed,
    required String senderHandle,
    required List<Uint8List> images,
    required Map<String, Object?> phoneReading,
    required String locale,
    bool addEvidence = false,
  });

  Future<PaymentStatus> coachConfirm(String paymentId, String key);
  Future<PaymentStatus> coachNotReceived({required String paymentId, required String key, required String reasonCode, required String note, required Uint8List statement});
  Future<PaymentStatus> coachDifferentAmount({required String paymentId, required String key, required int amountPiasters, required bool acceptLower});
  Future<void> coachReport({required String subId, required String txnNumber, required String key});
  Future<void> clientConfirmReport({required String paymentId, required bool accept});
  Future<DateTime?> requestAddressChange({required String address, required String accountName, required String key});
  Future<DateTime?> verifyAddressChange({required String otp, required String key});
  Future<PaymentStatus> requestRefund({required String paymentId, required String key, required String reasonCode, required String note});
  Future<PaymentStatus> recordRefund({required String paymentId, required String key, required int amountPiasters, required String txnNumber});
  Future<PaymentStatus> openServiceDispute({required String paymentId, required String key, required String reasonCode, required String note});
  Future<void> markFeePaid({required String statementId, required String txnNumber, required String key});
  Future<void> setAutoConfirm(bool enabled);
}
```
7. File `app/lib/features/instapay/data/firestore_instapay_repository.dart` (create). Pattern copied from `firestore_coaching_repository.dart` (`_call`, `_guard`, `_one`, `_list`, lines 79-155). Full content:
```dart
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../app_state/firebase_boot.dart';
import '../../private_coaching/data/firestore_coaching_repository.dart'
    show kCoachingCallTimeout, kCoachingProofTimeout;
import '../../private_coaching/data/firestore_plain.dart';
import '../../private_coaching/domain/parse.dart';
import '../domain/instapay_models.dart';
import 'instapay_repository.dart';

class FirestoreInstapayRepository implements InstapayRepository {
  FirestoreInstapayRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions, FirebaseStorage? storage})
    : _fs = firestore, _fn = functions, _st = storage;

  final FirebaseFirestore? _fs;
  final FirebaseFunctions? _fn;
  final FirebaseStorage? _st;

  FirebaseFirestore get _db => _fs ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions => _fn ?? FirebaseBoot.functions;
  FirebaseStorage get _storage => _st ?? FirebaseBoot.personalMedia;

  @override
  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  PaymentFailure _failure(FirebaseFunctionsException e) => PaymentFailure(
    e.message ?? '',
    unreachable: const {'unavailable', 'deadline-exceeded', 'cancelled'}.contains(e.code),
  );

  Stream<T> _guard<T>(Stream<T> s) => s.transform(
    StreamTransformer<T, T>.fromHandlers(
      handleError: (e, st, sink) => sink.addError(
        PaymentFailure('', unreachable: e is FirebaseException && e.code == 'unavailable'),
        st,
      ),
    ),
  );

  Future<Map<String, Object?>> _call(String name, Map<String, Object?> payload, {Duration timeout = kCoachingCallTimeout}) async {
    if ((uid ?? '').isEmpty) throw const PaymentFailure('signed_out');
    try {
      final r = await _functions.httpsCallable(name, options: HttpsCallableOptions(timeout: timeout)).call<Object?>(payload);
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

  @override
  Stream<Payment?> watchPayment(String id) => _guard(_db.collection('payments').doc(id).snapshots().map(
    (s) => s.exists ? Payment.fromMap(s.id, firestorePlain(s.data())) : null));

  Stream<List<Payment>> _byField(String field) => _guard(
    _db.collection('payments').where(field, isEqualTo: uid).orderBy('createdAt', descending: true).limit(50).snapshots().map(
      (q) => <Payment>[for (final d in q.docs) ?Payment.fromMap(d.id, firestorePlain(d.data()))]));

  @override
  Stream<List<Payment>> watchMyPaymentsAsClient() => _byField('clientUid');
  @override
  Stream<List<Payment>> watchMyPaymentsAsCoach() => _byField('coachUid');

  @override
  Stream<List<PaymentEvent>> watchEvents(String id) => _guard(
    _db.collection('payments').doc(id).collection('events').orderBy('at').snapshots().map(
      (q) => <PaymentEvent>[for (final d in q.docs) PaymentEvent.fromMap(firestorePlain(d.data()))]));

  @override
  Stream<CoachAddress?> watchMyAddress() => _guard(
    _db.collection('coachPayoutProfiles').doc(uid).snapshots().map((s) {
      final m = asMap(firestorePlain(s.data()));
      if (m == null) return null;
      return CoachAddress(address: readString(m['address']), accountName: readString(m['accountName']));
    }));

  @override
  Stream<List<FeeStatement>> watchMyStatements() => _guard(
    _db.collection('feeStatements').where('coachUid', isEqualTo: uid).orderBy('month', descending: true).limit(12).snapshots().map(
      (q) => <FeeStatement>[for (final d in q.docs) ?FeeStatement.fromMap(d.id, firestorePlain(d.data()))]));

  @override
  Future<Payment> createPayment({required String subId, required String packageId, required String idempotencyKey, required String locale}) async {
    final d = await _call(InstapayCallables.createPayment, {'subId': subId, 'packageId': packageId, 'idempotencyKey': idempotencyKey, 'locale': locale});
    final id = readStringOrNull(d['paymentId']);
    if (id == null) throw const PaymentFailure('unreadable');
    return Payment(
      id: id, clientUid: uid ?? '', coachUid: '', status: _status(d),
      packageId: packageId, amountPiasters: readInt(d['amountPiasters']),
      reference: readString(d['reference']), expiresAt: readTime(d['expiresAt']),
    );
  }

  @override
  Future<ProofResult> submitProof({
    required String paymentId, required String idempotencyKey, required String txnNumber,
    required DateTime paidAtClaimed, required String senderHandle, required List<Uint8List> images,
    required Map<String, Object?> phoneReading, required String locale, bool addEvidence = false,
  }) async {
    final paths = <String>[];
    try {
      for (var n = 0; n < images.length; n++) {
        final path = 'payment-proofs/$paymentId/$idempotencyKey-$n.jpg';
        await _storage.ref(path).putData(images[n], SettableMetadata(contentType: 'image/jpeg'));
        paths.add(path);
      }
    } on FirebaseException catch (e) {
      throw PaymentFailure('', unreachable: e.code == 'unavailable' || e.code == 'retry-limit-exceeded');
    }
    final d = await _call(InstapayCallables.submitProof, {
      'paymentId': paymentId, 'idempotencyKey': idempotencyKey, 'txnNumber': txnNumber.trim(),
      'paidAtClaimed': paidAtClaimed.toUtc().toIso8601String(), 'senderHandle': senderHandle,
      'screenshotPaths': paths, 'phoneReading': phoneReading, 'addEvidence': addEvidence, 'locale': locale,
    }, timeout: kCoachingProofTimeout);
    final out = readString(d['riskOutcome']);
    return ProofResult(
      status: _status(d),
      outcome: RiskOutcome.values.where((r) => r.name == out).firstOrNull,
      reasons: readStrings(d['reasons']),
    );
  }

  Future<PaymentStatus> _statusCall(String name, Map<String, Object?> p) async => _status(await _call(name, p));

  @override
  Future<PaymentStatus> coachConfirm(String id, String key) =>
      _statusCall(InstapayCallables.coachConfirm, {'paymentId': id, 'idempotencyKey': key});

  @override
  Future<PaymentStatus> coachNotReceived({required String paymentId, required String key, required String reasonCode, required String note, required Uint8List statement}) async {
    final path = 'payment-proofs/$paymentId/coach-$key.jpg';
    try {
      await _storage.ref(path).putData(statement, SettableMetadata(contentType: 'image/jpeg'));
    } on FirebaseException catch (e) {
      throw PaymentFailure('', unreachable: e.code == 'unavailable');
    }
    return _statusCall(InstapayCallables.coachNotReceived, {'paymentId': paymentId, 'idempotencyKey': key, 'reasonCode': reasonCode, 'note': note, 'searchedTick': true, 'statementPath': path});
  }

  @override
  Future<PaymentStatus> coachDifferentAmount({required String paymentId, required String key, required int amountPiasters, required bool acceptLower}) =>
      _statusCall(InstapayCallables.coachDifferentAmount, {'paymentId': paymentId, 'idempotencyKey': key, 'amountPiasters': amountPiasters, 'acceptLower': acceptLower});

  @override
  Future<void> coachReport({required String subId, required String txnNumber, required String key}) async {
    await _call(InstapayCallables.coachReport, {'subId': subId, 'txnNumber': txnNumber, 'idempotencyKey': key});
  }

  @override
  Future<void> clientConfirmReport({required String paymentId, required bool accept}) async {
    await _call(InstapayCallables.clientConfirmReport, {'paymentId': paymentId, 'accept': accept});
  }

  @override
  Future<DateTime?> requestAddressChange({required String address, required String accountName, required String key}) async =>
      readTime((await _call(InstapayCallables.setAddress, {'step': 'request', 'address': address, 'accountName': accountName, 'idempotencyKey': key}))['effectiveAt']);

  @override
  Future<DateTime?> verifyAddressChange({required String otp, required String key}) async =>
      readTime((await _call(InstapayCallables.setAddress, {'step': 'verify', 'otp': otp, 'idempotencyKey': key}))['effectiveAt']);

  @override
  Future<PaymentStatus> requestRefund({required String paymentId, required String key, required String reasonCode, required String note}) =>
      _statusCall(InstapayCallables.requestRefund, {'paymentId': paymentId, 'idempotencyKey': key, 'reasonCode': reasonCode, 'note': note});

  @override
  Future<PaymentStatus> recordRefund({required String paymentId, required String key, required int amountPiasters, required String txnNumber}) =>
      _statusCall(InstapayCallables.recordRefund, {'paymentId': paymentId, 'idempotencyKey': key, 'amountPiasters': amountPiasters, 'txnNumber': txnNumber});

  @override
  Future<PaymentStatus> openServiceDispute({required String paymentId, required String key, required String reasonCode, required String note}) =>
      _statusCall(InstapayCallables.openServiceDispute, {'paymentId': paymentId, 'idempotencyKey': key, 'reasonCode': reasonCode, 'note': note});

  @override
  Future<void> markFeePaid({required String statementId, required String txnNumber, required String key}) async {
    await _call(InstapayCallables.markFeePaid, {'statementId': statementId, 'txnNumber': txnNumber, 'idempotencyKey': key});
  }

  @override
  Future<void> setAutoConfirm(bool enabled) async {
    await _call(InstapayCallables.setAutoConfirm, {'enabled': enabled});
  }
}
```
UNVERIFIED: `firestorePlain` signature (`Map<String,dynamic>?` in, plain map out); verify `sed -n 1,30p app/lib/features/private_coaching/data/firestore_plain.dart`. The Firestore index for `payments` by `clientUid`/`coachUid` + `createdAt` is a server order (WO-10a); if the query errors with "index required", write it to QUESTIONS.md.
8. File `app/lib/features/instapay/data/instapay_local_store.dart` (create). Uses `shared_preferences` (in pubspec). Full content:
```dart
library;

import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Things that stay on the phone: her own InstaPay handle (asked once) and the
/// idempotency key of the action she is in the middle of. A retry or a double
/// tap reuses the key, so the server makes one payment.
class InstapayLocalStore {
  static const _handleKey = 'instapay.senderHandle';
  static const _consentKey = 'instapay.learnConsent';

  Future<String> senderHandle() async {
    try {
      return (await SharedPreferences.getInstance()).getString(_handleKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> saveSenderHandle(String handle) async {
    try {
      await (await SharedPreferences.getInstance()).setString(_handleKey, handle.trim());
    } catch (_) {}
  }

  Future<bool> learnConsent() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_consentKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> saveLearnConsent(bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_consentKey, v);
    } catch (_) {}
  }

  /// 24 hex characters.
  static String newKey([Random? r]) {
    final g = r ?? Random.secure();
    const hex = '0123456789abcdef';
    return List<String>.generate(24, (_) => hex[g.nextInt(16)]).join();
  }
}
```
9. File `app/test/features/instapay/support/fake_instapay_repository.dart` (create). Full content:
```dart
import 'dart:async';
import 'dart:typed_data';

import 'package:own_hub/features/instapay/data/instapay_repository.dart';
import 'package:own_hub/features/instapay/domain/instapay_models.dart';

class FakeInstapayRepository implements InstapayRepository {
  FakeInstapayRepository({this.uid = 'me'});
  @override
  String? uid;

  final List<(String, Map<String, Object?>)> calls = <(String, Map<String, Object?>)>[];
  PaymentFailure? failNext;
  PaymentStatus nextStatus = PaymentStatus.proofSubmitted;
  RiskOutcome nextOutcome = RiskOutcome.green;

  final _payments = StreamController<List<Payment>>.broadcast(sync: true);
  List<Payment> all = <Payment>[];
  CoachAddress? address;
  List<FeeStatement> statements = <FeeStatement>[];
  List<PaymentEvent> events = <PaymentEvent>[];

  void setPayments(List<Payment> list) {
    all = list;
    _payments.add(list);
  }

  Never _throwIfFailing() {
    final f = failNext!;
    failNext = null;
    throw f;
  }

  PaymentStatus _record(String name, Map<String, Object?> args) {
    calls.add((name, args));
    if (failNext != null) _throwIfFailing();
    return nextStatus;
  }

  Stream<List<Payment>> _list(bool Function(Payment) keep) => Stream<List<Payment>>.multi((c) {
    c.add(all.where(keep).toList());
    final s = _payments.stream.listen((l) => c.add(l.where(keep).toList()));
    c.onCancel = s.cancel;
  });

  @override
  Stream<Payment?> watchPayment(String id) => _list((p) => p.id == id).map((l) => l.isEmpty ? null : l.first);
  @override
  Stream<List<Payment>> watchMyPaymentsAsClient() => _list((p) => p.clientUid == uid);
  @override
  Stream<List<Payment>> watchMyPaymentsAsCoach() => _list((p) => p.coachUid == uid);
  @override
  Stream<List<PaymentEvent>> watchEvents(String id) => Stream<List<PaymentEvent>>.value(events);
  @override
  Stream<CoachAddress?> watchMyAddress() => Stream<CoachAddress?>.value(address);
  @override
  Stream<List<FeeStatement>> watchMyStatements() => Stream<List<FeeStatement>>.value(statements);

  @override
  Future<Payment> createPayment({required String subId, required String packageId, required String idempotencyKey, required String locale}) async {
    _record('createPayment', {'subId': subId, 'packageId': packageId, 'key': idempotencyKey});
    return Payment(id: 'p1', clientUid: uid ?? '', coachUid: 'coach', status: PaymentStatus.awaitingPayment,
      amountPiasters: 50037, reference: 'OH-4821', address: const CoachAddress(address: 'rahma@instapay', accountName: 'Rahma M.'),
      expiresAt: DateTime.now().add(const Duration(hours: 24)));
  }

  @override
  Future<ProofResult> submitProof({required String paymentId, required String idempotencyKey, required String txnNumber, required DateTime paidAtClaimed, required String senderHandle, required List<Uint8List> images, required Map<String, Object?> phoneReading, required String locale, bool addEvidence = false}) async {
    _record('submitProof', {'paymentId': paymentId, 'key': idempotencyKey, 'txn': txnNumber, 'images': images.length, 'handle': senderHandle, 'addEvidence': addEvidence});
    return ProofResult(status: nextStatus, outcome: nextOutcome);
  }

  @override
  Future<PaymentStatus> coachConfirm(String id, String key) async => _record('coachConfirm', {'id': id, 'key': key});
  @override
  Future<PaymentStatus> coachNotReceived({required String paymentId, required String key, required String reasonCode, required String note, required Uint8List statement}) async =>
      _record('coachNotReceived', {'id': paymentId, 'reason': reasonCode, 'note': note});
  @override
  Future<PaymentStatus> coachDifferentAmount({required String paymentId, required String key, required int amountPiasters, required bool acceptLower}) async =>
      _record('coachDifferentAmount', {'id': paymentId, 'amount': amountPiasters, 'acceptLower': acceptLower});
  @override
  Future<void> coachReport({required String subId, required String txnNumber, required String key}) async {
    _record('coachReport', {'subId': subId, 'txn': txnNumber});
  }
  @override
  Future<void> clientConfirmReport({required String paymentId, required bool accept}) async {
    _record('clientConfirmReport', {'id': paymentId, 'accept': accept});
  }
  @override
  Future<DateTime?> requestAddressChange({required String address, required String accountName, required String key}) async {
    _record('requestAddressChange', {'address': address, 'name': accountName});
    return DateTime.now().add(const Duration(hours: 24));
  }
  @override
  Future<DateTime?> verifyAddressChange({required String otp, required String key}) async {
    _record('verifyAddressChange', {'otp': otp});
    return DateTime.now().add(const Duration(hours: 24));
  }
  @override
  Future<PaymentStatus> requestRefund({required String paymentId, required String key, required String reasonCode, required String note}) async =>
      _record('requestRefund', {'id': paymentId, 'reason': reasonCode});
  @override
  Future<PaymentStatus> recordRefund({required String paymentId, required String key, required int amountPiasters, required String txnNumber}) async =>
      _record('recordRefund', {'id': paymentId, 'amount': amountPiasters, 'txn': txnNumber});
  @override
  Future<PaymentStatus> openServiceDispute({required String paymentId, required String key, required String reasonCode, required String note}) async =>
      _record('openServiceDispute', {'id': paymentId, 'reason': reasonCode});
  @override
  Future<void> markFeePaid({required String statementId, required String txnNumber, required String key}) async {
    _record('markFeePaid', {'id': statementId, 'txn': txnNumber});
  }
  @override
  Future<void> setAutoConfirm(bool enabled) async {
    _record('setAutoConfirm', {'enabled': enabled});
  }
}
```
10. File `app/test/features/instapay/instapay_models_test.dart` (create), plus one test appended to `app/test/domain/flags/feature_flags_test.dart` (see Tests).

## Strings to add
None.

## Tests to add or change
| file | test name | arrange, act, assert |
|---|---|---|
| app/test/features/instapay/instapay_models_test.dart | `egpText writes piasters and drops .00` | `egpText(50037)` equals `'500.37 EGP'`; `egpText(50000)` equals `'500 EGP'`; `egpText(50005, arabic: true)` equals `'500.05 جنيه'` |
| same | `Payment.fromMap reads a full document` | map with status `proof_submitted`, `amountPiasters: 50037`, `addressSnapshot: {address: 'a@instapay', accountName: 'Rahma M.'}`, `proof: {txnNumber: '123'}`; assert status, amount, address.accountName, txnNumber |
| same | `an unknown status is not a payment` | `Payment.fromMap('p', {'status': 'zzz'})` is null; empty id is null |
| same | `only confirmed and resolved_paid activate a package` | loop all `PaymentStatus.values`; `activatesPackage` is true for exactly two |
| same | `timeLeft is zero once past` | `expiresAt` one minute before `now` gives `Duration.zero` |
| same | `newKey is 24 hex and different each time` | two keys match `^[0-9a-f]{24}$` and differ |
| app/test/domain/flags/feature_flags_test.dart | `instapayPayments is on and can open` | `FeatureFlags.shipped.isOn(Feature.instapayPayments)` is true (this proves `marketplace`, its parent, is on in the shipped build). UNVERIFIED how `shipped` is named in that test file: `grep -n "FeatureFlags.shipped" app/test/domain/flags/feature_flags_test.dart` |

Run: `cd app && flutter test test/features/instapay test/domain/flags` .

## Verify
- `cd app && dart analyze lib/features/instapay lib/domain/flags test/features/instapay` ends with `No issues found!`
- `cd app && flutter test test/features/instapay test/domain/flags` ends with `All tests passed!` (the existing `every_feature_has_a_switch_test.dart` must pass: it needs the `gatesNoScreen` entry from step 4)
- `cd app && flutter test test/product_rules_test.dart` still passes.

## Do not
- Do not edit `coaching_repository.dart`, `payments.dart` (the old money pages) or the old `PaymentProofForm`.
- Do not make the flag a child of `payments`.
- Do not write a payment from the client: no Firestore `set` or `update` anywhere in this feature.
- Do not log txn numbers, amounts or paths to analytics (spec 4.15).

## Done checklist
- [ ] flag, parent, shipped line, gatesNoScreen entry
- [ ] models, repository, firestore repository, local store, fake
- [ ] tests written and passing; analyze clean
- [ ] differences from server names written to handover/QUESTIONS.md

## If stuck
If an anchor is not found or a test fails twice: stop, write the question to `handover/QUESTIONS.md` with file:line and what you saw, and move to WO-10j2 or WO-10q, which do not depend on this one.

UNVERIFIED in this order: 3 (asMap name, firestorePlain signature, feature_flags_test variable name).
