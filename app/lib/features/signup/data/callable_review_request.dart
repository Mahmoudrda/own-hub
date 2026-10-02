/// `request_review` over the wire. See `domain/review_request.dart`.
///
/// The body is `{path}` and nothing else: no images, no frames, no phone
/// number. A woman reviewer looks her phone number up from Firebase Auth at
/// the moment she calls, through a reviewer-only callable that logs the
/// lookup. Nothing here could carry it anyway.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/review_request.dart';

class CallableReviewRequester implements ReviewRequester {
  CallableReviewRequester({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseBoot.functions;

  final FirebaseFunctions _functions;

  /// The request body. Pinned to the contract by
  /// test/contracts/identity_contract_test.dart.
  static Map<String, Object?> payloadFor(ReviewPath path) => <String, Object?>{
    'path': path.name,
  };

  @override
  Future<ReviewRequestState> request(ReviewPath path) async {
    final callable = _functions.httpsCallable(
      kRequestReviewCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final HttpsCallableResult<Object?> response;
    try {
      response = await callable.call<Object?>(payloadFor(path));
    } on FirebaseFunctionsException catch (error) {
      throw VerificationCallFailure(error.code, error.message);
    }
    final data = response.data;
    final state = data is Map ? reviewRequestStateFrom(data['state']) : null;
    if (state == null) {
      // An answer we cannot read is not a place in the queue.
      throw const VerificationCallFailure('internal');
    }
    return state;
  }
}
