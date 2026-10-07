// The tour, on the real app, touches nothing.
//
// Every control on every stop is tapped, one at a time, on a fresh launch of
// `OwnHubApp`, the way the tap crawler does it. After each tap:
//
//   * the only routes above the tour are the join sheet, Rahma's first
//     recipe, or one of the tour's exits (her week, O03 or O05, or her
//     number, C06), and leaving the tour lands on the front door;
//   * nothing the app keeps about her has moved: Home is still day one, no
//     meal, no cycle, no week set up, no progress, the onboarding flags as
//     they were;
//   * the snapshot on the phone was never written;
//   * the only analytics are the screen views of the front door and the tour,
//     plus "sign-up started" when an exit starts it, and the tour's funnel:
//     which stop she reached and which Join she tapped, as two tokens and
//     nothing else;
//   * neither the verification backend nor the cloud transport was asked
//     anything.
//
// And `AppRouter.goTo`, called from inside the tour, opens the sheet and
// pushes nothing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/cloud_store.dart';
import 'package:own_hub/app_state/cloud_transport.dart';
import 'package:own_hub/app_state/demo_mode.dart';
import 'package:own_hub/app_state/local_persistence.dart';
import 'package:own_hub/app_state/onboarding_state.dart';
import 'package:own_hub/domain/analytics/analytics_gateway.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/features/eat/presentation/rahma_recipe_view.dart';
import 'package:own_hub/features/signup/data/verification_backend.dart';
import 'package:own_hub/features/signup/domain/server_verification.dart';
import 'package:own_hub/features/signup/presentation/demo/demo_stops.dart';
import 'package:own_hub/features/signup/presentation/look_around_view.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/ui/screen_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../qa/round1/round1_harness.dart' show wipe;

final FeatureFlags _launch = FeatureFlags.allOff.with_(<Feature, bool>{
  Feature.accountRequired: true,
  Feature.signUp: true,
  Feature.verification: true,
  Feature.today: true,
  Feature.train: true,
  Feature.eat: true,
  Feature.progress: true,
  Feature.cycle: true,
  Feature.privacyCentre: true,
});

class _Recording implements AnalyticsSink {
  final List<(String, Map<String, Object>)> sent =
      <(String, Map<String, Object>)>[];

  /// Everything but the tour's funnel, as (event, screen id).
  List<(String, Object?)> get events => [
    for (final (event, props) in sent)
      if (!event.startsWith('tour')) (event, props['screenId']),
  ];

  /// The tour's funnel, as (event, source, stop).
  List<(String, Object?, Object?)> get tour => [
    for (final (event, props) in sent)
      if (event.startsWith('tour'))
        (event, props['source'], props['tourStop']),
  ];

  @override
  Future<void> send(String event, Map<String, Object> props) async =>
      sent.add((event, Map.of(props)));
}

class _Storage implements SnapshotStorage {
  int writes = 0;
  int erasures = 0;

  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String snapshot) async => writes++;

  @override
  Future<void> erase() async => erasures++;
}

class _Backend extends VerificationBackend {
  int calls = 0;

  @override
  bool get isReady {
    calls++;
    return false;
  }

  @override
  String? get currentUid {
    calls++;
    return null;
  }

  @override
  Future<bool> verifiedClaim({bool forceRefresh = false}) async {
    calls++;
    return false;
  }

  @override
  Future<ServerVerification?> readStatus(String uid) async {
    calls++;
    return null;
  }

  @override
  Future<ServerVerification?> cachedStatus(String uid) async {
    calls++;
    return null;
  }

  @override
  Stream<ServerVerification?>? watchStatus(String uid) {
    calls++;
    return null;
  }

  @override
  Stream<Object?> tokenChanges() {
    calls++;
    return const Stream<Object?>.empty();
  }
}

class _Transport implements CloudTransport {
  int calls = 0;

  @override
  Future<List<CloudDoc>> pull(String uid) async {
    calls++;
    return const <CloudDoc>[];
  }

  @override
  Future<void> push(String uid, CloudDoc doc) async => calls++;
}

String _name(String id) => appRoutes[id]!.name;

