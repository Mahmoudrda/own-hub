/// A payment between a client and her coach, as the server keeps it
/// (`functions/payments`). Read only: every change goes through a callable.
library;

import '../../private_coaching/domain/parse.dart';
import 'payments_rules.dart';

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

/// What `open_service_dispute` opens, chosen by the payment's status
/// (`functions/payments/refund.py`): a problem with a paid package, a refund
/// her coach would not agree to, or a refund recorded that never arrived.
enum DisputeKind {
  service('service'),
  refund('refund'),
  refundNotReceived('refund_not_received');

  const DisputeKind(this.wire);
  final String wire;
}

class CoachAddress {
  const CoachAddress({
    this.address = '',
    this.accountName = '',
    this.pendingAddress = '',
    this.pendingAccountName = '',
    this.pendingEffectiveAt,
    this.autoConfirmGreen = false,
    this.cleanConfirmed = 0,
  });
  final String address;
  final String accountName;

  /// A change waiting out its 24 hours (spec 4.4).
  final String pendingAddress;
  final String pendingAccountName;
  final DateTime? pendingEffectiveAt;

  /// She lets a GREEN proof confirm itself (`autoConfirmGreen`), and how many
  /// payments she has confirmed that were clean (`cleanConfirmed`). Both are
  /// written by the server on `coachPaymentProfiles/{uid}`.
  final bool autoConfirmGreen;
  final int cleanConfirmed;

  bool get isEmpty => address.isEmpty && pendingAddress.isEmpty;

  /// Whether a change is still waiting at [now].
  bool pendingAt(DateTime now) =>
      pendingAddress.isNotEmpty &&
      pendingEffectiveAt != null &&
      pendingEffectiveAt!.isAfter(now);

  /// `coachPaymentProfiles/{uid}`: `address`, `accountName`, `pending`,
  /// `autoConfirmGreen` and `cleanConfirmed`.
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
      autoConfirmGreen: readBool(m['autoConfirmGreen']),
      cleanConfirmed: readInt(m['cleanConfirmed']),
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
    this.screenshotPaths = const <String>[],
    this.imageFlags = const <String>[],
    this.paidAtClaimed,
    this.statementPaths = const <String>[],
    this.receivedPiasters,
    this.autoConfirmed = false,
    this.disputeReasonCode = '',
    this.refundCoachDueAt,
    this.statusAt,
    this.disputeDecidedAt,
    this.disputeKinds = const <String>[],
    this.disputeStaffDecision = '',
    this.refundOwedPiasters = 0,
    this.refundOwedDueAt,
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

  /// `proof.screenshotPaths`: her pictures, read through `get_payment_image`.
  final List<String> screenshotPaths;

  /// `proof.imageFlags`: `sameImage`, `nearImage`, `txnReused`, the repeats
  /// the coach may see (spec 4.2).
  final List<String> imageFlags;

  /// `proof.paidAtClaimed`: when she says she paid. Only a claim; the server
  /// clock decides everything else.
  final DateTime? paidAtClaimed;

  /// `coachDecision.statementPaths`: the coach's own bank list.
  final List<String> statementPaths;

  /// `coachDecision.receivedPiasters`: what the coach says arrived when she
  /// confirmed. Null until she has.
  final int? receivedPiasters;

  /// `coachDecision.autoConfirmed`: the server confirmed it for her because a
  /// GREEN proof came in while automatic confirming was on.
  final bool autoConfirmed;

  /// `dispute.reasonCode`: why the payment is in review, or staff's decision.
  final String disputeReasonCode;

  /// `refund.coachDueAt`: when a refund request goes to staff if the coach
  /// stays silent (3 days after the request).
  final DateTime? refundCoachDueAt;

  /// `statusAt`: when the status last changed (the server's clock).
  final DateTime? statusAt;

  /// `dispute.decidedAt`: when staff decided a review.
  final DateTime? disputeDecidedAt;

  /// `disputeKinds`: the kinds she has already raised on this payment, each
  /// allowed once.
  final List<String> disputeKinds;

  /// `dispute.staffDecision`: what staff decided on a review, for example
  /// `refund_owed`.
  final String disputeStaffDecision;

  /// `dispute.refundOwedPiasters`: the refund staff ordered the coach to send.
  final int refundOwedPiasters;

