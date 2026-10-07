/// What the admin console talks to: the console callables, the events
/// collection and the content library, each through Firebase when it is up
/// and somebody is signed in, and otherwise through something that says it
/// cannot rather than something that pretends.
///
/// Nothing here grants anything. Every one of these is refused by the server
/// unless the signed-in account holds the `admin` claim.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../features/admin/data/callable_console_source.dart';
import '../features/admin/data/firestore_content_documents.dart';
import '../features/admin/domain/console_source.dart';
import '../features/admin/domain/content_documents.dart';
import '../features/events/data/firestore_events.dart';
import '../features/events/domain/event_repository.dart';
import '../features/events/domain/hub_event.dart';
import 'firebase_boot.dart';

abstract final class AdminBackends {
  static bool get _signedIn {
    try {
      return FirebaseBoot.isReady && FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  static ConsoleSource console() => FirebaseBoot.isReady
      ? CallableConsoleSource(FirebaseBoot.functions)
      : const UnavailableConsoleSource();

  static EventAdminStore events() => _signedIn
      ? FirestoreEventAdminStore(FirebaseFirestore.instance)
      : const UnavailableEventAdminStore();

  static ContentDocuments? contentDocuments() =>
      _signedIn ? FirestoreContentDocuments(FirebaseFirestore.instance) : null;
}

/// No Firebase, or nobody signed in: events cannot be read or written, and
/// Z17 says so instead of keeping a list that would vanish on restart.
class UnavailableEventAdminStore implements EventAdminStore {
  const UnavailableEventAdminStore();

  @override
  Future<List<HubEvent>> all() async =>
      throw const ConsoleException(ConsoleFailure.unavailable);

  @override
  String newId() => '';

  @override
  Future<void> save(HubEvent event) async =>
      throw const ConsoleException(ConsoleFailure.unavailable);
}
