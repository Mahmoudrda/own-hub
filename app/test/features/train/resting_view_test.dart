// R09 — Resting.
//
// Implements P0-LOG-01's second half and P0-LOG-02: the confirmation names the
// same numbers, undo sits inside it for five seconds, and undoing means nothing
// was ever written.
//
// The layout tests pass `autoStart: false` deliberately. A running clock
// schedules a frame every second, so `pumpAndSettle()` on one never settles —
// it pumps until it times out. Those tests assert a static frame; the countdown
// group below leaves the clock running and drives it with explicit pumps.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('names what was saved, the rest left, and what is next', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RestingView(
          autoStart: false,
          upNext: 'Goblet squat, set 3',
          upNextPrescription: '12 × 10',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Set 2 saved · 12 kg × 10'), findsOneWidget);
    expect(find.text('0:38'), findsOneWidget);
    expect(find.text('rest'), findsOneWidget);
    expect(find.textContaining('Catch your breath'), findsOneWidget);
    // The next set is stated before she needs it, so the next tap needs no
    // reading.
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Goblet squat, set 3'), findsOneWidget);
    expect(find.text('12 × 10'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with nothing given, it names no next set', (tester) async {
    // This assertion was made against `RestingView()` with no next set passed
    // in, because the card was two fixed strings — `gobletSquatSet3` and
    // `n1210`. So R09 named the prototype's move, set number and prescription
    // to every woman who rested, and the test called that "what is next".
    await tester.pumpWidget(_host(const RestingView(autoStart: false)));
    await tester.pumpAndSettle();

    expect(find.text('Up next'), findsNothing);
    expect(find.text('Goblet squat, set 3'), findsNothing);
    expect(find.text('12 × 10'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('the clock is a clock, not a picture of one', () {
    testWidgets('it counts down on its own', (tester) async {
      // The regression: this screen was a StatelessWidget holding a const
      // Duration(seconds: 38). It promised "the timer starts itself, ends
      // itself" in its own doc comment and never ticked once. Every test
      // passed, because they all asserted the painted value.
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 5),
            total: Duration(seconds: 60),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('0:05'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:04'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:02'), findsOneWidget);
    });

    testWidgets('a tick rebuilds the ring, not the rest of the screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 5),
            total: Duration(seconds: 60),
            upNext: 'Goblet squat, set 3',
          ),
        ),
      );
      await tester.pump();

      final rebuilt = <String>{};
      final before = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        rebuilt.add(element.widget.runtimeType.toString());
      };
      addTearDown(() => debugOnRebuildDirtyWidget = before);

      await tester.pump(const Duration(seconds: 1));
      debugOnRebuildDirtyWidget = before;

      expect(find.text('0:04'), findsOneWidget);
      expect(rebuilt, contains('AppRingStat'));
      expect(rebuilt, isNot(contains('RestingView')));
      expect(rebuilt, isNot(contains('AppCard')));
      expect(rebuilt, isNot(contains('AppScaffold')));
    });

    testWidgets('it ends itself, with no tap at all', (tester) async {
      // "Zero taps required" is the entire premise of R09. Rest that only ends
      // when she taps is not rest she can stop watching.
      var ready = 0;
      await tester.pumpWidget(
        _host(
          RestingView(
            remaining: const Duration(seconds: 2),
            total: const Duration(seconds: 60),
            onReady: () => ready++,
          ),
        ),
      );
      await tester.pump();

      await tester.pump(const Duration(seconds: 1));
      expect(ready, 0, reason: 'not over yet');

      await tester.pump(const Duration(seconds: 1));
      expect(ready, 1, reason: 'rest ended by itself');
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('it does not run past zero, or fire twice', (tester) async {
      var ready = 0;
      await tester.pumpWidget(
        _host(
          RestingView(
            remaining: const Duration(seconds: 1),
            total: const Duration(seconds: 60),
            onReady: () => ready++,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(ready, 1);

      await tester.pump(const Duration(seconds: 10));
      expect(ready, 1, reason: 'the clock stopped rather than going negative');
      expect(find.text('0:00'), findsOneWidget);
    });

    group('the clock does not follow her out of the screen', () {
      // R09 is pushed UNDER R07 rather than replaced by it, so tapping "I'm
      // ready" left this screen mounted with its clock still running. Up to
      // thirty-eight seconds later the clock reached zero and called `onReady`
      // anyway — which pushes the workout player over whatever she is doing
      // now. It was caught landing on the cycle check-in and in the middle of
      // `Y02`. `mounted` is true for a route that is merely buried, so the
      // guard is `ModalRoute.isCurrent`.

      Widget hostWithNavigator(Widget child, GlobalKey<NavigatorState> key) {
        return MaterialApp(
          navigatorKey: key,
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          theme: buildTheme(const Locale('en')),
          home: child,
        );
      }

      testWidgets('a rest that ends behind another screen navigates nowhere', (
        tester,
      ) async {
        var ready = 0;
        final navigator = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          hostWithNavigator(
            RestingView(
              remaining: const Duration(seconds: 3),
              total: const Duration(seconds: 60),
              onReady: () => ready++,
            ),
            navigator,
          ),
        );
        await tester.pump();

        // She moves on, and this screen is buried rather than disposed.
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Somewhere else')),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Somewhere else'), findsOneWidget);

        // The rest runs out underneath her.
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        expect(
          ready,
          0,
          reason:
              'rest ending behind her must never push a workout screen over '
              'what she is doing',
        );
        expect(find.text('Somewhere else'), findsOneWidget);
      });

      testWidgets('but it still ends itself while she is looking at it', (
        tester,
      ) async {
        var ready = 0;
        final navigator = GlobalKey<NavigatorState>();

        await tester.pumpWidget(
          hostWithNavigator(
            RestingView(
              remaining: const Duration(seconds: 1),
              total: const Duration(seconds: 60),
              onReady: () => ready++,
            ),
            navigator,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(ready, 1, reason: 'zero taps to log is the point of R09');
      });

      testWidgets('and the clock is cancelled when the screen is disposed', (
        tester,
      ) async {
        var ready = 0;
        await tester.pumpWidget(
          _host(
            RestingView(
              remaining: const Duration(seconds: 2),
              total: const Duration(seconds: 60),
              onReady: () => ready++,
            ),
          ),
        );
        await tester.pump();

        await tester.pumpWidget(_host(const SizedBox.shrink()));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(seconds: 1));
        }

        expect(ready, 0);
        // A live timer left behind fails the test binding at teardown, so
        // there is nothing further to assert here.
      });
    });

    testWidgets('a static preview does not tick', (tester) async {
      await tester.pumpWidget(
        _host(
          const RestingView(remaining: Duration(seconds: 30), autoStart: false),
        ),
      );
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('0:30'), findsOneWidget);
    });
  });

  group('add 30 seconds', () {
    testWidgets('adds thirty seconds', (tester) async {
      // It added nothing at all: the button bound to onAddThirtySeconds, which
      // the router never passes, so it rendered permanently disabled.
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 10),
            total: Duration(seconds: 60),
            autoStart: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0:10'), findsOneWidget);

      await tester.tap(find.byTooltip('Add 30 seconds'));
      await tester.pump();

      expect(find.text('0:40'), findsOneWidget);
    });

    testWidgets(
      'works with no callback supplied, as the router supplies none',
      (tester) async {
        await tester.pumpWidget(_host(const RestingView(autoStart: false)));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Add 30 seconds'));
        await tester.pump();

        expect(find.text('1:08'), findsOneWidget, reason: '0:38 plus thirty');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('still tells the caller she asked for longer', (tester) async {
      var asked = 0;
      await tester.pumpWidget(
        _host(RestingView(autoStart: false, onAddThirtySeconds: () => asked++)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Add 30 seconds'));
      await tester.pump();
      expect(asked, 1);
    });
  });

  testWidgets('zero taps are required to get through it', (tester) async {
    await tester.pumpWidget(_host(const RestingView(autoStart: false)));
    await tester.pumpAndSettle();

    // Both controls are offered, neither is needed — the timer ends itself.
    expect(find.text("I'm ready, next set"), findsOneWidget);
    expect(find.byTooltip('Add 30 seconds'), findsOneWidget);
  });

  testWidgets('P0-LOG-02 — undo inside the window writes nothing at all', (
    tester,
  ) async {
    final bus = LogCommandBus();
    final repository = InMemoryTrainRepository();
    var undone = 0;

    final handle = bus.submit(
      UndoableLog(
        describe: 'Set 2 saved · 12 kg × 10',
        commit: () => repository.flushMove(
          sessionId: 's',
          exerciseId: 'goblet_squat',
          sets: const [],
        ),
      ),
    );

    await tester.pumpWidget(
      _host(
        RestingView(handle: handle, onUndo: () => undone++, autoStart: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pump();

    expect(undone, 1);

    await tester.pump(const Duration(seconds: 10));
    expect(
      repository.flushes,
      isEmpty,
      reason:
          'the undo window sits ahead of the write, so an undone set '
          'never reaches the server even offline',
    );

    bus.dispose();
  });

  testWidgets('no dialog appears anywhere on this path', (tester) async {
    await tester.pumpWidget(_host(const RestingView(autoStart: false)));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('the rest clock is a value, in Western digits in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RestingView(remaining: Duration(seconds: 95), autoStart: false),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1:35'), findsOneWidget);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const RestingView(autoStart: false), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('اتحفظت المجموعة 2 · 12 كجم × 10'), findsOneWidget);
    expect(find.text('جاهزة، المجموعة اللي بعدها'), findsOneWidget);
    expect(find.byTooltip('ضيفي 30 ثانية'), findsOneWidget);
    expect(find.text("I'm ready, next set"), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const RestingView(autoStart: false),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  group('rest by deadline, and the alert while she is away (F504)', () {
    // The tester's fake time does not move DateTime.now, so the wall clock is
    // handed in and moved by hand.
    var wall = DateTime(2026, 10, 14, 10);
    final told = <DateTime>[];
    var cancelled = 0;
    var ready = 0;

    Future<void> open(
      WidgetTester tester, {
      Duration remaining = const Duration(seconds: 60),
      bool autoStart = true,
    }) async {
      wall = DateTime(2026, 10, 14, 10);
      told.clear();
      cancelled = 0;
      ready = 0;
      await tester.pumpWidget(
        _host(
          RestingView(
            remaining: remaining,
            total: const Duration(seconds: 60),
            autoStart: autoStart,
            clock: () => wall,
            onBackgrounded: told.add,
            onAlertCancel: () => cancelled++,
            onReady: () => ready++,
          ),
        ),
      );
      await tester.pump();
    }

    void state(WidgetTester tester, AppLifecycleState s) =>
        tester.binding.handleAppLifecycleStateChanged(s);

    testWidgets('going to the background says when the rest ends', (
      tester,
    ) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      state(tester, AppLifecycleState.paused);
      expect(told, [wall.add(const Duration(seconds: 50))]);
    });

    testWidgets('coming back counts from the deadline, not from the ticks', (
      tester,
    ) async {
      await open(tester);
      await tester.pump(const Duration(seconds: 10));
      state(tester, AppLifecycleState.paused);
      // The phone slept: no ticks arrive, twenty seconds of the wall pass.
      wall = wall.add(const Duration(seconds: 20));
      state(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('0:30'), findsOneWidget);
      expect(cancelled, 1);
      expect(ready, 0);
      // And it goes on counting.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('0:29'), findsOneWidget);
    });

    testWidgets('a rest that ended while she was away ends itself', (
      tester,
    ) async {
      await open(tester);
      state(tester, AppLifecycleState.paused);
      wall = wall.add(const Duration(seconds: 90));
      state(tester, AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('0:00'), findsOneWidget);
      expect(ready, 1);
      expect(cancelled, 1);
    });

    testWidgets('hidden then paused tells it once', (tester) async {
      await open(tester);
      state(tester, AppLifecycleState.hidden);
      state(tester, AppLifecycleState.paused);
      expect(told, hasLength(1));
    });

    testWidgets('a rest she held is not announced', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.pause));
      await tester.pump();
      state(tester, AppLifecycleState.paused);
      expect(told, isEmpty);
    });

    testWidgets('a rest she tapped past is not announced', (tester) async {
      await open(tester);
      await tester.tap(find.text("I'm ready, next set"));
      await tester.pump();
      expect(ready, 1);
      expect(cancelled, 1);
      state(tester, AppLifecycleState.paused);
      expect(told, isEmpty);
    });

    testWidgets('asking for thirty more cancels what was left', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('Add 30 seconds'));
      await tester.pump();
      expect(cancelled, 1);
      state(tester, AppLifecycleState.paused);
      expect(told, [wall.add(const Duration(seconds: 90))]);
    });

    testWidgets('leaving the screen cancels it', (tester) async {
      await open(tester);
      state(tester, AppLifecycleState.paused);
      await tester.pumpWidget(const SizedBox());
      expect(cancelled, greaterThanOrEqualTo(1));
    });

    testWidgets('a rest with no clock running is not announced', (
      tester,
    ) async {
      await open(tester, autoStart: false);
      state(tester, AppLifecycleState.paused);
      expect(told, isEmpty);
    });
  });
}
