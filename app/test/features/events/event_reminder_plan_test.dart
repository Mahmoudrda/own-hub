// The notes before an event: which events earn them, when, and how many.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/features/events/domain/event_reminder_plan.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/train/domain/notification_plan.dart';

// A Wednesday morning, local time.
final DateTime _now = DateTime(2026, 11, 4, 9);

/// An event starting at the local [start] with [capacity] seats.
HubEvent _event(
  String id,
  DateTime start, {
  int? capacity = 20,
  int taken = 0,
  EventStatus status = EventStatus.published,
}) => HubEvent(
  id: id,
  titleEn: 'Class $id',
  titleAr: 'حصة $id',
  startsAt: start.toUtc(),
  endsAt: start.add(const Duration(hours: 1)).toUtc(),
  mode: EventMode.online,
  status: status,
  capacity: capacity,
  seatsTaken: taken,
);

List<DateTime> _times(List<PlannedNotification> plan) => [
  for (final n in plan) n.at,
];

List<PlannedNotification> _plan(
  List<HubEvent> events, {
  Set<String> booked = const {},
  DateTime? now,
}) => EventReminderPlan.build(now: now ?? _now, events: events, booked: booked);

void main() {
  group('an event she has not booked', () {
    test('gets three days, the day before and three hours before', () {
      final plan = _plan([_event('a', DateTime(2026, 11, 12, 19))]);
      expect(_times(plan), [
        DateTime(2026, 11, 9, 10),
        DateTime(2026, 11, 11, 18),
        DateTime(2026, 11, 12, 16),
      ]);
      expect(plan.every((n) => n.kind == PlanKind.eventReminder), isTrue);
      expect(plan.every((n) => !n.weekly), isTrue);
      for (final n in plan) {
        expect(eventFromCode(n.variant).booked, isFalse);
      }
    });

    test('keeps only the times still ahead', () {
      // Two days away: the three day note has passed.
      final plan = _plan([_event('a', DateTime(2026, 11, 6, 19))]);
      expect(_times(plan), [
        DateTime(2026, 11, 5, 18),
        DateTime(2026, 11, 6, 16),
      ]);
      // Four hours away: only the three hour note, and it is not yet due...
      final close = _plan([
        _event('a', DateTime(2026, 11, 4, 14)),
      ], now: DateTime(2026, 11, 4, 9));
      expect(_times(close), [DateTime(2026, 11, 4, 11)]);
      // ...and one hour away has none.
      expect(
        _plan([
          _event('a', DateTime(2026, 11, 4, 14)),
        ], now: DateTime(2026, 11, 4, 13)),
        isEmpty,
      );
    });

    test('an event that has started or is over earns nothing', () {
      expect(_plan([_event('a', DateTime(2026, 11, 4, 8))]), isEmpty);
      expect(_plan([_event('a', DateTime(2026, 11, 1, 18))]), isEmpty);
    });

    test('a cancelled or draft event earns nothing', () {
      for (final status in [EventStatus.cancelled, EventStatus.draft]) {
        expect(
          _plan([_event('a', DateTime(2026, 11, 12, 19), status: status)]),
          isEmpty,
        );
      }
    });

    test('a full event, or one with no seats set, earns nothing', () {
      expect(
        _plan([_event('a', DateTime(2026, 11, 12, 19), capacity: 5, taken: 5)]),
        isEmpty,
      );
      expect(
        _plan([_event('a', DateTime(2026, 11, 12, 19), capacity: null)]),
        isEmpty,
      );
      // One seat left is enough.
      expect(
        _plan([_event('a', DateTime(2026, 11, 12, 19), capacity: 5, taken: 4)]),
        hasLength(3),
      );
    });
  });

  group('an event she has booked', () {
    test('gets the morning of and three hours before', () {
      final plan = _plan(
        [_event('a', DateTime(2026, 11, 12, 19))],
        booked: {'a'},
      );
      expect(_times(plan), [
        DateTime(2026, 11, 12, 9),
        DateTime(2026, 11, 12, 16),
      ]);
      for (final n in plan) {
        expect(eventFromCode(n.variant).booked, isTrue);
      }
    });

    test('still gets them when the event is full', () {
      final plan = _plan(
        [_event('a', DateTime(2026, 11, 12, 19), capacity: 5, taken: 5)],
        booked: {'a'},
      );
      expect(plan, hasLength(2));
    });

    test('the morning note is dropped when it sits next to the other', () {
      // 12:00 start: three hours before is 09:00, the same moment.
      expect(
        _times(_plan([_event('a', DateTime(2026, 11, 12, 12))], booked: {'a'})),
        [DateTime(2026, 11, 12, 9)],
      );
      // 13:00 start: 10:00 and 09:00 are an hour apart, so one note.
      expect(
        _times(_plan([_event('a', DateTime(2026, 11, 12, 13))], booked: {'a'})),
        [DateTime(2026, 11, 12, 10)],
      );
      // 14:00 start: two hours apart, both stay.
      expect(
        _plan([_event('a', DateTime(2026, 11, 12, 14))], booked: {'a'}),
        hasLength(2),
      );
    });

    test('a seat on one event does not change another', () {
      final plan = _plan(
        [
          _event('a', DateTime(2026, 11, 12, 19)),
          _event('b', DateTime(2026, 11, 20, 19)),
        ],
        booked: {'a'},
      );
      final b = plan.where((n) => n.at.isAfter(DateTime(2026, 11, 13)));
      expect(b, hasLength(3));
      expect(b.every((n) => !eventFromCode(n.variant).booked), isTrue);
    });
  });

  group('quiet hours', () {
    test('a note in the night moves to 08:00, never before the start', () {
      // 01:00 start: three hours before (22:00) would move to 08:00, after
      // the start, so it is dropped; the evening before still stands.
      final late = _plan([_event('a', DateTime(2026, 11, 12, 1))]);
      expect(_times(late), [
        DateTime(2026, 11, 9, 10),
        DateTime(2026, 11, 11, 18),
      ]);
      // 10:30 start: three hours before is 07:30, which becomes 08:00.
      final early = _plan([_event('a', DateTime(2026, 11, 12, 10, 30))]);
      expect(early.last.at, DateTime(2026, 11, 12, 8));
    });

    test('nothing is ever planned between 22:00 and 08:00', () {
      final events = [
        for (var i = 0; i < 6; i++)
          _event('e$i', DateTime(2026, 11, 8 + i, i * 4 + 1, 17)),
      ];
      for (final n in _plan(events)) {
        expect(n.at.hour >= kQuietToHour && n.at.hour < kQuietFromHour, isTrue);
      }
    });
  });

  group('the limits', () {
    test('at most two notes on a day, a seat she holds first', () {
      // Three events the same evening: the booked one keeps its note, the
      // others share what is left of the two.
      final day = DateTime(2026, 11, 12);
      final plan = _plan(
        [
          _event('a', DateTime(day.year, day.month, day.day, 17)),
          _event('b', DateTime(day.year, day.month, day.day, 18)),
          _event('c', DateTime(day.year, day.month, day.day, 19)),
        ],
        booked: {'c'},
      );
      final onDay = plan.where((n) => n.at.day == 12).toList();
      expect(onDay, hasLength(2));
      expect(onDay.any((n) => eventFromCode(n.variant).booked), isTrue);
      final perDay = <int, int>{};
      for (final n in plan) {
        perDay.update(n.at.day, (c) => c + 1, ifAbsent: () => 1);
      }
      expect(perDay.values.every((c) => c <= kEventNotesPerDay), isTrue);
    });

    test('only the soonest six events are planned', () {
      final events = [
        for (var i = 0; i < 9; i++)
          _event('e$i', DateTime(2026, 11, 20 + i, 19)),
      ];
      final plan = _plan(events);
      final latest = plan
          .map((n) => n.at)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      // The seventh event (28 Nov) is far past the sixth (25 Nov).
      expect(latest.isBefore(DateTime(2026, 11, 26)), isTrue);
      expect(plan.length, lessThanOrEqualTo(kEventMaxPlanned * 3));
    });

    test('the order the events arrive in does not matter', () {
      final events = [
        _event('b', DateTime(2026, 11, 20, 19)),
        _event('a', DateTime(2026, 11, 12, 19)),
      ];
      expect(_plan(events), _plan(events.reversed.toList()));
    });
  });

  group('ids', () {
    test('every id is in the block 7171 to 7194 and in kPlannedIds', () {
      final events = [
        for (var i = 0; i < 8; i++)
          _event('e$i', DateTime(2026, 11, 12 + i * 2, 19)),
      ];
      final plan = _plan(events, booked: {'e1', 'e4'});
      expect(plan, isNotEmpty);
      for (final n in plan) {
        expect(n.id, inInclusiveRange(7171, 7194));
        expect(kPlannedIds, contains(n.id));
      }
      expect(plan.map((n) => n.id).toSet(), hasLength(plan.length));
    });

    test('the mapping is slot times four plus the step', () {
      expect(eventNotificationId(0, EventReminderStep.threeDays), 7171);
      expect(eventNotificationId(0, EventReminderStep.morningOf), 7174);
      expect(eventNotificationId(5, EventReminderStep.morningOf), 7194);
      final plan = _plan([
        _event('a', DateTime(2026, 11, 12, 19)),
        _event('b', DateTime(2026, 11, 14, 19)),
      ]);
      // Event a is slot 0, event b slot 1; the step is the offset.
      expect(plan.map((n) => n.id).toList()..sort(), [
        7171, // a, three days
        7172, // a, one day
        7173, // a, three hours
        7175, // b, three days
        7176, // b, one day
        7177, // b, three hours
      ]);
    });

    test('ids are free of every other kind of note', () {
      final others = kPlannedIds.where((id) => id < 7171 || id > 7194);
      expect(others, isNotEmpty);
      expect(
        others.toSet().intersection({for (var i = 7171; i <= 7194; i++) i}),
        isEmpty,
      );
      expect(kPlannedIds.toSet(), hasLength(kPlannedIds.length));
    });

    test('the text variant rotates between the notes of one event', () {
      final plan = _plan([_event('a', DateTime(2026, 11, 12, 19))]);
      final variants = plan.map((n) => eventFromCode(n.variant).variant);
      expect(variants.toSet(), {0, 1});
    });

    test('"open for booking" is on the three day note and no other', () {
      // Text 1 of a note with no seat is "a new event is open for booking".
      final plan = _plan([_event('a', DateTime(2026, 11, 12, 19))]);
      expect(plan, hasLength(3));
      final byTime = {
        for (final n in plan) n.at: eventFromCode(n.variant).variant,
      };
      expect(byTime[DateTime(2026, 11, 9, 10)], 1);
      expect(byTime[DateTime(2026, 11, 11, 18)], 0);
      expect(byTime[DateTime(2026, 11, 12, 16)], 0);
      // Whatever the date, the later notes never carry text 1.
      for (var day = 10; day < 28; day++) {
        for (final n in _plan([_event('a', DateTime(2026, 11, day, 19))])) {
          final threeDays = n.at.hour == 10 && n.at.day == day - 3;
          expect(eventFromCode(n.variant).variant, threeDays ? 1 : 0);
        }
      }
    });
  });

  group('the plan as a whole', () {
    test('event notes ride along with the training days without a budget', () {
      final events = [
        for (var i = 0; i < 6; i++)
          _event('e$i', DateTime(2026, 11, 8 + i, 19)),
      ];
      final notes = _plan(events);
      final plan = NotificationPlan.build(
        now: _now,
        permitted: true,
        events: notes,
      );
      expect(plan.where((n) => n.kind == PlanKind.eventReminder), notes);
    });

    test('off, none are kept', () {
      final notes = _plan([_event('a', DateTime(2026, 11, 12, 19))]);
      final plan = NotificationPlan.build(
        now: _now,
        permitted: true,
        prefs: const NotificationPrefs(events: false),
        events: notes,
      );
      expect(plan.where((n) => n.kind == PlanKind.eventReminder), isEmpty);
    });

    test('nothing before the phone has agreed', () {
      final notes = _plan([_event('a', DateTime(2026, 11, 12, 19))]);
      expect(
        NotificationPlan.build(now: _now, permitted: false, events: notes),
        isEmpty,
      );
    });

    test('they take no place in the casual notes\' week', () {
      // The same casual notes with and without a crowd of events.
      final without = NotificationPlan.build(now: _now, permitted: true);
      final events = [
        for (var i = 0; i < 6; i++)
          _event('e$i', DateTime(2026, 11, 8 + i, 19)),
      ];
      final withEvents = NotificationPlan.build(
        now: _now,
        permitted: true,
        events: _plan(events),
      );
      expect(
        withEvents.where((n) => n.kind != PlanKind.eventReminder).toList(),
        without,
      );
    });
  });
}
