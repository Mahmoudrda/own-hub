/// The notes before an Own Hub event, worked out in one place.
///
/// Pure, like `NotificationPlan`: it takes the moment, the events the phone
/// knows and which of them she has a seat on, and returns what to schedule.
///
/// - An event she has not booked, still published, not started and with a
///   seat left: three days before at 10:00, the day before at 18:00 and three
///   hours before the start.
/// - An event she has booked: three hours before and the morning of at 09:00.
///   The morning note is left out when it would sit within two hours of the
///   three hour one, so a seat never gets two notes in a row.
/// - Quiet hours (22:00 to 08:00) move a time to 08:00. A time that has gone
///   by, or that quiet hours would push to the start or later, is dropped.
/// - An event with no seat limit has no seat to take, so it earns no note
///   until she has one. A full event earns none either, unless she holds a
///   seat on it.
/// - The soonest [kEventMaxPlanned] events, and at most [kEventNotesPerDay]
///   notes on any calendar day. When a day is over, a seat she holds wins,
///   then the nearest note to the start.
///
/// These do not count in the casual nudge budget (see the library comment of
/// `notification_plan.dart`). Nothing here reads anything about her beyond
/// which events she booked, and no text names the event.
library;

import '../../train/domain/notification_plan.dart';
import 'hub_event.dart';

abstract final class EventReminderPlan {
  /// The hour of the three day note, and of the day before note.
  static const int threeDaysHour = 10;
  static const int oneDayHour = 18;

  /// The hour of the note on the morning of a booked event.
  static const int morningHour = 9;

  /// Notes of one event closer than this are reduced to the later one.
  static const Duration minGap = Duration(hours: 2);

  /// The notes to have scheduled at [now] (local), soonest first.
  ///
  /// [booked] holds the ids of the events she has a seat on.
  static List<PlannedNotification> build({
    required DateTime now,
    required Iterable<HubEvent> events,
    Set<String> booked = const <String>{},
  }) {
    final eligible =
        <({HubEvent event, DateTime start})>[
          for (final event in events)
            if (event.status == EventStatus.published &&
                event.startsAt.toLocal().isAfter(now) &&
                (booked.contains(event.id) || (event.seatsLeft ?? 0) > 0))
              (event: event, start: event.startsAt.toLocal()),
        ]..sort((a, b) {
          final byStart = a.start.compareTo(b.start);
          return byStart != 0 ? byStart : a.event.id.compareTo(b.event.id);
        });

    final candidates = <_Candidate>[];
    for (
      var slot = 0;
      slot < eligible.length && slot < kEventMaxPlanned;
      slot++
    ) {
      final start = eligible[slot].start;
      final isBooked = booked.contains(eligible[slot].event.id);
      final steps = isBooked
          ? const [EventReminderStep.threeHours, EventReminderStep.morningOf]
          : const [
              EventReminderStep.threeDays,
              EventReminderStep.oneDay,
              EventReminderStep.threeHours,
            ];
      final own = <_Candidate>[];
      for (final step in steps) {
        final at = afterQuietHours(_rawTime(start, step));
        if (!at.isAfter(now) || !at.isBefore(start)) continue;
        own.add(
          _Candidate(
            PlannedNotification(
              id: eventNotificationId(slot, step),
              kind: PlanKind.eventReminder,
              at: at,
              variant: eventVariantCode(
                booked: isBooked,
                variant: _variant(step, isBooked, start),
              ),
            ),
            _priority(step, isBooked),
          ),
        );
      }
      // Two notes within [minGap] of each other are one too many: keep the
      // one nearer the start.
      own.sort((a, b) => a.note.at.compareTo(b.note.at));
      for (var i = 0; i < own.length; i++) {
        final next = i + 1 < own.length ? own[i + 1] : null;
        if (next != null && next.note.at.difference(own[i].note.at) < minGap) {
          continue;
        }
        candidates.add(own[i]);
      }
    }

    // The day cap is spent in priority order, then in time order.
    candidates.sort((a, b) {
      final byPriority = a.priority.compareTo(b.priority);
      return byPriority != 0 ? byPriority : a.note.at.compareTo(b.note.at);
    });
    final perDay = <int, int>{};
    final plan = <PlannedNotification>[];
    for (final candidate in candidates) {
      final day = _dayNumber(candidate.note.at);
      final used = perDay[day] ?? 0;
      if (used >= kEventNotesPerDay) continue;
      perDay[day] = used + 1;
      plan.add(candidate.note);
    }
    plan.sort((a, b) => a.at.compareTo(b.at));
    return plan;
  }

  /// Which of the two texts a note carries. For an event she has not booked,
  /// "a new event is open for booking" is the three day note only; the later
  /// notes say it is coming up. A booked seat alternates with the day.
  static int _variant(EventReminderStep step, bool booked, DateTime start) =>
      booked
      ? _dayNumber(start) + step.index
      : (step == EventReminderStep.threeDays ? 1 : 0);

  /// A seat she holds first, then the note nearest the start.
  static int _priority(EventReminderStep step, bool booked) => booked
      ? (step == EventReminderStep.threeHours ? 0 : 1)
      : switch (step) {
          EventReminderStep.threeHours => 2,
          EventReminderStep.oneDay => 3,
          _ => 4,
        };

  static DateTime _rawTime(DateTime start, EventReminderStep step) =>
      switch (step) {
        EventReminderStep.threeDays => DateTime(
          start.year,
          start.month,
          start.day - 3,
          threeDaysHour,
        ),
        EventReminderStep.oneDay => DateTime(
          start.year,
          start.month,
          start.day - 1,
          oneDayHour,
        ),
        EventReminderStep.threeHours => start.subtract(
          const Duration(hours: 3),
        ),
        EventReminderStep.morningOf => DateTime(
          start.year,
          start.month,
          start.day,
          morningHour,
        ),
      };

  /// Whole days since 1970 for the calendar day of [at], zone-free.
  static int _dayNumber(DateTime at) =>
      DateTime.utc(at.year, at.month, at.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
}

class _Candidate {
  const _Candidate(this.note, this.priority);

  final PlannedNotification note;
  final int priority;
}
