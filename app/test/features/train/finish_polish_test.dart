// Design items on R10: the finish wipe and the count-in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/rewards/training_streak.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_week_segments.dart';
import 'package:own_hub/ui/hand/hand.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  bool still = false,
  bool bare = false,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: still),
    child: bare ? child : Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

const _live = TrainSession(
  id: 'live-1',
  source: SessionSource.live,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

const _recalled = TrainSession(
  id: 'recalled-1',
  source: SessionSource.recalled,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

const _summary = SessionSummary(
  sessionId: 'live-9',
  source: SessionSource.live,
  moves: 3,
  sets: 9,
  minutes: 20,
  credit: CreditOutcome(sessionPoints: 30),
);

void main() {
  final saved = AppRouter.featureFlags;
  tearDown(() => AppRouter.featureFlags = saved);

  group('finish wipe', () {
    Widget view({bool still = false}) => _host(
      const FinishedView(session: _live, summary: _summary),
      still: still,
      bare: true,
    );
    setUp(
      () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.train: true,
        Feature.finishReveal: true,
      }),
    );
    final wipe = find.byKey(const ValueKey('finish-wipe'));

    testWidgets('shows, then reveals, within 600 ms', (tester) async {
      await tester.pumpWidget(view());
      await tester.pump();
      expect(wipe, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(wipe, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 300));
      expect(wipe, findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('a tap skips it', (tester) async {
      await tester.pumpWidget(view());
      await tester.pump(const Duration(milliseconds: 50));
      expect(wipe, findsOneWidget);
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      expect(wipe, findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('is absent under Reduce Motion', (tester) async {
      await tester.pumpWidget(view(still: true));
      await tester.pump();
      expect(wipe, findsNothing);
    });

    testWidgets('is absent for a recalled session', (tester) async {
      await tester.pumpWidget(
        _host(
          const FinishedView(session: _recalled, summary: _summary),
          bare: true,
        ),
      );
      await tester.pump();
      expect(wipe, findsNothing);
      await tester.pumpAndSettle();
    });
  });

  group('count-in', () {
    testWidgets(
      'ticks in one by one, 40 ms apart, ending at the right number',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const AppWeekSegments(
              style: WeekStyle.marks,
              total: 4,
              filled: 3,
              stagger: HandTiming.staggerStep,
            ),
          ),
        );
        expect(find.byType(HandTick), findsNWidgets(3));
        final delays = [
          for (final t in tester.widgetList<HandTick>(find.byType(HandTick)))
            t.delay,
        ];
        expect(delays, [
          Duration.zero,
          HandTiming.staggerStep,
          HandTiming.staggerStep * 2,
        ]);
        await tester.pumpAndSettle();
        expect(find.byType(HandTick), findsNWidgets(3));
      },
    );

    testWidgets('is complete on the first frame under Reduce Motion', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const AppWeekSegments(
            style: WeekStyle.marks,
            total: 5,
            filled: 2,
            stagger: HandTiming.staggerStep,
          ),
          still: true,
        ),
      );
      expect(find.byType(HandTick), findsNWidgets(2));
      await tester.pump();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('R10 keeps her streak in See details, and states her days', (
      tester,
    ) async {
      AppRouter.featureFlags = FeatureFlags.everything;
      await tester.pumpWidget(
        _host(
          const FinishedView(
            session: _live,
            summary: SessionSummary(
              sessionId: 'live-9',
              source: SessionSource.live,
              moves: 3,
              sets: 9,
              minutes: 20,
              credit: CreditOutcome(sessionPoints: 30),
              trainingStreak: StreakStatus(enabled: true, days: 4, best: 4),
            ),
          ),
          bare: true,
        ),
      );
      await tester.pumpAndSettle();
      // Not on the celebration itself: behind See details.
      expect(find.textContaining('Training streak:'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('r10-see-details')));
      await tester.pumpAndSettle();
      expect(find.text('Training streak: 4 days'), findsOneWidget);
      expect(find.byType(AppWeekSegments), findsOneWidget);
      expect(find.textContaining('lost'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
