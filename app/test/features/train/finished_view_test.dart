// R10 — Finished.
//
// The one celebration. What it must get right is the order of what she earned,
// and that the trophy appears only for a session that was actually measured.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/haptics.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/rewards/credit_outcome.dart';
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/features/train/domain/session_summary.dart';
import 'package:own_hub/ui/hand/mascot/kitten_painter.dart';
import 'package:own_hub/ui/hand/paper_confetti.dart';
import 'package:own_hub/ui/hand/hand.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/finish_reveal.dart';
import 'package:own_hub/features/train/presentation/finished_view.dart';
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

const _live = TrainSession(
  id: 'live-1',
  source: SessionSource.live,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

const _recalled = TrainSession(
  id: 'recalled-2026-09-15-day-2',
  source: SessionSource.recalled,
  dateKey: '2026-09-15',
  sets: [],
  completed: true,
);

void main() {
  // The share link posts to a group, so R10 is tested with Community on.
  final savedFlags = AppRouter.featureFlags;
  setUp(
    () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.community: true,
    }),
  );
  tearDown(() => AppRouter.featureFlags = savedFlags);

  testWidgets('names what she earned, in the order she cares about', (
    tester,
  ) async {
    // A Tuesday, so the heading is checkable. It used to say Tuesday to
    // everyone on every day, which is what this now guards against.
    await tester.pumpWidget(
      _host(FinishedView(finishedOn: DateTime(2026, 9, 15))),
    );
    await tester.pumpAndSettle();

    expect(find.text("That's Tuesday done"), findsOneWidget);
    // No points are claimed before the ledger has answered (D41): the fixed
    // "+30 points" stood here whether or not anything was granted.
    expect(find.textContaining('points'), findsNothing);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('One more session and this week counts.'), findsOneWidget);

    // What this test used to assert, and should not have.
    //
    // R10 is handed a session, a week and a level percentage — and no lifetime
    // balance, no session number and no points-to-next-level. It stated all
    // three anyway, from fixed strings, so the assertions below pinned the
    // prototype's history as every woman's. They are gone rather than
    // corrected: none has a parameterised form to correct them into.
    expect(
      find.text('15 minutes, 5 moves, 14 sets. You typed nothing.'),
      findsNothing,
    );
    expect(find.text('490 total'), findsNothing);
    expect(find.text('Session 20 · personal best 10'), findsNothing);
    expect(find.text('70 points to level 8.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no personal best is claimed without a real one (D40)', (
    tester,
  ) async {
    // This screen used to draw "A personal best" in an amber card with a
    // trophy for every measured session, whether or not anything was beaten.
    await tester.pumpWidget(_host(const FinishedView(session: _live)));
    await tester.pumpAndSettle();

    expect(find.text('A personal best'), findsNothing);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
    expect(find.byKey(const ValueKey('r10-bests')), findsNothing);
  });

  testWidgets(
    'a best she really beat is named, with the value it beat, in sage',
    (tester) async {
      await tester.pumpWidget(
        _host(
          FinishedView(
            session: _live,
            summary: SessionSummary(
              sessionId: 'live-1',
              source: SessionSource.live,
              moves: 4,
              sets: 11,
              minutes: 24,
              credit: const CreditOutcome(sessionPoints: 30),
              newBests: const [
                PersonalBest(
                  exerciseId: 'glute_bridge',
                  metric: BestMetric.reps,
                  dateKey: '2026-09-15',
                  sessionId: 'live-1',
                  reps: 14,
                  previous: PreviousBest(reps: 12),
                ),
              ],
              firstMarks: 2,
              moveNames: const {'glute_bridge': 'Glute bridge'},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Glute bridge: 14 reps, up from 12 reps'),
        findsOneWidget,
      );
      expect(find.text('First marks set on 2 moves.'), findsOneWidget);
      expect(find.text('Moves: 4 · Sets: 11 · Time: 24 min'), findsOneWidget);
      expect(find.text('+30 points'), findsOneWidget);
      expect(find.byIcon(Icons.emoji_events), findsNothing);
      final line = tester.widget<Text>(
        find.text('Glute bridge: 14 reps, up from 12 reps'),
      );
      expect(line.style?.color, AppColors.tertiary);
    },
  );

  testWidgets('a recalled session never shows one, even on this screen', (
    tester,
  ) async {
    // The rule travels with the session, not with the screen it lands on.
    await tester.pumpWidget(
      _host(
        const FinishedView(
          session: _recalled,
          summary: SessionSummary(
            sessionId: 'recalled-2026-09-15-day-2',
            source: SessionSource.recalled,
            newBests: [
              PersonalBest(
                exerciseId: 'squat',
                metric: BestMetric.reps,
                dateKey: '2026-09-15',
                sessionId: 'r',
                reps: 20,
                previous: PreviousBest(reps: 10),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('r10-bests')), findsNothing);
  });

  testWidgets('points the cap refused are not claimed', (tester) async {
    await tester.pumpWidget(
      _host(
        const FinishedView(
          session: _live,
          summary: SessionSummary(
            sessionId: 'live-3',
            source: SessionSource.live,
            credit: CreditOutcome(sessionPoints: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('points'), findsNothing);
  });

  testWidgets('the session that counts the week says so', (tester) async {
    await tester.pumpWidget(
      _host(
        const FinishedView(
          session: _live,
          sessionsThisWeek: 3,
          sessionsPrescribed: 3,
          summary: SessionSummary(
            sessionId: 'live-3',
            source: SessionSource.live,
            credit: CreditOutcome(
              sessionPoints: 30,
              weekPoints: 40,
              weekCountedNow: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('r10-week-counts')), findsOneWidget);
    expect(find.text('+70 points'), findsOneWidget);
  });

  group('the reveal (D40)', () {
    setUp(
      () => AppRouter.featureFlags = FeatureFlags.allOff.with_({
        Feature.community: true,
        // `finishReveal` lives inside `train`, and a switch is on only when
        // its parents are.
        Feature.train: true,
        Feature.finishReveal: true,
      }),
    );

    const summary = SessionSummary(
      sessionId: 'live-9',
      source: SessionSource.live,
      moves: 3,
      sets: 9,
      minutes: 20,
      credit: CreditOutcome(sessionPoints: 30),
    );

    testWidgets('arrives in turn and settles, with confetti once', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(const FinishedView(session: _live, summary: summary)),
      );
      await tester.pump();
      // The paper comes last, after the kitten (stage 6 of 7).
      expect(find.byType(PaperConfetti), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(PaperConfetti), findsOneWidget);
      // Every stage is on the page once it has run.
      expect(find.text('Moves: 3 · Sets: 9 · Time: 20 min'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'the cheer and the burst arrive with their stages, not before',
      (tester) async {
        Kitten.resetPlayed();
        await tester.pumpWidget(
          _host(
            const FinishedView(
              session: _live,
              cheer: true,
              sessionsThisWeek: 3,
              sessionsPrescribed: 3,
              summary: SessionSummary(
                sessionId: 'live-10',
                source: SessionSource.live,
                credit: CreditOutcome(
                  sessionPoints: 30,
                  weekPoints: 40,
                  weekCountedNow: true,
                  loggedAfter: 3,
                  target: 3,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        // The order is the week (stage 2), the cheer (stage 5), then the
        // paper (stage 6): none exists before its stage starts to arrive.
        expect(find.byType(PaperConfetti), findsNothing);
        expect(find.byType(Kitten), findsNothing);
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(PaperConfetti), findsNothing);
        expect(find.byType(Kitten), findsNothing);
        await tester.pump(const Duration(milliseconds: 450));
        expect(find.byType(Kitten), findsOneWidget);
        expect(find.byType(PaperConfetti), findsNothing);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(PaperConfetti), findsOneWidget);
        await tester.pumpAndSettle();
      },
    );

    testWidgets('a session that is not a full cheer gets a nod, one kitten', (
      tester,
    ) async {
      Kitten.resetPlayed();
      await tester.pumpWidget(
        _host(
          const FinishedView(
            session: _live,
            sessionsThisWeek: 1,
            sessionsPrescribed: 3,
            summary: SessionSummary(
              sessionId: 'live-11',
              source: SessionSource.live,
              credit: CreditOutcome(
                sessionPoints: 10,
                weekPoints: 10,
                weekCountedNow: false,
                loggedAfter: 1,
                target: 3,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(Kitten), findsOneWidget);
      expect(tester.widget<Kitten>(find.byType(Kitten)).pose, KittenPose.nod);
      await tester.pumpAndSettle();
    });

    testWidgets('only the day is drawn while the credit is landing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          FinishedView(
            session: _live,
            awaitingSummary: true,
            finishedOn: DateTime(2026, 9, 15),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text("That's Tuesday done"), findsOneWidget);
      expect(find.text('This week'), findsNothing);
      expect(find.text('One more session and this week counts.'), findsNothing);
    });

    testWidgets(
      'when the summary lands, the first stage stays and the rest arrive',
      (tester) async {
        await tester.pumpWidget(
          _host(
            FinishedView(
              session: _live,
              awaitingSummary: true,
              finishedOn: DateTime(2026, 9, 15),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(
          _host(
            FinishedView(
              session: _live,
              summary: summary,
              finishedOn: DateTime(2026, 9, 15),
            ),
          ),
        );
        await tester.pump();
        double inkOf(String text) => tester
            .widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.text(text),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            )
            .opacity
            .value;
        expect(inkOf("That's Tuesday done"), 1);
        expect(inkOf('Moves: 3 · Sets: 9 · Time: 20 min'), lessThan(1));
        await tester.pumpAndSettle();
        expect(inkOf('Moves: 3 · Sets: 9 · Time: 20 min'), 1);
      },
    );

    testWidgets(
      'one medium tap, as the kitten cheers, and the week counts up',
      (tester) async {
        final felt = <String?>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'HapticFeedback.vibrate') {
                felt.add(call.arguments as String?);
              }
              return null;
            });
        final saved = AppHaptics.enabled;
        AppHaptics.enabled = () => true;
        addTearDown(() {
          AppHaptics.enabled = saved;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });
        await tester.pumpWidget(
          _host(
            const FinishedView(
              session: _live,
              sessionsThisWeek: 2,
              sessionsPrescribed: 3,
              summary: SessionSummary(
                sessionId: 'live-12',
                source: SessionSource.live,
                credit: CreditOutcome(
                  sessionPoints: 30,
                  weekPoints: 40,
                  weekCountedNow: true,
                  loggedAfter: 3,
                  target: 3,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(felt, isEmpty);
        // Stage 3 is the count-up (450 ms): mid-way it is not yet the final
        // figure, and the kitten (stage 5, 750 ms) has not cheered.
        await tester.pump(const Duration(milliseconds: 740));
        expect(felt, isEmpty);
        // The cheer arrives, and the one medium tap lands with it.
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.text('3 of 3'), findsNothing);
        expect(felt, ['HapticFeedbackType.mediumImpact']);
        await tester.pumpAndSettle();
        expect(find.text('3 of 3'), findsOneWidget);
        expect(felt, ['HapticFeedbackType.mediumImpact']);
      },
    );

    testWidgets(
      'the whole reveal, cheer to confetti, ends inside two seconds',
      (tester) async {
        await tester.pumpWidget(
          _host(
            const FinishedView(session: _live, cheer: true, summary: summary),
          ),
        );
        await tester.pump();
        // The cheer's move (stage 5, 750 ms + 1200 ms) is the last thing of
        // the reveal to finish, and the paper (stage 6) is long gone.
        for (var ms = 0; ms < 1950; ms += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(
          find.descendant(
            of: find.byType(PaperConfetti),
            matching: find.byType(CustomPaint),
          ),
          findsNothing,
        );
        for (final fade in tester.widgetList<FadeTransition>(
          find.byType(FadeTransition),
        )) {
          expect(fade.opacity.value, 1);
        }
        // What is left is the kitten's idle breathing, and then it is still.
        await tester.pump(kittenRunFor(KittenPose.cheer));
        expect(tester.hasRunningAnimations, isFalse);
      },
    );

    testWidgets('ink that draws on is timed from now, not from the start', (
      tester,
    ) async {
      Duration? lead;
      Widget host({required bool enabled}) => _host(
        FinishReveal(
          stages: 7,
          enabled: enabled,
          child: Builder(
            builder: (context) {
              lead = revealLead(context, 2);
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(host(enabled: true));
      expect(lead, const Duration(milliseconds: 300));
      await tester.pumpWidget(const SizedBox());
      // The page opened first and its summary landed later: the reveal
      // resumes at the second stage, so stage 2 is one step away, not two.
      await tester.pumpWidget(host(enabled: false));
      await tester.pumpWidget(host(enabled: true));
      expect(lead, const Duration(milliseconds: 150));
    });

    testWidgets('a tap brings everything in at once', (tester) async {
      await tester.pumpWidget(
        _host(const FinishedView(session: _live, summary: summary)),
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(200, 300));
      await tester.pump();
      final effort = find.ancestor(
        of: find.text('Moves: 3 · Sets: 9 · Time: 20 min'),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(effort.first).opacity.value, 1);
      await tester.pumpAndSettle();
    });

    testWidgets('is still under Reduce Motion: complete on the first frame', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppL10n.localizationsDelegates,
          supportedLocales: AppL10n.supportedLocales,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: FinishedView(session: _live, summary: summary),
          ),
        ),
      );
      await tester.pump();
      final effort = find.ancestor(
        of: find.text('Moves: 3 · Sets: 9 · Time: 20 min'),
        matching: find.byType(FadeTransition),
      );
      expect(tester.widget<FadeTransition>(effort.first).opacity.value, 1);
      // No confetti at all under Reduce Motion.
      expect(
        find.descendant(
          of: find.byType(PaperConfetti),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });

  testWidgets('sharing is a quiet link, and hands over an intent only', (
    tester,
  ) async {
    var shared = 0;
    var back = 0;
    await tester.pumpWidget(
      _host(FinishedView(onShare: () => shared++, onBackToToday: () => back++)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Share the squat with your group'));
    await tester.tap(find.text('Back to today'));
    await tester.pumpAndSettle();

    expect(shared, 1);
    expect(back, 1);
  });

  testWidgets('the week is drawn as a count of sessions, never as days', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const FinishedView(sessionsThisWeek: 2, sessionsPrescribed: 3)),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 of 3'), findsOneWidget);
    // Rule 3: nothing on this screen counts consecutive days.
    expect(find.textContaining('day streak'), findsNothing);
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(
        FinishedView(session: _live, finishedOn: DateTime(2026, 9, 15)),
        locale: const Locale('ar'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('كده خلّصتي الثلاثاء'), findsOneWidget);
    // No best is claimed without one (D40); the Arabic "A personal best" that
    // stood here was the trophy every live session used to get.
    expect(find.text('رقم شخصي جديد'), findsNothing);
    expect(find.text('ارجعي لصفحة اليوم'), findsOneWidget);
    expect(find.text('Back to today'), findsNothing);
  });

  testWidgets('the effort line agrees with its minutes in Arabic', (
    tester,
  ) async {
    for (final (minutes, words) in const [
      (1, 'دقيقة واحدة'),
      (2, 'دقيقتين'),
      (5, '5 دقايق'),
      (24, '24 دقيقة'),
    ]) {
      await tester.pumpWidget(
        _host(
          FinishedView(
            session: _live,
            summary: SessionSummary(
              sessionId: 'live-$minutes',
              source: SessionSource.live,
              moves: 3,
              sets: 9,
              minutes: minutes,
            ),
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(words), findsOneWidget, reason: '$minutes');
    }
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const FinishedView(session: _live),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
