// What a member sees of events, and that she sees none of it while the owner
// has Feature.events switched off.
//
//   * T09 lists published events in Cairo time, in her language, with an
//     honest empty state, and sends nothing about her on opening;
//   * Home's Upcoming card is drawn only with the flag on AND an event to come;
//   * with the flag off, T09 is FeatureOff, the card is absent and nothing is
//     read from the server;
//   * the server may switch events and only events (RemoteFeatures).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:own_hub/app_state/events_state.dart';
import 'package:own_hub/app_state/remote_features.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/events/domain/event_repository.dart';
import 'package:own_hub/features/events/domain/hub_event.dart';
import 'package:own_hub/features/events/presentation/events_view.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  ),
);

HubEvent _online({
  String id = 'e1',
  EventStatus status = EventStatus.published,
}) => HubEvent(
  id: id,
  titleEn: 'Morning stretch, together',
  titleAr: 'tamaddud',
  descriptionEn: 'Thirty quiet minutes on the floor.',
  descriptionAr: 'wasf',
  // Thursday 5 November 2026, 18:30 to 19:30 in Cairo (UTC+2).
  startsAt: DateTime.utc(2026, 11, 5, 16, 30),
  endsAt: DateTime.utc(2026, 11, 5, 17, 30),
  mode: EventMode.online,
  link: 'https://meet.example.com/stretch',
  status: status,
);

HubEvent _inPerson() => HubEvent(
  id: 'e2',
  titleEn: 'Walk by the Nile',
  titleAr: 'mashy',
  startsAt: DateTime.utc(2026, 11, 7, 6),
  endsAt: DateTime.utc(2026, 11, 7, 7),
  mode: EventMode.place,
  placeName: 'Zamalek ladies gym',
  capacity: 20,
  status: EventStatus.published,
);

TodayView _today({HubEvent? next, VoidCallback? onOpenEvents}) => TodayView(
  repository: InMemoryTodayRepository(
    day: InMemoryTodayRepository.defaultDay(date: _tuesday),
  ),
  now: _tuesday,
  onStartSession: () {},
  onRecall: () {},
  onOpenMeal: () {},
  onOpenPlate: () {},
  onOpenWeek: () {},
  onOpenCycle: () {},
  onAsk: () {},
  onNotifications: () {},
  onSelectTab: (_) {},
  nextEvent: next,
  onOpenEvents: onOpenEvents ?? () {},
);

class _CountingReader implements EventReader {
  _CountingReader(this.events);
  final List<HubEvent> events;
  int reads = 0;
  final List<bool> cacheFirstAsked = <bool>[];

  @override
  Future<List<HubEvent>> upcoming(
    DateTime now, {
    int limit = 20,
    bool cacheFirst = false,
  }) async {
    reads++;
    cacheFirstAsked.add(cacheFirst);
    return upcomingOf(events, now);
  }
}

class _FakeSwitches implements FeatureSwitchStore {
  _FakeSwitches(this.data);
  final Map<String, Object?> data;
  final List<(String, bool)> writes = [];

  @override
  Future<Map<String, Object?>?> read() async => data;

  @override
  Future<void> write(String key, bool on) async => writes.add((key, on));
}

