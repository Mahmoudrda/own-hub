/// The only file that talks to Firestore.
///
/// `cloud_documents.dart` decides WHAT a document may contain, against the
/// deployed rules. `cloud_store.dart` decides WHEN one is written. This decides
/// how it gets there, and it is kept apart from both so that the two files with
/// the product decisions in them can be exercised by a test with no Firebase,
/// no platform channel and no network.
///
/// ## Offline persistence is on, and nothing here turns it on
///
/// The Flutter SDK enables it by default on Android and iOS. That is not a read
/// cache — it is a durable mutation queue on disk: a `set()` made with no signal
/// is applied locally at once and sent when the network returns, surviving the
/// app being killed. Every retry this app needs already exists there, which is
/// why there is no queue, no backoff and no retry timer anywhere in this
/// feature. `Settings(persistenceEnabled:)` is deliberately never called —
/// leaving the default alone IS the decision, and writing it down here is what
/// stops somebody later "fixing" it to false and silently deleting the only
/// offline write path the app has.
///
/// ## A write's future is an acknowledgement, not a completion
///
/// Because of that queue, the future returned by `set()` completes when the
/// **server** accepted the write. With no signal it never completes, and that
/// is correct rather than a hang: the write is already on disk and already
/// applied locally. Callers must never await one in order to carry on. They
/// await it to learn that the server REFUSED it, which is the one fact the
/// rules can tell us that the phone cannot.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'cloud_documents.dart';

/// Why a Firestore call did not happen.
///
/// Kept as a value rather than an exception code so that the one case which has
/// to change behaviour — a denial — is matched on once, here, instead of by a
/// string comparison at every call site.
enum CloudRefusal {
  /// `PERMISSION_DENIED`. Under `firebase/firestore.rules` that means one thing
  /// in practice: `isSelfVerified(uid)` was false, because the `verified`
  /// custom claim is server-minted and nothing mints it yet.
  notVerified,

  /// No route to Firestore. Not a fault and not a state to act on — a write is
  /// already on the queue and will leave with the network.
  unreachable,
}

class CloudRefused implements Exception {
  const CloudRefused(this.refusal, [this.cause]);

  final CloudRefusal refusal;
  final Object? cause;

  @override
  String toString() =>
      'CloudRefused(${refusal.name}${cause == null ? '' : ': $cause'})';
}

/// Where the documents go. One implementation ships; the interface exists so a
/// test can watch what was written, and refuse it, without a platform channel.
abstract class CloudTransport {
  /// Everything stored under `users/{uid}` that this build can read.
  ///
  /// Throws [CloudRefused] rather than letting a `FirebaseException` out.
  Future<List<CloudDoc>> pull(String uid);

  /// Queues [doc] under `users/{uid}`.
  ///
  /// The returned future completes when the server accepted it. See the note at
  /// the top of this file.
  Future<void> push(String uid, CloudDoc doc);
}

