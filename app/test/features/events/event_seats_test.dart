// What a member sees of seats on T09, and what her taps ask the server.
//
//   * the seats line: "{n} of {capacity} seats left", "Full", nothing at all
//     when the owner set no limit;
//   * Reserve for a woman without a seat, Cancel for one with it, on a full or
//     closed event too, and no Reserve where one cannot succeed;
//   * a tap calls the registrar and shows the server's count; a refusal is
//     said in plain words;
//   * Open in Maps only for the Google Maps hosts the rules allow;
//   * the nav bar gives the community's slot to Events while the community
//     is off, and keeps it for the community when it is on.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:own_hub/domain/rewards/rewards.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/features/progress/presentation/progress_view_model.dart';
import 'package:own_hub/features/progress/presentation/you_view.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/identity/user_roles.dart';
import 'package:own_hub/features/events/domain/event_draft.dart';
import 'package:own_hub/features/events/domain/event_registration.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/events/presentation/events_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

final DateTime _now = DateTime.utc(2026, 11, 1, 10);

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

HubEvent _event({
  int? capacity = 20,
  int seatsTaken = 16,
  DateTime? endsAt,
  EventStatus status = EventStatus.published,
  String? locationUrl,
  String? locationAddress,
  String? coverFile,
  List<String> imageFiles = const [],
  List<String> videoFiles = const [],
}) => HubEvent(
  id: 'e2',
  titleEn: 'Walk by the Nile',
  titleAr: 'mashy',
  startsAt: DateTime.utc(2026, 11, 7, 6),
  endsAt: endsAt ?? DateTime.utc(2026, 11, 7, 7),
  mode: EventMode.place,
  placeName: 'Zamalek ladies gym',
  locationAddress: locationAddress,
  locationUrl: locationUrl,
  capacity: capacity,
  seatsTaken: seatsTaken,
  coverFile: coverFile,
  imageFiles: imageFiles,
  videoFiles: videoFiles,
  status: status,
);

class _FakeRegistrar implements EventRegistrar {
  _FakeRegistrar({this.registered = false, this.taken = 16, this.refuse});

  bool registered;
  int taken;
  SeatFailure? refuse;
  final List<String> calls = [];

  /// Holds the next register open until completed.
  Completer<void>? gate;

  /// How many reads fail before one succeeds.
  int readsToFail = 0;

  @override
  Future<bool> isRegistered(String eventId) async {
    if (readsToFail > 0) {
      readsToFail--;
      throw const EventRegistrationException(SeatFailure.offline);
    }
    return registered;
  }

  @override
  Future<SeatResult> register(String eventId) async {
    calls.add('register:$eventId');
    await gate?.future;
    final failure = refuse;
    if (failure != null) throw EventRegistrationException(failure);
    if (!registered) taken++;
    registered = true;
    return SeatResult(registered: true, seatsTaken: taken, capacity: 20);
  }

  @override
  Future<SeatResult> cancel(String eventId) async {
    calls.add('cancel:$eventId');
    if (registered) taken--;
    registered = false;
    return SeatResult(registered: false, seatsTaken: taken, capacity: 20);
  }
}

