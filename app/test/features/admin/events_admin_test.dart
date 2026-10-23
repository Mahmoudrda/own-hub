// Z17 and Z18: the owner creates, edits, publishes and cancels an event.
//
// Against InMemoryEvents, which records every save, so each test asserts what
// was stored rather than what a callback was handed. The rules that hold the
// same shape on the server are test/rules/17-events-and-console.test.js.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/admin/presentation/event_form_view.dart';
import 'package:own_hub/features/admin/presentation/events_admin_view.dart';
import 'package:own_hub/features/events/domain/event_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

HubEvent _event(String id, EventStatus status) => HubEvent(
  id: id,
  titleEn: 'Stretch $id',
  titleAr: 'tamaddud $id',
  startsAt: DateTime.utc(2026, 11, 5, 16, 30),
  endsAt: DateTime.utc(2026, 11, 5, 17, 30),
  mode: EventMode.online,
  link: 'https://meet.example.com/$id',
  status: status,
);

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);

Future<void> _type(WidgetTester tester, String label, String value) async {
  final semantics = _field(label);
  expect(semantics, findsOneWidget, reason: 'no field labelled "$label"');
  final field = find.descendant(
    of: semantics,
    matching: find.byType(TextField),
  );
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester) async {
  await _type(tester, 'Title (English)', 'Morning stretch');
  await _type(tester, 'Title (Arabic)', 'tamaddud');
  await _type(tester, 'Starts, Cairo time', '2026-11-05 18:30');
  await _type(tester, 'Ends, Cairo time', '2026-11-05 19:30');
  await _type(
    tester,
    'Link, starting with https://',
    'https://meet.example.com/x',
  );
}

