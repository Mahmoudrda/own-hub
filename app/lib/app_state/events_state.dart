/// The events a member sees: on Home's Upcoming card and on `T09`.
///
/// Read only while [Feature.events] is on, only for a verified account (the
/// rules refuse anyone else), and at most once an hour: one query of twenty
/// small documents. Offline or refused, the list is simply empty and both
/// places show their empty state. Reading the list sends nothing about her;
/// her seat is asked for only when she taps Reserve or Cancel.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';

import '../domain/flags/feature_flags.dart';
import '../features/events/data/callable_event_registrar.dart';
import '../features/events/data/firestore_events.dart';
import '../features/events/domain/event_registration.dart';
import '../features/events/domain/event_repository.dart';
import '../features/events/domain/hub_event.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';

class EventsState {
  EventsState._();

  static final EventsState instance = EventsState._();

  /// Where events are read from. Null when no read could succeed.
  EventReader? Function() source = _liveSource;

  DateTime Function() now = DateTime.now;

  /// Where seats are reserved and given back. Null when no call could
  /// succeed: no Firebase, nobody signed in, or not verified.
  EventRegistrar? Function() registrar = _liveRegistrar;

  static EventRegistrar? _liveRegistrar() {
    try {
      if (!FirebaseBoot.isReady) return null;
      if (FirebaseAuth.instance.currentUser == null) return null;
      if (!AppRouter.isVerified) return null;
      return CallableEventRegistrar();
    } catch (_) {
      return null;
    }
  }

  /// Keeps the list in step with a count the server just answered, so a card
  /// opened again within the hour does not show the old number.
  void setSeats(String eventId, int seatsTaken) {
    _events = [
      for (final e in _events)
        e.id == eventId ? e.copyWith(seatsTaken: seatsTaken) : e,
    ];
  }

  static const Duration readEvery = Duration(hours: 1);

  List<HubEvent> _events = const [];
  DateTime? _readAt;
  Future<void>? _inFlight;

  /// Published events not over yet, soonest first.
  List<HubEvent> get upcoming => upcomingOf(_events, now());

  static EventReader? _liveSource() {
    try {
      if (!FirebaseBoot.isReady) return null;
      if (FirebaseAuth.instance.currentUser == null) return null;
      if (!AppRouter.isVerified) return null;
      return FirestoreEventReader(FirebaseFirestore.instance);
    } catch (_) {
      return null;
    }
  }

  /// Reads again if an hour has passed, or [force]. Never throws.
  Future<void> refresh({bool force = false}) =>
      _inFlight ??= _refresh(force).whenComplete(() => _inFlight = null);

  Future<void> _refresh(bool force) async {
    if (!AppRouter.featureFlags.isOn(Feature.events)) {
      if (_events.isNotEmpty) {
        _events = const [];
        AppChanges.bump();
      }
      return;
    }
    final at = now();
    final last = _readAt;
    if (!force && last != null && at.difference(last) < readEvery) return;
    final reader = source();
    if (reader == null) return;
    try {
      _events = await reader.upcoming(at.toUtc());
      _readAt = at;
      AppChanges.bump();
    } catch (_) {
      // The last list stands.
    }
  }

  /// Puts a list in place. Tests only.
  @visibleForTesting
  void seed(List<HubEvent> events) {
    _events = List.unmodifiable(events);
    _readAt = now();
  }

  @visibleForTesting
  void reset() {
    _events = const [];
    _readAt = null;
    _inFlight = null;
    source = _liveSource;
    registrar = _liveRegistrar;
    now = DateTime.now;
  }
}
