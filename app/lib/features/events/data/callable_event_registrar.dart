/// `register_for_event` and `cancel_event_registration` over the wire, and her
/// own attendee document for reading her place.
///
/// The body is `{eventId}` and nothing else. The attendee document is
/// readable by her and by the owner only (`firestore.rules`).
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/event_registration.dart';

class CallableEventRegistrar implements EventRegistrar {
  CallableEventRegistrar({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _functions = functions ?? FirebaseBoot.functions,
       _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  static Map<String, Object?> payloadFor(String eventId) => <String, Object?>{
    'eventId': eventId,
  };

  @override
  Future<bool> isRegistered(String eventId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const EventRegistrationException(SeatFailure.offline);
    }
    try {
      final doc = await _db
          .collection('events')
          .doc(eventId)
          .collection('attendees')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      return doc.exists;
    } catch (_) {
      // A failed read is not "not booked": the caller keeps her last known
      // state and offers a retry, so she can still reach Cancel.
      throw const EventRegistrationException(SeatFailure.offline);
    }
  }

  @override
  Future<SeatResult> register(String eventId) =>
      _call(kRegisterForEventCallable, eventId);

  @override
  Future<SeatResult> cancel(String eventId) =>
      _call(kCancelEventRegistrationCallable, eventId);

  Future<SeatResult> _call(String name, String eventId) async {
    final callable = _functions.httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
    );
    final HttpsCallableResult<Object?> response;
    try {
      response = await callable.call<Object?>(payloadFor(eventId));
    } on FirebaseFunctionsException catch (error) {
      throw EventRegistrationException(
        seatFailureOf(error.code, error.message),
      );
    } catch (_) {
      throw const EventRegistrationException(SeatFailure.offline);
    }
    final data = response.data;
    if (data is Map) {
      final registered = data['registered'];
      final taken = data['seatsTaken'];
      final capacity = data['capacity'];
      if (registered is bool && taken is int) {
        return SeatResult(
          registered: registered,
          seatsTaken: taken < 0 ? 0 : taken,
          capacity: capacity is int ? capacity : null,
        );
      }
    }
    throw const EventRegistrationException(SeatFailure.offline);
  }
}
