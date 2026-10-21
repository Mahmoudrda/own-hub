/// Her seat on an event, as the app asks for it.
///
/// Only the server moves a seat: it checks that she is verified, that the
/// event is published and not over, and that a seat is left, and it changes
/// the count and her place together. The app asks, and shows the answer. A
/// repeated ask changes nothing, so a double tap or a retry after a dropped
/// connection cannot book her twice or cancel someone else's seat.
library;

import 'package:meta/meta.dart';

const String kRegisterForEventCallable = 'register_for_event';
const String kCancelEventRegistrationCallable = 'cancel_event_registration';

/// What the server answers to a reserve or a cancel.
@immutable
class SeatResult {
  const SeatResult({
    required this.registered,
    required this.seatsTaken,
    this.capacity,
  });

  final bool registered;
  final int seatsTaken;
  final int? capacity;
}

enum SeatFailure {
  /// `event_full`.
  full,

  /// `event_closed`: cancelled, over, or no seats set.
  closed,

  /// `permission-denied` `not_verified`.
  notVerified,

  /// `event_not_found`.
  notFound,

  /// `app_check_missing`: this copy of the app cannot reach Own Hub.
  updateApp,

  /// Anything else, most often no connection.
  offline,
}

class EventRegistrationException implements Exception {
  const EventRegistrationException(this.failure);

  final SeatFailure failure;

  @override
  String toString() => 'EventRegistrationException(${failure.name})';
}

/// The server's refusal in the domain's words.
SeatFailure seatFailureOf(String code, String? message) {
  switch (code) {
    case 'not-found':
      return SeatFailure.notFound;
    case 'permission-denied':
      return SeatFailure.notVerified;
    case 'failed-precondition':
      return switch (message) {
        'event_full' => SeatFailure.full,
        'event_closed' => SeatFailure.closed,
        'app_check_missing' => SeatFailure.updateApp,
        _ => SeatFailure.offline,
      };
    default:
      return SeatFailure.offline;
  }
}

abstract class EventRegistrar {
  /// Whether her attendee document exists. Throws [EventRegistrationException]
  /// (offline) when it cannot be read, so a failed read is never taken for
  /// "not booked".
  Future<bool> isRegistered(String eventId);

  /// Throws [EventRegistrationException].
  Future<SeatResult> register(String eventId);

  /// Throws [EventRegistrationException].
  Future<SeatResult> cancel(String eventId);
}