  /// `dispute.refundDueAt`: when that refund is due (7 days after the decision).
  final DateTime? refundOwedDueAt;

  /// Staff decided this payment's review in the client's favour: the coach
  /// owes the refund and records it (`functions/payments/refund.py`).
  bool get refundOwed =>
      status == PaymentStatus.inReview &&
      disputeStaffDecision == 'refund_owed' &&
      refundOwedPiasters > 0;

  /// Past "waiting for her payment" and not over: her proof is with the coach
  /// or staff, or the payment stands. She lands on the status, never on PAY1.
  bool get inProgress => !status.unpaid && !status.dead;

  /// The coach reported this payment and is waiting for the client's answer.
  bool get coachAsks =>
      status.unpaid && coachReportTxn.isNotEmpty && !coachReportAnswered;

  /// A payment that confirmed itself may still be flagged "not received" by
  /// the coach for [window] after it did (`claims.not_received`, 13.4).
  bool canFlagAutoConfirmed(DateTime now, Duration window) =>
      status == PaymentStatus.confirmed &&
      autoConfirmed &&
      confirmedAt != null &&
      !now.isAfter(confirmedAt!.add(window));

  /// She may withdraw it: nothing is paid yet and her coach has not said she
  /// was (then she answers that instead).
  bool get canCancel => status.unpaid && !coachAsks;

  /// When her access began, as the server reckons it (`started_at` in
  /// `functions/payments/refund.py`): the coach's confirmation, else staff's
  /// decision, else the last status change.
  DateTime? get accessStartedAt => confirmedAt ?? disputeDecidedAt ?? statusAt;

  /// She may still ask for a refund: the payment stands, she has not asked,
  /// and the first [kRefundWindowDays] days have not run out. With no start
  /// time on the document the server decides.
  bool refundWindowOpen(DateTime now) {
    final start = accessStartedAt;
    return status.activatesPackage &&
        refundRequestedAt == null &&
        (start == null ||
            !now.isAfter(start.add(const Duration(days: kRefundWindowDays))));
  }

  /// The one dispute she may open from here, or null. The package-length
  /// window of a service problem is not on this document: the server refuses
  /// a late one with `dispute_window_closed`.
  DisputeKind? disputeToOpen(DateTime now) {
    final kind = switch (status) {
      PaymentStatus.confirmed ||
      PaymentStatus.resolvedPaid => DisputeKind.service,
      PaymentStatus.refundDenied => DisputeKind.refund,
      PaymentStatus.refunded => DisputeKind.refundNotReceived,
      _ => null,
    };
    if (kind == null || disputeKinds.contains(kind.wire)) return null;
    final recorded = refundRecordedAt;
    if (kind == DisputeKind.refundNotReceived &&
        recorded != null &&
        now.isAfter(
          recorded.add(const Duration(days: kServiceDisputeGraceDays)),
        )) {
      return null;
    }
    return kind;
  }

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
      screenshotPaths: readStrings(proof['screenshotPaths']),
      imageFlags: readStrings(proof['imageFlags']),
      paidAtClaimed: readTime(proof['paidAtClaimed']),
      statementPaths: readStrings(dec['statementPaths']),
      receivedPiasters: readIntOrNull(dec['receivedPiasters']),
      autoConfirmed: readBool(dec['autoConfirmed']),
      disputeReasonCode: readString(dispute['reasonCode']),
      refundCoachDueAt: readTime(refund['coachDueAt']),
      statusAt: readTime(m['statusAt']),
      disputeDecidedAt: readTime(dispute['decidedAt']),
      disputeKinds: readStrings(m['disputeKinds']),
      disputeStaffDecision: readString(dispute['staffDecision']),
      refundOwedPiasters: readInt(dispute['refundOwedPiasters']),
      refundOwedDueAt: readTime(dispute['refundDueAt']),
    );
  }
}

/// Where the coach pays Own Hub (`feeStatements.payTo`, copied from
/// `coachingConfig/receivingAccounts.instapay` when the statement is made).
/// Both are empty when the owner had not set them.
class FeePayTo {
  const FeePayTo({this.address = '', this.holderName = ''});
  final String address;
  final String holderName;
}

