/// Coach Agreement v2 as the coach sees it: accepted in the app, signed on
/// paper, uploaded, then verified by Own Hub (`coachPrivate/{uid}.agreement`).
/// The server decides; this only reads what it wrote.
library;

import '../../payments/domain/payments_rules.dart';
import 'coach_application.dart';
import 'parse.dart';

/// The numbers the agreement's summary lines state, with the server's values
/// (`functions/payments/model.py`, `coaching/agreement.py`).
abstract final class CoachAgreementFacts {
  static const String marketplacePercent = '15%';
  static const String invitePercent = '7.5%';
  static const int payWithinDays = 3;
  static const int holdAfterDays = kFeeHoldDays;
  static const int videosPerMonth = 2;
  static const int keepClientsMonths = 12;
}

enum AgreementStatus {
  accepted('accepted'),
  uploaded('uploaded'),
  verified('verified'),
  rejected('rejected');

  const AgreementStatus(this.wire);
  final String wire;

  static AgreementStatus? fromWire(Object? raw) {
    for (final value in values) {
      if (value.wire == raw) return value;
    }
    return null;
  }
}

/// What she has to do next.
enum AgreementStep {
  /// Version 2 is not accepted yet.
  accept,

  /// Accepted; the signed copy is still to come.
  upload,

  /// Uploaded; Own Hub has not decided.
  waiting,

  /// Own Hub asked for a new copy.
  uploadAgain,

  /// Done: she may accept new clients.
  verified,
}

class CoachAgreement {
  const CoachAgreement({
    required this.version,
    required this.status,
    this.reason = '',
    this.path = '',
  });

  final int version;
  final AgreementStatus status;

  /// Why Own Hub asked for a new copy.
  final String reason;
  final String path;

  static CoachAgreement? fromMap(Object? raw) {
    final map = asMap(raw);
    final status = AgreementStatus.fromWire(map?['status']);
    if (map == null || status == null) return null;
    return CoachAgreement(
      version: readInt(map['version']),
      status: status,
      reason: readString(map['reason']),
      path: readString(map['path']),
    );
  }
}

/// Where [agreement] leaves her; a missing record or an older version means
/// she still has to accept.
AgreementStep agreementStep(CoachAgreement? agreement) {
  if (agreement == null || agreement.version != kCoachTermsVersion) {
    return AgreementStep.accept;
  }
  return switch (agreement.status) {
    AgreementStatus.accepted => AgreementStep.upload,
    AgreementStatus.uploaded => AgreementStep.waiting,
    AgreementStatus.rejected => AgreementStep.uploadAgain,
    AgreementStatus.verified => AgreementStep.verified,
  };
}