/// The real one.
class FirestoreCloudTransport implements CloudTransport {
  FirestoreCloudTransport({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// The three collections that hold exactly one document.
  ///
  /// Fetched by id rather than by listing, and for `cycle` that is not a choice:
  /// the rule is `allow get` with `allow list: if false`, because there is no
  /// cycle query for anyone, ever. A `collection('cycle').get()` is a list, and
  /// it would be denied even for a verified woman reading her own document —
  /// which would look exactly like the verification gate and be debugged as it.
  static const Map<String, String> _singletons = <String, String>{
    'cycle': 'current',
    'eatPrefs': 'current',
    'firstWeek': 'arc',
  };

  DocumentReference<Map<String, dynamic>> _root(String uid) =>
      _firestore.collection('users').doc(uid);

  @override
  Future<List<CloudDoc>> pull(String uid) async {
    final out = <CloudDoc>[];
    try {
      // The gated collections first. If the `verified` claim is missing, the
      // first of them denies and the rest are never asked for — thirteen round
      // trips to be told the same thing is thirteen chances to look like a
      // network fault.
      for (final collection in CloudDocuments.readableCollections) {
        final single = _singletons[collection];
        if (single != null) {
          final snapshot = await _root(uid)
              .collection(collection)
              .doc(single)
              .get();
          final data = snapshot.data();
          if (data == null) continue;
          out.add(
            CloudDoc(
              collection: collection,
              id: single,
              data: _fromFirestore(data),
            ),
          );
          continue;
        }
        final snapshot = await _root(uid).collection(collection).get();
        for (final document in snapshot.docs) {
          out.add(
            CloudDoc(
              collection: collection,
              id: document.id,
              data: _fromFirestore(document.data()),
            ),
          );
        }
      }

      // `users/{uid}` last, and it is deliberately outside the gate: the rule
      // is `allow read: if isSelf(uid)`, because the verification flow itself
      // has to read it before she can possibly be verified.
      final root = await _root(uid).get();
      final rootData = root.data();
      if (rootData != null) {
        out.add(
          CloudDoc(collection: '', id: '', data: _fromFirestore(rootData)),
        );
      }
    } on FirebaseException catch (error) {
      throw CloudRefused(_refusalFor(error), error);
    }
    return out;
  }

  @override
  Future<void> push(String uid, CloudDoc doc) {
    final ref = doc.isRoot
        ? _root(uid)
        : _root(uid).collection(doc.collection).doc(doc.id);

    final options = doc.mergeFields == null
        ? null
        : SetOptions(mergeFields: doc.mergeFields);

    Future<void> write(Map<String, Object?> data) {
      final wired = _toFirestore(data);
      // `set(data)` and `set(data, options)` rather than one call with a
      // possibly-empty `SetOptions`: an options object with neither `merge` nor
      // `mergeFields` set is not documented to mean "replace the document", and
      // the difference between replacing and merging is whether sign-up's
      // fields on `users/{uid}` survive.
      final sent = options == null ? ref.set(wired) : ref.set(wired, options);
      return sent.catchError((Object error) {
        if (error is FirebaseException) {
          throw CloudRefused(_refusalFor(error), error);
        }
        throw error;
      });
    }

    final birth = doc.bornAs;
    if (birth == null) return write(doc.data);

    // Both issued now, in order, and neither awaited before the other is
    // queued. Firestore sends local mutations in the order they were made, so
    // awaiting the first would mean the second never being written at all on a
    // phone with no signal — see `CloudDoc.bornAs` for why there are two.
    final born = write(birth);
    final filled = write(doc.data);
    return Future.wait<void>(<Future<void>>[born, filled]);
  }

  static CloudRefusal _refusalFor(FirebaseException error) =>
      error.code == 'permission-denied'
      ? CloudRefusal.notVerified
      : CloudRefusal.unreachable;

  /// Firestore values to the plain ones `cloud_documents.dart` reads.
  ///
  /// Only `Timestamp` needs converting, and it needs it everywhere: a time
  /// nested three maps deep in a logged set comes back as one too, and the
  /// readers there answer null for anything that is not a `DateTime` or an ISO
  /// string — so a missed conversion would not throw, it would quietly drop
  /// the moment she logged something.
  static Map<String, Object?> _fromFirestore(Map<String, Object?> data) =>
      _plain(data) as Map<String, Object?>;

  static Object? _plain(Object? value) => switch (value) {
    final Timestamp stamp => stamp.toDate(),
    final Map<String, Object?> map => <String, Object?>{
      for (final entry in map.entries) entry.key: _plain(entry.value),
    },
    final List<Object?> list => <Object?>[
      for (final item in list) _plain(item),
    ],
    _ => value,
  };

  /// The reverse, for the one value that has no plain form: the server clock.
  static Map<String, Object?> _toFirestore(Map<String, Object?> data) =>
      _wire(data) as Map<String, Object?>;

  static Object? _wire(Object? value) {
    if (identical(value, kServerTime)) return FieldValue.serverTimestamp();
    return switch (value) {
      final Map<String, Object?> map => <String, Object?>{
        for (final entry in map.entries) entry.key: _wire(entry.value),
      },
      final List<Object?> list => <Object?>[
        for (final item in list) _wire(item),
      ],
      _ => value,
    };
  }
}
