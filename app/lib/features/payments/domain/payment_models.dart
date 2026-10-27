/// A payment between a client and her coach, as the server keeps it
/// (`functions/payments`). Read only: every change goes through a callable.
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

  /// Before any proof: she can still pay (or send a late proof).
  bool get unpaid => this == awaitingPayment || this == expired;

  /// Her proof is with the coach or staff and the payment is not settled yet.
  bool get settling =>
      this == proofSubmitted ||
      this == coachNotReceived ||
      this == inReview ||
      this == differentAmount;

  /// Over without a payment: nothing is owed and a new request may start.
  bool get dead => this == cancelled || this == resolvedUnpaid;
}

enum RiskOutcome { green, amber, red }

class CoachAddress {
  const CoachAddress({
    this.address = '',
    this.accountName = '',
    this.pendingAddress = '',
    this.pendingAccountName = '',
    this.pendingEffectiveAt,
  });
  final String address;
  final String accountName;

  /// A change waiting out its 24 hours (spec 4.4).
  final String pendingAddress;
  final String pendingAccountName;
  final DateTime? pendingEffectiveAt;

  bool get isEmpty => address.isEmpty && pendingAddress.isEmpty;

  /// Whether a change is still waiting at [now].
  bool pendingAt(DateTime now) =>
      pendingAddress.isNotEmpty &&
      pendingEffectiveAt != null &&
      pendingEffectiveAt!.isAfter(now);

  /// `coachPaymentProfiles/{uid}`: `address`, `accountName` and `pending`.
  static CoachAddress? fromMap(Object? raw) {
    final m = asMap(raw);
    if (m == null) return null;
    final p = asMap(m['pending']) ?? const <String, Object?>{};
    return CoachAddress(
      address: readString(m['address']),
      accountName: readString(m['accountName']),
      pendingAddress: readString(p['address']),
      pendingAccountName: readString(p['accountName']),
      pendingEffectiveAt: readTime(p['effectiveAt']),
    );
  }
}

/// One row of the timeline. The server writes `{at, from, to, role, actor,
/// code}`; no name, amount or uid, because both parties read it.
class PaymentEvent {
  const PaymentEvent({
    this.at,
    this.from = '',
    this.to = '',
    this.role = '',
    this.code = '',
  });
  final DateTime? at;
  final String from;
  final String to;
  final String role;
  final String code;

  factory PaymentEvent.fromMap(Object? raw) {
    final m = asMap(raw) ?? const <String, Object?>{};
    return PaymentEvent(
      at: readTime(m['at']),
      from: readString(m['from']),
      to: readString(m['to']),
      role: readString(m['role']),
      code: readString(m['code']),
    );
  }
}

class Payment {
  const Payment({
    required this.id,
    required this.clientUid,
    required this.coachUid,
    required this.status,
    this.subId = '',
    this.packageId = '',
    this.amountPiasters = 0,
    this.reference = '',
    this.address = const CoachAddress(),
    this.createdAt,
    this.expiresAt,
    this.lateUntil,
    this.outcome,
    this.hint = '',
    this.accessUntil,
    this.txnNumber = '',
    this.submittedAt,
    this.disputeKind = '',
    this.notReceivedReason = '',
    this.differentAmountPiasters = 0,
    this.acceptLower = false,
    this.coachReportTxn = '',
    this.coachReportAnswered = false,
    this.feePiasters = 0,
    this.refundRequestedAt,
    this.refundRecordedAt,
    this.confirmedAt,
  });

  final String id;
  final String clientUid;
  final String coachUid;
  final PaymentStatus status;
  final String subId;
  final String packageId;
  final int amountPiasters;
  final String reference;
  final CoachAddress address;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  /// The last moment a proof is still accepted (7 days after the request).
  final DateTime? lateUntil;

  /// `outcome` on the document: what the checks said about her proof.
  final RiskOutcome? outcome;

  /// One neutral next step the server picked for her (`needDetails`, ...).
  final String hint;

  /// `access.until` while bounded access runs (spec 13.1).
  final DateTime? accessUntil;
  final String txnNumber;
  final DateTime? submittedAt;

  /// `dispute.kind`: `proof_red`, `not_received`, `service`, ...
  final String disputeKind;
  final String notReceivedReason;
  final int differentAmountPiasters;
  final bool acceptLower;

  /// The coach said she was paid (spec 4.5); [coachReportAnswered] is set
  /// once the client answered.
  final String coachReportTxn;
  final bool coachReportAnswered;
  final int feePiasters;
  final DateTime? refundRequestedAt;
  final DateTime? refundRecordedAt;
  final DateTime? confirmedAt;

