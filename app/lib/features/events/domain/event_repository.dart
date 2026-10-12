/// Where events are read from and written to.
///
/// Two sides with two different rights, so two interfaces:
///
///   * [EventReader] is the member's: published events that are not over yet.
///     The Firestore implementation asks for `status == 'published'`, which is
///     the only query the rules let a member run.
///   * [EventAdminStore] is the console's: every event, drafts and cancelled
///     ones included, and the one write. The rules accept it from an account
///     holding the `admin` claim and nobody else.
///
/// [InMemoryEvents] serves both, for tests and for a build with no Firebase.
library;

import 'dart:async';

import 'hub_event.dart';

abstract class EventReader {
  /// Published, not over at [now], soonest first. At most [limit].
  Future<List<HubEvent>> upcoming(DateTime now, {int limit = 20});
}

abstract class EventAdminStore {
  /// Every event, newest start first.
  Future<List<HubEvent>> all();

  /// A fresh document id. Events are not CSV rows: nobody types an id for
  /// one, so the store mints it.
  String newId();

  /// Create or replace one event.
  Future<void> save(HubEvent event);
}

class InMemoryEvents implements EventReader, EventAdminStore {
  InMemoryEvents([Iterable<HubEvent> seed = const []]) {
    for (final e in seed) {
      events[e.id] = e;
    }
  }

  final Map<String, HubEvent> events = <String, HubEvent>{};

  /// Every id saved, in order. Tests assert against this rather than a
  /// callback, for the reason `ContentStore.writes` records.
  final List<String> writes = <String>[];

  int _next = 0;

  @override
  Future<List<HubEvent>> upcoming(DateTime now, {int limit = 20}) async =>
      upcomingOf(events.values, now).take(limit).toList();

  @override
  Future<List<HubEvent>> all() async =>
      events.values.toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));

  @override
  String newId() {
    String id;
    do {
      id = 'event-${++_next}';
    } while (events.containsKey(id));
    return id;
  }

  @override
  Future<void> save(HubEvent event) async {
    events[event.id] = event;
    writes.add(event.id);
  }
}
