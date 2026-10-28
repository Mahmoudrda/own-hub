// Rewards without the mascot (release plan 3.4): one touch on R10 that is
// heavier only when she really beat a best, one heavy touch on R09 for the set
// that beat it, and one warm closing line chosen from a small bank.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/features/train/domain/live_best.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
import 'package:own_hub/features/train/presentation/resting_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

const _heavy = 'HapticFeedbackType.heavyImpact';
const _medium = 'HapticFeedbackType.mediumImpact';

Widget _host(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: child,
);

const _live = TrainSession(
  id: 'live-1',
  source: SessionSource.live,
  dateKey: '2026-10-28',
  sets: [],
  completed: true,
);

const _before = PreviousBest(loadKg: 10, reps: 8, dateKey: '2026-10-20');

const _beaten = PersonalBest(
  exerciseId: 'goblet_squat',
  metric: BestMetric.load,
  dateKey: '2026-10-28',
  sessionId: 'live-1',
  loadKg: 12,
  reps: 8,
  previous: _before,
);

const _plain = SessionSummary(
  sessionId: 'live-1',
  source: SessionSource.live,
  moves: 3,
  sets: 9,
  minutes: 20,
  credit: CreditOutcome(sessionPoints: 30),
);

const _withBest = SessionSummary(
  sessionId: 'live-1',
  source: SessionSource.live,
  moves: 3,
  sets: 9,
  minutes: 20,
  credit: CreditOutcome(sessionPoints: 30),
  newBests: [_beaten],
);

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedHaptics = AppHaptics.enabled;
  late List<String?> felt;

  void flags({bool warm = true}) =>
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.train: true,
        Feature.finishReveal: true,
        Feature.haptics: true,
        Feature.warmFinish: warm,
      });

  setUp(() {
    felt = <String?>[];
    flags();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            felt.add(call.arguments as String?);
          }
          return null;
        });
  });
  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppHaptics.enabled = savedHaptics;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> finish(WidgetTester tester, SessionSummary summary) async {
    await tester.pumpWidget(
      _host(FinishedView(session: _live, summary: summary)),
    );
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('R10', () {
    testWidgets('one heavy touch, and no other, when she beat a best', (
      tester,
    ) async {
      await finish(tester, _withBest);
      expect(felt, [_heavy]);
    });

    testWidgets('one medium touch when she did not', (tester) async {
      await finish(tester, _plain);
      expect(felt, [_medium]);
    });

    testWidgets('with the switch off a best still gets the medium touch', (
      tester,
    ) async {
      flags(warm: false);
      await finish(tester, _withBest);
      expect(felt, [_medium]);
    });

    testWidgets('a recalled session has no best and no heavy touch', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const FinishedView(
            session: TrainSession(
              id: 'r-1',
              source: SessionSource.recalled,
              dateKey: '2026-10-28',
              sets: [],
              completed: true,
            ),
            summary: _withBest,
          ),
        ),
      );
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(felt, isNot(contains(_heavy)));
    });

    testWidgets('ends on one warm line from the bank, the same on a redraw', (
      tester,
    ) async {
      await finish(tester, _plain);
      final l10n = AppL10n.of(tester.element(find.byType(FinishedView)));
      final line = find.byKey(const ValueKey('r10-kitten-caption'));
      expect(line, findsOneWidget);
      final shown = (tester.widget<Text>(line)).data;
      expect(shown, closingLineFor(l10n, 'live-1'));
      await tester.pumpWidget(
        _host(FinishedView(session: _live, summary: _plain)),
      );
      await tester.pump();
      expect((tester.widget<Text>(line)).data, shown);
    });
  });

  group('the closing line', () {
    testWidgets('is picked by the session, uses the whole bank, and has no '
        'figure, in both languages', (tester) async {
      for (final locale in const [Locale('en'), Locale('ar')]) {
        late AppL10n l10n;
        await tester.pumpWidget(
          _host(
            Builder(
              builder: (context) {
                l10n = AppL10n.of(context);
                return const SizedBox();
              },
            ),
            locale: locale,
          ),
        );
        final lines = {
          for (var i = 0; i < 40; i++) closingLineFor(l10n, 'session-$i'),
        };
        expect(lines.length, 5, reason: locale.languageCode);
        expect(closingLineFor(l10n, null), l10n.gladYouShowedUpToday);
        for (final line in lines) {
          expect(line, isNot(contains(RegExp(r'\d'))));
          expect(line, isNot(contains('—')));
        }
      }
    });
  });

  group('R09', () {
    Future<void> rest(WidgetTester tester, {LiveBest? best}) async {
      await tester.pumpWidget(
        _host(
          RestingView(
            remaining: const Duration(seconds: 30),
            total: const Duration(seconds: 60),
            liveBest: best,
          ),
        ),
      );
      await tester.pump();
    }

    const best = LiveBest(
      exerciseId: 'goblet_squat',
      kind: LiveBestKind.heavier,
      loadKg: 12,
    );

    testWidgets('one heavy touch for a best, not repeated by a redraw', (
      tester,
    ) async {
      await rest(tester, best: best);
      expect(felt, [_heavy]);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(felt, [_heavy]);
    });

    testWidgets('a best that lands after the page opened still gets its touch '
        'once', (tester) async {
      Future<void> redraw(LiveBest? shown) async {
        await tester.pumpWidget(
          _host(
            RestingView(
              remaining: const Duration(seconds: 30),
              total: const Duration(seconds: 60),
              liveBest: shown,
            ),
          ),
        );
        await tester.pump();
      }

      await redraw(null);
      expect(felt, isEmpty);
      // The set's undo window closes and the write lands: the chip appears.
      await redraw(best);
      expect(felt, [_heavy]);
      await redraw(best);
      await redraw(best);
      expect(felt, [_heavy]);
    });

    testWidgets('nothing for a set that beat nothing', (tester) async {
      await rest(tester);
      expect(felt, isEmpty);
    });

    testWidgets('nothing with the switch off', (tester) async {
      flags(warm: false);
      await rest(tester, best: best);
      expect(felt, isEmpty);
    });

    testWidgets('nothing when haptics are off', (tester) async {
      AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.train: true,
        Feature.warmFinish: true,
      });
      await rest(tester, best: best);
      expect(felt, isEmpty);
    });
  });
}
