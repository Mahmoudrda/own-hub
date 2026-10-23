// Events, below the screens: Cairo time, the owner's draft, and the document
// shape the rules accept.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/events/domain/cairo_time.dart';
import 'package:own_hub/features/events/domain/event_draft.dart';
import 'package:own_hub/features/events/domain/event_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';

HubEvent event({
  String id = 'e1',
  EventStatus status = EventStatus.published,
  DateTime? starts,
  DateTime? ends,
}) {
  final s = starts ?? DateTime.utc(2026, 11, 5, 16, 30);
  return HubEvent(
    id: id,
    titleEn: 'Morning stretch',
    titleAr: 'tamaddud',
    startsAt: s,
    endsAt: ends ?? s.add(const Duration(hours: 1)),
    mode: EventMode.online,
    link: 'https://meet.example.com/x',
    status: status,
  );
}

void main() {
  group('Cairo time', () {
    test('winter is UTC+2', () {
      final at = parseCairo('2026-01-15 18:30')!;
      expect(at, DateTime.utc(2026, 1, 15, 16, 30));
      expect(formatCairo(at), '2026-01-15 18:30');
    });

    test('summer is UTC+3, because Egypt moves its clocks again', () {
      final at = parseCairo('2026-07-15 18:30')!;
      expect(at, DateTime.utc(2026, 7, 15, 15, 30));
      expect(formatCairo(at), '2026-07-15 18:30');
    });

    test('the same instant reads as Cairo time whatever the phone says', () {
      final at = DateTime.utc(2026, 11, 5, 16, 30);
      expect(cairoDay(at), '2026-11-05');
      expect(cairoClock(at), '18:30');
      expect(cairoWeekday(at), DateTime.thursday);
    });

    test('anything else is refused rather than guessed', () {
      for (final bad in [
        '',
        '5/11/2026 18:30',
        '2026-11-05',
        '2026-02-30 10:00',
        '2026-11-05 25:00',
        '٢٠٢٦-١١-٠٥ ١٨:٣٠',
      ]) {
        expect(parseCairo(bad), isNull, reason: bad);
      }
    });
  });

  group('the draft', () {
    const good = EventDraft(
      titleEn: 'Morning stretch',
      titleAr: 'tamaddud',
      startsAt: '2026-11-05 18:30',
      endsAt: '2026-11-05 19:30',
      link: 'https://meet.example.com/x',
    );

    test('a complete online event has no problems', () {
      expect(good.problems(), isEmpty);
      final e = good.toEvent(id: 'e1', status: EventStatus.draft)!;
      expect(e.startsAt, DateTime.utc(2026, 11, 5, 16, 30));
      expect(e.placeName, isNull);
    });

    test('each rule the server holds is said beside its field', () {
      const draft = EventDraft(
        titleEn: '',
        titleAr: 'x',
        startsAt: '2026-11-05 18:30',
        endsAt: '2026-11-05 18:00',
        link: 'http://meet.example.com/x',
        capacity: '0',
      );
      expect(draft.problems(), {
        EventField.titleEn: EventProblem.required,
        EventField.endsAt: EventProblem.endBeforeStart,
        EventField.link: EventProblem.badLink,
        EventField.capacity: EventProblem.badCapacity,
      });
      expect(draft.toEvent(id: 'e1', status: EventStatus.draft), isNull);
    });

    test('in person needs a place name and nothing more precise', () {
      const draft = EventDraft(
        titleEn: 'Walk',
        titleAr: 'mashy',
        startsAt: '2026-11-05 18:30',
        endsAt: '2026-11-05 19:30',
        mode: EventMode.place,
      );
      expect(draft.problems(), {EventField.placeName: EventProblem.required});
      const named = EventDraft(
        titleEn: 'Walk',
        titleAr: 'mashy',
        startsAt: '2026-11-05 18:30',
        endsAt: '2026-11-05 19:30',
        mode: EventMode.place,
        placeName: 'Zamalek ladies gym',
        capacity: '20',
      );
      final e = named.toEvent(id: 'e2', status: EventStatus.published)!;
      expect(e.link, isNull);
      expect(e.capacity, 20);
    });

    EventDraft place(String url, {String capacity = '', int taken = 0}) =>
        EventDraft(
          titleEn: 'Walk',
          titleAr: 'mashy',
          startsAt: '2026-11-05 18:30',
          endsAt: '2026-11-05 19:30',
          mode: EventMode.place,
          placeName: 'Gym',
          locationUrl: url,
          capacity: capacity,
          seatsTaken: taken,
        );

    test('the maps link is matched whole, and goo.gl only under /maps', () {
      for (final ok in [
        'https://maps.google.com',
        'https://maps.google.com/?q=cairo',
        'https://maps.app.goo.gl/abc123',
        'https://goo.gl/maps/abc',
        'https://www.google.com/maps/place/x',
      ]) {
        expect(place(ok).problems(), isEmpty, reason: ok);
      }
      for (final bad in [
        'https://goo.gl',
        'https://goo.gl/other/maps',
        'https://goo.gl/mapsx',
        'https://maps.google.com/ok\nevil',
        'https://maps.google.com/has space',
        'https://maps.google.com.evil.com/x',
        'http://maps.google.com/x',
      ]) {
        expect(
          place(bad).problems()[EventField.locationUrl],
          EventProblem.badMapsLink,
          reason: bad,
        );
      }
    });

    test('the online link takes no whitespace at all', () {
      for (final bad in ['https://meet.example.com/a\nb', 'https://a b.com']) {
        final draft = EventDraft(
          titleEn: 'x',
          titleAr: 'y',
          startsAt: '2026-11-05 18:30',
          endsAt: '2026-11-05 19:30',
          link: bad,
        );
        expect(draft.problems()[EventField.link], EventProblem.badLink);
      }
    });

    test('capacity cannot go below the seats already reserved', () {
      expect(place('', capacity: '10', taken: 12).problems(), {
        EventField.capacity: EventProblem.capacityBelowSeats,
      });
      expect(place('', capacity: '', taken: 12).problems(), {
        EventField.capacity: EventProblem.capacityBelowSeats,
      });
      expect(place('', capacity: '12', taken: 12).problems(), isEmpty);
      expect(place('', capacity: '', taken: 0).problems(), isEmpty);
    });

    test('opening a stored event remembers its seats', () {
      final e = good.toEvent(id: 'e1', status: EventStatus.published)!;
      expect(EventDraft.of(e.copyWith(seatsTaken: 7)).seatsTaken, 7);
    });

    test('it opens an event exactly as it was saved', () {
      final e = good.toEvent(id: 'e1', status: EventStatus.published)!;
      final again = EventDraft.of(e)
          .toEvent(id: 'e1', status: EventStatus.published);
      expect(again, e);
    });
  });

  group('the document', () {
    test('carries exactly the keys the rules allow, and no person', () {
      final doc = event().toDocument();
      expect(doc.keys.toSet(), {
        'titleEn',
        'titleAr',
        'descriptionEn',
        'descriptionAr',
        'startsAt',
        'endsAt',
        'timeZone',
        'mode',
        'link',
        'placeName',
        'audience',
        'capacity',
        'coverFile',
        'imageFiles',
        'videoFiles',
        'locationAddress',
        'locationUrl',
        'status',
      });
      // seatsTaken is the server's alone: the rules refuse a changed count.
      expect(doc.containsKey('seatsTaken'), isFalse);
      expect(doc['audience'], 'all');
      expect(doc['timeZone'], 'Africa/Cairo');
    });

    test('round trips, and a broken document is skipped rather than shown', () {
      final e = event();
      expect(HubEvent.fromDocument('e1', e.toDocument()), e);
      expect(
        HubEvent.fromDocument('e1', {...e.toDocument(), 'status': 'live'}),
        isNull,
      );
      expect(
        HubEvent.fromDocument('e1', {...e.toDocument(), 'endsAt': e.startsAt}),
        isNull,
      );
    });

    test('a cover lives under content/events only', () {
      final e = HubEvent.fromDocument('e9', {
        ...event().toDocument(),
        'coverFile': 'cover.jpg',
      })!;
      expect(e.coverPath, 'content/events/e9/cover.jpg');
    });
  });

  group('what a member is shown', () {
    final now = DateTime.utc(2026, 11, 5, 12);

    test('published and not over, soonest first', () async {
      final store = InMemoryEvents([
        event(id: 'later', starts: now.add(const Duration(days: 3))),
        event(id: 'soon', starts: now.add(const Duration(hours: 2))),
        event(id: 'running', starts: now.subtract(const Duration(minutes: 30))),
        event(id: 'over', starts: now.subtract(const Duration(days: 1))),
        event(
          id: 'draft',
          status: EventStatus.draft,
          starts: now.add(const Duration(days: 1)),
        ),
        event(
          id: 'cancelled',
          status: EventStatus.cancelled,
          starts: now.add(const Duration(days: 1)),
        ),
      ]);
      final shown = await store.upcoming(now);
      expect([for (final e in shown) e.id], ['running', 'soon', 'later']);
    });

    test('the store mints ids that do not collide', () {
      final store = InMemoryEvents([event(id: 'event-1')]);
      expect(store.newId(), 'event-2');
    });
  });
}
