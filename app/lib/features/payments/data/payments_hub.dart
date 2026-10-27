library;

import '../../../app_state/firebase_boot.dart';
import 'firebase_phone_reauth.dart';
import 'firestore_payments_repository.dart';
import 'payments_repository.dart';

/// Where a screen gets the repository and the phone re-authentication.
/// Tests set [override] and [reauthOverride].
class PaymentsHub {
  static PaymentsRepository? override;
  static PhoneReauth? reauthOverride;
  static PaymentsRepository? _live;
  static PhoneReauth? _liveReauth;

  static PaymentsRepository? get repository =>
      override ??
      (FirebaseBoot.isReady ? (_live ??= FirestorePaymentsRepository()) : null);

  static PhoneReauth get reauth =>
      reauthOverride ?? (_liveReauth ??= FirebasePhoneReauth());
}
