/// The coach marking that she has read a client's health answers. Same shape
/// as `check_in.dart`: an interface, a callable one, an in-memory one.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';

const String kReviewClientHealthCallable = 'review_client_health';

abstract class HealthReviewStore {
  /// True when the server recorded it.
  Future<bool> markRead(String subId);
}

class HealthReviews {
  HealthReviews._();

  static HealthReviewStore? override;
  static HealthReviewStore get store =>
      override ??
      (FirebaseBoot.isReady
          ? CallableHealthReviewStore()
          : InMemoryHealthReviewStore());
}

class CallableHealthReviewStore implements HealthReviewStore {
  CallableHealthReviewStore({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  @override
  Future<bool> markRead(String subId) async {
    try {
      await _functions
          .httpsCallable(
            kReviewClientHealthCallable,
            options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
          )
          .call<Object?>(<String, Object>{'subId': subId});
      return true;
    } catch (_) {
      return false;
    }
  }
}

class InMemoryHealthReviewStore implements HealthReviewStore {
  final List<String> read = <String>[];
  bool works = true;

  @override
  Future<bool> markRead(String subId) async {
    if (works) read.add(subId);
    return works;
  }
}
