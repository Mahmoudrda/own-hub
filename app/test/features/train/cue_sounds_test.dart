// M3, M4 and M5: the sound beside what R07, R09 and R10 already draw and make
// felt. A set gets one pitch of five, the last three seconds of a rest get a
// gentle tick each and the end gets a chime, and the finish gets one phrase,
// the brighter one when she really beat a best. None of it needs motion, and
// none of it plays when she is not looking at the screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/sound.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
import 'package:own_hub/features/train/presentation/mid_set_view.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/fake_sound.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: child!,
  ),
  home: child,
);

DateTime Function() _clockStepping(Duration step) {
  var now = DateTime(2026, 10, 28, 9);
  return () => now = now.add(step);
}

final _move = PlannedMove(
  exerciseId: 'hip_thrust',
  name: 'Hip thrust',
  prescriptionLabel: '3 × 10 at 40 kg',
  sets: [
    for (var i = 1; i <= 3; i++)
      PrescribedSet(exerciseId: 'hip_thrust', order: i, weightKg: 40, reps: 10),
  ],
);

const _live = TrainSession(
  id: 'live-1',
  source: SessionSource.live,
  dateKey: '2026-10-28',
  sets: [],
  completed: true,
);

const _beaten = PersonalBest(
  exerciseId: 'goblet_squat',
  metric: BestMetric.load,
  dateKey: '2026-10-28',
  sessionId: 'live-1',
  loadKg: 12,
  reps: 8,
  previous: PreviousBest(loadKg: 10, reps: 8, dateKey: '2026-10-20'),
);

SessionSummary _summary({String id = 'live-1', bool best = false}) =>
    SessionSummary(
      sessionId: id,
      source: SessionSource.live,
      moves: 3,
      sets: 9,
      minutes: 20,
      credit: const CreditOutcome(sessionPoints: 30),
      newBests: best ? const [_beaten] : const [],
    );

void main() {
  late FakeSoundBackend backend;
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    backend = setUpFakeSound();
    AppSound.clock = _clockStepping(const Duration(seconds: 1));
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.train: true,
      Feature.finishReveal: true,
      Feature.warmFinish: true,
    });
  });
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    tearDownFakeSound();
  });

  group('R07: a set logged (M3)', () {
    Future<void> logSet(WidgetTester tester, int setIndex) async {
      await tester.pumpWidget(
        _host(MidSetView(move: _move, setIndex: setIndex)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · 40 kg × 10'));
      await tester.pump();
    }

    for (final index in [0, 1, 2]) {
      testWidgets('set ${index + 1} plays pitch ${index + 1}', (tester) async {
        await logSet(tester, index);
        expect(backend.names, ['set_done_${index + 1}']);
      });
    }

    testWidgets('the pitch starts again on the next move', (tester) async {
      await logSet(tester, 2);
      await logSet(tester, 0);
      expect(backend.names, ['set_done_3', 'set_done_1']);
    });

    testWidgets('it plays with Reduce Motion on', (tester) async {
      await tester.pumpWidget(
        _host(MidSetView(move: _move, setIndex: 0), reduceMotion: true),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done · 40 kg × 10'));
      await tester.pump();
      expect(backend.names, ['set_done_1']);
    });

    testWidgets('her switch off, and it is silent', (tester) async {
      AppSound.enabled = () => false;
      await logSet(tester, 0);
      expect(backend.played, isEmpty);
    });
  });

  group('R09: the rest (M4)', () {
    Future<void> seconds(WidgetTester tester, int n) async {
      for (var i = 0; i < n; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
    }

    testWidgets('three gentle ticks in the last three seconds, then a chime', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 6),
            total: Duration(seconds: 30),
          ),
        ),
      );
      await seconds(tester, 2);
      expect(backend.names, isEmpty, reason: 'nothing before the last three');
      await seconds(tester, 4);
      expect(backend.names, ['rest_tick', 'rest_tick', 'rest_tick', 'rest_end']);
    });

    testWidgets('a rest that ends plays the chime once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 1),
            total: Duration(seconds: 30),
          ),
        ),
      );
      await seconds(tester, 3);
      expect(backend.names, ['rest_end']);
    });

    testWidgets('the sounds do not need motion', (tester) async {
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 2),
            total: Duration(seconds: 30),
          ),
          reduceMotion: true,
        ),
      );
      await seconds(tester, 2);
      expect(backend.names, ['rest_tick', 'rest_end']);
    });

    testWidgets('a rest behind another screen stays quiet', (tester) async {
      await tester.pumpWidget(
        _host(
          const RestingView(
            remaining: Duration(seconds: 5),
            total: Duration(seconds: 30),
          ),
        ),
      );
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('over it')),
          ),
        ),
      );
      await tester.pump();
      await seconds(tester, 6);
      expect(backend.played, isEmpty);
    });

    testWidgets('coming back to a rest that ended while away is silent', (
      tester,
    ) async {
      var now = DateTime(2026, 10, 28, 9);
      await tester.pumpWidget(
        _host(
          RestingView(
            remaining: const Duration(seconds: 30),
            total: const Duration(seconds: 60),
            clock: () => now,
          ),
        ),
      );
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 2));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(backend.played, isEmpty, reason: 'the notification told her');
    });

    testWidgets('no sound when she taps "I\'m ready"', (tester) async {
      await tester.pumpWidget(
        _host(
          RestingView(
            remaining: const Duration(seconds: 30),
            total: const Duration(seconds: 60),
            onReady: () {},
          ),
        ),
      );
      await tester.tap(find.text("I'm ready, next set"));
      await tester.pump();
      expect(backend.played, isEmpty);
    });
  });

  group('R10: the finish (M5)', () {
    Future<void> finish(
      WidgetTester tester,
      SessionSummary summary, {
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(
        _host(
          FinishedView(session: _live, summary: summary),
          reduceMotion: reduceMotion,
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('one phrase for a session', (tester) async {
      await finish(tester, _summary());
      expect(backend.names, ['session_done']);
    });

    testWidgets('the brighter phrase for a real best, and only that one', (
      tester,
    ) async {
      await finish(tester, _summary(best: true));
      expect(backend.names, ['personal_best']);
    });

    testWidgets('with the closing-line switch off a best gets the plain phrase '
        '(the touch does the same)', (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.train: true,
        Feature.finishReveal: true,
      });
      await finish(tester, _summary(best: true));
      expect(backend.names, ['session_done']);
    });

    testWidgets('it plays with Reduce Motion on, once', (tester) async {
      await finish(tester, _summary(), reduceMotion: true);
      expect(backend.names, ['session_done']);
    });

    testWidgets('it plays with the reveal switched off, once', (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({Feature.train: true});
      await finish(tester, _summary());
      expect(backend.names, ['session_done']);
    });

    testWidgets('a redraw or a second visit to the same session is silent', (
      tester,
    ) async {
      await finish(tester, _summary());
      await tester.pumpWidget(
        _host(FinishedView(session: _live, summary: _summary())),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(backend.names, ['session_done']);
    });

    testWidgets('a different session plays its own', (tester) async {
      await finish(tester, _summary());
      await tester.pumpWidget(_host(const SizedBox()));
      await finish(tester, _summary(id: 'live-2'));
      expect(backend.names, ['session_done', 'session_done']);
    });

    testWidgets('nothing plays while the summary has not landed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const FinishedView(session: _live, awaitingSummary: true)),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(backend.played, isEmpty);
    });

    testWidgets('her switch off, and it is silent', (tester) async {
      AppSound.enabled = () => false;
      await finish(tester, _summary());
      expect(backend.played, isEmpty);
    });
  });
}
