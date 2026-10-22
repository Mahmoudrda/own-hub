// Bookings belong to the woman who read them. When she deletes everything,
// signs out, or another woman signs in on the same run, her events, her seats
// and the notes worked out from them are gone, and a read still under way
// cannot bring them back.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/events_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/events/domain/event_registration.dart';
import 'package:own_hub/features/events/domain/event_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';
import 'package:own_hub/features/train/domain/training_reminders.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

HubEvent _event(String id, DateTime at) => HubEvent(
  id: id,
  titleEn: 'Class $id',
  titleAr: 'حصة $id',
  startsAt: at.toUtc(),
  endsAt: at.add(const Duration(hours: 1)).toUtc(),
  mode: EventMode.online,
  status: EventStatus.published,
  capacity: 20,
  seatsTaken: 3,
);

class _Registrar implements EventRegistrar {
  _Registrar(this.mine, {this.gate});

  final Set<String> mine;
  final Completer<void>? gate;

  @override
  Future<bool> isRegistered(String eventId) async {
    await gate?.future;
    return mine.contains(eventId);
  }

  @override
  Future<SeatResult> register(String eventId) async =>
      SeatResult(registered: true, seatsTaken: 1);

  @override
  Future<SeatResult> cancel(String eventId) async =>
      SeatResult(registered: false, seatsTaken: 0);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 14, 10);
  final start = DateTime(2026, 10, 20, 19);
  final shipped = AppRouter.featureFlags;
  final state = EventsState.instance;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = FeatureFlags.allOff.with_({Feature.events: true});
    state.reset();
    state.now = () => now;
    ReminderState.instance.reset();
  });
  tearDown(() {
    AppRouter.featureFlags = shipped;
    state.reset();
    ReminderState.instance.reset();
  });

  void bookedForA() {
    state.seed([_event('a', start)]);
    state.seedBooked(['a']);
    ReminderState.instance.eventPlan = [
      PlannedNotification(
        id: 7171,
        kind: PlanKind.eventReminder,
        at: DateTime(2026, 10, 20, 16),
      ),
    ];
  }

  test('delete everything drops her events, seats and saved notes', () async {
    bookedForA();
    expect(state.reminderInput()!.booked, {'a'});

    await const ThisPhoneWipe().clearPersistence();

    expect(state.reminderInput(), isNull);
    expect(state.upcoming, isEmpty);
    expect(ReminderState.instance.eventPlan, isEmpty);
  });

  test('signing out drops her events and her seats', () async {
    bookedForA();
    expect(state.reminderInput()!.booked, {'a'});

    await const ThisPhoneWipe().signOut();

    expect(state.reminderInput(), isNull);
    expect(state.upcoming, isEmpty);
  });

  test('a different woman signing in starts with none of the seats', () async {
    bookedForA();

    await const ThisPhoneWipe(
      keepsOwner: true,
      keepsSignUp: true,
    ).clearPersistence();

    expect(state.reminderInput(), isNull);
    expect(state.upcoming, isEmpty);
  });

  test('a read that began for her cannot put her list back', () async {
    final gate = Completer<void>();
    state.source = () => InMemoryEvents([_event('a', start)]);
    state.registrar = () => _Registrar({'a'}, gate: gate);
    final reading = state.refresh(force: true);
    await pumpEventQueue();

    state.erase();
    gate.complete();
    await reading;

    expect(state.upcoming, isEmpty);
    expect(state.reminderInput(), isNull);
  });

  test('with no one to ask, no seat is known to be held', () async {
    state.seed([_event('a', start)]);
    state.seedBooked(['a']);
    state.registrar = () => null;

    state.setSeats('a', 4);
    await pumpEventQueue();

    expect(state.reminderInput()!.booked, isEmpty);
  });

  test('a refresh for a signed out phone forgets the seats', () async {
    state.seedBooked(['a']);
    state.source = () => InMemoryEvents([_event('a', start)]);
    state.registrar = () => null;

    await state.refresh(force: true);

    expect(state.reminderInput()!.booked, isEmpty);
  });
}
