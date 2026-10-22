// Ending a workout from inside it: the sheet's three outcomes, the control on
// each live screen, and the back button sending her to the same sheet once a
// set is logged.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/end_workout_sheet.dart';
import 'package:own_hub/features/train/presentation/follow_along_view.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/move_logged_view.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget home, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

class _Calls {
  int finished = 0;
  int discarded = 0;

  SessionEnd end(int sets) => SessionEnd(
    setsLogged: sets,
    onFinish: () => finished++,
    onDiscard: () => discarded++,
  );
}

const _end = ValueKey('session-end');

PlannedMove _move() => PlannedMove(
  exerciseId: 'donkey_kick',
  name: 'Donkey kick',
  prescriptionLabel: '3 × 12 · bodyweight',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: 'donkey_kick', order: i, reps: 12),
  ],
);

void main() {
  group('the sheet', () {
    testWidgets('Finish and save names the sets saved and finishes', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _host(Scaffold(body: SessionEndButton(end: calls.end(4)))),
      );
      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();

      expect(find.text('Sets saved so far: 4'), findsOneWidget);
      expect(find.text('Finish and save'), findsOneWidget);
      expect(find.text('Discard this workout'), findsOneWidget);
      expect(find.text('Keep going'), findsOneWidget);

      await tester.tap(find.text('Finish and save'));
      await tester.pumpAndSettle();
      expect(calls.finished, 1);
      expect(calls.discarded, 0);
      expect(find.text('Keep going'), findsNothing);
    });

    testWidgets('Discard discards and Keep going does neither', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _host(Scaffold(body: SessionEndButton(end: calls.end(2)))),
      );
      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(calls.finished + calls.discarded, 0);

      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Discard this workout'));
      await tester.pumpAndSettle();
      expect(calls.discarded, 1);
      expect(calls.finished, 0);
    });

    testWidgets('with nothing logged only Discard and Keep going are offered', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _host(Scaffold(body: SessionEndButton(end: calls.end(0)))),
      );
      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();

      expect(find.text('Finish and save'), findsNothing);
      expect(find.byKey(const ValueKey('end-finish')), findsNothing);
      expect(find.text('Discard this workout'), findsOneWidget);
      expect(find.text('Keep going'), findsOneWidget);
      expect(find.textContaining('Nothing is logged yet'), findsOneWidget);
    });

    testWidgets('dismissing the sheet changes nothing', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _host(Scaffold(body: SessionEndButton(end: calls.end(3)))),
      );
      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Keep going'), findsNothing);
      expect(calls.finished + calls.discarded, 0);
    });

    testWidgets('the control is a 48 px target and reads in Arabic', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          Scaffold(body: SessionEndButton(end: _Calls().end(1))),
          locale: const Locale('ar'),
        ),
      );
      final size = tester.getSize(find.byKey(_end));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(find.text('إنهاء التمرين'), findsOneWidget);

      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();
      expect(find.text('خلّصي واحفظي'), findsOneWidget);
      expect(find.text('كمّلي'), findsOneWidget);
    });
  });

  group('the control on each live screen', () {
    final calls = _Calls();

    testWidgets('R07, R09, R13 and R06 show it when given one', (tester) async {
      final end = calls.end(1);
      final screens = <Widget>[
        MidSetView(move: _move(), end: end),
        RestingView(end: end, autoStart: false),
        MoveLoggedView(end: end),
        FollowAlongView(end: end),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(_host(screen));
        await tester.pump();
        expect(
          find.byKey(_end),
          findsOneWidget,
          reason: screen.runtimeType.toString(),
        );
        expect(find.text('End workout'), findsOneWidget);
      }
    });

    testWidgets('none of them shows it with no workout live', (tester) async {
      final screens = <Widget>[
        MidSetView(move: _move()),
        const RestingView(autoStart: false),
        const MoveLoggedView(),
        const FollowAlongView(),
      ];
      for (final screen in screens) {
        await tester.pumpWidget(_host(screen));
        await tester.pump();
        expect(
          find.byKey(_end),
          findsNothing,
          reason: screen.runtimeType.toString(),
        );
      }
    });

    testWidgets('at the largest text size the bar does not overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      for (final locale in const [Locale('en'), Locale('ar')]) {
        final screens = <Widget>[
          MidSetView(
            move: _move(),
            moveNumber: 1,
            moveCount: 5,
            onPause: () {},
            end: calls.end(1),
          ),
          RestingView(
            moveNumber: 1,
            moveCount: 5,
            autoStart: false,
            end: calls.end(1),
          ),
          MoveLoggedView(onPause: () {}, end: calls.end(1)),
        ];
        for (final screen in screens) {
          await tester.pumpWidget(_host(screen, locale: locale, scale: 2));
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason: '${screen.runtimeType} ${locale.languageCode}',
          );
          expect(find.byKey(_end), findsOneWidget);
        }
      }
    });
  });

  group('back and close', () {
    Widget app(SessionEnd? end) => _host(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => SessionEndFrame(
                    end: end,
                    child: Scaffold(
                      body: Center(
                        child: TextButton(
                          key: const ValueKey('x'),
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('the workout'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    testWidgets('with a set logged, back opens the sheet and stays', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(app(calls.end(2)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('the workout'), findsOneWidget);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('the workout'), findsOneWidget);
      expect(find.text('Finish and save'), findsOneWidget);

      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(find.text('the workout'), findsOneWidget);
    });

    testWidgets('with nothing logged, back leaves as it always did', (
      tester,
    ) async {
      await tester.pumpWidget(app(_Calls().end(0)));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('the workout'), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('with no workout live, back leaves', (tester) async {
      await tester.pumpWidget(app(null));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('the workout'), findsNothing);
    });

    testWidgets('the overlay draws the control and Finish reaches the caller', (
      tester,
    ) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _host(
          SessionEndFrame(
            end: calls.end(3),
            overlay: true,
            child: const Scaffold(body: SizedBox.expand()),
          ),
        ),
      );
      expect(find.byKey(_end), findsOneWidget);
      await tester.tap(find.byKey(_end));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish and save'));
      await tester.pumpAndSettle();
      expect(calls.finished, 1);
    });

    testWidgets('a side trip with guardPop off leaves freely', (tester) async {
      final calls = _Calls();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SessionEndFrame(
                      end: calls.end(3),
                      guardPop: false,
                      child: const Scaffold(body: Text('the swap')),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      await nav.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Finish and save'), findsNothing);
      expect(find.text('the swap'), findsNothing);
    });

    testWidgets('the frame says it holds Back once a set is logged', (
      tester,
    ) async {
      bool? seen;
      Widget probe() => Builder(
        builder: (context) {
          seen = SessionEndGuard.holdingBack(context);
          return const Scaffold(body: SizedBox.expand());
        },
      );
      final calls = _Calls();
      await tester.pumpWidget(
        _host(SessionEndFrame(end: calls.end(0), child: probe())),
      );
      expect(seen, isFalse);
      await tester.pumpWidget(
        _host(SessionEndFrame(end: calls.end(2), child: probe())),
      );
      expect(seen, isTrue);
      await tester.pumpWidget(
        _host(
          SessionEndFrame(end: calls.end(2), guardPop: false, child: probe()),
        ),
      );
      expect(seen, isFalse);
    });
  });
}
