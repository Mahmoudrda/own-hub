/// The one callable behind sharing a dish: `submit_community_food`.
///
/// It takes `{nameEn?, nameAr?, items: [{name, grams}], kcal, proteinG,
/// carbsG, fatG}` and writes a server-only candidate that the owner reviews.
/// Nothing here carries a photo, a uid or a name of hers. A refusal is
/// swallowed by the caller: sharing never blocks or fails a log.
library;

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';

const String kSubmitCommunityFoodCallable = 'submit_community_food';

const Duration kCommunityFoodTimeout = Duration(seconds: 20);

abstract class CommunityFoodClient {
  /// Offers [dish] to the shared list. Throws on any refusal.
  Future<void> submit(Map<String, Object?> dish);
}

class CallableCommunityFoodClient implements CommunityFoodClient {
  CallableCommunityFoodClient({this.functions});

  final FirebaseFunctions? functions;

  @override
  Future<void> submit(Map<String, Object?> dish) async {
    if (functions == null && !FirebaseBoot.isReady) {
      throw StateError('no backend');
    }
    final callable = (functions ?? FirebaseBoot.functions).httpsCallable(
      kSubmitCommunityFoodCallable,
      options: HttpsCallableOptions(timeout: kCommunityFoodTimeout),
    );
    await callable.call<Object?>(dish);
  }
}