/// One payment on a statement (`lines[]`). [feeState] is `owed`, `disputed`,
/// `settled` or `waived`.
class FeeLine {
  const FeeLine({
    required this.paymentId,
    this.reference = '',
    this.basePiasters = 0,
    this.feePiasters = 0,
    this.feeState = '',
    this.owedAt,
  });
  final String paymentId;
  final String reference;
  final int basePiasters;
  final int feePiasters;
  final String feeState;
  final DateTime? owedAt;
}

/// A coach's monthly fee statement (`feeStatements`, id `{coachUid}__{YYYY-MM}`).
class FeeStatement {
  const FeeStatement({
    required this.id,
    this.year = 0,
    this.month = 0,
    this.status = '',
    this.totalDuePiasters = 0,
    this.disputedPiasters = 0,
    this.lines = const <FeeLine>[],
    this.payTo = const FeePayTo(),
    this.claimedTxn = '',
    this.dueAt,
    this.holdAt,
    this.onHold = false,
    this.paidAt,
  });
  final String id;
  final int year;
  final int month;

  /// `open`, `paid_claimed` or `paid`. There is no `overdue` status: a
  /// statement is late when it is still `open` past [dueAt].
  final String status;
  final int totalDuePiasters;

  /// Fees on payments still in review: listed, not counted in the total.
  final int disputedPiasters;
  final List<FeeLine> lines;
  final FeePayTo payTo;

  /// The transaction number the coach gave when she marked the fee as paid.
  final String claimedTxn;
  final DateTime? dueAt;

  /// When an unpaid bill puts her account on hold (7 days after it became
  /// owed). Null on a statement made before that rule.
  final DateTime? holdAt;

  /// The server has put her account on hold for this bill.
  final bool onHold;
  final DateTime? paidAt;

  int get paymentCount => lines.length;
  bool get paid => status == 'paid';

  static FeeStatement? fromMap(String id, Object? raw) {
    final m = asMap(raw);
    if (m == null || id.isEmpty) return null;
    final payTo = asMap(m['payTo']) ?? const <String, Object?>{};
    return FeeStatement(
      id: id,
      year: readInt(m['year']),
      month: readInt(m['month']),
      status: readString(m['status']),
      totalDuePiasters: readInt(m['totalDuePiasters']),
      disputedPiasters: readInt(m['disputedPiasters']),
      lines: [
        for (final l in readMaps(m['lines']))
          FeeLine(
            paymentId: readString(l['paymentId']),
            reference: readString(l['reference']),
            basePiasters: readInt(l['basePiasters']),
            feePiasters: readInt(l['feePiasters']),
            feeState: readString(l['feeState']),
            owedAt: readTime(l['owedAt']),
          ),
      ],
      payTo: FeePayTo(
        address: readString(payTo['address']),
        holderName: readString(payTo['holderName']),
      ),
      claimedTxn: readString(m['claimedTxn']),
      dueAt: readTime(m['dueAt']),
      holdAt: readTime(m['holdAt']),
      onHold:
          readBool(m['overdueNotified']) &&
          readString(m['status']) != 'paid' &&
          (m['totalDuePiasters'] == null || readInt(m['totalDuePiasters']) > 0),
      paidAt: readTime(m['paidAt']),
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

/// What the coach space says before a hold: a bill due within 24 hours or
/// already past due but not yet held. Null when nothing needs saying (an
/// account already on hold has its own banner).
({bool late, DateTime holdOn})? feeNoticeFor(
  List<FeeStatement> bills,
  DateTime now,
) {
  final open = [
    for (final b in bills)
      if (b.status == 'open' && b.totalDuePiasters > 0 && b.dueAt != null) b,
  ];
  if (open.any((b) => b.onHold)) return null;
  FeeStatement? pick(bool Function(FeeStatement) test) {
    final hits = open.where(test).toList()
      ..sort((a, b) => (a.holdAt ?? a.dueAt!).compareTo(b.holdAt ?? b.dueAt!));
    return hits.isEmpty ? null : hits.first;
  }

  final late = pick((b) => !b.dueAt!.isAfter(now));
  if (late != null) return (late: true, holdOn: late.holdAt ?? late.dueAt!);
  final soon = pick(
    (b) => !b.dueAt!.subtract(const Duration(hours: 24)).isAfter(now),
  );
  return soon == null
      ? null
      : (late: false, holdOn: soon.holdAt ?? soon.dueAt!);
}