  /// Past "waiting for her payment" and not over: her proof is with the coach
  /// or staff, or the payment stands. She lands on the status, never on PAY1.
  bool get inProgress => !status.unpaid && !status.dead;

  /// The coach reported this payment and is waiting for the client's answer.
  bool get coachAsks =>
      status.unpaid && coachReportTxn.isNotEmpty && !coachReportAnswered;

  /// Time left to pay; zero once past. [now] is the phone clock, a display only.
  Duration timeLeft(DateTime now) {
    final end = expiresAt;
    if (end == null || !end.isAfter(now)) return Duration.zero;
    return end.difference(now);
  }

  /// A late proof is accepted until `lateUntil` (server clock decides).
  bool canSendProof(DateTime now) =>
      status.unpaid && (lateUntil == null || !lateUntil!.isBefore(now));

  static Payment? fromMap(String id, Object? raw) {
    final m = asMap(raw);
    final status = PaymentStatus.fromWire(m?['status']);
    if (m == null || id.isEmpty || status == null) return null;
    final proof = asMap(m['proof']) ?? const <String, Object?>{};
    final dec = asMap(m['coachDecision']) ?? const <String, Object?>{};
    final snap = asMap(m['addressSnapshot']) ?? const <String, Object?>{};
    final refund = asMap(m['refund']) ?? const <String, Object?>{};
    final dispute = asMap(m['dispute']) ?? const <String, Object?>{};
    final access = asMap(m['access']) ?? const <String, Object?>{};
    final report = asMap(m['coachReport']) ?? const <String, Object?>{};
    final outcome = readString(m['outcome']);
    return Payment(
      id: id,
      clientUid: readString(m['clientUid']),
      coachUid: readString(m['coachUid']),
      status: status,
      subId: readString(m['subId']),
      packageId: readString(m['packageId']),
      amountPiasters: readInt(m['amountPiasters']),
      reference: readString(m['reference']),
      address: CoachAddress(
        address: readString(snap['address']),
        accountName: readString(snap['accountName']),
      ),
      createdAt: readTime(m['createdAt']),
      expiresAt: readTime(m['expiresAt']),
      lateUntil: readTime(m['lateUntil']),
      outcome: RiskOutcome.values.where((r) => r.name == outcome).firstOrNull,
      hint: readString(m['hint']),
      accessUntil: readTime(access['until']),
      txnNumber: readString(proof['txnNumber']),
      submittedAt: readTime(proof['submittedAt']),
      disputeKind: readString(dispute['kind']),
      notReceivedReason: readString(dec['reasonCode']),
      differentAmountPiasters: readInt(dec['differentAmountPiasters']),
      acceptLower: readBool(dec['acceptLower']),
      coachReportTxn: readString(report['txnNumber']),
      coachReportAnswered: report['clientAnswer'] != null,
      feePiasters: readInt(m['feePiasters']),
      refundRequestedAt: readTime(refund['requestedAt']),
      refundRecordedAt: readTime(refund['recordedAt']),
      confirmedAt: readTime(dec['confirmedAt']),
    );
  }
}

/// A coach's monthly fee statement (`feeStatements`, id `{coachUid}__{YYYY-MM}`).
class FeeStatement {
  const FeeStatement({
    required this.id,
    this.year = 0,
    this.month = 0,
    this.status = '',
    this.totalDuePiasters = 0,
    this.paymentCount = 0,
    this.dueAt,
  });
  final String id;
  final int year;
  final int month;

  /// `open`, `paid_claimed`, `paid`, `overdue`, ... as the server writes it.
  final String status;
  final int totalDuePiasters;
  final int paymentCount;
  final DateTime? dueAt;

  bool get paid => status == 'paid';

  static FeeStatement? fromMap(String id, Object? raw) {
    final m = asMap(raw);
    if (m == null || id.isEmpty) return null;
    return FeeStatement(
      id: id,
      year: readInt(m['year']),
      month: readInt(m['month']),
      status: readString(m['status']),
      totalDuePiasters: readInt(m['totalDuePiasters']),
      paymentCount: readMaps(m['lines']).length,
      dueAt: readTime(m['dueAt']),
    );
  }
}

/// "500.37" for the bank's amount box. Western digits, no currency.
String egpPlain(int piasters) {
  final rest = piasters % 100;
  return rest == 0
      ? '${piasters ~/ 100}'
      : '${piasters ~/ 100}.${rest.toString().padLeft(2, '0')}';
}
