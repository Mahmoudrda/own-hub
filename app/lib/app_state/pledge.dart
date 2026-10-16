/// Her agreement to the community's three rules (`C16`, "How we treat each
/// other").
///
/// Kept twice, for two different readers. On the phone, in the snapshot, so
/// the community opens on her next visit without asking again. And on the
/// server, at `users/{uid}/consents/pledge-v{N}` through `record_pledge`, so
/// there is a record of which rules she agreed to and when, written with the
/// server's clock. The rules forbid the client writing a consent record
/// itself, which is why it is a callable.
///
/// The community is off in the first release, so nothing asks for this yet.
/// When it is on, `M01` shows the rules before the first feed and records the
/// agreement here.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../features/signup/data/callable_failure.dart';
import '../features/signup/domain/legal_acceptance.dart' show kAppVersion;
import 'firebase_boot.dart';

/// The version of the rules on `C16`. Moves with the server's
/// `config.PLEDGE_VERSION`; `contracts/identity_contract.json` pins both. Bump
/// it when the rules change in either language, and every woman is shown them
/// again before the community opens.
const int kPledgeVersion = 2;

/// Callable name, identical on both sides of the contract.
const String kRecordPledgeCallable = 'record_pledge';

/// The body `record_pledge` takes.
Map<String, Object> pledgePayload({
  required String locale,
  String appVersion = kAppVersion,
}) => <String, Object>{
  'version': kPledgeVersion,
  'locale': locale == 'en' ? 'en' : 'ar',
  'appVersion': appVersion,
};

/// What this phone knows of her agreement.
class PledgeState {
  PledgeState._();

  static final PledgeState instance = PledgeState._();

  /// The version she agreed to, or null.
  int? agreedVersion;

  /// When she agreed, on this phone's clock.
  DateTime? agreedAt;

  /// Whether she has agreed to the rules as they stand now.
  bool get agreed => agreedVersion == kPledgeVersion;

  void agree({DateTime? at}) {
    agreedVersion = kPledgeVersion;
    agreedAt = at ?? DateTime.now();
  }

  /// Account deletion and sign-out: a fresh start includes the rules.
  void reset() {
    agreedVersion = null;
    agreedAt = null;
  }
}

/// Sends `record_pledge`.
abstract class PledgeStore {
  Future<void> record({required String locale});
}

class CallablePledgeStore implements PledgeStore {
  CallablePledgeStore({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  @override
  Future<void> record({required String locale}) async {
    final callable = _functions.httpsCallable(
      kRecordPledgeCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    try {
      await callable.call<Object?>(pledgePayload(locale: locale));
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error);
    }
  }
}

/// A build with no back end: the agreement stays on this phone only.
class LocalOnlyPledgeStore implements PledgeStore {
  const LocalOnlyPledgeStore();

  @override
  Future<void> record({required String locale}) async {}
}