void main() {
  group('Z17 — every event, with its status', () {
    testWidgets('drafts, published and cancelled, newest first', (
      tester,
    ) async {
      _phone(tester);
      final store = InMemoryEvents([
        _event('a', EventStatus.draft),
        _event('b', EventStatus.published),
        _event('c', EventStatus.cancelled),
      ]);
      HubEvent? opened;
      await tester.pumpWidget(
        _host(EventsAdminView(store: store, onOpen: (e) => opened = e)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      await tester.tap(find.text('Stretch b'));
      expect(opened?.id, 'b');
    });

    testWidgets('none yet: says so and offers Add', (tester) async {
      _phone(tester);
      var added = 0;
      await tester.pumpWidget(
        _host(EventsAdminView(store: InMemoryEvents(), onAdd: () => added++)),
      );
      await tester.pumpAndSettle();
      expect(find.text('No events yet'), findsOneWidget);
      await tester.tap(find.text('Add an event'));
      expect(added, 1);
    });
  });

  group('Z18 — one event', () {
    testWidgets('a new event publishes, in Cairo time, for all members', (
      tester,
    ) async {
      _phone(tester);
      final store = InMemoryEvents();
      HubEvent? saved;
      await tester.pumpWidget(
        _host(EventFormView(store: store, onSaved: (e) => saved = e)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Add an event'), findsOneWidget);

      await _fill(tester);
      await _tap(tester, 'Publish');

      expect(store.writes, hasLength(1));
      final stored = store.events[store.writes.single]!;
      expect(stored.status, EventStatus.published);
      expect(stored.startsAt, DateTime.utc(2026, 11, 5, 16, 30));
      expect(stored.toDocument()['audience'], 'all');
      expect(saved, stored);
    });

    testWidgets('save as draft keeps it from members', (tester) async {
      _phone(tester);
      final store = InMemoryEvents();
      await tester.pumpWidget(_host(EventFormView(store: store)));
      await tester.pumpAndSettle();
      await _fill(tester);
      await _tap(tester, 'Save as draft');
      expect(store.events.values.single.status, EventStatus.draft);
    });

    testWidgets('nothing is stored while a field is wrong, and it says which', (
      tester,
    ) async {
      _phone(tester);
      final store = InMemoryEvents();
      await tester.pumpWidget(_host(EventFormView(store: store)));
      await tester.pumpAndSettle();
      await _type(tester, 'Title (English)', 'Morning stretch');
      await _type(tester, 'Starts, Cairo time', 'tomorrow evening');
      await _type(tester, 'Link, starting with https://', 'http://x.example');
      await _tap(tester, 'Publish');

      expect(store.writes, isEmpty);
      expect(find.text('Required'), findsWidgets);
      expect(find.text('Use the format 2026-11-05 18:30.'), findsOneWidget);
      expect(find.text('Use a link that starts with https://'), findsOneWidget);
    });

    testWidgets('in person asks for a place, an address and a Maps link', (
      tester,
    ) async {
      _phone(tester);
      final store = InMemoryEvents();
      await tester.pumpWidget(_host(EventFormView(store: store)));
      await tester.pumpAndSettle();
      await _type(tester, 'Title (English)', 'Walk');
      await _type(tester, 'Title (Arabic)', 'mashy');
      await _type(tester, 'Starts, Cairo time', '2026-11-07 08:00');
      await _type(tester, 'Ends, Cairo time', '2026-11-07 09:00');
      await _tap(tester, 'In person');
      await _type(tester, 'Place name', 'Zamalek ladies gym');
      await _type(tester, 'Street address (optional)', '4 Brazil St, Zamalek');
      await _type(
        tester,
        'Google Maps link (optional)',
        'https://maps.app.goo.gl/abc',
      );
      await _type(tester, 'Seats members can reserve (optional)', '20');
      await _tap(tester, 'Publish');
      final stored = store.events.values.single;
      expect(stored.mode, EventMode.place);
      expect(stored.placeName, 'Zamalek ladies gym');
      expect(stored.locationAddress, '4 Brazil St, Zamalek');
      expect(stored.locationUrl, 'https://maps.app.goo.gl/abc');
      expect(stored.link, isNull);
      expect(stored.capacity, 20);
      expect(stored.seatsTaken, 0);
    });

    testWidgets('a Maps link from any other host is refused beside the field', (
      tester,
    ) async {
      _phone(tester);
      final store = InMemoryEvents();
      await tester.pumpWidget(_host(EventFormView(store: store)));
      await tester.pumpAndSettle();
      await _type(tester, 'Title (English)', 'Walk');
      await _type(tester, 'Title (Arabic)', 'mashy');
      await _type(tester, 'Starts, Cairo time', '2026-11-07 08:00');
      await _type(tester, 'Ends, Cairo time', '2026-11-07 09:00');
      await _tap(tester, 'In person');
      await _type(tester, 'Place name', 'Zamalek ladies gym');
      await _type(
        tester,
        'Google Maps link (optional)',
        'https://evil.example.com/x',
      );
      await _tap(tester, 'Publish');
      expect(store.writes, isEmpty);
      expect(find.text('Use a link from Google Maps.'), findsOneWidget);
    });

    testWidgets('several pictures and clips come from the media library', (
      tester,
    ) async {
      _phone(tester);
      final store = InMemoryEvents();
      await tester.pumpWidget(
        _host(
          EventFormView(
            store: store,
            mediaNames: const ['a.webp', 'b.webp', 'intro.mp4', 'notes.pdf'],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _fill(tester);
      expect(find.text('notes.pdf'), findsNothing);
      await tester.ensureVisible(find.text('Event videos'));
      await tester.pumpAndSettle();
      // The picture names appear under the cover and under the pictures.
      await tester.tap(find.text('b.webp').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('a.webp').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('intro.mp4'));
      await tester.pumpAndSettle();
      await _tap(tester, 'Publish');
      final stored = store.events.values.single;
      expect(stored.imageFiles, ['b.webp', 'a.webp']);
      expect(stored.videoFiles, ['intro.mp4']);
      expect(stored.picturePaths, [
        'content/events/${stored.id}/b.webp',
        'content/events/${stored.id}/a.webp',
      ]);
    });

    testWidgets('cancelling asks once, inline, then stores cancelled', (
      tester,
    ) async {
      _phone(tester);
      final published = _event('e1', EventStatus.published);
      final store = InMemoryEvents([published]);
      await tester.pumpWidget(
        _host(EventFormView(store: store, event: published)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit an event'), findsOneWidget);

      await _tap(tester, 'Cancel this event');
      expect(store.writes, isEmpty, reason: 'one tap must not cancel it');
      expect(find.text('Members will no longer see it.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);

      await _tap(tester, 'Keep it');
      expect(store.writes, isEmpty);

      await _tap(tester, 'Cancel this event');
      await _tap(tester, 'Yes, cancel it');
      expect(store.events['e1']!.status, EventStatus.cancelled);
    });

    testWidgets('a published event goes back to draft', (tester) async {
      _phone(tester);
      final published = _event('e1', EventStatus.published);
      final store = InMemoryEvents([published]);
      await tester.pumpWidget(
        _host(EventFormView(store: store, event: published)),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'Move back to draft');
      expect(store.events['e1']!.status, EventStatus.draft);
      expect(store.events['e1']!.titleEn, 'Stretch e1');
    });

    testWidgets('a refused save says so and keeps the form', (tester) async {
      _phone(tester);
      var failed = 0;
      await tester.pumpWidget(
        _host(EventFormView(store: _RefusingStore(), onFailed: () => failed++)),
      );
      await tester.pumpAndSettle();
      await _fill(tester);
      await _tap(tester, 'Publish');
      expect(failed, 1);
      expect(find.text('Add an event'), findsOneWidget);
    });

    testWidgets('a cover comes from the media library', (tester) async {
      _phone(tester);
      final store = InMemoryEvents();
      await tester.pumpWidget(
        _host(EventFormView(store: store, mediaNames: const ['cover.jpg'])),
      );
      await tester.pumpAndSettle();
      await _fill(tester);
      await _tap(tester, 'cover.jpg');
      await _tap(tester, 'Publish');
      final stored = store.events.values.single;
      expect(stored.coverPath, 'content/events/${stored.id}/cover.jpg');
    });

    testWidgets('with no pictures uploaded, it says so', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(EventFormView(store: InMemoryEvents())));
      await tester.pumpAndSettle();
      expect(find.text('No pictures in the media library yet.'), findsWidgets);
      expect(find.text('No videos in the media library yet.'), findsOneWidget);
    });

    testWidgets('in Arabic, the Arabic title field reads right to left', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          EventFormView(store: InMemoryEvents()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final fields = tester.widgetList<TextField>(find.byType(TextField));
      expect(
        fields.map((f) => f.textDirection),
        containsAll([TextDirection.rtl, TextDirection.ltr]),
      );
    });
  });
}

class _RefusingStore extends InMemoryEvents {
  @override
  Future<void> save(HubEvent event) async =>
      throw StateError('permission-denied');
}
