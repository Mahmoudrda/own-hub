/// What a coach sees of her money. Only she reads these (`coachPrivate/`).
library;

import 'coaching_contract.dart';
import 'parse.dart';

class LedgerEntry {
  const LedgerEntry({
    required this.subId,
    required this.status,
    this.clientLabel = '',
    this.packageTitle = '',
    this.coachAmountEgp = 0,
    this.eligibleAt,
    this.payoutId,
    this.createdAt,
  });

  final String subId;
  final LedgerStatus status;
  final String clientLabel;

  /// The tag that stands for the client on a ledger line, "#A1B2" (the stored
  /// label, with the "#" added if it is missing), or empty. The screen words
  /// it through AppL10n, so it reads right in both languages.
  String get clientTag {
    final label = clientLabel.trim();
    if (label.isEmpty) return '';
    return label.startsWith('#') ? label : '#$label';
  }

  final String packageTitle;
  final int coachAmountEgp;
  final DateTime? eligibleAt;
  final String? payoutId;
  final DateTime? createdAt;

  static LedgerEntry? fromMap(String subId, Object? raw) {
    final map = asMap(raw);
    if (map == null || subId.isEmpty) return null;
    final status = LedgerStatus.fromWire(map['status']);
    if (status == null) return null;
    return LedgerEntry(
      subId: subId,
      status: status,
      clientLabel: readString(map['clientLabel']),
      packageTitle: readString(map['packageTitle']),
      coachAmountEgp: readInt(map['coachAmountEgp']),
      eligibleAt: readTime(map['eligibleAt']),
      payoutId: readStringOrNull(map['payoutId']),
      createdAt: readTime(map['createdAt']),
    );
  }

  /// Pending until 14 days after the start, then eligible, then paid.
  bool isOwed(DateTime now) =>
      status == LedgerStatus.eligible ||
      (status == LedgerStatus.pending &&
          eligibleAt != null &&
          !now.isBefore(eligibleAt!));
}

class Payout {
  const Payout({
    required this.id,
    this.amountEgp = 0,
    this.rail = '',
    this.reference = '',
    this.paidAt,
    this.entryIds = const <String>[],
    this.createdAt,
  });

  final String id;
  final int amountEgp;
  final String rail;
  final String reference;
  final DateTime? paidAt;
  final List<String> entryIds;
  final DateTime? createdAt;

  static Payout? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    return Payout(
      id: id,
      amountEgp: readInt(map['amountEgp']),
      rail: readString(map['rail']),
      reference: readString(map['reference']),
      paidAt: readTime(map['paidAt']),
      entryIds: readStrings(map['entryIds']),
      createdAt: readTime(map['createdAt']),
    );
  }
}

/// `coachPrivate/{uid}`: her payout account and what she is owed.
class CoachPrivateSummary {
  const CoachPrivateSummary({
    this.fullName = '',
    this.payoutRail = '',
    this.payoutAccount = '',
    this.payoutHolderName = '',
    this.payoutState,
    this.pendingPayout,
    this.owedEgp = 0,
    this.paidEgp = 0,
    this.payoutNameMatches,
    this.suspended = false,
    this.suspendReason = '',
    this.suspendedAt,
    this.claimPending = false,
  });

  final String fullName;
  final String payoutRail;
  final String payoutAccount;
  final String payoutHolderName;
  final PayoutAccountState? payoutState;

  /// A change she asked for that finance has not confirmed yet.
  final CoachPayoutChange? pendingPayout;
  final int owedEgp;
  final int paidEgp;

  /// Whether the payout account holder matches her legal name. Null when
  /// finance has not checked yet.
  final bool? payoutNameMatches;
  final bool suspended;
  final String suspendReason;
  final DateTime? suspendedAt;

  /// A change to her coach status is still being applied to her sign-in.
  final bool claimPending;

  bool get hasPendingChange => pendingPayout != null;

  static CoachPrivateSummary? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null || map.isEmpty) return null;
    final payout = asMap(map['payout']) ?? const <String, Object?>{};
    return CoachPrivateSummary(
      fullName: readString(map['fullName']),
      payoutRail: readString(payout['rail']),
      payoutAccount: readString(payout['account']),
      payoutHolderName: readString(payout['holderName']),
      payoutState: PayoutAccountState.fromWire(map['payoutState']),
      pendingPayout: CoachPayoutChange.fromMap(map['pendingPayout']),
      owedEgp: readInt(map['owedEgp']),
      paidEgp: readInt(map['paidEgp']),
      payoutNameMatches: map['payoutNameMatches'] is bool
          ? map['payoutNameMatches'] as bool
          : null,
      suspended: readBool(map['suspended']),
      suspendReason: readString(map['suspendReason']),
      suspendedAt: readTime(map['suspendedAt']),
      claimPending: readBool(map['claimPending']),
    );
  }
}

class CoachPayoutChange {
  const CoachPayoutChange({
    this.rail = '',
    this.account = '',
    this.holderName = '',
  });

  final String rail;
  final String account;
  final String holderName;

  static CoachPayoutChange? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null || map.isEmpty) return null;
    return CoachPayoutChange(
      rail: readString(map['rail']),
      account: readString(map['account']),
      holderName: readString(map['holderName']),
    );
  }
}
