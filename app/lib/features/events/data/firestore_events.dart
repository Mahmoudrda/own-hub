/// [EventReader] and [EventAdminStore] over Firestore `events/{id}`.
///
/// The member's read is one query, `status == 'published'` and not over yet,
/// soonest end first, twenty at most: the only shape the rules accept from
/// her, and one small read a launch. Both directions convert between the
/// document's timestamps and the domain's UTC [DateTime]s here and nowhere
/// else.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/event_repository.dart';
import '../domain/hub_event.dart';

const String kEventsCollection = 'events';

Map<String, Object?> _plain(Map<String, Object?> data) => data.map(
  (key, value) =>
      MapEntry(key, value is Timestamp ? value.toDate().toUtc() : value),
);

HubEvent? eventFromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
  final data = doc.data();
  if (data == null) return null;
  return HubEvent.fromDocument(doc.id, _plain(data));
}

class FirestoreEventReader implements EventReader {
  FirestoreEventReader(this._db);

  final FirebaseFirestore _db;

  @override
  Future<List<HubEvent>> upcoming(DateTime now, {int limit = 20}) async {
    final snapshot = await _db
        .collection(kEventsCollection)
        .where('status', isEqualTo: EventStatus.published.name)
        .where('endsAt', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('endsAt')
        .limit(limit)
        .get()
        .timeout(const Duration(seconds: 10));
    return upcomingOf([
      for (final doc in snapshot.docs) ?eventFromSnapshot(doc),
    ], now);
  }
}

class FirestoreEventAdminStore implements EventAdminStore {
  FirestoreEventAdminStore(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _events =>
      _db.collection(kEventsCollection);

  @override
  Future<List<HubEvent>> all() async {
    final snapshot = await _events
        .orderBy('startsAt', descending: true)
        .limit(200)
        .get()
        .timeout(const Duration(seconds: 15));
    return [for (final doc in snapshot.docs) ?eventFromSnapshot(doc)];
  }

  @override
  String newId() => _events.doc().id;

  @override
  Future<void> save(HubEvent event) async {
    final body = event.toDocument().map(
      (key, value) =>
          MapEntry(key, value is DateTime ? Timestamp.fromDate(value) : value),
    );
    body['updatedAt'] = FieldValue.serverTimestamp();
    await _events
        .doc(event.id)
        .set(body, SetOptions(merge: true))
        .timeout(const Duration(seconds: 15));
  }
}
