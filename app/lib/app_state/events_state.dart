/// The events a member sees: on Home's Upcoming card and on `T09`.
///
/// Read only while [Feature.events] is on, only for a verified account (the
/// rules refuse anyone else), and at most once an hour: one query of twenty
/// small documents. The time of the last read from the server is kept on the
/// phone, so a launch inside the hour reads the list from Firestore's own
/// copy on the phone and the server is asked only after the hour. Offline or refused, the list is simply empty and both
/// places show their empty state. Reading the list sends nothing about her;
/// her seat is asked for only when she taps Reserve or Cancel.
///
/// The same read feeds her event reminders (`EventReminderPlan`): after each
/// read, and after each seat she takes or gives back, the notes on the phone
/// are worked out again. Which of the next events she holds a seat on is
/// read from her own attendee document, one small read each, and kept for the
/// run; it never leaves the phone.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/flags/feature_flags.dart';
import '../features/events/data/callable_event_registrar.dart';
import '../features/events/data/firestore_events.dart';
import '../features/events/domain/event_registration.dart';
import '../features/events/domain/event_repository.dart';
import '../features/events/domain/hub_event.dart';
import '../features/train/domain/notification_plan.dart' show kEventMaxPlanned;
import '../features/train/domain/training_reminders.dart' show ReminderState;
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';
import 'notification_sync.dart';

/// When the list was last read from the server. Removed by [EventsState.erase],
/// which both the local wipe and a change of account call.
const String kEventsReadAtKey = 'own_hub.events_read_at';

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
    unawaited(_seatChanged(eventId));
  }

  /// A seat was just taken or given back: ask which, then plan the notes.
  Future<void> _seatChanged(String eventId) async {
    await _readBooked([eventId]);
    await _replan();
  }

  static const Duration readEvery = Duration(hours: 1);

  List<HubEvent> _events = const [];
  DateTime? _readAt;
  Future<void>? _inFlight;

  /// Counts the times the list was dropped for another woman, so a read that
  /// started before it cannot put the old list back.
  int _epoch = 0;

  /// The events she holds a seat on, as far as this run has read. Not an
  /// event here means "not known to be booked".
  final Set<String> _booked = <String>{};

  /// A read has succeeded in this run (or the feature is off), so the list is
  /// the truth and not just the empty start.
  bool _listKnown = false;

  /// What the reminders are worked out from, or null before the list is
  /// known: the notes already on the phone then stand.
  ({List<HubEvent> events, Set<String> booked})? reminderInput() => _listKnown
      ? (events: _events, booked: Set<String>.unmodifiable(_booked))
      : null;

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
      final had =
          _events.isNotEmpty || ReminderState.instance.eventPlan.isNotEmpty;
      _events = const [];
      _booked.clear();
      _listKnown = true;
      if (had) {
        AppChanges.bump();
        await _replan();
      }
      return;
    }
    final at = now();
    final epoch = _epoch;
    DateTime? stored;
    if (!force) {
      final last = _readAt;
      if (last != null) {
        if (at.difference(last) < readEvery) return;
      } else {
        final saved = await _storedReadAt();
        if (epoch != _epoch) return;
        final age = saved == null ? null : at.difference(saved);
        if (age != null && !age.isNegative && age < readEvery) stored = saved;
      }
    }
    final reader = source();
    if (reader == null) return;
    try {
      final read = await reader.upcoming(
        at.toUtc(),
        cacheFirst: stored != null,
      );
      if (epoch != _epoch) return;
      _events = read;
      _readAt = stored ?? at;
      if (stored == null) unawaited(_storeReadAt(at));
      _listKnown = true;
      AppChanges.bump();
    } catch (_) {
      // The last list stands.
      return;
    }
    await _readBooked([
      for (final e in upcomingOf(_events, at).take(kEventMaxPlanned)) e.id,
    ]);
    if (epoch != _epoch) return;
    await _replan();
  }

  static Future<DateTime?> _storedReadAt() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        kEventsReadAtKey,
      );
      return raw == null ? null : DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _storeReadAt(DateTime at) async {
    try {
      await (await SharedPreferences.getInstance()).setString(
        kEventsReadAtKey,
        at.toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  static Future<void> _forgetReadAt() async {
    try {
      await (await SharedPreferences.getInstance()).remove(kEventsReadAtKey);
    } catch (_) {}
  }

  /// Which of [ids] she holds a seat on. A read that fails leaves what was
  /// known. With no one to ask there is no account to hold a seat, so nothing
  /// is known to be booked.
  Future<void> _readBooked(List<String> ids) async {
    final asker = registrar();
    if (asker == null) {
      _booked.clear();
      return;
    }
    final epoch = _epoch;
    await Future.wait([
      for (final id in ids)
        () async {
          try {
            final held = await asker.isRegistered(id);
            if (epoch != _epoch) return;
            if (held) {
              _booked.add(id);
            } else {
              _booked.remove(id);
            }
          } catch (_) {}
        }(),
    ]);
  }

  /// Works the event notes out again. Never throws.
  Future<void> _replan() async {
    try {
      await NotificationSync.reapplyLast(
        AppRouter.reminderScheduler,
        now: now(),
      );
    } catch (_) {}
  }

  /// Drops the list and her seats: the account that read them is gone, on
  /// delete, sign out or a different woman signing in. The notes on the phone
  /// are cancelled by the caller.
  void erase() {
    _epoch++;
    _events = const [];
    _booked.clear();
    _listKnown = false;
    _readAt = null;
    _inFlight = null;
    unawaited(_forgetReadAt());
  }

  /// Puts a list in place. Tests only.
  @visibleForTesting
  void seed(List<HubEvent> events) {
    _events = List.unmodifiable(events);
    _readAt = now();
    _listKnown = true;
  }

  /// Marks the events she holds a seat on. Tests only.
  @visibleForTesting
  void seedBooked(Iterable<String> ids) {
    _booked
      ..clear()
      ..addAll(ids);
  }

  @visibleForTesting
  void reset() {
    _events = const [];
    _booked.clear();
    _listKnown = false;
    _readAt = null;
    _inFlight = null;
    unawaited(_forgetReadAt());
    source = _liveSource;
    registrar = _liveRegistrar;
    now = DateTime.now;
  }
}