Future<void> _show(
  WidgetTester tester,
  HubEvent event, {
  EventRegistrar? registrar,
  ValueChanged<String>? onOpenLink,
  Locale locale = const Locale('en'),
}) async {
  _phone(tester);
  await tester.pumpWidget(
    _host(
      EventsView(
        events: [event],
        registrar: registrar,
        onOpenLink: onOpenLink,
        now: () => _now,
      ),
      locale: locale,
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = savedFlags);

  group('when her booking cannot be read', () {
    testWidgets('she can still reach Cancel, and Try again re-reads', (
      tester,
    ) async {
      final registrar = _FakeRegistrar(registered: true)..readsToFail = 1;
      await _show(tester, _event(), registrar: registrar);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.text('Cancel my reservation'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Your seat is reserved'), findsOneWidget);
      expect(find.text('Cancel my reservation'), findsOneWidget);
    });

    testWidgets('Cancel works from the unknown state', (tester) async {
      final registrar = _FakeRegistrar(registered: true)..readsToFail = 5;
      await _show(tester, _event(), registrar: registrar);
      await tester.tap(find.text('Cancel my reservation'));
      await tester.pumpAndSettle();
      expect(registrar.calls, ['cancel:e2']);
      expect(registrar.registered, isFalse);
    });
  });

  group('the seats line', () {
    testWidgets('seats left, in English', (tester) async {
      await _show(tester, _event(), registrar: _FakeRegistrar());
      expect(find.text('4 of 20 seats left'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsOneWidget);
    });

    testWidgets('seats left, in Egyptian Arabic with Western digits', (
      tester,
    ) async {
      await _show(
        tester,
        _event(),
        registrar: _FakeRegistrar(),
        locale: const Locale('ar'),
      );
      expect(find.text('فاضل 4 مكان من 20'), findsOneWidget);
      expect(find.text('احجزي مكانك'), findsOneWidget);
    });

    testWidgets('full: says so and offers no Reserve', (tester) async {
      await _show(
        tester,
        _event(seatsTaken: 20),
        registrar: _FakeRegistrar(taken: 20),
      );
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsNothing);
      expect(find.textContaining('seats left'), findsNothing);
    });

    testWidgets('a count past the limit still reads Full, never negative', (
      tester,
    ) async {
      await _show(tester, _event(seatsTaken: 25), registrar: _FakeRegistrar());
      expect(find.text('Full'), findsOneWidget);
    });

    testWidgets('registered: her state, and Cancel even when full', (
      tester,
    ) async {
      await _show(
        tester,
        _event(seatsTaken: 20),
        registrar: _FakeRegistrar(registered: true, taken: 20),
      );
      expect(find.text('Your seat is reserved'), findsOneWidget);
      expect(find.text('Cancel my reservation'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsNothing);
    });

    testWidgets('closed: no Reserve, and the reason', (tester) async {
      await _show(
        tester,
        _event(status: EventStatus.cancelled),
        registrar: _FakeRegistrar(),
      );
      expect(find.text('Reserve my seat'), findsNothing);
      expect(
        find.text('Reservations for this event are closed.'),
        findsOneWidget,
      );
    });

    testWidgets('a vanished event says it is closed once, not twice', (
      tester,
    ) async {
      await _show(
        tester,
        _event(),
        registrar: _FakeRegistrar(refuse: SeatFailure.notFound),
      );
      await tester.tap(find.text('Reserve my seat'));
      await tester.pumpAndSettle();
      expect(
        find.text('Reservations for this event are closed.'),
        findsOneWidget,
      );
    });

    testWidgets('a refreshed count replaces the one it was drawn with', (
      tester,
    ) async {
      _phone(tester);
      Widget app(int taken) => _host(
        EventsView(
          events: [_event(seatsTaken: taken)],
          registrar: _FakeRegistrar(),
          now: () => _now,
        ),
      );
      await tester.pumpWidget(app(16));
      await tester.pumpAndSettle();
      expect(find.text('4 of 20 seats left'), findsOneWidget);
      await tester.pumpWidget(app(19));
      await tester.pumpAndSettle();
      expect(find.text('1 of 20 seats left'), findsOneWidget);
    });

    testWidgets('closed but registered: she can still give the seat back', (
      tester,
    ) async {
      await _show(
        tester,
        _event(status: EventStatus.cancelled),
        registrar: _FakeRegistrar(registered: true),
      );
      expect(find.text('Cancel my reservation'), findsOneWidget);
    });

    testWidgets('no limit set: no seats line and nothing to reserve', (
      tester,
    ) async {
      await _show(
        tester,
        _event(capacity: null, seatsTaken: 0),
        registrar: _FakeRegistrar(),
      );
      expect(find.textContaining('seats'), findsNothing);
      expect(find.text('Full'), findsNothing);
      expect(find.text('Reserve my seat'), findsNothing);
    });

    testWidgets('with no registrar the line shows and nothing can be tapped', (
      tester,
    ) async {
      await _show(tester, _event());
      expect(find.text('4 of 20 seats left'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsNothing);
    });
  });

  group('her taps', () {
    testWidgets('Reserve asks the server, then offers Cancel', (tester) async {
      final registrar = _FakeRegistrar();
      await _show(tester, _event(), registrar: registrar);
      await tester.tap(find.text('Reserve my seat'));
      await tester.pumpAndSettle();
      expect(registrar.calls, ['register:e2']);
      expect(find.text('3 of 20 seats left'), findsOneWidget);
      expect(find.text('Your seat is reserved'), findsOneWidget);
      expect(find.text('Cancel my reservation'), findsOneWidget);

      await tester.tap(find.text('Cancel my reservation'));
      await tester.pumpAndSettle();
      expect(registrar.calls, ['register:e2', 'cancel:e2']);
      expect(find.text('4 of 20 seats left'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsOneWidget);
    });

    testWidgets('the button shows progress and cannot be tapped twice', (
      tester,
    ) async {
      final registrar = _FakeRegistrar()..gate = Completer<void>();
      await _show(tester, _event(), registrar: registrar);
      await tester.tap(find.text('Reserve my seat'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.text('Reserve my seat'), warnIfMissed: false);
      await tester.pump();
      registrar.gate!.complete();
      await tester.pumpAndSettle();
      expect(registrar.calls, ['register:e2']);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('a refusal as full is said, and the line reads Full', (
      tester,
    ) async {
      final registrar = _FakeRegistrar(refuse: SeatFailure.full);
      await _show(tester, _event(), registrar: registrar);
      await tester.tap(find.text('Reserve my seat'));
      await tester.pumpAndSettle();
      expect(find.text('This event is full.'), findsOneWidget);
      expect(find.text('Full'), findsOneWidget);
      expect(find.text('Reserve my seat'), findsNothing);
    });

    testWidgets('no connection is said plainly and she can try again', (
      tester,
    ) async {
      final registrar = _FakeRegistrar(refuse: SeatFailure.offline);
      await _show(tester, _event(), registrar: registrar);
      await tester.tap(find.text('Reserve my seat'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'We could not update your reservation. Check your connection and try again.',
        ),
        findsOneWidget,
      );
      expect(find.text('Reserve my seat'), findsOneWidget);
    });

    testWidgets('not verified and an out-of-date app get their own words', (
      tester,
    ) async {
      for (final (failure, text) in [
        (SeatFailure.notVerified, 'Only verified members can reserve a seat.'),
        (SeatFailure.updateApp, 'Update Own Hub to reserve a seat.'),
      ]) {
        await _show(
          tester,
          _event(),
          registrar: _FakeRegistrar(refuse: failure),
        );
        await tester.tap(find.text('Reserve my seat'));
        await tester.pumpAndSettle();
        expect(find.text(text), findsOneWidget);
      }
    });
  });

  group('the server failures, in the domain\'s words', () {
    test('each status and message', () {
      expect(
        seatFailureOf('failed-precondition', 'event_full'),
        SeatFailure.full,
      );
      expect(
        seatFailureOf('failed-precondition', 'event_closed'),
        SeatFailure.closed,
      );
      expect(
        seatFailureOf('failed-precondition', 'app_check_missing'),
        SeatFailure.updateApp,
      );
      expect(
        seatFailureOf('permission-denied', 'not_verified'),
        SeatFailure.notVerified,
      );
      expect(
        seatFailureOf('not-found', 'event_not_found'),
        SeatFailure.notFound,
      );
      expect(seatFailureOf('unavailable', null), SeatFailure.offline);
    });
  });

  group('the place in Maps', () {
    testWidgets('an allowed host opens, with the venue and address', (
      tester,
    ) async {
      final opened = <String>[];
      await _show(
        tester,
        _event(
          locationUrl: 'https://maps.app.goo.gl/abc123',
          locationAddress: '4 Brazil St, Zamalek',
        ),
        onOpenLink: opened.add,
      );
      expect(find.text('Zamalek ladies gym'), findsOneWidget);
      expect(find.text('4 Brazil St, Zamalek'), findsOneWidget);
      await tester.tap(find.text('Open in Maps'));
      expect(opened, ['https://maps.app.goo.gl/abc123']);
    });

    testWidgets('a host that is not Google Maps shows no button', (
      tester,
    ) async {
      await _show(
        tester,
        _event(locationUrl: 'https://evil.example.com/maps'),
        onOpenLink: (_) {},
      );
      expect(find.text('Open in Maps'), findsNothing);
    });

    test('only the hosts the rules allow', () {
      for (final ok in [
        'https://maps.google.com/?q=cairo',
        'https://goo.gl/maps/abc',
        'https://maps.app.goo.gl/abc',
        'https://www.google.com/maps/place/x',
        'https://maps.google.com',
      ]) {
        expect(isAllowedMapsUrl(ok), isTrue, reason: ok);
      }
      for (final bad in [
        'http://maps.google.com/x',
        'https://maps.google.com.evil.com/x',
        'https://evil.com/?u=https://maps.google.com',
        'https://google.com/maps',
        'https://goo.gl',
        'https://goo.gl/other',
        'https://maps.google.com/ok\nbad',
        'https://maps.google.com/has space',
        'javascript:alert(1)',
      ]) {
        expect(isAllowedMapsUrl(bad), isFalse, reason: bad);
      }
    });

    test('a stored document with a bad link or file names drops them', () {
      final event = HubEvent.fromDocument('e9', {
        'titleEn': 'a',
        'titleAr': 'b',
        'startsAt': DateTime.utc(2026, 11, 7, 6),
        'endsAt': DateTime.utc(2026, 11, 7, 7),
        'mode': 'place',
        'status': 'published',
        'placeName': 'Gym',
        'locationUrl': 'https://evil.example.com/x',
        'imageFiles': ['a.webp', '../b.webp', 7, 'c.jpg'],
        'videoFiles': ['clip.mp4', 'x.mov'],
        'seatsTaken': -3,
        'capacity': 10,
      })!;
      expect(event.locationUrl, isNull);
      expect(event.imageFiles, ['a.webp', 'c.jpg']);
      expect(event.videoFiles, ['clip.mp4']);
      expect(event.seatsTaken, 0);
      expect(event.seatsLeft, 10);
    });

    test('the document the app writes never carries the seat count', () {
      final body = _event(seatsTaken: 5).toDocument();
      expect(body.containsKey('seatsTaken'), isFalse);
      expect(body['locationUrl'], isNull);
      expect(body['imageFiles'], isEmpty);
    });
  });

  group('pictures and clips', () {
    testWidgets('the cover and pictures page with a dot each', (tester) async {
      await _show(
        tester,
        _event(coverFile: 'a.webp', imageFiles: ['a.webp', 'b.webp', 'c.jpg']),
      );
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byKey(const ValueKey('event-dot-0')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-dot-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-dot-3')), findsNothing);
    });

    testWidgets('a clip waits for her tap: nothing is fetched before it', (
      tester,
    ) async {
      _phone(tester);
      final fetched = <String>[];
      await tester.pumpWidget(
        _host(
          EventsView(
            events: [
              _event(videoFiles: ['intro.mp4']),
            ],
            fetchClip: (path) async {
              fetched.add(path);
              return null;
            },
            now: () => _now,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(fetched, isEmpty);
      expect(find.bySemanticsLabel('Play'), findsOneWidget);
    });
  });

  group('the validation mirrors the rules', () {
    EventDraft draft({
      String maps = '',
      List<String> images = const [],
      List<String> videos = const [],
    }) => EventDraft(
      titleEn: 'a',
      titleAr: 'b',
      startsAt: '2026-11-05 18:30',
      endsAt: '2026-11-05 19:30',
      mode: EventMode.place,
      placeName: 'Gym',
      locationUrl: maps,
      imageFiles: images,
      videoFiles: videos,
    );

    test(
      'a Maps link, at most six pictures and two clips, rule-shaped names',
      () {
        expect(draft().problems(), isEmpty);
        expect(draft(maps: 'https://evil.example.com').problems(), {
          EventField.locationUrl: EventProblem.badMapsLink,
        });
        expect(
          draft(images: [for (var i = 0; i < 7; i++) 'p$i.webp']).problems(),
          {EventField.imageFiles: EventProblem.tooMany},
        );
        expect(draft(videos: ['a.mp4', 'b.mp4', 'c.mp4']).problems(), {
          EventField.videoFiles: EventProblem.tooMany,
        });
        expect(draft(images: ['Bad Name.png']).problems(), {
          EventField.imageFiles: EventProblem.badFile,
        });
        expect(
          draft(
            maps: 'https://maps.app.goo.gl/x',
            images: ['a.webp'],
          ).toEvent(id: 'e', status: EventStatus.draft)!.locationUrl,
          'https://maps.app.goo.gl/x',
        );
      },
    );
  });

  group('the nav bar', () {
    List<String> tabIds(AppRole role) => [
      for (final t in tabsFor(role)) t.screenId,
    ];

    test('Events has no tab: it is a row on You and a card on Home', () {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.train: true,
        Feature.eat: true,
        Feature.progress: true,
        Feature.events: true,
        Feature.community: true,
      });
      expect(tabIds(AppRole.trainee), ['T01', 'R01', 'E02', 'E01', 'P01']);
    });

    test('with Events off the bar is the same', () {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.train: true,
        Feature.eat: true,
        Feature.progress: true,
      });
      expect(tabIds(AppRole.trainee), ['T01', 'R01', 'E02', 'E01', 'P01']);
    });

    test('a coach\'s bar is not touched', () {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.train: true,
        Feature.eat: true,
        Feature.events: true,
      });
      expect(tabIds(AppRole.coach), [
        for (final t in coachTabs)
          if (AppRouter.screenIsOn(t.screenId)) t.screenId,
      ]);
    });

    testWidgets('You lists Events when it is on, and opens it', (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.today: true,
        Feature.events: true,
      });
      var opened = false;
      await tester.pumpWidget(
        _host(
          YouView(
            summary: ProgressSummary.from(
              goal: const WeeklyGoal(sessionsTarget: 3),
              rewards: const Rewards(),
            ),
            activities: const SizedBox.shrink(),
            onOpenEvents: () => opened = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('you-events')));
      expect(opened, isTrue);
      expect(find.text('Events'), findsOneWidget);
    });

    test('the flag ships on', () {
      expect(FeatureFlags.shipped.isOn(Feature.events), isTrue);
    });
  });
}