/// The routes the router has built that are still in the navigator, top
/// last. The join sheet is not one of them; it is looked for on its own.
List<Route<dynamic>> _routes(WidgetTester t) {
  final out = <Route<dynamic>>[];
  for (final element
      in find.byType(ScreenScope, skipOffstage: false).evaluate()) {
    final route = ModalRoute.of(element);
    if (route != null && !out.contains(route)) out.add(route);
  }
  return out;
}

Future<void> _settle(WidgetTester t) async {
  try {
    await t.pumpAndSettle(
      const Duration(milliseconds: 50),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 3),
    );
  } catch (_) {}
}

/// The front door, then the tour, on stop [stop].
Future<void> _openTour(WidgetTester t, int stop) async {
  await t.pumpWidget(OwnHubApp(key: UniqueKey()));
  await _settle(t);
  t.state<NavigatorState>(find.byType(Navigator).first).pushNamed(_name('C04'));
  await _settle(t);
  for (var i = 0; i < stop; i++) {
    t.semantics.tap(find.semantics.byLabel('Next'));
    await _settle(t);
  }
}

String _labelOf(SemanticsNode n) {
  final d = n.getSemanticsData();
  return [
    d.label,
    d.tooltip,
    d.hint,
  ].where((s) => s.trim().isNotEmpty).join(' / ').replaceAll('\n', ' ');
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedAnalytics = AppRouter.analytics;
  final savedBackend = AppRouter.verificationBackend;
  late _Recording analytics;
  late _Storage storage;
  late _Backend backend;
  late _Transport transport;

  late RecipeBook book;

  setUpAll(() async {
    // Read once from disk, so the tour's own read of the seed is answered
    // from the cache rather than from an asset bundle this binary mocks.
    book = await SeededRecipeLibrary(
      readAsset: (path) async => File(path).readAsString(),
    ).load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    AppRouter.featureFlags = _launch;
    wipe();
    analytics = _Recording();
    AppRouter.analytics = AnalyticsGateway(analytics);
    backend = _Backend();
    AppRouter.verificationBackend = backend;
    transport = _Transport();
    CloudStore.instance.transport = transport;
    storage = _Storage();
    LocalPersistence.instance.storage = storage;
    LocalPersistence.instance.start();
    OnboardingState.instance
      ..beforeSignup = false
      ..shortSetupAfterSignup = false
      ..enteredFromSignup = false
      ..cycleRowDismissed = false;
  });

  tearDown(() {
    LocalPersistence.instance.reset();
    AppRouter.featureFlags = savedFlags;
    AppRouter.analytics = savedAnalytics;
    AppRouter.verificationBackend = savedBackend;
    AppRouter.awaitingReviewer = false;
    OnboardingState.instance.beforeSignup = false;
    wipe();
  });

  /// Nothing she has is any different.
  void expectNothingMoved({required bool joined}) {
    final day = AppRouter.todayRepository.day;
    expect(day.state, DayState.dayOne);
    expect(day.arc.hasAnyLog, isFalse);
    expect(day.week.sessionsLogged, 0);
    expect(AppRouter.mealRepository.store.days, isEmpty);
    expect(AppRouter.mealRepository.writes, isEmpty);
    expect(AppRouter.cycleRepository.current, isNull);
    expect(AppRouter.intakeRepository.setupDone, isFalse);
    expect(AppRouter.trainRepository.sessions, isEmpty);
    expect(AppRouter.trainRepository.flushes, isEmpty);
    expect(AppRouter.progressStore.weeks, isEmpty);
    expect(AppRouter.progressStore.rewards.points, 0);
    expect(AppRouter.progressStore.rewards.sessionsLogged, 0);
    expect(AppRouter.progressStore.goal.sessionsTarget, 3);
    expect(OnboardingState.instance.beforeSignup, joined);
    expect(OnboardingState.instance.shortSetupAfterSignup, isFalse);
    expect(OnboardingState.instance.enteredFromSignup, isFalse);
    expect(OnboardingState.instance.cycleRowDismissed, isFalse);
  }

  for (var stop = 0; stop <= DemoStop.values.length; stop++) {
    final where = stop < DemoStop.values.length
        ? DemoStop.values[stop].name
        : 'the end card';

    testWidgets('every control on $where', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();

      await _openTour(tester, stop);
      final count = find.semantics
          .byAction(SemanticsAction.tap)
          .evaluate()
          .length;
      expect(count, greaterThan(3), reason: 'the stop has controls');
      final outcomes = <String>[];

      for (var i = 0; i < count; i++) {
        wipe();
        OnboardingState.instance.beforeSignup = false;
        await _openTour(tester, stop);
        final nodes = find.semantics
            .byAction(SemanticsAction.tap)
            .evaluate()
            .toList();
        if (i >= nodes.length) break;
        final node = nodes[i];
        if (node.getSemanticsData().flagsCollection.isTextField) continue;
        final label = _labelOf(node);

        final tour = _routes(tester).last;
        expect(tour.settings.name, _name('C04'));
        final eventsBefore = analytics.events.length;
        final funnelBefore = analytics.tour.length;

        tester.semantics.tap(
          find.semantics.byPredicate((n) => n.id == node.id),
        );
        await tester.pump();
        await _settle(tester);
        // Past any undo window, so a write that was going to happen has.
        await tester.pump(const Duration(seconds: 6));
        await _settle(tester);
        expect(tester.takeException(), isNull, reason: label);

        final routes = _routes(tester);
        final top = routes.last.settings.name;
        final sheet = find.text('Join to make this yours').evaluate();
        final String outcome;
        if (!routes.contains(tour)) {
          expect(top, _name('C01'), reason: '$label left the tour');
          outcome = 'LEFT';
        } else if (top == _name('C04')) {
          outcome = sheet.isNotEmpty ? 'SHEET' : 'STAYED';
        } else if (top == null) {
          // The one page the tour pushes itself: Rahma's first recipe, read
          // only, still inside the tour.
          expect(find.byType(RahmaRecipeView), findsOneWidget, reason: label);
          expect(routes.indexOf(tour), routes.length - 2);
          outcome = 'RECIPE';
        } else {
          expect(
            {_name('O03'), _name('O05'), _name('C06')},
            contains(top),
            reason: '$label opened $top',
          );
          expect(routes.indexOf(tour), routes.length - 2);
          outcome = 'EXIT';
        }
        outcomes.add('$outcome\t$label');

        final joined = outcome == 'EXIT' && top != _name('C06');
        expectNothingMoved(joined: joined);

        final events = analytics.events.sublist(eventsBefore);
        if (outcome == 'EXIT') {
          final screen = routes.last.settings.name!
              .split('/')
              .last
              .toUpperCase();
          expect(events, [
            if (joined) ('signUpStarted', null),
            ('screenViewed', screen),
          ], reason: label);
        } else {
          expect(events, isEmpty, reason: '$label reported something');
        }

        // The funnel: a Join that starts sign-up is counted on the stop it
        // was tapped on, and moving the tour counts the stop it lands on.
        // Nothing else, and never anything but its two tokens.
        final funnel = analytics.tour.sublist(funnelBefore);
        final here = stop < DemoStop.values.length ? '${stop + 1}' : 'end';
        final joins = funnel.where((e) => e.$1 == 'tourJoinTapped').toList();
        if (joined) {
          expect(joins, hasLength(1), reason: label);
          expect(joins.single.$3, here, reason: label);
          expect(['bar', 'end'], contains(joins.single.$2), reason: label);
        } else {
          expect(joins, isEmpty, reason: '$label counted a join');
        }
        for (final (event, source, at) in funnel) {
          if (event == 'tourStopViewed') {
            expect(outcome, 'STAYED', reason: '$label moved and $outcome');
            expect(source, isNull, reason: label);
            expect(at, isNot(here), reason: label);
          }
        }
      }

      // Every control did one of the five things, and the stops' own
      // controls mostly raised the sheet.
      // ignore: avoid_print
      print('$where\n  ${outcomes.join('\n  ')}');
      if (stop < DemoStop.values.length) {
        expect(outcomes.where((o) => o.startsWith('SHEET')), isNotEmpty);
      }

      // Past the persistence delay: nothing was ever written to the phone.
      await tester.pump(LocalPersistence.writeDelay * 3);
      expect(storage.writes, 0);
      expect(backend.calls, 0);
      expect(transport.calls, 0);

      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 6));
    });
  }

  testWidgets('the only reports are the two screen views', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await _openTour(tester, DemoStop.values.length);
    expect(analytics.events, [
      ('screenViewed', 'C01'),
      ('screenViewed', 'C04'),
    ]);
    // And the funnel: the tour begun, every stop she walked through, then
    // the end card, which is also the tour completed.
    expect(analytics.tour, [
      ('tourStarted', null, null),
      for (var i = 1; i <= DemoStop.values.length; i++)
        ('tourStopViewed', null, '$i'),
      ('tourStopViewed', null, 'end'),
      ('tourCompleted', null, null),
    ]);
    for (final (_, props) in analytics.sent) {
      expect(
        props.keys.toSet().difference({'screenId', 'flow', 'tourStop'}),
        isEmpty,
      );
    }
    semantics.dispose();
  });

  testWidgets('a join from the sheet is counted with the stop it was on', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await _openTour(tester, 2);
    final before = analytics.tour.length;
    await tester.tap(find.text('Done · 12 reps'));
    await _settle(tester);
    expect(find.text('Join to make this yours'), findsOneWidget);
    await tester.tap(find.text('Join Own Hub').last);
    await _settle(tester);
    expect(analytics.tour.sublist(before), [('tourJoinTapped', 'sheet', '3')]);
    expect(analytics.events.last, ('screenViewed', 'O03'));
    semantics.dispose();
  });

  testWidgets('goTo inside the tour opens the sheet and pushes nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await _openTour(tester, 0);
    final before = _routes(tester);

    final inside = tester.element(find.byType(TodayView));
    expect(DemoScope.maybeOf(inside), isNotNull);
    for (final id in const ['T01', 'R03', 'E01', 'Y03', 'P01', 'A02']) {
      AppRouter.goTo(inside, id);
      await _settle(tester);
      expect(find.text('Join to make this yours'), findsOneWidget, reason: id);
      expect(_routes(tester), before, reason: id);
      Navigator.of(tester.element(find.text('Keep looking'))).pop();
      await _settle(tester);
    }

    // Outside the tour, goTo is what it always was.
    final outside = tester.element(find.byType(LookAroundView));
    expect(DemoScope.maybeOf(outside), isNull);
    AppRouter.goTo(outside, 'C06');
    await _settle(tester);
    expect(_routes(tester).last.settings.name, _name('C06'));
    semantics.dispose();
  });
  group('the exits, wherever the tour was opened from', () {
    testWidgets('as the first screen, leaving opens the front door', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _settle(tester);
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamedAndRemoveUntil(_name('C04'), (_) => false);
      await _settle(tester);
      expect(_routes(tester).map((r) => r.settings.name), [_name('C04')]);

      await tester.tap(find.byTooltip('Leave the tour'));
      await _settle(tester);
      expect(_routes(tester).map((r) => r.settings.name), [_name('C01')]);
    });

    testWidgets('C05, opened while she waits on her check, sends her back', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
      await _settle(tester);
      AppRouter.awaitingReviewer = true;
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushNamed(_name('C05'));
      await _settle(tester);

      expect(
        find.text('The app opens as soon as your check is done.'),
        findsOneWidget,
      );
      expect(find.text('Join Own Hub'), findsNothing);
      await tester.tap(find.text('Back to my check').last);
      await _settle(tester);
      expect(_routes(tester).map((r) => r.settings.name), [_name('C01')]);
      expect(OnboardingState.instance.beforeSignup, isFalse);
    });

    testWidgets('"Back to my check" on the recipe page leaves the tour too', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      AppRouter.awaitingReviewer = true;
      await _openTour(tester, DemoStop.recipes.index);
      final first = find.text(firstBookRecipe(book)!.titleEn);
      await tester.ensureVisible(first);
      await _settle(tester);
      await tester.tap(first);
      await _settle(tester);
      expect(find.byType(RahmaRecipeView), findsOneWidget);

      await tester.tap(find.text('Back to my check'));
      await _settle(tester);
      expect(find.byType(RahmaRecipeView), findsNothing);
      expect(find.byType(LookAroundView), findsNothing);
      expect(_routes(tester).map((r) => r.settings.name), [_name('C01')]);
      semantics.dispose();
    });
  });
}