void main() {
  final shipped = AppRouter.featureFlags;
  final off = FeatureFlags.shipped.with_({Feature.events: false});
  setUp(() {
    AppRouter.featureFlags = off;
    EventsState.instance.reset();
  });
  tearDown(() {
    AppRouter.featureFlags = shipped;
    EventsState.instance.reset();
    RemoteFeatures.store = () => null;
    AppRouter.lastVerification = null;
  });

  group('T09, the Events screen', () {
    testWidgets('an event, in Cairo time, with its link', (tester) async {
      _phone(tester);
      final opened = <String>[];
      await tester.pumpWidget(
        _host(
          EventsView(events: [_online(), _inPerson()], onOpenLink: opened.add),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Upcoming events'), findsOneWidget);
      expect(find.text('Morning stretch, together'), findsOneWidget);
      expect(
        find.text('Thursday · 2026-11-05 · 18:30 to 19:30 · Cairo time'),
        findsOneWidget,
      );
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Zamalek ladies gym'), findsOneWidget);
      expect(find.text('Thirty quiet minutes on the floor.'), findsOneWidget);

      await tester.tap(find.text('Open event link'));
      expect(opened, ['https://meet.example.com/stretch']);
    });

    testWidgets('nothing planned is said plainly', (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(const EventsView()));
      await tester.pumpAndSettle();
      expect(find.text('No events coming up'), findsOneWidget);
      expect(
        find.text('When Own Hub plans one, you will find it here.'),
        findsOneWidget,
      );
    });

    testWidgets('in Arabic it reads right to left, in her language', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(EventsView(events: [_online()]), locale: const Locale('ar')),
      );
      await tester.pumpAndSettle();
      expect(find.text('tamaddud'), findsOneWidget);
      expect(find.text('wasf'), findsOneWidget);
      final direction = tester.widget<Directionality>(
        find
            .ancestor(
              of: find.text('tamaddud'),
              matching: find.byType(Directionality),
            )
            .first,
      );
      expect(direction.textDirection, TextDirection.rtl);
      // Western digits in both languages.
      expect(find.textContaining('2026-11-05'), findsOneWidget);
    });

    testWidgets('large text does not overflow', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(EventsView(events: [_online(), _inPerson()]), textScale: 2.0),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the screen collects nothing: no field, no switch', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(EventsView(events: [_online()])));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });
  });

  group('the flag', () {
    test('ships on', () {
      expect(FeatureFlags.shipped.isOn(Feature.events), isTrue);
      expect(AppRouter.screenFeatures['T09'], Feature.events);
    });

    testWidgets('off: Home draws no Upcoming card, even with an event', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(_today(next: _online())));
      await tester.pumpAndSettle();
      expect(find.textContaining('Upcoming events'), findsNothing);
    });

    testWidgets('on: the card names the next event and opens T09', (
      tester,
    ) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.shipped;
      var opened = 0;
      await tester.pumpWidget(
        _host(_today(next: _online(), onOpenEvents: () => opened++)),
      );
      await tester.pumpAndSettle();
      final card = find.text('Upcoming events · Morning stretch, together');
      await tester.scrollUntilVisible(card, 200);
      expect(card, findsOneWidget);
      await tester.tap(card);
      expect(opened, 1);
    });

    testWidgets('on, with nothing planned: no card at all', (tester) async {
      _phone(tester);
      AppRouter.featureFlags = FeatureFlags.shipped;
      await tester.pumpWidget(_host(_today()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Upcoming events'), findsNothing);
    });

    testWidgets('off: T09 is switched off even by name', (tester) async {
      _phone(tester);
      AppRouter.lastVerification = VerificationResult(
        method: VerificationMethod.automatic,
        decidedAt: DateTime(2026, 10, 2),
        imagesDeletedAt: DateTime(2026, 10, 2),
      );
      final route = AppRouter.onGenerateRoute(
        RouteSettings(name: appRoutes['T09']!.name),
      )!;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          onGenerateRoute: (_) => route,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FeatureOff), findsOneWidget);
    });

    test('off: nothing is read from the server', () async {
      final reader = _CountingReader([_online()]);
      EventsState.instance.source = () => reader;
      await EventsState.instance.refresh(force: true);
      expect(reader.reads, 0);
      expect(EventsState.instance.upcoming, isEmpty);
    });

    test('on: read once, then not again within the hour', () async {
      AppRouter.featureFlags = FeatureFlags.shipped;
      final reader = _CountingReader([_online()]);
      var now = DateTime.utc(2026, 11, 1, 10);
      EventsState.instance.source = () => reader;
      EventsState.instance.now = () => now;
      await EventsState.instance.refresh();
      await EventsState.instance.refresh();
      expect(reader.reads, 1);
      expect([for (final e in EventsState.instance.upcoming) e.id], ['e1']);
      now = now.add(const Duration(hours: 2));
      await EventsState.instance.refresh();
      expect(reader.reads, 2);
    });

    group('across cold starts', () {
      final now = DateTime.utc(2026, 11, 1, 10);

      Future<String?> storedReadAt() async =>
          (await SharedPreferences.getInstance()).getString(kEventsReadAtKey);

      setUp(() {
        TestWidgetsFlutterBinding.ensureInitialized();
        AppRouter.featureFlags = FeatureFlags.shipped;
      });

      test('a first launch reads the server and keeps the time', () async {
        SharedPreferences.setMockInitialValues({});
        final reader = _CountingReader([_online()]);
        EventsState.instance.source = () => reader;
        EventsState.instance.now = () => now;
        await EventsState.instance.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(reader.cacheFirstAsked, [false]);
        expect(await storedReadAt(), now.toIso8601String());
      });

      test('a launch inside the hour reads the phone copy first', () async {
        final before = now.subtract(const Duration(minutes: 20));
        SharedPreferences.setMockInitialValues({
          kEventsReadAtKey: before.toIso8601String(),
        });
        final reader = _CountingReader([_online()]);
        EventsState.instance.source = () => reader;
        EventsState.instance.now = () => now;
        await EventsState.instance.refresh();
        await Future<void>.delayed(Duration.zero);
        expect(reader.cacheFirstAsked, [true]);
        expect([for (final e in EventsState.instance.upcoming) e.id], ['e1']);
        // The server time is not moved by a read from the phone.
        expect(await storedReadAt(), before.toIso8601String());
        // Still inside the hour from that read: nothing more is asked.
        await EventsState.instance.refresh();
        expect(reader.reads, 1);
      });

      test(
        'after the hour, or with a forced read, the server answers',
        () async {
          SharedPreferences.setMockInitialValues({
            kEventsReadAtKey: now
                .subtract(const Duration(minutes: 61))
                .toIso8601String(),
          });
          final reader = _CountingReader([_online()]);
          EventsState.instance.source = () => reader;
          EventsState.instance.now = () => now;
          await EventsState.instance.refresh();
          expect(reader.cacheFirstAsked, [false]);
          EventsState.instance.erase();
          await Future<void>.delayed(Duration.zero);
          SharedPreferences.setMockInitialValues({
            kEventsReadAtKey: now
                .subtract(const Duration(minutes: 5))
                .toIso8601String(),
          });
          await EventsState.instance.refresh(force: true);
          expect(reader.cacheFirstAsked, [false, false]);
        },
      );

      test('a stored time in the future is not trusted', () async {
        SharedPreferences.setMockInitialValues({
          kEventsReadAtKey: now.add(const Duration(days: 3)).toIso8601String(),
        });
        final reader = _CountingReader([_online()]);
        EventsState.instance.source = () => reader;
        EventsState.instance.now = () => now;
        await EventsState.instance.refresh();
        expect(reader.cacheFirstAsked, [false]);
      });

      test('erase forgets the stored time', () async {
        SharedPreferences.setMockInitialValues({
          kEventsReadAtKey: now.toIso8601String(),
        });
        EventsState.instance.erase();
        await Future<void>.delayed(Duration.zero);
        expect(await storedReadAt(), isNull);
      });
    });

    test('switched off again: the list empties', () async {
      AppRouter.featureFlags = FeatureFlags.shipped;
      EventsState.instance.seed([_online()]);
      AppRouter.featureFlags = off;
      await EventsState.instance.refresh(force: true);
      expect(EventsState.instance.upcoming, isEmpty);
    });
  });

  group('the server switch', () {
    test('events are the only thing the server can switch on', () {
      expect(Feature.events.serverMayTurnOn, isTrue);
      expect(
        [
          for (final f in Feature.values)
            if (f.serverMayTurnOn) f,
        ],
        [Feature.events],
      );
    });

    test('a verified woman takes the owner\'s answer for events, and nothing '
        'switches on the community or off the gate', () async {
      AppRouter.lastVerification = VerificationResult(
        method: VerificationMethod.automatic,
        decidedAt: DateTime(2026, 10, 2),
        imagesDeletedAt: DateTime(2026, 10, 2),
      );
      final store = _FakeSwitches({
        'events': true,
        // Anything else in the document is ignored.
        'community': true,
        'accountRequired': false,
      });
      RemoteFeatures.store = () => store;
      await RemoteFeatures.load();
      expect(AppRouter.featureFlags.isOn(Feature.events), isTrue);
      expect(AppRouter.featureFlags.isOn(Feature.community), isFalse);
      expect(AppRouter.featureFlags.isOn(Feature.accountRequired), isTrue);
    });

    test('nothing is read before she is verified', () async {
      final store = _FakeSwitches({'events': true});
      RemoteFeatures.store = () => store;
      await RemoteFeatures.load();
      expect(AppRouter.featureFlags.isOn(Feature.events), isFalse);
    });

    test(
      'Z14 publishes events, and refuses what the server cannot move',
      () async {
        final store = _FakeSwitches({});
        RemoteFeatures.store = () => store;
        expect(await RemoteFeatures.publish(Feature.events, true), isTrue);
        expect(
          await RemoteFeatures.publish(Feature.accountRequired, false),
          isFalse,
        );
        expect(
          await RemoteFeatures.publish(Feature.verification, false),
          isFalse,
        );
        expect(store.writes, [('events', true)]);
      },
    );
  });
}
